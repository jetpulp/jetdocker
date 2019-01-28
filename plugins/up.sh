#!/usr/bin/env bash

COMMANDS['up']='Up::Execute' # Function name
COMMANDS_USAGE['00']="  up                       Start docker-compose after initializing context (databases, ports, proxy, etc... )"

optDelete=false
optBuild=false
optSilent=false
optOpen=false
optXdebug=false
optHelp=false


Up::Execute()
{

    namespace up
    ${DEBUG} && Log::AddOutput up DEBUG
    Log "Up::Execute"

    # Analyse des arguments de la ligne de commande grâce à l'utilitaire getopts
    local OPTIND opt
    while getopts ":dbsoxh-:" opt ; do
       case $opt in
           d ) optDelete=true;;
           b ) optBuild=true;;
           s ) optSilent=true;;
           o ) optOpen=true;;
           x ) optXdebug=true;;
           h ) optHelp=true;;
           - ) case $OPTARG in
                  delete-data ) optDelete=true;;
                  xdebug ) optXdebug=true;;
                  build ) optBuild=true;;
                  silent ) optSilent=true;;
                  open ) optOpen=true;;
                  help ) Up::Usage
                         exit 0;;
                  * ) echo "illegal option --$OPTARG"
                      Up::Usage
                      exit 1;;
               esac;;
           ? ) echo "illegal option -$opt"
               Up::Usage
               exit 1;;
      esac
    done
    shift $((OPTIND - 1))

    Log "optDelete = ${optDelete}"
    Log "optBuild = ${optBuild}"
    Log "optSilent = ${optSilent}"
    Log "optOpen = ${optOpen}"
    Log "optXdebug = ${optXdebug}"
    Log "optHelp = ${optHelp}"

    ${optHelp} && {
      Up::Usage
      exit 0
    }

    if [ "$optXdebug" = true ]; then
        export XDEBUG_ENABLED=true
    fi

    Compose::InitDockerCompose

   #stop and remove docker containers when stop script
   trap "Up::Stop" SIGINT SIGTERM

   #trap "try { docker-compose stop;docker-compose rm -f -v } catch { Log 'End' }" SIGINT SIGTERM
   Log "RUN WHEN EXIT : docker-compose stop;docker-compose rm -f -v"

   # On the first run, or on asked option : build the app
   if [ "$optBuild" = true ]; then
      Up::Install
   fi

   # Run Compose::CheckOpenPorts again in case ports have been used during Compose::InitDataVolumes or Up::Install
   Compose::CheckOpenPorts

   Up::StartReverseProxy

   # create file bash_home/.bash_history if it doesn't exists
   touch "${JETDOCKER}/bash_home/.bash_history"
   touch "${JETDOCKER}/bash_home/.my_aliases"

   ${DEBUG} && docker-compose config
   echo "$(UI.Color.Green)docker-compose ${dockerComposeFile} up -d ${JETDOCKER_UP_DEFAULT_SERVICE}$(UI.Color.Default)"
   docker-compose ${dockerComposeFile} up -d ${JETDOCKER_UP_DEFAULT_SERVICE}

   # connect the container nginx-reverse-proxy to the network of the project (required to communicate)
   try {
    Log "docker network connect ${COMPOSE_PROJECT_NAME}_default nginx-reverse-proxy"
    docker network connect "${COMPOSE_PROJECT_NAME}_default" nginx-reverse-proxy > /tmp/jetdocker-error 2>&1
   } catch {
     Log $(cat /tmp/jetdocker-error)
   }
   try {
    Log "docker network connect bridge ${COMPOSE_PROJECT_NAME}-${JETDOCKER_UP_DEFAULT_SERVICE}"
    docker network connect bridge "${COMPOSE_PROJECT_NAME}-${JETDOCKER_UP_DEFAULT_SERVICE}" > /tmp/jetdocker-error 2>&1
   } catch {
     Log $(cat /tmp/jetdocker-error)
   }

   # check if OPEN_URl is set (beware of unbound varaible error, see https://stackoverflow.com/questions/7832080/test-if-a-variable-is-set-in-bash-when-using-set-o-nounset )
   if [ -z "${OPEN_URL:-}" ]; then
     OPEN_URL="https://$SERVER_NAME"
   fi
   echo ""
   echo "$(UI.Color.Green)Open your browser on $OPEN_URL $(UI.Color.Default)"
   echo ""
   if [ "$optOpen" = true ]; then
        if [ "$OSTYPE" != 'linux-gnu' ]; then
            open "$OPEN_URL"
        else
            xdg-open "$OPEN_URL"
        fi
    fi

    Up::Message

    if [ "$optSilent" = false ]; then
        # log in standard output
        try {
            docker-compose logs --follow
        } catch {
            Log "End docker-compose logs --follow"
        }
    else
        echo "$(UI.Color.Green) For more informations run : docker-compose logs $(UI.Color.Default)"
    fi

}

Up::Usage()
{
  echo ""
  echo "$(UI.Color.Blue)Usage:$(UI.Color.Default)  jetdocker up [OPTIONS]"
  echo ""
  echo "$(UI.Color.Yellow)Options:$(UI.Color.Default)"
  echo "  -d, --delete-data        Delete data docker volumes before start, forcing it to restore"
  echo "  -b, --build              Force building (assets, etc...) before start"
  echo "  -x, --xdebug             Enable xdebug in PHP container"
  echo "  -s, --silent             Don't run docker-compose log --follow after start"
  echo "  -o, --open               Open browser after start on the $SERVER_NAME url"
  echo "  -h, --help               Print help information and quit"
  echo ""
  echo "Start docker-compose after initializing context (databases, ports, proxy, etc... )"
  echo ""
}

#
# build assets , default is make install
# TO OVERRIDE in env.sh in case of grunt, multiple builds, composer, etc...
#
Up::Install()
{
    Log "Up::Install"
    install # To avoid BC Break, we keep old function name
}
install() {
    echo "$(UI.Color.Green)Installation ... $(UI.Color.Default)"
    cd "${projectPath}" || exit
    try {
        make install
    } catch {
        Log "make install error"
    }
    cd "$optConfigPath" || exit
    echo "$(UI.Color.Green)END Installation ... $(UI.Color.Default)"
}

#
# Start docker-compose with traefik, mailhog and phpmyadmin
#
# TODO : voir comment fair ça avec traefik : Add proxies to 8443 ports for java tomcat applications
#
Up::StartReverseProxy() {

    Log "Up::StartReverseProxy"
    try {
        docker inspect mailhog > /dev/null 2>&1
    } catch {
        touch "$JETDOCKER/templates/config.user.inc.php"
        docker-compose --project-name=jetdocker -f "$JETDOCKER/docker-compose.yml" up -d
    }
}

Up::Stop()
{
    try {
        docker-compose stop
        docker-compose rm -f -v
        docker network rm ${COMPOSE_PROJECT_NAME}_default
    } catch {
        Log 'End'
    }
}

Up::Message()
{
    Log "Up::Message : override function in env.sh to display custom message to the developper"
}