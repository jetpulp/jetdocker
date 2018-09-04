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

jetdocker is installed by running one of the following commands in your terminal. You can install this via the command-line with either `curl` or `wget`.

#### via curl

```shell
sh -c "$(curl -fsSL https://raw.githubusercontent.com/coordtechjetpulp/jetdocker/master/tools/install.sh)"
```

#### via wget

```shell
sh -c "$(wget https://raw.githubusercontent.com/coordtechjetpulp/jetdocker/master/tools/install.sh -O -)"
```

### Basic Usage

In order to use `jetdocker` in your project you need a `docker` directory, containing all the jetdocker config files.
This is the default path must you can specify a different path with the `-c` option.

You can find some examples of docker config directory in the `examples` directory of this repository, "ready to use" for wordpress, magento or symfony projects.

The bare minimum is a `docker-compose.yml` and a `env.sh` in this directory.


The main usage of jetdocker is to run a docker-compose config :

```shell
jetdocker up
```

See all available commands and options

```shell
jetdocker --help
```
#### Environnement variables in env.sh

The env.sh file is required in order to define some environement variables on each project

* COMPOSE_PROJECT_NAME : (required) a prefix used for naming containers and volumes
* JETDOCKER_UP_DEFAULT_SERVICE : (optional, default=web) docker-compose service used by `jetdocker up`
* JETDOCKER_DB_DEFAULT_SERVICE : (optional, default=db) docker-compose service used for database restoration
* JETDOCKER_TERM_DEFAULT_SERVICE : (optional) docker-compose service used by `jetdocker term`
* DB_RESTORE_TIMEOUT : (optional, default=3m0s)database restoration timeout
* SERVER_NAME : (required) hostname
* VIRTUAL_HOST : (required) list of hostnames, separated by comma
* MYSQL_DATABASE : (optional) name of the database

## Getting Updates

By default, an automatic update is done every day.


### Manual Updates

If you'd like to upgrade at any point in time (maybe someone just released a new command and you don't want to wait a week?) you just need to run:

```shell
jetdocker update
```

## Contributing

Feel free to send PR, and open issues.

## Acknowledgement



## Follow Us

We're on the social media.

* [@jetpulp](https://twitter.com/jetpulp) on Twitter. You should follow it.

## License

Jetdocker is released under the [MIT license](LICENSE.txt).

## About JETPULP

![JETPULP](https://blog.jetpulp.fr/wp-content/uploads/sites/2/2017/10/JETPULP_logo_alt_g__2.png)

Jetdocker was developped by the team at [JETPULP](https://www.jetpulp.fr/?utm_source=github), a [digital agency](https://www.jetpulp.fr/expertise/?utm_source=github).