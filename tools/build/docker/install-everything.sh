#!/bin/sh

#Just do everything 
apk update 
apk add perl perl-io-socket-ssl perl-dev redis libarchive-dev libbz2 openssl-dev zlib-dev 
apk add imagemagick imagemagick-perlmagick libwebp-tools
apk add g++ make pkgconf gnupg wget curl nodejs nodejs-npm
apk add supervisor su-exec shadow

#Hey it's cpanm
curl -L https://cpanmin.us | perl - App::cpanminus 

#Install Linux::Inotify2 manually since it's not in the base cpanfile (doesn't build on macOS)
cpanm Linux::Inotify2

#Copy wsl.conf to /etc for extra WSL compatibility 
cp tools/build/windows/wsl.conf /etc/wsl.conf

#Install the LRR dependencies proper
cd tools && cpanm --notest --installdeps . -M https://cpan.metacpan.org && cd ..
npm run lanraragi-installer install-front 

#Cleanup to lighten the image
apk del perl-dev g++ make gnupg wget curl nodejs nodejs-npm openssl-dev 
rm -rf /root/.cpanm/* /usr/local/share/man/* node_modules tools/_screenshots tools/Documentation tools/windows tools/homebrew tools/vagrant

#Remove part of ghostscript by hand as it bloats up the image by 40MBs and is only needed for PDF support(which we don't have rn)
rm -r /usr/share/ghostscript/
rm /usr/bin/gs
rm /usr/lib/libgs.so.9*