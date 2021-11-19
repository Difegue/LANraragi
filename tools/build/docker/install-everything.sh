#!/bin/sh

#Just do everything
apk update
apk add perl perl-io-socket-ssl perl-dev redis libarchive-dev libbz2 openssl-dev zlib-dev
apk add imagemagick imagemagick-perlmagick libwebp-tools libheif
apk add g++ make pkgconf gnupg wget curl nodejs nodejs-npm file
apk add shadow s6 s6-portable-utils

#Hey it's cpanm
curl -L https://cpanmin.us | perl - App::cpanminus

#Alpine's libffi build comes with AVX instructions enabled
#Rebuild our own libffi with those disabled
if [ $(uname -m) == 'x86_64' ]; then
  cpanm --notest Alien::FFI
fi

#Install the LRR dependencies proper
cd tools && cpanm --notest --installdeps . -M https://cpan.metacpan.org && cd ..
npm run lanraragi-installer install-full

#Cleanup to lighten the image
apk del perl-dev g++ make gnupg wget curl nodejs nodejs-npm openssl-dev file
rm -rf /root/.cpanm/* /root/.npm/ /usr/local/share/man/* node_modules /var/cache/apk/*
