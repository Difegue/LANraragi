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

# Install additional packages.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends build-essential make gnupg pkg-config \
    cpanminus redis-server libarchive-dev webp libssl-dev zlib1g-dev \
    npm perltidy ghostscript

# Install image/perlmagick on its own since we can't use the Debian package here
# Ripped off from https://github.com/spleck/docker-perlmagick7
RUN apt-get install libstdc++-8-dev curl gnupg \
		libdjvulibre-dev libgvc6 liblqr-1-0-dev libltdl-dev libopenexr-dev libopenjp2-7-dev libwmf-dev \
		ghostscript gsfonts fonts-dejavu libzstd-dev libfftw3-dev libpango1.0-dev libraw-dev \
		libraw1394-dev libpng-dev libgif-dev libjpeg-dev libtiff5-dev git -y && \
	find /usr/local/lib/perl5 -name "libperl.so" -exec ln -s {} /usr/local/lib/libperl.so \; && \
	git clone https://github.com/ImageMagick/ImageMagick.git /opt/ImageMagick --branch 7.0.10-33 && \
	cd /opt/ImageMagick && ./configure --with-perl && make && make install && cd / && rm -rf /opt/ImageMagick && \
	rm -rf /var/lib/apt/lists/* 