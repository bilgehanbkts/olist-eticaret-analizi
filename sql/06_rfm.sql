/* =====================================================================
   06_rfm.sql
   Amaç : Müşterileri RFM (Recency, Frequency, Monetary) ile segmentlere
          ayırmak.
   Notlar:
     - Müşteri, customer_id ile değil customer_unique_id ile sayılır.
       (Olist'te her sipariş için yeni bir customer_id üretilir.)
     - Recency: verideki son sipariş tarihinin 1 gün sonrası referans alınır.
     - R ve M, NTILE(5) ile 1-5 puanlanır (5 en iyi).
     - Frequency için NTILE kullanılmadı: müşterilerin %97'si tek sipariş
       verdiği için eşit bölme anlamsız olur. Sabit eşik kullanıldı:
       1 sipariş = 1, 2 sipariş = 3, 3+ sipariş = 5.
   ===================================================================== */

USE olist;
GO

-- 1) Frekans dağılımı (puanlama eşiklerini belirlemek için)
SELECT
    frekans,
    COUNT(*) AS musteri_sayisi
FROM (
    SELECT customer_unique_id, COUNT(DISTINCT order_id) AS frekans
    FROM vw_teslim_edilen_satislar
    GROUP BY customer_unique_id
) t
GROUP BY frekans
ORDER BY frekans;
GO

-- 2) RFM view'ı
CREATE OR ALTER VIEW vw_rfm AS
WITH musteri AS (
    SELECT
        customer_unique_id,
        MAX(order_purchase_timestamp) AS son_siparis,
        COUNT(DISTINCT order_id)      AS frekans,
        SUM(price)                    AS parasal
    FROM vw_teslim_edilen_satislar
    GROUP BY customer_unique_id
),
referans AS (
    SELECT DATEADD(DAY, 1, MAX(order_purchase_timestamp)) AS tarih
    FROM vw_teslim_edilen_satislar
),
rfm AS (
    SELECT
        m.customer_unique_id,
        DATEDIFF(DAY, m.son_siparis, r.tarih) AS recency,
        m.frekans,
        m.parasal
    FROM musteri m
    CROSS JOIN referans r
),
skor AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency DESC) AS r_skor,   -- yakın tarih = yüksek puan
        CASE WHEN frekans = 1 THEN 1
             WHEN frekans = 2 THEN 3
             ELSE 5 END                       AS f_skor,
        NTILE(5) OVER (ORDER BY parasal)      AS m_skor
    FROM rfm
)
SELECT
    customer_unique_id, recency, frekans, parasal,
    r_skor, f_skor, m_skor,
    CASE
        WHEN r_skor >= 4 AND f_skor >= 3 AND m_skor >= 4 THEN N'Şampiyonlar'
        WHEN f_skor >= 3 AND r_skor >= 3                 THEN N'Sadık Müşteriler'
        WHEN f_skor >= 3 AND r_skor <= 2                 THEN N'Kaybedilme Riski (Sadık)'
        WHEN r_skor >= 4 AND m_skor >= 4                 THEN N'Yüksek Değerli Yeni'
        WHEN r_skor >= 4                                 THEN N'Yeni Müşteriler'
        WHEN r_skor <= 2 AND m_skor >= 4                 THEN N'Kaybedilen Yüksek Değerli'
        WHEN r_skor <= 2                                 THEN N'Uykudaki Müşteriler'
        ELSE N'Gelişim Potansiyeli'
    END AS segment
FROM skor;
GO

-- 3) Segment özeti (CTE + NTILE + pencere fonksiyonu sonucu)
SELECT
    segment,
    COUNT(*)                                                    AS musteri_sayisi,
    ROUND(AVG(parasal), 2)                                      AS ort_harcama,
    ROUND(SUM(parasal), 2)                                      AS toplam_gelir,
    ROUND(100.0 * SUM(parasal) / SUM(SUM(parasal)) OVER (), 1)  AS gelir_payi_yuzde
FROM vw_rfm
GROUP BY segment
ORDER BY toplam_gelir DESC;
GO
