#!/bin/bash

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Usage: ./create_release.sh X.Y.Z"
  exit 1
fi

# Dependency checks
if ! command -v git-cliff &> /dev/null; then
  echo "Error: git-cliff is not installed. (https://github.com/orhun/git-cliff)"
  exit 1
fi

if ! command -v gh &> /dev/null; then
  echo "Error: gh (GitHub CLI) is not installed. (https://cli.github.com/)"
  exit 1
fi

# Checks clean working tree
if ! git diff-index --quiet HEAD --; then
  echo "Error: There are uncommitted changes. Please commit or stash them first."
  git status -s
  exit 1
fi

# Ensure we are on main
BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "main" ]; then
  echo "Switching to main branch..."
  git checkout main
fi

# Fetch and check status against origin
echo "Fetching from origin..."
git fetch origin

LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u})
BASE=$(git merge-base @ @{u})

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "Branch is up-to-date with origin."
elif [ "$LOCAL" = "$BASE" ]; then
    echo "Branch is behind origin. Pulling..."
    git pull origin main
elif [ "$REMOTE" = "$BASE" ]; then
    echo "Branch is ahead of origin."
else
    echo "Branch has diverged from origin. Please rebase or merge manualy."
    exit 1
fi

# Update VERSION file
echo "$VERSION" > VERSION
echo "Updated VERSION to $VERSION"

# Generating changelog
echo "Generating changelog..."
git cliff -o CHANGELOG.md

# Commit version and changelog
git add VERSION CHANGELOG.md
git commit -m "chore: release v$VERSION"

# Creates annotated tag
echo "Tagging v$VERSION..."
git tag -a "v$VERSION" -m "Release v$VERSION"

# Push branch + tag
echo "Pushing to origin..."
git push origin main
git push origin "v$VERSION"

# Create GitHub release
echo "Creating GitHub release..."
gh release create "v$VERSION" --notes "$(git cliff --latest)"

echo "✅ Release v$VERSION created successfully"
