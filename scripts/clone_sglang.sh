#!/bin/bash
remote_repo=$1
git_branch=$1

# if there is not sglang repo, clone it
if [ ! -d "sglang" ]; then
    git clone $remote_repo
fi

# checkout the branch
git checkout $git_branch