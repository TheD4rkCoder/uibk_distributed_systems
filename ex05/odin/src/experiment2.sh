#!/bin/bash

A="python3 /app/auction_node.py"

docker compose up -d --build
docker exec ex05-node1 $A new
docker exec ex05-node1 $A -v --think 1 bid alice 100 & docker exec ex05-node2 $A -v --think 1 bid bob 90 & wait
docker exec ex05-node3 $A -v --think 1 bid carol 200 & docker exec ex05-node4 $A close & docker exec ex05-node5 $A close & wait
docker compose down