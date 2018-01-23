# DOCKER-VERSION 0.3.4
FROM        debian:stretch
MAINTAINER  dfug sugoi@cock.li

#Base LRR dependencies and essential tools for next commands
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y curl make git gnupg cpanminus redis-server unar imagemagick libimage-magick-perl 

#npm
RUN curl -sL https://deb.nodesource.com/setup_9.x | bash -
RUN apt-get install -y nodejs

#Clone latest LRR
RUN git clone https://github.com/Difegue/LANraragi.git /home/koyomi/lanraragi
RUN cd /home/koyomi/lanraragi && npm run lanraragi-installer install-full

#Setup content directory so it stores everything: database, thumbnails and (of course) archives 
#This allows the Docker user to have everything in one volume mounted on /content
RUN mkdir /home/koyomi/lanraragi/content/thumb
RUN cd /home/koyomi/lanraragi/public && rm -r thumb 
RUN ln -s /home/koyomi/lanraragi/content/thumb thumb

RUN apt-get install -y supervisor

#Default mojo daemon port
EXPOSE 3000

#Special redis conf to write DB in content directory
COPY redis.conf /etc/redis/redis.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

CMD ["/usr/bin/supervisord"]