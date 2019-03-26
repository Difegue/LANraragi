# DOCKER-VERSION 0.3.4
FROM        alpine:latest
LABEL       git="https://github.com/Difegue/LANraragi" 

#Environment variables overridable by the user on container deployment
ENV LRR_NETWORK http://*:3000
ENV LRR_UID 1337

RUN adduser -D -u ${LRR_UID} -g '' koyomi && apk add sudo

#Switch to our newly created user, using the 1337 UID or one given by the base system
USER koyomi
WORKDIR ${HOME}/lanraragi

#Copy cpanfile and install script before copying the entire context
#This allows for Docker cache to preserve cpan dependencies
COPY /tools tools
COPY /package.json package.json

ENV EV_EXTRA_DEFS -DEV_NO_ATFORK
#Run the install script as root
RUN sudo chmod 755 ./tools/DockerSetup/install-everything.sh && sudo root ./tools/DockerSetup/install-everything.sh

#Copy remaining LRR files from context
COPY / ${HOME}/lanraragi

#Default mojo server port
EXPOSE 3000

#Enable UTF-8
ENV MUSL_LOCPATH /usr/local/share/i18n/locales/musl
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

#Start supervisor with the Docker configuration
#This also loads the redis config to write DB in content directory and disable daemonization
ENTRYPOINT ["supervisord", "--nodaemon", "--configuration", "~/tools/DockerSetup/supervisord.conf"]
