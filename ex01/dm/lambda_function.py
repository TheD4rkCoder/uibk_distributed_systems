import json
import time

def lambda_handler(event, context):
    # same inputs as cpp version
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

    # very simplified logic ignoring y, vy, H and T
    period = 2 * W  # Simplified 1D period for demonstration
    hits = 0
    temp = x
    for _ in range(period):
        if temp == posX or temp == 2 * W - posX:
            hits += 1
        temp = (temp + vx) % (2 * W)

    compute_ms = (time.perf_counter() - start) * 1000
    return {
        'statusCode': 200,
        'body': json.dumps({
            'hits': hits,
            'compute_ms': compute_ms
        })
    }