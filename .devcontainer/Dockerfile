# Update the VARIANT arg in devcontainer.json to pick a Perl version
ARG VARIANT=5
FROM perl:${VARIANT}

# [Option] Install zsh
ARG INSTALL_ZSH="true"
# [Option] Upgrade OS packages to their latest versions
ARG UPGRADE_PACKAGES="false"

ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8

# Install needed packages and setup non-root user. Use a separate RUN statement to add your own dependencies.
ARG USERNAME=koyomi
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN wget -P /tmp/library-scripts https://raw.githubusercontent.com/microsoft/vscode-dev-containers/master/script-library/common-debian.sh
RUN apt-get update \
    && /bin/bash /tmp/library-scripts/common-debian.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts

# [Optional] Uncomment this section to install additional packages.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends build-essential make gnupg pkg-config \
    cpanminus redis-server libarchive-dev imagemagick perlmagick webp libssl-dev zlib1g-dev \
    npm perltidy ghostscript