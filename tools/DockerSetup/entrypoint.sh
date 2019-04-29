#!/bin/sh


# Add local user
# Either use the LOCAL_USER_ID if passed in at runtime or
# fallback

USER_ID=${LRR_UID:-9001}

echo "Starting LANraragi with UID : $USER_ID"

#Add the koyomi user, using the specified uid. 
#This solves permission problems on the content folder if the Docker user sets the same uid as the owner of the folder.
adduser -D -u $USER_ID -g '' koyomi 
#Fix permissions before stepping down
chown -R koyomi /home/koyomi/lanraragi
chmod -R 777 /home/koyomi/lanraragi

export HOME=/home/koyomi

#Start supervisor with the Docker configuration
#This also loads the redis config to write DB in content directory and disable daemonization
exec su-exec koyomi supervisord --nodaemon --configuration ./tools/DockerSetup/supervisord.conf



