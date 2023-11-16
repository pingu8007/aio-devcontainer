# !/bin/bash

[ ! "$(docker network ls | grep dev-infra)" ] \
  && docker network create dev-infra \
  || echo Docker network \"dev-infra\" is exist.
docker compose --file shared.docker-compose.yml --profile debug up -d
