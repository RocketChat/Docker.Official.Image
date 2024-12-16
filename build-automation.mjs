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

    acc.set(minor, latest > patch ? latest : patch);

    return acc;
  }, new Map());
  return groupedReleases;
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

  await removeCurrentVersions();

  for await (const [minor, patch] of supportedVersions) {
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
