# N-body web app

Small FastAPI app that simulates an $n$-body system in Python and visualizes the result in the browser.

## What it does

- Accepts `n` and `t_max` as inputs.
- Runs a finite simulation in Python and returns all sampled frames.
- Animates the returned trajectory in the browser and stops automatically when the final frame is reached.

## Run locally

```bash
cd nbody-web
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app:app --reload
```

Open `http://127.0.0.1:8000` in a browser, when running locally

