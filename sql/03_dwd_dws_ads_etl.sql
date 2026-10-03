USE gmall;
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;

-- ==================================================
-- ??DIM ???
-- ==================================================
DROP TABLE IF EXISTS dim_province_full;
CREATE TABLE dim_province_full (
  id BIGINT COMMENT '??id',
  province_name STRING COMMENT '????',
  area_code STRING COMMENT '????',
  iso_code STRING COMMENT 'ISO??'
) COMMENT '?????' STORED AS ORC;

INSERT OVERWRITE TABLE dim_province_full
SELECT id, name, area_code, iso_code
FROM ods_base_province_full
WHERE dt='2026-06-23';

DROP TABLE IF EXISTS dim_sku_full;
CREATE TABLE dim_sku_full (
  id BIGINT COMMENT 'sku_id',
  sku_name STRING COMMENT 'sku??',
  price DECIMAL(16,2) COMMENT '??',
  tm_id BIGINT COMMENT '??id',
  tm_name STRING COMMENT '????',
  category3_id BIGINT COMMENT '????id',
  category3_name STRING COMMENT '??????',
  category2_name STRING COMMENT '??????',
  category1_name STRING COMMENT '??????',
  spu_id BIGINT COMMENT 'spu_id'
) COMMENT 'SKU???' STORED AS ORC;

INSERT OVERWRITE TABLE dim_sku_full
SELECT s.id, s.sku_name, s.price, s.tm_id, t.tm_name,
       s.category3_id, c3.name, c2.name, c1.name, s.spu_id
FROM ods_sku_info_full s
LEFT JOIN ods_base_trademark_full t  ON s.tm_id = t.id          AND t.dt='2026-06-23'
LEFT JOIN ods_base_category3_full c3 ON s.category3_id = c3.id  AND c3.dt='2026-06-23'
LEFT JOIN ods_base_category2_full c2 ON c3.category2_id = c2.id AND c2.dt='2026-06-23'
LEFT JOIN ods_base_category1_full c1 ON c2.category1_id = c1.id AND c1.dt='2026-06-23'
WHERE s.dt='2026-06-23';

-- ==================================================
-- ??DWD ???????????
-- ==================================================
DROP TABLE IF EXISTS dwd_trade_order_detail_inc;
CREATE TABLE dwd_trade_order_detail_inc (
  order_id BIGINT COMMENT '??id',
  user_id BIGINT COMMENT '??id',
  sku_id BIGINT COMMENT 'sku_id',
  sku_name STRING COMMENT 'sku??',
  province_id INT COMMENT '??id',
  order_price DECIMAL(16,2) COMMENT '??',
  sku_num BIGINT COMMENT '??',
  split_total_amount DECIMAL(16,2) COMMENT '????',
  create_time STRING COMMENT '????'
) COMMENT '??????????'
PARTITIONED BY (dt STRING) STORED AS ORC;

INSERT OVERWRITE TABLE dwd_trade_order_detail_inc PARTITION(dt='2026-06-23')
SELECT od.order_id, oi.user_id, od.sku_id, od.sku_name, oi.province_id,
       od.order_price, od.sku_num, od.split_total_amount, od.create_time
FROM ods_order_detail_inc od
LEFT JOIN ods_order_info_inc oi ON od.order_id = oi.id AND oi.dt='2026-06-23'
WHERE od.dt='2026-06-23';

-- ==================================================
-- ??DWS ???
-- ==================================================
DROP TABLE IF EXISTS dws_trade_province_order_1d;
CREATE TABLE dws_trade_province_order_1d (
  province_id INT COMMENT '??id',
  province_name STRING COMMENT '????',
  order_count BIGINT COMMENT '???',
  order_total_amount DECIMAL(16,2) COMMENT '????'
) COMMENT '???????????'
PARTITIONED BY (dt STRING) STORED AS ORC;

INSERT OVERWRITE TABLE dws_trade_province_order_1d PARTITION(dt='2026-06-23')
SELECT oi.province_id, p.province_name,
       COUNT(DISTINCT oi.id), SUM(oi.total_amount)
FROM ods_order_info_inc oi
LEFT JOIN dim_province_full p ON oi.province_id = p.id
WHERE oi.dt='2026-06-23'
GROUP BY oi.province_id, p.province_name;

DROP TABLE IF EXISTS dws_trade_user_order_1d;
CREATE TABLE dws_trade_user_order_1d (
  user_id BIGINT COMMENT '??id',
  order_count BIGINT COMMENT '???',
  order_sku_num BIGINT COMMENT '????',
  order_total_amount DECIMAL(16,2) COMMENT '????'
) COMMENT '???????????'
PARTITIONED BY (dt STRING) STORED AS ORC;

INSERT OVERWRITE TABLE dws_trade_user_order_1d PARTITION(dt='2026-06-23')
SELECT user_id, COUNT(*), SUM(sku_num), SUM(total_amount)
FROM (
  SELECT oi.user_id, oi.id, oi.total_amount,
         NVL(SUM(od.sku_num), 0) AS sku_num
  FROM ods_order_info_inc oi
  LEFT JOIN ods_order_detail_inc od
    ON oi.id = od.order_id AND od.dt='2026-06-23'
  WHERE oi.dt='2026-06-23'
  GROUP BY oi.user_id, oi.id, oi.total_amount
) t
GROUP BY user_id;

-- ==================================================
-- ??ADS ???
-- ==================================================
DROP TABLE IF EXISTS ads_gmv;
CREATE TABLE ads_gmv (
  dt STRING COMMENT '????',
  order_count BIGINT COMMENT '???',
  order_user_count BIGINT COMMENT '?????',
  order_amount DECIMAL(16,2) COMMENT '????'
) COMMENT 'GMV??' STORED AS ORC;

INSERT OVERWRITE TABLE ads_gmv
SELECT '2026-06-23', COUNT(*), COUNT(DISTINCT user_id), SUM(total_amount)
FROM ods_order_info_inc WHERE dt='2026-06-23';

DROP TABLE IF EXISTS ads_order_by_province;
CREATE TABLE ads_order_by_province (
  dt STRING COMMENT '????',
  province_id INT COMMENT '??id',
  province_name STRING COMMENT '????',
  order_count BIGINT COMMENT '???',
  order_total_amount DECIMAL(16,2) COMMENT '????'
) COMMENT '???????' STORED AS ORC;

INSERT OVERWRITE TABLE ads_order_by_province
SELECT '2026-06-23', province_id, province_name, order_count, order_total_amount
FROM dws_trade_province_order_1d WHERE dt='2026-06-23';

DROP TABLE IF EXISTS ads_sku_topn;
CREATE TABLE ads_sku_topn (
  dt STRING COMMENT '????',
  sku_id BIGINT COMMENT '??id',
  sku_name STRING COMMENT '????',
  order_amount DECIMAL(16,2) COMMENT '???',
  order_count BIGINT COMMENT '??',
  rnk BIGINT COMMENT '??'
) COMMENT '??????' STORED AS ORC;

INSERT OVERWRITE TABLE ads_sku_topn
SELECT '2026-06-23', sku_id, sku_name, order_amount, order_count, rnk
FROM (
  SELECT sku_id, MAX(sku_name) AS sku_name,
         SUM(split_total_amount) AS order_amount,
         SUM(sku_num) AS order_count,
         RANK() OVER (ORDER BY SUM(split_total_amount) DESC) AS rnk
  FROM dwd_trade_order_detail_inc
  WHERE dt='2026-06-23'
  GROUP BY sku_id
) t
WHERE rnk <= 10;
