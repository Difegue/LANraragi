#!/bin/sh

set -e

mkdir -p ./win-dist/runtime

cp -R /ucrt64/bin ./win-dist/runtime
cp -R /ucrt64/etc ./win-dist/runtime

mkdir -p ./win-dist/runtime/lib

cp -R /ucrt64/lib/perl5 ./win-dist/runtime/lib
cp -R /ucrt64/lib/p11-kit ./win-dist/runtime/lib

mkdir -p ./win-dist/runtime/share

cp -R /ucrt64/share/pki ./win-dist/runtime/share

cp ./package.json ./win-dist
cp ./lrr.conf ./win-dist
cp -R ./lib ./win-dist
cp -R ./public ./win-dist
cp -R ./script ./win-dist
cp -R ./templates ./win-dist
cp -R ./locales ./win-dist

cp ./tools/build/msys2/run.ps1 ./win-dist

wget -q -O redis.zip https://github.com/redis-windows/redis-windows/releases/download/7.2.8/Redis-7.2.8-Windows-x64-msys2.zip
unzip -qq redis.zip
rm redis.zip

mkdir -p win-dist/runtime/redis

mv ./Redis-7.2.8-Windows-x64-msys2/* ./win-dist/runtime/redis

rm -rf ./Redis-7.2.8-Windows-x64-msys2

cp ./tools/build/msys2/redis.conf ./win-dist/runtime/redis
