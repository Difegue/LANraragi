#!/bin/sh

echo "🎌 Building up LRR Windows Package 🎌"

mkdir win_package

# Export and squash image
# I'd like to use docker export here instead of squashing tars by hand, but Github Actions doesn't allow it. eeeh...
docker save --output save.tar difegue/lanraragi
tar -xf save.tar --wildcards "*.tar"
mkdir squashed
find . -mindepth 2 -type f -iname "*.tar" -print0 -exec tar -xvf {} -C squashed \; 
find squashed -printf "%P\n" -type f -o -type l -o -type d | tar -cf package.tar --no-recursion -C squashed -T -

# Move package.tar to folder 
mv package.tar win_package

# Download LxRunOffline and Karen
wget https://github.com/DDoSolitary/LxRunOffline/releases/download/v3.3.3/LxRunOffline-v3.3.3.zip
wget https://github.com/Difegue/Karen/releases/download/v1.0/Karen-v1.zip

# Unzip them to installer folder under the desired names
unzip -d win_package/LxRunOffline LxRunOffline-v3.3.3.zip 
unzip -d win_package/Bootloader Karen-v1.zip 

# Copy installer script to root 
mv win_package/Bootloader/Karen-Installer.ps1 win_package/install.ps1

# Zip installer folder and we're done
zip -r win_package.zip win_package
