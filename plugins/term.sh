#!/usr/bin/env bash

COMMANDS['term']='Term::Execute' # Function name
COMMANDS_USAGE['05']="  term                     Open a shell terminal into one of ${DOCKER_COMPOSE} service"

optUser=''

Term::Execute()
{
    namespace term
    ${DEBUG} && Log::AddOutput term DEBUG
    Log "Term::Execute"

    # Analyse des arguments de la ligne de commande grâce à l'utilitaire getopts
    local OPTIND opt
    while getopts ":hu:-:" opt ; do
       case $opt in
           h ) optUser=$OPTARG;;
           u ) Term::Usage
               exit 0;;
           - ) case $OPTARG in
                  user ) optUser=$2;shift;;
                  help ) Term::Usage
                         exit 0;;
                  * ) echo "illegal option --$OPTARG"
                      Term::Usage
                      exit 1;;
               esac;;
           ? ) echo "illegal option -$opt"
               Term::Usage
               exit 1;;
      esac
    done
    shift $((OPTIND - 1))

    Log "optUser = ${optUser}"

    Compose::InitDockerCompose

    if [ -z "${*:-}" ]; then
        if [ -z "${JETDOCKER_TERM_DEFAULT_SERVICE:-}" ]; then
            try {
                ${DOCKER_COMPOSE} ${dockerComposeFile} config --services | tr '\n' ', ' > /tmp/jetdocker_services
            } catch {
                Log "${DOCKER_COMPOSE} ${dockerComposeFile} "$@" stopped"
            }
            echo "Which service do you want to connect to ? ($(cat /tmp/jetdocker_services))"
            read -r service
        else
            service="${JETDOCKER_TERM_DEFAULT_SERVICE}"
        fi
    else
        service="${1}"
    fi

    user=''
    if echo "engine web php-apache" | grep -w "$service" > /dev/null; then
        user="--user=www-data"
    fi
    if [ "${optUser}" != "" ]; then
        user="--user=${optUser}"
    fi

    echo "Connection to $service"
    Log "${DOCKER_COMPOSE} ${dockerComposeFile} exec $user $service bash"
    try {
        ${DOCKER_COMPOSE} ${dockerComposeFile} exec "$user" "$service" bash 2> /tmp/jetdocker-error
    } catch {

        if [ "$user" == '' ]; then

            Log "${DOCKER_COMPOSE} ${dockerComposeFile} run --rm $service bash"
            try {
                ${DOCKER_COMPOSE} ${dockerComposeFile} run --rm "$service" bash 2> /tmp/jetdocker-error
            } catch {
                cat /tmp/jetdocker-error
                echo ""
                echo "$(UI.Color.Red)Service $service doesn't exist !$(UI.Color.Default)"
            }

        else

            cat /tmp/jetdocker-error
            echo ""
            echo "$(UI.Color.Red)Run jetdocker up before trying to access $service container !"
            exit 1

        fi

    }

}

Term::Usage()
{
  echo ""
  echo "$(UI.Color.Blue)Usage:$(UI.Color.Default)  jetdocker term [OPTIONS] [SERVICE]"
  echo ""
  echo "$(UI.Color.Yellow)Options:$(UI.Color.Default)"
  echo "  -u, --user               Connect with a specific user"
  echo "  -h, --help               Print help information and quit"
  echo ""
  echo "Open a shell terminal into one of ${DOCKER_COMPOSE} service"
  echo "If [SERVICE] is not specified, it will connect to the service defined in the environement var JETDOCKER_TERM_DEFAULT_SERVICE, instead it list all available services in the ${dockerComposeFileBase} file"
}

