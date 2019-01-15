# DOCKER-VERSION 0.3.4
FROM        debian:stretch
LABEL       git="https://github.com/Difegue/LANraragi" 

#Base LRR dependencies and essential tools for next commands
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl make gnupg cpanminus redis-server unar libpng-dev libjpeg-dev build-essential supervisor locales locales-all libssl-dev zlib1g-dev && \
    curl -sL https://deb.nodesource.com/setup_9.x | bash - && \ 
    apt-get install -y --no-install-recommends nodejs && rm -rf /var/lib/apt/lists/*

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
