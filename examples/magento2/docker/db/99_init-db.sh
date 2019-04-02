#!/usr/bin/env bash
set -e

echo "Start init-db.sh";

# Need to create the same user as in production database, used in triggers
USERNAME_DATABASE=produser

echo "Update database to local context ${SERVER_NAME}";
mysql  -pmagento2 -u magento2 $MYSQL_DATABASE <<- EOM
UPDATE core_config_data SET value=replace(value, '${ORIGINAL_SERVER_NAME}', '${SERVER_NAME}');

TRUNCATE cron_schedule;
EOM
mysql  -proot -u root $MYSQL_DATABASE <<- EOM
CREATE USER '$USERNAME_DATABASE'@'localhost' IDENTIFIED BY 'magento2';
GRANT ALL ON *.* TO '$USERNAME_DATABASE'@'localhost';
GRANT FILE ON *.* TO 'magento2'@'%';
EOM

echo "End init-db.sh";
