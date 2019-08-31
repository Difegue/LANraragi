FROM  avastsoftware/perl_critic:latest

LABEL "name"="perl-critic"
LABEL "maintainer"="Difegue <sugoi@cock.li>"
LABEL "version"="0.0.1"

LABEL "com.github.actions.name"="Perl Critic"
LABEL "com.github.actions.description"="Runs perlcritic on the codebase."
LABEL "com.github.actions.icon"="eye"
LABEL "com.github.actions.color"="orange"

RUN yum -y install bash ca-certificates coreutils jq 

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]