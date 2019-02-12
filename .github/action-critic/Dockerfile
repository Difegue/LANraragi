FROM avastsoftware/perl_critic

LABEL "name"="perl-critic"
LABEL "maintainer"="Difegue <sugoi@cock.li>"
LABEL "version"="0.0.1"

LABEL "com.github.actions.name"="Perl Critic"
LABEL "com.github.actions.description"="Runs perlcritic on the codebase."
LABEL "com.github.actions.icon"="eye"
LABEL "com.github.actions.color"="orange"

COPY ../.. .
ENTRYPOINT ["perlcritic"]
CMD ["./lib/* ./script/* ./tools/install.pl"]
