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
cpanm --notest --installdeps Crypt::DES -M https://cpan.metacpan.org
curl -L -s https://cpan.metacpan.org/authors/id/D/DP/DPARIS/Crypt-DES-2.07.tar.gz | tar -xz
cd Crypt-DES-2.07
patch -p1 < ../perl-Crypt-DES-fedora-c99.patch
perl Makefile.PL && make install
cd ../ && rm -rf Crypt-DES-2.07

cpanm --notest https://cpan.metacpan.org/authors/id/E/ET/ETHER/Net-IDN-Encode-2.501-TRIAL.tar.gz

cpanm --notest --installdeps JSON::Validator -M https://cpan.metacpan.org
curl -L -s https://cpan.metacpan.org/authors/id/J/JH/JHTHORSEN/JSON-Validator-5.17.tar.gz | tar -xz
cd JSON-Validator-5.17
patch -p1 < ../perl-JSON-Validator.patch
perl Makefile.PL && make install
cd ../ && rm -rf JSON-Validator-5.17

# cpanm can't find the correct version so manually download and install it
cpanm --notest https://cpan.metacpan.org/authors/id/S/SR/SRI/Minion-11.0.tar.gz

# Install the LRR dependencies proper
cpanm --notest --installdeps . -M https://cpan.metacpan.org

cd ..

npm run lanraragi-installer install-back
