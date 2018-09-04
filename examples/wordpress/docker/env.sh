#!/usr/bin/env bash

#
# Set environnement variables for jetdocker
#
init() {

    export COMPOSE_PROJECT_NAME=project
    # service utilisé par défaut par jetdocker term
    export JETDOCKER_TERM_DEFAULT_SERVICE=web
    # timeout for DB restoring waiting (default 3m0s)
    #export DB_RESTORE_TIMEOUT=3m0s
    # local server name
    export SERVER_NAME=project.$JETDOCKER_DOMAIN_NAME
    # local server name
    export SERVER_NAME_ALIAS=project-alias.$JETDOCKER_DOMAIN_NAME
    # every vitural_host separated by , (used for nginx proxy)
    export VIRTUAL_HOST=$SERVER_NAME,$SERVER_NAME_ALIAS
    # database name
    export MYSQL_DATABASE=project

}

#
# OVERRIDE functions of jetdocker for specific cases here
#
