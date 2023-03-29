# ELFK部署

*author: mirschao*

*email: mirschao@gmail.com*

*github: https://github.com/mirschao*

*usage: study elk data stream*

---

[TOC]

&emsp;&emsp;在日常运维过程中监控是很重要的, 监控又分为业务状态监控、日志数据监控两种, 对于日志而言可以反应出的指标就很多了, 而且日常排查问题也常常需要日志来辅助运维进行, 极其具备参考价值; 在现阶段而言ELK和Loki是两大日志收集阵容, ELK更加倾向于ECS主机的日志采集工作, 而Loki更加倾向于收集Kubernetes中pod的日志; 本篇主要介绍ELK的安装;

 ### ElasticSearch 集群部署

&emsp;&emsp;Elasticsearch是位于Elastic Stack核心的分布式搜索和分析引擎。Logstash和Beats有助于收集、聚合和丰富数据，并将其存储在Elasticsearch中。Kibana使您能够交互式地探索、可视化和共享对数据的见解，并管理和监控堆栈。Elasticsearch是索引、搜索和分析发生的地方。Elasticsearch为所有类型的数据提供近乎实时的搜索和分析。无论您是结构化还是非结构化文本、数字数据还是地理空间数据，Elasticsearch都可以以支持快速搜索的方式高效地存储和索引。您可以超越简单的数据检索和聚合信息，发现数据中的趋势和模式。随着数据和查询量的增长，Elasticsearch的分布式特性使您的部署能够无缝增长。虽然不是每个问题都是搜索问题，但Elasticsearch在各种用例中提供了处理数据的速度和灵活性：

- 将搜索框添加到应用程序或网站
- 存储和分析日志、指标和安全事件数据
- 使用机器学习实时自动建模数据的行为
- 使用Elasticsearch作为存储引擎自动化业务工作流
- 使用Elasticsearch作为地理信息系统（GIS）管理、集成和分析空间信息
- 使用Elasticsearch作为生物信息学研究工具存储和处理遗传数据



| hostname   | ipaddress  | roles        | Configure      |
| ---------- | ---------- | ------------ | -------------- |
| elastics-a | 10.9.12.51 | Master, data | 4 core 4G(RAM) |
| elastics-b | 10.9.12.52 | Master, data | 4 core 4G(RAM) |
| elastics-c | 10.9.12.53 | Master, data | 4 core 4G(RAM) |

```bash
#> install elasticserach package
$ rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
$ vim /etc/yum.repos.d/elasticsearch.repo
[elasticsearch]
name=Elasticsearch repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=0
autorefresh=1
type=rpm-md

$ yum clean all && yum makecache
$ yum install --enablerepo=elasticsearch elasticsearch
```

Or 使用下方直接下载rpm包进行安装

```bash
#> download elasticsearch package
$ wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.6.2-x86_64.rpm
$ yum -y install elasticsearch-8.6.2-x86_64.rpm
```

初始化系统配置, 为elasticsearch启动做准备

```bash
#> create initial directory (all nodes)
$ mkdir -p /data/elasticsearch/{data,logs}
$ chown -R elasticsearch:elasticsearch /data/elasticsearch

#> modify file.max & sysctl.conf (all nodes)
$ vim /etc/security/limits.conf
* soft nproc 131072
* hard nproc 131072
* soft nofile 131072
* hard nofile 131072

$ vim /etc/sysctl.conf
vm.max_map_count = 262144
$ sysctl -p

#> generated certs (only elastics-a)
$ /usr/share/elasticsearch/bin/elasticsearch-certutil ca      # 一直回车即可, 下同!
$ /usr/share/elasticsearch/bin/elasticsearch-certutil cert --ca /usr/share/elasticsearch/elastic-stack-ca.p12
$ /usr/share/elasticsearch/bin/elasticsearch-keystore create

#> transfer certs to location (only elastics-a)
$ cd /usr/share/elasticsearch/
$ cp elastic-certificates.p12 elastic-stack-ca.p12 /etc/elasticsearch/certs/
$ scp elastic-certificates.p12 elastic-stack-ca.p12 root@10.9.12.52:/etc/elasticsearch/certs/
$ scp elastic-certificates.p12 elastic-stack-ca.p12 root@10.9.12.53:/etc/elasticsearch/certs/
$ scp /etc/elasticsearch/elasticsearch.keystore root@10.9.12.52:/etc/elasticsearch/
$ scp /etc/elasticsearch/elasticsearch.keystore root@10.9.12.53:/etc/elasticsearch/

$ chown -R elasticsearch:elasticsearch /etc/elasticsearch/  # 每个节点都要执行

#> modify configure files (all nodes)
$ egrep -v "(^$|^#)" /etc/elasticsearch/elasticsearch.yml
cluster.name: logging
node.name: elastics-a      #这里注意要修改, 每个节点都是不一致的
node.roles: [master,data]
path.data: /data/elasticsearch/data
path.logs: /data/elasticsearch/logs
network.host: 0.0.0.0
http.port: 9200
http.cors.enabled: true
http.cors.allow-origin: '*'
discovery.seed_hosts: ["10.9.12.51:9300", "10.9.12.52:9300", "10.9.12.53:9300"]
cluster.initial_master_nodes: ["10.9.12.51:9300", "10.9.12.52:9300", "10.9.12.53:9300"]
xpack.security.enabled: true
xpack.security.transport.ssl:
  enabled: true
  verification_mode: none
  keystore.path: certs/elastic-certificates.p12
  truststore.path: certs/elastic-certificates.p12
http.host: 0.0.0.0

#> modify JVM configure (all nodes)
$ vim /etc/elasticsearch/jvm.options
-Xms4g
-Xmx4g
```

启动服务, 验证配置是否能够正常启动, 依次启动每个节点即可

```bash
$ systemctl enable --now elasticsearch
```

配置elasticsearch集群中的认证账号的密码, 依次进行设定即可

```bash
$ /usr/share/elasticsearch/bin/elasticsearch-setup-passwords interactive
Enter password for [elastic]:
Enter password for [elastic]: 
Reenter password for [elastic]: 
Enter password for [apm_system]: 
Reenter password for [apm_system]: 
Enter password for [kibana_system]: 
Reenter password for [kibana_system]: 
Enter password for [logstash_system]: 
Reenter password for [logstash_system]: 
Enter password for [beats_system]: 
Reenter password for [beats_system]: 
Enter password for [remote_monitoring_user]: 
Reenter password for [remote_monitoring_user]: 
Changed password for user [apm_system]
Changed password for user [kibana_system]
Changed password for user [kibana]
Changed password for user [logstash_system]
Changed password for user [beats_system]
Changed password for user [remote_monitoring_user]
Changed password for user [elastic]
```

使用浏览器或者curl验证集群正确性及是否组建成功

```bash
$ curl -u elastic:xxxxxx http://10.9.12.51:9200/_cat/health?v
```



### Kibana可视化观测平台

&emsp;&emsp;Kibana 是一个免费且开放的用户界面, 能够让您对 Elasticsearch 数据进行可视化, 并让您在 Elastic Stack 中进行导航. 您可以进行各种操作, 从跟踪查询负载, 到理解请求如何流经您的整个应用都能轻松完成. Kibana 核心产品搭载了一批经典功能：柱状图、线状图、饼图、旭日图等等。当然，您还可以搜索自己的所有文档。借助我们精选的时序数据 UI，对您 Elasticsearch 中的数据执行高级时间序列分析。您可以利用功能强大、简单易学的表达式来描述查询、转换和可视化。

- 搜索、观察和保护您的数据。从发现文档到分析日志再到发现安全漏洞，Kibana是您访问这些功能和更多功能的门户。
- 分析您的数据。搜索隐藏的见解，可视化您在图表、仪表、地图、图表等中发现的内容，并将它们组合到仪表板中。
- 管理、监控和保护弹性堆栈。管理数据，监控Elastic Stack集群的运行状况，并控制哪些用户可以访问哪些功能。



| hostname         | ipaddress  | roles  | Configure      |
| ---------------- | ---------- | ------ | -------------- |
| kibana-transform | 10.9.12.61 | Kibana | 2 core 2G(RAM) |

```bash
#> install kibana package
$ rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
$ vim /etc/yum.repos.d/kibana.repo
[kibana-8.x]
name=Kibana repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md

$ yum -y install kibana
```

Or 使用下方直接下载rpm包进行安装

```bash
$ wget https://artifacts.elastic.co/downloads/kibana/kibana-8.6.2-x86_64.rpm
$ yum -y install kibana-8.6.2-x86_64.rpm
```

 如果 Elasticsearch 集群有多个节点，分发 Kibana 节点之间请求的最简单的方法就是在 Kibana 机器上运行一个 Elasticsearch *协调（Coordinating only node）* 的节点。Elasticsearch 协调节点本质上是智能负载均衡器，也是集群的一部分，如果有需要，这些节点会处理传入 HTTP 请求，重定向操作给集群中其它节点，收集并返回结果。

```bash
$ wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.6.2-x86_64.rpm
$ yum -y install elasticsearch-8.6.2-x86_64.rpm

#> transfer elasticsearch certs
$ scp root@10.9.12.51:/etc/elasticsearch/certs/elastic-certificates.p12 /etc/elasticsearch/certs/
$ scp root@10.9.12.51:/etc/elasticsearch/certs/elastic-stack-ca.p12 /etc/elasticsearch/certs/
$ scp root@10.9.12.51:/etc/elasticsearch/elasticsearch.keystore /etc/elasticsearch/
$ chown -R elasticsearch:elasticsearch /etc/elasticsearch/

#> modify elasticsearch configure file
$ egrep -v "(^$|^#)" /etc/elasticsearch/elasticsearch.yml
cluster.name: logging
node.name: kibana-transform
node.roles: [ ]
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
network.host: 0.0.0.0
http.port: 9200
http.cors.enabled: true
http.cors.allow-origin: '*'
discovery.seed_hosts: ["10.9.12.51:9300", "10.9.12.52:9300", "10.9.12.53:9300"]
xpack.security.enabled: true
xpack.security.enrollment.enabled: true
xpack.security.transport.ssl:
  enabled: true
  verification_mode: none
  keystore.path: certs/elastic-certificates.p12
  truststore.path: certs/elastic-certificates.p12
http.host: 0.0.0.0

$ vim /etc/elasticsearch/jvm.options
-Xms4g
-Xmx4g
$ systemctl enable --now elasticsearch

#> modify kibana configure file
$ egrep -v "(^$|^#)" /etc/kibana/kibana.yml
server.port: 5601
server.host: "10.9.12.61"
server.basePath: "/kibana"
server.rewriteBasePath: true
server.publicBaseUrl: "https://kibana.hiops.icu/kibana"
server.ssl.enabled: true
server.ssl.certificate: /etc/kibana/certs/fullchain1.pem
server.ssl.key: /etc/kibana/certs/privkey1.pem
elasticsearch.hosts: ["http://localhost:9200"]
elasticsearch.username: 'kibana_system'
elasticsearch.password: 'xxxxxx'
logging:
  appenders:
    file:
      type: file
      fileName: /var/log/kibana/kibana.log
      layout:
        type: json
  root:
    appenders:
      - default
      - file
path.data: /data/kibana/data
pid.file: /run/kibana/kibana.pid
i18n.locale: "zh-CN"

$ chown -R kibana:kibana /data/kibana/
$ chown -R kibana:kibana /etc/kibana/certs/
$ systemctl enable --now kibana
```

做好DNS解析, 并访问 `https://kibana.hiops.icu:5601/kibana`即可访问到界面, 在界面中使用 `elastic` 用户登陆即可



### Kafka高性能消息队列

&emsp;&emsp;在数据事件流方面，Apache Kafka 是事实上的标准。它是一个由服务器和客户端组成的开源分布式系统。Apache Kafka 主要用于构建实时数据流管道。使用 Apache Kafka 作为数据集成层，数据源会将其数据发布到 Apache Kafka，而目标系统将从 Apache Kafka 获取数据。这分离了源数据流和目标系统，允许简化数据集成解决方案。现代应用程序包括数以万计的微服务——所有这些都不断地产生日志。这些日志充满了可用于商业智能、故障预测和调试的信息。接下来的挑战是如何处理在一个地方产生的这些大量日志数据。公司将日志数据推送到数据流中以进行流处理

<img src="https://www.conduktor.io/_next/image/?url=https%3A%2F%2Fimages.ctfassets.net%2Fo12xgu4mepom%2F36HRcNifBz55AUvkBs1p9x%2F31af23c93be2c7b0d1233a3f9f8797e5%2FWhat_is_Apache_Kafka_Part_1_-_Decoupling_Different_Data_Systems.png&w=3840&q=75" alt="kafka-arch" style="zoom: 25%;" />



| hostname      | ipaddress  | roles | Configure      |
| ------------- | ---------- | ----- | -------------- |
| kafka-queue-a | 10.9.12.62 | queue | 2 core 4G(RAM) |
| kafka-queue-b | 10.9.12.63 | queue | 2 core 4G(RAM) |

```bash
#> deploy java environment
$ yum -y install java-11-openjdk

#> download kafka package
$ wget https://archive.apache.org/dist/kafka/3.0.0/kafka_2.13-3.0.0.tgz

#> deploy kafka
$ tar xf kafka_2.13-3.0.0.tgz -C /usr/local/
$ cd /usr/local/kafka_2.13-3.0.0/
$ bin/kafka-storage.sh random-uuid
ZfqgKzrHR1SqbBwOr3Iolw

$ egrep -v "(^$|^#)" config/kraft/server.properties
process.roles=broker,controller
node.id=1 # 每个节点的id不同
controller.quorum.voters=1@10.9.12.62:9093,2@10.9.12.63:9093 # {id}@{ipaddress}:{port} 节点间用逗号分隔
listeners=PLAINTEXT://:9092,CONTROLLER://:9093
inter.broker.listener.name=PLAINTEXT
advertised.listeners=PLAINTEXT://10.9.12.62:9092 # 当前节点的IP地址
controller.listener.names=CONTROLLER
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
log.dirs=/tmp/kraft-combined-logs
num.partitions=1
num.recovery.threads.per.data.dir=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000

$ bin/kafka-storage.sh format -t ZfqgKzrHR1SqbBwOr3Iolw -c config/kraft/server.properties
Formatting /tmp/kraft-combined-logs

$ bin/kafka-server-start.sh config/kraft/server.properties
```

在测试能够正常启动后, 将上方进程放入到systemd中进行管理

```bash
$ vim /usr/lib/systemd/system/kafka.service
[Unit]
Description=kafka
Before=network-pre.target
Wants=network-pre.target

[Service]
ExecStart=/usr/local/kafka_2.13-3.0.0/bin/kafka-server-start.sh /usr/local/kafka_2.13-3.0.0/config/kraft/server.properties
ExecReload=/bin/kill -HUP $MAINPID
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target

$ systemctl daemon-reload
$ systemctl enable --now kafka
```

测试kafka服务是否能够正常写入topic

```bash
$ bin/kafka-topics.sh --create \
--replication-factor 1 \
--partitions 1 \
--topic test \
--bootstrap-server 10.9.12.62:9092
Created topic test.
```



### logstash日志管道

&emsp;&emsp;Logstash 是一个具有实时流水线功能的开源数据收集引擎。Logstash 可以动态统一来自不同来源的数据，并将数据规范化到您选择的目的地。为各种高级下游分析和可视化用例清理和民主化您的所有数据。虽然 Logstash 最初推动了日志收集方面的创新，但其功能远远超出了该用例。任何类型的事件都可以通过广泛的输入、过滤器和输出插件进行丰富和转换，许多本机编解码器进一步简化了摄取过程。Logstash 通过利用更大量和更多样化的数据来加速您的洞察力

| hostname             | ipaddress  | roles    | Configure      |
| -------------------- | ---------- | -------- | -------------- |
| logstash-pipeline-01 | 10.9.12.64 | logstash | 2 core 4G(RAM) |
| logstash-pipeline-02 | 10.9.12.65 | logstash | 2 core 4G(RAM) |

```bash
$ rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
$ vim /etc/yum.repos.d/logstash.repo
[logstash-8.x]
name=Elastic repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md

$ yum -y install logstash
```

Or 下载logstash的rpm进行安装

```bash
$ wget https://artifacts.elastic.co/downloads/logstash/logstash-8.6.2-x86_64.rpm
$ yum -y install logstash-8.6.2-x86_64.rpm
```

增加管道配置文件, 作为Kafka的消费者, 这里简单的使用输入和输出作为logstash的管道, 也可以加入filter进行过滤, 但需要准备很多基础的正则表达式知识, 在后续的文件中会有介绍;

```bash
$ vim /etc/logstash/conf.d/currency.conf
input {
  kafka {
    bootstrap_servers => "10.9.12.62:9092,10.9.12.63:9092"
    auto_offset_reset => "latest"
    group_id => "currencys"
    topics => ["currency"]
    codec => "json"
  }
}

output {
  elasticsearch {
    hosts => ["http://10.9.12.51:9200", "http://10.9.12.52:9200", "http://10.9.12.53:9200"]
    user => "elastic"
    password => "xxxxxx"
    index => "currency-%{+YYYY.MM.dd}"
  }
}
```

```bash
$ systemctl daemon-reload
$ systemctl enable --now logstash
```



### filebeat 数据采集端

&emsp;&emsp;Filebeat 是用于转发和集中日志数据的轻量级托运器。作为代理安装在您的服务器上，Filebeat 监控您指定的日志文件或位置，收集日志事件，并将它们转发到[Elasticsearch](https://www.elastic.co/products/elasticsearch)或 [Logstash](https://www.elastic.co/products/logstash)以进行索引。

Filebeat 的工作原理如下：当您启动 Filebeat 时，它会启动一个或多个输入，这些输入会查找您为日志数据指定的位置。对于 Filebeat 找到的每个日志，Filebeat 都会启动一个收割机。每个采集器读取单个日志以获取新内容并将新日志数据发送到 libbeat，后者聚合事件并将聚合数据发送到您为 Filebeat 配置的输出。

<img src="https://www.elastic.co/guide/en/beats/filebeat/current/images/filebeat.png" alt="filebeat-arch" style="zoom:50%;" />

```bash
#> 准备被采集日志的服务, 这里用nginx作为被采集服务
$ cat <<-EOF >/etc/yum.repos.d/nginx.repo
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF

$ yum clean all && yum makecache
$ yum -y install nginx
$ systemctl enable --now nginx
```

&emsp;&emsp;安装filebeat采集工具, 这里采用yum的方式进行安装; 后续如果机器多的情况下可以使用ansible批量安装, 但要考虑到logstash的topic是否与filebeat匹配的问题, kafka作为中间的队列服务所产生的topic由filebeat决定;

```bash
$ rpm --import https://packages.elastic.co/GPG-KEY-elasticsearch
$ vim /etc/yum.repos.d/filebeat.repo
[elastic-8.x]
name=Elastic repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md

$ yum makecache
$ yum -y install filebeat
$ systemctl enable --now filebeat
```

&emsp;&emsp;配置采集 nginx 服务器的日志, 并设定filebeat配置文件的采集源(/var/log/nginx/access.log)及输送源(Kafka), 这里filebeat使用单一的日志源作为采集源, 也可以使用正则表达式的方式来匹配不同类型、不同虚拟主机的日志, 同样的Kafka的topic也可以自动的生成对应的topic从而再经过配置logstash来输送数据到elasticsearch中进行存储

```bash
$ vim /etc/filebeat/filebeat.yml
filebeat.inputs:
 - type: log
   tail_files: true
   backoff: "1s"
   paths:
      - /var/log/nginx/access.log

output:
  kafka:
    hosts: ["10.9.12.62:9092", "10.9.12.63:9092"]
    topic: currency

$ egrep -v "(^$|^#|#)" /etc/filebeat/filebeat.yml
filebeat.inputs:
- type: log
  tail_files: true
  backoff: "1s"
  id: nginx-logstream-access
  enabled: true
  paths:
    - /var/log/nginx/access.log
filebeat.config.modules:
  path: ${path.config}/modules.d/*.yml
  reload.enabled: false
setup.template.settings:
  index.number_of_shards: 1
setup.kibana:
output:
  kafka:
    hosts: ["10.9.12.62:9092", "10.9.12.63:9092"]
    topic: currency
processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded
  - add_cloud_metadata: ~
  - add_docker_metadata: ~
  - add_kubernetes_metadata: ~

$ systemctl enable --now filebeat
```

