# Хранилища данных — лабораторные работы (Тимонин А.)

Вариант 13: **«Система должна описывать процесс работы торгового отдела»**.

| Папка | Лабораторная | Содержимое |
|---|---|---|
| `lab1/` | Лаб. 1 — Neo4j, социальный граф | `01_social_graph.cypher` — создание графа (24 узла, 63 ребра); `02_queries.cypher` — практические запросы; `draw_graph.py` — визуализация графа |
| `lab2/` | Лаб. 2 — 3NF и Data Vault в PostgreSQL | `01_3nf_schema.sql`, `02_3nf_test_data.sql` — модель 3NF; `03_datavault_schema.sql`, `04_datavault_load.sql`, `05_datavault_queries.sql` — модель Data Vault 2.0 и её загрузка; `diagrams/gen_erd.py` — генератор даталогических моделей |

## Как запустить

### Лабораторная 2 (PostgreSQL 14+)
```bash
createdb trade_dept
psql -d trade_dept -f lab2/01_3nf_schema.sql
psql -d trade_dept -f lab2/02_3nf_test_data.sql
psql -d trade_dept -f lab2/03_datavault_schema.sql
psql -d trade_dept -f lab2/04_datavault_load.sql
psql -d trade_dept -f lab2/05_datavault_queries.sql
```
Схема `trade` — операционная БД в 3NF, схема `dv` — хранилище Data Vault
(8 хабов, 9 линков, 12 сателлитов). Скрипт загрузки идемпотентен: при повторном
запуске в сателлиты попадают только изменившиеся записи (по `hash_diff`).

### Лабораторная 1 (Neo4j 5.x)
Открыть Neo4j Browser или Neo4j Aura Query (или `docker run -p 7474:7474 -p 7687:7687 neo4j:5`),
выполнить `lab1/01_social_graph.cypher`, затем запросы из `lab1/02_queries.cypher`.
