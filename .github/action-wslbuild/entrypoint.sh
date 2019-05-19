#!/bin/sh

echo "🎌 Building up LRR Windows Package 🎌"

mkdir win_package

# Move package.tar to folder 
mv package.tar win_package

# Download LxRunOffline and Karen
wget https://github.com/DDoSolitary/LxRunOffline/releases/download/v3.3.3/LxRunOffline-v3.3.3.zip
wget https://github.com/Difegue/Karen/releases/download/v1.0/Karen-v1.zip

# Unzip them to installer folder under the desired names
unzip LxRunOffline-v3.3.3.zip win_package/LxRunOffline
unzip Karen-v1.zip win_package/Bootloader

# Copy installer script to root 
mv win_package/Bootloader/Karen-Installer.ps1 win_package/install.ps1

# Zip installer folder and we're done
 zip -r win_package.zip win_package