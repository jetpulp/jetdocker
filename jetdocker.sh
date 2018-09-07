#!/usr/bin/env bash
#
# This script is used to start and stop a docker compose configuration
#
#

VERSION=2.0.0

# Set JETDOCKER must be set during install
if [[ -z "$JETDOCKER" ]]; then
    echo "$(tput setaf 1) The env var JETDOCKER must be set during install on the absolute path of your install, and be accessible in your shell."
fi

# Set JETDOCKER_CUSTOM to the path where your custom lib files
# exists, or else we will use the default custom/
if [[ -z "$JETDOCKER_CUSTOM" ]]; then
    JETDOCKER_CUSTOM="$JETDOCKER/custom"
fi

# Set JETDOCKER_DOMAIN_NAME to domain name you want to use for your projects
# The default is localhost.tv (All subdomains on *.localhost.tv (except www)
# points to 127.0.0.1 (or 0:0:0:0:0:0:0:1 for IPv6). )
# Man can use 127.0.0.1.xip.io or anOtherIP.xip.io, see http://xip.io/
if [[ -z "$JETDOCKER_DOMAIN_NAME" ]]; then
    JETDOCKER_DOMAIN_NAME="localhost.tv"
fi


## BOOTSTRAP ##
source "${JETDOCKER}/lib/oo-bootstrap.sh"
## MAIN ##
import util/log util/exception util/tryCatch util/namedParameters util/class util/log UI/Color


# Default ports for docker containers
export DOCKER_PORT_HTTP=81
export DOCKER_PORT_HTTPS=444
export DOCKER_PORT_MYSQL=3306
export DOCKER_PORT_POSTGRES=5432
export DOCKER_PORT_MAILHOG=8025

# Defaut timeout for DB restoring waiting
export DB_RESTORE_TIMEOUT=3m0s

# Default mysql credentials
export MYSQL_ROOT_PASSWORD=root
export MYSQL_USER=root
export MYSQL_PASSWORD=root

# Defaut docker-compose startup service
JETDOCKER_UP_DEFAULT_SERVICE=web
# Defaut docker-compose startup service
JETDOCKER_DB_DEFAULT_SERVICE=db

dockerComposeFile="";
dockerComposeInitialised=false;
projectPath=$(pwd)

# declare associative array for commands loaded in plugins
declare -A COMMANDS
declare -A COMMANDS_USAGE
declare -A COMMANDS_STANDALONE


#
# usage function
#
Jetdocker::Usage()
{
  #Cette fonction affiche les consignes d'usage du script
  echo ""
  echo "$(UI.Color.Blue)Usage:$(UI.Color.Default)  jetdocker [OPTIONS] COMMAND"
  echo ""
  echo "$(UI.Color.Yellow)Options:$(UI.Color.Default)"
  echo "  -c, --config string      Location of project docker config files (default \"./docker\")"
  echo "  -D, --debug              Enable debug mode"
  echo "  -h, --help               Print help information and quit"
  echo "  -v, --version            Print version information and quit"
  echo ""
  echo "$(UI.Color.Yellow)Commands:$(UI.Color.Default)"
  for command in "${!COMMANDS_USAGE[@]}"
  do
    echo "${COMMANDS_USAGE[$command]}"
  done
  echo ""
  echo "Run 'jetdocker COMMAND --help' for more information on a command."
}

Jetdocker::CheckLastExecutionOlderThanOneDay()
{
    flagfile=/tmp/jetdocker${1}
    if [ ! -f $flagfile ]; then
        echo 0 > $flagfile
    fi
    lastupdate=$(cat $flagfile)
    now=$(date +%s)
    oneday=( 24*60*60 )
    if [ $(( now - oneday)) -gt "$lastupdate" ]; then
        echo "$now" > "$flagfile"
        echo "true"
    else
        echo "false"
    fi

}

COMMANDS['update']='Jetdocker::Update' # Function name
COMMANDS_USAGE[4]="  update                   Update jetdocker to the latest version"
Jetdocker::Update()
{

    Log "Jetdocker::Update"
    previousPath=$(pwd)
    cd "$JETDOCKER" || exit
    echo "$(UI.Color.Green)"
    echo "Upgrading jetdocker"
    echo ""
    if git pull --rebase --stat origin master
    then
        echo ""
        echo "Jetdocker upgraded"
    else
        echo ""
        echo "$(UI.Color.Red)There was an error updating jetdocker"
    fi
    echo "$(UI.Color.Default)"
    cd "$previousPath" || exit

}

Jetdocker::CheckProject()
{

    Log "Jetdocker::CheckProject"

    Log "go in $optConfigPath"
    if [ -d "$optConfigPath" ]; then
        cd "$optConfigPath" || exit
    fi

    Log "We're in $optConfigPath directory"

    # Check there's a docker-compose file in current directory
    if [ ! -f 'docker-compose.yml' ]; then
        echo ""
        echo "$(UI.Color.Red)  docker-compose.yml file doesn't exist in $(pwd)!"
        echo ""
        exit 1
    fi
    Log "docker-compose.yml file exist"

    # Check there's a env.sh file in current directory
    if [ ! -f 'env.sh' ]; then
        echo ""
        echo "$(UI.Color.Red)  env.sh file doesn't exist in $(pwd)!"
        echo ""
        exit 1
    fi
    Log "env.sh file exist"

    # Source env.sh
    # shellcheck disable=SC1091
    source "env.sh"

    if Jetdocker::FunctionExists init; then
       Log "init function exist"
       init
    else
        echo ""
        echo "$(UI.Color.Red) Function init does not exist in env.sh, it must be implemented ! "
        echo ""
        exit 1
    fi

}

#
# Check if the function exists
#
Jetdocker::FunctionExists()
{
    Log "Jetdocker::FunctionExists"
    type "$1" 2>/dev/null | grep -q 'is a function'
    if [ $? -eq 0 ]; then
        return 0
    fi
    #on different OS the message language is not the same
    type "$1" 2>/dev/null | grep -q 'est une fonction'
    if [ $? -eq 0 ]; then
        return 0
    fi
    return 1
}

#
# (Re)generate SSL certificate (in docker volume), if not exist or if force argument passed
#
Jetdocker::GenerateSSLCertificate() {

    Log "Jetdocker::GenerateSSLCertificate"

    try {
        docker volume inspect jetdocker-ssl-certificate | grep "$JETDOCKER_DOMAIN_NAME" > /dev/null 2>&1
    } catch {

        try {
            Log "remove volume jetdocker-ssl-certificate"
            docker volume rm jetdocker-ssl-certificate
        } catch {
            Log "No jetdocker-ssl-certificate volume to remove"
        }

        Jetdocker::GenerateRootCACertificate

        Log "Generate volume jetdocker-ssl-certificate"
        docker volume create jetdocker-ssl-certificate --label "$JETDOCKER_DOMAIN_NAME"
        docker pull jetpulp/jetdocker-ssl-certificate:latest
        docker run --rm -e COMMON_NAME="*.$JETDOCKER_DOMAIN_NAME" -e KEY_NAME=jetdocker-ssl-certificate -v jetdocker-ssl-certificate:/certs -v "$JETDOCKER/cacerts:/cacerts" jetpulp/jetdocker-ssl-certificate

    }

    #recopie les certificats généré dans le dossier courrant du host afin de pouvoir les utiliser dans browser-sync en local
    Log "local copy SSL certificate"
    docker run --rm --user "$(id -u):$(id -g)" -v jetdocker-ssl-certificate:/certs -v $(pwd):/certs_host jetpulp/jetdocker-ssl-certificate bash -c "cp -Rf certs/ certs_host/"
    touch .gitignore
    grep -q -F certs .gitignore || echo 'certs' >> .gitignore
}

#
# (Re)generate RootCA certificate
#
Jetdocker::GenerateRootCACertificate() {
   Log "Jetdocker::GenerateRootCACertificate"

   ## TODO : generate cacerts/rootCA.crt and cacerts/rootCA.key files

}

#
# (Re)generate ~/.composer/docker_passwd file, this file must be mounted in composer container
# in order to simulate a real user (see https://hub.docker.com/r/library/composer/)
# On mac OSX /etc/passwd doesn't contain the user, then we generate this file ...
#
Jetdocker::GeneratePseudoPasswdFile() {

    Log "Jetdocker::GeneratePseudoPasswdFile"
    try {
        mkdir -p ~/.composer > /dev/null 2>&1
    } catch {
        Log "~/.composer already exist"
    }
    echo "# File generated by jetdocker, mounted in docker containers for simulating a real user" > ~/.composer/docker_passwd
    echo "root:x:0:0:root:/root:/bin/bash" >> ~/.composer/docker_passwd
    echo "$(whoami):x:$(id -u):$(id -g):,,,:/home/www-data:/bin/bash" >> ~/.composer/docker_passwd
}

optDebug=false
optConfigPath=docker
optVersion=false
optHelp=false

# Analyse des arguments de la ligne de commande grâce à l'utilitaire getopts
while getopts ":vhDc:-:" opt ; do
   case $opt in
       D ) optDebug=true;;
       c ) optConfigPath=$OPTARG;;
       v ) optVersion=true;;
       h ) optHelp=true;;
       - ) case $OPTARG in
              debug ) optDebug=true;;
              config ) optConfigPathg=$2;shift;;
              help ) optHelp=true;;
              version ) optVersion;;
              * ) echo "$(UI.Color.Red)illegal option --$OPTARG"
                  Jetdocker::Usage
                  exit 1;;
           esac;;
       ? ) echo "$(UI.Color.Red)illegal option -$opt"
           Jetdocker::Usage
           exit 1;;
  esac
done
shift $((OPTIND - 1))

export DEBUG=${optDebug}

namespace jetdocker
${DEBUG} && Log::AddOutput jetdocker DEBUG

${DEBUG} && docker --version
${DEBUG} && docker-compose --version
Log "optDebug = ${optDebug}"
Log "optConfigPath = ${optConfigPath}"
Log "optVersion = ${optVersion}"
Log "optHelp = ${optHelp}"
Log "JETDOCKER = ${JETDOCKER}"
Log "JETDOCKER_CUSTOM = ${JETDOCKER_CUSTOM}"
Log "JETDOCKER_DOMAIN_NAME = ${JETDOCKER_DOMAIN_NAME}"

${optVersion} && {
  echo "Jetdocker v$VERSION"
  exit 0
}

${optHelp} && {
  Jetdocker::Usage
  exit 0
}

# Load all of the config files in ~/.jetdocker/plugins and in custom/plugins that end in .sh
pluginsFiles="$(ls $JETDOCKER_CUSTOM/jetdocker.sh 2> /dev/null) $(ls $JETDOCKER_CUSTOM/plugins/*.sh 2> /dev/null) $(ls $JETDOCKER/plugins/*.sh)"
declare -A loadedPlugins
for pluginfile in $pluginsFiles; do
  pluginfilename=$(basename "${pluginfile}")
  if [ ! -n "${loadedPlugins[$pluginfilename]}" ]; then
      Log "source $pluginfile"
      source $pluginfile
      loadedPlugins[$pluginfilename]=true;
   fi
done

#Get command, and pass command line to his function
if [ "$1" != "" ] && [ -n "${COMMANDS[$1]}" ]; then
  command=$1
  commandFunction=${COMMANDS[$1]}
  shift
else
  echo "$(UI.Color.Red)illegal command \"$1\""
  Jetdocker::Usage
  exit 1
fi

if [ "$(Jetdocker::CheckLastExecutionOlderThanOneDay)" == "true" ]; then
    Jetdocker::Update
fi

if [ -n "${COMMANDS_STANDALONE[$command]}" ]; then
   "$commandFunction" "$@"
   exit $?
fi

Jetdocker::CheckProject
if [ $? -eq 1 ]; then
   exit 1
fi

Jetdocker::GenerateSSLCertificate false
Jetdocker::GeneratePseudoPasswdFile

"$commandFunction" "$@"