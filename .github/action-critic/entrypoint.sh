#!/bin/bash

# Return neutral error code if critic fails as it isn't a showstopper for now
violations=$(perlcritic ./lib/* ./script/* ./tools/install.pl)
success=$?
echo "$violations"

if [ $success -ne 0 ]; then
    #Report the critic violations in a comment on the commit

    COMMENT="#### Perl Critic Notes (Level 5 - gentle):
    <pre>$violations</pre>"
    PAYLOAD=$(echo '{}' | jq --arg body "$COMMENT" '.body = $body')
    COMMIT_URL="https://api.github.com/repos/"$GITHUB_REPOSITORY/commits/$GITHUB_SHA/comments
    echo "Pushing payload to $COMMIT_URL"
    curl -s -S -H "Authorization: token $GITHUB_TOKEN" --header "Content-Type: application/json" --data "$PAYLOAD" "$COMMIT_URL" > /dev/null

    exit 78
fi
exit $success