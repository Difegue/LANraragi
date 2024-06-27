#!/bin/sh

set -e

usage() { echo "Usage: $0 [-d (devmode) -w (wsl cpan packages)]" 1>&2; exit 1; }

DEV=0
WSL=0

while getopts "dw" o; do
    case "${o}" in
        d)
            DEV=1
            ;;
        w)
            WSL=1
            ;;
        *)
            usage
            ;;
    esac
done

#Just do everything
apk update
apk add tzdata
apk add perl perl-io-socket-ssl perl-dev redis libarchive-dev libbz2 openssl-dev zlib-dev linux-headers
apk add imagemagick imagemagick-perlmagick libwebp-tools libheif ghostscript
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

# Install cpanm
curl -L https://cpanmin.us | perl - App::cpanminus

# Check for WSL1 to install specific versions of packages
if [ $WSL -eq 1 ]; then
    # Install Linux::Inotify 2.2 explicitly as 2.3 doesn't work properly on WSL:
    # WSL2 literally doesn't work for any form of filewatching,
    # WSL1 works with both default watcher and inotify 2.2, but crashes with inotify 2.3 ("can't open fd 4 as perl handle")

    # Doing the install here allows us to use 2.3 on non-WSL builds. 
    cpanm https://cpan.metacpan.org/authors/id/M/ML/MLEHMANN/Linux-Inotify2-2.2.tar.gz --reinstall
fi

#Alpine's libffi build comes with AVX instructions enabled
#Rebuild our own libffi with those disabled
if [ $(uname -m) == 'x86_64' ]; then

  #Install deps only
  cpanm --notest --installdeps Alien::FFI
  cpanm Sort::Versions 
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
if [ $WSL -eq 1 ]; then
npm run lanraragi-installer install-full legacy
else
npm run lanraragi-installer install-full
fi

if [ $DEV -eq 0 ]; then
  #Cleanup to lighten the image
  apk del perl-dev g++ make gnupg wget curl nodejs npm openssl-dev file
  rm -rf public/js/vendor/*.map public/css/vendor/*.map
  rm -rf /root/.cpanm/* /root/.npm/ /usr/local/share/man/* node_modules /var/cache/apk/*
fi
