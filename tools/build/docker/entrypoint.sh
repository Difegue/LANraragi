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

#Crash with an error if content folder doesn't exist
if [ ! -d "/home/koyomi/lanraragi/content" ]; then
  echo "Content folder doesn't exist! Please ensure your Docker mappings are correct."
  exit 1
fi

#Ensure database is writable
chown koyomi /home/koyomi/lanraragi/content/database.rdb
chmod +rw /home/koyomi/lanraragi/content/database.rdb

#Ensure thumbnail folder is writable
chown -R koyomi /home/koyomi/lanraragi/content/thumb 
chmod 744 /home/koyomi/lanraragi/content/thumb

#Ensure log folder is writable
mkdir /home/koyomi/lanraragi/log
chown -R koyomi /home/koyomi/lanraragi/log
chmod 744 /home/koyomi/lanraragi/log

#Ensure temp folder is writable
mkdir /home/koyomi/lanraragi/public/temp
chown -R koyomi /home/koyomi/lanraragi/public/temp
chmod 744 /home/koyomi/lanraragi/public/temp

#Remove hypnotoad and shinobu pid files
rm /home/koyomi/lanraragi/script/hypnotoad.pid
rm /home/koyomi/lanraragi/.shinobu-pid

export HOME=/home/koyomi

# https://redis.io/topics/faq#background-saving-fails-with-a-fork-error-under-linux-even-if-i-have-a-lot-of-free-ram
OVERCOMMIT=$(cat /proc/sys/vm/overcommit_memory)
if [ $OVERCOMMIT -eq 0 ]
then
    echo "WARNING: overcommit_memory is set to 0! This might lead to background saving errors if your database is too large."
    echo "Please check https://redis.io/topics/faq#background-saving-fails-with-a-fork-error-under-linux-even-if-i-have-a-lot-of-free-ram for details."
fi

#Start supervisor with the Docker configuration
#This also loads the redis config to write DB in content directory and disable daemonization
if [ $USER_ID -eq 0 ] && [ $GROUP_ID -eq 0 ] 
then
    echo "UID and GID set to 0, running as root. You've been warned!"
    exec supervisord --nodaemon --configuration ./tools/build/docker/supervisord.conf
else   
    exec su-exec koyomi supervisord --nodaemon --configuration ./tools/build/docker/supervisord.conf
fi