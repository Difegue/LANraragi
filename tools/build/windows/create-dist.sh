#!/bin/sh

set -e

# Create the root vfs, copy bin and etc as-is
mkdir -p ./win-dist/runtime

cp -R /ucrt64/bin ./win-dist/runtime
cp -R /ucrt64/etc ./win-dist/runtime

# Remove other exes
find ./win-dist/runtime/bin -name "*.exe" -not -name "perl.exe" -not -name "gs.exe" -type f -delete

# Copy perl, openssl and magick libs
mkdir -p ./win-dist/runtime/lib

cp -R /ucrt64/lib/perl5 ./win-dist/runtime/lib
cp -R /ucrt64/lib/p11-kit ./win-dist/runtime/lib
cp -R /ucrt64/lib/ImageMagick-7.1.2 ./win-dist/runtime/lib

# We don't need .a files, they are used only during compilation
find ./win-dist/runtime/lib/ImageMagick-7.1.2/ -name "*.a" -type f -delete

# Copy vips modules
cp -R /ucrt64/lib/vips-modules-8.17 ./win-dist/runtime/lib

# Copy more openssl stuff
mkdir -p ./win-dist/runtime/share

cp -R /ucrt64/share/pki ./win-dist/runtime/share

# Inject redis into the vfs
wget -q -O redis.zip https://github.com/redis-windows/redis-windows/releases/download/7.2.8/Redis-7.2.8-Windows-x64-msys2.zip
unzip -qq redis.zip
rm redis.zip

mkdir -p win-dist/runtime/redis

mv ./Redis-7.2.8-Windows-x64-msys2/* ./win-dist/runtime/redis

rm -rf ./Redis-7.2.8-Windows-x64-msys2

# Copy the actual app
cp ./package.json ./win-dist
cp ./lrr.conf ./win-dist
cp -R ./lib ./win-dist
cp -R ./public ./win-dist
cp -R ./script ./win-dist
cp -R ./templates ./win-dist
cp -R ./locales ./win-dist

cp ./tools/build/windows/run.ps1 ./win-dist

cp ./tools/build/windows/redis.conf ./win-dist/runtime/redis
