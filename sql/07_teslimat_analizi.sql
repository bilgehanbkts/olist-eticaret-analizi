/* =====================================================================
   07_teslimat_analizi.sql
   Amaç : Teslimat performansını, müşteri memnuniyetini ve tekrar alım
          davranışını incelemek.
   Soru : Geç teslimat puanı düşürüyor mu? Müşterinin geri dönmesini
          etkiliyor mu?
   Notlar:
     - Analiz sipariş düzeyinde yapılır (vw_teslimat).
     - "Gecikme", platformun verdiği tahmini teslim tarihine göre tanımlıdır.
     - Tekrar alım analizlerinde yalnızca ilk siparişi 2018 öncesi olan
       müşteriler alınır. Veri Ağustos 2018'de bittiği için bu müşterilerin
       tümüne tekrar alışveriş yapmak için en az 8 ay süre tanınmış olur.
   ===================================================================== */

USE olist;
GO

-- 1) Genel özet
SELECT
    COUNT(*)                                     AS siparis,
    ROUND(AVG(1.0 * teslimat_gun), 1)            AS ort_teslimat_gun,
    ROUND(AVG(1.0 * tahmini_gun), 1)             AS ort_tahmini_gun,
    ROUND(100.0 * SUM(gecikti_mi) / COUNT(*), 1) AS gecikme_orani_yuzde,
    ROUND(AVG(puan), 2)                          AS ort_puan
FROM vw_teslimat;

-- 2) Gecikmenin puana etkisi
SELECT
    CASE
        WHEN gecikme_gun <= 0 THEN N'1) Zamanında veya erken'
        WHEN gecikme_gun <= 3 THEN N'2) 1-3 gün geç'
        WHEN gecikme_gun <= 7 THEN N'3) 4-7 gün geç'
        ELSE N'4) 8+ gün geç'
    END AS gecikme_grubu,
    COUNT(*)                                                                   AS siparis,
    ROUND(AVG(puan), 2)                                                        AS ort_puan,
    ROUND(100.0 * SUM(CASE WHEN puan <= 2 THEN 1 ELSE 0 END) / COUNT(puan), 1) AS dusuk_puan_orani_yuzde
FROM vw_teslimat
GROUP BY
    CASE
        WHEN gecikme_gun <= 0 THEN N'1) Zamanında veya erken'
        WHEN gecikme_gun <= 3 THEN N'2) 1-3 gün geç'
        WHEN gecikme_gun <= 7 THEN N'3) 4-7 gün geç'
        ELSE N'4) 8+ gün geç'
    END
ORDER BY gecikme_grubu;

-- 3) Gerçek teslimat süresine göre puan
SELECT
    CASE
        WHEN teslimat_gun <= 7  THEN N'1) 0-7 gün'
        WHEN teslimat_gun <= 14 THEN N'2) 8-14 gün'
        WHEN teslimat_gun <= 21 THEN N'3) 15-21 gün'
        ELSE N'4) 22+ gün'
    END AS teslimat_suresi,
    COUNT(*)                                                                   AS siparis,
    ROUND(AVG(puan), 2)                                                        AS ort_puan,
    ROUND(100.0 * SUM(CASE WHEN puan <= 2 THEN 1 ELSE 0 END) / COUNT(puan), 1) AS dusuk_puan_orani_yuzde
FROM vw_teslimat
GROUP BY
    CASE
        WHEN teslimat_gun <= 7  THEN N'1) 0-7 gün'
        WHEN teslimat_gun <= 14 THEN N'2) 8-14 gün'
        WHEN teslimat_gun <= 21 THEN N'3) 15-21 gün'
        ELSE N'4) 22+ gün'
    END
ORDER BY teslimat_suresi;

-- 4) Eyalet bazlı teslimat performansı (en az 500 siparişi olan eyaletler)
SELECT TOP 10
    customer_state,
    COUNT(*)                                     AS siparis,
    ROUND(AVG(1.0 * teslimat_gun), 1)            AS ort_teslimat_gun,
    ROUND(100.0 * SUM(gecikti_mi) / COUNT(*), 1) AS gecikme_orani_yuzde,
    ROUND(AVG(puan), 2)                          AS ort_puan
FROM vw_teslimat
GROUP BY customer_state
HAVING COUNT(*) >= 500
ORDER BY gecikme_orani_yuzde DESC;

-- 5) İlk siparişin gecikmesi, müşterinin tekrar alışveriş yapmasını etkiliyor mu?
WITH siralama AS (
    SELECT
        customer_unique_id,
        order_purchase_timestamp,
        gecikti_mi,
        ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp) AS sira,
        COUNT(*)     OVER (PARTITION BY customer_unique_id) AS siparis_sayisi
    FROM vw_teslimat
)
SELECT
    CASE WHEN gecikti_mi = 1 THEN N'Geç teslim edildi' ELSE N'Zamanında teslim edildi' END AS ilk_siparis,
    COUNT(*) AS musteri,
    SUM(CASE WHEN siparis_sayisi > 1 THEN 1 ELSE 0 END) AS tekrar_alan,
    ROUND(100.0 * SUM(CASE WHEN siparis_sayisi > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS tekrar_orani_yuzde
FROM siralama
WHERE sira = 1
  AND order_purchase_timestamp < '2018-01-01'
GROUP BY gecikti_mi;

-- 6) İlk siparişin puanı, tekrar alışverişi etkiliyor mu?
WITH siralama AS (
    SELECT
        customer_unique_id,
        order_purchase_timestamp,
        puan,
        ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp) AS sira,
        COUNT(*)     OVER (PARTITION BY customer_unique_id) AS siparis_sayisi
    FROM vw_teslimat
)
SELECT
    CASE
        WHEN puan IS NULL THEN N'4) Yorum yok'
        WHEN puan <= 2    THEN N'1) Düşük (1-2)'
        WHEN puan < 4     THEN N'2) Orta (3)'
        ELSE N'3) Yüksek (4-5)'
    END AS ilk_siparis_puani,
    COUNT(*) AS musteri,
    ROUND(100.0 * SUM(CASE WHEN siparis_sayisi > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS tekrar_orani_yuzde
FROM siralama
WHERE sira = 1
  AND order_purchase_timestamp < '2018-01-01'
GROUP BY
    CASE
        WHEN puan IS NULL THEN N'4) Yorum yok'
        WHEN puan <= 2    THEN N'1) Düşük (1-2)'
        WHEN puan < 4     THEN N'2) Orta (3)'
        ELSE N'3) Yüksek (4-5)'
    END
ORDER BY ilk_siparis_puani;

-- 7) (Opsiyonel) Aynı soru, en büyük 3 eyalette ayrı ayrı: gecikme etkisi
--    yer farkından mı kaynaklanıyor? (README'deki bulgular bu sorguya dayanmaz.)
WITH siralama AS (
    SELECT
        customer_unique_id,
        customer_state,
        order_purchase_timestamp,
        gecikti_mi,
        ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp) AS sira,
        COUNT(*)     OVER (PARTITION BY customer_unique_id) AS siparis_sayisi
    FROM vw_teslimat
)
SELECT
    customer_state AS eyalet,
    gecikti_mi,
    COUNT(*) AS musteri,
    ROUND(100.0 * SUM(CASE WHEN siparis_sayisi > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS tekrar_orani_yuzde
FROM siralama
WHERE sira = 1
  AND order_purchase_timestamp < '2018-01-01'
  AND customer_state IN ('SP', 'RJ', 'MG')
GROUP BY customer_state, gecikti_mi
ORDER BY customer_state, gecikti_mi;
GO
