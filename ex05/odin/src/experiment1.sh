#!/bin/bash

A="python3 /app/auction_node.py"

docker compose up -d --build
docker exec ex05-node1 $A new
docker exec ex05-node1 $A bid alice 10
docker exec ex05-node2 $A bid bob 20
docker exec ex05-node3 $A bid eve 25
docker exec ex05-node4 $A bid maurits 30
docker exec ex05-node5 $A bid alice 35
docker exec ex05-node1 $A close
for i in 1 2 3 4 5; do docker exec ex05-node$i $A query; done
docker compose down