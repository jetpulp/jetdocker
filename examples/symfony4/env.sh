#!/usr/bin/env bash

#
# environnement variables for running the project on docker
#
function init {

    export COMPOSE_PROJECT_NAME=sfprojet
    # service utilisé par défaut par jetdocker term
    export JETDOCKER_TERM_DEFAULT_SERVICE=engine
    # local server name
    export SERVER_NAME=sf-projet.$JETDOCKER_DOMAIN_NAME
    # every vitural_host separated by , (used for nginx proxy)
    export VIRTUAL_HOST=$SERVER_NAME
    # database name
    export MYSQL_DATABASE=sf_projet

}

#
# OVERRIDE functions of jetdocker for specific cases :
#
