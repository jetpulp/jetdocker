Jetdocker
==============
![Jetdocker](https://raw.githubusercontent.com/docker/compose/master/logo.png "Docker Compose Logo")

`jetdocker` is a wrapper around docker-compose, especially opinionated for PHP developpement, but not only.

Some of the features are :
* can run several docker-compose projects, bind automatically to free ports if some try to bind on the same, using a reverse-http-proxy
* smooth database restoration, can use Search and Replace DB automatically
* SSL-TLS auto-signed certificate automatically created and configured, in order to test on https
* xdebug integration
* phpmyadmin integration

## Getting Started

### Prerequisites

__Disclaimer:__ _Jetdocker works on macOS and Linux._

* Unix-like operating system (macOS or Linux)
* bash 4
* `docker` and `docker-compose` should be installed
* `symfony` should be installed
* `git` should be installed
* `await` should be installed

#### Install bash4

On macOSX bash3 is installed by default, but you can install bash4

```shell
brew install bash
echo '/usr/local/bin/bash' | sudo tee -a /etc/shells
```

#### Install symfony binary

See https://symfony.com/download 

#### Install await

On linux

```shell
sudo curl -s -f -L -o /usr/local/bin/await https://github.com/betalo-sweden/await/releases/download/v0.4.0/await-linux-amd64
sudo chmod +x /usr/local/bin/await
```

On macOSX
```shell
curl -f -L -o /usr/local/bin/await https://github.com/betalo-sweden/await/releases/download/v0.4.0/await-darwin-amd64
chmod +x /usr/local/bin/await
```

### Basic Installation

jetdocker is installed by running one of the following commands in your terminal. You can install this via the command-line with `curl`.

```shell
sh -c "$(curl -fsSL https://raw.githubusercontent.com/jetpulp/jetdocker/master/tools/install.sh)"
```


### Basic Usage

In order to use `jetdocker` in your project you need a `docker` directory, containing all the jetdocker config files.
`docker` is the default path, you can specify a different one with the `jetdocker -c configPath` option.

You can find some examples of docker config directory in the `examples` directory of this repository, "ready to use" for wordpress, magento or symfony projects.

The bare minimum is a `docker-compose.yml` and a `env.sh` file in this directory.

The env.sh file is required in order to define some environement variables on each project

* COMPOSE_PROJECT_NAME : (required) a prefix used for naming containers and volumes
* JETDOCKER_UP_DEFAULT_SERVICE : (optional, default=web) docker-compose service used by `jetdocker up`
* JETDOCKER_DB_DEFAULT_SERVICE : (optional, default=db) docker-compose service used for database restoration
* JETDOCKER_TERM_DEFAULT_SERVICE : (optional) docker-compose service used by `jetdocker term`
* DB_RESTORE_TIMEOUT : (optional, default=3m0s) database restoration timeout
* SERVER_NAME : (required) hostname
* VIRTUAL_HOST : (required) list of hostnames, separated by comma
* MYSQL_DATABASE : (optional) name of the database

Usually `SERVER_NAME` is constructed based on an other env var : `JETDOCKER_DOMAIN_NAME`, jetdocker set it as default to `localhost.tv` (see http://localhost.tv), for example with `SERVER_NAME=project.$JETDOCKER_DOMAIN_NAME`, project.localhost.tv will resolve on 127.0.0.1.

`JETDOCKER_DOMAIN_NAME` can be modified in `~/.jetdockerrc`, for example: `JETDOCKER_DOMAIN_NAME=192.168.0.10.xip.io`, xip.io will resolve *.192.168.0.10.xip.io on 192.168.0.10, you could then test with a mobile device on your local server which is on 192.168.0.10 on your local LAN.

The main usage of jetdocker is to run a docker-compose config :

```shell
jetdocker up
```

Some usefull option of `jetdocker up` are :
* `jetdocker up -x` : Enable xdebug in PHP container
* `jetdocker up -o` : Open browser after start on the $SERVER_NAME url
* `jetdocker up -d` : Delete data docker volumes before start, forcing it to restore

See all other available commands and options

```shell
jetdocker --help
```

## Advanced Usage

Here are the different commands

* up : Start docker-compose after initializing context (databases, ports, proxy, etc... )
* term : Open a shell terminal into one of docker-compose service
* compose : Run a docker-compose command (alias for docker-compose run --rm)
* free-disk-space :Free disk space utility
* update : Update jetdocker to the latest version
* search-replace-db : Run Search Replace DB in a container
* phpmyadmin : Start/Restart a PhpMyAdmin container connecting to all running MySQL containers

## SSL/TLS Certificate

On first start of `jetdocker up`, jetdocker will generate a SSL/TLS certificate, signed by the `./cacerts/jetdockerRootCA.crt` Root CA certificate, for all the `$JETDOCKER_DOMAIN_NAME` subdomains (default is *.localhost.tv).
This certificate is stored in a docker volume named `jetdocker-ssl-certificate`, and this volume is mounted in the nginx-proxy container, and used by nginx.

In order to avoid the browser alert due to an unknown CA, you should import the `./cacerts/jetdockerRootCA.crt` in your browsers as a new CA :
* Firefox : https://wiki.wmtransfer.com/projects/webmoney/wiki/Installing_root_certificate_in_Mozilla_Firefox
* Chrome : https://wiki.wmtransfer.com/projects/webmoney/wiki/Installing_root_certificate_in_Google_Chrome

If you change your `$JETDOCKER_DOMAIN_NAME`, you will have to delete your `jetdocker-ssl-certificate` volume to force jetdocker to recreate it : `docker volume rm jetdocker-ssl-certificate`.

## Getting Updates

By default, an automatic update is done every day.


## Contributing

Feel free to send PR, and open issues.

## Road Map

* a "create" command which copy a template of docker config files


## Acknowledgement

__Disclaimer:__ _Jetdocker is standing on the shoulder of giants._

Thank's to
* Docker of course
* [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh) for inspiration
* [Bash OO Framework](https://github.com/niieani/bash-oo-framework)
* [Search Replace DB](https://interconnectit.com/products/search-and-replace-for-wordpress-databases/)
* All others ..

## Follow Us

We're on the social media.

* [@jetpulp](https://twitter.com/jetpulp) on Twitter. You should follow it.

## License

Jetdocker is released under the [MIT license](LICENSE.txt).

## About JETPULP

![JETPULP](https://blog.jetpulp.fr/wp-content/uploads/sites/2/2017/10/JETPULP_logo_alt_g__2.png)

Jetdocker was developped by the team at [JETPULP](https://www.jetpulp.fr/?utm_source=github), a [digital agency](https://www.jetpulp.fr/expertise/?utm_source=github).