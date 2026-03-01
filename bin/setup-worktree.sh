#!/usr/bin/env bash
set -euo pipefail

# Post-creation setup for a worktree: install dependencies and copy config.
# Run this from inside an already-created worktree directory.
# Usage: ./script/setup-worktree.sh

WORKTREE_DIR="$(git rev-parse --show-toplevel)"
# The main repo root is the commondir for worktrees
REPO_ROOT="$(git rev-parse --git-common-dir)"
REPO_ROOT="$(cd "${REPO_ROOT}" && cd .. && pwd)"

echo "Setting up worktree at: ${WORKTREE_DIR}"
echo "Main repo root: ${REPO_ROOT}"

echo "Copying .env from repo root..."
cp "${REPO_ROOT}/.env" "${WORKTREE_DIR}/.env" 2>/dev/null \
  || echo "  No .env found in repo root, skipping"

echo "Installing forge dependencies..."
forge install

echo "Installing pnpm dependencies..."
pnpm install

if [ -d "lib/mento-core" ]; then
  echo "Installing mento-core node_modules..."
  (cd lib/mento-core && npm install)

  echo "Cleaning up mento-core..."
  (cd lib/mento-core && git checkout yarn.lock && rm -f package-lock.json)
fi

echo ""
echo "Worktree setup complete!"
