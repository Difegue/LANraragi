#!/bin/sh

echo "🎌 Running LRR Test Suite 🎌"

# Run the perl tests on the repo
prove -I /home/koyomi/perl5/lib/perl5 -r -l -v tests/
