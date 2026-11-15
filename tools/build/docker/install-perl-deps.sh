#!/bin/sh

set -e

# Run it with increased jobs to improve performance
export MAKEFLAGS="-j$(nproc)"

# Redirect perl dependencies to the home directory
eval "$(perl -Mlocal::lib)"

# Install cpanm
curl -L https://cpanmin.us | perl - App::cpanminus

cd ./tools

# Install the LRR dependencies proper
cpanm --notest --installdeps . --configure-timeout 300

cd ..

perl ./tools/install.pl install-back
