#!/usr/bin/env bash

COMMANDS['search-replace-db']='SearchReplaceDb::Execute' # Function name
COMMANDS_USAGE['30']="  search-replace-db        Run Search Replace DB in a container"

optFrom=production
optTo=local

#
# Run the search-replace-db container configured in docker-compose.yml
# "from" and "to" options determine the env targets,
#
SearchReplaceDb::Execute()
{
    namespace search-replace-db
    ${DEBUG} && Log::AddOutput search-replace-db DEBUG
    Log "SearchReplaceDb::Execute"

    # Analyse des arguments de la ligne de commande grâce à l'utilitaire getopts
    OPTERR=1
    local OPTIND opt
    while getopts ":hf:t:-:" opt; do
       case $opt in
           f ) optFrom=$OPTARG;;
           t ) optTo=$OPTARG;;
           h ) SearchReplaceDb::Usage
               exit 0;;
           - ) case $OPTARG in
                  help ) SearchReplaceDb::Usage
                         exit 0;;
                  * ) echo "illegal option --$OPTARG"
                      SearchReplaceDb::Usage
                      exit 1;;
               esac;;
           ? ) echo "illegal option -$opt"
               SearchReplaceDb::Usage
               exit 1;;
      esac
    done
    shift $((OPTIND - 1))

    Log "optFrom = ${optFrom}"
    Log "optTo   = ${optTo}"

    Compose::InitDockerCompose

    ${DEBUG} && echo "docker-compose run --rm search-replace-db php srdb.bulk.php --from $optFrom --to $optTo"
    docker-compose run --rm search-replace-db php srdb.bulk.php --from "$optFrom" --to "$optTo"

}

SearchReplaceDb::Usage()
{
  echo ""
  echo "$(UI.Color.Blue)Usage:$(UI.Color.Default)  jetdocker search-replace-db [OPTIONS]"
  echo ""
  echo "$(UI.Color.Yellow)Options:$(UI.Color.Default)"
  echo "  -f,                      From environement defined in ${optConfigPath}/db/config.yml (default is production)"
  echo "  -t,                      To environement defined in ${optConfigPath}/db/config.yml (default is local)"
  echo "  -h, --help               Print help information and quit"
  echo ""
  echo "Run Search Replace DB script (see https://interconnectit.com/products/search-and-replace-for-wordpress-databases/)"
  echo "The jetpulp/search-replace-db docker image must be configured in docker-compose.yml"
  echo ""
}

