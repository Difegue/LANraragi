# LRR Windows Boot Script

# add perl/unar/lsar to path and start redis-server + LRR with daemon
function Launch-LRR {
    $env:Path += ";" + $PSScriptRoot + "\unar"
    $env:Path += ";" + $PSScriptRoot + "\redis"
    $env:Path += ";C:\berrybrew\5.26.0_64\perl\site\bin;C:\berrybrew\5.26.0_64\perl\bin;C:\berrybrew\5.26.0_64\c\bin"

    echo "Perl OK. Running LANraragi Installer..."
    cd .\lanraragi
    perl .\tools\install.pl install-back 

    echo "All dependencies up to date! Starting..."
    cd ..
    Start-Process ".\redis\redis-server.exe" -ArgumentList ".\redis\redis.windows-lrr.conf"
    cd .\lanraragi 
    perl .\script\lanraragi daemon 
    exit 0
}


# Install perl alongside the magick ppm and the cpan deps
function Brew-Perl {
    echo "No compatible Perl installation detected - Asking berrybrew to brew one up."
    .\berrybrew\bin\berrybrew.exe install 5.26.0_64

    echo "Installing PerlMagick...You'll have to press Enter at least once."
    .\berrybrew\bin\berrybrew.exe exec --with 5.26.0_64 ppm install Image-Magick

    echo "All done! Moving up."
}

# Check through berrybrew if the correct perl version is installed
function Check-Perl {
    echo "Checking for Perl installation..."

    If (not Test-Path "C:\berrybrew\5.26.0_64") {
	    Brew-Perl
        Check-Perl
    } else {
        Launch-LRR
    }
}

echo "LANraragi Windows QuickStarter"
echo "=============="
echo ""

Check-Perl