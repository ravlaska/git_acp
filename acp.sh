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
colors['DIR_NOT_REPO']='\x1B[38;5;160m'
colors['ENTER_REPO_CLONE']='\x1B[38;5;215m'
colors['REPO_LINK']='\x1B[38;5;205m'
colors['WRONG_URL']='\x1B[38;5;160m'
colors['AZURE_REPO']='\x1B[38;5;26m'
colors['GH_REPO']=''
colors['REPO_DETECTED']='\x1B[38;5;30m'
colors['CLONE_USER']='\x1B[38;5;72m'
colors['CLONE_PASS']='\x1B[38;5;73m'

# ========== Script initialization (adding alias) ==========
if [ $# -gt 0 ]; then
    if [ "$1" == "--init" ]; then
        SDIR=$(dirname -- "$( readlink -f -- "$0"; )";)/acp.sh # taking current script location
        echo "alias acp='bash $SDIR && cd \$(pwd)'" >> /home/$USER/.bashrc # creating alias in system (.bashrc file)
        echo -e "${colors['ALIAS_ADDED']}\nAlias to this script added. From now just use 'acp' command in your git repo location.\${colors['ZERO']}\n"
        exit
    else
        echo "Invalid argument, use --init to initialize the script."
        exit
    fi
fi

# RET=$(git add . 2>&1)

# ========== Git add all files in directory ==========
git add . > /dev/null 2>&1 # trying to git add files

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
    if [ -n "$new_branch" ]; then # new_branch not empty - handle new branch creation
        skip_checkout=0
        for element in "${local_branches[@]}"; do 
            if [[ "$element" == "$new_branch" ]]; then # if entered branch exists - checkout to it
                echo -e "${colors['CHECKOUT']}"
                git checkout $new_branch
                skip_checkout=1
                break
            fi
        done
        if [[ $skip_checkout == 0 ]]; then # if entered branch does not exist - create it
            echo -e "${colors['CHECKOUT']}"
            git checkout -b $new_branch
        fi
    else
        new_branch=$current_branch # no new_branch selected - stay on current branch
    fi
    echo -e -n "\n${colors['ENTER_COMMIT']}Enter the commit message: ${colors['ZERO']}"; read commit_message
    echo -e "${colors['COMMIT_INFO']}"
    git commit -m "$commit_message" # commit changes
    if [ $? -eq 0 ]; then # if there is a new commit to push
        git rev-parse --abbrev-ref --symbolic-full-name $new_branch@{upstream} > /dev/null # checking if repo has a remote branch for current local branch
        if [ $? -eq 0 ]; then
            echo -e "\n${colors['PUSHING']}Pushing. . .${colors['ZERO']}"
            git push # pushing normally
        else
            echo -e "\n${colors['PUSH_BRANCH']}Branch: ${colors['BRANCH_HEAD']}${new_branch}${colors['PUSH_BRANCH']} has no upstream remote branch. \n${colors['PUSHING']}Pushing with setting the upstream. . .${colors['ZERO']}"
            git push --set-upstream origin $new_branch # pushing with new remote branch creation
        fi
    elif [ $? -eq 1 ]; then # if there are no new commits to push - pushing previous one
        git rev-parse --abbrev-ref --symbolic-full-name $new_branch@{upstream} > /dev/null # checking if repo has a remote branch for current local branch
        if [ $? -eq 0 ]; then
            echo -e "\n${colors['PUSHING']}Pushing previous commit. . .${colors['ZERO']}"
            git push # pushing normally
        else
            echo -e "\n${colors['PUSH_BRANCH']}Branch: ${colors['BRANCH_HEAD']}${new_branch}${colors['PUSH_BRANCH']} has no upstream remote branch. \n${colors['PUSHING']}Pushing previous commit with setting the remote upstream. . .${colors['ZERO']}"
            git push --set-upstream origin $new_branch # pushing with new remote branch creation
        fi
    else
        echo ''
        exit
    fi

# ========== If directory is not git repo ==========
else
    # Message with clone input option
    echo -en "\n${colors['DIR_NOT_REPO']}This directory is not a git repo.\n${colors['ZERO']}\n${colors['ENTER_REPO_CLONE']}Enter the ${colors['REPO_LINK']}<repo link>${colors['ENTER_REPO_CLONE']} to clone it here\n${colors['ZERO']}:${colors['URL_ADDR']}"; read repo_to_clone
    
    # ========== If none entered - exit the script ==========
    if [ -z "$repo_to_clone" ]; then
        exit
    fi
    # ========== If repo URL for cloning entered ==========
    echo -e "${colors['ZERO']}"
    # Validating repo URL v1
    export GIT_TERMINAL_PROMPT=0 # turning off terminal prompt (prevent interrupting with git pass prompt)
    check=$(git ls-remote -h $repo_to_clone 2>&1) # checking if it's a valid repository URL
    ret_check=$?
    unset GIT_TERMINAL_PROMPT # turning on terminal prompt (prevent interrupting with git pass prompt)

    # Validating repo URL v2
    if [ $ret_check -ne 0 ]; then
        # Checking if there is a password for repo
        if [[ ! "$check" == *"Password"* && ! "$check" == *"Username"* ]]; then # No password in output -> bad URL -> exit
            echo -e "${colors['WRONG_URL']}You entered wrong repository URL!"
            exit
        else # There is a password to enter -> handling password protected repo clone
            if [[ "$repo_to_clone" == *"github"* ]]; then # checking if its a github repository
                echo -e "${colors['UNDERLINE']}\x1B[38;5;127mGitHub repository${colors['ZERO']}${colors['REPO_DETECTED']} detected!${colors['ZERO']}\n"
                echo -en "${colors['CLONE_USER']}Provide username${colors['ZERO']}: ${colors['URL_ADDR']}"; read repo_user
                echo -en "${colors['CLONE_PASS']}Provide PAT token${colors['ZERO']}: ${colors['URL_ADDR']}"; read repo_patoken
                domain="${repo_to_clone#https://}"
                repo_to_clone="https://$repo_user:$repo_patoken@$domain" # adjusting repo link
            fi
            if [[ "$repo_to_clone" == *"azure"* ]]; then # checking if its an azure repository
                echo -e "${colors['UNDERLINE']}${colors['AZURE_REPO']}Azure Repos${colors['ZERO']}${colors['REPO_DETECTED']} detected!${colors['ZERO']}\n"
                if [[ "$repo_to_clone" == *"@dev.azure"* ]]; then # checking if its a link requiring username
                    echo -en "${colors['CLONE_PASS']}Provide PAT token${colors['ZERO']}: ${colors['URL_ADDR']}"; read repo_patoken
                    domain=$(echo "$repo_to_clone" | sed 's/.*@dev\.azure\.com/@dev.azure.com/')
                    repo_to_clone="https://$repo_patoken$domain" # adjusting repo link
                else
                    echo -en "${colors['CLONE_USER']}Provide username${colors['ZERO']}: ${colors['URL_ADDR']}"; read repo_user
                    echo -en "${colors['CLONE_PASS']}Provide PAT token${colors['ZERO']}: ${colors['URL_ADDR']}"; read repo_patoken
                    domain="${repo_to_clone#https://}"
                    repo_to_clone="https://$repo_user:$repo_patoken@$domain" # adjusting repo link
                fi
            fi
        fi
    fi
    # Cloning repo with adjusted link
    echo -e "${colors['URL_ADDR']}"
    git clone $repo_to_clone
    echo -e "${colors['ZERO']}"
    exit
fi
