#!/bin/sh
# Use in conjunction with build-docker.sh
# If not logged to a Docker repo this will obviously fail."
# Run as root!

echo "Enabling experimental Docker"
echo '{ "experimental": true }' | sudo tee /etc/docker/daemon.json
sudo service docker restart

echo "Pushing previously built images"
for docker_arch in amd64 arm32v6 arm64v8; do
  docker push difegue/lanraragi:$1-${docker_arch}
done

echo "Pushing multi-arch manifest"
docker manifest create difegue/lanraragi:$1 difegue/lanraragi:$1-amd64 difegue/lanraragi:$1-arm32v6 difegue/lanraragi:$1-arm64v8 
docker manifest annotate difegue/lanraragi:$1 difegue/lanraragi:$1-arm32v6 --os linux --arch arm
docker manifest annotate difegue/lanraragi:$1 difegue/lanraragi:$1-arm64v8 --os linux --arch arm64 --variant armv8
docker manifest push difegue/lanraragi:$1
