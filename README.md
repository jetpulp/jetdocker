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
* `git` should be installed
* `await` should be installed

#### Install bash4

On macOSX bash3 is installed by default, but you can install bash4

```shell
brew install bash
echo '/usr/local/bin/bash' | sudo tee -a /etc/shells
```

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
sh -c "$(curl -fsSL https://raw.githubusercontent.com/coordtechjetpulp/jetdocker/master/tools/install.sh)"
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
* DB_RESTORE_TIMEOUT : (optional, default=3m0s)database restoration timeout
* SERVER_NAME : (required) hostname
* VIRTUAL_HOST : (required) list of hostnames, separated by comma
* MYSQL_DATABASE : (optional) name of the database


The main usage of jetdocker is to run a docker-compose config :

```shell
jetdocker up
```

See all other available commands and options

```shell
jetdocker --help
```

## commands

* up : Start docker-compose after initializing context (databases, ports, proxy, etc... )
* term : Open a shell terminal into one of docker-compose service
* compose : Run a docker-compose command (alias for docker-compose run --rm)
* free-disk-space :Free disk space utility
* update : Update jetdocker to the latest version
* search-replace-db : Run Search Replace DB in a container
* phpmyadmin : Start/Restart a PhpMyAdmin container connecting to all running MySQL containers


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