# !/bin/bash

docker network create dev-infra
docker compose -f shared.docker-compose.yml up -d
