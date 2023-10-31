#!/bin/sh

echo "🎌 Running LRR Test Suite 🎌"

# Install cpan deps in case some are missing
perl ./tools/install.pl install-back

# Run the perl tests on the repo
prove -r -l -v tests/

