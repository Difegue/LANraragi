#!/usr/bin/env bash

apt-get update
apt-get install -y apache2 cpanminus make imagemagick unar redis-server npm git

npm install -g bower
ln -s /usr/bin/nodejs /usr/bin/node

if ! [ -L /var/www ]; then
  rm -rf /var/www
  ln -fs /vagrant /var/www
fi

rm -rf /var/www/lanraragi
git clone https://github.com/Difegue/LANraragi.git /var/www/lanraragi
cd /var/www/lanraragi

cpanm -i HTML::Table Redis JSON::Parse CGI::Session CGI::Session::Driver::redis Image::Info IPC::Cmd LWP::Simple Digest::SHA URI::Escape
bower install --allow-root

cp /vagrant/000-default.conf /etc/apache2/sites-enabled/000-default.conf

a2enmod cgi
service apache2 restart

chown -R www-data /var/www/lanraragi
chmod -R 755 /var/www/lanraragi


