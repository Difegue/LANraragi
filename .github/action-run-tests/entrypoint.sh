#!/bin/sh

echo "🎌 Running LRR Test Suite 🎌"

# Run the perl tests on the repo
prove -l tests/*.t

