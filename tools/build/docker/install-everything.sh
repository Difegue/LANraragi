#!/bin/sh

#Just do everything
apk update
apk add tzdata
apk add perl perl-io-socket-ssl perl-dev redis libarchive-dev libbz2 openssl-dev zlib-dev linux-headers
apk add imagemagick imagemagick-perlmagick libwebp-tools libheif
apk add g++ make pkgconf gnupg wget curl file
apk add shadow s6 s6-portable-utils 

# Check for alpine version
if [ -f /etc/alpine-release ]; then
  alpine_version=$(cat /etc/alpine-release)
  if [ "$alpine_version" = "3.12.12" ]; then
      apk add nodejs-npm
    else # Those packages don't exist on 3.12
      apk add nodejs npm s6-overlay libjxl
  fi
fi

#Hey it's cpanm
curl -L https://cpanmin.us | perl - App::cpanminus

#Alpine's libffi build comes with AVX instructions enabled
#Rebuild our own libffi with those disabled
if [ $(uname -m) == 'x86_64' ]; then

  #Install deps only
  cpanm --notest --installdeps Alien::FFI
  curl -L -s https://cpan.metacpan.org/authors/id/P/PL/PLICEASE/Alien-FFI-0.25.tar.gz | tar -xz
  cd Alien-FFI-0.25
  # Patch build script to disable AVX - and SSE4 for real old CPUs
  # See https://developers.redhat.com/blog/2021/01/05/building-red-hat-enterprise-linux-9-for-the-x86-64-v2-microarchitecture-level
  sed -i 's/--disable-builddir/--disable-builddir --with-gcc-arch=x86-64/' alienfile
  perl Makefile.PL && make install
  cd ../ && rm -rf Alien-FFI-0.25
fi

#Install the LRR dependencies proper
cd tools && cpanm --notest --installdeps . -M https://cpan.metacpan.org && cd ..
npm run lanraragi-installer install-full

#Cleanup to lighten the image
apk del perl-dev g++ make gnupg wget curl nodejs npm openssl-dev file
rm -rf public/js/vendor/*.map public/css/vendor/*.map
rm -rf /root/.cpanm/* /root/.npm/ /usr/local/share/man/* node_modules /var/cache/apk/*
