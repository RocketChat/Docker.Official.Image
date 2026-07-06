import { promisify } from "util";

import child_process from "child_process";

const exec = promisify(child_process.exec);

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

    const { nodeVersion } = info;

    const nodeMajor = nodeVersion.replace(/([0-9]+)\..*/, '$1');

    await exec(`cp -r ./templates/node${nodeMajor} ${minor}`, { shell: "bash" });

    await exec(`sed -ri 's/^(ENV RC_VERSION=).*/\\1'"${fullVersion}"'/;' ${minor}/Dockerfile`, { shell: "bash" });
    await exec(`sed -ri 's/^(ENV NODE_VERSION=).*/\\1'"${nodeVersion}"'/;' ${minor}/Dockerfile`, { shell: "bash" });
  }

  return newVersions;
}
