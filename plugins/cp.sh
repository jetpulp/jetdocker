#!/usr/bin/env bash

COMMANDS['cp']='Cp::Execute' # Function name
COMMANDS_USAGE['13']="  cp                       Copy [path] from container into local"

Cp::Execute()
{

    namespace cp
    ${DEBUG} && Log::AddOutput cp DEBUG
    Log "Cp::Execute"

    # Analyse des arguments de la ligne de commande grâce à l'utilitaire getopts
    local OPTIND opt
    while getopts ":h-:" opt ; do
       case $opt in
           h ) Cp::Usage
               exit 0;;
           - ) case $OPTARG in
                  help ) Cp::Usage
                         exit 0;;
                  * ) echo "illegal option --$OPTARG"
                      Cp::Usage
                      exit 1;;
               esac;;
           ? ) echo "illegal option -$opt"
               Cp::Usage
               exit 1;;
      esac
    done
    shift $((OPTIND - 1))

    if [ -z "${JETDOCKER_TERM_DEFAULT_SERVICE:-}" ]; then
        try {
            Compose::InitDockerCompose
            docker-compose ${dockerComposeFile} config --services | tr '\n' ', ' > /tmp/jetdocker_services
        } catch {
            Log "docker-compose ${dockerComposeFile} "$@" stopped"
        }
        echo "Which service do you want to copy from ? ($(cat /tmp/jetdocker_services))"
        read -r service
    else
        service="${JETDOCKER_TERM_DEFAULT_SERVICE}"
    fi

    path="${1}"
    echo "docker cp  $COMPOSE_PROJECT_NAME-$service:/var/www/html/$path/. ../$path"
    try {
        docker cp $COMPOSE_PROJECT_NAME-$service:/var/www/html/$path/. ../$path
    } catch {
        Log "Un problème est survenu lors de la copie, il est possible que le container $COMPOSE_PROJECT_NAME-$service ne soit pas démarré"
    }

}

Cp::Usage()
{
  echo ""
  echo "$(UI.Color.Blue)Usage:$(UI.Color.Default)  jetdocker cp [OPTIONS] [PATH]"
  echo ""
  echo "$(UI.Color.Yellow)Options:$(UI.Color.Default)"
  echo "  -h, --help               Print help information and quit"
  echo ""
  echo "Copy [PATH] from container into local"
  echo "Utility command used for exemple to copy generated code in docker volumes, to local filesystem in order to debug"
  echo "For example copy generated code of magento2 : $(UI.Color.Blue)jetdocker cp generated$(UI.Color.Default)"
  echo ""
}

