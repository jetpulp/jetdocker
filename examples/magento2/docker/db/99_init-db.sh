#!/usr/bin/env bash
set -e

echo "Start init-db.sh";

echo "Update database to local context ${SERVER_NAME}";
mysql  -pmagento2 -u magento2 $MYSQL_DATABASE <<- EOM
UPDATE core_config_data SET value=replace(value, '${ORIGINAL_SERVER_NAME}', '${SERVER_NAME}');
EOM
mysql  -proot -u root $MYSQL_DATABASE <<- EOM
GRANT FILE ON *.* TO 'magento2'@'%';
EOM

echo "End init-db.sh";
