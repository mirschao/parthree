# Ansible课程笔记

*author: mirschao*

*email: mirschao@gmail.com*

*github: https://github.com/mirschao*

*target: Proficient in Ansible's deployment of services and role organization of projects*

---

&emsp;&emsp;Ansible 是运维人员的一把趁手的利器, 对于批量(001~499)机器的运维任务、日常巡检、agent程序部署等工作均有良好的性能表现及便利性; 相较于老牌批量运维工具Puppet、SaltStack等不一样的点在于其<u>无客户端程序</u>而转投使用SSH协议的方式来控制其目标机器来完成工作任务; 

&emsp;&emsp;在开始学习Ansible之前理解其如何通过SSH与远程服务器连接是很重要的; 在正常的运维过程中大多使用终端软件来连接远程机器, 终端软件与远程服务器之间采用的就是SSH协议进行连接的, 终端软件中内置了SSH客户端程序以此链接服务端的OpenSSH服务, 当然底层也是经过了TCP三次握手的; SSH协议帮助我们将终端软件输入的命令发送到远程服务器去执行, 以此就完成了对远程服务器的控制工作; ansible实际上就是在Linux主机中调用SSH去链接到远程服务器, 后续通过SSH协议将要执行的指令发送到远程机器去执行, 从而完成对远程主机的控制; 但值得注意的是ansible要求SSH协议对远程主机的控制是免密的, 所以要事先将ansible主机的密钥认证到要控制的主机中, 所以编写自动推送密钥的脚本还是很重要的;

&emsp;&emsp;统一下概念: 安装有ansible的机器叫做<u>控制端</u>; 被管理或执行任务的机器叫做<u>被控端</u>; ansible是由python写的程序所以需要有python环境在控制端(要求python version 2.7+);

---

[TOC]

## 一、构建Ansible的执行环境

&emsp;&emsp;值得说明的是Ansible在控制端, 在安装时需要`epel-release`来支持安装; 所以配置好安装源是很重要的; 章节中所有的实验系统均采用`CentOS Stream 9`来进行, 配置2c 2g 20G; 注意所准备的机器均采用静态IP地址, 且能相互进行通信;

| 端点 node         | IP地址 ipaddress | 操作系统 operating system | 配置 configure |
| ----------------- | ---------------- | ------------------------- | -------------- |
| 控制端 controller | 192.168.108.11   | CentOS Stream 9           | 2c 2g 20G      |
| 被控端 target     | 192.168.108.21   | CentOS Stream 9           | 1c 1g 20G      |
| 被控端 target     | 192.168.108.22   | CentOS Stream 9           | 1c 1g 20G      |
| 被控端 target     | 192.168.108.23   | CentOS Stream 9           | 1c 1g 20G      |

```bash
##>> 安装epel扩展源到 控制端
$ yum -y install epel-release
$ yum makecache

##>> 安装ansible到 控制端
$ yum -y install ansible
$ ansible --version
ansible [core 2.14.2]
  config file = /etc/ansible/ansible.cfg
  module path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3.11/site-packages/ansible
  ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
  executable location = /usr/bin/ansible
  python version = 3.11.2 [GCC 11.3.1 20221121 (Red Hat 11.3.1-4)] (/usr/bin/python3.11)
  jinja version = 3.1.2
  libyaml = True
```

```bash
##>> 克隆仓库获取脚本等学习资料
$ git clone https://github.com/mirschao/parthree.git
$ cd parthree
$ git branch feature/ansible

##>> 增加被控主机配置, 注意下方格式不要变化,不要加引号等特殊字符
$ vim initials/transfer_key_config.ini
[machines]
agent1 = 10.9.12.xx
agent2 = 10.9.12.xx
agent3 = 10.9.12.xx
[machines:vars]
remote_user = root
password = xxxxxxxx

##>> 执行脚本 由 控制端 向 被控端 传送公钥
$ bash transfer_key.sh
```

&emsp;&emsp;在安装以及初始化控制端及受控端后, 就可以开心的使用ansible控制受控端主机了, 对受控端的任务编排可以采用Ad-Hoc、playbook两种方式, Ad-Hoc经常被用来执行一些临时性的批量任务, 而固化为playbook剧本的任务通常具备长期、重复的上线任务或着节前巡检任务; 工作场景中playbook出现的身影占据90%;

&emsp;&emsp;在学习过程中, Ad-Hoc是被用来熟悉ansible中的模块用法来使用的,  ansible本身是一个具备很多母插槽的框架, 真正完成工作任务的是ansible中的众多插件模块; playbook是学习的重点内容, 尤其是在熟悉了各个模块的情况下如何使用模块完成既定需求, 也就是YAML剧本的编写, 这里给大家的建议就是大量的编写playbook;

&emsp;&emsp;在使用ansible之前先来了解一下ansible在使用过程过程中涉及到的周边衍生文件:

- hosts: 用于指定受控端主机的IP地址列表
- ansible.cfg: 配置文件, 对ansible的基本配置、调优等均来自于此
- ansible-doc -s \<MODULE_NAME\>: 用于输出对应模块的帮助信息及关键参数的帮助信息



