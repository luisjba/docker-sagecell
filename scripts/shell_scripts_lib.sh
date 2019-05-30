#!/bin/bash
# Functions to use in deploy environment intended to be used in docker container
# for automatically check a repository, update the latest code and put it in
# production.
# MAINTAINER: Jose Luis Bracamonte Amavizca. <luisjba@gmail.com>
# Date Created: 2019-04-24
# Las Updated: 2019-05-23

function current_date(){
    echo $(date +"%Y-%m-%d %T")
}

# <CRONJOB Fucntions>

function cronjob_setup_job_in_crontab(){
    # Continuous Integration Delivery - Configuration of the cron job file and installed the crontab file
    # arg1: The cron job file
    # arg2: The cron job script file
    # arg3: The cron job file to write the log
    local cron_job_file=$1
    local cron_job_script=$2
    local cron_job_log=$3
    # Drop 3 arguments
    shift; shift; shift;
    # Having shifted twice, the rest is now the time parameter
    local cron_job_time=$@
    [ ! -n "$cron_job_time" ] && cron_job_time="*/1 * * * *"
    if [ -n "$cron_job_file" ]; then
        if [ -f $cron_job_file ]; then
            if [ -n "$cron_job_script" ]; then
                if [ -f $cron_job_script ]; then
                    if [ -n "$cron_job_log" ]; then
                        sed -i "s/{CRON_JOB_TIME}/$(echo "$cron_job_time" | sed "s/\//\\\\\//g")/g" $cron_job_file
                        sed -i "s/{CRON_JOB_SCRIPT}/$(echo "$cron_job_script" | sed "s/\//\\\\\//g")/g" $cron_job_file
                        sed -i "s/{CRON_JOB_LOG}/$(echo "$cron_job_log" | sed "s/\//\\\\\//g")/g" $cron_job_file
                        [ ! -f $cron_job_log ] && touch $cron_job_log
                        echo "Installing crontab file: $cron_job_file"
                        crontab $cron_job_file
                        return $?
                    fi
                    echo "Missing parameter, call this function as $0 $1 $2 cron_job_log [cron_job_time]"
                    return 5
                fi
                echo "The cron job script file $cron_job_script not exists"
                return 4
            fi
            echo "Missing parameter, call this function as $0 $1 cron_job_script cron_job_log [cron_job_time]"
            return 3
        fi
        echo "The cron job file file $cron_job_file not exists"
        return 2
    fi
    echo "Missing parameter, call this function as $0 cron_job_file cron_job_script cron_job_log [cron_job_time]"
    return 1
}
# </CRONJOB Fucntions>

# <SSH Fucntions>
function setup_ssh_agent_auth_sock(){
    # Find the pid of ssh-agent and set the SSH_AUTH_SOCK
    SSH_AGENT_PID=$(pgrep ssh-agent)
    if [ ! -z $SSH_AGENT_PID ] && [ $SSH_AGENT_PID -gt 0 ]; then
        export SSH_AGENT_PID=$SSH_AGENT_PID
        for sock_item in $(find /tmp -path "*ssh*" -type s -iname "agent.$(($SSH_AGENT_PID-1))"); do
            export SSH_AUTH_SOCK=$sock_item
            # check if connectopm to the agent is not established to kill and remove the file
            if [ $(ssh-add -l &> /dev/null; echo $?) -gt 1 ]; then
                #The exit values for ssh-add -l
                #   0 : OK
                #   1 : The agent has no identities.
                #   2 : Error connecting to agent: No such file or directory
                echo "Killing the ssh-agent on $sock_item "
                ssh-agent -k
                continue
            else
                break
            fi
        done
        if [ -n "$SSH_AUTH_SOCK" ]; then
            return 0
        fi
        echo "ssh-agent auth sock file not found"
        return 2
    fi
    echo "ssh-agent is not running"
    return 1
}

function ssh_agent_configure(){
    # arg1: key_file
    # Find the PID of the ssh agent
    local key_file=$1
    setup_ssh_agent_auth_sock
    if [ $? -gt 0 ]; then
        echo "Starting ssh-agent"
        eval `ssh-agent`
    fi
    if [ -f $key_file ]; then
        local ssh_fingerprint=$(ssh-keygen -l -f $key_file | awk '{print $2}')
        if [ ! -z  "$ssh_fingerprint" ] && [ -z "$(ssh-add -l | grep "$ssh_fingerprint")" ]; then
            #register the key into ssh-agent
            ssh-add $key_file
            echo "Added the key: $key_file to ssh-agent with the finrgerprint: $ssh_fingerprint"
        fi
        return 0
    fi
    echo "The key file  $key_file does not exists"
    return 1
}

function generate_ssh_keys(){
    # arg1: The key path to install the key file
    # arg2: Optional The key file name
    # arg3: Optional The passphrase
    local key_path=$1
    local key_file_name=$([ -n "$2" ] && echo "$2" || echo "id_rsa")
    local key_passphrase=$([ -n "$3" ] && echo "$3" || echo "")
    if [ -n "$key_path" ]; then
        local key_file=${key_path}/${key_file_name}
        if [ ! -f $key_file ]; then
            if [ ! -d $key_path ]; then
                mkdir $key_path
                echo "Created the the dir $key_path to install the new rsa key"
            fi
            ssh-keygen -t rsa -f $key_file -P "$key_passphrase" -q
            echo "successfull generated the private key: $key_file with public key: $key_file.pub"
            return 0
        fi
        echo "The kery file $key_file already exists"
        return 2
    fi
    echo "Missing parameter, call this function as $0 key_path [key_file_name [key_passphrase]]"
    return 1
}

function ssh_add_know_host(){
    # arg1: the host to add
    # arg2: the user home directory
    local host=$1
    local user_home_dir=$2
    if [ -n "$host" ]; then
        if [ -n "$user_home_dir" ]; then
            if [ -d $user_home_dir ]; then
                [ ! -d ${user_home_dir}/.ssh ] && mkdir ${user_home_dir}/.ssh
                [ ! -f ${user_home_dir}/.ssh/known_hosts ] && touch ${user_home_dir}/.ssh/known_hosts
                if [ -z "$(ssh-keygen -F $host)" ]; then
                    ssh-keyscan -H $host > $user_home_dir/.ssh/known_hosts 2> /dev/null
                    echo "Host $host added to the know_hosts in $user_home_dir/.ssh/known_hosts"
                    return 0
                fi
                echo "The host identity already exists in the know_hosts file $user_home_dir/.ssh/known_hosts"
                return 4
            fi
            echo "Invalid user home dir: $user_home_dir"
            return 3
        fi
        echo "Missing parameter, call this function as $0 $1 user_home_dir"
        return 2
    fi
    echo "Missing parameter, call this function as $0 host user_home_dir"
    return 1
}

function ssh_permission_status(){
    # arg1: The ssh host to connec to with publickey method
    # stdout: GRANTED|DENIED
    local host=$1
    if [ -n "$host" ]; then
        ssh -v -o PreferredAuthentications=publickey -o BatchMode=yes -o ConnectTimeout=10 $host /bin/true &> /dev/null
        local ret_code=$?
        [ $ret_code -eq 0 ] && echo "GRANTED" || echo "DENIED"
        return $ret_code
    fi
    echo "Missing parameter, call this function as $0 host"
    return 1
}

function ssh_psswordless_configure_localhost(){
    # arg1: The user home dir
    # arg2: Optional The key file name
    local user_home=$1
    local key_file_name=$([ -n "$2" ] && echo "$2" || echo "id_rsa")
    if [ -n "$user_home" ]; then
        if [ -d $user_home ]; then
            local key_file=${user_home}/.ssh/$key_file_name
            if [ $(ssh-add -l &> /dev/null; echo $?) -gt 0 ]; then
                generate_ssh_keys ${user_home}/.ssh $key_file_name
                ssh_agent_configure $key_file
                ssh_add_know_host localhost ${user_home}
                cat ${key_file}.pub > ${user_home}/.ssh/authorized_keys \
                && echo "Sucefull configure ssh passwordless to localhost"
                return $?
                #ssh-copy-id -i ${key_file}.pub localhost
            fi
            echo "ssh passwordless already configured"
            return 0
        fi
        echo "$user_home is not valid directory"
        return 2
    fi
    echo "Missing parameter, call this function as $0 user_home [key_file_name]"
    return 1
}

# </SSH Fucntions>

# <File Fucntions>
function file_register_environment_variables(){
    # arg1: The target dir to save the exported variables
    local target_dir_profile=$1
    if [ -n "$target_dir_profile" ]; then
        eval $(printenv | sed -n "s/^\([^=]\+\)=\(.*\)$/export \1=\2/p" | sed 's/"/\\\"/g' | sed '/=/s//="/' | sed 's/$/"/' >> $target_dir_profile)
        echo "successfully registered env variables into $target_dir_profile"
        return 0
    fi
    echo "Missing parameter, call this function as $0 target_dir_profile"
    return 1
}

function file_content_string_replace(){
    # arg1: The match pattern
    # arg2: The replace value
    # arg3: The target file
    # arg4: Optional start line
    # arg5: Optional end line
    local match_pattern=$1
    local replace_value=$(echo "$2" | sed "s/\//\\\\\//g")
    local target_file=$3
    local start_line=$([ -n "$4" ] && echo "$4" || echo "1")
    local end_line=$([ -n "$5" ] && echo "$5" || echo "\$")
    if [ -f $target_file ]; then
        sed -i "${start_line},$end_line s/${match_pattern}/${replace_value}/g" $target_file
        return $?
    fi
    echo "Invalid file $target_file"
    return 1
}

function file_content_var_exists(){
    # arg1: The var name
    # arg2: The target file
    local var_name=$1
    local target_file=$2
    if [ -n "$var_name" ]; then
        if [ -f $target_file ]; then
            grep "^$var_name=\(.\+\)" $target_file
            return $?
        fi
        echo "Invalid target file $target_file"
        return 2
    fi
    echo "Missing parameter, call this function as $0 var_name target_file"
    return 1
}

function file_content_get_var_value(){
    # arg1: The var name
    # arg2: The target file
    # arg3: Optional delimiter character, default '='
    local var_name=$1
    local target_file=$2
    local delimiter_char=$([ -n "$3" ] && echo "$3" || echo "=")
    if [ -n "$var_name" ]; then
        if [ -f $target_file ]; then
            grep "^$var_name=\(.\+\)" $target_file | head -n 1 | cut -d"$delimiter_char" -f2
            return 0
        fi
        echo "Invalid target file $target_file"
        return 2
    fi
    echo "Missing parameter, call this function as $0 var_name target_file [delimiter_char]"
    return 1
}

function file_content_update_var_value(){
    # arg1: The var name
    # arg2: The var value
    # arg3: The target file
    local var_name=$1
    local var_value=$2
    local target_file=$3
    if [ -n "$var_name" ]; then
        if [ -f $target_file ]; then
            sed -i "s/^$var_name=\(.*\)$/$var_name=\"$var_value\"/g" $target_file
            return 0
        fi
        echo "Invalid target file $target_file"
        return 2
    fi
    echo "Missing parameter, call this function as $0 var_name var_value target_file"
    return 1
}
# </File Fucntions>

# <Git Fucntions>
function git_remote_repo_exists(){
    # arg1: The git remote address
    local git_remote_address=$1
    if [ -n "$git_remote_address" ]; then
        local host=$(awk -F/ '{print $3}' <<< $git_remote_address)
        if [ -n "$host" ]; then
            ssh_permission_status $host &> /dev/null
            if [ $? -eq 0 ]; then
                local remote_repo="${git_remote_address#*://$host/}"
                if [ -n "$remote_repo" ]; then
                    # nex line, becuase is slow and inefficient an cause ssh to get down when
                    # multiple calls are requested
                    #> git ls-remote $git_remote_address &> /dev/null;
                    # The Eficient way using ssh
                    ssh -o PreferredAuthentications=publickey -o BatchMode=yes -o ConnectTimeout=10 $host "[ -d $remote_repo ]" &> /dev/null
                    return $?
                fi
                echo "Missing repository part in $git_remote_address"
                return 4
            fi
            echo "ssh permission denied to $host"
            return 3
        fi
        echo "Host not found in $git_remote_address"
        return 2
    fi
    echo "Missing the parameter git remote address, call this function as $0 git_remote_address"
    return 1
}

function git_pull_repo(){
    # arg1: The repository directory
    # arg2: Optional branch name, default is master
    local repo_dir=$1
    local repo_branch=$([ -n "$2" ] && echo "$2" || echo "master")
    if [ -d $repo_dir ]; then
        cd $repo_dir
        local fetch_output=$(git fetch origin -v --dry-run 2>&1 | grep "$repo_branch * -> origin/$repo_branch$")
        if [ -n "$fetch_output" ]; then
            if [ $(echo $fetch_output | grep "up to date" &> /dev/null ;echo $?) -gt 0 ]; then
                git pull origin $repo_branch 2>&1
                if [ $(git branch -l | grep "\* $repo_branch$" &> /dev/null ;echo $?) -gt 0 ]; then
                    git checkout $repo_branch 2>&1
                fi
                return 0
            fi
            #is up to date
            echo $fetch_output
            return 3
        fi
        echo "The remote branch origin/$repo_branch was not found in the remote repository"
        return 2
    fi
    echo "Invalid repository directory $repo_dir"
    return 1
}

function git_init_with_remote(){
    # arg1: The repository directory
    # arg2: The git remote address
    # arg3: Optional branch name, default is master
    local repo_dir=$1
    local git_remote_address=$2
    local repo_branch=$([ -n "$3" ] && echo "$3" || echo "master")
    if [ -d $repo_dir ]; then
        if [ -n "$git_remote_address" ]; then
            git_remote_repo_exists $git_remote_address
            if [ $? -eq 0 ]; then
                cd $repo_dir
                git init  2>&1
                git remote add origin $git_remote_address  2>&1
                git_pull_repo $repo_dir $repo_branch
                if [ $? -eq 0 ]; then
                    return 0
                fi
                echo "Pull remote repository $git_remote_address failed in $repo_dir"
                return 4
            fi
            echo "Invalid remote repository address $git_remote_address"
            return 3
        fi
        echo "Missing parameter, call this function as $0 $1 git_remote_address"
        return 2
    fi
    echo "Invalid repository directory $repo_dir"
    return 1
}
# </Git Fucntions>

# <Composer Fucntions>
function composer_download_dependencies(){
    # arg1: The repository directory
    local repo_dir=$1
    if [ -d $repo_dir ]; then
        if [ $(command -v composer &> /dev/null ;echo $?) -eq 0 ]; then
            if [ -f $repo_dir/composer.json ]; then
                cd $repo_dir
                if [ ! -d vendor ] || [ $(ls vendor | wc -l) -lt 2 ] ; then
                    composer install 2>&1
                    return 0
                fi
                composer clear-cache  2>&1
                composer update  2>&1
                return 0
            fi
            echo "Seems not to be a laravel app, culd not find a composer.json file in $repo_dir"
            return 3
        fi
        echo "The composer package is not accesible or is not installed"
        return 2
    fi
    echo "Invalid repository directory $repo_dir"
    return 1
}
# </Composer Fucntions>

# <Deployment Fucntions>
function laravel_app_deploy_to_production(){
    # arg1: The repository directory
    # arg2: The home directory for deployment
    # arg3: The apache port to run
    # arg4: Optional apache document root, default  /var/www/html
    # arg5: Optional apache run user, default www-data
    local repo_dir=$1
    local deployment_home=$2
    local apache_port=$3
    local apache_document_root=$([ -n "$4" ] && echo "$4" || echo "/var/www/html")
    local apache_run_user=$([ -n "$5" ] && echo "$5" || echo "www-data")
    if [ -d $repo_dir ]; then
        if [ -d $deployment_home ]; then
            if [ -n "$apache_port" ]; then
                # local target_deploy_dir="$deployment_home/$(date +"%Y%m%d_%H%M")"
                # if [ -d $target_deploy_dir ]; then
                #     # Delete the directory and the content
                #     rm -rf $target_deploy_dir
                # fi
                # cp $repo_dir $target_deploy_dir
                rsync -arh -c -t -v -C \
                --delete --delete-after \
                --update --dry-run \
                --exclude "/.ssh" \
                --exclude ".git" \
                --exclude ".gitignore" \
                --exclude ".gitattributes" \
                --exclude "/.env" \
                --exclude "/storage/app/public" \
                --exclude "/storage/framework" \
                --exclude "/storage/logs" \
                ${repo_dir}/ ${deployment_home}/
                [ -d ${deployment_home}/.ssh ] && rm -rf ${deployment_home}/.ssh
                [ -d ${deployment_home}/.git ] && rm -rf ${deployment_home}/.git
                [ -f ${deployment_home}/.gitignore ] && rm ${deployment_home}/.gitignore
                [ -f ${deployment_home}/.gitattributes ] && rm ${deployment_home}/.gitattributes
                [ ! -d ${deployment_home}/storage ] && mkdir ${deployment_home}/storage
                [ ! -d ${deployment_home}/storage/framework ] && mkdir ${deployment_home}/storage/framework
                [ ! -d ${deployment_home}/storage/framework/sessions ] && mkdir ${deployment_home}/storage/framework/sessions
                [ ! -d ${deployment_home}/storage/framework/views ] && mkdir ${deployment_home}/storage/framework/views
                [ ! -d ${deployment_home}/storage/framework/cache ] && mkdir ${deployment_home}/storage/framework/cache
                # chmod -R 775 ${deployment_home}/storage
                # [ -d ${deployment_home}/bootstrap/cache ] && chmod 775 ${deployment_home}/bootstrap/cache
                if [ $(command -v php &> /dev/null; echo $?) -eq 0 ]; then
                    if [ -f ${deployment_home}/artisan ]; then
                        cd ${deployment_home}
                        if [ ! -f ${deployment_home}/.env ] && [ -f ${deployment_home}/.env.example ]; then
                            cp ${deployment_home}/.env.example ${deployment_home}/.env
                            echo "WARNING: Created the file ${deployment_home}/.env, but is missconfigured"
                        fi
                        [ -f ${deployment_home}/.env ] && [ -f ${deployment_home}/.env.example ] && rm ${deployment_home}/.env.example
                        if [ -f ${deployment_home}/.env ]; then
                            if [ -z $(grep "^APP_KEY=\(.\+\)" ${deployment_home}/.env | head -n 1) ]; then
                                php artisan key:generate 2>&1
                            fi
                            local trusted_proxies="$(hostname -i | cut -d"." -f1,2,3).0/24"
                            if [ -z $(grep "^APP_TRUSTED_PROXIES=\(.\+\)" ${deployment_home}/.env | head -n 1) ]; then
                                echo "APP_TRUSTED_PROXIES=$trusted_proxies" >> ${deployment_home}/.env
                            fi
                            local current_trusted_proxies=$(grep "^APP_TRUSTED_PROXIES=\(.\+\)" ${deployment_home}/.env | head -n 1 | cut -d"=" -f2)
                            if [ -z $(echo $current_trusted_proxies | grep "$trusted_proxies") ]; then
                                if [ -n "$current_trusted_proxies" ]; then
                                    trusted_proxies="$current_trusted_proxies,$trusted_proxies"
                                fi
                                sed -i "s/^APP_TRUSTED_PROXIES=\(.*\)$/APP_TRUSTED_PROXIES=$(echo "$trusted_proxies" | sed "s/\//\\\\\//g")/g" ${deployment_home}/.env
                            fi
                        fi
                        if [ ! -d storage/app/public ]; then
                            php artisan storage:link 2>&1
                        fi
                        php artisan auth:clear-resets
                        php artisan cache:clear 2>&1
                        php artisan config:clear 2>&1
                        # php artisan debugbar:clear 2>&1
                        php artisan route:clear 2>&1
                        php artisan view:clear 2>&1
                        apache_configure $deployment_home $apache_port $apache_document_root $apache_run_user
                        if [ $? -eq 0 ]; then
                            echo "Sucessfull deployed laravel app in $deployment_home"
                            return 0
                        fi
                        echo "Failed configure apache for this laravel app: $deployment_home"
                        return 6
                    fi
                    echo "Artisan is not installed in this laravel app: $deployment_home"
                    return 5
                fi
                echo "The php package is not accesible or is not installed"
                return 4
            fi
            echo "Missing parameter, call this function as $0 $1 $3 apache_port [ apache_document_root apache_run_user ]"
            return 3
        fi
        echo "Invalid deployment home direcotry $deployment_home"
        return 2
    fi
    echo "Invalid repository directory $repo_dir"
    return 1
}

function dir_get_latest_deployed_dir(){
    # arg1: The target dir to list
    local target_dir=$1
    if [ -d $target_dir ]; then
        find $target_dir -maxdepth 1 -type d -name '[1-2][0-9][0-9][0-9][0-1][0-9][0-3][0-9]_[0-2][0-9][0-5][0-9]*' | sort | head -n 1 2>&1
        return 0
    fi
    return 1
}

function file_find_top_sorted_by_date(){
    # arg1: The target dir to find
    # arg2: Optional file extension
    local target_dir=$1
    local file_ext=$([ -n "$2" ] && echo "$2" || echo "")
    if [ -n "$file_ext" ] && [ ! "${file_ext:0:1}" == "." ]; then
        file_ext=".$file_ext"
    fi
    if [ -d $target_dir ]; then
        find $target_dir -maxdepth 1 -type f -name "[1-2][0-9][0-9][0-9][0-1][0-9][0-3][0-9]_[0-2][0-9][0-5][0-9]*$file_ext" | sort | head -n 1 2>&1
        return $?
    fi
    return 1
}


# </Deployment Fucntions>

# <Apache Fucntions>
function apache_configure(){
    # arg1: The home directory for deployment
    # arg2: The apache port to run
    # arg3: Optional apache document root, default  /var/www/html
    # arg4: Optional apache run user, default www-data
    local deployment_home=$1
    local apache_port=$2
    local apache_document_root=$([ -n "$3" ] && echo "$3" || echo "/var/www/html")
    local apache_run_user=$([ -n "$4" ] && echo "$4" || echo "www-data")
    if [ -d $deployment_home ]; then
        if [ -n "$apache_port" ]; then
            # Apache initialization
            sed -i "s/{PORT}/$apache_port/g" /etc/apache2/apache2.conf
            [ ! -d /var/lock/apache2 ] && mkdir /var/lock/apache2
            [ ! -d /var/run/apache2 ] && mkdir /var/run/apache2
            # point the wwroot to public in the root symbolic directory
            # local target_deploy_dir=${deployment_home}
            # local target_deploy_dir=$(dir_get_latest_deployed_dir ${deployment_home})
            # if [ -z "$target_deploy_dir" ]; then
            #     target_deploy_dir=${deployment_home}
            # fi
            #chown -R $apache_run_user ${deployment_home}/ &
            # the above commenda sent to backgroud, because it can
            local target_deploy_dir_doc_root=$([ -d ${deployment_home}/public ] && echo "${deployment_home}/public" || echo "${deployment_home}")
            #check if the target and actual document root are the same
            if [ -L $apache_document_root ] && [ "$target_deploy_dir_doc_root" == "$(readlink -f $apache_document_root)" ];then
                echo "Apache document root already configured in: $target_deploy_dir_doc_root"
            else
                [ -L $apache_document_root ] && rm ${apache_document_root}
                # If is directory, rename it to not delete anything inside it
                if [ -d $apache_document_root ]; then
                    mv $apache_document_root ${apache_document_root}_old
                fi
                ln -s ${target_deploy_dir_doc_root} ${apache_document_root}
                echo "Sucefull configured apache with document root in: $target_deploy_dir_doc_root"
            fi
            return 0
        fi
        echo "Missing parameter, call this function as $0 $1 apache_port"
        return 2
    fi
    echo "Invalid deployment home direcotry $deployment_home"
    return 1
}
# </Apache Fucntions>


function execute_self_fn(){
    local fn_name=$1
    if [ -n "$fn_name" ]; then
        if [ $(type ${fn_name} &> /dev/null; echo $?) -eq 0 ]; then
            shift;
            echo "Executing ${fn_name} $@"
            ${fn_name} $@
            return $?
        fi
        echo "invalid function ${fn_name}"
        return 1
    fi
    return 0
}

#check if there are any argument
if [ $# -gt 0 ]; then
    while getopts :c opt; do
        case $opt in
            c)
                execute_self_fn ${OPTARG}
            ;;
        esac
    done
fi

