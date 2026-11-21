#!/usr/bin/env python3
"""Plot results/results.csv from run_experiment.py as experiment.png."""

from __future__ import annotations

import csv
import os
import random
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RESULTS_DIR = ROOT / "results"
CSV_PATH = RESULTS_DIR / "results.csv"
OUTPUT_PATH = ROOT / "experiment.png"

os.environ.setdefault("MPLCONFIGDIR", str(RESULTS_DIR / ".mplconfig"))

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


def load_rows() -> list[dict[str, str]]:
    if not CSV_PATH.exists():
        raise SystemExit(f"{CSV_PATH.relative_to(ROOT)} not found; run ./run_experiment.py first")
    with CSV_PATH.open(newline="", encoding="utf-8") as csv_file:
        rows = list(csv.DictReader(csv_file))
    return [row for row in rows if row.get("processing_seconds")]


def main() -> int:
    rows = load_rows()
    if not rows:
        raise SystemExit("no successful runs in results.csv")

    frameworks = ["dapr", "csml"]
    labels = {"dapr": "Dapr", "csml": "CSML"}
    colors = {"dapr": "#3b6ea5", "csml": "#c46a2e"}

    processing = {
        framework: [float(row["processing_seconds"]) for row in rows if row["framework"] == framework]
        for framework in frameworks
    }
    startup = {
        framework: [float(row["startup_seconds"]) for row in rows if row["framework"] == framework]
        for framework in frameworks
    }
    active = [framework for framework in frameworks if processing[framework]]
    if not active:
        raise SystemExit("no framework has timing data")

    RESULTS_DIR.mkdir(exist_ok=True)
    plt.rcParams.update({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False})
    figure, (time_axis, startup_axis) = plt.subplots(1, 2, figsize=(11, 4.2))

    values = [processing[framework] for framework in active]
    positions = list(range(1, len(active) + 1))
    time_axis.boxplot(
        values,
        positions=positions,
        widths=0.45,
        patch_artist=True,
        boxprops={"facecolor": "#d9e2ec", "edgecolor": "#52606d"},
        medianprops={"color": "#102a43", "linewidth": 2},
        whiskerprops={"color": "#52606d"},
        capprops={"color": "#52606d"},
    )
    rng = random.Random(7)
    for position, framework in zip(positions, active):
        jitter = [rng.uniform(-0.08, 0.08) for _ in processing[framework]]
        time_axis.scatter(
            [position + offset for offset in jitter],
            processing[framework],
            color=colors[framework],
            s=28,
            zorder=3,
            label=labels[framework],
        )
    time_axis.set_xticks(positions, [labels[framework] for framework in active])
    time_axis.set_ylabel("processing time [s]")
    time_axis.set_title("First submission to final summary")
    time_axis.grid(axis="y", alpha=0.25)

    mean_processing = [statistics.mean(processing[framework]) for framework in active]
    mean_startup = [statistics.mean(startup[framework]) for framework in active]
    startup_axis.bar(
        [labels[framework] for framework in active],
        mean_processing,
        color=[colors[framework] for framework in active],
        label="processing",
    )
    startup_axis.bar(
        [labels[framework] for framework in active],
        mean_startup,
        bottom=mean_processing,
        color="#cbd2d9",
        label="startup / compile",
    )
    startup_axis.set_ylabel("mean wall time [s]")
    startup_axis.set_title("Startup overhead vs. processing")
    startup_axis.legend(frameon=False)
    startup_axis.grid(axis="y", alpha=0.25)
    for index, (processing_mean, startup_mean) in enumerate(zip(mean_processing, mean_startup)):
        startup_axis.text(
            index,
            processing_mean + startup_mean + 0.3,
            f"{processing_mean:.1f}s + {startup_mean:.1f}s",
            ha="center",
            fontsize=9,
        )

    correct = sum(1 for row in rows if row["correct"] == "True")
    figure.suptitle(f"UC3: Dapr vs. CSML ({correct}/{len(rows)} runs correct)", y=1.02)
    figure.tight_layout()
    figure.savefig(OUTPUT_PATH, dpi=160, bbox_inches="tight")
    print(f"wrote {OUTPUT_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
