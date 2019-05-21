#!/bin/bash
# MAINTAINER: Jose Luis Bracamonte A. <luisjba@gmail.com>
# Date Created: 2018-05-08
# Las Updated: 2019-05-20
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

function configure_ssh_passwordless(){
    local user_home=/home/sage
    local key_path=${user_home}/.ssh
    local key_file_name=id_rsa
    local key_file=$key_path/$key_file_name
    if [ $(ssh-add -l &> /dev/null; echo $?) -gt 0 ]; then
        generate_ssh_keys $key_path $key_file_name
        ssh_agent_configure $key_file
        ssh_add_know_host localhost ${user_home}
        ssh-copy-id -i ${key_file}.pub localhost
    fi
}

function configure_sagecell(){
    local $sagecell_config_file=/home/sagecell/config.py
    file_content_string_replace "{SAGECELL_KERNEL_DIR}" $SAGECELL_KERNEL_DIR $sagecell_config_file && \
    file_content_string_replace "{SAGECELL_PROVIDER_SETTINGS_MAX_KERNELS}" $SAGECELL_PROVIDER_SETTINGS_MAX_KERNELS $sagecell_config_file && \
    file_content_string_replace "{SAGECELL_PROVIDER_SETTINGS_PRE_FROKED}" $SAGECELL_PROVIDER_SETTINGS_PRE_FROKED $sagecell_config_file && \
    file_content_string_replace "{SAGECELL_PROVIDER_SETTINGS_PRE_FROKED_LIMIT_CPU}" $SAGECELL_PROVIDER_SETTINGS_PRE_FROKED_LIMIT_CPU $sagecell_config_file && \
    file_content_string_replace "{SAGECELL_PROVIDER_INFO_HOST}" $SAGECELL_PROVIDER_INFO_HOST $sagecell_config_file && \
    file_content_string_replace "{SAGECELL_PROVIDER_INFO_USERNAME}" $SAGECELL_PROVIDER_INFO_USERNAME $sagecell_config_file
}

function sagecell_setup(){
    # Continuous Integration Delivery - Setup
    configure_ssh_passwordless
    configure_sagecell
    file_register_environment_variables /etc/profile
    sed -i "s/SSH_PORT/$SSH_PORT/g" /etc/ssh/sshd_config
    service ssh start
}

#calling the sagecell setup
sagecell_setup
#CMD entry point
exec "\$@"
