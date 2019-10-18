# DOCKER-VERSION 0.3.4
FROM        alpine:latest
LABEL       git="https://github.com/Difegue/LANraragi" 

ENTRYPOINT ["sh", "/home/koyomi/lanraragi/tools/DockerSetup/entrypoint.sh"]

# Check application health
HEALTHCHECK --interval=1m --timeout=10s --retries=3 \
  CMD wget --quiet --tries=1 --no-check-certificate --spider \
  http://localhost:3000 || exit 1

#Default mojo server port
EXPOSE 3000

#Enable UTF-8 (might not do anything extra on alpine tho)
ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 \
    #rootless user id
    LRR_UID=9001 LRR_GID=9001 \
    #Environment variables overridable by the user on container deployment
    LRR_NETWORK=http://*:3000 \
    # extra variables
    EV_EXTRA_DEFS=-DEV_NO_ATFORK

RUN \
  if [ $(getent group ${LRR_GID}) ]; then \
    adduser -D -u ${LRR_UID} koyomi; \
  else \
    addgroup -g ${LRR_GID} koyomi && \
    adduser -D -u ${LRR_UID} -G koyomi koyomi; \
fi

WORKDIR /home/koyomi/lanraragi

#Copy cpanfile and install script before copying the entire context
#This allows for Docker cache to preserve cpan dependencies
COPY --chown=koyomi:koyomi /tools tools
COPY --chown=koyomi:koyomi /package.json package.json

# Make scripts executable + Run the install script as root
RUN chmod +x ./tools/DockerSetup/install-everything.sh ./tools/DockerSetup/entrypoint.sh && sh ./tools/DockerSetup/install-everything.sh

#Copy remaining LRR files from context  
COPY --chown=koyomi:koyomi /lib lib
COPY --chown=koyomi:koyomi /public public
COPY --chown=koyomi:koyomi /script script
COPY --chown=koyomi:koyomi /templates templates
COPY --chown=koyomi:koyomi /tests tests
COPY --chown=koyomi:koyomi /lrr.conf lrr.conf
COPY --chown=koyomi:koyomi /COPYING COPYING

# Persistent volumes
VOLUME [ "/home/koyomi/lanraragi/content" ]
