#!/bin/sh

set -e

pacman --needed -S mingw-w64-ucrt-x86_64-perl mingw-w64-ucrt-x86_64-openssl mingw-w64-ucrt-x86_64-imagemagick mingw-w64-ucrt-x86_64-libjxl mingw-w64-ucrt-x86_64-libheif mingw-w64-ucrt-x86_64-ghostscript mingw-w64-ucrt-x86_64-zlib mingw-w64-ucrt-x86_64-lzo2 mingw-w64-ucrt-x86_64-libarchive mingw-w64-ucrt-x86_64-ca-certificates libxcrypt --noconfirm

pacman --needed -S mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-make make mingw-w64-ucrt-x86_64-diffutils libbz2-devel patch mingw-w64-ucrt-x86_64-nodejs mingw-w64-ucrt-x86_64-tools-git unzip --noconfirm

curl -L https://cpanmin.us | perl - App::cpanminus

cd ./tools

cpanm --notest --installdeps Crypt::DES -M https://cpan.metacpan.org
curl -L -s https://cpan.metacpan.org/authors/id/D/DP/DPARIS/Crypt-DES-2.07.tar.gz | tar -xz
cd Crypt-DES-2.07
patch -p1 < ../build/msys2/perl-Crypt-DES-fedora-c99.patch
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
patch -p1 < ../build/msys2/perl-Image-Magic-fix-msys2.patch
perl Makefile.PL && mingw32-make install
cd ../ && rm -rf Image-Magick-7.1.1

cpanm --notest --installdeps . -M https://cpan.metacpan.org
cd ..

perl ./tools/install.pl install-full

pacman -Rs mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-make make mingw-w64-ucrt-x86_64-diffutils libbz2-devel patch mingw-w64-ucrt-x86_64-nodejs mingw-w64-ucrt-x86_64-tools-git unzip --noconfirm

rm -rf ./public/js/vendor/*.map ./public/css/vendor/*.map
