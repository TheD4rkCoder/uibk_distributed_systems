#!/usr/bin/env python3
"""Plot the request times from nbody_bench.sh (nbody_bench_results.csv)."""

import csv
import statistics
import sys
from collections import defaultdict

import matplotlib.pyplot as plt

SERIES_COLORS = ["#2a78d6", "#eb6834", "#1baf7a"]
TEXT_SECONDARY = "#52514e"
GRID = "#e4e3df"


def load(path):
    # {t_max: {n: [time, ...]}}
    data = defaultdict(lambda: defaultdict(list))
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            if not row["time"]:
                continue
            data[int(row["t_max"])][int(row["n"])].append(float(row["time"]))
    return data


def main():
    in_file = sys.argv[1] if len(sys.argv) > 1 else "nbody_bench_results.csv"
    out_file = sys.argv[2] if len(sys.argv) > 2 else "nbody_bench_plot.png"

    data = load(in_file)
    if not data:
        sys.exit(f"No data in {in_file}")

    fig, ax = plt.subplots(figsize=(8, 5))

    for color, (t_max, by_n) in zip(SERIES_COLORS, sorted(data.items())):
        ns = sorted(by_n)
        means = [statistics.mean(by_n[n]) for n in ns]
        stdevs = [statistics.stdev(by_n[n]) if len(by_n[n]) > 1 else 0 for n in ns]

        # individual runs
        for n in ns:
            ax.scatter([n] * len(by_n[n]), by_n[n], s=12, color=color, alpha=0.3, linewidths=0)

        # mean ± standard deviation
        ax.errorbar(ns, means, yerr=stdevs, color=color, linewidth=2, marker="o",
                    markersize=6, capsize=4, label=f"t_max = {t_max}")

        runs = len(by_n[ns[0]])
        for n, m in zip(ns, means):
            ax.annotate(f"{m:.2f}s", (n, m), textcoords="offset points", xytext=(-8, 8),
                        ha="right", fontsize=9, color=TEXT_SECONDARY)

    ax.set_title(f"N-body simulation request time (mean ± std, {runs} runs)", loc="left")
    ax.set_xlabel("Number of bodies (n)")
    ax.set_ylabel("Request time (s)")
    ax.set_ylim(bottom=0)
    ax.margins(x=0.1)
    ax.grid(axis="y", color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    if len(data) > 1:
        ax.legend(frameon=False)

    fig.tight_layout()
    fig.savefig(out_file, dpi=150)
    print(f"Saved plot to {out_file}")


if __name__ == "__main__":
    main()
