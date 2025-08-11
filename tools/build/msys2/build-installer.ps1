# --- LRR Windows build script V2 ---

echo "🎌 Building up LRR Windows Package 🎌"
echo "Inferring version from package.json..."

$json = (Get-Content "package.json" -Raw) | ConvertFrom-Json
$version = $json.version
echo "Version is $version"
$env:LRR_VERSION_NUM=$version

# Copy vfs
Copy-Item -Path "./win-dist" -Destination "./tools/build/msys2/Karen/Karen/bin/win-x64/publish/lanraragi" -Recurse -Container

# Build Karen
Set-Location "./tools/build/msys2/Karen"
dotnet publish --nologo -r win-x64 -o Karen\bin\win-x64\publish Karen\Karen.csproj

# Build Setup
MSBuild -nologo -v:minimal /p:RestorePackagesConfig=true /t:Restore
MSBuild Setup\Setup.csproj -nologo -v:minimal /p:Configuration=Release /p:Platform=AnyCPU

Get-FileHash "./Setup/bin/LANraragi.msi" | Format-List
