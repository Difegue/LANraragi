#!/bin/sh

set -e

usage() { echo "Usage: $0 [-d (devmode)]" 1>&2; exit 1; }

DEV=0

while getopts "dw" o; do
    case "${o}" in
        d)
            DEV=1
            ;;
        *)
            usage
            ;;
    esac
done

# Just do everything
apk add --no-cache tzdata
apk add --no-cache valkey valkey-cli
apk add --no-cache perl perl-io-socket-ssl imagemagick imagemagick-perlmagick
apk add --no-cache libffi vips vips-jxl vips-heif
apk add --no-cache ghostscript
apk add --no-cache shadow s6 s6-overlay s6-portable-utils procps-ng
apk add --no-cache g++ make pkgconf wget curl nodejs npm perl-dev libarchive-dev linux-headers patch

# Run it with unlimited jobs to improve performance
export MAKEFLAGS="-j"

# Install cpanm
curl -L https://cpanmin.us | perl - App::cpanminus

cd /home/koyomi/lanraragi/tools

# Manually download and patch modules
cpanm --notest --installdeps Crypt::DES -M https://cpan.metacpan.org
curl -L -s https://cpan.metacpan.org/authors/id/D/DP/DPARIS/Crypt-DES-2.07.tar.gz | tar -xz
cd Crypt-DES-2.07
patch -p1 < ../perl-Crypt-DES-fedora-c99.patch
perl Makefile.PL && make install
cd ../ && rm -rf Crypt-DES-2.07

# Install the LRR dependencies proper
cpanm --notest --installdeps . -M https://cpan.metacpan.org

cd ..

npm run lanraragi-installer install-full

if [ $DEV -eq 0 ]; then
  # Cleanup to lighten the image
  apk del --no-cache g++ make pkgconf wget curl nodejs npm perl-dev libarchive-dev linux-headers patch
  rm -rf public/js/vendor/*.map public/css/vendor/*.map
  rm -rf /root/.cpanm/* /root/.npm/ /usr/local/share/man/* node_modules
fi
