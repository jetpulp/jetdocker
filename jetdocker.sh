#!/usr/bin/env bash
#
# This script is used to start and stop a docker compose configuration
#
#

VERSION=2.0.0

## BOOTSTRAP ##
source "$( cd "${BASH_SOURCE[0]%/*}" && pwd )/lib/oo-bootstrap.sh"
## MAIN ##
import util/log util/exception util/tryCatch util/namedParameters util/class util/log UI/Color

SCRIPTPATH=${BASH_SOURCE[0]%/*}

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

# Set JETDOCKER must be set during install
if [[ -z "$JETDOCKER" ]]; then
    JETDOCKER="$SCRIPTPATH"
fi

# Set JETDOCKER_CUSTOM to the path where your custom lib files
# exists, or else we will use the default custom/
if [[ -z "$JETDOCKER_CUSTOM" ]]; then
    JETDOCKER_CUSTOM="$JETDOCKER/custom"
fi

# Load all of the config files in ~/.jetdocker/plugins and in custom/plugins that end in .sh
pluginsFiles="$(ls $JETDOCKER_CUSTOM/plugins/*.sh) $(ls $JETDOCKER/plugins/*.sh)"
declare -A loadedPlugins
for pluginfile in $pluginsFiles; do
  pluginfilename=$(basename "${pluginfile}")
  if [ ! -n "${loadedPlugins[$pluginfilename]}" ]; then
      source $pluginfile
      loadedPlugins[$pluginfilename]=true;
   fi
done

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

Jetdocker::CheckUpdateVersion()
{

    Log "Jetdocker::CheckUpdateVersion"

    # Check upgrade jetdocker
    flagfile=/tmp/jetdocker
    if [ ! -f $flagfile ]; then
        echo 0 > $flagfile
    fi
    lastupdate=$(cat $flagfile)
    now=$(date +%s)
    oneday=( 24*60*60 )
    if [ $(( now - oneday)) -gt "$lastupdate" ]; then
        echo "$now" > "$flagfile"
        Jetdocker::Update
    fi
    # END Check upgrade jetdocker

}

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
    . "env.sh"

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

projectPath=$(pwd)
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

DEBUG=${optDebug}

namespace jetdocker
${DEBUG} && Log::AddOutput jetdocker DEBUG

Log "optVersion = ${optVersion}"
Log "optHelp = ${optHelp}"
Log "optSilent = ${optSilent}"
Log "optOpen = ${optOpen}"
Log "optXdebug = ${optXdebug}"
Log "optHelp = ${optHelp}"

${optVersion} && {
  echo "Jetdocker v$VERSION"
  exit 0
}

${optHelp} && {
  Jetdocker::Usage
  exit 0
}

#Get command, and pass command line to his function
if [ "$1" != "" ] && [ -n "${COMMANDS[$1]}" ]; then
  command=${COMMANDS[$1]}
  shift
else
  echo "$(UI.Color.Red)illegal command \"$1\""
  Jetdocker::Usage
  exit 1
fi

Jetdocker::CheckUpdateVersion

if [ -n "${COMMANDS_STANDALONE[$command]}" ]; then
   "$command" "$@"
   exit $?
fi

Jetdocker::CheckProject
if [ $? -eq 1 ]; then
   exit 1
fi

#TODO generate-certificate-ssl false
#TODO generate-pseudo-passwd-file

"$command" "$@"