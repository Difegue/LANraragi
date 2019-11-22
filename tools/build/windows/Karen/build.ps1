# --- LRR Windows build script ---

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

echo "🎌 Building up LRR Windows Package 🎌"

# Clone Karen master
git clone https://github.com/Difegue/Karen.git
cd Karen
nuget restore

# Export Docker image 
docker export --output=External/package.tar difegue/lanraragi

# Download LxRunOffline
wget https://github.com/DDoSolitary/LxRunOffline/releases/download/v3.4.0/LxRunOffline-v3.4.0.zip -outfile lxro.zip
Unzip lxro.zip External/LxRunOffline

# Build Karen and Setup
msbuild /p:Configuration=Release /p:Platform=x64

# Move the result .msi
mv .\Setup\bin\LANraragi.msi .

