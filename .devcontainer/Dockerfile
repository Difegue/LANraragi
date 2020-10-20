FROM difegue/lanraragi:nightly

# [Option] Install zsh
ARG INSTALL_ZSH="true"
# [Option] Upgrade OS packages to their latest versions
ARG UPGRADE_PACKAGES="false"

ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8

# Install needed packages and setup non-root user. Use a separate RUN statement to add your own dependencies.
ARG USERNAME=koyomi
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN apk update && apk add wget
RUN wget -P /tmp/library-scripts https://raw.githubusercontent.com/microsoft/vscode-dev-containers/master/script-library/common-alpine.sh
RUN ash /tmp/library-scripts/common-alpine.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" \
    && rm -rf /var/lib/apt/lists/* /tmp/library-scripts

# Install additional packages.
RUN apk add perl-dev g++ make gnupg wget curl nodejs nodejs-npm openssl-dev ctags \
    && cpanm Perl::Tidy

