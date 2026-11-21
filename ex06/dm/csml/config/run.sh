#!/usr/bin/env bash

# LLM generated;
# I would just instead do:
# docker compose down
# docker compose up -d --force-recreate
# docker compose logs -f coordinator inventory payment | grep -E 'coordinator|inventory|payment'


# Starts etcd, a Zenoh router, and three Cirrina containers.
# Stop with Ctrl-C, then: docker compose -f docker-compose.yml down
set -euo pipefail
cd "$(dirname "$0")"

docker compose -f docker-compose.yml up --remove-orphans
