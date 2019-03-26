#!/bin/sh

#Just do everything 
apk update 
apk add perl perl-io-socket-ssl perl-dev g++ make pkgconf gnupg wget curl nodejs nodejs-npm redis libarchive-dev libbz2 libjpeg-turbo-dev libpng-dev openssl-dev zlib-dev supervisor

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

#Add the koyomi user, using the specified uid. 
#This solves permission problems on the content folder if the Docker user sets the same uid as the owner of the folder.
adduser -D -u $LRR_UID -g '' koyomi 
chown -R koyomi /home/koyomi/lanraragi