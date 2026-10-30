#!/bin/bash

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

BASE_COMMIT=d3cc73aed3a341785cd26574875da4887fed418b

# Go To Public folder
cd public

# Reset the public repo back to its root commit on every deploy,
# so the repo history always stays at exactly 2 commits:
# the root commit + the one created below.
# NOTE: this must run BEFORE `hugo`, otherwise it throws away the fresh build.
git reset --hard $BASE_COMMIT
# Drop leftovers from previous builds so the output is always clean.
git clean -fdx

# Build the project.
# if using a theme, replace with `hugo -t <YOURTHEME>`
cd ..
hugo
cd public

# Add changes to git.
git add -A

# Commit changes.
msg="rebuilding site `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi
git commit -m "$msg"

# Push source and build repos.
# Force push is required because the history is rewritten on every deploy.
git push --force origin master

# Come Back up to the Project Root
cd ..