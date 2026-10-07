// =====================================================================
// Лабораторная работа 1 (Neo4j). Практические запросы к социальному графу
// Выполнять после 01_social_graph.cypher
// =====================================================================

// 1. Весь граф (визуализация в Neo4j Browser)
MATCH (n)-[r]->(m) RETURN n, r, m;

// 2. Типы узлов и их количество
MATCH (n) RETURN labels(n)[0] AS label, count(*) AS cnt ORDER BY cnt DESC;

// 3. Типы рёбер и их количество
MATCH ()-[r]->() RETURN type(r) AS type, count(*) AS cnt ORDER BY cnt DESC;

// 4. Персонажи каждой группы с готовностью к покупке
MATCH (p:Persona)-[:BELONGS_TO]->(g:Group)
RETURN g.name AS grp, collect(p.name) AS personas, round(avg(p.readiness), 1) AS avg_readiness
ORDER BY avg_readiness DESC;

// 5. Фильтрация: эксперты с высокой готовностью купить (WHERE)
MATCH (p:Persona)
WHERE p.experience = 'эксперт' AND p.readiness >= 7
RETURN p.name, p.occupation, p.readiness ORDER BY p.readiness DESC;

// 6. Друзья друзей Сергея Иванова, которых он ещё не знает (рекомендация контактов)
MATCH (me:Persona {name: 'Сергей Иванов'})-[:KNOWS]-(:Persona)-[:KNOWS]-(fof:Persona)
WHERE fof <> me AND NOT (me)-[:KNOWS]-(fof)
RETURN DISTINCT fof.name AS recommended_contact;

// 7. Рекомендация товаров: что купили знакомые, но персонаж ещё не купил
MATCH (me:Persona {name: 'Марина Белова'})-[:KNOWS]-(friend:Persona)-[:BOUGHT]->(pr:Product)
WHERE NOT (me)-[:BOUGHT]->(pr)
RETURN pr.name AS product, collect(DISTINCT friend.name) AS bought_by;

// 8. Самые «влиятельные» персонажи (степень по связям KNOWS и RECOMMENDED)
MATCH (p:Persona)
OPTIONAL MATCH (p)-[k:KNOWS]-()
WITH p, count(k) AS knows
OPTIONAL MATCH (p)-[r:RECOMMENDED]->()
RETURN p.name, knows, count(r) AS recommendations, knows + count(r) AS influence
ORDER BY influence DESC;

// 9. Кратчайший путь знакомства от пенсионера до проектировщика
MATCH path = shortestPath((a:Persona {name: 'Виктор Орлов'})-[:KNOWS*..6]-(b:Persona {name: 'Елена Соколова'}))
RETURN path;  // в табличном виде: [n IN nodes(path) | n.name] AS chain, length(path) AS hops

// 10. Выручка по менеджерам торгового отдела через их клиентов
MATCH (e:Employee)-[:SERVES]->(p:Persona)-[b:BOUGHT]->(:Product)
RETURN e.name AS manager, count(b) AS purchases, sum(b.amount) AS revenue
ORDER BY revenue DESC;

// 11. Цели, которые разделяют разные группы
MATCH (g:Group)<-[:BELONGS_TO]-(:Persona)-[:HAS_GOAL]->(gl:Goal)
RETURN gl.name AS goal, gl.type AS type, collect(DISTINCT g.name) AS groups
ORDER BY size(groups) DESC;

// 12. Персонажи по городам
MATCH (p:Persona)-[:LIVES_IN]->(c:City)
RETURN c.name AS city, count(p) AS personas, collect(p.name) AS names;

// 13. MERGE: добавить нового персонажа и связи (без дублей при повторе)
MERGE (p:Persona {id: 8})
  ON CREATE SET p.name = 'Ольга Ким', p.age = 26, p.occupation = 'студентка',
                p.experience = 'новичок', p.readiness = 3
WITH p
MATCH (g:Group {name: 'Конечные потребители'}), (f:Persona {name: 'Марина Белова'})
MERGE (p)-[:BELONGS_TO {since: 2026}]->(g)
MERGE (p)-[:KNOWS {since: 2026, context: 'университет', strength: 0.5}]->(f)
RETURN p;

// 14. SET: обновить готовность к покупке после консультации
MATCH (p:Persona {name: 'Виктор Орлов'}) SET p.readiness = 6 RETURN p.name, p.readiness;

// 15. DELETE: удалить добавленного персонажа вместе со связями
MATCH (p:Persona {id: 8}) DETACH DELETE p;
