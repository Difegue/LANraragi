@echo off
rem LRR Windows Boot Script

echo LANraragi Windows QuickStarter
echo ==============
echo 

rem Check through berrybrew if the correct perl version is installed
:check
echo Checking for Perl installation...

IF EXIST C:\berrybrew\5.26.0_64 (
	goto :exec 
) ELSE (
	goto :brewing
) 

rem add perl/unar/lsar to path and start redis-server + LRR with daemon
:exec
SET PATH=%PATH%;%~dp0unar;%~dp0redis
set PATH=C:\berrybrew\5.26.0_64\perl\site\bin;C:\berrybrew\5.26.0_64\perl\bin;C:\berrybrew\5.26.0_64\c\bin;%PATH%
echo Perl OK. Running LANraragi Installer...
cd .\lanraragi
perl .\tools\install.pl install-back

echo All dependencies up to date! Starting...
cd ..
start cmd /c .\redis\redis-server.exe .\redis\redis.windows-lrr.conf
cd .\lanraragi 
perl .\script\lanraragi daemon 
exit 0


rem --------------------------
rem Install perl alongside the magick ppm and the cpan deps
:brewing
echo No compatible Perl installation detected - Asking berrybrew to brew one up.
.\berrybrew\bin\berrybrew.exe install 5.26.0_64
echo Installing PerlMagick...You'll have to press Enter at least once.
.\berrybrew\bin\berrybrew.exe exec --with 5.26.0_64 ppm install Image-Magick
echo All done! Moving up.
goto :check
