#!/bin/bash
# Print the newest @deepseek-ai/dsh release: the highest semver across all npm
# dist-tags. npm's `latest` tag can lag `next`, so "latest" alone is not newest.
# Uses the semver module that ships inside npm; no extra dependency.
set -euo pipefail
tags="$(npm view @deepseek-ai/dsh dist-tags --json)"
semver="$(npm root -g)/npm/node_modules/semver"
node -e '
const semver = require(process.argv[1]);
const versions = Object.values(JSON.parse(process.argv[2])).filter((v) => semver.valid(v));
if (!versions.length) process.exit(1);
console.log(versions.sort(semver.rcompare)[0]);
' "${semver}" "${tags}"
