#!/bin/bash
# ==========================================================
# ???? MySQL -> Hive ODS(?????)
# ??: bash sync_ods.sh
# ==========================================================
DT=2026-06-23
HADOOP=/opt/module/hadoop-3.3.4/bin/hadoop
BASE=/origin_data/gmall/db
TMP=/tmp/ods_export
mkdir -p $TMP

# ??1: MySQL??  ??2: Hive??  ??3: ????
sync_one() {
  local mtab=$1
  local htab=$2
  local cols=$3
  echo ">>> $mtab -> $htab"
  mysql -uroot -p"$MYSQL_PASSWORD" -B -N -e "SELECT $cols FROM gmall.$mtab" > $TMP/$htab.txt 2>/dev/null
  local n=$(wc -l < $TMP/$htab.txt)
  echo "    ????: $n"
  sudo -u atguigu $HADOOP fs -mkdir -p $BASE/$htab/dt=$DT
  sudo -u atguigu $HADOOP fs -put -f $TMP/$htab.txt $BASE/$htab/dt=$DT/
}

sync_one base_category1 ods_base_category1_full "*"
sync_one base_category2 ods_base_category2_full "*"
sync_one base_category3 ods_base_category3_full "*"
sync_one base_trademark ods_base_trademark_full "*"
sync_one base_dic       ods_base_dic_full       "*"
sync_one base_province  ods_base_province_full  "*"
sync_one sku_info       ods_sku_info_full       "*"
sync_one spu_info       ods_spu_info_full       "*"
sync_one activity_info  ods_activity_info_full  "*"
sync_one user_info      ods_user_info_inc       "*"
sync_one order_info     ods_order_info_inc      "*"
sync_one order_detail   ods_order_detail_inc    "*"
sync_one cart_info      ods_cart_info_inc       "*"
sync_one comment_info   ods_comment_info_inc    "*"
sync_one favor_info     ods_favor_info_inc      "*"

# payment_info ? text ??, ??????? callback_content
sync_one payment_info ods_payment_info_inc \
  "id,out_trade_no,order_id,user_id,payment_type,trade_no,total_amount,subject,payment_status,create_time,callback_time,operate_time"

echo ""
echo ">>> ???????"
hive -e "USE gmall;
$(for t in base_category1_full base_category2_full base_category3_full base_trademark_full \
base_dic_full base_province_full sku_info_full spu_info_full activity_info_full \
user_info_inc order_info_inc order_detail_inc payment_info_inc cart_info_inc \
comment_info_inc favor_info_inc; do echo "MSCK REPAIR TABLE ods_$t;"; done)"

echo ""
echo ">>> ???????"
hive -e "USE gmall;
SELECT 'category1', COUNT(*) FROM ods_base_category1_full WHERE dt='$DT'
UNION ALL SELECT 'category2', COUNT(*) FROM ods_base_category2_full WHERE dt='$DT'
UNION ALL SELECT 'category3', COUNT(*) FROM ods_base_category3_full WHERE dt='$DT'
UNION ALL SELECT 'trademark', COUNT(*) FROM ods_base_trademark_full WHERE dt='$DT'
UNION ALL SELECT 'dic', COUNT(*) FROM ods_base_dic_full WHERE dt='$DT'
UNION ALL SELECT 'province', COUNT(*) FROM ods_base_province_full WHERE dt='$DT'
UNION ALL SELECT 'sku', COUNT(*) FROM ods_sku_info_full WHERE dt='$DT'
UNION ALL SELECT 'spu', COUNT(*) FROM ods_spu_info_full WHERE dt='$DT'
UNION ALL SELECT 'activity', COUNT(*) FROM ods_activity_info_full WHERE dt='$DT'
UNION ALL SELECT 'user', COUNT(*) FROM ods_user_info_inc WHERE dt='$DT'
UNION ALL SELECT 'order', COUNT(*) FROM ods_order_info_inc WHERE dt='$DT'
UNION ALL SELECT 'order_detail', COUNT(*) FROM ods_order_detail_inc WHERE dt='$DT'
UNION ALL SELECT 'payment', COUNT(*) FROM ods_payment_info_inc WHERE dt='$DT'
UNION ALL SELECT 'cart', COUNT(*) FROM ods_cart_info_inc WHERE dt='$DT'
UNION ALL SELECT 'comment', COUNT(*) FROM ods_comment_info_inc WHERE dt='$DT'
UNION ALL SELECT 'favor', COUNT(*) FROM ods_favor_info_inc WHERE dt='$DT';"