/* =====================================================================
   05_satis_analizi.sql
   Amaç : Zaman içindeki satış trendi ve kategori bazlı gelir.
   Not  : Sadece teslim edilen siparişler ve ürün fiyatı (kargo hariç).
   ===================================================================== */

USE olist;
GO

-- 1) Aylık sipariş sayısı ve gelir
--    (PostgreSQL'deki DATE_TRUNC yerine DATEFROMPARTS kullanıldı)
SELECT
    DATEFROMPARTS(YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp), 1) AS ay,
    COUNT(DISTINCT order_id) AS siparis_sayisi,
    ROUND(SUM(price), 2)     AS toplam_gelir
FROM vw_teslim_edilen_satislar
GROUP BY DATEFROMPARTS(YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp), 1)
ORDER BY ay;

-- 2) Gelire göre en iyi 10 kategori
SELECT TOP 10
    kategori,
    COUNT(DISTINCT order_id) AS siparis_sayisi,
    ROUND(SUM(price), 2)     AS toplam_gelir
FROM vw_teslim_edilen_satislar
GROUP BY kategori
ORDER BY toplam_gelir DESC;
GO
