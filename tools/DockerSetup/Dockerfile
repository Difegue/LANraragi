# DOCKER-VERSION 0.3.4
FROM        debian:stretch
MAINTAINER  dfug sugoi@cock.li

#Base LRR dependencies and essential tools for next commands
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y curl make gnupg cpanminus redis-server unar imagemagick libimage-magick-perl build-essential supervisor locales locales-all

#npm
RUN curl -sL https://deb.nodesource.com/setup_9.x | bash -
RUN apt-get install -y nodejs

#Copy cpanfile before copying the entire context - allows for Docker cache to preserve cpan dependencies
COPY /tools/cpanfile /home/koyomi/cpanfile
RUN cpanm --installdeps /home/koyomi/.

#Copy LRR files from context (better than git!)
COPY / /home/koyomi/lanraragi/
RUN cd /home/koyomi/lanraragi && npm run lanraragi-installer install-full

#Default mojo server port
EXPOSE 3000

#Special redis conf to write DB in content directory and disable daemonization
COPY ./tools/DockerSetup/redis.conf /home/koyomi/redis.conf
COPY ./tools/DockerSetup/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

#Enable UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

CMD ["/usr/bin/supervisord"]