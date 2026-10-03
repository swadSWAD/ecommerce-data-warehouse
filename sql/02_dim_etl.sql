USE gmall;

-- ==================================================
-- 1. ????? dim_date
-- ==================================================
DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date (
  date_id STRING COMMENT '??ID',
  week_id STRING COMMENT '?ID',
  week_day STRING COMMENT '??',
  day STRING COMMENT '?',
  month STRING COMMENT '?',
  quarter STRING COMMENT '??',
  year STRING COMMENT '?',
  is_workday STRING COMMENT '?????',
  holiday_id STRING COMMENT '???'
) COMMENT '?????' STORED AS ORC;

-- ??????(?????)
DROP TABLE IF EXISTS stg_date_info;
CREATE EXTERNAL TABLE stg_date_info (
  date_id STRING, week_id STRING, week_day STRING, day STRING, month STRING,
  quarter STRING, year STRING, is_workday STRING, holiday_id STRING
) COMMENT '???????' ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE LOCATION '/origin_data/gmall/dim/date_info';

INSERT OVERWRITE TABLE dim_date
SELECT date_id, week_id, week_day, day, month, quarter, year, is_workday, holiday_id
FROM stg_date_info;

-- ==================================================
-- 2. ????? dim_user_zip
-- ==================================================
DROP TABLE IF EXISTS dim_user_zip;
CREATE TABLE dim_user_zip (
  id BIGINT COMMENT '??id',
  login_name STRING COMMENT '???',
  nick_name STRING COMMENT '??',
  name STRING COMMENT '??',
  phone_num STRING COMMENT '???',
  email STRING COMMENT '??',
  user_level STRING COMMENT '????',
  birthday STRING COMMENT '??',
  gender STRING COMMENT '??',
  create_time STRING COMMENT '????',
  start_date STRING COMMENT '????',
  end_date STRING COMMENT '????'
) COMMENT '???????' STORED AS ORC;

-- ????:???? start_date=????, end_date=9999-12-31
INSERT OVERWRITE TABLE dim_user_zip
SELECT id, login_name, nick_name, name, phone_num, email, user_level, birthday, gender,
       create_time,
       SUBSTR(create_time, 1, 10) AS start_date,
       '9999-12-31' AS end_date
FROM ods_user_info_inc
WHERE dt='2026-06-23';
