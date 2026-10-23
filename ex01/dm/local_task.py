import json
import time

def lambda_handler(event, context):
    W = int(event['W'])
    H = int(event['H'])
    T = int(event['T'])
    x = int(event['x'])
    y = int(event['y'])
    vx = int(event['vx'])
    vy = int(event['vy'])
    posX = int(event['posX'])
    posY = int(event['posY'])

    start = time.perf_counter()

    period = 2 * W
    hits = 0
    temp = x
    for _ in range(period):
        if temp == posX or temp == 2 * W - posX:
            hits += 1
        temp = (temp + vx) % (2 * W)

    compute_ms = (time.perf_counter() - start) * 1000
    return {'hits': hits, 'compute_ms': compute_ms}

# Same payload you use in invoke_lambda.py
payload = {
    "W": 500000, "H": 500001, "T": 100000000000,
    "x": 0, "y": 0, "vx": 1, "vy": 1,
    "posX": 250000, "posY": 250000,
}

# just some stub
class _Ctx:
    aws_request_id = "local"

results = []
for i in range(6):
    r = lambda_handler(payload, _Ctx())
    results.append(r)
    label = "cold" if i == 0 else f"warm {i}"
    print(f"{label:>6}: compute = {r['compute_ms']:.2f} ms   hits = {r['hits']}")