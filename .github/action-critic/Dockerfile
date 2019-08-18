FROM  scottw/alpine-perl:native

LABEL "name"="perl-critic"
LABEL "maintainer"="Difegue <sugoi@cock.li>"
LABEL "version"="0.0.1"

LABEL "com.github.actions.name"="Perl Critic"
LABEL "com.github.actions.description"="Runs perlcritic on the codebase."
LABEL "com.github.actions.icon"="eye"
LABEL "com.github.actions.color"="orange"

RUN apk add --no-cache bash ca-certificates coreutils jq && \
    cpanm Perl::Critic --notest

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]