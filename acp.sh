#!/bin/bash

#
# Script usage:
#
# 1. First run: run ' ./acp.sh --init ' to add script alias.
# 2. Just run ' acp ' command in any git repo that you want to push.
#

AUTO_TOKEN=1;
PASS_BASE_FILE=$(dirname -- "$( readlink -f -- "$0"; )";)/.pass_base;

# ========== Functions ==========

# checking pass for pushing
push_pass_check() {
    repo_to_clone=$(git remote get-url origin)
    domain=$repo_to_clone
    validate_repo # validating repository
    if [ $ret_check -ne 0 ]; then
        # Checking if there is a password for repo
        # No password in output -> bad URL -> exit
        if [[ ! "$check" == *"Password"* && ! "$check" == *"Username"* ]]; then 
            echo -e "${colors['WRONG_URL']}Error while checking remote branch!${colors['ZERO']}"
            exit
        # There is a password to enter -> handling password
        else
            echo -e "\nThis repo is password protected!"
            pass_prompt
            # azure check
            if [[ "$repo_to_clone" == *"dev.azure"* ]]; then
                # adjusting azure link
                if [[ "$repo_to_clone" == *"@dev.azure"* ]]; then
                    domain=$(echo "$repo_to_clone" | sed 's/.*@dev\.azure\.com/@dev.azure.com/') # extracting domain name
                else
                    domain="${repo_to_clone#https://}" # extracting domain name
                    domain="@$repo_to_clone"
                fi
                check_pass $domain
                if [ -n "$existing_pass" ]; then
                        repo_to_clone="https://$existing_pass$domain" # adjusting repo link
                        validate_repo # check if password is ok
                        if [ $ret_check -ne 0 ]; then
                            echo -en "${colors['ERROR_TOKEN']}Saved token is not working.${colors['ZERO']}"
                            create_and_validate_azure
                        fi
                    else
                        echo -en "${colors['ERROR_TOKEN']}Entered address does not exist in ${colors['PASSBASE']}Pass-base${colors['ERROR_TOKEN']} file.${colors['ZERO']}"
                        create_and_validate_azure
                    fi
            fi # github check
            if [[ "$repo_to_clone" == *"github"* ]]; then
                domain="${repo_to_clone#https://}" # extracting domain name
                rdomain=${domain%.git} # remove .git from end of string
                domain="@$domain" # adjusting domain name
                check_pass $domain
                if [ -n "$existing_pass" ]; then
                    repo_to_clone="https://$existing_pass$domain" # adjusting repo link
                    validate_repo # check if password is ok
                    if [ $ret_check -ne 0 ]; then
                        echo -en "${colors['ERROR_TOKEN']}Saved token is not working.${colors['ZERO']}"
                        echo $check
                        create_and_validate_github
                    fi
                else
                    echo -en "${colors['ERROR_TOKEN']}Entered address does not exist in ${colors['PASSBASE']}Pass-base${colors['ERROR_TOKEN']} file.${colors['ZERO']}"
                    create_and_validate_github
                fi
            fi
        fi
    fi
}

# validating repository
validate_repo() {
    export GIT_TERMINAL_PROMPT=0 # turning off terminal prompt (prevent interrupting with git pass prompt)
    check=$(git ls-remote -h $repo_to_clone 2>&1) # checking if it's a valid repository URL
    ret_check=$?
    unset GIT_TERMINAL_PROMPT # turning on terminal prompt (prevent interrupting with git pass prompt)
}

# checking if pass-base file exists, if not create new one
check_passbase_file() {
    # checking if the file exists
    if [ ! -f "$PASS_BASE_FILE" ]; then
        echo -e "${colors['CHECK_PASSBASE']}\nNo Pass-Base file detected.\n${colors['CREATE_PASSBASE']}Creating new one. . .${colors['ZERO']}"
        while true; do
        echo -en "\n\n${colors['CREATE_PASSWORD']}Create password for the Pass-Base file: "; read -s pbasepass
        echo -en "\n${colors['CREATE_PASSWORD']}Repeat password: "; read -s pbasepass_check
        echo -e "\n${colors['ZERO']}"
        if [ "$pbasepass" == "$pbasepass_check" ]; then
            encrypt_pass "Pass-Base File"
            if [ $? -eq 0 ]; then
                echo -e "${colors['PASSWORD_CREATED']}The Pass-base file created.\n${colors['RUN_ACP_AGAIN']}Run acp once again to clone/push repos.${colors['ZERO']}\n"
                exit
            else
                echo -e "${colors['CHECK_PASSBASE']}Error: Pass-base file not created!${colors['ZERO']}"
            fi
            sleep 1
            exit
        else
            echo -e "${colors['CHECK_PASSBASE']}The passwords are not identical!${colors['ZERO']}"
            sleep 1
        fi
        done
    fi
}

# encrypting base and saving to file
encrypt_pass() {
    enpbasepass=$(echo "$1" | openssl enc -aes-256-cbc -a -salt -pbkdf2 -pass pass:"$pbasepass")
    echo $enpbasepass > $PASS_BASE_FILE
}

# decrypting pass-base file
decrypt_pass() {
    depbasepass=$(cat "$PASS_BASE_FILE" | openssl enc -d -aes-256-cbc -a -pbkdf2 -pass pass:"$pbasepass")
    if [ $? -ne 0 ]; then
        echo -e "${colors['ERROR_TOKEN']}Bad password for Pass-Base file!!!${colors['ZERO']}"
        exit
    fi
}

# creating new entry in pass-base for azure
create_pass_azure() {
    decrypt_pass
    echo -en "\n${colors['PROVIDE_TOKEN']}Provide ${colors['PROVIDE_TOKEN_HIGH']}token${colors['ZERO']}: ${colors['URL_ADDR']}"; read -s new_pass
    echo -e "\n${colors['ZERO']}"
    updated_pbase="$depbasepass\n($1) : [$new_pass]"
    encrypt_pass "$updated_pbase"   
}

# create pass and validate it azure
create_and_validate_azure() {
    create_pass_azure $domain
    repo_to_clone="https://$new_pass$domain"
    validate_repo # check if password is ok
    if [ $ret_check -ne 0 ]; then
        echo -en "${colors['ERROR_TOKEN']}Token is not working.${colors['ZERO']}\n"
        delete_pass $domain
        exit
    fi
    repo_to_clone="https://$new_pass$domain" # adjusting repo link
}

# creating new entry in pass-base for github
create_pass_gh() {
    decrypt_pass
    echo -en "\n${colors['PROVIDE_TOKEN']}Provide ${colors['PROVIDE_TOKEN_HIGH']}username${colors['ZERO']}: ${colors['URL_ADDR']}"; read new_user
    echo -en "${colors['PROVIDE_TOKEN']}Provide ${colors['PROVIDE_TOKEN_HIGH']}token${colors['ZERO']}: ${colors['URL_ADDR']}"; read -s new_pass
    new_pass_gh="$new_user:$new_pass"
    echo -e "\n${colors['ZERO']}"
    updated_pbase="$depbasepass\n($1) : [$new_pass_gh]"
    encrypt_pass "$updated_pbase"
}

# create pass and validate it github
create_and_validate_github() {
    create_pass_gh $domain
    repo_to_clone="https://$new_pass_gh$domain"
    validate_repo # check if password is ok
    if [ $ret_check -ne 0 ]; then
        echo -en "${colors['ERROR_TOKEN']}Token is not working.${colors['ZERO']}\n"
        delete_pass $domain
        exit
    fi
    repo_to_clone="https://$new_pass_gh$domain" # adjusting repo link
}

# remove specific record from pass-base
delete_pass() {
    decrypt_pass
    del_adjusted_search_domain=$(echo "$1" | sed 's/[./]/\\&/g')
    depbasepass=$(echo -e "$depbasepass" | grep -v $adjusted_search_domain)
    encrypt_pass "$depbasepass"
}

# checking if password for specified address exists if so use it
check_pass() {
    decrypt_pass
    adjusted_search_domain=$(echo "$1" | sed 's/[./]/\\&/g')
    existing_pass=$(echo -e "$depbasepass" | grep $adjusted_search_domain | awk -F'[][]' '{print $2}')
}

# prompting for password
pass_prompt() {
    echo -en "${colors['PROVIDE_PASS']}Please provide password for the ${colors['PASSBASE']}Pass-base${colors['PROVIDE_PASS']} file: ${colors['ZERO']}"; read -s pbasepass
    echo -e "\n"
}

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
colors['GH_REPO']='\x1B[38;5;127m'
colors['REPO_DETECTED']='\x1B[38;5;30m'
colors['CLONE_USER']='\x1B[38;5;72m'
colors['CLONE_PASS']='\x1B[38;5;73m'
colors['CHECK_PASSBASE']='\033[38;5;161m\n'
colors['CREATE_PASSBASE']='\033[38;5;220m'
colors['CREATE_PASSWORD']='\033[38;5;68m'
colors['PASSWORD_CREATED']='\033[38;5;29m'
colors['RUN_ACP_AGAIN']='\033[38;5;215m'
colors['PROVIDE_PASS']='\033[38;5;6m'
colors['PASSBASE']='\033[38;5;72m'
colors['PROVIDE_TOKEN']='\033[38;5;215m'
colors['PROVIDE_TOKEN_HIGH']='\033[38;5;211m'
colors['ERROR_TOKEN']='\033[38;5;196m'

# ========== Script initialization (adding alias) ==========
if [ $# -gt 0 ]; then
    if [ "$1" == "--init" ]; then
        SDIR=$(dirname -- "$( readlink -f -- "$0"; )";)/acp.sh # taking current script location
        echo "alias acp='bash $SDIR && cd \$(pwd)'" >> /home/$USER/.bashrc # creating alias in system (.bashrc file)
        echo -e "${colors['ALIAS_ADDED']}\nAlias to this script added. From now just use 'acp' command in your git repo location.${colors['ZERO']}\n"
        sleep 2
        while true; do
        echo -en "Do you want to store PAT tokens automatically? (y/n)"; read auto_token_cfg
        if [ "${auto_token_cfg,,}" == "y" ]; then
            sed -i 's/AUTO_TOKEN=1/AUTO_TOKEN=1/' "$0"
            echo -e "Automatic PAT token storing turned ON.\nPass-Base file will be created in next script run.\nIf you have old '.pass_base' file you can paste it here."
            sleep 2
            break
        elif [ "${auto_token_cfg,,}" == "n" ]; then
            echo -e "Automatic PAT token storing turned OFF."
            sleep 2
            break
        else
            echo -e "Select a valid option."
            sleep 2
        fi
        done
        exit
    else
        echo "Invalid argument, use --init to initialize the script."
        exit
    fi
fi

if [ "$AUTO_TOKEN" -eq 1 ]; then
    check_passbase_file
fi

# RET=$(git add . 2>&1)

# ========== Git add all files in directory ==========
git add . > /dev/null 2>&1 # trying to git add files

# ============================== If directory is a git repo ==============================
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
    push_pass_check # check if there is a password to push repo
    if [ $? -eq 0 ]; then # if there is a new commit to push
        git rev-parse --abbrev-ref --symbolic-full-name $new_branch@{upstream} > /dev/null # checking if repo has a remote branch for current local branch
        if [ $? -eq 0 ]; then
            echo -e "\n${colors['PUSHING']}Pushing. . .${colors['ZERO']}"
            git push $repo_to_clone # pushing normally
        else
            echo -e "\n${colors['PUSH_BRANCH']}Branch: ${colors['BRANCH_HEAD']}${new_branch}${colors['PUSH_BRANCH']} has no upstream remote branch. \n${colors['PUSHING']}Pushing with setting the upstream. . .${colors['ZERO']}"
            git push -u $repo_to_clone $new_branch # pushing with new remote branch creation
        fi
    elif [ $? -eq 1 ]; then # if there are no new commits to push - pushing previous one
        git rev-parse --abbrev-ref --symbolic-full-name $new_branch@{upstream} > /dev/null # checking if repo has a remote branch for current local branch
        if [ $? -eq 0 ]; then
            echo -e "\n${colors['PUSHING']}Pushing previous commit. . .${colors['ZERO']}"
            git push $repo_to_clone # pushing normally
        else
            echo -e "\n${colors['PUSH_BRANCH']}Branch: ${colors['BRANCH_HEAD']}${new_branch}${colors['PUSH_BRANCH']} has no upstream remote branch. \n${colors['PUSHING']}Pushing previous commit with setting the remote upstream. . .${colors['ZERO']}"
            git push -u $repo_to_clone $new_branch # pushing with new remote branch creation
        fi
    else
        echo ''
        exit
    fi

# ============================== If directory is not git repo ==============================
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
    validate_repo

    # Validating repo URL v2
    if [ $ret_check -ne 0 ]; then
        # Checking if there is a password for repo

        # No password in output -> bad URL -> exit
        if [[ ! "$check" == *"Password"* && ! "$check" == *"Username"* ]]; then 
            echo -e "${colors['WRONG_URL']}You entered wrong repository URL!${colors['ZERO']}"
            exit
        
        # There is a password to enter -> handling password protected repo clone
        else 
            # checking if its a GITHUB repository
            if [[ "$repo_to_clone" == *"github"* ]]; then
                echo -e "${colors['UNDERLINE']}${colors['GH_REPO']}GitHub repository${colors['ZERO']}${colors['REPO_DETECTED']} detected!${colors['ZERO']}\n"
                domain="${repo_to_clone#https://}" # extracting domain name
                domain=${domain%.git} # remove .git from end of string
                domain="@$domain" # adjusting domain name

                # if AUTO_TOKEN ON
                if [ $AUTO_TOKEN -eq 1 ]; then
                    pass_prompt # prompting for password to pass-base
                    check_pass $domain # checking if token for that domain exists
                    if [ -n "$existing_pass" ]; then
                        repo_to_clone="https://$existing_pass$domain" # adjusting repo link
                        validate_repo # check if password is ok
                        if [ $ret_check -ne 0 ]; then
                            echo -en "${colors['ERROR_TOKEN']}Saved token is not working.${colors['ZERO']}"
                            create_and_validate_github
                        fi
                    else
                        echo -en "${colors['ERROR_TOKEN']}Entered address does not exist in ${colors['PASSBASE']}Pass-base${colors['ERROR_TOKEN']} file.${colors['ZERO']}"
                        create_and_validate_github
                    fi
                else
                # if AUTO_TOKEN OFF
                    echo -en "${colors['CLONE_USER']}Provide username${colors['ZERO']}: ${colors['URL_ADDR']}"; read repo_user # prompting for username
                    echo -en "${colors['CLONE_PASS']}Provide PAT token${colors['ZERO']}: ${colors['URL_ADDR']}"; read -s repo_patoken # prompting for password
                    repo_to_clone="https://$repo_user:$repo_patoken$domain" # adjusting repo link
                fi
            fi

            # checking if its an AZURE repository
            if [[ "$repo_to_clone" == *"dev.azure"* ]]; then
                echo -e "${colors['UNDERLINE']}${colors['AZURE_REPO']}Azure Repos${colors['ZERO']}${colors['REPO_DETECTED']} detected!${colors['ZERO']}\n"

                # adjusting azure link
                if [[ "$repo_to_clone" == *"@dev.azure"* ]]; then
                    domain=$(echo "$repo_to_clone" | sed 's/.*@dev\.azure\.com/@dev.azure.com/') # extracting domain name
                else
                    domain="${repo_to_clone#https://}" # extracting domain name
                    domain="@$domain"
                fi

                # if AUTO_TOKEN ON
                if [ $AUTO_TOKEN -eq 1 ]; then
                    pass_prompt # prompting for password to pass-base
                    pat_domain=$(echo "$domain" | cut -d'/' -f1-3)
                    check_pass $pat_domain # checking if token for that domain exists
                    if [ -n "$existing_pass" ]; then
                        repo_to_clone="https://$existing_pass$domain" # adjusting repo link
                        validate_repo # check if password is ok
                        if [ $ret_check -ne 0 ]; then
                            echo -en "${colors['ERROR_TOKEN']}Saved token is not working.${colors['ZERO']}"
                            create_and_validate_azure
                        fi
                    else
                        echo -en "${colors['ERROR_TOKEN']}Entered address does not exist in ${colors['PASSBASE']}Pass-base${colors['ERROR_TOKEN']} file.${colors['ZERO']}"
                        create_and_validate_azure
                    fi
                else
                # if AUTO_TOKEN OFF
                    echo -en "${colors['CLONE_PASS']}Provide PAT token${colors['ZERO']}: ${colors['URL_ADDR']}"; read repo_patoken
                    repo_to_clone="https://$repo_patoken$domain" # adjusting repo link
                fi
            fi
        fi # if there is not password for repo just clone repo below
    fi
    # Final cloning repo with adjusted link
    echo -e "${colors['URL_ADDR']}"
    git clone $repo_to_clone
    echo -e "${colors['ZERO']}"
    exit
fi
