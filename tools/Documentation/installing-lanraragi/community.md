# Community Install Packages  

## UnRAID  

An UnRAID package based on the Docker images is available [here.](https://github.com/naipilk/LANraragi-unraid-template/)  

## Arch Linux

An installation package is provided [in the AUR](https://aur.archlinux.org/packages/lanraragi/) (Arch User Repository).

Using the AUR package the installation process in Arch Linux should be as easy as entering `pikaur -S lanraragi` in the command line (if using pikaur). Using other AUR managers should be just as easy.

To install lanraragi without an AUR package manager the installation process would be something like:

```
wget https://aur.archlinux.org/cgit/aur.git/snapshot/lanraragi.tar.gz   -O - | tar -xz
cd lanraragi
makepkg -rsi
```
That would take care of installing LRR together with build and normal dependencies and deleting build dependencies after successful building and installing.

The installer also creates a lanraragi.service unit file for starting, restarting and stopping LRR with systemd's `systemctl`. If Redis is down it will get it up.

`systemctl start lanraragi.service`
`systemctl restart lanraragi.service`
`systemctl stop lanraragi.service`
`systemctl status lanraragi.service`

Systemd integration also gives an easy way to read the log (if necessary).

`journalctl -u lanraragi -f`
