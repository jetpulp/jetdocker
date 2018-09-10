#!/usr/bin/env bash

COMMANDS['term']='Term::Execute' # Function name
COMMANDS_USAGE[1]="  term                     Open a shell terminal into one of docker-compose service"

optUser=''
optHelp=false


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
           u ) optHelp=true;;
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
    Log "optHelp = ${optHelp}"

    ${optHelp} && {
      Term::Usage
      exit 0
    }

    Compose::InitDockerCompose

    if [ -z "${*:-}" ]; then
        if [ -z "${JETDOCKER_TERM_DEFAULT_SERVICE:-}" ]; then
            services=$(compose config --services | tr '\n' ', ')
            echo "Which service do you want to connect to ? ($services)"
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
    Log "docker-compose ${dockerComposeFile} exec $user $service bash"
    try {
        docker-compose ${dockerComposeFile} exec "$user" "$service" bash 2> /tmp/jetdocker-error
    } catch {

        if [ "$user" == '' ]; then

            Log "docker-compose ${dockerComposeFile} run --rm $service bash"
            try {
                docker-compose ${dockerComposeFile} run --rm "$service" bash 2> /tmp/jetdocker-error
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
  echo "Open a shell terminal into one of docker-compose service"
  echo "If [SERVICE] is not specified, it will connect to the service defined in the environement var JETDOCKER_TERM_DEFAULT_SERVICE, instead it list all available services in the docker-compose.yml file"
}

