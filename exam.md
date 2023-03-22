# 云计算Ansible科目考试(时间 120min)(及格分75)



### 简答题(每题6分, 尽量写具体, 不写全, 分全扣!!!)

1. 你常用的Ansible模块有哪些？(至少写出5个, 并写出其用法)
2. Ansible最多控制多少台机器？
3. 请写出使用ansible传输文件test.txt到agent组中所有主机的 Ad-Hoc 指令
4. 请写出使用ansible安装nginx以及启动nginx服务的Ad-Hoc指令
5. 请写出使用ansible将test.j2到agent组中所有主机的Ad-Hoc指令, 并且传送到目标主机的test.txt文件内容随着注入的变量而变化
6. 请写出ansible如何查询 uri 模块用法的指令
7. 请描述出使用剧本安装zabbix-agent的思路
8. 请写出使用ansible远程执行脚本abc.sh的Ad-Hoc指令, 并设置执行并发量为10
9. 请写出免密交互的ssh认证主机的脚本
10. 如何检查playbook.yaml的语法是否正确, 写出具体命令



### 面试题(每题5分, 尽量写具体, 不写全, 分全扣!!!)

1. 使用playbook剧本, 完成对 `epel-release`、`net-tools`、`vim`、`screen` 进行安装, 要求使用 with_items 循环完成
2. 请写出获取centos操作系统中, CPU使用率、Memory使用率、disk使用率的shell指令, 必须写全
3. 请写出如何探测 `www.baidu.com`、`www.sina.com`、`www.hiops.icu`这三个域名首页可用性的playbook剧本
4. 请写出如何执行playbook中某个task的指令, 并写出如何设置或如何编写的playbook剧本
5. 请写出如何在agent组中所有机器上, 安装filebeat的playbook剧本
6. 请写出ansible配置文件的优先级顺序
7. 请写出在hosts主机清单文件中, 如何将 `192.168.17.2` 、`192.168.17.3`、`192.168.17.4` 写成一行进行表示
8. 请写出在agent组中所有主机上 卸载 `epel-release`、`net-tools`、`vim`、`screen` 这几个软件的剧本, 要求使用 with_items
