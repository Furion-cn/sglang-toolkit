#!/bin/bash
remote_repo=$1
git_branch=$2

# if there is not sglang repo, clone it
if [ ! -d "sglang" ]; then
    git clone -b $git_branch $remote_repo sglang
fi

# 进入目录后再checkout
cd sglang
git checkout $git_branch