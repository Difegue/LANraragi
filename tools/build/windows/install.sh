#!/bin/sh

set -e

# Run it with unlimited jobs to improve performance
export MAKEFLAGS="-j"

# Install cpanm
curl -L https://cpanmin.us | perl - App::cpanminus

cd ./tools

# Manually download and patch modules

cpanm --notest --installdeps Minion@11.0
curl -L -s https://cpan.metacpan.org/authors/id/S/SR/SRI/Minion-11.0.tar.gz | tar -xz
cd Minion-11.0
sed -i "s/croak 'Minion workers do not support fork emulation'/#croak 'Minion workers do not support fork emulation'/" lib/Minion.pm
perl Makefile.PL && mingw32-make install
cd ../ && rm -rf Minion-11.0

cpanm --notest ETHER/Net-IDN-Encode-2.501-TRIAL.tar.gz

# Install remaining modules
cpanm --notest --installdeps .

cd ..

# Run installer
perl ./tools/install.pl install-full
