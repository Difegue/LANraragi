# DOCKER-VERSION 0.3.4
FROM        alpine:latest
LABEL       git="https://github.com/Difegue/LANraragi" 

WORKDIR /home/koyomi/lanraragi
#Copy cpanfile before copying the entire context - allows for Docker cache to preserve cpan dependencies
COPY /tools/cpanfile cpanfile
COPY /tools/install.pl tools/install.pl
COPY /package.json package.json
ENV EV_EXTRA_DEFS -DEV_NO_ATFORK

#Just do everything in one RUN command
#Use a patched version of Rijndael for musl support until a proper CPAN release is done
#See https://framagit.org/fiat-tux/hat-softwares/lufi/issues/137
#Also use alpine-glibc for decent locale support
RUN apk update && \
    apk add perl perl-io-socket-ssl perl-dev g++ make pkgconf gnupg wget curl nodejs nodejs-npm redis libarchive-dev libbz2 libjpeg-turbo-dev libpng-dev openssl-dev zlib-dev supervisor && \
    wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-2.25-r0.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-bin-2.25-r0.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-i18n-2.25-r0.apk && \
    apk add glibc-bin-2.25-r0.apk glibc-i18n-2.25-r0.apk glibc-2.25-r0.apk && \
    /usr/glibc-compat/bin/localedef -i en_US -f UTF-8 en_US.UTF-8 && \
    curl -L https://cpanmin.us | perl - App::cpanminus && \
    cpanm https://gitlab.com/thedudeabides/crypt-rijndael/-/archive/musl-libc/crypt-rijndael-musl-libc.tar.gz && \
    cpanm --notest --installdeps . -M https://cpan.metacpan.org && \
    npm run lanraragi-installer install-front && \
    apk del perl-dev g++ make gnupg wget curl nodejs nodejs-npm openssl-dev ca-certificates && \
    rm -rf /root/.cpanm/* /usr/local/share/man/* *.apk node_modules musl-locales

#Copy remaining LRR files from context
COPY / /home/koyomi/lanraragi

#Default mojo server port
EXPOSE 3000

#Enable UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

#Special redis conf to write DB in content directory and disable daemonization
COPY /tools/DockerSetup/redis.conf /home/koyomi/redis.conf
COPY /tools/DockerSetup/supervisord.conf /home/koyomi/supervisord.conf

#Environment variable overridable by the user on container deployment
ENV LRR_NETWORK http://*:3000
ENTRYPOINT ["supervisord", "--nodaemon", "--configuration", "/home/koyomi/supervisord.conf"]
