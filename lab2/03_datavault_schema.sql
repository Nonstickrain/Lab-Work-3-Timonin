-- =====================================================================
-- Лабораторная работа 2. «Хранилища данных»
-- Вариант 13: «Система должна описывать процесс работы торгового отдела»
-- Часть 2. Структура хранилища по методологии Data Vault 2.0, PostgreSQL 16
-- Автор: Тимонин А.
-- =====================================================================
-- Правила, по которым построена модель:
--  * HUB (хаб)        — уникальный список бизнес-ключей одной сущности.
--                       Поля: хеш-ключ (*_hk), бизнес-ключ, load_date,
--                       record_source. Хабы никогда не изменяются.
--  * LINK (связь)     — уникальный список связей между хабами
--                       (бизнес-событие или отношение). Поля: хеш-ключ
--                       связи, хеш-ключи хабов, load_date, record_source.
--                       Связь всегда «многие-ко-многим», что позволяет
--                       без перестройки модели менять кардинальность.
--  * SATELLITE (сателлит) — описательные атрибуты хаба или связи с
--                       историей изменений. PK = (хеш-ключ родителя,
--                       load_date); hash_diff — хеш всех атрибутов, по
--                       нему определяется, изменилась ли запись.
--  * Хеш-ключ = MD5 от бизнес-ключа (CHAR(32)): ключи вычисляются
--    независимо в любом источнике, загрузка хабов/связей/сателлитов
--    может идти параллельно.
--  * Справочники 3NF-модели (город, должность, статус, способ оплаты)
--    не выделяются в хабы — у них нет самостоятельного бизнес-смысла,
--    их значения хранятся как атрибуты в сателлитах.
-- =====================================================================

DROP SCHEMA IF EXISTS dv CASCADE;
CREATE SCHEMA dv;
SET search_path TO dv;

-- =====================================================================
-- ХАБЫ
-- =====================================================================

-- Клиент. Бизнес-ключ — код клиента
CREATE TABLE hub_customer (
    customer_hk    CHAR(32)     PRIMARY KEY,           -- MD5(customer_code)
    customer_code  VARCHAR(20)  NOT NULL UNIQUE,
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL
);
COMMENT ON TABLE hub_customer IS 'Хаб «Клиент»';

-- Сотрудник торгового отдела. Бизнес-ключ — табельный номер
CREATE TABLE hub_employee (
    employee_hk    CHAR(32)     PRIMARY KEY,           -- MD5(personnel_no)
    personnel_no   VARCHAR(20)  NOT NULL UNIQUE,
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL
);
COMMENT ON TABLE hub_employee IS 'Хаб «Сотрудник»';

-- Поставщик. Бизнес-ключ — ИНН
CREATE TABLE hub_supplier (
    supplier_hk    CHAR(32)     PRIMARY KEY,           -- MD5(inn)
    inn            VARCHAR(12)  NOT NULL UNIQUE,
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL
);
COMMENT ON TABLE hub_supplier IS 'Хаб «Поставщик»';

-- Товар. Бизнес-ключ — артикул
CREATE TABLE hub_product (
    product_hk     CHAR(32)     PRIMARY KEY,           -- MD5(sku)
    sku            VARCHAR(30)  NOT NULL UNIQUE,
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL
);
COMMENT ON TABLE hub_product IS 'Хаб «Товар»';

-- Категория товара. Бизнес-ключ — наименование категории
CREATE TABLE hub_category (
    category_hk    CHAR(32)     PRIMARY KEY,           -- MD5(category_name)
    category_name  VARCHAR(100) NOT NULL UNIQUE,
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL
);
COMMENT ON TABLE hub_category IS 'Хаб «Категория товара»';

-- Заказ клиента. Бизнес-ключ — номер заказа
CREATE TABLE hub_order (
    order_hk       CHAR(32)     PRIMARY KEY,           -- MD5(order_no)
    order_no       VARCHAR(20)  NOT NULL UNIQUE,
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL
);
COMMENT ON TABLE hub_order IS 'Хаб «Заказ клиента»';

-- Поставка. Бизнес-ключ — номер накладной
CREATE TABLE hub_supply (
    supply_hk      CHAR(32)     PRIMARY KEY,           -- MD5(supply_no)
    supply_no      VARCHAR(20)  NOT NULL UNIQUE,
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL
);
COMMENT ON TABLE hub_supply IS 'Хаб «Поставка»';

-- Платёж. Бизнес-ключ — номер платёжного документа
CREATE TABLE hub_payment (
    payment_hk     CHAR(32)     PRIMARY KEY,           -- MD5(document_no)
    document_no    VARCHAR(30)  NOT NULL UNIQUE,
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL
);
COMMENT ON TABLE hub_payment IS 'Хаб «Платёж»';

-- =====================================================================
-- ЛИНКИ (СВЯЗИ)
-- =====================================================================

-- Оформление заказа: заказ — клиент — менеджер
CREATE TABLE link_order (
    link_order_hk  CHAR(32)     PRIMARY KEY,           -- MD5(order_no|customer_code|personnel_no)
    order_hk       CHAR(32)     NOT NULL REFERENCES hub_order(order_hk),
    customer_hk    CHAR(32)     NOT NULL REFERENCES hub_customer(customer_hk),
    employee_hk    CHAR(32)     NOT NULL REFERENCES hub_employee(employee_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL,
    CONSTRAINT uq_link_order UNIQUE (order_hk, customer_hk, employee_hk)
);
COMMENT ON TABLE link_order IS 'Связь «Оформление заказа»: заказ, клиент, менеджер';

-- Позиция заказа: заказ — товар
CREATE TABLE link_order_product (
    link_order_product_hk CHAR(32) PRIMARY KEY,        -- MD5(order_no|sku)
    order_hk       CHAR(32)     NOT NULL REFERENCES hub_order(order_hk),
    product_hk     CHAR(32)     NOT NULL REFERENCES hub_product(product_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL,
    CONSTRAINT uq_link_order_product UNIQUE (order_hk, product_hk)
);
COMMENT ON TABLE link_order_product IS 'Связь «Позиция заказа»';

-- Оплата заказа: платёж — заказ
CREATE TABLE link_payment_order (
    link_payment_order_hk CHAR(32) PRIMARY KEY,        -- MD5(document_no|order_no)
    payment_hk     CHAR(32)     NOT NULL REFERENCES hub_payment(payment_hk),
    order_hk       CHAR(32)     NOT NULL REFERENCES hub_order(order_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL,
    CONSTRAINT uq_link_payment_order UNIQUE (payment_hk, order_hk)
);
COMMENT ON TABLE link_payment_order IS 'Связь «Оплата заказа»';

-- Приёмка поставки: поставка — поставщик — сотрудник
CREATE TABLE link_supply (
    link_supply_hk CHAR(32)     PRIMARY KEY,           -- MD5(supply_no|inn|personnel_no)
    supply_hk      CHAR(32)     NOT NULL REFERENCES hub_supply(supply_hk),
    supplier_hk    CHAR(32)     NOT NULL REFERENCES hub_supplier(supplier_hk),
    employee_hk    CHAR(32)     NOT NULL REFERENCES hub_employee(employee_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL,
    CONSTRAINT uq_link_supply UNIQUE (supply_hk, supplier_hk, employee_hk)
);
COMMENT ON TABLE link_supply IS 'Связь «Приёмка поставки»: поставка, поставщик, сотрудник';

-- Позиция поставки: поставка — товар
CREATE TABLE link_supply_product (
    link_supply_product_hk CHAR(32) PRIMARY KEY,       -- MD5(supply_no|sku)
    supply_hk      CHAR(32)     NOT NULL REFERENCES hub_supply(supply_hk),
    product_hk     CHAR(32)     NOT NULL REFERENCES hub_product(product_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL,
    CONSTRAINT uq_link_supply_product UNIQUE (supply_hk, product_hk)
);
COMMENT ON TABLE link_supply_product IS 'Связь «Позиция поставки»';

-- Ассортимент поставщика: поставщик — товар
CREATE TABLE link_supplier_product (
    link_supplier_product_hk CHAR(32) PRIMARY KEY,     -- MD5(inn|sku)
    supplier_hk    CHAR(32)     NOT NULL REFERENCES hub_supplier(supplier_hk),
    product_hk     CHAR(32)     NOT NULL REFERENCES hub_product(product_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL,
    CONSTRAINT uq_link_supplier_product UNIQUE (supplier_hk, product_hk)
);
COMMENT ON TABLE link_supplier_product IS 'Связь «Поставщик поставляет товар»';

-- Товар относится к категории
CREATE TABLE link_product_category (
    link_product_category_hk CHAR(32) PRIMARY KEY,     -- MD5(sku|category_name)
    product_hk     CHAR(32)     NOT NULL REFERENCES hub_product(product_hk),
    category_hk    CHAR(32)     NOT NULL REFERENCES hub_category(category_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL,
    CONSTRAINT uq_link_product_category UNIQUE (product_hk, category_hk)
);
COMMENT ON TABLE link_product_category IS 'Связь «Товар — категория»';

-- Иерархия категорий (иерархический линк): подкатегория — родитель
CREATE TABLE link_category_hierarchy (
    link_category_hierarchy_hk CHAR(32) PRIMARY KEY,   -- MD5(child|parent)
    category_hk        CHAR(32) NOT NULL REFERENCES hub_category(category_hk),
    parent_category_hk CHAR(32) NOT NULL REFERENCES hub_category(category_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL,
    CONSTRAINT uq_link_category_hierarchy UNIQUE (category_hk, parent_category_hk)
);
COMMENT ON TABLE link_category_hierarchy IS 'Иерархический линк категорий';

-- Подчинённость сотрудников (иерархический линк)
CREATE TABLE link_employee_manager (
    link_employee_manager_hk CHAR(32) PRIMARY KEY,     -- MD5(personnel_no|manager_personnel_no)
    employee_hk    CHAR(32)     NOT NULL REFERENCES hub_employee(employee_hk),
    manager_hk     CHAR(32)     NOT NULL REFERENCES hub_employee(employee_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    record_source  VARCHAR(50)  NOT NULL,
    CONSTRAINT uq_link_employee_manager UNIQUE (employee_hk, manager_hk)
);
COMMENT ON TABLE link_employee_manager IS 'Иерархический линк «Сотрудник — руководитель»';

-- =====================================================================
-- САТЕЛЛИТЫ
-- =====================================================================

-- Атрибуты клиента
CREATE TABLE sat_customer (
    customer_hk    CHAR(32)     NOT NULL REFERENCES hub_customer(customer_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    hash_diff      CHAR(32)     NOT NULL,
    customer_type  CHAR(1)      NOT NULL,
    name           VARCHAR(200) NOT NULL,
    inn            VARCHAR(12),
    phone          VARCHAR(20),
    email          VARCHAR(100),
    city           VARCHAR(100),      -- денормализовано из справочника city
    region         VARCHAR(100),
    address        VARCHAR(200),
    discount_pct   NUMERIC(4,2),
    registered_at  DATE,
    record_source  VARCHAR(50)  NOT NULL,
    PRIMARY KEY (customer_hk, load_date)
);
COMMENT ON TABLE sat_customer IS 'Сателлит хаба «Клиент»: контакты, адрес, скидка (с историей)';

-- Атрибуты сотрудника
CREATE TABLE sat_employee (
    employee_hk    CHAR(32)     NOT NULL REFERENCES hub_employee(employee_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    hash_diff      CHAR(32)     NOT NULL,
    last_name      VARCHAR(50)  NOT NULL,
    first_name     VARCHAR(50)  NOT NULL,
    middle_name    VARCHAR(50),
    position_title VARCHAR(100),      -- денормализовано из справочника position
    base_salary    NUMERIC(12,2),
    phone          VARCHAR(20),
    email          VARCHAR(100),
    hire_date      DATE,
    record_source  VARCHAR(50)  NOT NULL,
    PRIMARY KEY (employee_hk, load_date)
);
COMMENT ON TABLE sat_employee IS 'Сателлит хаба «Сотрудник»';

-- Атрибуты поставщика
CREATE TABLE sat_supplier (
    supplier_hk    CHAR(32)     NOT NULL REFERENCES hub_supplier(supplier_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    hash_diff      CHAR(32)     NOT NULL,
    name           VARCHAR(200) NOT NULL,
    contact_name   VARCHAR(100),
    phone          VARCHAR(20),
    email          VARCHAR(100),
    city           VARCHAR(100),
    address        VARCHAR(200),
    record_source  VARCHAR(50)  NOT NULL,
    PRIMARY KEY (supplier_hk, load_date)
);
COMMENT ON TABLE sat_supplier IS 'Сателлит хаба «Поставщик»';

-- Описательные атрибуты товара (меняются редко)
CREATE TABLE sat_product (
    product_hk     CHAR(32)     NOT NULL REFERENCES hub_product(product_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    hash_diff      CHAR(32)     NOT NULL,
    name           VARCHAR(200) NOT NULL,
    unit           VARCHAR(10),
    is_active      BOOLEAN,
    record_source  VARCHAR(50)  NOT NULL,
    PRIMARY KEY (product_hk, load_date)
);
COMMENT ON TABLE sat_product IS 'Сателлит хаба «Товар»: наименование, ед. измерения, активность';

-- Цена и остаток товара (меняются часто — выделены в отдельный сателлит
-- по скорости изменения, чтобы не дублировать описательные атрибуты)
CREATE TABLE sat_product_price (
    product_hk     CHAR(32)     NOT NULL REFERENCES hub_product(product_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    hash_diff      CHAR(32)     NOT NULL,
    price          NUMERIC(12,2) NOT NULL,
    stock_qty      INT,
    record_source  VARCHAR(50)  NOT NULL,
    PRIMARY KEY (product_hk, load_date)
);
COMMENT ON TABLE sat_product_price IS 'Сателлит хаба «Товар»: история цен и остатков';

-- Атрибуты категории
CREATE TABLE sat_category (
    category_hk    CHAR(32)     NOT NULL REFERENCES hub_category(category_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    hash_diff      CHAR(32)     NOT NULL,
    description    VARCHAR(200),
    record_source  VARCHAR(50)  NOT NULL,
    PRIMARY KEY (category_hk, load_date)
);
COMMENT ON TABLE sat_category IS 'Сателлит хаба «Категория»';

-- Атрибуты заказа (статус меняется — история сохраняется)
CREATE TABLE sat_order (
    order_hk       CHAR(32)     NOT NULL REFERENCES hub_order(order_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    hash_diff      CHAR(32)     NOT NULL,
    order_date     TIMESTAMP    NOT NULL,
    status_code    VARCHAR(20)  NOT NULL,     -- денормализовано из order_status
    status_name    VARCHAR(100),
    delivery_date  DATE,
    comment        TEXT,
    record_source  VARCHAR(50)  NOT NULL,
    PRIMARY KEY (order_hk, load_date)
);
COMMENT ON TABLE sat_order IS 'Сателлит хаба «Заказ»: дата, статус, доставка';

-- Атрибуты позиции заказа (сателлит линка)
CREATE TABLE sat_order_line (
    link_order_product_hk CHAR(32) NOT NULL REFERENCES link_order_product(link_order_product_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    hash_diff      CHAR(32)     NOT NULL,
    line_no        SMALLINT,
    quantity       INT          NOT NULL,
    unit_price     NUMERIC(12,2) NOT NULL,
    discount_pct   NUMERIC(4,2),
    record_source  VARCHAR(50)  NOT NULL,
    PRIMARY KEY (link_order_product_hk, load_date)
);
COMMENT ON TABLE sat_order_line IS 'Сателлит линка «Позиция заказа»: количество, цена, скидка';

-- Атрибуты платежа
CREATE TABLE sat_payment (
    payment_hk     CHAR(32)     NOT NULL REFERENCES hub_payment(payment_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    hash_diff      CHAR(32)     NOT NULL,
    amount         NUMERIC(12,2) NOT NULL,
    paid_at        TIMESTAMP    NOT NULL,
    payment_method VARCHAR(50),               -- денормализовано из payment_method
    record_source  VARCHAR(50)  NOT NULL,
    PRIMARY KEY (payment_hk, load_date)
);
COMMENT ON TABLE sat_payment IS 'Сателлит хаба «Платёж»';

-- Атрибуты поставки
CREATE TABLE sat_supply (
    supply_hk      CHAR(32)     NOT NULL REFERENCES hub_supply(supply_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    hash_diff      CHAR(32)     NOT NULL,
    supply_date    DATE         NOT NULL,
    record_source  VARCHAR(50)  NOT NULL,
    PRIMARY KEY (supply_hk, load_date)
);
COMMENT ON TABLE sat_supply IS 'Сателлит хаба «Поставка»';

-- Атрибуты позиции поставки (сателлит линка)
CREATE TABLE sat_supply_line (
    link_supply_product_hk CHAR(32) NOT NULL REFERENCES link_supply_product(link_supply_product_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    hash_diff      CHAR(32)     NOT NULL,
    quantity       INT          NOT NULL,
    unit_cost      NUMERIC(12,2) NOT NULL,
    record_source  VARCHAR(50)  NOT NULL,
    PRIMARY KEY (link_supply_product_hk, load_date)
);
COMMENT ON TABLE sat_supply_line IS 'Сателлит линка «Позиция поставки»';

-- Условия поставщика по товару (сателлит линка)
CREATE TABLE sat_supplier_product (
    link_supplier_product_hk CHAR(32) NOT NULL REFERENCES link_supplier_product(link_supplier_product_hk),
    load_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    hash_diff      CHAR(32)     NOT NULL,
    purchase_price NUMERIC(12,2) NOT NULL,
    lead_time_days SMALLINT,
    record_source  VARCHAR(50)  NOT NULL,
    PRIMARY KEY (link_supplier_product_hk, load_date)
);
COMMENT ON TABLE sat_supplier_product IS 'Сателлит линка «Ассортимент поставщика»: закупочная цена, срок поставки';

-- =====================================================================
-- Индексы по хеш-ключам хабов внутри линков (ускоряют обратные соединения)
-- =====================================================================
CREATE INDEX ix_lo_customer  ON link_order(customer_hk);
CREATE INDEX ix_lo_employee  ON link_order(employee_hk);
CREATE INDEX ix_lop_product  ON link_order_product(product_hk);
CREATE INDEX ix_lpo_order    ON link_payment_order(order_hk);
CREATE INDEX ix_ls_supplier  ON link_supply(supplier_hk);
CREATE INDEX ix_lsp_product  ON link_supply_product(product_hk);
CREATE INDEX ix_lpc_category ON link_product_category(category_hk);
