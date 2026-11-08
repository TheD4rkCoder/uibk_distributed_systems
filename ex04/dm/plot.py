# Draws the role of each node over time from samples/ (written by run_experiment.sh).
# CLARIFICATION: I used Deepseek to write this file (from top to bottom)!

import re

import matplotlib.pyplot as plt
from matplotlib.patches import Patch

COLORS = {"follower": "#9ecae1", "candidate": "#f4a261", "leader": "#2a9d8f"}
# the leader sends one heartbeat every kHeartbeat (read it, so the plot follows node.cpp)
src = open("src/node.cpp").read()
m = re.search(r"^constexpr auto kHeartbeat = (\d+)ms;", src, re.M)
HEARTBEAT = (int(m.group(1)) if m else 50) / 1000
MIN_WIDTH = 0.020  # candidates are often only a few ms long; give them a visible sliver

starts, events, killed = {}, [], None
for line in open("samples/events.log"):
    parts = line.split()
    if parts[0] == "event":
        events.append((parts[1], float(parts[-1])))
        if parts[1] == "kill":
            killed = parts[2]
    else:
        starts.setdefault(parts[0], []).append(float(parts[2]))

t0 = events[0][1]
events = [(name, t - t0) for name, t in events]
at = dict(events)

spans = {node: [] for node in "ABC"}
for node in "ABC":
    runs, run = [], []
    for line in open(f"samples/{node}.log"):
        if "start:" in line and run:
            runs.append(run)
            run = []
        run.append(line)
    runs.append(run)

    for i, lines in enumerate(runs):
        offset = starts[node][i] - t0
        start, state, term = None, "follower", 0
        end = at["kill"] if (node == killed and i == 0) else at["end"]
        for line in lines:
            m = re.search(r"\[[A-C] +([\d.]+)\] (.*)", line)
            if not m:
                continue
            t, msg = float(m.group(1)) + offset, m.group(2)
            start = t if start is None else start
            term = int(re.search(r"term (\d+)$", msg).group(1)) if "term" in msg[-6:] else term
            if "election timeout -> candidate" in msg:
                spans[node].append((start, t, state, term))
                start, state = t, "candidate"
            elif "elected leader" in msg:
                spans[node].append((start, t, state, term))
                start, state = t, "leader"
            elif msg.startswith("-> follower"):
                spans[node].append((start, t, state, term))
                start, state = t, "follower"
        spans[node].append((start, end, state, term))

fig, ax = plt.subplots(figsize=(9, 3.0))

# heartbeats: a leader broadcasts one every HEARTBEAT ms while it is leader;
# drawn as short ticks inside the leader bar, a full-height comb reads as a grid
for row, node in enumerate("ABC"):
    for start, end, state, _ in spans[node]:
        if start is None or state != "leader":
            continue
        t = start
        while t < end:
            ax.plot([t, t], [2 - row - 0.27, 2 - row + 0.27], color="white", alpha=0.4,
                    linewidth=0.6, zorder=3)
            t += HEARTBEAT

for row, node in enumerate("ABC"):
    for start, end, state, term in spans[node]:
        if start is None or end <= start:
            continue
        if state == "candidate" and end - start < MIN_WIDTH:
            # too short to draw as a bar: mark the moment with a single thick line
            ax.plot([start, start], [2 - row - 0.28, 2 - row + 0.28], color=COLORS["candidate"],
                    linewidth=2.5, zorder=3)
            continue
        ax.barh(2 - row, end - start, left=start, height=0.55, color=COLORS[state], zorder=2)
        if state == "leader":
            ax.text(start + (end - start) / 2, 2 - row, f"leader, term {term}",
                    ha="center", va="center", fontsize=7, color="white")

# crash -> new leader, annotated like the table
new_leader = min((start for node in "ABC" for start, end, state, _ in spans[node]
                  if state == "leader" and start > at["kill"]), default=None)
if new_leader is not None:
    y = -0.40
    ax.annotate("", xy=(new_leader, y), xytext=(at["kill"], y),
                arrowprops=dict(arrowstyle="<->", color="0.35", linewidth=0.8))
    ax.text((at["kill"] + new_leader) / 2, y - 0.14, f"{round((new_leader - at['kill']) * 1000)} ms",
            ha="center", va="top", fontsize=8, color="0.25")

for name, t in events:
    if name in ("kill", "restart"):
        ax.axvline(t, color="#c1121f", linestyle="--", linewidth=1)
        ax.text(t + 0.06, 2.45, name, color="#c1121f", fontsize=8, va="top")

ax.set_yticks([2, 1, 0], ["A", "B", "C"])
ax.tick_params(axis="both", which="both", length=0) # no tick marks, the grid is enough
ax.set_xlabel("time [s]")
ax.set_ylim(-0.95, 2.55)
ax.set_xlim(0, at["end"])
ax.legend(handles=[Patch(color=c, label=s) for s, c in COLORS.items()]
                  + [Patch(color=COLORS["leader"], alpha=0.35, label=f"heartbeat ({HEARTBEAT * 1000:.0f} ms)")],
          loc="upper center", bbox_to_anchor=(0.5, 1.16), ncol=4, fontsize=7.5, frameon=False)
fig.tight_layout()
fig.savefig("timeline.png", dpi=200)
