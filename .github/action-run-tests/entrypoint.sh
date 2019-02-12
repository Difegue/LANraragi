#!/bin/sh

# Just run the perl tests on the repo
echo "\n🎌 Running LRR Test Suite 🎌\n"
echo ls -l
perl ./script/lanraragi test tests/*.t

