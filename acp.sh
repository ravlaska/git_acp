#!/bin/bash

#
# Script usage:
#
# 1. First run: run ' ./acp.sh --init ' to add script alias.
# 2. Just run ' acp ' command in any git repo that you want to push.
#

# ========== Colors array definition ==========
declare -A colors;
colors['ZERO']='\x1B[0m'
colors['UNDERLINE']='\x1B[4m'
colors['URL']='\033[38;5;220m'
colors['URL_ADDR']='\033[38;5;248m'
colors['ALIAS_ADDED']='\x1B[33m'
colors['LIST_OF_BRANCHES']='\x1B[38;5;63m'
colors['BRANCH_HEAD']='\x1B[38;5;30m'
colors['BRANCH_REMOTE']='\x1B[38;5;125m'
colors['SELECTED_BRANCH']='\x1B[38;5;29m'
colors['SELECTED_BRANCH_NAME']='\x1B[48;5;239m'
colors['BRANCH_INFORMATION']='\x1B[38;5;209m'
colors['BRANCH_INFO_HIGHL']='\x1B[38;5;211m'
colors['CHECKOUT']='\x1B[38;5;216m'
colors['ENTER_COMMIT']='\x1B[38;5;133m'
colors['COMMIT_INFO']='\x1B[38;5;247m'
colors['PUSHING']='\x1B[38;5;160m'
colors['PUSH_BRANCH']='\x1B[38;5;173m'

# ========== Script initialization (adding alias) ==========
if [ $# -gt 0 ]; then
    if [ "$1" == "--init" ]; then
        SDIR=$(dirname -- "$( readlink -f -- "$0"; )";)/acp.sh
        echo "alias acp='bash $SDIR && cd \$(pwd)'" >> /home/$USER/.bashrc
        echo -e "${colors['ALIAS_ADDED']}\nAlias to this script added. From now just use 'acp' command in your git repo location.${colors['ZERO']}\n"
        exit
    else
        echo "Invalid argument, use --init to initialize the script."
        exit
    fi
fi

# RET=$(git add . 2>&1)

# ========== Git add all files in directory ==========
git add .

# ========== If directory is a git repo ==========
if [ $? -eq 0 ]; then

    # ========== Repo URL ==========
    echo -e "\n${colors['URL']}${colors['UNDERLINE']}Repository URL${colors['ZERO']}: ${colors['URL_ADDR']}$(git remote get-url origin)"

    # ========== Local branches ==========
    current_branch=$(git branch --show-current)
    local_branches=($(git branch | grep -v "$current_branch"))
    items_per_column=$(((${#local_branches[@]} + 1) / 2))

    echo -e "\n${colors['LIST_OF_BRANCHES']}${colors['UNDERLINE']}List of local branches${colors['ZERO']}:${colors['BRANCH_REMOTE']}"
    printf "%b" "${colors['BRANCH_HEAD']}* $current_branch${colors['BRANCH_REMOTE']}\n"
    printf "%-50s %-50s\n" "${local_branches[@]:0:items_per_column}" "${local_branches[@]:items_per_column}"; echo -e "${colors['ZERO']}"

    # ========== Remote branches ==========
    remote_branches=($(git branch -r | sed 's|origin/||'))
    items_per_column=$(((${#remote_branches[@]} + 1) / 2))

    echo -e "\n${colors['LIST_OF_BRANCHES']}${colors['UNDERLINE']}List of remote branches${colors['ZERO']}:${colors['BRANCH_HEAD']}"
    printf "%-50s" "${remote_branches[0]}${remote_branches[1]}${remote_branches[2]}"
    echo -e "${colors['BRANCH_REMOTE']}"; printf "%-50s %-50s\n" "${remote_branches[@]:3}" "${remote_branchess[@]:items_per_column + 3}"; echo -e "${colors['ZERO']}"

    # ========== Branch selection ==========
    echo -e "\n${colors['SELECTED_BRANCH']}${colors['UNDERLINE']}Selected branch${colors['ZERO']}: ${colors['BRANCH_HEAD']}${colors['SELECTED_BRANCH_NAME']}${current_branch}${colors['ZERO']}\n"
    echo -e -n "${colors['BRANCH_INFORMATION']}Type branchname to ${colors['BRANCH_INFO_HIGHL']}[create new] ${colors['BRANCH_INFORMATION']}/${colors['BRANCH_INFO_HIGHL']} [select existing]${colors['BRANCH_INFORMATION']} branch, press ${colors['BRANCH_INFO_HIGHL']}<ENTER>${colors['BRANCH_INFORMATION']} to stay at the current branch.${colors['ZERO']}\n:"; read new_branch
    if [ -n "$new_branch" ]; then
        skip_checkout=0
        for element in "${local_branches[@]}"; do
            if [[ "$element" == "$new_branch" ]]; then
                echo -e "${colors['CHECKOUT']}"
                git checkout $new_branch
                skip_checkout=1
                break
            fi
        done
        if [[ $skip_checkout == 0 ]]; then
            echo -e "${colors['CHECKOUT']}"
            git checkout -b $new_branch
        fi
    else
        new_branch=$current_branch
    fi
    echo -e -n "\n${colors['ENTER_COMMIT']}Enter the commit message: ${colors['ZERO']}"; read commit_message
    echo -e "${colors['COMMIT_INFO']}"
    git commit -m "$commit_message"
    if [ $? -eq 0 ]; then
        git rev-parse --abbrev-ref --symbolic-full-name $new_branch@{upstream} > /dev/null
        if [ $? -eq 0 ]; then
            echo -e "\n${colors['PUSHING']}Pushing. . .${colors['ZERO']}"
            git push
        else
            echo -e "\n${colors['PUSH_BRANCH']}Branch: ${colors['BRANCH_HEAD']}${new_branch}${colors['PUSH_BRANCH']} has no upstream remote branch. \n${colors['PUSHING']}Pushing with setting the upstream. . .${colors['ZERO']}"
            git push --set-upstream origin $new_branch
        fi
    elif [ $? -eq 1 ]; then
        git rev-parse --abbrev-ref --symbolic-full-name $new_branch@{upstream} > /dev/null
        if [ $? -eq 0 ]; then
            echo -e "\n${colors['PUSHING']}Pushing previous commit. . .${colors['ZERO']}"
            git push
        else
            echo -e "\n${colors['PUSH_BRANCH']}Branch: ${colors['BRANCH_HEAD']}${new_branch}${colors['PUSH_BRANCH']} has no upstream remote branch. \n${colors['PUSHING']}Pushing previous commit with setting the remote upstream. . .${colors['ZERO']}"
            git push --set-upstream origin $new_branch
        fi
    else
        echo ''
        exit
    fi

# ========== If directory is not git repo ==========
else
    echo ''
    exit
fi
