#!/usr/bin/env node

// Classifies the difference between the published library/rocket.chat manifest and a freshly
// generated one, and emits the `changed`, `title` and `body` outputs used to open the
// docker-library/official-images pull request.
//
//   node library-diff.mjs <old-manifest> <new-manifest> [<dockerfile-root>]

import { appendFileSync, readFileSync } from 'fs';
import path from 'path';

const OUTPUT_DELIMITER = '__LIBRARY_DIFF_EOF__';
const FULL_VERSION = /^\d+\.\d+\.\d+$/;
const RELEASE_NOTES = 'https://github.com/RocketChat/Rocket.Chat/releases/tag';

const parseManifest = (text) => {
  const entries = new Map();

  for (const block of text.split(/\n{2,}/)) {
    const fields = {};

    for (const line of block.split('\n')) {
      const field = line.match(/^([A-Za-z][A-Za-z0-9-]*):\s*(.*)$/);

      if (field) {
        fields[field[1]] = field[2].trim();
      }
    }

    // the header block carries Maintainers/GitRepo/GitFetch and no Directory
    if (!fields.Directory) {
      continue;
    }

    entries.set(fields.Directory, {
      directory: fields.Directory,
      gitCommit: fields.GitCommit || '',
      tags: (fields.Tags || '').split(',').map((tag) => tag.trim()).filter(Boolean),
    });
  }

  return entries;
};

// A shallow checkout makes `git log -1 -- <dir>` return nothing, and stackbrew.js then emits an
// empty GitCommit without complaining. Refuse to build a PR out of that.
const assertUsable = (entries, label) => {
  if (entries.size === 0) {
    throw new Error(`${label}: no version blocks found — the manifest looks empty or malformed`);
  }

  for (const { directory, gitCommit, tags } of entries.values()) {
    if (!/^[0-9a-f]{40}$/.test(gitCommit)) {
      throw new Error(
        `${label}: Directory ${directory} has an invalid GitCommit ${JSON.stringify(gitCommit)}` +
        ` — the checkout is likely too shallow for \`git log -1 -- ${directory}\``,
      );
    }

    if (!tags.some((tag) => FULL_VERSION.test(tag))) {
      throw new Error(`${label}: Directory ${directory} has no X.Y.Z tag (got: ${tags.join(', ') || 'none'})`);
    }
  }
};

const fullVersion = (entry) => entry.tags.find((tag) => FULL_VERSION.test(tag));

// descending
const compareVersions = (a, b) => {
  const left = a.split('.').map(Number);
  const right = b.split('.').map(Number);

  return (right[0] - left[0]) || (right[1] - left[1]) || ((right[2] || 0) - (left[2] || 0));
};

const byDirectoryDesc = (a, b) => compareVersions(a.directory, b.directory);

const classify = (oldEntries, newEntries) => {
  const added = [];
  const bumped = [];
  const rebuilt = [];
  const retagged = [];
  const dropped = [];

  for (const [directory, next] of newEntries) {
    const previous = oldEntries.get(directory);

    if (!previous) {
      added.push({ directory, next });
    } else if (fullVersion(previous) !== fullVersion(next)) {
      bumped.push({ directory, previous, next });
    } else if (previous.gitCommit !== next.gitCommit) {
      rebuilt.push({ directory, previous, next });
    } else if (previous.tags.join(', ') !== next.tags.join(', ')) {
      retagged.push({ directory, previous, next });
    }
  }

  for (const [directory, previous] of oldEntries) {
    if (!newEntries.has(directory)) {
      dropped.push({ directory, previous });
    }
  }

  return {
    added: added.sort(byDirectoryDesc),
    bumped: bumped.sort(byDirectoryDesc),
    rebuilt: rebuilt.sort(byDirectoryDesc),
    retagged: retagged.sort(byDirectoryDesc),
    dropped: dropped.sort(byDirectoryDesc),
  };
};

const withOverflow = (items, keep) => {
  const remaining = items.length - keep;

  return remaining > 0 ? `${items.slice(0, keep).join(', ')} (+${remaining} more)` : items.join(', ');
};

const describeTagDelta = (items) => {
  const removed = new Set();
  const introduced = new Set();

  for (const { previous, next } of items) {
    for (const tag of previous.tags) {
      if (!next.tags.includes(tag)) {
        removed.add(tag);
      }
    }

    for (const tag of next.tags) {
      if (!previous.tags.includes(tag)) {
        introduced.add(tag);
      }
    }
  }

  if (removed.size && !introduced.size) {
    return [...removed].every((tag) => /^\d+$/.test(tag))
      ? 'drop major tags'
      : `drop ${withOverflow([...removed], 3)}`;
  }

  if (introduced.size && !removed.size) {
    return `add ${withOverflow([...introduced], 3)}`;
  }

  return '';
};

const buildTitle = ({ added, bumped, rebuilt, retagged, dropped }) => {
  const releases = [...added, ...bumped].map(({ next }) => fullVersion(next)).sort(compareVersions);

  if (releases.length) {
    return `Update rocket.chat to ${withOverflow(releases, 3)}`;
  }

  if (rebuilt.length) {
    return `Rocket.Chat: rebuild ${withOverflow(rebuilt.map(({ directory }) => directory), 4)}`;
  }

  const parts = [];

  if (retagged.length) {
    const delta = describeTagDelta(retagged);

    parts.push(`retag ${withOverflow(retagged.map(({ directory }) => directory), 4)}${delta ? ` (${delta})` : ''}`);
  }

  if (dropped.length) {
    parts.push(`drop ${withOverflow(dropped.map(({ directory }) => directory), 4)}`);
  }

  return `Rocket.Chat: ${parts.join(', ')}`;
};

const readImageInfo = (root, directory) => {
  let dockerfile;

  try {
    dockerfile = readFileSync(path.join(root, directory, 'Dockerfile'), 'utf-8');
  } catch {
    return '';
  }

  const base = dockerfile.match(/^FROM\s+(\S+)/m);
  const deno = dockerfile.match(/^ENV DENO_VERSION=(\S+)/m);

  return [base && base[1], deno && `Deno ${deno[1]}`].filter(Boolean).join(', ');
};

const buildBody = ({ added, bumped, rebuilt, retagged, dropped }, { sourcePr, dockerfileRoot }) => {
  const sections = [];

  if (sourcePr) {
    sections.push(`Source: ${sourcePr}`);
  }

  const releases = [...added, ...bumped].sort(byDirectoryDesc);

  if (releases.length) {
    sections.push([
      '### New versions',
      ...releases.map(({ directory, next }) => {
        const version = fullVersion(next);
        const info = readImageInfo(dockerfileRoot, directory);

        return `- \`${directory}\` → **${version}**${info ? ` — ${info}` : ''}\n  ${RELEASE_NOTES}/${version}`;
      }),
    ].join('\n'));
  }

  if (rebuilt.length) {
    sections.push([
      '### Rebuilt (no version change)',
      ...rebuilt.map(({ directory, next }) => {
        const info = readImageInfo(dockerfileRoot, directory);

        return `- \`${directory}\` (${fullVersion(next)})${info ? ` — ${info}` : ''}`;
      }),
    ].join('\n'));
  }

  if (retagged.length) {
    sections.push([
      '### Tag changes',
      ...retagged.map(({ directory, previous, next }) => `- \`${directory}\`: ${previous.tags.join(', ')} → ${next.tags.join(', ')}`),
    ].join('\n'));
  }

  if (dropped.length) {
    sections.push([
      '### Removed',
      ...dropped.map(({ directory, previous }) => `- \`${directory}\` (was ${fullVersion(previous)})`),
    ].join('\n'));
  }

  return sections.join('\n\n');
};

const setOutput = (name, value) => {
  const text = String(value);

  if (text.includes(OUTPUT_DELIMITER)) {
    throw new Error(`output ${name} contains the heredoc delimiter ${OUTPUT_DELIMITER}`);
  }

  const line = text.includes('\n')
    ? `${name}<<${OUTPUT_DELIMITER}\n${text}\n${OUTPUT_DELIMITER}\n`
    : `${name}=${text}\n`;

  if (process.env.GITHUB_OUTPUT) {
    appendFileSync(process.env.GITHUB_OUTPUT, line);
  } else {
    process.stdout.write(line);
  }
};

const [oldPath, newPath, dockerfileRoot = '.'] = process.argv.slice(2);

if (!oldPath || !newPath) {
  console.error('usage: library-diff.mjs <old-manifest> <new-manifest> [<dockerfile-root>]');
  process.exit(2);
}

const oldEntries = parseManifest(readFileSync(oldPath, 'utf-8'));
const newEntries = parseManifest(readFileSync(newPath, 'utf-8'));

assertUsable(newEntries, newPath);

const changes = classify(oldEntries, newEntries);
const changed = Object.values(changes).some(({ length }) => length > 0);

for (const [bucket, items] of Object.entries(changes)) {
  if (items.length) {
    console.error(`${bucket}: ${items.map(({ directory }) => directory).join(', ')}`);
  }
}

setOutput('changed', String(changed));

if (!changed) {
  console.error('no change to library/rocket.chat');
  process.exit(0);
}

const title = buildTitle(changes);

console.error(`title: ${title}`);

setOutput('title', title);
setOutput('body', buildBody(changes, { sourcePr: process.env.SOURCE_PR, dockerfileRoot }));
