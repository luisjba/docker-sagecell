#!/bin/bash
# MAINTAINER: Jose Luis Bracamonte A. <luisjba@gmail.com>
# Date Created: 2018-05-08
# Las Updated: 2019-05-21
# include libs
. /usr/local/bin/shell_scripts_lib.sh
cat >/etc/motd <<EOL
v 1.0
 _          _       _      _  _
| |_  _ _  | | _ _ <_> ___<_>| |_  ___
| . \| | | | || | || |<_-<| || . \<_> |
|___/\_  | |_| ___||_|/__/| ||___/<___|
     <___|               <__|
This docker Instance with SageMath installed and SageCell
Support include custom sage libraries  with Continuous
delivery from a git repository
SageMath version : `sage -v | head -n 1`
MAINTAINER: Jose Luis Bracamonte Amavizca. <luisjba@gmail.com>
-------------------------------------------------------------------------
EOL
cat /etc/motd

SAGECELL_HOME=/home/sage/sagecell
function configure_ssh_passwordless(){
    local user_home=/home/sage
    local key_path=${user_home}/.ssh
    local key_file_name=id_rsa
    local key_file=$key_path/$key_file_name
    if [ $(ssh-add -l &> /dev/null; echo $?) -gt 0 ]; then
        generate_ssh_keys $key_path $key_file_name \
        && ssh_agent_configure $key_file \
        && ssh_add_know_host localhost ${user_home} \
        && cat ${key_file}.pub > ${key_path}/authorized_keys \
        && echo "Sucefull configure ssh passwordless to localhost"
        #ssh-copy-id -i ${key_file}.pub localhost
    fi
}

function configure_sagecell(){
    declare -a sagecell_conf_vars=("SAGECELL_KERNEL_DIR" "SAGECELL_PROVIDER_SETTINGS_MAX_KERNELS" \
    "SAGECELL_PROVIDER_SETTINGS_PRE_FROKED" "SAGECELL_PROVIDER_SETTINGS_PRE_FROKED_LIMIT_CPU")
    for var_name in "${sagecell_conf_vars[@]}"; do
        if [ -n "${!var_name}" ]; then
            file_content_string_replace "{${var_name}}" ${!var_name} ${SAGECELL_HOME}/config.py
        else
            echo "WARNING: Empty value in var \$${var_name}"
        fi
    done
    unset sagecell_conf_vars
}

function sagecell_setup(){
    # Configure and start ssh service
    sed -i "s/SSH_PORT/$SSH_PORT/g" /etc/ssh/sshd_config
    service ssh start
    # run rsyslog
    service rsyslog start
    configure_sagecell
    file_register_environment_variables /etc/profile
}
#calling the sagecell setup
sagecell_setup
#CMD entry point
cd $SAGECELL_HOME
su - sage
configure_ssh_passwordless
exec $@
