FROM docker:stable
# Use the base LRR container to have a prepared test environment

LABEL "name"="lrr-wslbuild"
LABEL "maintainer"="Difegue <sugoi@cock.li>"
LABEL "version"="0.0.1"

LABEL "com.github.actions.name"="Package Windows Installer"
LABEL "com.github.actions.description"="Export built docker image and bundle with Karen and LxRunOffline."
LABEL "com.github.actions.icon"="truck"
LABEL "com.github.actions.color"="blue"

# install python and entrypoint reqs
RUN apk add zip unzip wget tar python py-pip python-dev

# Install docker-squash as we can't easily install experimental features here
# Docker export is also off the table due to Github Actions restrictions.
RUN pip install docker-squash

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

