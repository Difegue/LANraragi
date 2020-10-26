FROM debian:stable

# [Option] Install zsh
ARG INSTALL_ZSH="true"
# [Option] Upgrade OS packages to their latest versions
ARG UPGRADE_PACKAGES="false"

ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8

# Install needed packages and setup non-root user. Use a separate RUN statement to add your own dependencies.
ARG USERNAME=koyomi
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get -y update && apt-get -y install wget \
	&& wget -P /tmp/library-scripts https://raw.githubusercontent.com/microsoft/vscode-dev-containers/master/script-library/common-debian.sh
RUN /bin/bash /tmp/library-scripts/common-debian.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts

# Install additional packages.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends build-essential make gnupg pkg-config \
    cpanminus redis-server libarchive-dev webp libssl-dev zlib1g-dev \
    perlmagick npm perltidy ghostscript 

# Just re-grab cpanfile/install.pl/package.json from the online repo as codespaces' build context is super fucked and I don't get it at all
# Dropping copies of the files in the .devcontainer folder should also work, but I cba to duplicate my build files for this and symlinks aint working I hate computers
RUN wget -P /tools https://raw.githubusercontent.com/Difegue/LANraragi/dev/tools/cpanfile \
    && wget -P /tools https://raw.githubusercontent.com/Difegue/LANraragi/dev/tools/install.pl \
    && wget https://raw.githubusercontent.com/Difegue/LANraragi/dev/package.json

RUN npm run lanraragi-installer install-full

