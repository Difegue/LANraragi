#!/bin/sh
# Use in conjunction with build-docker.sh
# If not logged to a Docker repo this will obviously fail."

echo "Starting experimental Docker"
sudo service docker stop
sudo dockerd --experimental 

echo "Pushing multi-arch manifest"
docker manifest create difegue/lanraragi:$1 difegue/lanraragi:$1-amd64 difegue/lanraragi:$1-arm32v6 difegue/lanraragi:$1-arm64v8 
docker manifest annotate difegue/lanraragi:$1 difegue/lanraragi:$1-arm32v6 --os linux --arch arm
docker manifest annotate difegue/lanraragi:$1 difegue/lanraragi:$1-arm64v8 --os linux --arch arm64 --variant armv8
docker manifest push difegue/lanraragi:$1
