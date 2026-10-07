-- =====================================================================
-- Лабораторная работа 2. «Хранилища данных»
-- Вариант 13: «Система должна описывать процесс работы торгового отдела»
-- Часть 1. Структура БД в третьей нормальной форме (3NF), PostgreSQL 16
-- Автор: Тимонин А.
-- =====================================================================
-- Предметная область.
-- Торговый отдел закупает товары у поставщиков (поставки), хранит их
-- в каталоге с текущими ценами, принимает заказы от клиентов, которые
-- оформляют менеджеры отдела, и учитывает оплату заказов.
--
-- Соблюдение 3NF:
--  * 1NF — все атрибуты атомарны, у каждой таблицы есть первичный ключ;
--  * 2NF — в таблицах с составным смыслом (строки заказа и поставки)
--          неключевые атрибуты зависят от ключа строки целиком;
--  * 3NF — нет транзитивных зависимостей: справочные данные (должности,
--          категории, статусы, способы оплаты, города) вынесены в
--          отдельные таблицы, в фактах хранятся только ссылки на них.
-- =====================================================================

DROP SCHEMA IF EXISTS trade CASCADE;
CREATE SCHEMA trade;
SET search_path TO trade;

-- ---------------------------------------------------------------------
-- Справочники
-- ---------------------------------------------------------------------

-- Города (адреса клиентов и поставщиков)
CREATE TABLE city (
    city_id     SERIAL       PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    region      VARCHAR(100),
    CONSTRAINT uq_city UNIQUE (name, region)
);
COMMENT ON TABLE city IS 'Справочник городов';

-- Должности сотрудников торгового отдела
CREATE TABLE position (
    position_id SERIAL       PRIMARY KEY,
    title       VARCHAR(100) NOT NULL UNIQUE,
    base_salary NUMERIC(12,2) NOT NULL CHECK (base_salary >= 0)
);
COMMENT ON TABLE position IS 'Должности (руководитель отдела, менеджер по продажам, менеджер по закупкам и т.д.)';

-- Категории товаров (иерархия: подкатегория ссылается на родителя)
CREATE TABLE product_category (
    category_id        SERIAL       PRIMARY KEY,
    name               VARCHAR(100) NOT NULL UNIQUE,
    parent_category_id INT REFERENCES product_category(category_id)
);
COMMENT ON TABLE product_category IS 'Категории товаров с поддержкой иерархии';

-- Статусы заказа
CREATE TABLE order_status (
    status_id   SMALLSERIAL  PRIMARY KEY,
    code        VARCHAR(20)  NOT NULL UNIQUE,   -- new, confirmed, shipped, closed, cancelled
    description VARCHAR(100) NOT NULL
);
COMMENT ON TABLE order_status IS 'Статусы жизненного цикла заказа клиента';

-- Способы оплаты
CREATE TABLE payment_method (
    method_id   SMALLSERIAL  PRIMARY KEY,
    name        VARCHAR(50)  NOT NULL UNIQUE    -- наличные, карта, безналичный расчёт
);
COMMENT ON TABLE payment_method IS 'Способы оплаты заказа';

-- ---------------------------------------------------------------------
-- Основные сущности
-- ---------------------------------------------------------------------

-- Сотрудники торгового отдела
CREATE TABLE employee (
    employee_id   SERIAL       PRIMARY KEY,
    personnel_no  VARCHAR(20)  NOT NULL UNIQUE,   -- табельный номер (бизнес-ключ)
    last_name     VARCHAR(50)  NOT NULL,
    first_name    VARCHAR(50)  NOT NULL,
    middle_name   VARCHAR(50),
    position_id   INT          NOT NULL REFERENCES position(position_id),
    manager_id    INT          REFERENCES employee(employee_id),  -- непосредственный руководитель
    phone         VARCHAR(20),
    email         VARCHAR(100) UNIQUE,
    hire_date     DATE         NOT NULL DEFAULT CURRENT_DATE
);
COMMENT ON TABLE employee IS 'Сотрудники торгового отдела';

-- Клиенты (физические и юридические лица)
CREATE TABLE customer (
    customer_id   SERIAL       PRIMARY KEY,
    customer_code VARCHAR(20)  NOT NULL UNIQUE,   -- код клиента (бизнес-ключ)
    customer_type CHAR(1)      NOT NULL CHECK (customer_type IN ('P','C')), -- P — физлицо, C — компания
    name          VARCHAR(200) NOT NULL,
    inn           VARCHAR(12)  UNIQUE,
    phone         VARCHAR(20),
    email         VARCHAR(100),
    city_id       INT          REFERENCES city(city_id),
    address       VARCHAR(200),
    discount_pct  NUMERIC(4,2) NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 50),
    registered_at DATE         NOT NULL DEFAULT CURRENT_DATE
);
COMMENT ON TABLE customer IS 'Клиенты торгового отдела';

-- Поставщики
CREATE TABLE supplier (
    supplier_id   SERIAL       PRIMARY KEY,
    inn           VARCHAR(12)  NOT NULL UNIQUE,   -- ИНН (бизнес-ключ)
    name          VARCHAR(200) NOT NULL,
    contact_name  VARCHAR(100),
    phone         VARCHAR(20),
    email         VARCHAR(100),
    city_id       INT          REFERENCES city(city_id),
    address       VARCHAR(200)
);
COMMENT ON TABLE supplier IS 'Поставщики товаров';

-- Товары
CREATE TABLE product (
    product_id    SERIAL        PRIMARY KEY,
    sku           VARCHAR(30)   NOT NULL UNIQUE,  -- артикул (бизнес-ключ)
    name          VARCHAR(200)  NOT NULL,
    category_id   INT           NOT NULL REFERENCES product_category(category_id),
    unit          VARCHAR(10)   NOT NULL DEFAULT 'шт',
    price         NUMERIC(12,2) NOT NULL CHECK (price >= 0),   -- текущая цена продажи
    stock_qty     INT           NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    is_active     BOOLEAN       NOT NULL DEFAULT TRUE
);
COMMENT ON TABLE product IS 'Каталог товаров торгового отдела';

-- Какие поставщики могут поставлять какой товар (M:N) и по какой цене
CREATE TABLE supplier_product (
    supplier_id    INT           NOT NULL REFERENCES supplier(supplier_id),
    product_id     INT           NOT NULL REFERENCES product(product_id),
    purchase_price NUMERIC(12,2) NOT NULL CHECK (purchase_price >= 0),
    lead_time_days SMALLINT      NOT NULL DEFAULT 7,
    PRIMARY KEY (supplier_id, product_id)
);
COMMENT ON TABLE supplier_product IS 'Ассортимент поставщиков и закупочные цены';

-- ---------------------------------------------------------------------
-- Бизнес-процессы: продажи
-- ---------------------------------------------------------------------

-- Заказ клиента (шапка)
CREATE TABLE sales_order (
    order_id      SERIAL      PRIMARY KEY,
    order_no      VARCHAR(20) NOT NULL UNIQUE,    -- номер заказа (бизнес-ключ)
    customer_id   INT         NOT NULL REFERENCES customer(customer_id),
    employee_id   INT         NOT NULL REFERENCES employee(employee_id), -- менеджер, оформивший заказ
    status_id     SMALLINT    NOT NULL REFERENCES order_status(status_id),
    order_date    TIMESTAMP   NOT NULL DEFAULT NOW(),
    delivery_date DATE,
    comment       TEXT
);
COMMENT ON TABLE sales_order IS 'Заказы клиентов';

-- Строки заказа
CREATE TABLE order_item (
    order_id      INT           NOT NULL REFERENCES sales_order(order_id) ON DELETE CASCADE,
    line_no       SMALLINT      NOT NULL,
    product_id    INT           NOT NULL REFERENCES product(product_id),
    quantity      INT           NOT NULL CHECK (quantity > 0),
    unit_price    NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),  -- цена на момент продажи
    discount_pct  NUMERIC(4,2)  NOT NULL DEFAULT 0,
    PRIMARY KEY (order_id, line_no)
);
COMMENT ON TABLE order_item IS 'Позиции заказа; цена фиксируется на момент продажи, поэтому не является транзитивной зависимостью';

-- Оплаты по заказу (заказ может оплачиваться частями)
CREATE TABLE payment (
    payment_id    SERIAL        PRIMARY KEY,
    order_id      INT           NOT NULL REFERENCES sales_order(order_id),
    method_id     SMALLINT      NOT NULL REFERENCES payment_method(method_id),
    amount        NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    paid_at       TIMESTAMP     NOT NULL DEFAULT NOW(),
    document_no   VARCHAR(30)
);
COMMENT ON TABLE payment IS 'Платежи клиентов по заказам';

-- ---------------------------------------------------------------------
-- Бизнес-процессы: закупки
-- ---------------------------------------------------------------------

-- Поставка от поставщика (шапка)
CREATE TABLE supply (
    supply_id     SERIAL      PRIMARY KEY,
    supply_no     VARCHAR(20) NOT NULL UNIQUE,    -- номер накладной (бизнес-ключ)
    supplier_id   INT         NOT NULL REFERENCES supplier(supplier_id),
    employee_id   INT         NOT NULL REFERENCES employee(employee_id), -- принял поставку
    supply_date   DATE        NOT NULL DEFAULT CURRENT_DATE
);
COMMENT ON TABLE supply IS 'Поставки товаров от поставщиков';

-- Строки поставки
CREATE TABLE supply_item (
    supply_id     INT           NOT NULL REFERENCES supply(supply_id) ON DELETE CASCADE,
    product_id    INT           NOT NULL REFERENCES product(product_id),
    quantity      INT           NOT NULL CHECK (quantity > 0),
    unit_cost     NUMERIC(12,2) NOT NULL CHECK (unit_cost >= 0),
    PRIMARY KEY (supply_id, product_id)
);
COMMENT ON TABLE supply_item IS 'Позиции поставки';

-- ---------------------------------------------------------------------
-- Индексы по внешним ключам (ускоряют соединения и отчёты)
-- ---------------------------------------------------------------------
CREATE INDEX ix_employee_position   ON employee(position_id);
CREATE INDEX ix_customer_city       ON customer(city_id);
CREATE INDEX ix_product_category    ON product(category_id);
CREATE INDEX ix_order_customer      ON sales_order(customer_id);
CREATE INDEX ix_order_employee      ON sales_order(employee_id);
CREATE INDEX ix_order_date          ON sales_order(order_date);
CREATE INDEX ix_order_item_product  ON order_item(product_id);
CREATE INDEX ix_payment_order       ON payment(order_id);
CREATE INDEX ix_supply_supplier     ON supply(supplier_id);
CREATE INDEX ix_supply_item_product ON supply_item(product_id);

-- ---------------------------------------------------------------------
-- Представление: сумма заказа и остаток к оплате (вычисляемые данные
-- не хранятся в таблицах, чтобы не нарушать 3NF)
-- ---------------------------------------------------------------------
CREATE VIEW v_order_total AS
SELECT o.order_id,
       o.order_no,
       c.name                                                    AS customer,
       e.last_name || ' ' || e.first_name                        AS manager,
       s.code                                                    AS status,
       ROUND(SUM(i.quantity * i.unit_price * (1 - i.discount_pct/100)), 2) AS total,
       COALESCE((SELECT SUM(p.amount) FROM payment p WHERE p.order_id = o.order_id), 0) AS paid
FROM sales_order o
JOIN customer     c ON c.customer_id = o.customer_id
JOIN employee     e ON e.employee_id = o.employee_id
JOIN order_status s ON s.status_id   = o.status_id
JOIN order_item   i ON i.order_id    = o.order_id
GROUP BY o.order_id, o.order_no, c.name, e.last_name, e.first_name, s.code;
