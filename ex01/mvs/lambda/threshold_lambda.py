"""
AWS Lambda threshold recommendation

Input (JSON):
    {
      "lowerPercentile": 5,
      "upperPercentile": 95,
      "minValues": 50,
      "sensors": [
        {"sensorId": 30001, "type": "TEMPERATURE", "values": [21.3, 21.5, ...]},
        ...
      ]
    }

Output (JSON):
    {
      "results": [
        {"sensorId": 30001, "type": "TEMPERATURE", "count": 168, "lower": 17.42, "upper": 19.96},
        {"sensorId": 30002, "type": "HUMIDITY", "count": 12, "skipped": "not enough values"}
      ],
      "computeMs": 0.41
    }

Works both for direct invocation (event = payload) and via a Function URL
(event["body"] = JSON string).
"""
import base64
import json
import math
import time


def percentile(sorted_values, p):
    n = len(sorted_values)
    if n == 1:
        return sorted_values[0]
    pos = p * (n + 1) / 100.0
    if pos < 1:
        return sorted_values[0]
    if pos >= n:
        return sorted_values[-1]
    fpos = math.floor(pos)
    lower = sorted_values[fpos - 1]
    upper = sorted_values[fpos]
    return lower + (pos - fpos) * (upper - lower)


def round2(value):
    #java Math.round(x * 100.0) / 100.0 rounds half up
    return math.floor(value * 100.0 + 0.5) / 100.0


def recommend(sensor, lower_p, upper_p, min_values):
    values = sorted(float(v) for v in sensor.get("values", []))
    result = {"sensorId": sensor.get("sensorId"), "type": sensor.get("type"), "count": len(values)}
    if len(values) < min_values:
        result["skipped"] = "not enough values"
        return result
    result["lower"] = round2(percentile(values, lower_p))
    result["upper"] = round2(percentile(values, upper_p))
    return result


def parse_event(event):
    if isinstance(event, dict) and "body" in event:  #function URL / API Gateway
        body = event["body"] or "{}"
        if event.get("isBase64Encoded"):
            body = base64.b64decode(body).decode()
        return json.loads(body)
    return event


def response(status, payload, via_url):
    if not via_url:
        return payload
    return {"statusCode": status, "headers": {"Content-Type": "application/json"}, "body": json.dumps(payload)}


def lambda_handler(event, context):
    via_url = isinstance(event, dict) and "body" in event
    try:
        payload = parse_event(event)
        lower_p = float(payload.get("lowerPercentile", 5))
        upper_p = float(payload.get("upperPercentile", 95))
        min_values = int(payload.get("minValues", 50))
        sensors = payload["sensors"]
    except (ValueError, KeyError, TypeError) as e:
        return response(400, {"error": f"invalid input: {e}"}, via_url)

    start = time.perf_counter()
    results = [recommend(s, lower_p, upper_p, min_values) for s in sensors]
    compute_ms = round((time.perf_counter() - start) * 1000, 3)

    return response(200, {"results": results, "computeMs": compute_ms}, via_url)
