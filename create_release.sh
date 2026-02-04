#!/bin/bash

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Usage: ./create_release.sh X.Y.Z"
  exit 1
fi

# Checks branch
BRANCH=$(git branch --show-current)
if [ "$BRANCH" == "main" ]; then
  echo "You need to be in the feature branch you want to merge"
  exit 1
fi

# Updates version file
echo "$VERSION" > VERSION
echo "Version updated to $VERSION in VERSION file"

git add VERSION
git commit -m "feat: release v$VERSION"

# generating changelog
echo "Generating changelog"
git cliff -o CHANGELOG.md
git add CHANGELOG.md
git commit -m "feat: release v$VERSION"

# Checks clean working tree
if ! git diff-index --quiet HEAD --; then
  echo "There are uncommitted changes"
  git status
  exit 1
fi

# checks if it is ok to merge
git fetch origin && \
[ -z "$(git status --porcelain)" ] || { echo "There are uncommitted changes"; exit 1; } && \
git merge-base --is-ancestor origin/main HEAD && \
echo "OK to merge" || (echo "Rebase or merge main first" && exit 1)

# Checks branch
BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "main" ]; then
  git checkout main
fi

# Updates main & merges
echo "Updating main"
git pull origin main

echo "Merging $BRANCH into main"
git merge $BRANCH

# Creates annotated tag
echo "Creating tag v$VERSION"
git tag -a "v$VERSION" -m "Release v$VERSION"

# Push branch + tag
echo "Pushing branch + tag"
git push origin main
git push origin "v$VERSION"

gh release create "v$VERSION" --notes "$(git cliff --latest)"

git cliff -o CHANGELOG.md
git add CHANGELOG.md
git commit -m "chore: update changelog"
git push origin main

echo "✅ Release v$VERSION created successfully"

