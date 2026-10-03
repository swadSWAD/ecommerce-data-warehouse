#!/bin/bash
# ==========================================================
# 02_configure_flume.sh - Flume ????
# ? hadoop102 ?? root ??
# ==========================================================
set -e

FLUME_HOME=/opt/module/flume-1.10.1
HADOOP_HOME=/opt/module/hadoop-3.3.4

echo "=== 1. ?? Flume ?????? ==="
mkdir -p $FLUME_HOME/jobs

echo "=== 2. ?? ????1????? ? Kafka (hadoop102) ==="
cat > $FLUME_HOME/jobs/file_to_kafka.conf << 'FLUMEEOF1'
# ????
a1.sources = r1
a1.channels = c1
a1.sinks = k1

# source: TailDir ????????
a1.sources.r1.type = TAILDIR
a1.sources.r1.positionFile = /opt/module/flume-1.10.1/jobs/taildir_position.json
a1.sources.r1.filegroups = f1
a1.sources.r1.filegroups.f1 = /opt/module/applog/.*\.log
a1.sources.r1.fileHeader = true

# interceptor: ???
a1.sources.r1.interceptors = i1
a1.sources.r1.interceptors.i1.type = static
a1.sources.r1.interceptors.i1.key = timestamp
a1.sources.r1.interceptors.i1.value = 1

# channel: Kafka Channel????? Kafka?
a1.channels.c1.type = org.apache.flume.channel.kafka.KafkaChannel
a1.channels.c1.kafka.bootstrap.servers = hadoop102:9092,hadoop103:9092,hadoop104:9092
a1.channels.c1.kafka.topic = topic_log
a1.channels.c1.parseAsFlumeEvent = false

# sink: ????????????? kafka channel?
a1.sinks.k1.type = logger

# ??
a1.sources.r1.channels = c1
a1.sinks.k1.channel = c1
FLUMEEOF1

echo "=== 3. ?? ????2?Kafka ? HDFS (hadoop103/104) ==="
cat > $FLUME_HOME/jobs/kafka_to_hdfs.conf << 'FLUMEEOF2'
# ????
a2.sources = r2
a2.channels = c2
a2.sinks = k2

# source: Kafka ???
a2.sources.r2.type = org.apache.flume.source.kafka.KafkaSource
a2.sources.r2.kafka.bootstrap.servers = hadoop102:9092,hadoop103:9092,hadoop104:9092
a2.sources.r2.kafka.topics = topic_log
a2.sources.r2.kafka.consumer.group.id = flume_hdfs
a2.sources.r2.batchSize = 100

# channel: ????
a2.channels.c2.type = file
a2.channels.c2.checkpointDir = /opt/module/flume-1.10.1/data/checkpoint
a2.channels.c2.dataDirs = /opt/module/flume-1.10.1/data/data

# sink: HDFS
a2.sinks.k2.type = hdfs
a2.sinks.k2.hdfs.path = /origin_data/gmall/log/topic_log/%Y-%m-%d
a2.sinks.k2.hdfs.filePrefix = log-
a2.sinks.k2.hdfs.rollInterval = 3600
a2.sinks.k2.hdfs.rollSize = 134217728
a2.sinks.k2.hdfs.rollCount = 0
a2.sinks.k2.hdfs.fileType = CompressedStream
a2.sinks.k2.hdfs.codeC = gzip

# ??
a2.sources.r2.channels = c2
a2.sinks.k2.channel = c2
FLUMEEOF2

echo "=== 4. ?????? ==="
mkdir -p $FLUME_HOME/data/checkpoint $FLUME_HOME/data/data

echo "=== 5. ?? Flume ??? 103/104 ==="
rsync -av $FLUME_HOME/jobs/ hadoop103:$FLUME_HOME/jobs/
rsync -av $FLUME_HOME/conf/ hadoop103:$FLUME_HOME/conf/
rsync -av $FLUME_HOME/jobs/ hadoop104:$FLUME_HOME/jobs/
rsync -av $FLUME_HOME/conf/ hadoop104:$FLUME_HOME/conf/

echo "=== Flume ??????????==="
echo "  hadoop102: ?????? flume-1.agent ???Kafka"
echo "    flume-ng agent -n a1 -c \$FLUME_HOME/conf -f \$FLUME_HOME/jobs/file_to_kafka.conf"
echo "  hadoop103/104: ?? HDFS ?? flume"
echo "    flume-ng agent -n a2 -c \$FLUME_HOME/conf -f \$FLUME_HOME/jobs/kafka_to_hdfs.conf"
