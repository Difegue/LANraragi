# DOCKER-VERSION 0.3.4
FROM        alpine:3.20
LABEL       git="https://github.com/Difegue/LANraragi"
ARG INSTALL_PARAMETER

ENV S6_KEEP_ENV 1

# warn if we can't run stage2 (fix-attrs/cont-init)
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS 1

# wait 10s before KILLing
ENV S6_KILL_GRACETIME 10000
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME 0

# s6: The init is provided by alpine's s6-overlay package, hence the double slash.
# See https://pkgs.alpinelinux.org/contents?branch=v3.14&name=s6-overlay&arch=x86&repo=community
ENTRYPOINT ["//init"]

# Check application health
HEALTHCHECK --interval=1m --timeout=10s --retries=3 \
  CMD wget --quiet --tries=1 --no-check-certificate --spider -Y off \
  http://127.0.0.1:3000 || exit 1

#Default mojo server port
EXPOSE 3000

# Enable UTF-8 (might not do anything extra on alpine tho)
ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 \
    # rootless user id
    LRR_UID=9001 LRR_GID=9001 \
    # Environment variables overridable by the user on container deployment
    LRR_NETWORK=http://*:3000 \
    # extra variables
    EV_EXTRA_DEFS=-DEV_NO_ATFORK \
    # Enable automatic http proxy detection for mojo
    MOJO_PROXY=1 \
    # Allow Mojo to automatically pick up the X-Forwarded-For and X-Forwarded-Proto headers
    MOJO_REVERSE_PROXY=1 \
    # Attempt to fix file permissions automatically
    LRR_AUTOFIX_PERMISSIONS=1

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
COPY --chown=koyomi:koyomi /tools/cpanfile /tools/install.pl /tools/build/docker/install-everything.sh tools/
COPY --chown=koyomi:koyomi /package.json package.json
COPY --chown=koyomi:koyomi /package-lock.json package-lock.json

# Run the install script as root
RUN sh ./tools/install-everything.sh $INSTALL_PARAMETER

#Copy remaining LRR files from context
COPY --chown=koyomi:koyomi /lib lib
COPY --chown=koyomi:koyomi /public public
COPY --chown=koyomi:koyomi /script script
COPY --chown=koyomi:koyomi /templates templates
COPY --chown=koyomi:koyomi /tests tests
COPY --chown=koyomi:koyomi /lrr.conf lrr.conf
COPY --chown=koyomi:koyomi /tools/build/docker/redis.conf tools/build/docker/
COPY /tools/build/docker/wsl.conf /etc/wsl.conf
#Copy s6-overlay 3.x services
#Uses a system-d like definition that can't be use in 2.x
COPY /tools/build/docker/s6/s6-rc.d/ /etc/s6-overlay/s6-rc.d/
#Copy setup script as-is since no changes are needed between 2.x and 3.x
COPY /tools/build/docker/s6/cont-init.d/01-lrr-setup /etc/s6-overlay/s6-rc.d/init/
#COPY /tools/build/docker/s6/fix-attrs.d/ /etc/fix-attrs.d/

# Persistent volumes
VOLUME [ "/home/koyomi/lanraragi/content" ]
VOLUME [ "/home/koyomi/lanraragi/thumb" ]
VOLUME [ "/home/koyomi/lanraragi/database"]
VOLUME [ "/home/koyomi/lanraragi/lib/LANraragi/Plugin/Sideloaded" ]
