# DOCKER-VERSION 0.3.4
FROM        debian:jessie
MAINTAINER  dfug sugoi@cock.li

RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y perl apache2 cpanminus make imagemagick perlmagick unar redis-server npm git
RUN cpanm CGI Switch Template Redis JSON::Parse CGI::Session File::ShareDir::Install CGI::Session::Driver::redis Image::Info IPC::Cmd LWP::Simple Digest::SHA URI::Escape

RUN npm install -g bower
RUN ln -s /usr/bin/nodejs /usr/bin/node

RUN git clone https://github.com/Difegue/LANraragi.git /var/www/lanraragi
RUN cd /var/www/lanraragi && bower install --allow-root

RUN a2enmod cgi
RUN chown -R www-data /var/www/lanraragi
RUN chmod -R 755 /var/www/lanraragi
RUN rm -r /var/www/lanraragi/.git
RUN rm -r /var/www/lanraragi/tools

RUN apt-get install -y supervisor

EXPOSE 80
COPY 000-default.conf /etc/apache2/sites-enabled/000-default.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

CMD ["/usr/bin/supervisord"]