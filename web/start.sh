#!/bin/bash

echo "01. setup apache"
mkdir /var/log/apache2 2>/dev/null
chown -R www-data /var/log/apache2 2>/dev/null
a2enmod rewrite vhost_alias headers
a2ensite 000-default

mkdir -p /var/lib/drupal-private
chown -R www-data /var/lib/drupal-private

GIT_REPO="https://github.com/szmediathek/szmediathek.git"


if [ ! -f /var/www/sites/default/settings.php ] ; then

    echo "02. cloning repo"
    cd /var/www
    rm -rf html
    #todo: use ssh + myphrase
    git clone ${GIT_REPO} html
    cd html
    git checkout ${GIT_BRANCH}
    git pull

    mkdir -p sites/default/files && chmod 755 sites/default && chown -R www-data:www-data sites/default/files;

    echo "03. setting database"
    mv /tmp/settings.php sites/default/settings.php
    sed -i "s/placeholder_PWD/${MYSQL_ROOT_PASSWORD}/g" sites/default/settings.php
    sed -i "s/placeholder_DB/${MYSQL_DATABASE}/g" sites/default/settings.php
    sed -i "s/placeholder_USER/${MYSQL_USER}/g" sites/default/settings.php
    sed -i "s/placeholder_HOST/${MYSQL_HOST}/g" sites/default/settings.php

    mysqladmin -u root password $MYSQL_ROOT_PASSWORD 
    #echo "CREATE DATABASE $MYSQL_DATABASE; GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO $MYSQL_USER@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD'; FLUSH PRIVILEGES;"
    mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE $MYSQL_DATABASE; GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO $MYSQL_USER@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD'; FLUSH PRIVILEGES;"
    # allow mysql cli for root
    mv /root/.my.cnf.sample /root/.my.cnf
    sed -i "s/ADDED_BY_START.SH/$MYSQL_ROOT_PASSWORD/" /root/.my.cnf 

    if [[ "${MYSQL_HOST}" = "mysql" ]]; then        
        DATABASE_REPO="https://${GIT_USER}:${GIT_PASSWORD}@github.com/szmediathek/databases.git"
        cd /var/www/html
        git clone ${DATABASE_REPO} db
        cd db
        echo "02. unzip sql file"
        gunzip -c ${FILENAME} > /tmp/db1.sql
        cd ..
        #drush sql-drop #check when
        echo "02. import database"
        drush sql-cli < /tmp/db1.sql
        rm /tmp/db1.sql        
    fi

else
    echo "02. pulling repo"
    cd /var/www/html    
    git checkout ${GIT_BRANCH}
    git pull

    if [[ "${UPDATE_DB}" = "1" ]]; then
        DATABASE_REPO="https://${GIT_USER}:${GIT_PASSWORD}@github.com/szmediathek/databases.git"
        cd /var/www/html
        if [ ! -d /var/www/html/db ] ; then
            git clone ${DATABASE_REPO} db
        else
            cd db
            git pull
            cd ..
        fi
        cd db
        echo "02. unzip sql file"
        gunzip -c ${FILENAME} > /tmp/db1.sql
        cd ..
        #drush sql-drop #check when
        echo "02. import database"
        drush sql-cli < /tmp/db1.sql
        rm /tmp/db1.sql
    fi
fi

if [ "x$MYSQL_HOST" == 'xlocalhost' ] ; then
    # Stop mysql, will be restarted by supervisor below
    killall mysqld
    sleep 5s
fi

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