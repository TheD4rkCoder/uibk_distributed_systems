# Draws the two concurrent-bid experiments from results/.
# CLARIFICATION: I used Deepseek to write this file (from top to bottom)!
import glob
import os
import re

import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
LINE = re.compile(r"\[([A-E]) [\d.]+\] bid (\d+) (accepted|rejected)")
NODES = "ABCDE"
COLOR = {"accepted": "#2a9d8f", "rejected": "#e63946"}

def read(pattern):
    """Returns {(round, node): (amount, outcome)}; the round is the bid amount / 100."""
    bids = {}
    for path in glob.glob(os.path.join(HERE, "results", pattern)):
        for line in open(path):
            m = LINE.search(line)
            if m:
                bids[(int(m.group(2)) // 100, m.group(1))] = (int(m.group(2)), m.group(3))
    return bids

figure, (left, right) = plt.subplots(1, 2, figsize=(11, 3.6))

# left: five equal bids per round, exactly one of them is accepted
equal = read("exp2-*-r*.log")
for (round, node), (_, outcome) in equal.items():
    left.scatter(round, NODES.index(node), s=110 if outcome == "accepted" else 55,
                 marker="o" if outcome == "accepted" else "x", color=COLOR[outcome], zorder=3)
left.set_xticks(range(1, 6), [f"round {r}\nbid {r * 100}" for r in range(1, 6)])
left.set_yticks(range(len(NODES)), list(NODES))
left.set_title("five simultaneous equal bids: only one is accepted")
left.set_ylim(-0.6, len(NODES) + 0.1)
left.grid(color="#dddddd", zorder=0)

# right: five different bids at the same time, the highest wins
mixed = read("exp2-mixed-*.log")
for (_, node), (amount, outcome) in mixed.items():
    right.scatter(NODES.index(node), amount, s=110 if outcome == "accepted" else 55,
                  marker="o" if outcome == "accepted" else "x", color=COLOR[outcome], zorder=3)
    right.annotate(str(amount), (NODES.index(node), amount), textcoords="offset points",
                   xytext=(0, 10), ha="center", fontsize=8)
right.set_xticks(range(len(NODES)), list(NODES))
right.set_xlabel("node that placed the bid")
right.set_ylabel("bid amount")
right.set_title("five simultaneous different bids: the highest wins")
right.margins(y=0.12)
right.grid(color="#dddddd", zorder=0)

for outcome in COLOR:
    left.scatter([], [], color=COLOR[outcome], marker="o" if outcome == "accepted" else "x",
                 s=110 if outcome == "accepted" else 55, label=outcome)
left.legend(loc="upper center", ncol=2, frameon=False, fontsize=8)
figure.tight_layout()
figure.savefig(os.path.join(HERE, "races.png"), dpi=160)
print("wrote races.png")
