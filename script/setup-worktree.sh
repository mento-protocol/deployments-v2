#!/usr/bin/env bash
set -euo pipefail

# Setup a Claude Code worktree with forge + pnpm dependencies installed.
# Usage: ./script/setup-worktree.sh <branch-name> [base-branch]
#   branch-name: the branch to create (e.g. feat/configure-v3-prestage)
#   base-branch:  the branch to base off of (default: main)

BRANCH="${1:?Usage: $0 <branch-name> [base-branch]}"
BASE="${2:-main}"

# Derive a short worktree dir name from the branch (strip prefixes like feat/)
WORKTREE_NAME="${BRANCH##*/}"

REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKTREE_DIR="${REPO_ROOT}/.claude/worktrees/${WORKTREE_NAME}"

if [ -d "$WORKTREE_DIR" ]; then
  echo "Worktree already exists at ${WORKTREE_DIR}"
  echo "To remove it: git worktree remove ${WORKTREE_DIR}"
  exit 1
fi

echo "Creating worktree '${WORKTREE_NAME}' off '${BASE}' at ${WORKTREE_DIR}..."
git worktree add "$WORKTREE_DIR" -b "$BRANCH" "$BASE"

echo "Copying .env from repo root..."
cp "${REPO_ROOT}/.env" "${WORKTREE_DIR}/.env" 2>/dev/null \
  || echo "  No .env found in repo root, skipping"

echo "Installing forge dependencies..."
(cd "$WORKTREE_DIR" && forge install)

echo "Installing pnpm dependencies..."
(cd "$WORKTREE_DIR" && pnpm install)

echo "Installing mento-core node_modules..."
(cd "$WORKTREE_DIR/lib/mento-core" && npm install)

echo ""
echo "Worktree ready at: ${WORKTREE_DIR}"
echo "  cd ${WORKTREE_DIR}"
