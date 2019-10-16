#!/bin/sh

echo "🎌 Running LRR Test Suite 🎌"

cpanm Test::MockObject

# Start a redis server instance
/usr/bin/redis-server --daemonize yes

# Run the perl tests on the repo
prove -l tests/*.t

