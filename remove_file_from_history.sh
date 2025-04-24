#!/bin/bash

# --- Configuration ---
# Provide the full path to the file within the repository you want to remove.
# Example: FILE_TO_REMOVE="credentials.json"
# Example: FILE_TO_REMOVE="src/config/secret_keys.yaml"
FILE_TO_REMOVE="assets/credentials.json" # <<< EDIT THIS LINE

# --- Safety Checks ---
if [ -z "$FILE_TO_REMOVE" ]; then
  echo "ERROR: Please edit this script and set the FILE_TO_REMOVE variable."
  exit 1
fi

if ! command -v git-filter-repo &> /dev/null; then
    echo "ERROR: git-filter-repo command could not be found."
    echo "Please install it from: https://github.com/newren/git-filter-repo"
    exit 1
fi

# Check for uncommitted changes (filter-repo requires a clean state)
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: You have uncommitted changes in your working directory or staging area."
  echo "Please commit or stash them before running this script."
  exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" == "HEAD" ]; then
  echo "ERROR: You are in a detached HEAD state. Please check out a branch first."
  exit 1
fi

echo "--------------------------------------------------------------------"
echo "WARNING: This script will rewrite the Git history of the"
echo "         CURRENT branch ('$CURRENT_BRANCH') to remove the file:"
echo "         '$FILE_TO_REMOVE'"
echo ""
echo "         This is a destructive operation. Commit hashes will change."
echo "         Make sure you have backed up your repository if needed."
echo "         (e.g., git branch backup-before-history-rewrite)"
echo "--------------------------------------------------------------------"
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo # Move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# --- Execute History Rewrite ---
echo "Running git filter-repo to remove '$FILE_TO_REMOVE' from branch '$CURRENT_BRANCH' history..."

# Use --refs HEAD to limit the rewrite primarily to the history reachable by the current branch.
# Note: filter-repo still analyzes repository-wide objects but limits the refs it updates.
# git filter-repo --path "$FILE_TO_REMOVE" --invert-paths --refs HEAD
git filter-repo --force --path "$FILE_TO_REMOVE" --invert-paths --refs HEAD

# Error check for filter-repo
if [ $? -ne 0 ]; then
  echo "ERROR: git filter-repo failed. Please check the output above."
  echo "Your history may not have been rewritten correctly."
  exit 1
fi

# --- Post-Rewrite Instructions ---
echo ""
echo "--------------------------------------------------------------------"
echo "SUCCESS: History rewriting completed for branch '$CURRENT_BRANCH'."
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "1.  Verify the history: Use 'git log --stat' or check specific commits"
echo "    (remember hashes changed!) to confirm '$FILE_TO_REMOVE' is gone."
echo "2.  Push the changes (FORCE PUSH REQUIRED):"
echo "    git push --force-with-lease origin $CURRENT_BRANCH"
echo "    (Using --force-with-lease is safer than --force)."
echo "3.  Coordinate with collaborators: Anyone else working on this branch"
echo "    will need to fetch the new history and potentially rebase their work."
echo "4.  REVOKE THE SECRET: If the removed file contained an active credential,"
echo "    revoke it immediately with the service provider!"
echo "--------------------------------------------------------------------"

exit 0