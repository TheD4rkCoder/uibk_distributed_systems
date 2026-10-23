import boto3
import json
import time

# boto3 automatically uses the EC2 instance profile (LabRole)
client = boto3.client('lambda', region_name='us-east-1')

# The input payload for the Lambda function
payload = {
    "W": 500000, "H": 500001, "T": 100000000000,
    "x": 0, "y": 0, "vx": 1, "vy": 1,
    "posX": 250000, "posY": 250000,
}

print(f"Invoking Lambda with payload: {json.dumps(payload)}")

# mesure the total round-trip time from EC2
t0 = time.perf_counter()

response = client.invoke(
    FunctionName='ex01-task',          # Your function name
    InvocationType='RequestResponse', # Synchronous call
    Payload=json.dumps(payload)
)

t1 = time.perf_counter()
wall_ms = (t1 - t0) * 1000

response_payload = json.loads(response['Payload'].read())
body = json.loads(response_payload['body'])
lambda_compute_ms = body['compute_ms']

print(f"Total round-trip (EC2 to Lambda): {wall_ms:.2f} ms")
print(f"Internal Lambda compute time:   {lambda_compute_ms:.2f} ms")
print(f"Overhead (Network + Cold Start): {wall_ms - lambda_compute_ms:.2f} ms")