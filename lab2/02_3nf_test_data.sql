-- =====================================================================
-- Лабораторная работа 2. Вариант 13. Тестовые данные для модели 3NF
-- =====================================================================
SET search_path TO trade;

INSERT INTO city (name, region) VALUES
 ('Москва', 'Москва'), ('Химки', 'Московская обл.'), ('Тула', 'Тульская обл.');

INSERT INTO position (title, base_salary) VALUES
 ('Руководитель торгового отдела', 150000),
 ('Менеджер по продажам',           90000),
 ('Менеджер по закупкам',           85000);

INSERT INTO product_category (name, parent_category_id) VALUES
 ('Бытовая техника', NULL), ('Климатическая техника', 1), ('Кухонная техника', 1);

INSERT INTO order_status (code, description) VALUES
 ('new','Новый'), ('confirmed','Подтверждён'), ('shipped','Отгружен'),
 ('closed','Закрыт'), ('cancelled','Отменён');

INSERT INTO payment_method (name) VALUES ('Наличные'), ('Банковская карта'), ('Безналичный расчёт');

INSERT INTO employee (personnel_no, last_name, first_name, middle_name, position_id, manager_id, phone, email, hire_date) VALUES
 ('T-001','Соколова','Ирина','Петровна',  1, NULL, '+7-900-100-00-01','sokolova@trade.ru','2019-03-01'),
 ('T-002','Петров',  'Олег', 'Иванович',  2, 1,    '+7-900-100-00-02','petrov@trade.ru',  '2021-06-15'),
 ('T-003','Ким',     'Анна', 'Сергеевна', 2, 1,    '+7-900-100-00-03','kim@trade.ru',     '2022-02-10'),
 ('T-004','Белов',   'Денис','Андреевич', 3, 1,    '+7-900-100-00-04','belov@trade.ru',   '2020-09-01');

INSERT INTO customer (customer_code, customer_type, name, inn, phone, email, city_id, address, discount_pct) VALUES
 ('C-0001','P','Иванов Сергей Петрович', NULL,          '+7-916-000-11-22','ivanov@mail.ru', 1,'ул. Ленина, 5',     0),
 ('C-0002','C','ООО «Климат-Сервис»',    '7701234567',  '+7-495-111-22-33','info@klimat.ru', 2,'Ленинградское ш., 1',7.5),
 ('C-0003','C','ИП Смирнова А.В.',       '710400112233','+7-487-222-33-44','smirnova@tula.ru',3,'пр. Ленина, 40',     3);

INSERT INTO supplier (inn, name, contact_name, phone, email, city_id, address) VALUES
 ('7702000001','АО «ТехноПоставка»','Орлов В.В.','+7-495-500-00-01','sales@techno.ru',1,'ул. Заводская, 10'),
 ('7102000002','ООО «КухняПро»',     'Гусева Н.А.','+7-487-500-00-02','opt@kuhnya.ru', 3,'ул. Промышленная, 3');

INSERT INTO product (sku, name, category_id, unit, price, stock_qty) VALUES
 ('AC-09','Сплит-система 9000 BTU', 2,'шт', 32990, 12),
 ('AC-12','Сплит-система 12000 BTU',2,'шт', 41990,  8),
 ('MW-20','Микроволновая печь 20 л',3,'шт',  7490, 30),
 ('KT-17','Электрочайник 1,7 л',    3,'шт',  2190, 50);

INSERT INTO supplier_product (supplier_id, product_id, purchase_price, lead_time_days) VALUES
 (1,1,24000,10),(1,2,31000,10),(2,3,5200,5),(2,4,1300,5),(1,3,5400,7);

INSERT INTO supply (supply_no, supplier_id, employee_id, supply_date) VALUES
 ('S-2026-001',1,4,'2026-09-01'), ('S-2026-002',2,4,'2026-09-03');

INSERT INTO supply_item (supply_id, product_id, quantity, unit_cost) VALUES
 (1,1,10,24000),(1,2,8,31000),(2,3,25,5200),(2,4,40,1300);

INSERT INTO sales_order (order_no, customer_id, employee_id, status_id, order_date, delivery_date) VALUES
 ('O-2026-0001',1,2,4,'2026-09-10 11:20','2026-09-12'),
 ('O-2026-0002',2,3,3,'2026-09-15 15:05','2026-09-18'),
 ('O-2026-0003',3,2,2,'2026-09-20 10:00', NULL);

INSERT INTO order_item (order_id, line_no, product_id, quantity, unit_price, discount_pct) VALUES
 (1,1,1,1,32990,0),(1,2,4,1,2190,0),
 (2,1,2,5,41990,7.5),(2,2,1,3,32990,7.5),
 (3,1,3,10,7490,3);

INSERT INTO payment (order_id, method_id, amount, paid_at, document_no) VALUES
 (1,2, 35180.00,'2026-09-10 11:25','CHK-5501'),
 (2,3,150000.00,'2026-09-16 09:00','PP-118'),
 (2,3, 135751.00,'2026-09-19 09:00','PP-131');
