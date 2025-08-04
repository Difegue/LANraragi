#!/bin/sh

set -e

# Remove compilation deps
pacman -Rs mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-make make mingw-w64-ucrt-x86_64-diffutils libbz2-devel patch mingw-w64-ucrt-x86_64-nodejs mingw-w64-ucrt-x86_64-tools-git --noconfirm

# Cleanup
rm -rf ./public/js/vendor/*.map ./public/css/vendor/*.map
