#!/bin/sh

#Just do everything
apk update
apk add perl perl-io-socket-ssl perl-dev redis libarchive-dev libbz2 openssl-dev zlib-dev
apk add imagemagick imagemagick-perlmagick libwebp-tools
apk add g++ make pkgconf gnupg wget curl nodejs nodejs-npm
apk add shadow s6=2.9.1.0-r0 s6-portable-utils

#Hey it's cpanm
curl -L https://cpanmin.us | perl - App::cpanminus

#Install the LRR dependencies proper
cd tools && cpanm --notest --installdeps . -M https://cpan.metacpan.org && cd ..
npm run lanraragi-installer install-full

#Cleanup to lighten the image
apk del perl-dev g++ make gnupg wget curl nodejs nodejs-npm openssl-dev
rm -rf /root/.cpanm/* /root/.npm/ /usr/local/share/man/* node_modules /var/cache/apk/*
