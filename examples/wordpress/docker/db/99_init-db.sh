#!/usr/bin/env bash
set -e

echo "Start init-db.sh";

echo "UPDATE database to local context";

mysql  -proot -u root $MYSQL_DATABASE <<- EOM
EOM

echo "End init-db.sh";
