#!/bin/bash
# ???? ETL?DWD -> DWS -> ADS?
source /etc/profile
hive -f /opt/scripts/etl_dw.sql
