#!/usr/bin/env bash

COMMANDS['up']='Up::Execute' # Function name
COMMANDS_USAGE['up']="  up                       Start docker-compose after initializing context (databases, ports, proxy, etc... )"

optDelete=false
optBuild=false
optSilent=false
optOpen=false
optXdebug=false
optHelp=false

namespace up
${DEBUG} && Log::AddOutput up DEBUG

Up::Execute()
{
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

    Up::InitDockerCompose

   #stop and remove docker containers when stop script
   trap "docker-compose stop;docker-compose rm -f -v" SIGINT SIGTERM
   Log "RUN WHEN EXIT : docker-compose stop;docker-compose rm -f -v"

   Up::CheckImagesUpdate
   firstRunOfDay="$?"

   # On the first run, or on asked option : build the app
   if [ "$optBuild" = true ] || [ "$firstRunOfDay" -eq 1 ]; then
      Up::Install
   fi

   ${DEBUG} && docker-compose config
   echo "$(UI.Color.Green)docker-compose ${dockerComposeFile} ${dockerComposeVerboseOption} up -d ${JETDOCKER_UP_DEFAULT_SERVICE}$(UI.Color.Default)"
   docker-compose ${dockerComposeFile} ${dockerComposeVerboseOption} up -d ${JETDOCKER_UP_DEFAULT_SERVICE}

   Up::StartReverseProxy

   # connect the container nginx-reverse-proxy to the network of the project (required to communicate)
   try {
    docker network connect "${COMPOSE_PROJECT_NAME}_default" nginx-reverse-proxy > /dev/null 2>&1
   } catch {
     ${DEBUG} && Exception::PrintException "${__EXCEPTION__[@]}"
   }
   try {
    docker network connect bridge "${COMPOSE_PROJECT_NAME}-${JETDOCKER_UP_DEFAULT_SERVICE}" > /dev/null 2>&1
   } catch {
     ${DEBUG} && Exception::PrintException "${__EXCEPTION__[@]}"
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

    if [ "$optSilent" = false ]; then
        # log in standard output
        docker-compose logs --follow
    else
        echo "$(UI.Color.Green) For more informations run : docker-compose logs $(UI.Color.Default)"
    fi

}

Up::Usage()
{
  #Cette fonction affiche les consignes d'usage du script
  echo ""
  echo "$(UI.Color.Blue)Usage:$(UI.Color.Default)  jetdocker up [OPTIONS]"
  echo ""
  echo "$(UI.Color.Yellow)Options:$(UI.Color.Default)"
  echo "  -d, --delete-data        Delete data docker volumes before start"
  echo "  -b, --build              Force building (assets, etc...) before start"
  echo "  -x, --xdebug             Enable xdebug in PHP container"
  echo "  -s, --silent             Don't run docker-compose log --follow after start "
  echo "  -o, --open               Open browser after start "
  echo "  -h, --help               Print help information and quit"
  echo ""
}

Up::InitDockerCompose()
{
    Log "Jetdocker::InitDockerCompose"

    if [ "$dockerComposeInitialised" = true ]; then
        Log "docker-compose already initialised"
        return;
    fi

    Up::CheckOpenPorts

    if [ "$optDelete" = true ]; then
        # Delete data volumes
        Up::DeleteDataVolumes
        optDelete=false # avoid double delete option
    fi

    # Initialise data containers
    Up::InitDataVolumes

    # MacOSX : add specific compose config file
    if [ "$OSTYPE" != 'linux-gnu' ]; then
        if [ -f "docker-compose-osx.yml" ]; then
            Log "Docker4Mac use docker-compose-osx.yml configuration file"
            dockerComposeFile="-f docker-compose.yml -f docker-compose-osx.yml"
        fi
    fi

    dockerComposeInitialised=true

}

#
# Change default ports if already used
#
Up::CheckOpenPorts()
{
    Log "Up::CheckOpenPorts"
    export DOCKER_PORT_HTTP=$(Up::RaisePort $DOCKER_PORT_HTTP)
    export DOCKER_PORT_HTTPS=$(Up::RaisePort $DOCKER_PORT_HTTPS)
    export DOCKER_PORT_MYSQL=$(Up::RaisePort $DOCKER_PORT_MYSQL)
    export DOCKER_PORT_POSTGRES=$(Up::RaisePort $DOCKER_PORT_POSTGRES)
    export DOCKER_PORT_MAILHOG=$(Up::RaisePort $DOCKER_PORT_MAILHOG)

    Log "${0} : DOCKER_PORT_HTTP = ${DOCKER_PORT_HTTP}"
    Log "${0} : DOCKER_PORT_HTTPS = ${DOCKER_PORT_HTTPS}"
    Log "${0} : DOCKER_PORT_MYSQL = ${DOCKER_PORT_MYSQL}"
    Log "${0} : DOCKER_PORT_POSTGRES = ${DOCKER_PORT_POSTGRES}"
    Log "${0} : DOCKER_PORT_MAILHOG = ${DOCKER_PORT_MAILHOG}"

}

#
# Function called to set the port to the next free port
#
function Up::RaisePort {

    port=${1}
    try {
        nc -z -w 1 localhost "$port"
        Up::RaisePort $((port+1))
    } catch {
        echo $port
    }

}

#
# delete data volumes
# TO OVERRIDE in env.sh in other case than one simple database
#
Up::DeleteDataVolumes()
{
    Log "Up::DeleteDataVolumes"
    delete-data-volumes # To avoid BC Break, we keep old function name
}
delete-data-volumes()
{
    echo "$(UI.Color.Red)Do you really want to delete your data volumes? (y/n)"
    read -r yes
    if [ "$yes" = 'y' ]; then

        # Mysql data container
        # remove db container in case he's only stopped
        docker rm -f "${COMPOSE_PROJECT_NAME}-db" > /dev/null 2>&1
        # remove dbdata volume
        docker volume rm "${COMPOSE_PROJECT_NAME}-dbdata" > /dev/null 2>&1
        sleep 1 # some time the docker inspect next command don't relalize the volume has been deleted ! wait a moment is better
        echo "${COMPOSE_PROJECT_NAME}-dbdata volume DELETED ! $(UI.Color.Default)"

        Up::DeleteExtraDataVolumes

    fi
    echo "$(UI.Color.Default)"
}

#
# delete extra data containers
# TO OVERRIDE in env.sh in specific cases
# For exemple if you have an Elasticseach data container
#
Up::DeleteExtraDataVolumes()
{
    Log "Up::DeleteExtraDataVolumes"
    delete-extra-data-volumes # To avoid BC Break, we keep old function name
}
delete-extra-data-volumes() {
    Log "No extra data container to delete";
}

#
# init data containers
# TO OVERRIDE in env.sh in other case than one simple Mysql database
#
Up::InitDataVolumes()
{
    Log "Up::InitDataVolumes"
    init-data-containers # To avoid BC Break, we keep old function name
}
init-data-containers()
{
    # Database data volume :
    docker volume inspect "${COMPOSE_PROJECT_NAME}-dbdata" > /dev/null 2>&1
    if [ $? -eq 1 ]; then
        docker volume create --name "${COMPOSE_PROJECT_NAME}-dbdata"
        Up:FetchDatabaseBackup

        # run init-extra-data-containers before compose up because it can need volumes created in init-extra-data-containers
        Up:InitExtraDataVolumes

        # shellcheck disable=SC2086
        docker-compose ${dockerComposeVerboseOption} up -d db
        echo "Restoring Database ......... "
        echo ""
        startTime=$(date +%s)
        # Wait for database connection is ready, see https://github.com/betalo-sweden/await
        echo "Waiting ${DB_RESTORE_TIMEOUT} for mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@localhost:${DOCKER_PORT_MYSQL}/$MYSQL_DATABASE is ready ...... "
        echo ""
        echo "$(UI.Color.Green)  follow database restoration logs in an other terminal running this command : "
        echo ""
        echo "  docker logs -f ${COMPOSE_PROJECT_NAME}-db$(UI.Color.Default)"
        echo ""
        echo "... $(UI.Color.Yellow)if you see errors in logs and the restoration is blocked, cancel it here with CTRL+C $(UI.Color.Default)"
        echo ""
        # shellcheck disable=SC2086
        await -q -t ${DB_RESTORE_TIMEOUT} mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@localhost:${DOCKER_PORT_MYSQL}/$MYSQL_DATABASE > /dev/null 2>&1
        awaitReturn=$?
        endTime=$(date +%s)
        if [ $awaitReturn -eq 0 ]; then
            echo "$(UI.Color.Green) DATABASE RESTORED in $(expr "$endTime" - "$startTime") s !! $(UI.Color.Default)"
            hasSearchReplace=$(docker-compose config | grep search-replace-db 2> /dev/null | wc -l)
            if [ "$hasSearchReplace" -gt 0 ]; then
                search-replace-db
            fi
        else
            echo "$(UI.Color.Red) DATABASE RESTORATION FAILED "
            echo " Restoring since $(expr "$endTime" - "$startTime") s."
            echo " Check log with this command : docker logs ${COMPOSE_PROJECT_NAME}-db "
            echo " The database dump might be to big for beeing restaured in less than the ${DB_RESTORE_TIMEOUT} await timeout "
            echo " You can increase this timeout in env.sh DB_RESTORE_TIMEOUT parameter "
            echo " then re-run with jetdocker --delete-data up "
            exit 1;
        fi

    fi
}

Up:FetchDatabaseBackup()
{
    Log "Up::FetchDatabaseBackup"
    #TODO : implement this method in custom jetpulp file
}

Up:InitDataVolumes()
{
    Log "Up::InitDataVolumes"
    init-extra-data-containers # To avoid BC Break, we keep old function name
}
init-extra-data-containers()
{
    Log "No extra data container to create"
}

#
# Pull images from docker-compose config every day
#
Up::CheckImagesUpdate() {

    Log "Up::CheckImagesUpdate"
    flagFile=/tmp/jetdocker-${COMPOSE_PROJECT_NAME}
    if [ ! -f "$flagFile" ]; then
        echo 0 > "$flagFile"
    fi
    lastUpdate=$(cat "$flagFile")
    now=$(date +%s)
    oneDay=( 24*60*60 )
    if [ $(( now - oneDay)) -gt "$lastUpdate" ]; then
        echo "$now" > "$flagFile"
        # Pull images
        Log "docker-compose ${dockerComposeVerboseOption} pull --ignore-pull-failures"
        docker-compose ${dockerComposeVerboseOption} pull --ignore-pull-failures
    fi

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
    make install
    cd "$optConfigPath" || exit
    echo "$(UI.Color.Green)END Installation ... $(UI.Color.Default)"
    exit 1
}

#
# Start docker reverse proxy, if not already running :
#  container nginx-reverse-proxy listen ports 80 and 443 and proxies requests to corresponding containers
#  container nginx-reverse-proxy-gen listen containers start and stop and auto-configure nginx in nginx-reverse-proxy
#
# see https://github.com/jwilder/docker-gen
#     http://jasonwilder.com/blog/2014/03/25/automated-nginx-reverse-proxy-for-docker/
# Template is based on https://golang.org/pkg/text/template/
#
# Add proxies to 8443 ports for java tomcat applications
#
Up::StartReverseProxy() {

    Log "Up::StartReverseProxy"
    ## On force la déconnection aux réseau puis la suppression des containers nginx
    ## pour ensuite le redémarrer systématiquement, c'est plus roboste ainsi
    for network in $(docker network ls --filter name=default -q);
    do
        docker network disconnect --force "$network" nginx-reverse-proxy > /dev/null 2>&1
    done;
    docker rm -f -v nginx-reverse-proxy nginx-reverse-proxy-gen > /dev/null 2>&1

    echo "Start Nginx reverse-proxy"
    docker run -d -p 80:80 -p 443:443 --name nginx-reverse-proxy \
        -v certificat-ssl:/certs  \
        -v /tmp/nginx:/etc/nginx/conf.d \
        -t nginx
    templateDir=/tmp/templates
    if [ "$OSTYPE" != 'linux-gnu' ]
    then
        templateDir=~/tmp/templates
    fi
    mkdir -p $templateDir
    cat <<- EOM > $templateDir/nginx.tmpl
ssl_certificate     /certs/my-certificate.crt;
ssl_certificate_key /certs/my-certificate.key;
proxy_connect_timeout       600;
proxy_send_timeout          600;
proxy_read_timeout          600;
send_timeout                600;
server_names_hash_bucket_size  64;
client_max_body_size        100m;
server {
    listen 80 default_server;
    listen 443 ssl default_server;
    server_name _; # This is just an invalid value which will never trigger on a real hostname.
    error_log /proc/self/fd/2;
    access_log /proc/self/fd/1;
    return 503;
}

{{ range \$host, \$containers := groupByMulti $ "Env.VIRTUAL_HOST" "," }}

{{ range \$index, \$value := \$containers }}

	{{ \$addrLen := len \$value.Addresses }}
	{{ \$network := index \$value.Networks 0 }}
    {{ range \$i, \$address := \$value.Addresses }}
    {{ if eq \$address.Port "80" }}
upstream {{ \$host }} {
        # {{\$value.Name}}
        server {{ \$network.IP }}:{{ \$address.Port }};
}
server {
    gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
    listen 80;
    server_name {{ \$host }};
    proxy_buffering off;
    error_log /proc/self/fd/2;
    access_log /proc/self/fd/1;

    location / {
        proxy_pass http://{{ trim \$host }};
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # HTTP 1.1 support
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
    {{ end }}
    {{ if eq \$address.Port "443" "8443" }}
upstream {{ \$host }}-ssl {
        # {{\$value.Name}}
        server {{ \$network.IP }}:{{ \$address.Port }};
}
server {
    gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
    listen 443;
    server_name {{ \$host }};
    proxy_buffering off;
    error_log /proc/self/fd/2;
    access_log /proc/self/fd/1;

    location / {
        proxy_pass https://{{ trim \$host }}-ssl;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # HTTP 1.1 support
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
    {{ end }}
    {{ end }}
{{ end }}
{{ end }}
EOM
    echo "Start Nginx reverse-proxy config generator"
    docker run -d --name nginx-reverse-proxy-gen \
        --volumes-from nginx-reverse-proxy \
        -v /var/run/docker.sock:/tmp/docker.sock:ro \
        -v $templateDir:/etc/docker-gen/templates \
        -t jwilder/docker-gen \
        -notify-sighup nginx-reverse-proxy -watch -only-exposed \
        /etc/docker-gen/templates/nginx.tmpl /etc/nginx/conf.d/default.conf

    for network in $(docker network ls --filter name=default -q);
    do
        docker network connect "$network" nginx-reverse-proxy 2> /dev/null
    done;

}

