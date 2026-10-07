// =====================================================================
// Лабораторная работа 1 (Neo4j). «Хранилища данных»
// Социальный граф персонажей целевой аудитории
// Вариант 13: торговый отдел (продажа климатической и бытовой техники)
// Автор: Тимонин А.
// ---------------------------------------------------------------------
// Граф построен по алгоритму описания персонажей из презентации:
//  1) первичный анализ — кто пользователи и что они делают с системой;
//  2) формирование групп пользователей по уникальному признаку
//     (как в примере презентации: конечные потребители, региональные
//     партнёры-дилеры, профессионалы отрасли);
//  3) описание 7 персонажей: имя, краткая биография, опыт использования
//     продукта, готовность купить, цели и специфические атрибуты.
// Итого: 24 узла, 63 ребра.
// =====================================================================

// Очистка базы (для повторного запуска)
MATCH (n) DETACH DELETE n;

// Ограничения уникальности (Neo4j 5.x)
CREATE CONSTRAINT persona_id  IF NOT EXISTS FOR (p:Persona)  REQUIRE p.id   IS UNIQUE;
CREATE CONSTRAINT group_name  IF NOT EXISTS FOR (g:Group)    REQUIRE g.name IS UNIQUE;
CREATE CONSTRAINT goal_name   IF NOT EXISTS FOR (g:Goal)     REQUIRE g.name IS UNIQUE;
CREATE CONSTRAINT product_sku IF NOT EXISTS FOR (p:Product)  REQUIRE p.sku  IS UNIQUE;
CREATE CONSTRAINT employee_no IF NOT EXISTS FOR (e:Employee) REQUIRE e.personnelNo IS UNIQUE;
CREATE CONSTRAINT city_name   IF NOT EXISTS FOR (c:City)     REQUIRE c.name IS UNIQUE;

// ---------------------------------------------------------------------
// Создание узлов и рёбер одним запросом
// ---------------------------------------------------------------------
CREATE
// ---------- Группы пользователей (3) ----------
  (g1:Group {name: 'Конечные потребители', criterion: 'Покупка для личного использования',
             description: 'Частные лица, покупающие технику для квартиры или дома', share: 0.55}),
  (g2:Group {name: 'Партнёры-дилеры', criterion: 'Перепродажа в регионе',
             description: 'Региональные магазины и ИП, закупающие оптом', share: 0.25}),
  (g3:Group {name: 'Профессионалы отрасли', criterion: 'Профессиональный опыт',
             description: 'Монтажники, проектировщики, инженеры по климату', share: 0.20}),

// ---------- Цели (5): маркетинговые и интерактивные ----------
  (gl1:Goal {name: 'Комфортный микроклимат дома', type: 'маркетинговая'}),
  (gl2:Goal {name: 'Выгодная оптовая закупка',    type: 'маркетинговая'}),
  (gl3:Goal {name: 'Быстрое сравнение моделей',   type: 'интерактивная'}),
  (gl4:Goal {name: 'Технические характеристики и документация', type: 'интерактивная'}),
  (gl5:Goal {name: 'Повышение статуса и имиджа',  type: 'маркетинговая'}),

// ---------- Города (3) ----------
  (c1:City {name: 'Москва', region: 'Москва'}),
  (c2:City {name: 'Химки',  region: 'Московская обл.'}),
  (c3:City {name: 'Тула',   region: 'Тульская обл.'}),

// ---------- Товары торгового отдела (4) ----------
  (pr1:Product {sku: 'AC-09', name: 'Сплит-система 9000 BTU',  category: 'Климатическая техника', price: 32990}),
  (pr2:Product {sku: 'AC-12', name: 'Сплит-система 12000 BTU', category: 'Климатическая техника', price: 41990}),
  (pr3:Product {sku: 'MW-20', name: 'Микроволновая печь 20 л', category: 'Кухонная техника',      price: 7490}),
  (pr4:Product {sku: 'KT-17', name: 'Электрочайник 1,7 л',     category: 'Кухонная техника',      price: 2190}),

// ---------- Сотрудники торгового отдела (2) ----------
  (e1:Employee {personnelNo: 'T-002', name: 'Олег Петров', position: 'Менеджер по продажам (розница)'}),
  (e2:Employee {personnelNo: 'T-003', name: 'Анна Ким',    position: 'Менеджер по продажам (опт)'}),

// ---------- Персонажи (7) ----------
  (p1:Persona {id: 1, name: 'Сергей Иванов', age: 38, gender: 'м', occupation: 'IT-инженер',
               income: 'выше среднего', experience: 'опытный пользователь', readiness: 8,
               channel: 'сайт', bio: 'Живёт с семьёй в новой квартире, сам выбирает технику, читает обзоры'}),
  (p2:Persona {id: 2, name: 'Марина Белова', age: 29, gender: 'ж', occupation: 'маркетолог',
               income: 'средний', experience: 'новичок', readiness: 6,
               channel: 'соцсети', bio: 'Снимает квартиру, плохо переносит жару, ищет недорогое решение'}),
  (p3:Persona {id: 3, name: 'Виктор Орлов', age: 61, gender: 'м', occupation: 'пенсионер',
               income: 'ниже среднего', experience: 'новичок', readiness: 4,
               channel: 'телефон', bio: 'Покупает технику для дачи, советуется с сыном, ценит личное общение'}),
  (p4:Persona {id: 4, name: 'Алла Смирнова', age: 44, gender: 'ж', occupation: 'ИП, владелец магазина',
               income: 'высокий', experience: 'эксперт', readiness: 9,
               channel: 'менеджер', bio: 'Держит магазин техники в Туле, закупает партии каждый месяц'}),
  (p5:Persona {id: 5, name: 'Игорь Кузнецов', age: 35, gender: 'м', occupation: 'директор ООО «Климат-Сервис»',
               income: 'высокий', experience: 'эксперт', readiness: 9,
               channel: 'менеджер', bio: 'Дилер и монтажная организация, нужны скидки и стабильные поставки'}),
  (p6:Persona {id: 6, name: 'Дмитрий Волков', age: 32, gender: 'м', occupation: 'монтажник кондиционеров',
               income: 'средний', experience: 'эксперт', readiness: 7,
               channel: 'мессенджер', bio: 'Подбирает оборудование клиентам, важны характеристики и наличие'}),
  (p7:Persona {id: 7, name: 'Елена Соколова', age: 41, gender: 'ж', occupation: 'инженер-проектировщик ОВиК',
               income: 'выше среднего', experience: 'эксперт', readiness: 5,
               channel: 'сайт', bio: 'Закладывает оборудование в проекты офисов, нужна документация'}),

// ===================== РЁБРА =====================
// BELONGS_TO — персонаж входит в группу (7)
  (p1)-[:BELONGS_TO {since: 2022}]->(g1),
  (p2)-[:BELONGS_TO {since: 2025}]->(g1),
  (p3)-[:BELONGS_TO {since: 2024}]->(g1),
  (p4)-[:BELONGS_TO {since: 2020}]->(g2),
  (p5)-[:BELONGS_TO {since: 2019}]->(g2),
  (p6)-[:BELONGS_TO {since: 2021}]->(g3),
  (p7)-[:BELONGS_TO {since: 2018}]->(g3),

// LIVES_IN — место жительства / работы (7)
  (p1)-[:LIVES_IN]->(c1),
  (p2)-[:LIVES_IN]->(c1),
  (p3)-[:LIVES_IN]->(c3),
  (p4)-[:LIVES_IN]->(c3),
  (p5)-[:LIVES_IN]->(c2),
  (p6)-[:LIVES_IN]->(c2),
  (p7)-[:LIVES_IN]->(c1),

// KNOWS — социальные связи между персонажами (10)
  (p1)-[:KNOWS {since: 2015, context: 'коллеги', strength: 0.8}]->(p2),
  (p1)-[:KNOWS {since: 2021, context: 'соседи',  strength: 0.5}]->(p6),
  (p2)-[:KNOWS {since: 2023, context: 'соцсети', strength: 0.3}]->(p7),
  (p3)-[:KNOWS {since: 2010, context: 'соседи по даче', strength: 0.6}]->(p4),
  (p4)-[:KNOWS {since: 2019, context: 'деловые партнёры', strength: 0.9}]->(p5),
  (p5)-[:KNOWS {since: 2020, context: 'работодатель', strength: 0.9}]->(p6),
  (p6)-[:KNOWS {since: 2022, context: 'совместные проекты', strength: 0.7}]->(p7),
  (p7)-[:KNOWS {since: 2017, context: 'выставка', strength: 0.6}]->(p5),
  (p3)-[:KNOWS {since: 2024, context: 'монтаж на даче', strength: 0.4}]->(p6),
  (p2)-[:KNOWS {since: 2020, context: 'друзья',  strength: 0.7}]->(p1),

// HAS_GOAL — первичные цели персонажа (11)
  (p1)-[:HAS_GOAL {priority: 1}]->(gl1),
  (p1)-[:HAS_GOAL {priority: 2}]->(gl3),
  (p2)-[:HAS_GOAL {priority: 1}]->(gl1),
  (p2)-[:HAS_GOAL {priority: 2}]->(gl5),
  (p3)-[:HAS_GOAL {priority: 1}]->(gl1),
  (p4)-[:HAS_GOAL {priority: 1}]->(gl2),
  (p5)-[:HAS_GOAL {priority: 1}]->(gl2),
  (p5)-[:HAS_GOAL {priority: 2}]->(gl5),
  (p6)-[:HAS_GOAL {priority: 1}]->(gl4),
  (p6)-[:HAS_GOAL {priority: 2}]->(gl3),
  (p7)-[:HAS_GOAL {priority: 1}]->(gl4),

// PURSUES — типичные цели группы (5)
  (g1)-[:PURSUES]->(gl1),
  (g1)-[:PURSUES]->(gl3),
  (g2)-[:PURSUES]->(gl2),
  (g3)-[:PURSUES]->(gl4),
  (g2)-[:PURSUES]->(gl5),

// INTERESTED_IN — интерес к товару (7)
  (p1)-[:INTERESTED_IN {level: 'высокий'}]->(pr2),
  (p2)-[:INTERESTED_IN {level: 'высокий'}]->(pr1),
  (p3)-[:INTERESTED_IN {level: 'средний'}]->(pr3),
  (p4)-[:INTERESTED_IN {level: 'высокий'}]->(pr4),
  (p6)-[:INTERESTED_IN {level: 'высокий'}]->(pr2),
  (p7)-[:INTERESTED_IN {level: 'средний'}]->(pr1),
  (p7)-[:INTERESTED_IN {level: 'средний'}]->(pr2),

// BOUGHT — совершённые покупки (5)
  (p1)-[:BOUGHT {date: date('2026-09-10'), qty: 1,  amount: 32990}]->(pr1),
  (p1)-[:BOUGHT {date: date('2026-09-10'), qty: 1,  amount: 2190}]->(pr4),
  (p5)-[:BOUGHT {date: date('2026-09-15'), qty: 5,  amount: 194204}]->(pr2),
  (p5)-[:BOUGHT {date: date('2026-09-15'), qty: 3,  amount: 91547}]->(pr1),
  (p4)-[:BOUGHT {date: date('2026-09-20'), qty: 10, amount: 72653}]->(pr3),

// RECOMMENDED — персонаж порекомендовал магазин/товар другому (4)
  (p6)-[:RECOMMENDED {product: 'AC-12', rating: 5}]->(p1),
  (p1)-[:RECOMMENDED {product: 'AC-09', rating: 5}]->(p2),
  (p5)-[:RECOMMENDED {product: 'AC-12', rating: 4}]->(p4),
  (p4)-[:RECOMMENDED {product: 'MW-20', rating: 4}]->(p3),

// SERVES — менеджер ведёт клиента (7)
  (e1)-[:SERVES {since: 2022}]->(p1),
  (e1)-[:SERVES {since: 2025}]->(p2),
  (e1)-[:SERVES {since: 2024}]->(p3),
  (e2)-[:SERVES {since: 2020}]->(p4),
  (e2)-[:SERVES {since: 2019}]->(p5),
  (e2)-[:SERVES {since: 2021}]->(p6),
  (e1)-[:SERVES {since: 2023}]->(p7);

// Проверка: количество узлов и рёбер
MATCH (n) RETURN count(n) AS nodes;
MATCH ()-[r]->() RETURN count(r) AS relationships;
