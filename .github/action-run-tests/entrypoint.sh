#!/bin/sh

echo "🎌 Running LRR Test Suite 🎌"

# Start a redis server instance and run the perl tests on the repo
/usr/bin/redis-server /home/koyomi/redis.conf & perl ./script/lanraragi test tests/*.t

