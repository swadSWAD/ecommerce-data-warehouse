#!/bin/bash
# ==========================================================
# 01_install_spark.sh - Spark 3.3.1 ????
# ? hadoop102 ?? root ????
# ==========================================================
set -e

SPARK_HOME=/opt/module/spark
SPARK_TGZ=/opt/software/spark-3.3.1-bin-hadoop3.tgz
HADOOP_HOME=/opt/module/hadoop-3.3.4
HIVE_HOME=/opt/module/hive

echo "=== 1. ?? Spark ==="
if [ ! -d "$SPARK_HOME" ]; then
    tar -zxvf $SPARK_TGZ -C /opt/module/
    mv /opt/module/spark-3.3.1-bin-hadoop3 /opt/module/spark
else
    echo "Spark ????????"
fi

echo "=== 2. ?? spark-defaults.conf ==="
cat > $SPARK_HOME/conf/spark-defaults.conf << 'SPARKEOF'
spark.master                     yarn
spark.deployMode                 cluster
spark.eventLog.enabled           true
spark.eventLog.dir               hdfs://hadoop102:8020/spark-history
spark.serializer                 org.apache.spark.serializer.KryoSerializer
spark.driver.memory              512m
spark.executor.memory            512m
spark.executor.cores             1
spark.yarn.historyServer.address hadoop102:18080
spark.history.fs.logDirectory    hdfs://hadoop102:8020/spark-history
SPARKEOF

echo "=== 3. ?? spark-env.sh ==="
cat > $SPARK_HOME/conf/spark-env.sh << 'SPARKENV'
export JAVA_HOME=/opt/module/jdk1.8.0_212
export HADOOP_HOME=/opt/module/hadoop-3.3.4
export HADOOP_CONF_DIR=/opt/module/hadoop-3.3.4/etc/hadoop
export SPARK_MASTER_HOST=hadoop102
export SPARK_MASTER_PORT=7077
SPARKENV
chmod +x $SPARK_HOME/conf/spark-env.sh

echo "=== 4. ?? workers ==="
cat > $SPARK_HOME/conf/workers << 'SPARKWK'
hadoop102
hadoop103
hadoop104
SPARKWK

echo "=== 5. ?? hive-site.xml ? Spark ==="
cp $HIVE_HOME/conf/hive-site.xml $SPARK_HOME/conf/

echo "=== 6. ?? Spark jar ? HDFS ==="
sudo -u atguigu $HADOOP_HOME/bin/hadoop fs -mkdir -p /spark-jars
sudo -u atguigu $HADOOP_HOME/bin/hadoop fs -mkdir -p /spark-history
sudo -u atguigu $HADOOP_HOME/bin/hadoop fs -put $SPARK_HOME/jars/* /spark-jars/

echo "=== 7. ?? Hive ?????? Spark ???? ==="
HIVE_CONF=$HIVE_HOME/conf/hive-site.xml
if grep -q "hive.execution.engine" $HIVE_CONF; then
    sed -i 's|<value>mr</value>|<value>spark</value>|' $HIVE_CONF
fi
# ?? spark ????
grep -q "spark.yarn.jars" $HIVE_CONF || cat >> $HIVE_CONF << 'HIVEEOF'
    <property>
        <name>spark.yarn.jars</name>
        <value>hdfs://hadoop102:8020/spark-jars/*</value>
    </property>
    <property>
        <name>hive.spark.client.connect.timeout</name>
        <value>600000</value>
    </property>
</configuration>
HIVEEOF

echo "=== 8. ?? Spark ? 103/104 ==="
rsync -av $SPARK_HOME/ hadoop103:$SPARK_HOME/ --exclude='data'
rsync -av $SPARK_HOME/ hadoop104:$SPARK_HOME/ --exclude='data'

echo "=== 9. ?? Spark ???? ==="
grep -q "SPARK_HOME" /etc/profile.d/my_env.sh || cat >> /etc/profile.d/my_env.sh << 'ENVEOF'

#SPARK_HOME
export SPARK_HOME=/opt/module/spark
export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin
ENVEOF
source /etc/profile.d/my_env.sh

ssh hadoop103 "grep -q 'SPARK_HOME' /etc/profile.d/my_env.sh || cat >> /etc/profile.d/my_env.sh << 'ENVEOF'

#SPARK_HOME
export SPARK_HOME=/opt/module/spark
export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin
ENVEOF"

ssh hadoop104 "grep -q 'SPARK_HOME' /etc/profile.d/my_env.sh || cat >> /etc/profile.d/my_env.sh << 'ENVEOF'

#SPARK_HOME
export SPARK_HOME=/opt/module/spark
export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin
ENVEOF"

echo "=== ?? ==="
$SPARK_HOME/bin/spark-shell --version 2>&1 | head -3
echo ""
echo "Spark ????????? YARN ??????"
echo "  spark-submit --class org.apache.spark.examples.SparkPi --master yarn $SPARK_HOME/examples/jars/spark-examples*.jar"
