# 项目踩坑记录

> 本项目在搭建和联调过程中遇到并解决的 52 个问题。

每条按 **现象 → 原因 → 解决 → 经验** 组织，便于快速检索。

---

### 一、环境与连接（4 个）

#### 坑 1：Xshell 6 / XFTP 6 版本过期，必须改系统时间才能用

**现象**：打开 Xshell 提示试用过期，网上方案是改系统时间，但改了之后浏览器打不开、pip/yum 全部证书失效。

**原因**：Xshell 6 是商业软件的老版本，会校验本地时间。

**解决**：放弃 Xshell，改用 Windows 10/11 自带的 OpenSSH 客户端（`ssh` / `scp` 命令），零依赖、零授权问题。

**经验**：**永远不要为了迁就一个工具去改系统时间**，时间不准会连锁破坏 HTTPS、证书校验、日志时间戳。用系统原生工具往往更省事。

---

#### 坑 2：Windows 连虚拟机每次都要输密码

**现象**：Windows PowerShell `ssh root@hadoop102` 每次都要求输密码。

**原因**：只配置了虚拟机之间的免密，Windows 端的公钥没有分发到虚拟机。

**解决**：把 Windows 的 `id_rsa.pub` 追加到虚拟机的 `~/.ssh/authorized_keys`：
```bash
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@hadoop102 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

**经验**：免密登录是"公钥在哪台机器上"的问题，Windows→虚拟机 和 虚拟机↔虚拟机 是两套独立的信任关系。

---

#### 坑 3：虚拟机之间没有免密，集群脚本无法自动分发

**现象**：`start-dfs.sh` 启动时要求输入另外两台机器的密码。

**解决**：每台机器生成密钥并互相分发：
```bash
ssh-keygen -t rsa        # 一路回车
ssh-copy-id hadoop102
ssh-copy-id hadoop103
ssh-copy-id hadoop104
```

**经验**：Hadoop 的启停脚本依赖 SSH 免密，这是集群部署的前置条件，必须最先做。

---

#### 坑 4：`scp` 命令打在虚拟机里，报 "Could not resolve hostname c:"

**现象**：执行 `scp "C:\xxx" root@hadoop102:/opt/`，报 `ssh: Could not resolve hostname c:`。

**原因**：当前已经在虚拟机的 `[root@hadoop102 ~]#` 提示符下，Windows 路径在 Linux 里不存在。

**解决**：`scp` 必须在**本地的 Windows PowerShell 窗口**里执行，不是虚拟机里。

**经验**：分清"本地终端"和"远程会话"。提示符是 `PS C:\>` 是本地，`[root@...]#` 是远程。

---

### 二、Hadoop 集群（4 个）

#### 坑 5：103/104 的 HADOOP_HOME 指向旧版本 hadoop-3.1.3

**现象**：三台机器版本不统一，103/104 的环境变量指向 `hadoop-3.1.3`，但 102 用的是 `hadoop-3.3.4`。

**解决**：
```bash
sed -i 's|HADOOP_HOME=/opt/module/hadoop-3.1.3|HADOOP_HOME=/opt/module/hadoop-3.3.4|' /etc/profile.d/my_env.sh
source /etc/profile.d/my_env.sh
```

**经验**：**集群节点版本必须完全一致**，否则会出现 RPC 协议不兼容、序列化失败等难排查的问题。

---

#### 坑 6：103/104 的 hadoop-3.3.4 目录只有 `etc` 和 `data`，二进制文件全缺失

**现象**：`start-dfs.sh` 报 `hadoop103: bash: /opt/module/hadoop-3.3.4/bin/hdfs: 没有那个文件或目录`。

**原因**：之前只在 103/104 上解压了配置目录，没有完整解压安装包。

**解决**：从 102 直接 rsync 完整目录过去：
```bash
rsync -av --exclude='data' /opt/module/hadoop-3.3.4/ hadoop103:/opt/module/hadoop-3.3.4/
```

**经验**：部署前先验证目录完整性（`ls bin/hdfs`），比启动失败再排查高效得多。

---

#### 坑 7：Hadoop 配成了单机模式（workers=localhost、副本数=1）

**现象**：集群起不来 DataNode，或者只有一个节点在跑。

**原因**：`workers` 文件里只有 `localhost`，`hdfs-site.xml` 里 `dfs.replication=1`。

**解决**：
```bash
echo -e "hadoop102\nhadoop103\nhadoop104" > $HADOOP_HOME/etc/hadoop/workers
sed -i 's|<value>1</value>|<value>3</value>|' $HADOOP_HOME/etc/hadoop/hdfs-site.xml
# 同步配置到其他节点
rsync -av ./ hadoop103:$HADOOP_HOME/etc/hadoop/
```

**经验**：改完配置一定要同步到所有节点，否则各节点认知不一致。

---

#### 坑 8：HDFS 根目录属主是 `atguigu`，root 用户写入被拒绝

**现象**：`hadoop fs -mkdir /user/hive/warehouse` 报 `Permission denied: user=root, access=WRITE, inode="/":atguigu:supergroup:drwxr-xr-x`。

**原因**：HDFS 的超级用户是 `atguigu`，而当前 shell 是 root，HDFS 只认用户名不认 Linux 权限。

**解决**：两种方式
```bash
# 方式一：以 atguigu 身份执行
sudo -u atguigu $HADOOP_HOME/bin/hadoop fs -mkdir -p /user/hive/warehouse

# 方式二：设置环境变量，让后续命令都以 atguigu 身份操作 HDFS
export HADOOP_USER_NAME=atguigu
```

**经验**：**HDFS 的权限模型是基于用户名的，不是基于操作系统的**。这个坑会连带影响 Hive、Spark、DolphinScheduler 等一系列组件。

---

### 三、Zookeeper（4 个）

#### 坑 9：zoo.cfg 配置了 dataDir/dataLogDir 但目录不存在

**现象**：ZK 启动后立刻退出，日志报目录访问失败。

**解决**：
```bash
mkdir -p /opt/module/zookeeper-3.7.1/data /opt/module/zookeeper-3.7.1/dataLog
echo 1 > /opt/module/zookeeper-3.7.1/data/myid   # 102=1, 103=2, 104=3
```

**经验**：**myid 必须和 zoo.cfg 里的 `server.N` 编号对应**，写错了会一直选不出 Leader。

---

#### 坑 10：ZK 启动失败 —— "Snapshot directory has log files"

**现象**：104 启动报
```
SnapDirContentCheckException: Snapshot directory has log files.
Check if dataLogDir and dataDir configuration is correct.
```

**原因**：之前运行过 ZK，`data/version-2` 里残留了事务日志，和新配置的 dataLogDir 冲突。

**解决**：
```bash
rm -rf /opt/module/zookeeper-3.7.1/data/version-2/
echo 3 > /opt/module/zookeeper-3.7.1/data/myid
```

**经验**：ZK 的 dataDir 和 dataLogDir **必须分开且干净**，迁移或重配时残留数据会导致校验失败。

---

#### 坑 11：ZK "假活" —— start 说已运行，status 连不上

**现象**：
```
$ zkServer.sh start
Starting zookeeper ... already running as process 4923.
$ zkServer.sh status
Error contacting service. It is probably not running.
```

**原因**：进程已经被杀，但 `zookeeper_server.pid` 文件没清掉，start 脚本只看 pid 文件就认为在运行。

**解决**：
```bash
ps -ef | grep [z]ookeeper          # 确认进程确实不在
rm -f /opt/module/zookeeper-3.7.1/data/zookeeper_server.pid
zkServer.sh start
```

**经验**：**"pid 文件存在"不等于"进程还活着"**。任何服务异常退出都可能留下僵尸 pid，重启前先确认。

---

#### 坑 12：`pkill -f QuorumPeerMain` 杀不掉进程，反而中断了自己的命令

**现象**：`ssh hadoop103 "pkill -9 -f QuorumPeerMain; echo done"` 没有输出 done，进程还在。

**原因**：**`pkill -f` 会匹配完整命令行**，而 ssh 执行的这条命令本身包含字符串 "QuorumPeerMain"，于是把自己的 shell 也杀了，命令链直接中断。

**解决**：改用 jps 取 PID 再杀：
```bash
kill -9 $(jps | awk '/QuorumPeerMain/ {print $1}')
```

**经验**：**`pkill -f` 是个危险操作**，模式字符串会匹配到调用它自己的进程。生产上更推荐按 PID 精确操作。

---

#### 坑 13：三台 ZK 全部卡在 Leader 选举

**现象**：三台 ZK 进程都在（jps 有 QuorumPeerMain），但 `zkServer.sh status` 全部报连接失败，日志显示 `Cannot open channel to 2 at election address hadoop103:3888`。

**原因**：ZK 在选出 Leader 之前不会开放 2181 客户端端口，而三台互相连不上 3888 选举端口，陷入死循环。根因是残留的 pid 和脏数据。

**解决**：三台全部清理后按顺序重启：
```bash
kill -9 $(jps | awk '/QuorumPeerMain/ {print $1}')
rm -f /opt/module/zookeeper-3.7.1/data/zookeeper_server.pid
zkServer.sh start    # 102 → 103 → 104 依次启动
```

**经验**：**ZK 是集群，必须整体健康**。只启动部分节点会出现"单个节点看起来在跑但完全不可用"的假象。

---

### 四、Kafka（3 个）

#### 坑 14：三台机器的 zookeeper.connect 配置不一致，broker 互相看不见

**现象**：Kafka 三台进程都起来了，但创建 3 副本的 topic 报 `Replication factor: 3 larger than available brokers: 1`。

**原因**：102 的配置是 `zookeeper.connect=...:2181`（根路径），103/104 是 `...:2181/kafka`（带命名空间）。两个命名空间互相隔离，Kafka 只能看到自己那一组。

**解决**：统一加上 `/kafka` 后缀：
```bash
sed -i 's|zookeeper.connect=hadoop102:2181,hadoop103:2181,hadoop104:2181$|&/kafka|' server.properties
```

**经验**：**多节点部署时，配置项一定要逐节点 diff 对比**。这种"看起来都对、跑起来不对"的问题，基本都是配置不一致。

---

#### 坑 15：Kafka 启动报 InconsistentClusterIdException

**现象**：
```
kafka.common.InconsistentClusterIdException: The Cluster ID RABOf2s_...
doesn't match stored clusterId Some(3GkisFpLQli3UmH9QNY-6A) in meta.properties.
```

**原因**：102 之前在根路径 `/` 注册过，本地 `data/meta.properties` 记录了旧集群 ID；改成 `/kafka` 后 ZK 里是新集群 ID，两者对不上。

**解决**：
```bash
rm -f /opt/module/kafka-3.3.1/data/meta.properties
```

**经验**：切换 ZK 命名空间、重建集群时，**本地的 meta 文件必须一起清掉**，否则会校验失败。

---

#### 坑 16：log.dirs 默认在 `/tmp`，重启就丢数据

**现象**：Kafka 的默认配置 `log.dirs=/tmp/kafka-logs`，虚拟机重启后数据全没了。

**解决**：改成持久化目录：
```bash
mkdir -p /opt/module/kafka-3.3.1/data
sed -i 's|log.dirs=/tmp/kafka-logs|log.dirs=/opt/module/kafka-3.3.1/data|' server.properties
```

**经验**：**`/tmp` 目录会被系统清理**，任何需要持久化的服务都不能把数据放这里。

---

#### 坑 17：三台 broker.id 冲突、advertised.listeners 没按节点改

**现象**：多节点启动后部分 broker 注册失败。

**解决**：每台分别配置
```bash
# 102
broker.id=0 ; advertised.listeners=PLAINTEXT://192.168.10.102:9092
# 103
broker.id=1 ; advertised.listeners=PLAINTEXT://192.168.10.103:9092
# 104
broker.id=2 ; advertised.listeners=PLAINTEXT://192.168.10.104:9092
```

**经验**：`broker.id` 是节点唯一标识，**必须全局唯一**；`advertised.listeners` 是给客户端返回的地址，多节点必须写成各自的 IP，否则客户端会连到错误节点。

---

### 五、MySQL 与 Hive（6 个）

#### 坑 18：MySQL 密码策略太严，创建 Maxwell 用户失败

**现象**：`CREATE USER 'maxwell'@'%' IDENTIFIED BY 'maxwell'` 报
```
ERROR 1819 (HY000): Your password does not satisfy the current policy requirements
```

**解决**：
```sql
SET GLOBAL validate_password_policy=LOW;
SET GLOBAL validate_password_length=4;
```

**经验**：MySQL 5.7 默认启用密码强度校验。**测试环境可以放宽，生产环境必须保留强策略**。

---

#### 坑 19：Hive 元数据库初始化报 "Table 'CTLGS' already exists"

**现象**：`schematool -initSchema` 报
```
Table 'CTLGS' already exists
Schema initialization FAILED! Metastore state would be inconsistent !!
```

**原因**：之前初始化过一部分，元数据库里有残留表，脚本从头开始执行时就撞表了。

**解决**：彻底清库重建
```sql
DROP DATABASE hive;
CREATE DATABASE hive;
```

**经验**：Hive 的 schematool **不支持断点续传**，初始化失败必须清库重来，不能全量重跑。

---

#### 坑 20：Hive 启动报 HDFS 权限不足

**现象**：`Exception in thread "main" java.lang.RuntimeException: org.apache.hadoop.security.AccessControlException: Permission denied: user=root, access=WRITE, inode="/"`

**原因**：同坑 8，Hive 的 warehouse 目录需要以 HDFS 超级用户身份创建。

**解决**：
```bash
sudo -u atguigu $HADOOP_HOME/bin/hadoop fs -mkdir -p /user/hive/warehouse
sudo -u atguigu $HADOOP_HOME/bin/hadoop fs -chmod g+w /user/hive/warehouse
export HADOOP_USER_NAME=atguigu
```

**经验**：这个坑在 Hadoop 生态里**极其常见**，几乎所有组件第一次运行都会遇到。统一设置 `HADOOP_USER_NAME` 是最省事的做法。

---

#### 坑 21：Hive on Spark 报 "Failed to create Spark client"

**现象**：Hive 执行 SQL 时报
```
FAILED: SemanticException Failed to get a spark session:
HiveException: Failed to create Spark client for Spark session ...
```

**原因**：每台机器只有 4G 内存，Spark on YARN 申请不到足够的 executor 资源，客户端创建会话超时。

**解决**：
1. 短期：把执行引擎切回 MR，保证链路可用
```bash
sed -i 's|<value>spark</value>|<value>mr</value>|' hive-site.xml
```
2. 长期：调小 Spark 的资源配置（`spark.executor.memory=512m`）后再切回 Spark

**经验**：**技术选型要匹配硬件条件**。Hive on Spark 需要足够的内存，小规模环境用 MR 反而更稳。面试时这个点能体现"你懂取舍"。

---

#### 坑 22：Hive 建表报 "cannot recognize input near 'start' 'STRING'"

**现象**：建表时字段名为 `start`、`common`，报解析错误。

**原因**：`start`、`common` 是 Hive 的**保留字**，不能直接作为列名。

**解决**：
- 加反引号：`` `start` STRING ``
- 或者改字段类型/换名

**经验**：建表时**避免使用 SQL 保留字作为字段名**。真要用就必须加反引号。

---

#### 坑 23：Hive 没有 `QUOTE` 函数

**现象**：用 `SELECT CONCAT('INSERT ...', QUOTE(dt), ...)` 生成 SQL 报 `Invalid function QUOTE`。

**原因**：`QUOTE` 不是 Hive 的内置函数（那是 MySQL 的）。

**解决**：用 `CONCAT` 手动拼引号：
```sql
SELECT CONCAT('INSERT INTO t VALUES("', dt, '",', num, ');')
```

**经验**：**Hive 的函数集和 MySQL 不一样**，写 SQL 时不能想当然。（另外 Hive 里有 `collect_list`、`get_json_object` 这些 MySQL 没有的，各有各的方言。）

---

#### 坑 24：Hive 命令行卡在 "> >" 双提示符

**现象**：Hive CLI 变成 `hive (default)> >`，输入的语句都报 `ParseException ... near '>' 'USE' 'gmall'`。

**原因**：之前的语句有未闭合的引号或分号，Hive 认为语句没结束，进入续行模式。

**解决**：`exit;` 退出重进，或者输入 `;` 结束当前语句。

**经验**：CLI 的次级提示符（`>` 变成 `>>`）说明**上一条语句没结束**，先按 Ctrl+C 或补分号，别继续输入。

---

### 六、Maxwell CDC（3 个）

#### 坑 25：Maxwell 报 "Access denied for user 'maxwell'@'hadoop102'"

**现象**：Maxwell 启动后报 SQLException，日志刷 `BasicResourcePool: Having failed to acquire a resource`。

**原因**：配置文件里的密码和 MySQL 里实际创建的 maxwell 用户密码不一致。

**解决**：重置用户密码，配置文件和数据库对齐：
```sql
DROP USER IF EXISTS 'maxwell'@'%';
CREATE USER 'maxwell'@'%' IDENTIFIED BY 'maxwell';
GRANT ALL PRIVILEGES ON maxwell.* TO 'maxwell'@'%';
GRANT SELECT, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'maxwell'@'%';
FLUSH PRIVILEGES;
```

**经验**：**权限和密码是两件事**。Maxwell 需要 `REPLICATION SLAVE` + `REPLICATION CLIENT`（读 binlog），还要 `ALL` on `maxwell` 库（存自己的位点信息）。

---

#### 坑 26：Maxwell 报 "couldn't find the requested binlog"

**现象**：Maxwell 启动后立刻退出
```
[ERROR] Maxwell: Maxwell couldn't find the requested binlog, exiting...
```

**原因**：Maxwell 把上次消费到的 binlog 位点存在自己的库里。MySQL 重启后 binlog 文件名从 `mysql-bin.000006` 变成了 `mysql-bin.000007`，Maxwell 去找旧文件找不到。

**解决**：清掉 Maxwell 的位点库重新初始化：
```sql
DROP DATABASE maxwell;
CREATE DATABASE maxwell;
```

**经验**：**CDC 工具依赖 binlog 的连续性**。binlog 被清理或重置后，必须重新建立同步位点。生产上要给 binlog 设置足够的保留时间（`expire_logs_days`）。

---

#### 坑 27：Maxwell 日志找不到 maxwell.log

**现象**：`tail -f logs/maxwell.log` 报文件不存在，但进程确实起来了。

**解决**：Maxwell 的 daemon 模式日志写在 `logs/MaxwellDaemon.out`。

**经验**：**不同版本的日志文件名不一样**，找不到日志时先 `ls logs/` 看一眼，别死磕固定路径。

---

### 七、数据同步（DataX / ODS 层）（5 个）

#### 坑 28：DataX 写 ORC 格式到 HDFS 失败

**现象**：用 DataX 的 hdfswriter 写 ORC，报
```
Code:[HdfsWriter-02]: 您配置的path不存在, 请先在hive端创建对应的数据库和表
```
或者写出的文件 Hive 读不了（`Malformed ORC file ... Invalid postscript length 0`）。

**原因**：DataX 的 hdfswriter 本质是写**文本文件**，即使指定 `fileType=orc`，写出的是 gzip 压缩文本，不是真正的 ORC 格式，Hive 的 ORC reader 解析不了。

**解决**：**换方案**——ODS 层改用外部文本表：
1. `mysql -B -N` 直接导出制表符分隔文本
2. `hadoop fs -put` 上传到 HDFS
3. Hive 建外部文本表指向该目录
4. `MSCK REPAIR TABLE` 挂载分区

**经验**：**ODS 层用文本、明细汇总层用 ORC** 是更合理的架构——ODS 要保真和可回溯，ORC 的价值在查询性能上。这个坑最后反而成了方案优化的契机。

---

#### 坑 29：ODS 表字段与源表对不上（`final_total_amount` vs `total_amount`）

**现象**：按原设计同步数据时报列数不匹配。

**原因**：写 DDL 时凭印象造的字段名，和 MySQL 源表的真实字段不一致。

**解决**：查 `information_schema.COLUMNS` 拿到真实表结构，重建 ODS 表。

**经验**：**建 ODS 表必须以源表结构为准**，最好用脚本从 `information_schema` 自动生成 DDL，避免手写出错。

---

#### 坑 30：`SELECT ... INTO OUTFILE` 被 secure-file-priv 限制

**现象**：
```
ERROR 1290 (HY000): The MySQL server is running with the --secure-file-priv option
so it cannot execute this statement
```

**原因**：MySQL 5.7 出于安全考虑，限制文件只能写到指定目录。

**解决**：两种方式
```bash
# 方式一：写到允许的目录
mysql -e "SELECT ... INTO OUTFILE '/var/lib/mysql-files/xxx.txt' ..."

# 方式二（更推荐）：用客户端输出重定向，不受限制
mysql -uroot -p"$MYSQL_PASSWORD" -B -N -e "SELECT ... FROM t" > /tmp/xxx.txt
```

**经验**：**`-B -N` 参数组合能把查询结果输出成制表符分隔、无表头的纯净文本**，是做数据导出的常用技巧。

---

#### 坑 31：Hive 读外部文本表查出 0 行

**现象**：数据文件明明在 HDFS 上（1051 字节），`SELECT COUNT(*)` 却返回 0。

**原因**：表定义的字段分隔符和文件实际的格式不匹配，或者表是 EXTERNAL 表但数据文件不在表指向的目录里。

**解决**：用 `LOAD DATA LOCAL INPATH` 加载到**受管理的临时表**，再 `INSERT OVERWRITE` 写入正式表：
```sql
CREATE TABLE gmall.stg_province (...) 
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE;
LOAD DATA LOCAL INPATH '/tmp/province.txt' OVERWRITE INTO TABLE gmall.stg_province;
INSERT OVERWRITE TABLE gmall.ods_base_province_full PARTITION(dt='2026-06-23')
SELECT id, name, region_id, area_code, iso_code FROM gmall.stg_province;
```

**经验**：**文本文件与 Hive 表的格式必须严格对齐**（分隔符、文件位置、字段顺序）。排查这类问题要一条条验证：文件在不在 → 内容对不对 → 分隔符对不对 → 表指向的路径对不对。

---

#### 坑 32：16 张表的校验查询跑了十几分钟

**现象**：ODS 同步完成后，用一个 `UNION ALL` 的校验语句统计 16 张表行数，卡了十几分钟还没结束。

**原因**：16 个 `UNION ALL` 会被 Hive 拆成 **16 个独立的 MapReduce 阶段**，在 4G 内存的小集群上每个都要几十秒。

**解决**：改用 `wc -l` 直接数本地导出文件的行数（秒出），或者拆成单表查询。

**经验**：**小集群上要避免把多个子查询堆在一个 SQL 里**。能用文件级统计解决的，就别起 MR 任务。

---

### 八、ETL 执行（2 个）

#### 坑 33：`Ctrl+C` 杀不掉正在跑的 Hive 任务

**现象**：Hive CLI 前台跑 YARN 任务，按 `Ctrl+C` 无反应。

**原因**：Hive CLI 在前台等待 YARN 任务返回，信号不一定能传递到后台的 MR 任务。

**解决**：从外部杀 YARN 应用
```bash
yarn application -list
yarn application -kill application_1790304665644_0015
```
或者 `Ctrl+Z` 挂起后 `kill -9 %1`。

**经验**：**YARN 任务要用 YARN 的命令杀**，终端信号未必能穿透多层进程。这也是为什么生产上要用调度平台管理任务生命周期。

---

#### 坑 34：手动跑的 ETL 和调度平台的任务抢资源

**现象**：手动跑 `run_etl_dw.sh` 的同时在 DolphinScheduler 上执行工作流，任务一直卡在 `ACCEPTED`。

**原因**：两个任务同时抢 YARN 的 container 资源。

**解决**：**避免重复触发**。手动验证和调度执行二选一；或者给不同任务设置不同的 YARN 队列。

**经验**：**资源是有上限的**，调度平台的价值之一就是避免任务互相踩踏。生产上要配队列和优先级。

---

### 九、DolphinScheduler（7 个）

#### 坑 35：`/opt/module/dolphinscheduler` 只是个空壳目录

**现象**：`ls /opt/module/dolphinscheduler/` 只有一个 `conf/config`，没有 `bin`、`lib`、`install.sh`。

**原因**：之前只建了目录，没有真正解压安装包。而且安装包只在 102 上，103/104 没有。

**解决**：
```bash
scp /opt/software/apache-dolphinscheduler-2.0.5-bin.tar.gz hadoop103:/opt/software/
tar -zxf apache-dolphinscheduler-2.0.5-bin.tar.gz -C /opt/module/
```

**经验**：**部署前先验证安装包和解压结果的完整性**，别假设"目录在就是装好了"。

---

#### 坑 36：元数据库是空的（导入 SQL 没执行成功）

**现象**：DS 服务都显示 RUNNING，但一执行工作流就报异常。

**排查**：
```sql
SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='dolphinscheduler';
-- 返回 0
```

**原因**：之前执行的 `< dolphinscheduler_mysql.sql` 因为路径错误（文件在 103，命令在 102 执行）静默失败了。

**解决**：
```bash
scp hadoop103:/opt/module/dolphinscheduler/sql/sql/dolphinscheduler_mysql.sql /tmp/
mysql -uroot -p"$MYSQL_PASSWORD" dolphinscheduler < /tmp/dolphinscheduler_mysql.sql
-- 验证：44 张表
```

**经验**：**服务"进程在跑"不等于"服务可用"**。数据库、注册中心、依赖组件任一环节不通，进程照样能起来。**验证要看业务是否真的能跑通，不能只看进程状态**。

---

#### 坑 37：DS 服务全部启动后立刻 STOP —— 缺 MySQL 驱动

**现象**：`start-all.sh` 显示 STARTED，但 20 秒后 `status-all.sh` 全部 STOP。master 日志报：
```
java.lang.IllegalStateException: Cannot load driver class: com.mysql.jdbc.Driver
```

**原因**：DS 的 lib 目录里没有 MySQL JDBC 驱动包，连不上元数据库，Spring 容器初始化失败就退出了。

**解决**：
```bash
scp /opt/software/mysql-connector-java-8.0.30.jar hadoop103:/opt/module/ds/lib/
scp /opt/software/mysql-connector-java-8.0.30.jar hadoop104:/opt/module/ds/lib/
```

**经验**：**Spring Boot 应用连不上数据库时会直接退出**，日志里的 `Cannot load driver class` 是明确的信号。部署 Java 应用时，**驱动 jar 要确认到位**。

---

#### 坑 38：103 的 worker 报 "zookeeper connect timeout"

**现象**：master 和 api 都正常，但 103 的 worker 启动后退出，日志报 `RegistryException: zookeeper connect timeout`。

**原因**：一次性启动 6 个 JVM，机器负载瞬间拉满，worker 连 ZK 超时。

**解决**：单独重试一次即可启动成功。

**经验**：**批量启动多个 Java 服务时要有节奏**，或者错峰启动。资源紧张的机器上一个接一个起比一把梭更稳。

---

#### 坑 39：DS 默认 JVM 堆配 4G，而机器只有 4G —— 整机卡死 ⚠️

**现象（最严重的一个）**：
- master 服务启动后几秒就消失，`status` 显示 STOP
- 执行工作流报"无可用 master 节点"
- 最后**整台 103 虚拟机卡死，SSH 都连不上，只能强制重启**

**定位过程**：
```bash
# 从启动命令里发现真相
nohup java -Dlogging.config=... -Xms4g -Xmx4g -Xmn2g -server ...
```

**原因**：DolphinScheduler 2.0.5 的 `dolphinscheduler-daemon.sh` 里默认 `HEAP_OPTS="-Xms4g -Xmx4g -Xmn2g"`，**给 master 配了 4G 堆**。而虚拟机总共只有 3.8G 内存，还要跑 DataNode、NodeManager、ZK、Kafka。JVM 申请不到这么多内存，启动即被系统 OOM Killer 干掉；更糟的是内存压力把整台机器拖死。

**解决**：修改 `bin/dolphinscheduler-daemon.sh` 和 `script/dolphinscheduler-daemon.sh`：
```bash
sed -i 's/-Xms4g -Xmx4g -Xmn2g/-Xms512m -Xmx512m -Xmn256m/g' dolphinscheduler-daemon.sh
sed -i 's/-Xms1g -Xmx1g -Xmn512m/-Xms512m -Xmx512m -Xmn256m/g' dolphinscheduler-daemon.sh
sed -i 's/-Xms2g -Xmx2g -Xmn1g/-Xms512m -Xmx512m -Xmn256m/g' dolphinscheduler-daemon.sh
```

**经验（重点）**：
1. **开源组件的默认配置是按生产环境设的**，在小内存机器上必须逐个检查 JVM 参数
2. 服务"启动后立刻消失"，**第一反应应该是去看启动命令里的内存参数**，而不是只看日志尾部
3. 内存不足不仅会让服务挂掉，还可能**拖死整台机器**，排查成本极高

---

#### 坑 40：执行工作流报"无可用 master 节点"

**现象**：DS 界面上点执行，弹窗提示"无可用 master 节点"。

**原因**：master 进程已经被 OOM 杀掉（就是坑 39），没有可用的 master 来接收调度请求。

**解决**：降低 JVM 堆内存后重启，master 稳定 RUNNING，问题消失。

**经验**：**这个报错是"结果"不是"原因"**。真正的排查路径是：查 master 进程状态 → 查 master 日志 → 发现缺驱动/OOM → 解决根因。**不要停在表面报错上**。

---

### 十、Superset 可视化（9 个）

> 这一段最后**没装成**，但踩坑过程本身很有价值——它说明"依赖地狱"是真实存在的工程问题。

#### 坑 41：conda 连不上 anaconda 官方源，创建环境失败

**现象**：`conda create -n superset python=3.8` 报网络错误，`Could not find conda environment: superset`。

**解决**：**放弃创建新环境**，直接用 Miniconda 的 base 环境（Python 3.9.12），满足 Superset 1.5 的要求。

**经验**：**遇到网络受限时，先看现有环境能不能直接用**，比死磕镜像源高效。

---

#### 坑 42-50：Superset 1.5.1 的依赖地狱（9 个依赖冲突）

按踩坑顺序：

| # | 报错 | 原因 | 解决 |
|:--:|:---|:---|:---|
| 42 | `Could not find a version that satisfies celery<5.0.0` | pip 版本太新（24+）不认老包的元数据 | 降级 `pip<24.1` |
| 43 | `cannot import name 'soft_unicode' from 'markupsafe'` | MarkupSafe 2.1+ 移除了该 API | `markupsafe==2.0.1` |
| 44 | `numpy.dtype size changed` | numpy 2.x 与 pandas 1.3.4 的 ABI 不兼容 | `numpy==1.23.5` |
| 45 | `No module named 'cryptography.hazmat.backends.openssl.x509'` | cryptography 42+ 移除了旧模块路径 | `cryptography==3.4.8` |
| 46 | `TypeError: __init__() got an unexpected keyword argument 'default'` | referencing 需要 typing_extensions>=4，与 Superset 要求的 <4 冲突 | `jsonschema==3.2.0`（绕开 referencing） |
| 47 | `cannot import name 'RowProxy' from 'sqlalchemy.engine'` | SQLAlchemy 1.4 移除了 RowProxy | `SQLAlchemy==1.3.24` |
| 48 | `No module named 'pkg_resources'` | setuptools 81+ 移除了 pkg_resources | `setuptools<81` |
| 49 | `InvalidRequirement: Expected matching RIGHT_PARENTHESIS ... pytz (>dev)` | packaging 太新，解析不了老包的畸形元数据 | `packaging==21.3` |
| 50 | `cannot import name 'Unpack' from 'typing_extensions'` | cron-descriptor 新版需要 typing_extensions>=4.4，与 Superset 的 <4 冲突 | **未能解决** |

**最终结论**：`pip check` 显示 `No broken requirements found`（前 9 个冲突全部解决），但最后一个 `cron-descriptor` 形成**无解的依赖环**——它要新版 typing_extensions，Superset 1.5 要旧版，两者不可调和。**放弃 Superset，改用 ECharts 做静态可视化看板。**

**经验（这段特别值钱）**：

1. **老版本框架 + 新版本包管理器 = 依赖地狱**。Superset 1.5.1 是 2022 年的版本，官方环境是 Python 3.8 + 当时的 pip，在 Python 3.9.12 + 新 pip 上装就会出现大量传递依赖被拉到新版。
2. **不要一个个试，用 `pip check` 一次性列出所有冲突**。我前面踩了 5 个坑才想到这招，早用可以省一半时间。
3. **要懂得止损**。可视化是项目的"最后一公里"，不是核心。当投入产出比明显失衡时，**换方案比硬扛更专业**。ECharts 方案 10 分钟就交付了，效果也不差。
4. 面试时这个经历可以这样讲：**"我尝试主流 BI 工具时遇到依赖冲突，在解决 9 个冲突后判断剩余问题无解，于是切换为轻量方案，保证了项目按期交付。"**——体现的是**技术判断力和成本意识**，比"我装上了"更有说服力。

---

### 十一、资源与性能（2 个）

#### 坑 51：三台 4G 虚拟机跑不动全套组件

**现象**：内存长期吃紧，`free -h` 显示 103 可用内存只剩 53M，大量使用 swap，所有操作都变慢。

**解决**：
1. 停掉非必需服务（如 103 的 Kafka——剩两个 broker 足够，副本因子是 1）
2. 停掉用不到的服务（python-gateway-server）
3. **把所有 Java 服务的 JVM 堆调小**（DS 从 4G→512M，Kafka 默认 1G）

**经验**：**"能不能跑起来"和"能不能稳定跑"是两件事**。资源规划要在部署前就做，而不是等 OOM 了再救火。

---

#### 坑 52：集群重启后 ZK 反复"假活"

**现象**：每次重启虚拟机，102 的 ZK 都会出现 "already running as process XXX" 但 status 连不上的情况。

**原因**：非正常关机时 ZK 来不及清理 pid 文件，下次启动就被误判为"已在运行"。

**解决**：写进启动流程——**先清 pid 再启动**：
```bash
rm -f /opt/module/zookeeper-3.7.1/data/zookeeper_server.pid
zkServer.sh start
```

**经验**：**反复出现的问题要固化到启动脚本里**，而不是每次手工处理。这也是为什么要写一键启动脚本。

---

