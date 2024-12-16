#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Grab last git commit
function getCommitHasForPath(path) {
  return require('child_process')
  .execSync(`git log -1 --format=%H HEAD -- ${path}`)
  .toString().trim()
}

const stackbrewPath = path.basename(__filename);

const url = 'https://github.com/RocketChat/Docker.Official.Image';

// Header
let stackbrew = `# this file is generated via ${url}/blob/${getCommitHasForPath(stackbrewPath)}/${stackbrewPath}

Maintainers: Rocket.Chat Image Team <buildmaster@rocket.chat> (@RocketChat)
GitRepo: ${url}.git
GitFetch: refs/heads/main\n`;

// Loop versions
const rcDirRegex = /^\d+\.\d+$/;

// Returns a list of the child directories in the given path
const getChildDirectories = (parent) => fs.readdirSync(parent, { withFileTypes: true })
  .filter((dirent) => dirent.isDirectory())
  .map(({ name }) => name);

const getRocketChatVersionDirs = (base) => getChildDirectories(base)
  .filter((childPath) => rcDirRegex.test(path.basename(childPath)));

// versions need to be in order from most recent to older
const versions = getRocketChatVersionDirs(__dirname)
  .sort((a,b) => b.localeCompare(a, undefined, { numeric: true, sensitivity: 'base' }));

let foundCurrent = false;

const latestMajor = [];

for (version of versions) {
  const isCurrent = !foundCurrent;
  foundCurrent = true;

  let fullversion;

  // Get full version from the first Dockerfile
  if (!fullversion) {
    const dockerfile = fs.readFileSync(path.join(version, 'Dockerfile'), 'utf-8');
    fullversion = dockerfile.match(/ENV RC_VERSION=(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)/)
  }
  let tags = [
    `${fullversion.groups.major}.${fullversion.groups.minor}.${fullversion.groups.patch}`,
    `${fullversion.groups.major}.${fullversion.groups.minor}`,
  ];

  const isLatestMajor = !latestMajor.includes(fullversion.groups.major);

  if (isLatestMajor) {
    tags.push(fullversion.groups.major);

    latestMajor.push(fullversion.groups.major);
  }

  if (isCurrent) {
    tags.push('latest');
  }

  // remove duplicates
  tags = tags.filter((x, i, a) => a.indexOf(x) == i);
  tags = tags.sort((a, b) => b - a);

  stackbrew += `\nTags: ${tags.join(', ')}\n`;
  // stackbrew += `Architectures: ${tbd.join(', ')}\n`
  stackbrew += `GitCommit: ${getCommitHasForPath(version)}\n`;
  stackbrew += `Directory: ${version}\n`;
}

// output
console.log(stackbrew)
