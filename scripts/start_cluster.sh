#!/bin/bash
# ==========================================================
# 05_start_cluster.sh - ???????????????
# ? hadoop102 ?? root ??
# ??: bash 05_start_cluster.sh
# ==========================================================
set -e

echo "=========================================="
echo "  ??????????"
echo "=========================================="

echo ""
echo ">>> [1/5] ?? Hadoop HDFS..."
start-dfs.sh
sleep 3

echo ""
echo ">>> [2/5] ?? Hadoop YARN..."
start-yarn.sh
sleep 3

echo ""
echo ">>> [3/5] ?? Zookeeper ??..."
for host in hadoop102 hadoop103 hadoop104; do
    echo "  ?? $host ..."
    ssh $host "/opt/module/zookeeper-3.7.1/bin/zkServer.sh start"
done
sleep 3

echo ""
echo ">>> [4/5] ?? Kafka ??..."
for host in hadoop102 hadoop103 hadoop104; do
    echo "  ?? $host ..."
    ssh $host "/opt/module/kafka-3.3.1/bin/kafka-server-start.sh -daemon /opt/module/kafka-3.3.1/config/server.properties"
done
sleep 3

echo ""
echo ">>> [5/5] ??????..."
echo ""
echo "--- JPS ?? ---"
for host in hadoop102 hadoop103 hadoop104; do
    echo "--- $host ---"
    ssh $host "jps" | grep -v Jps
done

echo ""
echo "--- Kafka Brokers ---"
/opt/module/zookeeper-3.7.1/bin/zkCli.sh -server hadoop102:2181 ls /kafka/brokers/ids 2>/dev/null | grep -E "^\["

echo ""
echo "=========================================="
echo "  ???????"
echo "=========================================="
echo "  Web UI:"
echo "    HDFS: http://hadoop102:9870"
echo "    YARN: http://hadoop102:8088"
echo "=========================================="
