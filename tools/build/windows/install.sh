#!/bin/sh

set -e

# Install cpanm
curl -L https://cpanmin.us | perl - App::cpanminus

cd ./tools

# Manually download and patch modules

cpanm --notest --installdeps Crypt::DES -M https://cpan.metacpan.org
curl -L -s https://cpan.metacpan.org/authors/id/D/DP/DPARIS/Crypt-DES-2.07.tar.gz | tar -xz
cd Crypt-DES-2.07
patch -p1 < ../build/windows/perl-Crypt-DES-fedora-c99.patch
perl Makefile.PL && mingw32-make install
cd ../ && rm -rf Crypt-DES-2.07

cpanm --notest --installdeps Minion -M https://cpan.metacpan.org
curl -L -s https://cpan.metacpan.org/authors/id/S/SR/SRI/Minion-10.31.tar.gz | tar -xz
cd Minion-10.31
sed -i "s/croak 'Minion workers do not support fork emulation'/#croak 'Minion workers do not support fork emulation'/" lib/Minion.pm
perl Makefile.PL && mingw32-make install
cd ../ && rm -rf Minion-10.31

cpanm --notest --installdeps Image::Magick -M https://cpan.metacpan.org
curl -L -s https://cpan.metacpan.org/authors/id/J/JC/JCRISTY/Image-Magick-7.1.1-28.tar.gz | tar -xz
cd Image-Magick-7.1.1
patch -p1 < ../build/windows/perl-Image-Magic-fix-msys2.patch
perl Makefile.PL && mingw32-make install
cd ../ && rm -rf Image-Magick-7.1.1

# Install remaining modules
cpanm --notest --installdeps . -M https://cpan.metacpan.org

cd ..

# Run installer
perl ./tools/install.pl install-full
