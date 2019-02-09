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
#Also build musl-locales to generate the en_US.UTF8 locale 
RUN apk update && \
    apk add perl perl-io-socket-ssl perl-dev g++ make pkgconf gnupg wget curl nodejs nodejs-npm redis libarchive-dev libbz2 libjpeg-turbo-dev libpng-dev openssl-dev zlib-dev supervisor && \
    curl -L https://cpanmin.us | perl - App::cpanminus && \
    cpanm https://gitlab.com/thedudeabides/crypt-rijndael/-/archive/musl-libc/crypt-rijndael-musl-libc.tar.gz && \
    cpanm --notest --installdeps . -M https://cpan.metacpan.org && \
    npm run lanraragi-installer install-front && \
    apk add git cmake musl-dev gcc gettext-dev libintl && \
    git clone https://gitlab.com/rilian-la-te/musl-locales.git && cd musl-locales &&\
    cmake . && make && make install && cd .. && \
    apk del perl-dev g++ make gnupg wget curl nodejs nodejs-npm openssl-dev  && \
    apk del git cmake ca-certificates musl-dev gcc gettext-dev libintl && \
    rm -rf /root/.cpanm/* /usr/local/share/man/* node_modules musl-locales

#Copy remaining LRR files from context
COPY / /home/koyomi/lanraragi

#Default mojo server port
EXPOSE 3000

#Enable UTF-8
ENV MUSL_LOCPATH /usr/local/share/i18n/locales/musl
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

#Special redis conf to write DB in content directory and disable daemonization
COPY /tools/DockerSetup/redis.conf /home/koyomi/redis.conf
COPY /tools/DockerSetup/supervisord.conf /home/koyomi/supervisord.conf

#Environment variable overridable by the user on container deployment
ENV LRR_NETWORK http://*:3000
ENTRYPOINT ["supervisord", "--nodaemon", "--configuration", "/home/koyomi/supervisord.conf"]
