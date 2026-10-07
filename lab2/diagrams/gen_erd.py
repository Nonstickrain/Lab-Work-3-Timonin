"""Генерация даталогических моделей (ER-диаграмм) по каталогу PostgreSQL.

Запуск: python3 gen_erd.py  (нужны psql и graphviz `dot`).
Результат: erd_3nf.png и erd_datavault.png в этой папке.
"""
import os
import subprocess
from collections import defaultdict

DB = os.environ.get("PGDATABASE", "trade_dept")
HERE = os.path.dirname(os.path.abspath(__file__))


def q(sql):
    cmd = ["psql", "-d", DB, "-At", "-F", "\t", "-c", sql]
    if os.geteuid() == 0:
        cmd = ["runuser", "-u", "postgres", "--"] + cmd
    out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    return [line.split("\t") for line in out.strip().splitlines() if line]


def meta(schema):
    cols = q(f"""select c.table_name, c.column_name,
        case when c.data_type='character varying' then 'varchar('||c.character_maximum_length||')'
             when c.data_type='character' then 'char('||c.character_maximum_length||')'
             when c.data_type='numeric' then 'numeric('||c.numeric_precision||','||c.numeric_scale||')'
             when c.data_type like 'timestamp%' then 'timestamp'
             else c.data_type end, c.is_nullable
        from information_schema.columns c join information_schema.tables t
          on t.table_schema=c.table_schema and t.table_name=c.table_name and t.table_type='BASE TABLE'
        where c.table_schema='{schema}' order by c.table_name, c.ordinal_position""")
    pks = q(f"""select tc.table_name, kcu.column_name from information_schema.table_constraints tc
        join information_schema.key_column_usage kcu on kcu.constraint_name=tc.constraint_name
         and kcu.table_schema=tc.table_schema
        where tc.table_schema='{schema}' and tc.constraint_type='PRIMARY KEY'""")
    fks = q(f"""select cl.relname, a.attname, fcl.relname
        from pg_constraint co join pg_class cl on cl.oid=co.conrelid
        join pg_namespace n on n.oid=cl.relnamespace
        join pg_class fcl on fcl.oid=co.confrelid
        join pg_attribute a on a.attrelid=co.conrelid and a.attnum=any(co.conkey)
        where co.contype='f' and n.nspname='{schema}'""")
    tables = defaultdict(list)
    for t, c, ty, nl in cols:
        tables[t].append((c, ty, nl))
    pk = defaultdict(set)
    for t, c in pks:
        pk[t].add(c)
    fk = defaultdict(set)
    edges = []
    for t, c, ft in fks:
        fk[t].add(c)
        edges.append((t, c, ft))
    return tables, pk, fk, edges


def node(t, cols, pk, fk, header_color, body_color):
    rows = [f'<tr><td colspan="3" bgcolor="{header_color}"><font color="white"><b>{t}</b></font></td></tr>']
    for c, ty, nl in cols:
        tag = ("PK " if c in pk else "") + ("FK" if c in fk else "")
        name = f"<b>{c}</b>" if c in pk else c
        nn = "" if nl == "YES" else " NN"
        rows.append(f'<tr><td align="left" bgcolor="{body_color}">{tag.strip()}</td>'
                    f'<td align="left" bgcolor="{body_color}">{name}</td>'
                    f'<td align="left" bgcolor="{body_color}"><font color="#555555">{ty}{nn}</font></td></tr>')
    return (f'"{t}" [label=<<table border="0" cellborder="1" cellspacing="0" cellpadding="3">'
            + "".join(rows) + "</table>>];")


def render(schema, out, colorer, title, rankdir="LR", engine="dot", only=None, compact=False):
    tables, pk, fk, edges = meta(schema)
    if only:
        tables = {t: c for t, c in tables.items() if t in only}
        edges = [e for e in edges if e[0] in only and e[2] in only]
    if compact:  # обзорная схема: только имена таблиц
        tables = {t: [] for t in tables}
    lines = [f'digraph G {{ graph [rankdir={rankdir}, splines=polyline, nodesep=0.5, ranksep=1.0, '
             f'label="{title}", labelloc=t, fontsize=22, fontname="DejaVu Sans", pad=0.4];',
             'node [shape=plaintext, fontname="DejaVu Sans", fontsize=10];',
             'edge [color="#666666", arrowhead=crow, arrowtail=tee, dir=both];']
    for t, cols in tables.items():
        h, b = colorer(t)
        lines.append(node(t, cols, pk[t], fk[t], h, b))
    seen = set()
    for t, c, ft in edges:
        if (t, ft, c) in seen:
            continue
        seen.add((t, ft, c))
        lines.append(f'"{ft}" -> "{t}";' if not compact else f'"{ft}" -> "{t}" [arrowtail=none];')
    lines.append("}")
    dot = "\n".join(lines)
    with open(os.path.join(HERE, out + ".dot"), "w") as f:
        f.write(dot)
    extra = ["-Goverlap=prism", "-Gsep=+15", "-Gsplines=true"] if engine != "dot" else []
    subprocess.run([engine, *extra, "-Tpng", "-Gdpi=110", "-o", os.path.join(HERE, out + ".png"),
                    os.path.join(HERE, out + ".dot")], check=True)


def color_3nf(t):
    ref = {"city", "position", "product_category", "order_status", "payment_method"}
    fact = {"sales_order", "order_item", "payment", "supply", "supply_item", "supplier_product"}
    if t in ref:
        return "#6b7280", "#f3f4f6"
    if t in fact:
        return "#b45309", "#fff7ed"
    return "#1d4ed8", "#eff6ff"


def color_dv(t):
    if t.startswith("hub_"):
        return "#1d4ed8", "#dbeafe"   # хабы — синие
    if t.startswith("link_"):
        return "#b91c1c", "#fee2e2"   # линки — красные
    return "#a16207", "#fef9c3"       # сателлиты — жёлтые


SALES = {"hub_order", "hub_customer", "hub_employee", "hub_product", "hub_payment", "link_order",
         "link_order_product", "link_payment_order", "sat_order", "sat_order_line", "sat_customer",
         "sat_payment"}
SUPPLY = {"hub_supply", "hub_supplier", "hub_employee", "hub_product", "link_supply",
          "link_supply_product", "link_supplier_product", "link_employee_manager", "sat_supply",
          "sat_supply_line", "sat_supplier", "sat_supplier_product", "sat_employee"}
CATALOG = {"hub_product", "hub_category", "link_product_category", "link_category_hierarchy",
           "sat_product", "sat_product_price", "sat_category"}

if __name__ == "__main__":
    render("trade", "erd_3nf", color_3nf, "Даталогическая модель 3NF — торговый отдел (схема trade)")
    render("dv", "erd_datavault", color_dv,
           "Даталогическая модель Data Vault — торговый отдел (схема dv): хабы / линки / сателлиты", engine="fdp")
    render("dv", "dv_overview", color_dv, "Data Vault: обзорная схема (синие — хабы, красные — линки, жёлтые — сателлиты)",
           engine="fdp", compact=True)
    render("dv", "dv_sales", color_dv, "Data Vault — область «Продажи»", only=SALES)
    render("dv", "dv_supply", color_dv, "Data Vault — область «Закупки и персонал»", only=SUPPLY)
    render("dv", "dv_catalog", color_dv, "Data Vault — область «Каталог товаров»", only=CATALOG)
    print("ok")
