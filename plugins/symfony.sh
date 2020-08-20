#!/usr/bin/env bash

COMMANDS['symfony-restart']='Symfony::Execute' # Function name
COMMANDS_USAGE['03']="  symfony-restart          Restart symfony binary server (for enabling/disabling xdebug)"

optXdebug=false
optHelp=false


Symfony::Execute()
{

    namespace symfony
    ${DEBUG} && Log::AddOutput up DEBUG
    Log "Symfony::Execute"

    # Analyse des arguments de la ligne de commande grâce à l'utilitaire getopts
    local OPTIND opt
    while getopts ":xh-:" opt ; do
       case $opt in
           x ) optXdebug=true;;
           h ) optHelp=true;;
           - ) case $OPTARG in
                  xdebug ) optXdebug=true;;
                  help ) Symfony::Usage
                         exit 0;;
                  * ) echo "illegal option --$OPTARG"
                      Symfony::Usage
                      exit 1;;
               esac;;
           ? ) echo "illegal option -$opt"
               Symfony::Usage
               exit 1;;
      esac
    done
    shift $((OPTIND - 1))

    Log "optXdebug = ${optXdebug}"
    Log "optHelp = ${optHelp}"

    ${optHelp} && {
      Symfony::Usage
      exit 0
    }

    if [ ! -z "${SYMFONY_PORT:-}" ]; then
        Symfony::Stop
        if [ "$optXdebug" = true ]; then
            Symfony::XdebugOn
        else
            Symfony::XdebugOff
        fi
        Symfony::Start
    else
        echo "$(UI.Color.Red)This project is not configured for running with symfony binary server (no SYMFONY_PORT env var) $(UI.Color.Default)"
        exit 1;
    fi

}

Symfony::Usage()
{
  echo ""
  echo "$(UI.Color.Blue)Usage:$(UI.Color.Default)  jetdocker symfony-restart [OPTIONS]"
  echo ""
  echo "$(UI.Color.Yellow)Options:$(UI.Color.Default)"
  echo "  -x, --xdebug             Enable xdebug in Symfony Server"
  echo "  -h, --help               Print help information and quit"
  echo ""
  echo "Restart symfony server after enabling or disabling xdebug"
  echo ""
}

Symfony::Start()
{
   Log "Symfony::Start"
   if [ ! -z "${SYMFONY_PORT:-}" ]; then
       # For symfony < 4 bootstrap app.php or app_dev.php depending on SYMFONY_ENV var
       # For magento and symfony >=4 index.php bootstrap by default
       export passthru=''
       if [ -f "../${SYMFONY_PUBLIC_DIR}/app.php" ]; then
        if [ ${SYMFONY_ENV} = 'prod' ]; then
            passthru="--passthru=app.php"
        else
            passthru="--passthru=app_dev.php"
        fi
       fi
       # TRUSTED_PROXY_IPS env var needed by symfony in order to set https schem correctly on requests
       export TRUSTED_PROXY_IPS=127.0.0.1
       ${DEBUG} && echo "symfony server:start --no-tls --port=${SYMFONY_PORT} --dir=../ --document-root=../${SYMFONY_PUBLIC_DIR} --daemon ${passthru}"
       symfony server:start --no-tls --port=${SYMFONY_PORT} --dir=../ --document-root=${SYMFONY_PUBLIC_DIR} --daemon ${passthru}
   fi
}

Symfony::Stop()
{
   Log "Symfony::Stop"
   if [ ! -z "${SYMFONY_PORT:-}" ]; then
      symfony server:stop --dir=../
   fi
}

Symfony::XdebugOn()
{
  Log "Symfony::XdebugOn"
  PHP_VERSION=$(symfony php -r "echo preg_replace('/(\.\d+)$/','', phpversion());")
  sed -i'.original' -e 's/^;zend_extension/zend_extension/g' "/usr/local/etc/php/$PHP_VERSION/conf.d/ext-xdebug.ini"
  Log "xdebug enabled"
  symfony php -v
}

Symfony::XdebugOff()
{
  Log "Symfony::XdebugOff"
  PHP_VERSION=$(symfony php -r "echo preg_replace('/(\.\d+)$/','', phpversion());")
  sed -i'.original' -e 's/^zend_extension/;zend_extension/g' "/usr/local/etc/php/$PHP_VERSION/conf.d/ext-xdebug.ini"
  Log "xdebug disabled"
  symfony php -v
}

Symfony::Logs()
{
  Log "Symfony::Logs"
  if [ ! -z "${SYMFONY_PORT:-}" ]; then
     symfony server:log --dir=../ &
  fi

}