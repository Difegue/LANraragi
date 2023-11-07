# --- LRR Windows build script ---

echo "🎌 Building up LRR Windows Package 🎌"
echo "Inferring version from package.json..."

$json = (Get-Content "package.json" -Raw) | ConvertFrom-Json
$version = $json.version
echo "Version is $version"
$env:LRR_VERSION_NUM=$version

# Use Docker image
mv .\package\package.tar .\tools\build\windows\Karen\External\package.tar 

# Download and unpack Redis
cd .\tools\build\windows\Karen\External
Invoke-WebRequest -Uri https://github.com/redis-windows/redis-windows/releases/download/7.0.14/Redis-7.0.14-Windows-x64.tar.gz -OutFile .\redis.tar.gz
tar -xzf .\redis.tar.gz
rm .\redis.tar.gz
mv .\Redis-7.0.14-Windows-x64 .\Redis

# Copy redis.conf to redis folder
cp ..\..\..\docker\redis.conf .\Redis\redis.conf

# Use Karen master
cd ..
echo (Resolve-Path .\).Path
nuget restore

# Build Karen and Setup 
msbuild /p:Configuration=Release

Get-FileHash .\Setup\bin\LANraragi.msi | Format-List