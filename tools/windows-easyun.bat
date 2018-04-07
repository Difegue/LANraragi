@echo off
rem LRR Windows Boot Script - super crude edition

echo LANraragi Easy-Windows Startup
echo ==============
echo 

rem Check through berrybrew if the correct perl version is installed
echo Checking for Perl installation...

IF EXIST C:\berrybrew\5.26.0_64 goto :exec ELSE goto :brewing

:exec
rem add unar/lsar to path and start redis-server + LRR with daemon
echo Perl installation good to go! Starting up...
SET PATH=%PATH%;%~dp0unar
set PATH=C:\berrybrew\5.26.0_64\perl\site\bin;C:\berrybrew\5.26.0_64\perl\bin;C:\berrybrew\5.26.0_64\c\bin;%PATH%

.\redis\redis-server.exe &
cd .\lanraragi &
perl .\script\lanraragi daemon 
exit 0

rem If install perl alongside the magick ppm and the cpan deps
:brewing
echo No compatible Perl installation detected - Asking berrybrew to brew one up.
.\berrybrew\bin\berrybrew.exe install 5.26.0_64
echo Installing PerlMagick...You'll have to press Enter at least once.
.\berrybrew\bin\berrybrew.exe exec --with 5.26.0_64 ppm install Image-Magick
echo Installing LRR dependencies.
.\berrybrew\bin\berrybrew.exe exec --with 5.26.0_64 cpanm --installdeps ./lanraragi/tools/. --force
echo All done! Moving up.
goto :exec
