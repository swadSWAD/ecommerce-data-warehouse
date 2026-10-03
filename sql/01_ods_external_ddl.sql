USE gmall;

-- ========== ???????==========
DROP TABLE IF EXISTS ods_base_category1_full;
CREATE EXTERNAL TABLE ods_base_category1_full (
  id BIGINT COMMENT '??', name STRING COMMENT '????',
  create_time STRING COMMENT '????', operate_time STRING COMMENT '????'
) COMMENT '?????' PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE
LOCATION '/origin_data/gmall/db/ods_base_category1_full';

DROP TABLE IF EXISTS ods_base_category2_full;
CREATE EXTERNAL TABLE ods_base_category2_full (
  id BIGINT, name STRING, category1_id BIGINT,
  create_time STRING, operate_time STRING
) COMMENT '?????' PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE
LOCATION '/origin_data/gmall/db/ods_base_category2_full';

DROP TABLE IF EXISTS ods_base_category3_full;
CREATE EXTERNAL TABLE ods_base_category3_full (
  id BIGINT, name STRING, category2_id BIGINT,
  create_time STRING, operate_time STRING
) COMMENT '?????' PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE
LOCATION '/origin_data/gmall/db/ods_base_category3_full';

DROP TABLE IF EXISTS ods_base_trademark_full;
CREATE EXTERNAL TABLE ods_base_trademark_full (
  id BIGINT, tm_name STRING, logo_url STRING,
  create_time STRING, operate_time STRING
) COMMENT '???' PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE
LOCATION '/origin_data/gmall/db/ods_base_trademark_full';

DROP TABLE IF EXISTS ods_base_dic_full;
CREATE EXTERNAL TABLE ods_base_dic_full (
  dic_code STRING, dic_name STRING, parent_code STRING,
  create_time STRING, operate_time STRING
) COMMENT '???' PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE
LOCATION '/origin_data/gmall/db/ods_base_dic_full';

DROP TABLE IF EXISTS ods_base_province_full;
CREATE EXTERNAL TABLE ods_base_province_full (
  id BIGINT, name STRING, region_id STRING, area_code STRING,
  iso_code STRING, iso_3166_2 STRING, create_time STRING, operate_time STRING
) COMMENT '???' PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE
LOCATION '/origin_data/gmall/db/ods_base_province_full';

DROP TABLE IF EXISTS ods_sku_info_full;
CREATE EXTERNAL TABLE ods_sku_info_full (
  id BIGINT, spu_id BIGINT, price DECIMAL(16,2), sku_name STRING, sku_desc STRING,
  weight DECIMAL(16,2), tm_id BIGINT, category3_id BIGINT, sku_default_img STRING,
  is_sale TINYINT, create_time STRING, operate_time STRING
) COMMENT 'SKU???' PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE
LOCATION '/origin_data/gmall/db/ods_sku_info_full';

DROP TABLE IF EXISTS ods_spu_info_full;
CREATE EXTERNAL TABLE ods_spu_info_full (
  id BIGINT, spu_name STRING, description STRING, category3_id BIGINT,
  tm_id BIGINT, create_time STRING, operate_time STRING
) COMMENT 'SPU???' PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE
LOCATION '/origin_data/gmall/db/ods_spu_info_full';

DROP TABLE IF EXISTS ods_activity_info_full;
CREATE EXTERNAL TABLE ods_activity_info_full (
  id BIGINT, activity_name STRING, activity_type STRING, activity_desc STRING,
  start_time STRING, end_time STRING, create_time STRING, operate_time STRING
) COMMENT '?????' PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE
LOCATION '/origin_data/gmall/db/ods_activity_info_full';

-- ========== ???????==========
DROP TABLE IF EXISTS ods_user_info_inc;
CREATE EXTERNAL TABLE ods_user_info_inc (
  id BIGINT, login_name STRING, nick_name STRING, passwd STRING, name STRING,
  phone_num STRING, email STRING, head_img STRING, user_level STRING,
  birthday STRING, gender STRING, create_time STRING, operate_time STRING, status STRING
) COMMENT '?????' PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE
LOCATION '/origin_data/gmall/db/ods_user_info_inc';

DROP TABLE IF EXISTS ods_order_info_inc;
CREATE EXTERNAL TABLE ods_order_info_inc (
  id BIGINT, consignee STRING, consignee_tel STRING, total_amount DECIMAL(16,2),
  order_status STRING, user_id BIGINT, payment_way STRING, delivery_address STRING,
  order_comment STRING, out_trade_no STRING, trade_body STRING, create_time STRING,
  operate_time STRING, expire_time STRING, process_status STRING, tracking_no STRING,
  parent_order_id BIGINT, img_url STRING, province_id INT,
  activity_reduce_amount DECIMAL(16,2), coupon_reduce_amount DECIMAL(16,2),
  original_total_amount DECIMAL(16,2), feight_fee DECIMAL(16,2),
  feight_fee_reduce DECIMAL(16,2), refundable_time STRING
) COMMENT '???' PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE
LOCATION '/origin_data/gmall/db/ods_order_info_inc';

DROP TABLE IF EXISTS ods_order_detail_inc;
CREATE EXTERNAL TABLE ods_order_detail_inc (
  id BIGINT, order_id BIGINT, sku_id BIGINT, sku_name STRING, img_url STRING,
  order_price DECIMAL(16,2), sku_num BIGINT, create_time STRING,
  split_total_amount DECIMAL(16,2), split_activity_amount DECIMAL(16,2),
  split_coupon_amount DECIMAL(16,2), operate_time STRING
) COMMENT '?????' PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE
LOCATION '/origin_data/gmall/db/ods_order_detail_inc';

DROP TABLE IF EXISTS ods_payment_info_inc;
CREATE EXTERNAL TABLE ods_payment_info_inc (
  id BIGINT, out_trade_no STRING, order_id BIGINT, user_id BIGINT,
  payment_type STRING, trade_no STRING, total_amount DECIMAL(16,2), subject STRING,
  payment_status STRING, create_time STRING, callback_time STRING, operate_time STRING
) COMMENT '???' PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE
LOCATION '/origin_data/gmall/db/ods_payment_info_inc';

DROP TABLE IF EXISTS ods_cart_info_inc;
CREATE EXTERNAL TABLE ods_cart_info_inc (
  id BIGINT, user_id STRING, sku_id BIGINT, cart_price DECIMAL(16,2), sku_num INT,
  img_url STRING, sku_name STRING, is_checked INT, create_time STRING,
  operate_time STRING, is_ordered BIGINT, order_time STRING
) COMMENT '????' PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE
LOCATION '/origin_data/gmall/db/ods_cart_info_inc';

DROP TABLE IF EXISTS ods_comment_info_inc;
CREATE EXTERNAL TABLE ods_comment_info_inc (
  id BIGINT, user_id BIGINT, nick_name STRING, head_img STRING, sku_id BIGINT,
  spu_id BIGINT, order_id BIGINT, appraise STRING, comment_txt STRING,
  create_time STRING, operate_time STRING
) COMMENT '???' PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE
LOCATION '/origin_data/gmall/db/ods_comment_info_inc';

DROP TABLE IF EXISTS ods_favor_info_inc;
CREATE EXTERNAL TABLE ods_favor_info_inc (
  id BIGINT, user_id BIGINT, sku_id BIGINT, spu_id BIGINT, is_cancel STRING,
  create_time STRING, operate_time STRING
) COMMENT '???' PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE
LOCATION '/origin_data/gmall/db/ods_favor_info_inc';
