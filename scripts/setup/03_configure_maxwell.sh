#!/bin/bash
# ==========================================================
# 03_configure_maxwell.sh - Maxwell CDC ??
# ? hadoop102 ?? root ??
# ==========================================================
set -e

MAXWELL_HOME=/opt/module/maxwell-1.29.2

echo "=== 1. ?? MySQL binlog????????==="
mysql -uroot -p123456 -e "SHOW VARIABLES LIKE 'log_bin';" 2>/dev/null | grep -q ON || {
    echo "  ??? /etc/my.cnf ??? binlog???????"
    cat >> /etc/my.cnf << 'MYCNF'

# Maxwell ??? binlog ??
server-id=1
log-bin=mysql-bin
binlog_format=row
binlog-do-db=gmall
MYCNF
    systemctl restart mysqld
    echo "  MySQL ????binlog ???"
}

echo "=== 2. ?? Maxwell ???? ==="
mysql -uroot -p123456 << 'SQLEOF'
CREATE USER IF NOT EXISTS 'maxwell'@'%' IDENTIFIED BY 'maxwell';
GRANT ALL PRIVILEGES ON maxwell.* TO 'maxwell'@'%';
GRANT SELECT, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'maxwell'@'%';
FLUSH PRIVILEGES;
SQLEOF

echo "=== 3. ?? Maxwell ???? ==="
cat > $MAXWELL_HOME/conf/config.properties << 'MAXEOF'
# Maxwell ??
log_level=info

# MySQL ??
host=hadoop102
port=3306
user=maxwell
password=maxwell

# ??????
filter=exclude: *.*, include:gmall.*

# ??? Kafka
producer=kafka
kafka.bootstrap.servers=hadoop102:9092,hadoop103:9092,hadoop104:9092
kafka.topic=mall_data_db

# ????
client_id=maxwell_1
maxwell_db.maxwell
# ????
kafka.partition_by=database
MAXEOF

echo "=== 4. ??? Maxwell ??? ==="
$MAXWELL_HOME/bin/maxwell --config $MAXWELL_HOME/conf/config.properties --daemon --init 2>&1 | tail -5 || true
sleep 2

echo "=== Maxwell ??????????==="
echo "  $MAXWELL_HOME/bin/maxwell --config $MAXWELL_HOME/conf/config.properties --daemon"
echo "  tail -f $MAXWELL_HOME/logs/maxwell.log  # ????"
