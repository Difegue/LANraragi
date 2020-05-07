# DOCKER-VERSION 0.3.4
FROM        alpine:latest
LABEL       git="https://github.com/Difegue/LANraragi"

ENV S6_OVERLAY_RELEASE v1.21.8.0
ENV S6_KEEP_ENV 1

# terminate if we can't run stage2 (fix-attrs/cont-init)
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS 2

# wait 10s before KILLing
ENV S6_KILL_GRACETIME 10000

ENTRYPOINT ["/init"] # s6

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


# we use s6-overlay-nobin to just pull in the s6-overlay arch agnostic (shell)
# components, since we apk install the binaries of s6 later which are arch specific
ADD https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_RELEASE}/s6-overlay-nobin.tar.gz /tmp/s6-overlay-nobin.tar.gz
RUN tar -C / -xzf /tmp/s6-overlay-nobin.tar.gz && rm -f /tmp/s6-overlay-nobin.tar.gz


WORKDIR /home/koyomi/lanraragi

#Copy cpanfile and install script before copying the entire context
#This allows for Docker cache to preserve cpan dependencies
COPY --chown=koyomi:koyomi /tools/cpanfile /tools/install.pl tools/
COPY --chown=koyomi:koyomi /package.json package.json

# Install deps (we install Linux::Inotify2 manually since it's not in the base cpanfile as it doesn't build on macOS)
RUN apk add --update perl perl-io-socket-ssl perl-dev redis libarchive-dev libbz2 openssl-dev zlib-dev \
imagemagick imagemagick-perlmagick libwebp-tools \
g++ make pkgconf gnupg wget curl nodejs nodejs-npm \
shadow s6 s6-portable-utils && \
curl -L https://cpanmin.us | perl - App::cpanminus && \
cpanm Linux::Inotify2 && \
cd tools && cpanm --notest --installdeps . -M https://cpan.metacpan.org && cd .. && \
npm run lanraragi-installer install-front && \
apk del perl-dev g++ make gnupg wget curl nodejs nodejs-npm openssl-dev && \
rm -rf /root/.cpanm/* /root/.npm/ /usr/local/share/man/* node_modules /var/cache/apk/*

#Copy remaining LRR files from context
# consider chowning in s6 setup scripts instead
COPY --chown=koyomi:koyomi /lib lib
COPY --chown=koyomi:koyomi /public public
COPY --chown=koyomi:koyomi /script script
COPY --chown=koyomi:koyomi /templates templates
COPY --chown=koyomi:koyomi /tests tests
COPY --chown=koyomi:koyomi /lrr.conf lrr.conf
COPY /tools/build/docker/redis.conf /etc/redis.conf
COPY /tools/build/docker/wsl.conf /etc/wsl.conf
COPY /tools/build/docker/s6/cont-init.d/ /etc/cont-init.d/
COPY /tools/build/docker/s6/services.d/ /etc/services.d/
# keep this out for now and do it in cont-init.d instead
#COPY /tools/build/docker/s6/fix-attrs.d/ /etc/fix-attrs.d/

# Persistent volumes
VOLUME [ "/home/koyomi/lanraragi/content" ]
VOLUME [ "/home/koyomi/lanraragi/database"]
