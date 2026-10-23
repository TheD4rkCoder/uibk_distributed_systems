import json
from compute_acceleration import compute_acceleration
import numpy as np

def lambda_handler(event, context):
    # Parse the input from the event

    payload = compute_acceleration(np.array(event['positions']), np.array(event['masses']))
    payload = payload.tolist()

    # Return the response
    return {
        'statusCode': 200,
        'body': json.dumps(payload),
    }

