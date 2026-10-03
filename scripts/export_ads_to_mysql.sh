#!/bin/bash
# ==========================================================
# ?? ADS ??? MySQL (v2 - ?? QUOTE ????)
# ==========================================================
set -e

echo "===== [2/3] ? Hive ???? ====="

hive -S -e "SET hive.cli.print.header=false;
SELECT CONCAT('INSERT INTO ads_gmv VALUES(\"', dt, '\",', order_count, ',', order_user_count, ',', order_amount, ');')
FROM gmall.ads_gmv;" > /tmp/load_gmv.sql
echo "  ads_gmv: $(wc -l < /tmp/load_gmv.sql) ?"

hive -S -e "SET hive.cli.print.header=false;
SELECT CONCAT('INSERT INTO ads_order_by_province VALUES(\"', dt, '\",', province_id, ',\"', province_name, '\",', order_count, ',', order_total_amount, ');')
FROM gmall.ads_order_by_province;" > /tmp/load_province.sql
echo "  ads_order_by_province: $(wc -l < /tmp/load_province.sql) ?"

hive -S -e "SET hive.cli.print.header=false;
SELECT CONCAT('INSERT INTO ads_sku_topn VALUES(\"', dt, '\",', sku_id, ',\"', sku_name, '\",', order_amount, ',', order_count, ',', rnk, ');')
FROM gmall.ads_sku_topn;" > /tmp/load_sku.sql
echo "  ads_sku_topn: $(wc -l < /tmp/load_sku.sql) ?"

echo "===== [3/3] ?? MySQL ====="
mysql -uroot -p"$MYSQL_PASSWORD" gmall_report < /tmp/load_gmv.sql 2>/dev/null
mysql -uroot -p"$MYSQL_PASSWORD" gmall_report < /tmp/load_province.sql 2>/dev/null
mysql -uroot -p"$MYSQL_PASSWORD" gmall_report < /tmp/load_sku.sql 2>/dev/null

echo ""
echo "===== ?? ====="
mysql -uroot -p"$MYSQL_PASSWORD" -e "
SELECT 'ads_gmv' AS tbl, COUNT(*) AS rows_cnt FROM gmall_report.ads_gmv
UNION ALL SELECT 'ads_order_by_province', COUNT(*) FROM gmall_report.ads_order_by_province
UNION ALL SELECT 'ads_sku_topn', COUNT(*) FROM gmall_report.ads_sku_topn;" 2>/dev/null