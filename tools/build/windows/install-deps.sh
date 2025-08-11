#!/bin/sh

set -e

# Install deps that will persist into the vfs
pacman --needed -S mingw-w64-ucrt-x86_64-perl mingw-w64-ucrt-x86_64-openssl mingw-w64-ucrt-x86_64-imagemagick mingw-w64-ucrt-x86_64-libjxl mingw-w64-ucrt-x86_64-libheif mingw-w64-ucrt-x86_64-ghostscript mingw-w64-ucrt-x86_64-zlib mingw-w64-ucrt-x86_64-lzo2 mingw-w64-ucrt-x86_64-libarchive mingw-w64-ucrt-x86_64-ca-certificates libxcrypt unzip --noconfirm

# Install temporary deps for compilation
pacman --needed -S mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-make make mingw-w64-ucrt-x86_64-diffutils libbz2-devel patch mingw-w64-ucrt-x86_64-nodejs mingw-w64-ucrt-x86_64-tools-git --noconfirm
