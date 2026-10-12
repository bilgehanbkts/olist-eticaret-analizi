/* =====================================================================
   01_tablolari_olustur.sql
   Amaç : olist veritabanını ve ana tabloları oluşturmak (SQL Server 2022)
   Not  : Tablo sırası önemlidir. Foreign key'ler, önce oluşturulmuş
          tablolara bağlanır.
   ===================================================================== */

IF DB_ID('olist') IS NULL
    CREATE DATABASE olist;
GO

USE olist;
GO

-- 1) Müşteriler
CREATE TABLE customers (
    customer_id               VARCHAR(50)  NOT NULL PRIMARY KEY,
    customer_unique_id        VARCHAR(50),
    customer_zip_code_prefix  VARCHAR(10),
    customer_city             NVARCHAR(100),
    customer_state            CHAR(2)
);

-- 2) Satıcılar
CREATE TABLE sellers (
    seller_id               VARCHAR(50)  NOT NULL PRIMARY KEY,
    seller_zip_code_prefix  VARCHAR(10),
    seller_city             NVARCHAR(100),
    seller_state            CHAR(2)
);

-- 3) Ürünler (orijinal veri setindeki "lenght" yazım hatası bilerek korundu)
CREATE TABLE products (
    product_id                  VARCHAR(50)  NOT NULL PRIMARY KEY,
    product_category_name       NVARCHAR(100),
    product_name_lenght         INT,
    product_description_lenght  INT,
    product_photos_qty          INT,
    product_weight_g            INT,
    product_length_cm           INT,
    product_height_cm           INT,
    product_width_cm            INT
);

-- 4) Kategori çevirisi (Portekizce -> İngilizce), yalnızca arama tablosu
CREATE TABLE product_category_translation (
    product_category_name          NVARCHAR(100),
    product_category_name_english  NVARCHAR(100)
);

-- 5) Siparişler
CREATE TABLE orders (
    order_id                       VARCHAR(50)  NOT NULL PRIMARY KEY,
    customer_id                    VARCHAR(50)  NOT NULL REFERENCES customers(customer_id),
    order_status                   VARCHAR(20),
    order_purchase_timestamp       DATETIME2(0),
    order_approved_at              DATETIME2(0),
    order_delivered_carrier_date   DATETIME2(0),
    order_delivered_customer_date  DATETIME2(0),
    order_estimated_delivery_date  DATETIME2(0)
);

-- 6) Sipariş kalemleri
CREATE TABLE order_items (
    order_id             VARCHAR(50)  NOT NULL REFERENCES orders(order_id),
    order_item_id        INT          NOT NULL,
    product_id           VARCHAR(50)  NOT NULL REFERENCES products(product_id),
    seller_id            VARCHAR(50)  NOT NULL REFERENCES sellers(seller_id),
    shipping_limit_date  DATETIME2(0),
    price                DECIMAL(10,2),
    freight_value        DECIMAL(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

-- 7) Ödemeler
CREATE TABLE order_payments (
    order_id              VARCHAR(50)  NOT NULL REFERENCES orders(order_id),
    payment_sequential    INT          NOT NULL,
    payment_type          VARCHAR(30),
    payment_installments  INT,
    payment_value         DECIMAL(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- 8) Yorumlar (review_id veride tekrar ettiği için primary key yok)
CREATE TABLE order_reviews (
    review_id                VARCHAR(50),
    order_id                 VARCHAR(50)  NOT NULL REFERENCES orders(order_id),
    review_score             INT,
    review_comment_title     NVARCHAR(MAX),
    review_comment_message   NVARCHAR(MAX),
    review_creation_date     DATETIME2(0),
    review_answer_timestamp  DATETIME2(0)
);

-- Not: Veri setindeki geolocation tablosu bu projede kullanılmadı.
GO
