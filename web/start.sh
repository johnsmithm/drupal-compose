#!/bin/bash

echo "01. setup apache"
mkdir /var/log/apache2 2>/dev/null
chown -R www-data /var/log/apache2 2>/dev/null
a2enmod rewrite vhost_alias headers
a2ensite 000-default

mkdir -p /var/lib/drupal-private
chown -R www-data /var/lib/drupal-private

GIT_REPO="https://github.com/szmediathek/szmediathek.git"
DATABASE_REPO="git@github.com:szmediathek/databases.git"
#MYSQL_HOST=""
#MYSQL_USER=""
#MYSQL_DATABASE=""
#MYSQL_ROOT_PASSWORD=""
MYSQL_PASSWORD="1"

#todo: handle existing repository

echo "02. cloning repo"
cd /var/www
rm -rf html
#todo: use ssh + myphrase
git clone ${GIT_REPO} html
cd html
git checkout ${GIT_BRANCH}
git pull

#todo: use ssh + myphrase
#git clone ${DATABASE_REPO} db
GIT_SSH=/gitwrap.sh git clone ${DATABASE_REPO} db
if ! [ -n "$SSH_AUTH_SOCK" ] || 
  ! { ssh-add -l &>/dev/null; rc=$?; [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ];}; then
    echo "Starting agent..."
    eval "$(ssh-agent -s)"
fi

mkdir -p sites/default/files && chmod 755 sites/default && chown -R www-data:www-data sites/default/files;

echo "03. setting database"
mv /tmp/settings.php sites/default/settings.php
sed -i "s/placeholder_PWD/${MYSQL_ROOT_PASSWORD}/g" sites/default/settings.php
sed -i "s/placeholder_DB/${MYSQL_DATABASE}/g" sites/default/settings.php
sed -i "s/placeholder_USER/${MYSQL_USER}/g" sites/default/settings.php
sed -i "s/placeholder_HOST/${MYSQL_HOST}/g" sites/default/settings.php

if [[ ${LOCAL_MYSQL} ]]; then
    mysqladmin -u root password $MYSQL_ROOT_PASSWORD 
    #echo "CREATE DATABASE $MYSQL_DATABASE; GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO $MYSQL_USER@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD'; FLUSH PRIVILEGES;"
    mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE $MYSQL_DATABASE; GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO $MYSQL_USER@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD'; FLUSH PRIVILEGES;"
    # allow mysql cli for root
    mv /root/.my.cnf.sample /root/.my.cnf
    sed -i "s/ADDED_BY_START.SH/$MYSQL_ROOT_PASSWORD/" /root/.my.cnf 

    #get database - maybe git
    #copy database
    #clear cache
    #delete repo git
fi

echo "4. setting up solr"
#cd /opt
#wget http://archive.apache.org/dist/lucene/solr/4.7.2/solr-4.7.2.tgz
#tar -xvf solr-4.7.2.tgz
#cp -R solr-4.7.2/example /opt/solr
#cd /opt/solr
#java -jar start.jar
#sudo cat /tmp/jetty > /etc/default/jetty
#sudo cat /tmp/jetty-logging.xml > /opt/solr/etc/jetty-logging.xml
#sudo useradd -d /opt/solr -s /sbin/false solr
#sudo chown solr:solr -R /opt/solr
#sudo wget -O /etc/init.d/jetty http://git.eclipse.org/c/jetty/org.eclipse.jetty.project.git/plain/jetty-distribution/src/main/resources/bin/jetty.sh
#sudo chmod a+x /etc/init.d/jetty
#sudo update-rc.d jetty defaults
#sudo /etc/init.d/jetty start
#use docker composer
#will not work because we have another port
   
# Create log that can be written to in the running container, and visible in the
# docker log (stdout) and thus the webfact UI.
# todo: could this be done by supervisord, but it must send the tail to stdout?
webfactlog=/tmp/webfact.log;
echo "`date '+%Y-%m-%d %H:%M'` Create new $webfactlog" > $webfactlog
tail -f $webfactlog &

# Start any stuff in rc.local
echo "-- starting /etc/rc.local"
/etc/rc.local &

echo "5. Starting processes via supervisor."
# Start lamp, make sure no PIDs lying around
rm /var/run/apache2/apache2.pid /var/run/rsyslog.pid /var/run/rsyslogd.pid /var/run/mysqld/mysqld.pid /var/run/crond.pid 2>/dev/null 2>/dev/null
supervisord -c /etc/supervisord.conf -n

#todo: the logs hangs:   mysqld entered RUNNING state, process has stayed up for > than 1 seconds

echo "6. Visit your site http:localhost:8003."
