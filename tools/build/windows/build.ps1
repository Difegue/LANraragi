# --- LRR Windows build script ---

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

echo "🎌 Building up LRR Windows Package 🎌"

# Use Karen master
cd Karen
nuget restore

# Use Docker image
mv ../package.tar External/package.tar 

# Download LxRunOffline
wget https://github.com/DDoSolitary/LxRunOffline/releases/download/v3.4.0/LxRunOffline-v3.4.0.zip -outfile lxro.zip
Unzip lxro.zip External/LxRunOffline

# Build Karen and Setup
msbuild /p:Configuration=Release /p:Platform=x64

# Move the result .msi
mv .\Setup\bin\LANraragi.msi .

