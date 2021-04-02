#!/usr/bin/env bash

COMMANDS['compose']='Compose::Execute' # Function name
COMMANDS_USAGE['10']="  compose                  Run a docker-compose command (alias for docker-compose run --rm)"

Compose::Execute()
{
    namespace compose
    ${DEBUG} && Log::AddOutput compose DEBUG
    Log "Compose::Execute"

    # Analyse des arguments de la ligne de commande grâce à l'utilitaire getopts
    local OPTIND opt
    while getopts ":h-:" opt ; do
       case $opt in
           h ) Compose::Usage
               exit 0;;
           - ) case $OPTARG in
                  help ) Compose::Usage
                         exit 0;;
                  * ) echo "illegal option --$OPTARG"
                      Compose::Usage
                      exit 1;;
               esac;;
           ? ) echo "illegal option -$opt"
               Compose::Usage
               exit 1;;
      esac
    done
    shift $((OPTIND - 1))

    Compose::InitDockerCompose

    try {
        docker-compose ${dockerComposeFile} "$@"
    } catch {
        Log "docker-compose ${dockerComposeFile} "$@" stopped"
    }

}

Compose::Usage()
{
  echo ""
  echo "$(UI.Color.Blue)Usage:$(UI.Color.Default)  jetdocker compose [OPTIONS] [COMMAND]"
  echo ""
  echo "$(UI.Color.Yellow)Options:$(UI.Color.Default)"
  echo "  -h, --help               Print help information and quit"
  echo ""
  echo "Run any docker-compose command via 'jetdocker compose': in the docker-compose documentation above, replace 'docker-compose' by 'jetdocker compose'"
  echo ""
  docker-compose --help
}


Compose::InitDockerCompose()
{
    namespace compose
    ${DEBUG} && Log::AddOutput compose DEBUG
    Log "Jetdocker::InitDockerCompose"

    if [ "$dockerComposeInitialised" = true ]; then
        Log "docker-compose already initialised"
        return;
    fi

    # MacOSX : add specific compose config file
    if [ "$OSTYPE" != 'linux-gnu' ]; then
        if [ -f "docker-compose-osx.yml" ]; then
            Log "Docker4Mac use docker-compose-osx.yml configuration file"
            dockerComposeFile="-f docker-compose.yml -f docker-compose-osx.yml"
        fi
    fi

    Compose::StartMailhog

    Compose::CheckOpenPorts

    if [ "$optDelete" = true ]; then
        # Delete data volumes
        Compose::DeleteDataVolumes
        optDelete=false # avoid double delete option
    fi

    # Initialise data containers
    Compose::InitDataVolumes

    # Pull images from docker-compose config every day
    if [ "$(Jetdocker::CheckLastExecutionOlderThanOneDay  "-${COMPOSE_PROJECT_NAME}")" == "true" ]; then
        Log "Force optBuild to true because it's the first run of day"
        optBuild=true
        Log "docker-compose ${dockerComposeFile} pull --ignore-pull-failures"
        docker-compose ${dockerComposeFile} pull --ignore-pull-failures
    fi
    dockerComposeInitialised=true

}

#
# Change default ports if already used
#
Compose::CheckOpenPorts()
{
    Log "Compose::CheckOpenPorts"
    export DOCKER_PORT_HTTP=$(Compose::RaisePort $DOCKER_PORT_HTTP)
    export DOCKER_PORT_HTTPS=$(Compose::RaisePort $DOCKER_PORT_HTTPS)
    export DOCKER_PORT_MYSQL=$(Compose::RaisePort $DOCKER_PORT_MYSQL)
    export DOCKER_PORT_POSTGRES=$(Compose::RaisePort $DOCKER_PORT_POSTGRES)
    export DOCKER_PORT_REDIS=$(Compose::RaisePort DOCKER_PORT_REDIS)
    export DOCKER_PORT_RABBITMQ=$(Compose::RaisePort DOCKER_PORT_RABBITMQ)
    export DOCKER_PORT_MAILHOG=$(Compose::RaisePort DOCKER_PORT_MAILHOG)

    if [ ! -z "${SYMFONY_PORT:-}" ]; then
       export DOCKER_PORT_MYSQL=306${PROJECT_PORT_SUFFIX}
       export DOCKER_PORT_POSTGRES=543${PROJECT_PORT_SUFFIX}
       export DOCKER_PORT_REDIS=637${PROJECT_PORT_SUFFIX}
       export DOCKER_PORT_RABBITMQ=567${PROJECT_PORT_SUFFIX}
    fi

    Log "${0} : DOCKER_PORT_HTTP = ${DOCKER_PORT_HTTP}"
    Log "${0} : DOCKER_PORT_HTTPS = ${DOCKER_PORT_HTTPS}"
    Log "${0} : DOCKER_PORT_MYSQL = ${DOCKER_PORT_MYSQL}"
    Log "${0} : DOCKER_PORT_POSTGRES = ${DOCKER_PORT_POSTGRES}"
    Log "${0} : DOCKER_PORT_REDIS = ${DOCKER_PORT_REDIS}"
    Log "${0} : DOCKER_PORT_RABBITMQ = ${DOCKER_PORT_RABBITMQ}"
    Log "${0} : DOCKER_PORT_MAILHOG = ${DOCKER_PORT_MAILHOG}"

}

#
# Function called to set the port to the next free port
#
function Compose::RaisePort {

    port=${1}
    try {
        nc -z -w 1 -n 0.0.0.0 "$port" > /dev/null 2>&1
        Compose::RaisePort $((port+1))
    } catch {
        echo $port
    }

}

#
# delete data volumes
# TO OVERRIDE in env.sh in other case than one simple database
#
Compose::DeleteDataVolumes()
{
    Log "Compose::DeleteDataVolumes"
    delete-data-volumes # To avoid BC Break, we keep old function name
}
delete-data-volumes()
{
    echo "$(UI.Color.Red)Do you really want to delete your data volumes? (y/n)$(UI.Color.Default)"
    read -r yes
    if [[ "$yes" = 'y' || "$yes" = 'yes' ]]; then

        # remove db container in case he's only stopped
        try {
            docker rm -f "${COMPOSE_PROJECT_NAME}-${JETDOCKER_DB_DEFAULT_SERVICE}" > /dev/null 2>&1
        } catch {
            Log "No container ${COMPOSE_PROJECT_NAME}-${JETDOCKER_DB_DEFAULT_SERVICE} to delete"
        }
        # remove dbdata volume
        try {
            docker volume rm "${COMPOSE_PROJECT_NAME}-${JETDOCKER_DB_DEFAULT_SERVICE}data" > /dev/null 2>&1
            sleep 1 # some time the docker inspect next command don't relalize the volume has been deleted ! wait a moment is better
            echo "$(UI.Color.Green)${COMPOSE_PROJECT_NAME}-${JETDOCKER_DB_DEFAULT_SERVICE}data volume DELETED ! $(UI.Color.Default)"
        } catch {
            Log "No ${COMPOSE_PROJECT_NAME}-${JETDOCKER_DB_DEFAULT_SERVICE}data volume to delete"
        }

    fi
    Compose::DeleteExtraDataVolumes

}

#
# delete extra data containers
# TO OVERRIDE in env.sh in specific cases
# For exemple if you have an Elasticseach data container
#
Compose::DeleteExtraDataVolumes()
{
    Log "Compose::DeleteExtraDataVolumes"
    delete-extra-data-volumes # To avoid BC Break, we keep old function name
}
delete-extra-data-volumes() {
    Log "No extra data volume configured, implement Compose::DeleteExtraDataVolumes if needed";
}

#
# init data containers
# TO OVERRIDE in env.sh in other case than one simple Mysql database
#
Compose::InitDataVolumes()
{
    Log "Compose::InitDataVolumes"
    init-data-containers # To avoid BC Break, we keep old function name
}
init-data-containers()
{
    # run init-extra-data-containers before compose up because it can need volumes created in init-extra-data-containers
    Compose::InitExtraDataVolumes

    # Database data volume :
    try {
        docker volume inspect "${COMPOSE_PROJECT_NAME}-${JETDOCKER_DB_DEFAULT_SERVICE}data" > /dev/null 2>&1
    } catch {
        docker volume create --name "${COMPOSE_PROJECT_NAME}-${JETDOCKER_DB_DEFAULT_SERVICE}data" > /dev/null 2>&1
        DatabaseBackup::Fetch

        # fix errors because init-db.sh is not executable :
        chmod ugo+x db/*.sh

        # shellcheck disable=SC2086
        docker-compose ${dockerComposeFile} up -d db
        echo "Restoring Database ......... "
        echo ""
        startTime=$(date +%s)
        # Wait for database connection is ready, see https://github.com/betalo-sweden/await
        if [ ! -z "${MYSQL_DATABASE:-}" ]; then
          echo "Waiting ${DB_RESTORE_TIMEOUT} for mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@localhost:${DOCKER_PORT_MYSQL}/$MYSQL_DATABASE is ready ...... "
        fi
        if [ ! -z "${POSTGRES_DB:-}" ]; then
          echo "Waiting ${DB_RESTORE_TIMEOUT} for postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:${DOCKER_PORT_POSTGRES}/$POSTGRES_DB is ready ...... "
        fi
        echo ""
        echo "$(UI.Color.Green)follow database restoration logs in an other terminal running this command : "
        echo "$(UI.Color.Blue)  docker logs -f ${COMPOSE_PROJECT_NAME}-${JETDOCKER_DB_DEFAULT_SERVICE}"
        echo "$(UI.Color.Yellow)(if you see errors in logs and the restoration is blocked, cancel it here with CTRL+C)$(UI.Color.Default)"
        echo ""
        echo "$(UI.Color.Green)  Please wait ${DB_RESTORE_TIMEOUT} ... "
        echo ""
        try {
            if [ ! -z "${MYSQL_DATABASE:-}" ]; then
              await -q -t ${DB_RESTORE_TIMEOUT} mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@localhost:${DOCKER_PORT_MYSQL}/$MYSQL_DATABASE > /dev/null 2>&1
            fi
            if [ ! -z "${POSTGRES_DB:-}" ]; then
              await -q -t ${DB_RESTORE_TIMEOUT} postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:${DOCKER_PORT_POSTGRES}/$POSTGRES_DB > /dev/null 2>&1
            fi
            endTime=$(date +%s)
            echo "$(UI.Color.Green) DATABASE RESTORED in $(expr "$endTime" - "$startTime") s !! $(UI.Color.Default)"
            try {
                hasSearchReplace=$(docker-compose config | grep search-replace-db 2> /dev/null | wc -l)
                Log "hasSearchReplace : ${hasSearchReplace}"
                if [ "${hasSearchReplace}" -gt 0 ]; then
                    SearchReplaceDb::Execute
                fi
            } catch {
                Log "No search-replace-db configured in docker-compose.yml"
            }
        } catch {
            echo "$(UI.Color.Red) DATABASE RESTORATION FAILED "
            endTime=$(date +%s)
            echo " Restoring since $(expr "$endTime" - "$startTime") s."
            echo " Check log with this command : docker logs ${COMPOSE_PROJECT_NAME}-db "
            echo " The database dump might be to big for beeing restaured in less than the ${DB_RESTORE_TIMEOUT} await timeout "
            echo " You can increase this timeout in env.sh DB_RESTORE_TIMEOUT parameter "
            echo " then re-run with jetdocker --delete-data up "
            exit 1;
        }

    }
}

Compose::InitExtraDataVolumes()
{
    Log "Compose::InitExtraDataVolumes"
    init-extra-data-containers # To avoid BC Break, we keep old function name
}
init-extra-data-containers()
{
    Log "No extra data container to create"
}

#
# Start mailhog container on jetdocker_default docker network
#
Compose::StartMailhog()
{
    Log "Compose::StartMailhog"
    try {
        docker inspect mailhog | grep Status | grep running > /dev/null 2>&1
    } catch {
        try {
            docker rm -f mailhog > /dev/null 2>&1
        } catch {
            Log "no mailhog container"
        }
        docker-compose --project-name=jetdocker -f "$JETDOCKER/docker-compose.yml" up -d
    }
}