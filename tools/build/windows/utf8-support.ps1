$vsPath = &"${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -property installationpath
Import-Module (Join-Path $vsPath "Common7\Tools\Microsoft.VisualStudio.DevShell.dll")
Enter-VsDevShell -VsInstallPath $vsPath -SkipAutomaticLocation

Set-Location .\win-dist\runtime\bin\
mt.exe -manifest ..\..\..\tools\build\windows\perl.exe.manifest "-outputresource:perl.exe;#1"
