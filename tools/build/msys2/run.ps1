[CmdletBinding()]
Param(
  [string]$Network,
  [Parameter(Mandatory=$true)]
  [string]$Data,
  [Parameter(Mandatory=$true)]
  [string]$Thumb,
  [Parameter(Mandatory=$true)]
  [string]$Database
)

Push-Location $([Environment]::CurrentDirectory)

if ([string]::IsNullOrEmpty($Network)) {
    $Env:LRR_NETWORK="http://0.0.0.0:3000"
} else {
    $Env:LRR_NETWORK=$Network
}

$Env:LRR_DATA_DIRECTORY = $Data
$Env:LRR_THUMB_DIRECTORY = $Thumb
$Env:Path = "$PWD\runtime\bin;$PWD\runtime\redis;$($Env:Path)"

[System.IO.Directory]::CreateDirectory("$PWD\log") | Out-Null
[System.IO.Directory]::CreateDirectory("$PWD\temp") | Out-Null

Start-Process -FilePath "redis-server" -ArgumentList "--pidfile", "$PWD\temp\redis.pid", "--dir", "$Database", "--logfile", "$PWD\log\redis.log"
Start-Process -FilePath "perl" -ArgumentList "script\launcher.pl", "-d", "script\lanraragi"

Pop-Location
