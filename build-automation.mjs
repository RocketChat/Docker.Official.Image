import { promisify } from "util";

import child_process from "child_process";

import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";

const exec = promisify(child_process.exec);

const SEMVER = /^\d+\.\d+\.\d+$/;
const SHA256 = /^[0-9a-f]{64}$/;

const DENO_ARCHES = {
  amd64: 'x86_64',
  arm64: 'aarch64',
};

const denoDigests = JSON.parse(await readFile(new URL('./deno-digests.json', import.meta.url), 'utf8'));

const denoArchiveUrl = (denoVersion, denoArch) =>
  `https://dl.deno.land/release/v${denoVersion}/deno-${denoArch}-unknown-linux-gnu.zip`;

// keyed by `${denoVersion}-${denoArch}`; most minors share a Deno version, so a release-day run
// downloads each archive once
const verifiedArchives = new Set();

// The entry in ./deno-digests.json is what ships. This download only detects an upstream re-tag:
// the same version tag that now serves a different archive.
const verifyDenoArchive = async (denoVersion, denoArch, expected) => {
  const key = `${denoVersion}-${denoArch}`;

  if (verifiedArchives.has(key)) {
    return;
  }

  verifiedArchives.add(key);

  const url = denoArchiveUrl(denoVersion, denoArch);

  let actual;

  try {
    const archive = await fetch(url);

    if (!archive.ok) {
      throw new Error(`HTTP ${archive.status}`);
    }

    actual = createHash('sha256')
      .update(Buffer.from(await archive.arrayBuffer()))
      .digest('hex');
  } catch (error) {
    console.warn(`Warning: cannot reach ${url} to verify Deno ${denoVersion} ${denoArch}: ${error.message}`);

    return;
  }

  if (actual !== expected) {
    throw new Error(
      `Deno ${denoVersion} ${denoArch}: ${url} now serves ${actual}, but ./deno-digests.json pins ${expected}. `
      + `Upstream replaced the archive under the same tag. Investigate before you touch the digest.`,
    );
  }

  console.log(`Deno ${denoVersion} ${denoArch}: ${expected} (archive matches)`);
};

const getDenoDigest = async (denoVersion, denoArch) => {
  const digest = denoDigests[denoVersion]?.[denoArch];

  if (!digest) {
    throw new Error(
      `No digest of record for Deno ${denoVersion} ${denoArch}. Add one to ./deno-digests.json:\n`
      + `  curl -fsSL ${denoArchiveUrl(denoVersion, denoArch)} | sha256sum`,
    );
  }

  if (!SHA256.test(digest)) {
    throw new Error(`./deno-digests.json: Deno ${denoVersion} ${denoArch} holds ${JSON.stringify(digest)}, which is not a sha256 digest`);
  }

  await verifyDenoArchive(denoVersion, denoArch, digest);

  return digest;
};

const replaceOnce = (contents, pattern, replacement, description) => {
  const matches = contents.match(new RegExp(pattern.source, `${pattern.flags}g`)) ?? [];

  if (matches.length !== 1) {
    throw new Error(`Expected exactly one ${description}, found ${matches.length}: ./templates and build-automation.mjs have drifted apart`);
  }

  return contents.replace(pattern, replacement);
};

const updateDockerfile = async (minor, { fullVersion, nodeVersion, denoVersion }) => {
  const file = `${minor}/Dockerfile`;

  let contents = await readFile(file, 'utf8');

  contents = replaceOnce(contents, /^(ENV RC_VERSION=).*$/m, `$1${fullVersion}`, 'ENV RC_VERSION line');

  // only the node14 template installs Node itself; the node:* based ones inherit it from FROM
  if (/^ENV NODE_VERSION=/m.test(contents)) {
    contents = replaceOnce(contents, /^(ENV NODE_VERSION=).*$/m, `$1${nodeVersion}`, 'ENV NODE_VERSION line');
  }

  // the node14 template has no Deno step
  if (/^ENV DENO_VERSION=/m.test(contents)) {
    contents = replaceOnce(contents, /^(ENV DENO_VERSION=).*$/m, `$1${denoVersion}`, 'ENV DENO_VERSION line');

    for (const [dpkgArch, denoArch] of Object.entries(DENO_ARCHES)) {
      // node20 has no arm64 branch, because Deno 1.37.1 ships no aarch64 build
      if (!contents.includes(`denoArch='${denoArch}'`)) {
        continue;
      }

      contents = replaceOnce(
        contents,
        new RegExp(`(denoArch='${denoArch}';[\\s\\S]{0,80}?denoSha256=')[0-9a-f]{64}(')`),
        `$1${await getDenoDigest(denoVersion, denoArch)}$2`,
        `${dpkgArch} Deno digest`,
      );
    }
  }

  await writeFile(file, contents);
};

const getCurrentVersions = async () => {
  const versionsOutput = await getCurrentFolders();

  const currentVersions = [];

  await Promise.all(versionsOutput.trim().split(' ').map(async (folder) => {
    const { stdout: fullVersionOutput } = await exec(`. ./functions.sh && get_full_version ${folder}`, { shell: "bash" });

    currentVersions.push(fullVersionOutput.trim());
  }));

  return currentVersions;
};

const getSupportedVersions = async (github) => {
  const { data: releases } = await github.request('https://releases.rocket.chat/v2/server/supportedVersions');

  const stableReleases = releases.versions.filter(({ releaseType }) => releaseType === 'stable');

  const groupedReleases = stableReleases.reduce((acc, { version }) => {
    const minor = version.replace(/([0-9+])\.([0-9]+).*/, '$1.$2');
    const patch = version.replace(/([0-9+])\.([0-9]+)\.([0-9]+).*/, '$3');

    const latest = acc.get(minor) || 0;

    acc.set(minor, Number(latest) > Number(patch) ? latest : patch);

    return acc;
  }, new Map());
  return groupedReleases;
};

const getMinor = (version) => version.split('.').slice(0, 2).join('.');

const compareMinors = (a, b) => {
  const [aMajor, aMinor] = a.split('.').map(Number);
  const [bMajor, bMinor] = b.split('.').map(Number);

  return (aMajor - bMajor) || (aMinor - bMinor);
};

const removeCurrentVersions = async () => {
  const versionsOutput = await getCurrentFolders();

  await Promise.all(versionsOutput.trim().split(' ').map((folder) => exec(`rm -rf ./${folder}`, { shell: "bash" })));
}

const getCurrentFolders = async () => {
  const { stdout } = await exec(". ./functions.sh && get_versions", { shell: "bash" });

  return stdout;
};

export default async function(github) {
  const supportedVersions = await getSupportedVersions(github);

  const currentVersions = await getCurrentVersions();

  const newVersions = Array
    .from(supportedVersions)
    .map(([minor, patch]) => `${minor}.${patch}`)
    .filter((version) => !currentVersions.includes(version));

  if (newVersions.length === 0) {
    console.log('No new versions found. No update required.');
    process.exit(0);
  }

  // keep publishing minors that left the supported list while an older minor
  // (e.g. an old LTS) is still supported, frozen at their last published patch
  const oldestSupportedMinor = Array.from(supportedVersions.keys()).sort(compareMinors)[0];

  const versionsToBuild = new Map(supportedVersions);

  for (const version of currentVersions) {
    const minor = getMinor(version);

    if (!versionsToBuild.has(minor) && compareMinors(minor, oldestSupportedMinor) > 0) {
      versionsToBuild.set(minor, version.split('.')[2]);
    }
  }

  await removeCurrentVersions();

  for await (const [minor, patch] of versionsToBuild) {
    const fullVersion = `${minor}.${patch}`;

    const { data: info } = await github.request(`https://releases.rocket.chat/${fullVersion}/info`);

    const { nodeVersion, denoVersion } = info;

    // these values come off the network and land in a shell command and in replacement strings
    for (const [label, value] of [['Rocket.Chat', fullVersion], ['Node.js', nodeVersion], ['Deno', denoVersion]]) {
      if (!SEMVER.test(value)) {
        throw new Error(`${fullVersion}: unexpected ${label} version ${JSON.stringify(value)}`);
      }
    }

    console.log(`Building ${fullVersion} with Node.js ${nodeVersion} and Deno ${denoVersion}`);

    const nodeMajor = nodeVersion.replace(/([0-9]+)\..*/, '$1');

    await exec(`cp -r ./templates/node${nodeMajor} ${minor}`, { shell: "bash" });

    await updateDockerfile(minor, { fullVersion, nodeVersion, denoVersion });
  }

  return newVersions;
}
