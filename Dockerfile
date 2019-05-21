FROM sagemath/sagemath:8.7
MAINTAINER "Jose Luis Bracamonte Amavizca <luisjba@gmail.com>"

ARG SAGECELL_SRC_TARGET=/opt
ARG SAGECELL_BRANCH=master

USER root
COPY scripts/install_sagecell.sh /tmp/
COPY scripts/shell_scripts_lib.sh /tmp/
COPY scripts/init_container.sh /tmp/
COPY config/sagecell_config.py /tmp/
COPY config/sshd_config /tmp/

# Packages needed for sagecell
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server locales \
    nodejs-dev node-gyp npm git\
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && npm install -g requirejs \
    && echo "root:Docker!" | chpasswd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mv /tmp/sshd_config  /etc/ssh/ \
    && chmod +x /tmp/*.sh

ENV SHELL /bin/bash

# We do a few things as root in the sagecell install scripts, though the sagecell install
# itself is done by sudo-ing as the sage user
RUN echo "Installing  Sagecell for SageMath  version `sage -v | head -n 1`" \
    && /tmp/install_sagecell.sh $SAGECELL_SRC_TARGET $SAGECELL_BRANCH \
    && mv /tmp/shell_scripts_lib.sh /usr/local/bin/ \
    && mv /tmp/init_container.sh /usr/local/bin/init_container \
    && mv /tmp/sagecell_config.py $SAGECELL_SRC_TARGET/sagecell/config.py \
    && rm -rf /tmp/* \
    && sync

ENV SAGECELL_PORT 80
ENV SSH_PORT 2222
EXPOSE 80 2222

# SageCell Configuration
ENV SAGECELL_KERNEL_DIR ${SAGECELL_SRC_TARGET}/sagecellkernels
ENV SAGECELL_PROVIDER_SETTINGS_MAX_KERNELS 10
ENV SAGECELL_PROVIDER_SETTINGS_PRE_FROKED 1
ENV SAGECELL_PROVIDER_SETTINGS_PRE_FROKED_LIMIT_CPU 120

USER sage
WORKDIR /home/sage/sagecell
ENTRYPOINT ["/bin/init_container"]
CMD ["sage", "web_server.py -p $SAGECELL_PORT"]
