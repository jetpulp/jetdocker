#!/bin/bash
cp /etc/nginx/conf.d/default.template /etc/nginx/conf.d/default.conf

[ ! -z "${PHP_HOST}" ]                 && sed -i "s/PHP_HOST/${PHP_HOST}/" /etc/nginx/conf.d/default.conf
[ ! -z "${PHP_PORT}" ]                 && sed -i "s/PHP_PORT/${PHP_PORT}/" /etc/nginx/conf.d/default.conf
[ ! -z "${SERVER_NAME}" ]              && sed -i "s/SERVER_NAME/${SERVER_NAME}/" /etc/nginx/conf.d/default.conf

/usr/sbin/nginx -g "daemon off;"