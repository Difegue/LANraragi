FROM debian:stable
# Use the base LRR container to have a prepared test environment

LABEL "name"="lrr-wslbuild"
LABEL "maintainer"="Difegue <sugoi@cock.li>"
LABEL "version"="0.0.1"

LABEL "com.github.actions.name"="Package Windows Installer"
LABEL "com.github.actions.description"="Runs the LRR tests."
LABEL "com.github.actions.icon"="truck"
LABEL "com.github.actions.color"="blue"

USER root

RUN apt-get install zip unzip wget

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

