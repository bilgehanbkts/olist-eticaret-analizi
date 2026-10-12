/* =====================================================================
   03_veri_kalitesi.sql
   Amaç : Analize başlamadan önce veriyi tanımak ve hataları yakalamak.
   ===================================================================== */

USE olist;
GO

-- 1) Para sütunu sağlık kontrolü (ondalık ayracı hatası yakalamak için)
--    Beklenen: en yüksek fiyat 6735.00, toplam yaklaşık 13.591.643,70
SELECT MAX(price) AS en_yuksek, SUM(price) AS toplam FROM order_items;

-- 2) Sipariş durumları dağılımı
SELECT order_status, COUNT(*) AS adet
FROM orders
GROUP BY order_status
ORDER BY adet DESC;

-- 3) Durumu "delivered" olduğu halde teslim tarihi boş olan siparişler
SELECT COUNT(*) AS tutarsiz_siparis
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- 4) Kategori adı boş olan ürünler
SELECT COUNT(*) AS kategorisiz_urun
FROM products
WHERE product_category_name IS NULL;

-- 5) Çevirisi olmayan kategoriler
SELECT DISTINCT p.product_category_name
FROM products p
LEFT JOIN product_category_translation t
    ON p.product_category_name = t.product_category_name
WHERE t.product_category_name IS NULL
  AND p.product_category_name IS NOT NULL;

-- 6) Çeviri tablosunda başlık satırı veya tekrar eden kategori var mı?
--    Her iki sorgu da boş dönmeli.
SELECT * FROM product_category_translation
WHERE product_category_name = 'product_category_name';

SELECT product_category_name, COUNT(*) AS adet
FROM product_category_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;
GO
