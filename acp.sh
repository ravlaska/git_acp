#!/bin/bash

#
# Script usage:
#
# 1. First run: run ' ./acp.sh --init ' to add script alias.
# 2. Just run ' acp ' command in any git repo that you want to push.
#

if [ $# -gt 0 ]; then
    if [ "$1" == "--init" ]; then
        SDIR=$(dirname -- "$( readlink -f -- "$0"; )";)/acp.sh
        echo "alias acp='bash $SDIR && cd \$(pwd)'" >> /home/$USER/.bashrc
        echo -e "\x1b[33m\nAlias to this script added. From now just use 'acp' command in your git repo location.\\x1b[0m\n"
        exit
    else
        echo 'Invalid argument, use --init to initialize the script.'
        exit
    fi
fi

# RET=$(git add . 2>&1)

git add .

if [ $? -eq 0 ]; then
    echo -e '\n\x1b[35mSelected branch: \x1b[31m'$(git branch --show-current)
    echo -e "\x1b[35mType name to crete new branch, press <ENTER> to stay at the current branch.\x1b[37m"; read new_branch
    echo -e "\x1b[33m"
    if [ -n "$new_branch" ]; then
        echo -e "\x1b[33m"
        git checkout -b $new_branch
    fi
    echo -e -n '\x1b[35mEnter the commit message: \x1b[33m'; read commit_message
    echo -e '\x1b[0m'
    git commit -m "$commit_message"
    if [ $? -eq 0 ]; then
        git rev-parse --abbrev-ref --symbolic-full-name $(git branch --show-current)@{upstream} > /dev/null
        if [ $? -eq 0 ]; then
            echo -e '\n\x1b[31mPushing. . .\x1b[37m'
            git push
        else
            echo -e "\n\x1b[33mBranch: \x1b[31m$(git branch --show-current)\x1b[33m  has no upstream remote branch. \n\x1b[31mPushing with setting the remote as upstream. . .\x1b[37m"
            git push --set-upstream origin $(git branch --show-current)
        fi
    elif [ $? -eq 1 ]; then
        git rev-parse --abbrev-ref --symbolic-full-name $(git branch --show-current)@{upstream} > /dev/null
        if [ $? -eq 0 ]; then
            echo -e '\n\x1b[31mPushing previous commit. . .\x1b[37m'
            git push
        else
            echo -e "\n\x1b[33mBranch: \x1b[31m$(git branch --show-current)\x1b[33m has no upstream remote branch. \n\x1b[31mPushing previous commit with setting the remote as upstream. . .\x1b[37m"
            git push --set-upstream origin $(git branch --show-current)
        fi
    else
        echo ''
        exit
    fi
else
    echo ''
    exit
fi
