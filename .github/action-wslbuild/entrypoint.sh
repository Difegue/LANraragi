#!/bin/sh

echo "🎌 Building up LRR Windows Package 🎌"

mkdir win_package

# Export and squash image
# I'd like to use docker export here instead of squashing tars by hand, but Github Actions doesn't allow it. eeeh...
docker save --output save.tar difegue/lanraragi
tar -xf save.tar --wildcards "*.tar"
mkdir squashed
find . -mindepth 2 -type f -iname "*.tar" -print0 -exec tar -xf {} -C squashed \; 

# Create missing directories - This is usually handled by the Docker entrypoint but we don't use it here.
mkdir squashed/home/koyomi/lanraragi/log
mkdir squashed/home/koyomi/lanraragi/public/temp

# Tar it all back up
find squashed -printf "%P\n" -type f -o -type l -o -type d | tar -cf package.tar --no-recursion -C squashed -T -

# Move package.tar to folder 
mv package.tar win_package

# Download LxRunOffline and Karen
wget https://github.com/DDoSolitary/LxRunOffline/releases/download/v3.3.3/LxRunOffline-v3.3.3.zip
wget https://github.com/Difegue/Karen/releases/latest/download/Karen.zip

# Unzip them to installer folder under the desired names
unzip -d win_package/LxRunOffline LxRunOffline-v3.3.3.zip 
unzip -d win_package/Bootloader Karen.zip 

# Copy installer script to root 
mv win_package/Bootloader/Karen-Installer.ps1 win_package/install.ps1

# Zip installer folder and we're done
zip -r LANraragi_Windows_Installer.zip win_package
