# --- LRR Windows build script ---

echo "🎌 Building up LRR Windows Package 🎌"
echo "Inferring version from package.json..."

$json = (Get-Content "package.json" -Raw) | ConvertFrom-Json
$version = $json.version
echo "Version is $version"
$env:LRR_VERSION_NUM=$version

# Use Docker image
mv .\package\package.tar .\tools\build\windows\Karen\External\package.tar 

# Use Karen master
cd .\tools\build\windows\Karen
echo (Resolve-Path .\).Path
nuget restore

# Build Karen and Setup 
msbuild /p:Configuration=Release

Get-FileHash .\Setup\bin\LANraragi.msi | Format-List
mv .\Setup\bin\LANraragi.msi .\LRR_WSL2.msi

# Do it again for legacy image if it exists
cd ..\..\..\..
if (Test-Path .\package-legacy\package.tar) {
    echo "WSL1 package found, building legacy version..."
} else {
    echo "No WSL1 package found, skipping legacy build..."
    exit 0
}
mv .\package-legacy\package.tar .\tools\build\windows\Karen\External\package.tar 
cd .\tools\build\windows\Karen
msbuild /p:Configuration=Release /p:DefineConstants=WSL1_LEGACY

Get-FileHash .\Setup\bin\LANraragi.msi | Format-List
mv .\Setup\bin\LANraragi.msi .\LRR_WSL1.msi