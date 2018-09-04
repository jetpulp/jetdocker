#!/usr/bin/env bash
#
# environnement variables for running the project on docker
#
init() {

    export COMPOSE_PROJECT_NAME=project
    # service utilisé par défaut par jetdocker term
    export JETDOCKER_TERM_DEFAULT_SERVICE=engine
    # timeout for DB restoring waiting (default 3m0s)
    #export DB_RESTORE_TIMEOUT=3m0s
    # local server name
    export SERVER_NAME=project.$JETDOCKER_DOMAIN_NAME
    # original server name
    export ORIGINAL_SERVER_NAME=www.project.com
    # every vitural_host separated by , (used for nginx proxy)
    export VIRTUAL_HOST=$SERVER_NAME
    # database name
    export MYSQL_DATABASE=project
    # database user
    export MYSQL_USER=magento2
    # database password
    export MYSQL_PASSWORD=magento2

}

#
# OVERRIDE functions of jetdocker for specific cases here
#