"""
Ploting file created with Claude Opus 5.5
"""
import matplotlib.pyplot as plt
import numpy as np

# Raw runs in seconds (output of bench_lambda.sh)
SEQUENTIAL = {  # k sequential requests
    "local":  {1: [0.060, 0.053, 0.051], 10: [0.419, 0.402, 0.516],
               50: [1.576, 1.325, 1.159], 100: [2.121, 2.064, 1.815]},
    "lambda": {1: [0.066, 0.076, 0.053], 10: [0.652, 0.611, 0.593],
               50: [2.852, 2.631, 2.308], 100: [4.528, 4.512, 4.367]},
}
PARALLEL = {  # 100 requests, P parallel clients
    "local":  {1: [1.594, 1.565, 1.435], 4: [1.322, 1.262, 1.400], 8: [1.391, 1.270, 1.293]},
    "lambda": {1: [3.740, 3.649, 3.635], 4: [1.779, 1.466, 1.486], 8: [1.408, 1.328, 1.355]},
}
N_PARALLEL_REQUESTS = 100

SERIES = [  # (key, legend label, color) - categorical slots 1 and 2, CVD-validated
    ("local", "VM only (baseline)", "#2a78d6"),
    ("lambda", "VM + Lambda (hybrid)", "#eb6834"),
]
TEXT_PRIMARY = "#0b0b0b"
TEXT_SECONDARY = "#52514e"
GRID = "#e4e3df"
SURFACE = "#fcfcfb"


def stats(runs, transform):
    # transform the mean run time (not the mean of transformed values) so numbers match the report tables
    runs = np.array(runs)
    value = transform(runs.mean())
    extremes = (transform(runs.min()), transform(runs.max()))
    return value, value - min(extremes), max(extremes) - value


def grouped_bars(ax, data, transform, fmt):
    params = sorted(next(iter(data.values())).keys())
    x = np.arange(len(params))
    width = 0.36
    for i, (key, label, color) in enumerate(SERIES):
        offset = (i - 0.5) * (width + 0.02)  # small surface gap between neighbouring bars
        means, lo, hi = zip(*(stats(data[key][p], lambda r, p=p: transform(r, p)) for p in params))
        bars = ax.bar(x + offset, means, width, color=color, label=label, zorder=2)
        ax.errorbar(x + offset, means, yerr=[lo, hi], fmt="none", ecolor=TEXT_SECONDARY,
                    elinewidth=1, capsize=3, zorder=3)
        for bar, m, h in zip(bars, means, hi):
            ax.text(bar.get_x() + bar.get_width() / 2, m + h, fmt(m), ha="center", va="bottom",
                    fontsize=8, color=TEXT_PRIMARY)
    ax.set_xticks(x, [str(p) for p in params])
    return params


def style(ax, title, xlabel, ylabel):
    ax.set_title(title, loc="left", fontsize=11, color=TEXT_PRIMARY, pad=10)
    ax.set_xlabel(xlabel, color=TEXT_SECONDARY)
    ax.set_ylabel(ylabel, color=TEXT_SECONDARY)
    ax.set_facecolor(SURFACE)
    ax.grid(axis="y", color=GRID, linewidth=0.8, zorder=0)
    ax.tick_params(colors=TEXT_SECONDARY, length=0)
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    ax.spines["bottom"].set_color(TEXT_SECONDARY)
    ax.margins(y=0.15)


fig, (ax_seq, ax_par) = plt.subplots(1, 2, figsize=(10, 4.2))
fig.patch.set_facecolor(SURFACE)

# (a) latency per request = total time / k
grouped_bars(ax_seq, SEQUENTIAL, lambda run, k: run / k * 1000, lambda v: f"{v:.0f}")
style(ax_seq, "(a) Latency per request, k sequential requests",
      "k (number of sequential requests)", "ms per request (mean of 3 runs)")

# (b) throughput = 100 requests / total time
grouped_bars(ax_par, PARALLEL, lambda run, p: N_PARALLEL_REQUESTS / run, lambda v: f"{v:.0f}")
style(ax_par, "(b) Throughput, 100 requests",
      "P (parallel clients)", "requests per second (mean of 3 runs)")

handles, labels = ax_seq.get_legend_handles_labels()
fig.legend(handles, labels, loc="upper center", ncol=2, frameon=False, fontsize=9,
           labelcolor=TEXT_PRIMARY, bbox_to_anchor=(0.5, 1.0))
fig.text(0.5, -0.02, "Threshold recommendation endpoint on a t2.micro; whiskers show min/max of the 3 runs.",
         ha="center", fontsize=8, color=TEXT_SECONDARY)
fig.tight_layout(rect=(0, 0, 1, 0.93))
fig.savefig("task3_comparison.pdf", bbox_inches="tight", facecolor=SURFACE)
fig.savefig("task3_comparison.png", dpi=200, bbox_inches="tight", facecolor=SURFACE)
print("saved task3_comparison.pdf")
