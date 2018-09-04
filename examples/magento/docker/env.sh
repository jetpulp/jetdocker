#!/usr/bin/env bash

#
# Set environnement variables for running the project on docker
#
init() {

    export COMPOSE_PROJECT_NAME=project
    # service utilisé par défaut par jetdocker term
    export JETDOCKER_TERM_DEFAULT_SERVICE=web
    # timeout for DB restoring waiting (default 3m0s)
    #export DB_RESTORE_TIMEOUT=3m0s
    # local server name
    export SERVER_NAME=project.$JETDOCKER_DOMAIN_NAME
    # local server name alias (facultatif)
    export SERVER_NAME=project-alias.$JETDOCKER_DOMAIN_NAME
    # original server name
    export ORIGINAL_SERVER_NAME=www.project.com
    # original server name alias
    export ORIGINAL_SERVER_NAME_ALIAS=www.project-alias.com
    # every vitural_host separated by , (used for nginx proxy)
    export VIRTUAL_HOST=$SERVER_NAME,$SERVER_NAME_ALIAS
    # database name
    export MYSQL_DATABASE=project

}


#
# OVERRIDE functions of jetdocker for specific cases here
#