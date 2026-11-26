# EX06 - Programming Abstractions (UC4 sensor monitoring)

## dapr

needs jdk 21, maven, docker, dapr cli 1.19.1

```
dapr init --runtime-version 1.19.1
cd dapr
./run.sh
```

run.sh compiles, sets a new RUN_ID for this run, starts the coordinator with its sidecar, waits 8 s, then starts sensor 1-3 with their own sidecars

messages from other runs (stale) or seen twice (duplicates) are ignored by the coordinator and logged as `ignored ...`

the coordinator exits after the summary, the sensors exit after their 4 readings

## csml

needs docker, the cirrina image is amd64 only (runs under rosetta on apple silicon)

```
cd csml/config
./run.sh
```

run.sh starts etcd, a zenoh router and 4 cirrina containers (RUN=coordinator, sensor1, sensor2, sensor3), all with ../src/uc4.pkl as main.pkl, follows the logs until the coordinator terminates, then docker compose down

the sensors only start measuring after the coordinator answered their ready event, so the start order of the containers doesn't matter

`docker compose logs` prints the containers one after another, so the order of lines from different containers in the output isn't the real order, the coordinator's own lines are
