#!/bin/sh

#Just do everything 
apk update 
apk add perl perl-io-socket-ssl perl-dev g++ make pkgconf gnupg wget curl nodejs nodejs-npm redis libarchive-dev libbz2 libjpeg-turbo-dev libpng-dev openssl-dev zlib-dev supervisor su-exec

#Hey it's cpanm
curl -L https://cpanmin.us | perl - App::cpanminus 

#Use a patched version of Rijndael for musl support until a proper CPAN release is done
#See https://framagit.org/fiat-tux/hat-softwares/lufi/issues/137
cpanm https://gitlab.com/thedudeabides/crypt-rijndael/-/archive/musl-libc/crypt-rijndael-musl-libc.tar.gz 

#Install the LRR dependencies proper
cd tools && cpanm --notest --installdeps . -M https://cpan.metacpan.org && cd ..
npm run lanraragi-installer install-front 

#Cleanup to lighten the image
apk del perl-dev g++ make gnupg wget curl nodejs nodejs-npm openssl-dev ca-certificates
rm -rf /root/.cpanm/* /usr/local/share/man/* node_modules 

#Make entrypoint executable
chmod +x ./tools/DockerSetup/entrypoint.sh