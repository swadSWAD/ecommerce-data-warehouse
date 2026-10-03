#!/bin/bash
# ????? ETL?dim_date / dim_user_zip / dim_province / dim_sku?
source /etc/profile
hive -f /opt/scripts/etl_dim.sql
