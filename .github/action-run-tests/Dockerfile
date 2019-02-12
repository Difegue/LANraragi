FROM difegue/lanraragi:nightly
# Use the base LRR container to have a prepared test environment

LABEL "name"="lrr-test"
LABEL "maintainer"="Difegue <sugoi@cock.li>"
LABEL "version"="0.0.1"

LABEL "com.github.actions.name"="LANraragi Test Suite"
LABEL "com.github.actions.description"="Runs the LRR tests."
LABEL "com.github.actions.icon"="check"
LABEL "com.github.actions.color"="purple"

#Fully copy the repo and run tests
COPY . .
ENTRYPOINT ["perl"]
CMD ["./script/lanraragi test tests/*.t"]

