#!/bin/sh

set -e

# Run it with unlimited jobs to improve performance
export MAKEFLAGS="-j"

# Install cpanm
curl -L https://cpanmin.us | perl - App::cpanminus

cd ./tools

# Manually download and patch modules

cpanm --notest --installdeps Crypt::DES@2.07
curl -L -s https://cpan.metacpan.org/authors/id/D/DP/DPARIS/Crypt-DES-2.07.tar.gz | tar -xz
cd Crypt-DES-2.07
patch -p1 < ../build/all/perl-Crypt-DES-fedora-c99.patch
perl Makefile.PL && mingw32-make install
cd ../ && rm -rf Crypt-DES-2.07

cpanm --notest --installdeps Minion@11.0
curl -L -s https://cpan.metacpan.org/authors/id/S/SR/SRI/Minion-11.0.tar.gz | tar -xz
cd Minion-11.0
sed -i "s/croak 'Minion workers do not support fork emulation'/#croak 'Minion workers do not support fork emulation'/" lib/Minion.pm
perl Makefile.PL && mingw32-make install
cd ../ && rm -rf Minion-11.0

cpanm --notest --installdeps Image::Magick
curl -L -s https://cpan.metacpan.org/authors/id/J/JC/JCRISTY/Image-Magick-7.1.2-3.tar.gz | tar -xz
cd Image-Magick-7.1.2
patch -p1 < ../build/windows/perl-Image-Magic-fix-msys2.patch
perl Makefile.PL && mingw32-make install
cd ../ && rm -rf Image-Magick-7.1.2

cpanm --notest ETHER/Net-IDN-Encode-2.501-TRIAL.tar.gz

# Install remaining modules
cpanm --notest --installdeps .

cd ..

# Run installer
perl ./tools/install.pl install-full
