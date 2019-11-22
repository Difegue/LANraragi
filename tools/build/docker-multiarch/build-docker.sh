#!/bin/sh
# Script for building multi-arch LRR images using QEMU when necessary. Will try pushing to Docker Hub.
# Shamelessly lifted off https://lobradov.github.io/Building-docker-multiarch-images
# example: ./build-docker.sh x86_64 nightly

echo "Enabling QEMU builds for this Docker host"
docker run --rm --privileged multiarch/qemu-user-static:register

echo "Downloading QEMU binaries"
for target_arch in aarch64 arm x86_64; do
  wget -N https://github.com/multiarch/qemu-user-static/releases/download/v2.9.1-1/x86_64_qemu-${target_arch}-static.tar.gz -O /tmp/x86_64_qemu-${target_arch}-static.tar.gz
  tar -xvf /tmp/x86_64_qemu-${target_arch}-static.tar.gz -C /tmp
done

echo "Building Dockerfile and image for $1, tag $2"

case $1 in
  amd64   ) qemu_arch="x86_64" ;;
  arm32v6 ) qemu_arch="arm" ;;
  arm64v8 ) qemu_arch="aarch64" ;;    
esac

cp ./tools/Docker-multiarch/Dockerfile ./tools/Docker-multiarch/Dockerfile.$1
sed -i "s|__BASEIMAGE_ARCH__|$1|g" ./tools/Docker-multiarch/Dockerfile.$1
sed -i "s|__QEMU_ARCH__|${qemu_arch}|g" ./tools/Docker-multiarch/Dockerfile.$1
if [ $1 = 'amd64' ]; then
  sed -i "/__CROSS_/d" ./tools/Docker-multiarch/Dockerfile.$1
else
  sed -i "s/__CROSS_//g" ./tools/Docker-multiarch/Dockerfile.$1
  cp /tmp/qemu-${qemu_arch}-static ./qemu-${qemu_arch}-static
fi

docker build -f ./tools/Docker-multiarch/Dockerfile.$1 -t difegue/lanraragi:$2-$1 .
echo "Image built, trying a push"
docker push difegue/lanraragi:$2-$1
