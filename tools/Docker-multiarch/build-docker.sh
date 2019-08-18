#!/bin/sh
# Script for building multi-arch LRR images using QEMU when necessary. 
# Shamelessly lifted off https://lobradov.github.io/Building-docker-multiarch-images

echo "Enabling QEMU builds for this Docker host"
docker run --rm --privileged multiarch/qemu-user-static:register

echo "Downloading QEMU binaries"
for target_arch in aarch64 arm x86_64; do
  wget -N https://github.com/multiarch/qemu-user-static/releases/download/v2.9.1-1/x86_64_qemu-${target_arch}-static.tar.gz
  tar -xvf x86_64_qemu-${target_arch}-static.tar.gz
done

echo "Building per-architecture Dockerfiles and images for $1"
for docker_arch in amd64 arm32v6 arm64v8; do
  case ${docker_arch} in
    amd64   ) qemu_arch="x86_64" ;;
    arm32v6 ) qemu_arch="arm" ;;
    arm64v8 ) qemu_arch="aarch64" ;;    
  esac
  cp ./tools/Docker-multiarch/Dockerfile Dockerfile.${docker_arch}
  sed -i "s|__BASEIMAGE_ARCH__|${docker_arch}|g" Dockerfile.${docker_arch}
  sed -i "s|__QEMU_ARCH__|${qemu_arch}|g" Dockerfile.${docker_arch}
  if [ ${docker_arch} = 'amd64' ]; then
    sed -i "/__CROSS_/d" Dockerfile.${docker_arch}
  else
    sed -i "s/__CROSS_//g" Dockerfile.${docker_arch}
  fi

  docker build -f Dockerfile.${docker_arch} -t difegue/lanraragi:$1-${docker_arch} .
done