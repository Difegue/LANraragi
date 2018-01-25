# DOCKER-VERSION 0.3.4
FROM        debian:stretch
MAINTAINER  dfug sugoi@cock.li

#Base LRR dependencies and essential tools for next commands
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y curl make gnupg cpanminus redis-server unar imagemagick libimage-magick-perl build-essential

#npm
RUN curl -sL https://deb.nodesource.com/setup_9.x | bash -
RUN apt-get install -y nodejs

#Copy LRR files from context (better than git!)
COPY / /home/koyomi/lanraragi/
RUN cd /home/koyomi/lanraragi && npm run lanraragi-installer install-full

#Setup content directory so it stores everything: database, thumbnails and (of course) archives 
#This allows the Docker user to have everything in one volume mounted on /content
#Symlink to content folder is done on container start - see supervisord.conf
RUN cd /home/koyomi/lanraragi/public && rm -r thumb 

RUN apt-get install -y supervisor

#Default mojo server port
EXPOSE 3000

#Special redis conf to write DB in content directory and disable daemonization
COPY ./tools/DockerSetup/redis.conf /home/koyomi/redis.conf
COPY ./tools/DockerSetup/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

CMD ["/usr/bin/supervisord"]