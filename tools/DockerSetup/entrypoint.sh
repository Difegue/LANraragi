#!/bin/sh

USER_ID=${LRR_UID}
GROUP_ID=${LRR_GID}

echo "Starting LANraragi with UID/GID : $USER_ID/$GROUP_ID"

#Update the koyomi user, using the specified uid/gid. 
#This solves permission problems on the content folder if the Docker user sets the same uid as the owner of the folder.
usermod -u $USER_ID koyomi
groupmod -g $GROUP_ID koyomi

#Ensure LRR folder is writable
chown koyomi /home/koyomi/lanraragi
chmod 744 /home/koyomi/lanraragi
export HOME=/home/koyomi

#Start supervisor with the Docker configuration
#This also loads the redis config to write DB in content directory and disable daemonization
exec su-exec koyomi supervisord --nodaemon --configuration ./tools/DockerSetup/supervisord.conf