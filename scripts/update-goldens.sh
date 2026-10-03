#!/bin/sh
# Regenerate golden files on Linux CI for a branch, then pull the result.
#
# Goldens must not be generated locally on macOS: font rendering differs from
# the Linux runner that compares them (see .github/workflows/golden.yml).
#
# Usage: scripts/update-goldens.sh [branch]   (defaults to the current branch)
# Requires: gh (authenticated), and the branch pushed to origin.

set -eu

branch=${1:-$(git rev-parse --abbrev-ref HEAD)}

if [ "$(git rev-parse "$branch")" != "$(git rev-parse "origin/$branch" 2>/dev/null)" ]; then
  echo "update-goldens: push '$branch' first; CI regenerates goldens from origin/$branch." >&2
  exit 1
fi

started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
gh workflow run golden.yml --ref "$branch" -f update=true

echo "Waiting for the run to start..."
run_id=""
while [ -z "$run_id" ]; do
  sleep 3
  run_id=$(gh run list --workflow golden.yml --branch "$branch" --event workflow_dispatch \
    --created ">=$started_at" --limit 1 --json databaseId --jq '.[0].databaseId // empty')
done

gh run watch "$run_id" --exit-status
git pull --ff-only origin "$branch"
