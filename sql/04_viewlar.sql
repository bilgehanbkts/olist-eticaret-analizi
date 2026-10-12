/* =====================================================================
   04_viewlar.sql
   Amaç : Analizlerde tekrar tekrar kullanılacak temiz veri katmanları.
   Not  : CREATE VIEW, bir batch'teki ilk komut olmak zorunda olduğu için
          her view'dan sonra GO var.
   ===================================================================== */

USE olist;
GO

/* View 1: Teslim edilen siparişlerin kalem düzeyinde satış verisi.
   Gelir ve kategori analizlerinde kullanılır. Sadece order_status = 'delivered'. */
CREATE OR ALTER VIEW vw_teslim_edilen_satislar AS
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_state,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    oi.product_id,
    oi.seller_id,
    oi.price,
    oi.freight_value,
    COALESCE(t.product_category_name_english,
             p.product_category_name,
             'bilinmiyor') AS kategori
FROM orders o
JOIN customers c    ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p     ON oi.product_id = p.product_id
LEFT JOIN product_category_translation t
    ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered';
GO

/* View 2: Sipariş düzeyinde teslimat ve memnuniyet verisi.
   - Teslim tarihi boş olan 8 tutarsız sipariş hariç tutulur.
   - Bir siparişin birden fazla yorumu olabildiği için yorumlar önce
     sipariş başına tek puana indirilir (satır çoğalmasını önlemek için).
   - gecikme_gun > 0 ise sipariş tahmini tarihten sonra gelmiştir. */
CREATE OR ALTER VIEW vw_teslimat AS
SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_state,
    o.order_purchase_timestamp,
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS teslimat_gun,
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_estimated_delivery_date) AS tahmini_gun,
    DATEDIFF(DAY, o.order_estimated_delivery_date, o.order_delivered_customer_date) AS gecikme_gun,
    CASE WHEN DATEDIFF(DAY, o.order_estimated_delivery_date, o.order_delivered_customer_date) > 0
         THEN 1 ELSE 0 END AS gecikti_mi,
    r.puan
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN (
    SELECT order_id, AVG(CAST(review_score AS DECIMAL(4,2))) AS puan
    FROM order_reviews
    GROUP BY order_id
) r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;
GO
