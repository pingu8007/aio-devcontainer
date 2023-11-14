# Local Development Env Starter

## 1. `dev.dockerfile`, `images.docker-compose.yml` and `images-build.sh`

Those file are the core of devcontainer.

`dev.dockerfile` is a multi-stage dockerfile with following features:

- Ubuntu 20.04/22.04 (switchable)
- git (latest, form `git-core/ppa`)
- common utils (sudo, nano, patch, less, htop, unzip, tzdata)
- network utils (curl, wget, ca-certificate, socat, net-tools, iputils-ping, dnsutils)
- jdk 8/15/17 (switchable)
- maven
- nvm
- node 14 & npm 6
- aws-cli 2

`images.docker-compose.yml` is a set of pre-defined images, and `images-build.sh` is the builder script.

## 2. `shared.docker-compose.yml` and `shared-init.sh`

`shared.docker-compose.yml` is a set of service containers used in local development, including:

- zrk container (all-in-one service, used by legacy project)
- zookeeper
- kafka & kafka-ui
- redis
- plantuml server
- sonar, postgresql and openldap

`shared-init.sh` is the starter.

## 3. `backend.docker-compose.yml`, `frontend.docker-compose.yml` and `.env.example`

Sample docker-compose files that can be used with IDE's devcontainer feature.

Frontend also need to configure AWS credential before start developing. Check `.env.example`.

## 4. `static.docker-compose.yml` and `www.conf`

Nginx service to serve frontend locally.

This service is depend on backend devcontainer.