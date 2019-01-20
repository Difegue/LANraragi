# DOCKER-VERSION 0.3.4
FROM        alpine:latest
LABEL       git="https://github.com/Difegue/LANraragi" 

#Copy cpanfile before copying the entire context - allows for Docker cache to preserve cpan dependencies
COPY /tools/cpanfile /
COPY /tools/install.pl /tools/install.pl
COPY /package.json /package.json
ENV EV_EXTRA_DEFS -DEV_NO_ATFORK

#Just do everything
RUN apk update && \
    apk add perl perl-io-socket-ssl perl-dbd-pg perl-dev g++ make gnupg wget curl nodejs nodejs-npm redis libarchive libjpeg libpng openssl-dev zlib-dev supervisor && \
    curl -L https://cpanmin.us | perl - App::cpanminus && \
    cpanm --notest --installdeps . -M https://cpan.metacpan.org && \
    npm run lanraragi-installer install-full && \
    apk del perl-dev g++ make gnupg wget curl nodejs nodejs-npm openssl-dev zlib-dev && \
    rm -rf /root/.cpanm/* /usr/local/share/man/*

#Copy remaining LRR files from context
COPY / /

#Default mojo server port
EXPOSE 3000

#Enable UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

#Special redis conf to write DB in content directory and disable daemonization
COPY /tools/DockerSetup/redis.conf /home/koyomi/redis.conf
COPY /tools/DockerSetup/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

CMD ["/usr/bin/supervisord"]
