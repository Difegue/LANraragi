FROM docker:stable
# Use the base LRR container to have a prepared test environment

LABEL "name"="lrr-wslbuild"
LABEL "maintainer"="Difegue <sugoi@cock.li>"
LABEL "version"="0.0.1"

LABEL "com.github.actions.name"="Package Windows Installer"
LABEL "com.github.actions.description"="Export built docker image and bundle with Karen and LxRunOffline."
LABEL "com.github.actions.icon"="truck"
LABEL "com.github.actions.color"="blue"

# Add needed utilities to create the WSL tarball and download tools
RUN apk add zip unzip wget tar 

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

