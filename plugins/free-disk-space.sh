#!/usr/bin/env bash

COMMANDS['free-disk-space']='FreeDiskSpace::Execute' # Function name
COMMANDS_USAGE['15']="  free-disk-space          Free disk space utility"
COMMANDS_STANDALONE['free-disk-space']=' ' # Function name

optHelp=false

#
#  Utility method to free disk space used by docker
#
#  - docker system prune (remove container, images and volumes unused)
#  - remove non tagged images
#
FreeDiskSpace::Execute()
{
    namespace free-disk-space
    ${DEBUG} && Log::AddOutput free-disk-space DEBUG
    Log "FreeDiskSpace::Execute"

    # Analyse des arguments de la ligne de commande grâce à l'utilitaire getopts
    local OPTIND opt
    while getopts ":h-:" opt ; do
       case $opt in
           h ) optHelp=true;;
           - ) case $OPTARG in
                  help ) FreeDiskSpace::Usage
                         exit 0;;
                  * ) echo "illegal option --$OPTARG"
                      FreeDiskSpace::Usage
                      exit 1;;
               esac;;
           ? ) echo "illegal option -$opt"
               FreeDiskSpace::Usage
               exit 1;;
      esac
    done
    shift $((OPTIND - 1))

    Log "optHelp = ${optHelp}"

    ${optHelp} && {
      FreeDiskSpace::Usage
      exit 0
    }

    # xargs is different between linux en osx => -r option is needed on linux
    # (in order to not run  the command if no argument provided)
    xargscommand="xargs -r"
    if [ "$OSTYPE" != 'linux-gnu' ]
    then
        xargscommand="xargs"
    fi

    #docker system prune => decomposition in each prune command : container, volume, network and images :

    try {
        docker container prune
    } catch {
        Log "No docker container deleted"
    }

    try {
        docker network prune
    } catch {
        Log "No docker network deleted"
    }

    echo "WARNING! This will remove all volume not used by at least one container, except the \"data\" ones."
    echo -n "Are you sure you want to continue? [y/N] "
    read -r yes
    if [[ "$yes" = 'y' || "$yes" = 'yes' ]]; then
        try {
        #docker volume prune ==> Remove all unused volumes , even data ones ... not what we want !!
        comm -13 <(docker volume ls -f name=data --format "{{.Name}}" | sort) <(docker volume ls -f dangling=true --format "{{.Name}}" | sort) | ${xargscommand} docker volume rm
        } catch {
            Log "No docker volumes deleted"
        }
    fi

    try {
        docker image prune
    } catch {
        Log "No docker image deleted"
    }

    # ==> docker image prune doesn't remove non tagged images versions :
    echo "WARNING! This will remove all images non tagged versions"
    echo -n "Are you sure you want to continue? [y/N] "
    read -r yes
    if [[ "$yes" = 'y' || "$yes" = 'yes' ]]; then
        try {
            docker images --no-trunc | grep '<none>' | awk '{ print $3 }' | "${xargscommand}" docker rmi
        } catch {
            Log "No docker images non tagged deleted"
        }
    fi

}

FreeDiskSpace::Usage()
{
  echo ""
  echo "$(UI.Color.Blue)Usage:$(UI.Color.Default)  jetdocker free-disk-space [OPTIONS]"
  echo ""
  echo "$(UI.Color.Yellow)Options:$(UI.Color.Default)"
  echo "  -h, --help               Print help information and quit"
  echo ""
}

