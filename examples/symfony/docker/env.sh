#!/usr/bin/env bash

#
# environnement variables for running the project on docker
#
init() {

    export COMPOSE_PROJECT_NAME=project
    # service utilisé par défaut par jetdocker term
    export JETDOCKER_TERM_DEFAULT_SERVICE=engine
    # local server name
    export SERVER_NAME=project.$JETDOCKER_DOMAIN_NAME
    # every vitural_host separated by , (used for nginx proxy)
    export VIRTUAL_HOST=$SERVER_NAME
    # database name
    export MYSQL_DATABASE=project

}

#
# OVERRIDE functions of jetdocker for specific cases here
#
