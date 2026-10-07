-- =====================================================================
-- Лабораторная работа 2. Вариант 13.
-- Часть 3. Загрузка хранилища Data Vault из операционной БД (схема trade, 3NF)
-- Скрипт идемпотентен: повторный запуск не создаёт дублей, а в сателлиты
-- добавляет только записи, у которых изменился hash_diff.
-- =====================================================================
SET search_path TO dv, trade;

-- Функция вычисления хеш-ключа: MD5 от нормализованной строки бизнес-ключа.
-- Составные ключи склеиваются через разделитель '|'.
CREATE OR REPLACE FUNCTION dv.hk(VARIADIC parts TEXT[])
RETURNS CHAR(32) LANGUAGE sql IMMUTABLE AS $$
    SELECT md5(array_to_string(
             ARRAY(SELECT upper(trim(coalesce(p, ''))) FROM unnest(parts) AS p), '|'));
$$;
COMMENT ON FUNCTION dv.hk(TEXT[]) IS 'Хеш-ключ/hash_diff Data Vault: MD5(UPPER(TRIM(k1))|UPPER(TRIM(k2))|...)';

-- ---------------------------------------------------------------------
-- 1. ХАБЫ
-- ---------------------------------------------------------------------
INSERT INTO hub_customer (customer_hk, customer_code, record_source)
SELECT dv.hk(customer_code), customer_code, 'trade.customer' FROM trade.customer
ON CONFLICT (customer_hk) DO NOTHING;

INSERT INTO hub_employee (employee_hk, personnel_no, record_source)
SELECT dv.hk(personnel_no), personnel_no, 'trade.employee' FROM trade.employee
ON CONFLICT (employee_hk) DO NOTHING;

INSERT INTO hub_supplier (supplier_hk, inn, record_source)
SELECT dv.hk(inn), inn, 'trade.supplier' FROM trade.supplier
ON CONFLICT (supplier_hk) DO NOTHING;

INSERT INTO hub_product (product_hk, sku, record_source)
SELECT dv.hk(sku), sku, 'trade.product' FROM trade.product
ON CONFLICT (product_hk) DO NOTHING;

INSERT INTO hub_category (category_hk, category_name, record_source)
SELECT dv.hk(name), name, 'trade.product_category' FROM trade.product_category
ON CONFLICT (category_hk) DO NOTHING;

INSERT INTO hub_order (order_hk, order_no, record_source)
SELECT dv.hk(order_no), order_no, 'trade.sales_order' FROM trade.sales_order
ON CONFLICT (order_hk) DO NOTHING;

INSERT INTO hub_supply (supply_hk, supply_no, record_source)
SELECT dv.hk(supply_no), supply_no, 'trade.supply' FROM trade.supply
ON CONFLICT (supply_hk) DO NOTHING;

INSERT INTO hub_payment (payment_hk, document_no, record_source)
SELECT dv.hk(coalesce(document_no, 'PAY-' || payment_id)),
       coalesce(document_no, 'PAY-' || payment_id), 'trade.payment'
FROM trade.payment
ON CONFLICT (payment_hk) DO NOTHING;

-- ---------------------------------------------------------------------
-- 2. ЛИНКИ
-- ---------------------------------------------------------------------
INSERT INTO link_order (link_order_hk, order_hk, customer_hk, employee_hk, record_source)
SELECT dv.hk(o.order_no, c.customer_code, e.personnel_no),
       dv.hk(o.order_no), dv.hk(c.customer_code), dv.hk(e.personnel_no), 'trade.sales_order'
FROM trade.sales_order o
JOIN trade.customer c ON c.customer_id = o.customer_id
JOIN trade.employee e ON e.employee_id = o.employee_id
ON CONFLICT (link_order_hk) DO NOTHING;

INSERT INTO link_order_product (link_order_product_hk, order_hk, product_hk, record_source)
SELECT DISTINCT dv.hk(o.order_no, p.sku), dv.hk(o.order_no), dv.hk(p.sku), 'trade.order_item'
FROM trade.order_item i
JOIN trade.sales_order o ON o.order_id = i.order_id
JOIN trade.product     p ON p.product_id = i.product_id
ON CONFLICT (link_order_product_hk) DO NOTHING;

INSERT INTO link_payment_order (link_payment_order_hk, payment_hk, order_hk, record_source)
SELECT dv.hk(coalesce(pm.document_no, 'PAY-' || pm.payment_id), o.order_no),
       dv.hk(coalesce(pm.document_no, 'PAY-' || pm.payment_id)), dv.hk(o.order_no), 'trade.payment'
FROM trade.payment pm
JOIN trade.sales_order o ON o.order_id = pm.order_id
ON CONFLICT (link_payment_order_hk) DO NOTHING;

INSERT INTO link_supply (link_supply_hk, supply_hk, supplier_hk, employee_hk, record_source)
SELECT dv.hk(s.supply_no, sp.inn, e.personnel_no),
       dv.hk(s.supply_no), dv.hk(sp.inn), dv.hk(e.personnel_no), 'trade.supply'
FROM trade.supply s
JOIN trade.supplier sp ON sp.supplier_id = s.supplier_id
JOIN trade.employee e  ON e.employee_id  = s.employee_id
ON CONFLICT (link_supply_hk) DO NOTHING;

INSERT INTO link_supply_product (link_supply_product_hk, supply_hk, product_hk, record_source)
SELECT dv.hk(s.supply_no, p.sku), dv.hk(s.supply_no), dv.hk(p.sku), 'trade.supply_item'
FROM trade.supply_item si
JOIN trade.supply  s ON s.supply_id  = si.supply_id
JOIN trade.product p ON p.product_id = si.product_id
ON CONFLICT (link_supply_product_hk) DO NOTHING;

INSERT INTO link_supplier_product (link_supplier_product_hk, supplier_hk, product_hk, record_source)
SELECT dv.hk(sp.inn, p.sku), dv.hk(sp.inn), dv.hk(p.sku), 'trade.supplier_product'
FROM trade.supplier_product x
JOIN trade.supplier sp ON sp.supplier_id = x.supplier_id
JOIN trade.product  p  ON p.product_id   = x.product_id
ON CONFLICT (link_supplier_product_hk) DO NOTHING;

INSERT INTO link_product_category (link_product_category_hk, product_hk, category_hk, record_source)
SELECT dv.hk(p.sku, c.name), dv.hk(p.sku), dv.hk(c.name), 'trade.product'
FROM trade.product p
JOIN trade.product_category c ON c.category_id = p.category_id
ON CONFLICT (link_product_category_hk) DO NOTHING;

INSERT INTO link_category_hierarchy (link_category_hierarchy_hk, category_hk, parent_category_hk, record_source)
SELECT dv.hk(c.name, pc.name), dv.hk(c.name), dv.hk(pc.name), 'trade.product_category'
FROM trade.product_category c
JOIN trade.product_category pc ON pc.category_id = c.parent_category_id
ON CONFLICT (link_category_hierarchy_hk) DO NOTHING;

INSERT INTO link_employee_manager (link_employee_manager_hk, employee_hk, manager_hk, record_source)
SELECT dv.hk(e.personnel_no, m.personnel_no), dv.hk(e.personnel_no), dv.hk(m.personnel_no), 'trade.employee'
FROM trade.employee e
JOIN trade.employee m ON m.employee_id = e.manager_id
ON CONFLICT (link_employee_manager_hk) DO NOTHING;

-- ---------------------------------------------------------------------
-- 3. САТЕЛЛИТЫ
-- Шаблон: вычисляем hash_diff по атрибутам источника и вставляем запись,
-- только если по ключу ещё нет записей или последняя запись отличается.
-- ---------------------------------------------------------------------

-- Клиент
INSERT INTO sat_customer (customer_hk, hash_diff, customer_type, name, inn, phone, email,
                          city, region, address, discount_pct, registered_at, record_source)
SELECT src.* FROM (
    SELECT dv.hk(c.customer_code) AS customer_hk,
           dv.hk(c.customer_type, c.name, c.inn, c.phone, c.email, ct.name, ct.region,
                 c.address, c.discount_pct::text, c.registered_at::text) AS hash_diff,
           c.customer_type, c.name, c.inn, c.phone, c.email, ct.name, ct.region,
           c.address, c.discount_pct, c.registered_at, 'trade.customer'
    FROM trade.customer c LEFT JOIN trade.city ct ON ct.city_id = c.city_id
) src
WHERE src.hash_diff IS DISTINCT FROM (
    SELECT s.hash_diff FROM sat_customer s WHERE s.customer_hk = src.customer_hk
    ORDER BY s.load_date DESC LIMIT 1);

-- Сотрудник
INSERT INTO sat_employee (employee_hk, hash_diff, last_name, first_name, middle_name,
                          position_title, base_salary, phone, email, hire_date, record_source)
SELECT src.* FROM (
    SELECT dv.hk(e.personnel_no),
           dv.hk(e.last_name, e.first_name, e.middle_name, p.title, p.base_salary::text,
                 e.phone, e.email, e.hire_date::text) AS hash_diff,
           e.last_name, e.first_name, e.middle_name, p.title, p.base_salary,
           e.phone, e.email, e.hire_date, 'trade.employee'
    FROM trade.employee e JOIN trade.position p ON p.position_id = e.position_id
) src (employee_hk, hash_diff)
WHERE src.hash_diff IS DISTINCT FROM (
    SELECT s.hash_diff FROM sat_employee s WHERE s.employee_hk = src.employee_hk
    ORDER BY s.load_date DESC LIMIT 1);

-- Поставщик
INSERT INTO sat_supplier (supplier_hk, hash_diff, name, contact_name, phone, email, city, address, record_source)
SELECT src.* FROM (
    SELECT dv.hk(s.inn),
           dv.hk(s.name, s.contact_name, s.phone, s.email, ct.name, s.address),
           s.name, s.contact_name, s.phone, s.email, ct.name, s.address, 'trade.supplier'
    FROM trade.supplier s LEFT JOIN trade.city ct ON ct.city_id = s.city_id
) src (supplier_hk, hash_diff)
WHERE src.hash_diff IS DISTINCT FROM (
    SELECT x.hash_diff FROM sat_supplier x WHERE x.supplier_hk = src.supplier_hk
    ORDER BY x.load_date DESC LIMIT 1);

-- Товар: описательные атрибуты
INSERT INTO sat_product (product_hk, hash_diff, name, unit, is_active, record_source)
SELECT src.* FROM (
    SELECT dv.hk(p.sku), dv.hk(p.name, p.unit, p.is_active::text),
           p.name, p.unit, p.is_active, 'trade.product'
    FROM trade.product p
) src (product_hk, hash_diff)
WHERE src.hash_diff IS DISTINCT FROM (
    SELECT x.hash_diff FROM sat_product x WHERE x.product_hk = src.product_hk
    ORDER BY x.load_date DESC LIMIT 1);

-- Товар: цена и остаток
INSERT INTO sat_product_price (product_hk, hash_diff, price, stock_qty, record_source)
SELECT src.* FROM (
    SELECT dv.hk(p.sku), dv.hk(p.price::text, p.stock_qty::text),
           p.price, p.stock_qty, 'trade.product'
    FROM trade.product p
) src (product_hk, hash_diff)
WHERE src.hash_diff IS DISTINCT FROM (
    SELECT x.hash_diff FROM sat_product_price x WHERE x.product_hk = src.product_hk
    ORDER BY x.load_date DESC LIMIT 1);

-- Категория
INSERT INTO sat_category (category_hk, hash_diff, description, record_source)
SELECT src.* FROM (
    SELECT dv.hk(c.name), dv.hk(c.name), c.name, 'trade.product_category'
    FROM trade.product_category c
) src (category_hk, hash_diff)
WHERE src.hash_diff IS DISTINCT FROM (
    SELECT x.hash_diff FROM sat_category x WHERE x.category_hk = src.category_hk
    ORDER BY x.load_date DESC LIMIT 1);

-- Заказ
INSERT INTO sat_order (order_hk, hash_diff, order_date, status_code, status_name,
                       delivery_date, comment, record_source)
SELECT src.* FROM (
    SELECT dv.hk(o.order_no),
           dv.hk(o.order_date::text, st.code, o.delivery_date::text, o.comment),
           o.order_date, st.code, st.description, o.delivery_date, o.comment, 'trade.sales_order'
    FROM trade.sales_order o JOIN trade.order_status st ON st.status_id = o.status_id
) src (order_hk, hash_diff)
WHERE src.hash_diff IS DISTINCT FROM (
    SELECT x.hash_diff FROM sat_order x WHERE x.order_hk = src.order_hk
    ORDER BY x.load_date DESC LIMIT 1);

-- Позиция заказа
INSERT INTO sat_order_line (link_order_product_hk, hash_diff, line_no, quantity, unit_price,
                            discount_pct, record_source)
SELECT src.* FROM (
    SELECT dv.hk(o.order_no, p.sku),
           dv.hk(i.line_no::text, i.quantity::text, i.unit_price::text, i.discount_pct::text),
           i.line_no, i.quantity, i.unit_price, i.discount_pct, 'trade.order_item'
    FROM trade.order_item i
    JOIN trade.sales_order o ON o.order_id = i.order_id
    JOIN trade.product     p ON p.product_id = i.product_id
) src (link_order_product_hk, hash_diff)
WHERE src.hash_diff IS DISTINCT FROM (
    SELECT x.hash_diff FROM sat_order_line x WHERE x.link_order_product_hk = src.link_order_product_hk
    ORDER BY x.load_date DESC LIMIT 1);

-- Платёж
INSERT INTO sat_payment (payment_hk, hash_diff, amount, paid_at, payment_method, record_source)
SELECT src.* FROM (
    SELECT dv.hk(coalesce(pm.document_no, 'PAY-' || pm.payment_id)),
           dv.hk(pm.amount::text, pm.paid_at::text, m.name),
           pm.amount, pm.paid_at, m.name, 'trade.payment'
    FROM trade.payment pm JOIN trade.payment_method m ON m.method_id = pm.method_id
) src (payment_hk, hash_diff)
WHERE src.hash_diff IS DISTINCT FROM (
    SELECT x.hash_diff FROM sat_payment x WHERE x.payment_hk = src.payment_hk
    ORDER BY x.load_date DESC LIMIT 1);

-- Поставка
INSERT INTO sat_supply (supply_hk, hash_diff, supply_date, record_source)
SELECT src.* FROM (
    SELECT dv.hk(s.supply_no), dv.hk(s.supply_date::text), s.supply_date, 'trade.supply'
    FROM trade.supply s
) src (supply_hk, hash_diff)
WHERE src.hash_diff IS DISTINCT FROM (
    SELECT x.hash_diff FROM sat_supply x WHERE x.supply_hk = src.supply_hk
    ORDER BY x.load_date DESC LIMIT 1);

-- Позиция поставки
INSERT INTO sat_supply_line (link_supply_product_hk, hash_diff, quantity, unit_cost, record_source)
SELECT src.* FROM (
    SELECT dv.hk(s.supply_no, p.sku), dv.hk(si.quantity::text, si.unit_cost::text),
           si.quantity, si.unit_cost, 'trade.supply_item'
    FROM trade.supply_item si
    JOIN trade.supply  s ON s.supply_id  = si.supply_id
    JOIN trade.product p ON p.product_id = si.product_id
) src (link_supply_product_hk, hash_diff)
WHERE src.hash_diff IS DISTINCT FROM (
    SELECT x.hash_diff FROM sat_supply_line x WHERE x.link_supply_product_hk = src.link_supply_product_hk
    ORDER BY x.load_date DESC LIMIT 1);

-- Условия поставщика
INSERT INTO sat_supplier_product (link_supplier_product_hk, hash_diff, purchase_price, lead_time_days, record_source)
SELECT src.* FROM (
    SELECT dv.hk(sp.inn, p.sku), dv.hk(x.purchase_price::text, x.lead_time_days::text),
           x.purchase_price, x.lead_time_days, 'trade.supplier_product'
    FROM trade.supplier_product x
    JOIN trade.supplier sp ON sp.supplier_id = x.supplier_id
    JOIN trade.product  p  ON p.product_id   = x.product_id
) src (link_supplier_product_hk, hash_diff)
WHERE src.hash_diff IS DISTINCT FROM (
    SELECT y.hash_diff FROM sat_supplier_product y WHERE y.link_supplier_product_hk = src.link_supplier_product_hk
    ORDER BY y.load_date DESC LIMIT 1);
