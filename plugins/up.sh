#!/usr/bin/env bash

COMMANDS['up']='Up::Execute' # Function name
COMMANDS_USAGE[0]="  up                       Start docker-compose after initializing context (databases, ports, proxy, etc... )"

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

   ${DEBUG} && docker-compose config
   echo "$(UI.Color.Green)docker-compose ${dockerComposeFile} ${dockerComposeVerboseOption} up -d ${JETDOCKER_UP_DEFAULT_SERVICE}$(UI.Color.Default)"
   docker-compose ${dockerComposeFile} ${dockerComposeVerboseOption} up -d ${JETDOCKER_UP_DEFAULT_SERVICE}

   Up::StartReverseProxy

   # connect the container nginx-reverse-proxy to the network of the project (required to communicate)
   message=""
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
  echo "  -d, --delete-data        Delete data docker volumes before start"
  echo "  -b, --build              Force building (assets, etc...) before start"
  echo "  -x, --xdebug             Enable xdebug in PHP container"
  echo "  -s, --silent             Don't run docker-compose log --follow after start"
  echo "  -o, --open               Open browser after start"
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
    exit
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
        try {
            docker network disconnect --force "$network" nginx-reverse-proxy > /dev/null 2>&1
        } catch {
            Log "docker network disconnect --force $network nginx-reverse-proxy error"
        }
    done;
    try {
        docker rm -f -v nginx-reverse-proxy nginx-reverse-proxy-gen > /dev/null 2>&1
    } catch {
        Log "docker rm -f -v nginx-reverse-proxy nginx-reverse-proxy-gen error"
    }

    echo "Start Nginx reverse-proxy"
    docker run -d -p 80:80 -p 443:443 --name nginx-reverse-proxy \
        -v jetdocker-ssl-certificate:/certs  \
        -v /tmp/nginx:/etc/nginx/conf.d \
        -t nginx
    templateDir=/tmp/templates
    if [ "$OSTYPE" != 'linux-gnu' ]
    then
        templateDir=~/tmp/templates
    fi
    mkdir -p $templateDir
    cat <<- EOM > $templateDir/nginx.tmpl
ssl_certificate     /certs/jetdocker-ssl-certificate.crt;
ssl_certificate_key /certs/jetdocker-ssl-certificate.key;
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

Up::Stop()
{
    try {
        docker-compose stop
        docker-compose rm -f -v
    } catch {
        Log 'End'
    }
}