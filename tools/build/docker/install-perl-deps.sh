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

#cpanm --notest --installdeps JSON::Validator@5.19
curl -L -s https://cpan.metacpan.org/authors/id/J/JH/JHTHORSEN/JSON-Validator-5.19.tar.gz | tar -xz
cd JSON-Validator-5.19
patch -p1 < ../build/all/perl-JSON-Validator.patch
perl Makefile.PL && make install
cd ../ && rm -rf JSON-Validator-5.19

# Install the LRR dependencies proper
cpanm --notest --installdeps .

cd ..

npm run lanraragi-installer install-back
