from __future__ import annotations

from datetime import datetime
import math
from pathlib import Path

import numpy as np
from fastapi import FastAPI
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
import json

import boto3


lambda_client = boto3.client("lambda", region_name="us-east-1")


def compute_acceleration_workload(positions: np.ndarray, masses: np.ndarray) -> np.ndarray:
    payload = {
        "positions": positions.tolist(),
        "masses": masses.tolist(),
    }
    response = lambda_client.invoke(
        FunctionName="lambda_acceleration",
        InvocationType="RequestResponse",
        Payload=json.dumps(payload),
    )
    response_payload = json.loads(response["Payload"].read())
    if response_payload.get("statusCode") != 200:
        raise RuntimeError(f"Lambda invocation failed: {response_payload}")
    return np.array(json.loads(response_payload["body"]))


PROJECT_ROOT = Path(__file__).resolve().parent
STATIC_DIR = PROJECT_ROOT / "static"

DEFAULT_DT = 0.01
MAX_OUTPUT_FRAMES = 240


class SimulationRequest(BaseModel):
    n: int = Field(default=5, ge=2, le=200)
    t_max: float = Field(default=20.0, gt=0.0, le=200.0)


app = FastAPI(title="N-body visualizer")
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")



def simulate(n: int, t_max: float) -> dict:
    seed = 42 + n * 17 + int(t_max * 100)
    rng = np.random.default_rng(seed)

    masses = rng.uniform(0.6, 2.0, size=n)
    positions = rng.normal(scale=2.0, size=(n, 2))
    velocities = rng.normal(scale=0.25, size=(n, 2))

    center_of_mass = np.sum(positions * masses[:, None], axis=0) / np.sum(masses)
    momentum = np.sum(velocities * masses[:, None], axis=0) / np.sum(masses)
    positions = positions - center_of_mass
    velocities = velocities - momentum

    dt = DEFAULT_DT
    total_steps = max(1, int(math.ceil(t_max / dt)))
    sample_every = max(1, total_steps // MAX_OUTPUT_FRAMES)

    frames = []
    acceleration = compute_acceleration_workload(positions, masses)

    for step in range(total_steps + 1):
        current_time = min(step * dt, t_max)
        if step % sample_every == 0 or step == total_steps:
            frames.append({"t": round(float(current_time), 6), "positions": positions.tolist()})

        if step == total_steps:
            break

        positions = positions + velocities * dt + 0.5 * acceleration * dt * dt
        next_acceleration = compute_acceleration_workload(positions, masses)
        velocities = velocities + 0.5 * (acceleration + next_acceleration) * dt
        acceleration = next_acceleration

    return {
        "n": n,
        "t_max": t_max,
        "dt": dt,
        "frame_count": len(frames),
        "masses": masses.tolist(),
        "frames": frames,
    }


@app.get("/")
async def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html", media_type="text/html")


@app.post("/api/simulate")
def run_simulation(request: SimulationRequest) -> JSONResponse:
    startTime = datetime.now()
    payload = simulate(request.n, request.t_max)
    endTime = datetime.now()
    print(f"Simulation completed in {(endTime - startTime).total_seconds():.3f} seconds")
    return JSONResponse(payload)
