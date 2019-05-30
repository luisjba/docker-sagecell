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

function sage_install_custom_libraries(){
    if [ -n "$SAGE_INSTALL_CUSTOM_LIBS" ]; then
        for sage_lib in $SAGE_INSTALL_CUSTOM_LIBS; do
            echo "installing $sage_lib into sage"
            sudo -H -E -u sage /usr/bin/sage -pip install ${sage_lib}
        done
    fi
    return 0
}

function load_extra_sage_libs(){
    SAGE_LIBS_DIR=${SAGE_LIBS_DIR%/}
    if [ -d ${SAGE_BUILD_LIB_DIR} ]; then
        if [ -d ${SAGE_LIBS_DIR} ]; then
            for dir_lib in $(ls -l ${SAGE_LIBS_DIR} | egrep '^d' | awk '{print $9}') ; do
                 [ -L ${SAGE_BUILD_LIB_DIR}/${dir_lib} ] && rm ${SAGE_BUILD_LIB_DIR}/${dir_lib}
                 ln -s ${SAGE_LIBS_DIR}/${dir_lib} ${SAGE_BUILD_LIB_DIR}/${dir_lib}
                 echo "Installed the lib ${dir_lib} into ${SAGE_LIBS_DIR}"
            done
            echo "Successfully Installed all libraries"
            return 0
        fi
        echo "Invalid dir ${SAGE_LIBS_DIR} to load inside sage libs "
        return 2
    fi
    echo "Invalid sage library directory ${SAGE_BUILD_LIB_DIR}"
    return 1
}

function configure_sagecell(){
    declare -a sagecell_conf_vars=("SAGECELL_KERNEL_DIR" \
    "SAGECELL_BEAT_INTERVAL" \
    "SAGECELL_FIRST_BEAT" \
    "SAGECELL_MAX_TIMEOUT" \
    "SAGECELL_MAX_LIFESPAN" \
    "SAGECELL_REQUIRE_TOS" \
    "SAGECELL_PROVIDER_SETTINGS_MAX_KERNELS" \
    "SAGECELL_PROVIDER_SETTINGS_PRE_FROKED" "SAGECELL_PROVIDER_SETTINGS_PRE_FROKED_LIMIT_CPU")
    for var_name in "${sagecell_conf_vars[@]}"; do
        if [ -n "${!var_name}" ]; then
            file_content_string_replace "{${var_name}}" "${!var_name}" ${SAGECELL_HOME}/config.py
            if [ $? -gt 0 ]; then
                echo "ERROR setting value ${var_name}=${!var_name} into ${SAGECELL_HOME}/config.py for SageCell "
                exit 1
            fi
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
chown -R sage:sage $SAGECELL_HOME
[ -n "$SAGECELL_KERNEL_DIR" ] && [ ! -d ${SAGECELL_KERNEL_DIR} ] && mkdir ${SAGECELL_KERNEL_DIR} && chown -R sage:sage ${SAGECELL_KERNEL_DIR}
chown -R sage:sage /home/sage/.sage/
sage_install_custom_libraries
load_extra_sage_libs
[ $? -eq 0 ] && chown -R sage:sage  ${SAGE_LIBS_DIR}
su sage -c "/usr/local/bin/shell_scripts_lib.sh ssh_psswordless_configure_localhost /home/sage"
su sage -c "/usr/local/bin/shell_scripts_lib.sh ssh_permission_status localhost &> /dev/null"
if [ $? -eq 0 ]; then
    echo "Executing => $@"
    sudo -H -E -u sage $(eval "echo $@")
    #su sage -c "$@"
else
    echo "ERROR: SageCell server not started. SSH passwordless missconfigured"
fi
