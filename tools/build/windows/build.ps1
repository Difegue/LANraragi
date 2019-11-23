# --- LRR Windows build script ---

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

echo "🎌 Building up LRR Windows Package 🎌"

# Use Docker image
mv .\package\package.tar .\tools\build\windows\Karen\External\package.tar 

# Use Karen master
cd .\tools\build\windows\Karen
echo (Resolve-Path .\).Path
nuget restore

# Download LxRunOffline
Invoke-WebRequest https://github.com/DDoSolitary/LxRunOffline/releases/download/v3.4.0/LxRunOffline-v3.4.0.zip -outfile .\lxro.zip -verbose
echo (dir)
Unzip .\tools\build\windows\Karen\lxro.zip .\tools\build\windows\Karen\External\LxRunOffline

echo (Resolve-Path .\).Path
# Build Karen and Setup 
msbuild /p:Configuration=Release /p:Platform=x64

# Move the result .msi
mv .\Setup\bin\LANraragi.msi .

