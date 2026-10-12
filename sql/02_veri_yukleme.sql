/* =====================================================================
   02_veri_yukleme.sql
   Amaç : CSV dosyalarından gelen ham veriyi (stg_ tabloları) temizleyerek
          ana tablolara aktarmak (ETL).

   ADIM 1 (SSMS arayüzünde, SQL ile değil):
     Her CSV için veritabanına sağ tık > Tasks > Import Flat File...
     Tablo adları: stg_customers, stg_sellers, stg_products,
                   stg_translation, stg_orders, stg_order_items,
                   stg_order_payments, stg_order_reviews
     Sihirbazda "Modify Columns" ekranında:
       - Primary Key hiçbir sütunda işaretli olmasın
       - Tüm sütunlarda Allow Nulls açık olsun
       - Sayısal sütunlar int, tarih sütunları datetime2 olsun
       - PARA SÜTUNLARI varchar(20) olsun:
            stg_order_items.price, stg_order_items.freight_value,
            stg_order_payments.payment_value
         Neden: Sihirbaz, Türkçe bölgesel ayar yüzünden "134.97"
         değerini nokta binlik ayracı sanıp 13497 olarak okudu (gelir
         yaklaşık 100 kat şişti). Metin olarak yükleyip TRY_CAST ile
         çevirmek sorunu çözer, çünkü T-SQL ondalık ayracı olarak her
         zaman noktayı kullanır.

   ADIM 2: Bu dosyadaki INSERT'ler, aşağıdaki sırayla çalıştırılır.
           Sıra, foreign key'ler yüzünden önemlidir.
   ===================================================================== */

USE olist;
GO

INSERT INTO customers
SELECT customer_id, customer_unique_id, customer_zip_code_prefix,
       customer_city, customer_state
FROM stg_customers;

INSERT INTO sellers
SELECT seller_id, seller_zip_code_prefix, seller_city, seller_state
FROM stg_sellers;

INSERT INTO products
SELECT product_id, product_category_name, product_name_lenght,
       product_description_lenght, product_photos_qty, product_weight_g,
       product_length_cm, product_height_cm, product_width_cm
FROM stg_products;

-- Sihirbaz bu dosyada başlık satırını veri olarak yükleyebiliyor.
-- Sütun adları farklı gelirse (örn. Column1) önce SELECT TOP 5 * ile bak.
INSERT INTO product_category_translation
SELECT product_category_name, product_category_name_english
FROM stg_translation;

DELETE FROM product_category_translation
WHERE product_category_name = 'product_category_name';   -- başlık satırı

-- Çevirisi olmayan 2 kategoriyi elle ekle
-- (ikinci çeviri projeye özgü, orijinal veri setinde karşılığı yok)
IF NOT EXISTS (SELECT 1 FROM product_category_translation WHERE product_category_name = 'pc_gamer')
    INSERT INTO product_category_translation
    VALUES ('pc_gamer', 'pc_gamer');

IF NOT EXISTS (SELECT 1 FROM product_category_translation
               WHERE product_category_name = 'portateis_cozinha_e_preparadores_de_alimentos')
    INSERT INTO product_category_translation
    VALUES ('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_food_preparers');

INSERT INTO orders
SELECT order_id, customer_id, order_status, order_purchase_timestamp,
       order_approved_at, order_delivered_carrier_date,
       order_delivered_customer_date, order_estimated_delivery_date
FROM stg_orders;

-- Para sütunları metinden ondalık sayıya burada çevriliyor
INSERT INTO order_items
SELECT order_id, order_item_id, product_id, seller_id, shipping_limit_date,
       TRY_CAST(price         AS DECIMAL(10,2)),
       TRY_CAST(freight_value AS DECIMAL(10,2))
FROM stg_order_items;

INSERT INTO order_payments
SELECT order_id, payment_sequential, payment_type, payment_installments,
       TRY_CAST(payment_value AS DECIMAL(10,2))
FROM stg_order_payments;

INSERT INTO order_reviews
SELECT review_id, order_id, review_score, review_comment_title,
       review_comment_message, review_creation_date, review_answer_timestamp
FROM stg_order_reviews;
GO

/* ADIM 3: Doğrulama. Beklenen satır sayıları:
   customers 99441, sellers 3095, products 32951, orders 99441,
   order_items 112650, order_payments 103886, order_reviews 99224,
   product_category_translation 73 (71 + elle eklenen 2)
   Not: stg_ tabloları ham veri katmanı olarak saklanabilir. */
SELECT 'customers' AS tablo, COUNT(*) AS satir FROM customers
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'product_category_translation', COUNT(*) FROM product_category_translation
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews;
GO
