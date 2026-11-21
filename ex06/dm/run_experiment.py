#!/usr/bin/env python3
"""Run UC3 end to end N times for both implementations and write results/results.csv."""

from __future__ import annotations

import argparse
import csv
import os
import re
import shutil
import signal
import statistics
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DAPR_DIR = ROOT / "dapr"
CSML_CONFIG_DIR = ROOT / "csml" / "config"
RESULTS_DIR = ROOT / "results"
LOG_DIR = RESULTS_DIR / "logs"
CSV_PATH = RESULTS_DIR / "results.csv"

EXPECTED_STATES = {
    "Order 1": "COMPLETED",
    "Order 2": "COMPLETED",
    "Order 3": "REJECTED",
    "Order 4": "COMPLETED",
    "Order 5": "REJECTED",
    "Order 6": "COMPLETED",
}

FIRST_MARKERS = ("submitted Order", "sent inventory-request for")
SUMMARY_MARKERS = ("final summary", "final order states")
ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
STATE_RE = re.compile(r"Order (\d+)=(COMPLETED|REJECTED)")


def strip_ansi(line: str) -> str:
    return ANSI_RE.sub("", line)


def parse_states(line: str) -> dict[str, str]:
    return {f"Order {number}": state for number, state in STATE_RE.findall(line)}


def run_command(
    framework: str,
    run_number: int,
    command: list[str],
    cwd: Path,
    env: dict[str, str],
    timeout_seconds: int,
) -> dict[str, object]:
    log_path = LOG_DIR / f"{framework}-{run_number:02d}.log"
    started = time.monotonic()
    first_submitted: float | None = None
    finished: float | None = None
    states: dict[str, str] = {}

    with log_path.open("w", encoding="utf-8") as log_file:
        process = subprocess.Popen(
            command,
            cwd=cwd,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            start_new_session=True,
        )
        assert process.stdout is not None

        try:
            for raw_line in process.stdout:
                now = time.monotonic()
                log_file.write(raw_line)
                log_file.flush()
                line = strip_ansi(raw_line)

                if first_submitted is None and any(marker in line for marker in FIRST_MARKERS):
                    first_submitted = now
                if any(marker in line for marker in SUMMARY_MARKERS):
                    parsed = parse_states(line)
                    if len(parsed) == 6:
                        states = parsed
                        finished = now

            return_code = process.wait(timeout=timeout_seconds)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=10)
            return_code = 124
        finally:
            elapsed = time.monotonic() - started

    if first_submitted is None or finished is None:
        return {
            "framework": framework,
            "run": run_number,
            "processing_seconds": "",
            "startup_seconds": "",
            "wall_seconds": round(elapsed, 3),
            "correct": False,
            "completed": "",
            "rejected": "",
            "orders": "",
            "return_code": return_code,
            "log": str(log_path.relative_to(ROOT)),
        }

    completed = sum(1 for state in states.values() if state == "COMPLETED")
    rejected = sum(1 for state in states.values() if state == "REJECTED")
    orders = ";".join(f"{order}={states[order]}" for order in sorted(states, key=lambda s: int(s.split()[1])))

    return {
        "framework": framework,
        "run": run_number,
        "processing_seconds": round(finished - first_submitted, 3),
        "startup_seconds": round(first_submitted - started, 3),
        "wall_seconds": round(elapsed, 3),
        "correct": return_code == 0 and states == EXPECTED_STATES,
        "completed": completed,
        "rejected": rejected,
        "orders": orders,
        "return_code": return_code,
        "log": str(log_path.relative_to(ROOT)),
    }


def prepare_dapr_env() -> dict[str, str]:
    env = os.environ.copy()
    local_dapr = ROOT.parent.parent / ".work" / "dapr" / "bin"
    if (local_dapr / "dapr").exists():
        env["PATH"] = f"{local_dapr}:{env.get('PATH', '')}"
    if shutil.which("dapr", path=env.get("PATH")) is None:
        raise SystemExit(
            "dapr not found. Install it or add .work/dapr/bin to PATH; see README."
        )
    return env


def run_dapr(run_number: int, timeout_seconds: int) -> dict[str, object]:
    return run_command(
        "dapr",
        run_number,
        ["./run.sh"],
        DAPR_DIR,
        prepare_dapr_env(),
        timeout_seconds,
    )


def run_csml(run_number: int, timeout_seconds: int) -> dict[str, object]:
    env = os.environ.copy()
    if shutil.which("docker") is None:
        raise SystemExit("docker not found; start Docker and retry.")

    subprocess.run(
        ["docker", "compose", "down", "--remove-orphans"],
        cwd=CSML_CONFIG_DIR,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    try:
        return run_command(
            "csml",
            run_number,
            [
                "docker",
                "compose",
                "up",
                "--abort-on-container-exit",
                "--exit-code-from",
                "coordinator",
            ],
            CSML_CONFIG_DIR,
            env,
            timeout_seconds,
        )
    finally:
        subprocess.run(
            ["docker", "compose", "down", "--remove-orphans"],
            cwd=CSML_CONFIG_DIR,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )


def summary(rows: list[dict[str, object]], framework: str) -> str:
    times = [float(row["processing_seconds"]) for row in rows if row["processing_seconds"] != ""]
    correct = sum(1 for row in rows if row["correct"])
    if not times:
        return f"{framework}: {correct}/{len(rows)} correct, no timing"
    return (
        f"{framework}: {correct}/{len(rows)} correct, "
        f"processing median {statistics.median(times):.2f}s "
        f"({min(times):.2f}-{max(times):.2f}s)"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runs", nargs="?", type=int, default=10, help="runs per framework (default: 10)")
    parser.add_argument(
        "--framework",
        choices=["all", "dapr", "csml"],
        default="all",
        help="which implementation(s) to run",
    )
    parser.add_argument("--timeout", type=int, default=180, help="seconds per run (default: 180)")
    args = parser.parse_args()
    if args.runs < 1:
        parser.error("runs must be >= 1")

    RESULTS_DIR.mkdir(exist_ok=True)
    LOG_DIR.mkdir(exist_ok=True)

    rows: list[dict[str, object]] = []
    frameworks = ["dapr", "csml"] if args.framework == "all" else [args.framework]

    for framework in frameworks:
        for run_number in range(1, args.runs + 1):
            print(f"[{framework} {run_number}/{args.runs}] running...", flush=True)
            row = run_dapr(run_number, args.timeout) if framework == "dapr" else run_csml(
                run_number, args.timeout
            )
            rows.append(row)
            if row["processing_seconds"] == "":
                print(f"  no summary found (exit {row['return_code']}); see {row['log']}")
            else:
                status = "ok" if row["correct"] else "WRONG"
                print(
                    f"  {row['processing_seconds']}s processing, "
                    f"{row['completed']} completed / {row['rejected']} rejected ({status})"
                )

    fieldnames = [
        "framework",
        "run",
        "processing_seconds",
        "startup_seconds",
        "wall_seconds",
        "correct",
        "completed",
        "rejected",
        "orders",
        "return_code",
        "log",
    ]
    with CSV_PATH.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nwrote {CSV_PATH.relative_to(ROOT)}")
    for framework in frameworks:
        framework_rows = [row for row in rows if row["framework"] == framework]
        print(summary(framework_rows, framework))

    return 0 if all(row["correct"] for row in rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
