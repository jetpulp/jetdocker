#!/usr/bin/env bash

COMMANDS['search-replace-db']='SearchReplaceDb::Execute' # Function name
COMMANDS_USAGE['30']="  search-replace-db        Run Search Replace DB in a container"

#
# Run the search-replace-db container configured in docker-compose.yml
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
           h ) SearchReplaceDb::Usage
               exit 0;;
           - ) case $OPTARG in
                  help ) SearchReplaceDb::Usage
                         exit 0;;
               esac;;
       esac
    done
    shift $((OPTIND - 1))

    Log "env.sh \$SEARCH_AND_REPLACE_OPTIONS : $SEARCH_AND_REPLACE_OPTIONS"
    Log "Command line options : $*"

    [ -z "$*" ] || SEARCH_AND_REPLACE_OPTIONS="$*"

    Log "Used options : $SEARCH_AND_REPLACE_OPTIONS"

    Compose::InitDockerCompose

    Log "Start Database and wait for connexion is ready"
    ${DOCKER_COMPOSE} ${dockerComposeFile} up -d db
    # Wait for database connection is ready, see https://github.com/betalo-sweden/await
    try {
      if [ ! -z "${MYSQL_DATABASE:-}" ]; then
        await -q -t 1m0s mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@localhost:${DOCKER_PORT_MYSQL}/$MYSQL_DATABASE > /dev/null 2>&1
      fi
      if [ ! -z "${POSTGRES_DB:-}" ]; then
        await -q -t 1m0s postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:${DOCKER_PORT_POSTGRES}/$POSTGRES_DB > /dev/null 2>&1
      fi
    } catch {
        echo "$(UI.Color.Red) Database failed to start in less than 1m"
        echo " Check log with this command : docker logs ${COMPOSE_PROJECT_NAME}-db "
        exit 1;
    }

    SearchReplaceDb::Run

}

#
# Run the search-replace-db container configured in docker-compose.yml
# "from" and "to" options determine the env targets,
#
SearchReplaceDb::Run()
{
    namespace search-replace-db
    ${DEBUG} && Log::AddOutput search-replace-db DEBUG
    Log "SearchReplaceDb::Run"

    if [[ ${#SEARCH_AND_REPLACE[@]} -gt 0 ]]; then
      Log "\$SEARCH_AND_REPLACE is defined"
    else
      Log "options doesn't contains --search, add it from config file or display error"
      DEPRECATED_CONFIG_FILE="./db/config.yml"
      if test -f "$DEPRECATED_CONFIG_FILE"; then
          Log "$DEPRECATED_CONFIG_FILE exists."
          echo "$(UI.Color.Yellow)Deprecated use of db/config.yml, please configure --search and --replace in SEARCH_AND_REPLACE env var in env.sh file instead$(UI.Color.Default)"
          if hash yq 2>/dev/null
          then
            search=$(yq '.search-and-replace-db[].production' $DEPRECATED_CONFIG_FILE)
            SEARCH_AND_REPLACE=("--search $search --replace $SERVER_NAME")
          else
            echo "$(UI.Color.Red) You need yq utils in order to read $DEPRECATED_CONFIG_FILE please install it"
            echo "$(UI.Color.Red) MacOS : brew install yq"
            echo "$(UI.Color.Red) Linux : wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq chmod +x /usr/bin/yq"
          fi
      else
        echo "$(UI.Color.Red)You should configure --search and --replace options in SEARCH_AND_REPLACE in env.sh file, for example : "
        echo "$(UI.Color.Default)export SEARCH_AND_REPLACE=(\"--search www.website.com --replace \${SERVER_NAME}\")"
        exit 1
      fi
    fi

    for searchAndReplace in "${SEARCH_AND_REPLACE[@]}"
    do
      ${DEBUG} && echo "${DOCKER_COMPOSE} run --rm search-replace-db php srdb.cli.php --host db --name $MYSQL_DATABASE --user root --pass root $searchAndReplace $SEARCH_AND_REPLACE_OPTIONS"
      ${DOCKER_COMPOSE} run --rm search-replace-db php srdb.cli.php --host db --name $MYSQL_DATABASE --user root --pass root $searchAndReplace $SEARCH_AND_REPLACE_OPTIONS
    done

}

SearchReplaceDb::Usage()
{
  echo ""
  echo "$(UI.Color.Blue)Usage:$(UI.Color.Default)  jetdocker search-replace-db [OPTIONS]"
  echo ""
  echo "$(UI.Color.Yellow)Options:$(UI.Color.Default)"
  echo "  -h, --help               Print help information and quit"
  echo "  see all Search Replace DB script options below"
  echo ""
  echo "Run Search Replace DB script (see https://interconnectit.com/products/search-and-replace-for-wordpress-databases/)"
  echo "The jetpulp/search-replace-db docker image must be configured in ${dockerComposeFileBase}"
  echo ""
  ${DOCKER_COMPOSE} run --rm search-replace-db php srdb.cli.php --help
}

