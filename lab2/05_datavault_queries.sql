-- =====================================================================
-- Лабораторная работа 2. Вариант 13.
-- Часть 4. Проверочные запросы к хранилищу Data Vault
-- =====================================================================
SET search_path TO dv;

-- 1. Количество записей во всех объектах хранилища
SELECT 'hub' AS kind, 'hub_customer' AS obj, count(*) FROM hub_customer UNION ALL
SELECT 'hub', 'hub_employee', count(*) FROM hub_employee UNION ALL
SELECT 'hub', 'hub_supplier', count(*) FROM hub_supplier UNION ALL
SELECT 'hub', 'hub_product',  count(*) FROM hub_product  UNION ALL
SELECT 'hub', 'hub_category', count(*) FROM hub_category UNION ALL
SELECT 'hub', 'hub_order',    count(*) FROM hub_order    UNION ALL
SELECT 'hub', 'hub_supply',   count(*) FROM hub_supply   UNION ALL
SELECT 'hub', 'hub_payment',  count(*) FROM hub_payment  UNION ALL
SELECT 'link','link_order',            count(*) FROM link_order            UNION ALL
SELECT 'link','link_order_product',    count(*) FROM link_order_product    UNION ALL
SELECT 'link','link_payment_order',    count(*) FROM link_payment_order    UNION ALL
SELECT 'link','link_supply',           count(*) FROM link_supply           UNION ALL
SELECT 'link','link_supply_product',   count(*) FROM link_supply_product   UNION ALL
SELECT 'link','link_supplier_product', count(*) FROM link_supplier_product UNION ALL
SELECT 'link','link_product_category', count(*) FROM link_product_category UNION ALL
SELECT 'link','link_category_hierarchy',count(*) FROM link_category_hierarchy UNION ALL
SELECT 'link','link_employee_manager', count(*) FROM link_employee_manager UNION ALL
SELECT 'sat', 'sat_product_price',     count(*) FROM sat_product_price     UNION ALL
SELECT 'sat', 'sat_order',             count(*) FROM sat_order;

-- 2. Продажи по менеджерам (текущее состояние сателлитов)
SELECT se.last_name || ' ' || se.first_name AS manager,
       count(DISTINCT lo.order_hk)          AS orders,
       round(sum(sl.quantity * sl.unit_price * (1 - sl.discount_pct/100)), 2) AS revenue
FROM link_order lo
JOIN link_order_product lop ON lop.order_hk = lo.order_hk
JOIN LATERAL (SELECT * FROM sat_order_line x WHERE x.link_order_product_hk = lop.link_order_product_hk
              ORDER BY x.load_date DESC LIMIT 1) sl ON TRUE
JOIN LATERAL (SELECT * FROM sat_employee x WHERE x.employee_hk = lo.employee_hk
              ORDER BY x.load_date DESC LIMIT 1) se ON TRUE
GROUP BY manager
ORDER BY revenue DESC;

-- 3. История цены товара (демонстрация историчности сателлита)
SELECT hp.sku, sp.price, sp.stock_qty, sp.load_date
FROM hub_product hp
JOIN sat_product_price sp ON sp.product_hk = hp.product_hk
WHERE hp.sku = 'AC-09'
ORDER BY sp.load_date;

-- 4. История статусов заказа
SELECT ho.order_no, so.status_code, so.load_date
FROM hub_order ho JOIN sat_order so ON so.order_hk = ho.order_hk
WHERE ho.order_no = 'O-2026-0003'
ORDER BY so.load_date;
