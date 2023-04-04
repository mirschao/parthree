# 云计算ELK科目考试(时间 120min)(及格分75)



### 简答题(每题6分, 尽量写具体, 不写全, 分全扣!!!)

1. 请详细描述出ELK(filebeat, logstash, elasticsearch, Kafka, Kibana)的日志数据流向(不接受草图)
2. elasticsearch中节点角色都有哪些? 分别有什么作用？
3. 请详细描述kibana机器中为什么需要一个elastic的负载均衡角色？该角色的配置为?
4. Kafka中的topic是什么意思？有什么意义？起到的作用是什么？
5. logstash的配置中如何将接收到的数据进行格式化？
6. 如何将filebeat批量安装到100台机器中, 并且100台机器有不同的业务(请考虑全面)
7. Kraft在Kafka集群中的作用是什么？使用它能带来什么好处？
8. 日常接收到报警后, 在kibana中要查看实时日志, 应该到kibana中的哪个板块中进行查看？(写出菜单的名称)
9. elasticsearch在组件集群的过程中为什么需要证书？
10. 请写出kafka、elasticsearch、logstash、kibana的默认服务端口？



### 面试题(每题5分, 尽量写具体, 不写全, 分全扣!!!)

1. 你创建过什么dashboard图像？
2. filebeat如何采集单机中的多个日志文件中的数据？请写出简要的配置项
3. 如何使用ansible批量的增加多台相同业务的filebeat的配置(假设业务为business)
4. 简要阐述filebeat使用pipeline的路数(过程一定要叙述完整)
5. logstash的grok中, 过滤 时间戳、IP地址、用户agent、请求方法、请求uri、请求url 分别用哪些正则别名进行匹配
6. 如果要增加自定义的grok正则表达式 文件, 应当如何进行增加？(写出具体的步骤)
7. 什么时候记录日志？以及日志的价值？
8. 日志和ELK什么关系？