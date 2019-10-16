FROM difegue/lanraragi:nightly
# Use the base LRR container to have a prepared test environment

LABEL "name"="lrr-test"
LABEL "maintainer"="Difegue <sugoi@cock.li>"
LABEL "version"="0.0.1"

LABEL "com.github.actions.name"="LANraragi Test Suite"
LABEL "com.github.actions.description"="Runs the LRR tests."
LABEL "com.github.actions.icon"="check"
LABEL "com.github.actions.color"="purple"

USER root

# Re-add devtools
RUN apk add perl-utils perl-dev wget g++ make

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

