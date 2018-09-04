#!/usr/bin/env bash
set -e

echo "Start init-db.sh";

echo "Update database to local context ${SERVER_NAME}";
mysql  -proot -u root $MYSQL_DATABASE <<- EOM
UPDATE core_config_data SET value=replace(value, '${ORIGINAL_SERVER_NAME}', '${SERVER_NAME}');
UPDATE core_config_data SET value=replace(value, '${ORIGINAL_SERVER_NAME_ALIAS}', '${SERVER_NAME_ALIAS}');
EOM

echo "End init-db.sh";
