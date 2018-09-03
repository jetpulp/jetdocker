Jetdocker
==============
![Jetdocker](https://raw.githubusercontent.com/docker/compose/master/logo.png "Docker Compose Logo")

`jetdocker` is an open source framework for managing multiple docker-compose projects, especially for PHP developpement, but not only.

Some of the features are :
* can run several docker-compose projects, bind automatically to free ports if some try to bind on the same, and use a reverse-http-proxy
* smooth database restoration, can use Search and Replace DB automatically
* SSL-TLS auto-signed certificate automatically created and configured, in order to test on https
* xdebug integration
* phpmyadmin integration

## Getting Started

### Prerequisites

__Disclaimer:__ _Jetdocker works on macOS and Linux._

* Unix-like operating system (macOS or Linux)
* `docker` and `docker-compose` should be installed
* `git` should be installed
* `await` should be installed

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

The main usage of jetdocker is to run a docker-compose config :

```shell
jetdocker up
```

See all available commands and options

```shell
jetdocker --help
```

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