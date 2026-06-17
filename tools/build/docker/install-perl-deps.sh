#!/bin/sh

set -e

# Run it with increased jobs to improve performance
export MAKEFLAGS="-j$(nproc)"

# Redirect perl dependencies to the home directory
eval "$(perl -Mlocal::lib)"

# Install cpanm
curl -L https://cpanmin.us | perl - App::cpanminus

cd ./tools

# Manually download and patch modules

cpanm --notest --installdeps Crypt::DES@2.07
curl -L -s https://cpan.metacpan.org/authors/id/D/DP/DPARIS/Crypt-DES-2.07.tar.gz | tar -xz
cd Crypt-DES-2.07
patch -p1 < ../build/all/perl-Crypt-DES-fedora-c99.patch
perl Makefile.PL && make install
cd ../ && rm -rf Crypt-DES-2.07

cpanm --notest ETHER/Net-IDN-Encode-2.501-TRIAL.tar.gz

# Install the LRR dependencies proper
cpanm --notest --installdeps .

cd ..

perl ./tools/install.pl install-back
