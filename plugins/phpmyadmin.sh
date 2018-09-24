#!/usr/bin/env bash

COMMANDS['phpmyadmin']='PhpMyAdmin::Execute' # Function name
COMMANDS_USAGE[6]="  phpmyadmin               Start/Restart a PhpMyAdmin container connecting to all running MySQL containers"
COMMANDS_STANDALONE['phpmyadmin']=' ' # Function name

optHelp=false
optPort=8888

#
# (Re)-Start phpmyadmin container
# phpmyadmin-gen container inspect every db container and auto-configure phpmyadmin container to connect to them
#
PhpMyAdmin::Execute()
{
    namespace phpmyadmin
    ${DEBUG} && Log::AddOutput phpmyadmin DEBUG
    Log "PhpMyAdmin::Execute"

    # Analyse des arguments de la ligne de commande grâce à l'utilitaire getopts
    local OPTIND opt
    while getopts ":hp:-:" opt ; do
       case $opt in
           h ) optHelp=true;;
           p ) optPort=$OPTARG;;
           - ) case $OPTARG in
                  help ) PhpMyAdmin::Usage
                         exit 0;;
                  * ) echo "illegal option --$OPTARG"
                      PhpMyAdmin::Usage
                      exit 1;;
               esac;;
           ? ) echo "illegal option -$opt"
               PhpMyAdmin::Usage
               exit 1;;
      esac
    done
    shift $((OPTIND - 1))

    Log "optHelp = ${optHelp}"

    ${optHelp} && {
      PhpMyAdmin::Usage
      exit 0
    }

    try {
        docker rm -f -v phpmyadmin phpmyadmin-gen > /dev/null 2>&1
    } catch {
        Log "No phpmyadmin container to remove"
    }

    templateDir=/tmp/templates
    if [ "$OSTYPE" != 'linux-gnu' ]
    then
        templateDir=~/tmp/templates
    fi
    mkdir -p $templateDir

    cat <<- EOM > $templateDir/pma.config.tmpl
<?php
\$cfg['NavigationDisplayServers']=true;
\$i=1;
{{ range \$containers := groupBy $ "Env.MYSQL_DATABASE" }}
{{ range \$index, \$value := \$containers }}
	{{ \$addrLen := len \$value.Addresses }}
	{{ \$network := index \$value.Networks 0 }}
    {{ range \$i, \$address := \$value.Addresses }}
\$i++;
\$cfg['Servers'][\$i]['host']='{{ \$network.IP }}';
\$cfg['Servers'][\$i]['verbose']='{{\$value.Name}}';
\$cfg['Servers'][\$i]['auth_type']='config';
\$cfg['Servers'][\$i]['user']='root';
\$cfg['Servers'][\$i]['password']='root';
    {{ end }}
{{ end }}
{{ end }}
EOM

    echo "Start PhpMyAdmin config generator"
    docker run -d --name phpmyadmin-gen \
        -v /tmp/phpmyadmin:/etc/phpmyadmin/ \
        -v /var/run/docker.sock:/tmp/docker.sock:ro \
        -v $templateDir:/etc/docker-gen/templates \
        -t jwilder/docker-gen \
        /etc/docker-gen/templates/pma.config.tmpl /etc/phpmyadmin/config.user.inc.php

    echo "Start PhpMyAdmin"
    docker run --name phpmyadmin -d \
        -v /tmp/phpmyadmin/config.user.inc.php:/etc/phpmyadmin/config.user.inc.php \
        -e PMA_ABSOLUTE_URI=http://pma."$JETDOCKER_DOMAIN_NAME"  \
        -e VIRTUAL_HOST=pma."$JETDOCKER_DOMAIN_NAME" \
         -p "$optPort:80" phpmyadmin/phpmyadmin

    for network in $(docker network ls --filter name=default -q);
    do
        docker network connect "$network" phpmyadmin 2> /dev/null
    done;

    echo ""
    echo "$(UI.Color.Green)  PHPMyAdmin is up and running here http://pma.${JETDOCKER_DOMAIN_NAME}:${optPort}/"
    echo ""

}

PhpMyAdmin::Usage()
{
  echo ""
  echo "$(UI.Color.Blue)Usage:$(UI.Color.Default)  jetdocker phpmyadmin [OPTIONS]"
  echo ""
  echo "$(UI.Color.Yellow)Options:$(UI.Color.Default)"
  echo "  -h, --help               Print help information and quit"
  echo "  -p                       Listen on this port, default is 8888"
  echo ""
  echo "Start/Restart a PhpMyAdmin container connecting to all running MySQL containers "
  echo ""
}

