"""Разбор 01_social_graph.cypher, подсчёт узлов/рёбер и визуализация графа.

Запуск: python3 draw_graph.py  -> social_graph.png
"""
import os
import re
from collections import Counter

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import networkx as nx

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "01_social_graph.cypher"), encoding="utf-8").read()
src = "\n".join(l for l in src.splitlines() if not l.strip().startswith("//"))
create = src[src.index("CREATE\n"):]

node_re = re.compile(r"\((\w+):(\w+)\s*\{(.*?)\}\)", re.S)
edge_re = re.compile(r"\((\w+)\)-\[:(\w+)(?:\s*\{[^}]*\})?\]->\((\w+)\)")

nodes = {}
for var, label, props in node_re.findall(create):
    name = re.search(r"name:\s*'([^']*)'", props)
    nodes[var] = (label, name.group(1) if name else var)
edges = edge_re.findall(create)

missing = {v for a, _, b in edges for v in (a, b) if v not in nodes}
assert not missing, f"Ссылки на неизвестные узлы: {missing}"
print("Узлов:", len(nodes), dict(Counter(l for l, _ in nodes.values())))
print("Рёбер:", len(edges), dict(Counter(t for _, t, _ in edges)))

COLORS = {"Persona": "#4C8EDA", "Group": "#F79767", "Goal": "#8DCC93",
          "Product": "#C990C0", "Employee": "#DA7194", "City": "#FFC454"}
EDGE_COLORS = {"KNOWS": "#1f4e8c", "RECOMMENDED": "#b8336a", "BOUGHT": "#7a3e9d"}

G = nx.MultiDiGraph()
for v, (label, name) in nodes.items():
    G.add_node(v, label=label, name=name)
for a, t, b in edges:
    G.add_edge(a, b, type=t)

# Раскладка: персонажи в центре по кругу, остальные — внешним кольцом по типам
pos = {}
import math
personas = [v for v in nodes if nodes[v][0] == "Persona"]
for i, v in enumerate(personas):
    ang = 2 * math.pi * i / len(personas) + math.pi / 2
    pos[v] = (2.6 * math.cos(ang), 2.6 * math.sin(ang))
outer_order = ["Group", "Goal", "Product", "City", "Employee"]
outer = [v for lab in outer_order for v in nodes if nodes[v][0] == lab]
for i, v in enumerate(outer):
    ang = 2 * math.pi * i / len(outer) + math.pi / 2 + 0.12
    pos[v] = (5.3 * math.cos(ang), 5.3 * math.sin(ang))
# фиксированная радиальная раскладка (персонажи — внутренний круг)

fig, ax = plt.subplots(figsize=(17, 15), dpi=110)
ax.set_title("Социальный граф персонажей торгового отдела (Neo4j)\n"
             f"{len(nodes)} узлов, {len(edges)} рёбер", fontsize=17, pad=14)

seen_pairs = Counter()
for a, b, d in G.edges(data=True):
    key = tuple(sorted((a, b)))
    seen_pairs[key] += 1
    rad = 0.08 + 0.12 * (seen_pairs[key] - 1)
    col = EDGE_COLORS.get(d["type"], "#9a9a9a")
    nx.draw_networkx_edges(G, pos, edgelist=[(a, b)], ax=ax, edge_color=col, width=1.4,
                           arrows=True, arrowstyle="-|>", arrowsize=14, node_size=2600,
                           connectionstyle=f"arc3,rad={rad}", alpha=0.85)
    (x1, y1), (x2, y2) = pos[a], pos[b]
    mx, my = (x1 + x2) / 2, (y1 + y2) / 2
    ax.text(mx + rad * (y2 - y1) * 0.5, my - rad * (x2 - x1) * 0.5, d["type"], fontsize=6.5,
            color=col, ha="center", va="center",
            bbox=dict(boxstyle="round,pad=0.1", fc="white", ec="none", alpha=0.75))

for lab, colr in COLORS.items():
    vs = [v for v in nodes if nodes[v][0] == lab]
    size = 3400 if lab == "Persona" else 2600
    nx.draw_networkx_nodes(G, pos, nodelist=vs, node_color=colr, node_size=size, ax=ax,
                           edgecolors="#333333", linewidths=1.2, label=f":{lab}")


def wrap(s, w=13):
    words, lines, cur = s.split(), [], ""
    for wd in words:
        if len(cur) + len(wd) + 1 > w and cur:
            lines.append(cur)
            cur = wd
        else:
            cur = (cur + " " + wd).strip()
    lines.append(cur)
    return "\n".join(lines)


nx.draw_networkx_labels(G, pos, {v: wrap(n) for v, (_, n) in nodes.items()}, font_size=7.5, ax=ax)
leg = ax.legend(scatterpoints=1, loc="lower left", fontsize=11, markerscale=0.35, frameon=True,
                title="Типы узлов")
ax.axis("off")
plt.tight_layout()
out = os.path.join(HERE, "social_graph.png")
plt.savefig(out, bbox_inches="tight")
print("saved", out)
