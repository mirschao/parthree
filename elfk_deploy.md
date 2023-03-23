# ELFK部署

*author: mirschao*

*email: mirschao@gmail.com*

*github: https://github.com/mirschao*

*usage: study elk data stream*

---

参考文档:

- Kafka KRaft mode deploy: https://www.conduktor.io/kafka/how-to-install-apache-kafka-on-linux-without-zookeeper-kraft-mode/
- Elastic search deploy cluster: https://www.elastic.co/guide/en/elasticsearch/reference/current/rpm.html



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
$ mv elastic-certificates.p12 elastic-stack-ca.p12 /etc/elasticsearch/certs/
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
node.roles: [transform]
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
elasticsearch.hosts: ["http://10.9.12.61:9200"]
elasticsearch.username: 'kibana_system'
elasticsearch.password: 'Qfcloud120..'
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

$ systemctl enable --now kibana
```

做好DNS解析, 并访问 `https://kibana.hiops.icu:5601/kibana`即可访问到界面, 在界面中使用 `elastic` 用户登陆即可