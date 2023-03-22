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

## 一、Ansible的执行环境

&emsp;&emsp;值得说明的是Ansible在控制端, 在安装时需要`epel-release`来支持安装; 所以配置好安装源是很重要的; 章节中所有的实验系统均采用`CentOS Stream 9`来进行, 配置2c 2g 20G; 注意所准备的机器均采用静态IP地址, 且能相互进行通信;

| 端点 node         | IP地址 ipaddress | 操作系统 operating system | 配置 configure |
| ----------------- | ---------------- | ------------------------- | -------------- |
| 控制端 controller | 10.9.12.241      | CentOS Stream 9           | 2c 2g 20G      |
| 被控端 target     | 10.9.12.231      | CentOS Stream 9           | 1c 1g 20G      |
| 被控端 target     | 10.9.12.232      | CentOS Stream 9           | 1c 1g 20G      |
| 被控端 target     | 10.9.12.233      | CentOS Stream 9           | 1c 1g 20G      |

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
agent1 = 10.9.12.231
agent2 = 10.9.12.232
agent3 = 10.9.12.233
[machines:vars]
remote_user = root
password = xxxxxxxx  # (替换成你自己的密码)

##>> 执行脚本 由 控制端 向 被控端 传送公钥
$ bash transfer_key.sh
```

### 1.1 配置控制端环境

&emsp;&emsp;在安装以及初始化控制端及受控端后, 就可以开心的使用ansible控制受控端主机了, 对受控端的任务编排可以采用Ad-Hoc、playbook两种方式, Ad-Hoc经常被用来执行一些临时性的批量任务, 而固化为playbook剧本的任务通常具备长期、重复的上线任务或着节前巡检任务; 工作场景中playbook出现的身影占据90%;

&emsp;&emsp;在学习过程中, Ad-Hoc是被用来熟悉ansible中的模块用法来使用的,  ansible本身是一个具备很多母插槽的框架, 真正完成工作任务的是ansible中的众多插件模块; playbook是学习的重点内容, 尤其是在熟悉了各个模块的情况下如何使用模块完成既定需求, 也就是YAML剧本的编写, 这里给大家的建议就是大量的编写playbook;

&emsp;&emsp;在使用ansible之前先来了解一下ansible在使用过程过程中涉及到的周边衍生文件:

- hosts: 用于指定受控端主机的IP地址列表, 也称之为主机清单
- ansible.cfg: 配置文件, 对ansible的基本配置、调优等均来自于此

```bash
##>> 创建ansible任务目录
$ mkdir -p /srv/apps/ansible/{adhocs,playbooks}

##>> 在adhocs目录中创建主机清单
$ vim /srv/apps/ansible/adhocs/hosts
[targetname]
10.9.12.231
10.9.12.232
10.9.12.233
# 10.9.12.23[1:3] # 上方三个IP地址可以简写成左侧的方式
[targetname:vars]
ansible_ssh_user=root
ansible_ssh_port=22
# ansible_ssh_private_key_file=/path/to/file  # 当且仅当私钥文件名称和位置不为 ~/.ssh/id_rsa 时使用

##>> 编写ansible.cfg配置文件, 完善ansible的配配置, 在adhocs目录中创建主机清单
##>> ansible.cfg文件在系统中是具备匹配顺序的(当然SuperBest都知道找不到会报错!)
###>>> 1.根据ANSIBLE_CONFIG环境变量设置的路径查找ansible.cfg配置文件
###>>> 2.在执行ansible命令的目录中寻找ansible.cfg配置文件
###>>> 3.在执行ansible指令的用户家目录中寻找 ~/.ansible.cfg 隐藏文件
###>>> 4.查找/etc/ansible/ansible.cfg配置文件
$ ansible-config init --disabled >/srv/apps/ansible/adhocs/ansible.cfg
##>> 修改配置文件中的寻找配置文件位置及资源清单位置
$ sed -i 's#;home=~/.ansible#home=/srv/apps/ansible/adhocs#' ansible.cfg
$ sed -i 's#;inventory=/etc/ansible/hosts#inventory=/srv/apps/ansible/adhocs/hosts#' ansible.cfg

##>> 使用ansible中的ping模块测试一下主机清单中的机器是否能够正常通信
$ cd /srv/apps/ansible/adhocs
$ ansible all -m ping
10.9.12.231 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
10.9.12.233 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
10.9.12.232 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```

### 1.2 受控端SSH协议调优

&emsp;&emsp;由于Ansible基于SSH协议通信, SSH连接慢会导致整个基于Ansible执行变得缓慢; 对于受控端来说, 与控制端的链接速度和时效以及延迟都是要考量的重点内容, 那么对于受控端机器的SSH调优就成了必要的设置项了;对于SSH协议来说调整的是`openssh`服务, 配置文件位置在`/etc/ssh/sshd_config`;

```bash
##>> 控制端及受控端均需配置
$ vim /etc/ssh/sshd_config
UseDNS no									# 不使用DNS PTR反向解析
GSSAPIAuthentication no   # 不使用密钥GSS API验证
$ systemctl restart sshd

##>> 如果ansible以root登录, 在受控端的 /root/.ssh/config 文件中添加以下代码:
$ vim /root/.ssh/config
HOST *
  Compression yes             # 是否压缩会话
  ServerAliveInterval 60　　　 # 60s之内没有操作就会断开
  ServerAliveCountMax 5　　    # 最大5个连接
  ControlMaster auto　　　　　　# 开启长链接
  ControlPath ~/.ssh/sockets/ % r@ % h- %p　　# 会话文件路径
  ControlPersist 4h　　　　　　 # 断开连接, 会话文件保持4个小时
```



## 二、Ansible命令模式及模块

&emsp;&emsp;Ad-Hoc模式经常被用来执行一些临时性的任务, 掌握Ad-Hoc模式的指令和应用命令模式的模块, 是通往编写playbook剧本的必经之路; 对于Ad-Hoc而言要学习的模块有copy、template、service等基本模块; 本章学习目标为: 熟练使用ansible-doc指令查看模块帮助信息、熟练使用ansible-doc指令学习模块的使用、熟练使用所学模块;

```bash
##>> 用于查看模块的名称
$ ansible-doc --list | grep <LEVEL[builtin or community] or MODULE_NAME>

##>> 用于查看某个模块的帮助
$ ansible-doc -s <MODULE_NAME>
```

### 2.1 ansible常用模块解析

&emsp;&emsp;在日常对Linux系统的运维过程中, 会涉及到服务的安装、文件的传输、文件的下载、文件的解压、进程的控制、执行脚本等常见操作及配置, 熟练掌握它们是日常提高效率的必备工具;

```bash
##>> 文件的传输 copy
$ mkdir -p /srv/apps/ansible/adhocs/study_modules
$ cd /srv/apps/ansible/adhocs/study_modules
$ vim hello_ansible.txt
hello ansible

$ ansible -i ../hosts all -m copy -a "src=hello_ansible.txt dest=/tmp/hello_ansible.txt"
10.9.12.233 | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": true,
    "checksum": "df800445bb74b4abb144b3f9bf03f90aa9618f4c",
    "dest": "/tmp/hello_ansible.txt",
    "gid": 0,
    "group": "root",
    "md5sum": "f61d358bbdd6a9bd2e93322023a4e29d",
    "mode": "0644",
    "owner": "root",
    "secontext": "unconfined_u:object_r:admin_home_t:s0",
    "size": 14,
    "src": "/root/.ansible/tmp/ansible-tmp-1679282085.9723966-14293-182503533489376/source",
    "state": "file",
    "uid": 0
}
10.9.12.232 | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": true,
    "checksum": "df800445bb74b4abb144b3f9bf03f90aa9618f4c",
    "dest": "/tmp/hello_ansible.txt",
    "gid": 0,
    "group": "root",
    "md5sum": "f61d358bbdd6a9bd2e93322023a4e29d",
    "mode": "0644",
    "owner": "root",
    "secontext": "unconfined_u:object_r:admin_home_t:s0",
    "size": 14,
    "src": "/root/.ansible/tmp/ansible-tmp-1679282085.9960058-14292-228524163572507/source",
    "state": "file",
    "uid": 0
}
10.9.12.231 | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": true,
    "checksum": "df800445bb74b4abb144b3f9bf03f90aa9618f4c",
    "dest": "/tmp/hello_ansible.txt",
    "gid": 0,
    "group": "root",
    "md5sum": "f61d358bbdd6a9bd2e93322023a4e29d",
    "mode": "0644",
    "owner": "root",
    "secontext": "unconfined_u:object_r:admin_home_t:s0",
    "size": 14,
    "src": "/root/.ansible/tmp/ansible-tmp-1679282085.9811597-14291-155975574044952/source",
    "state": "file",
    "uid": 0
}
###>>> 验证并查看结果
$ ansible -i ../hosts all -m shell -a "ls -l /tmp/hello_ansible.txt"
10.9.12.232 | CHANGED | rc=0 >>
-rw-r--r--. 1 root root 14 Mar 20 11:14 /tmp/hello_ansible.txt
10.9.12.231 | CHANGED | rc=0 >>
-rw-r--r--. 1 root root 14 Mar 20 11:14 /tmp/hello_ansible.txt
10.9.12.233 | CHANGED | rc=0 >>
-rw-r--r--. 1 root root 14 Mar 20 11:14 /tmp/hello_ansible.txt
```

```bash
$ mkdir -p /srv/apps/ansible/adhocs/study_modules
$ cd /srv/apps/ansible/adhocs/study_modules

##>> 文件的传输 template, 可以建立模版配置文件, 在文件中使用 {{ VARIABLE }} 来调用定义的变量
$ vim ansible_vars.j2
hello {{ VARIABLE }} value!

$ ansible -i ../hosts all -e VARIABLE="Ansible" -m template -a "src=ansible_vars.j2 dest=/tmp/ansible_vars.txt"

###>>> 验证并查看结果
$ ansible -i hosts all -m shell -a "cat /tmp/hello_ansible_vars.txt"
10.9.12.232 | CHANGED | rc=0 >>
hello Ansible
10.9.12.233 | CHANGED | rc=0 >>
hello Ansible
10.9.12.231 | CHANGED | rc=0 >>
hello Ansible
```

```bash
##>> 在ansible中可以使用get_url模块来下载互联网中的文件到对应的目录中, 像极了copy和template, 但是却从外部获取文件
$ mkdir -p /srv/apps/ansible/adhocs/study_modules
$ cd /srv/apps/ansible/adhocs
$ ansible -i hosts all -m get_url -a "url=https://mirrors.hiops.icu/packages/Python-3.11.2.tar.xz dest=/tmp/Python-3.11.2.tar.xz validate_certs=false"

###>>> 验证下载文件是否存在
$ ansible -i hosts all -m shell -a "ls -l /tmp"
10.9.12.232 | CHANGED | rc=0 >>
total 19436
-rw-r--r--. 1 root root 19893284 Mar 20 13:23 Python-3.11.2.tar.xz
10.9.12.231 | CHANGED | rc=0 >>
total 19436
-rw-r--r--. 1 root root 19893284 Mar 20 13:23 Python-3.11.2.tar.xz
10.9.12.233 | CHANGED | rc=0 >>
total 19436
-rw-r--r--. 1 root root 19893284 Mar 20 13:23 Python-3.11.2.tar.xz
```

```bash
##>> 将下载下来的包进行解压
$ ansible -i hosts all -m unarchive -a "remote_src=true src=https://mirrors.hiops.icu/packages/Python-3.11.2.tar.xz dest=/opt validate_certs=false"

$ ansible -i hosts all -m shell -a "ls -l /opt"
10.9.12.233 | CHANGED | rc=0 >>
total 4
drwxr-xr-x. 16 admin admin 4096 Feb  7 21:52 Python-3.11.2
10.9.12.231 | CHANGED | rc=0 >>
total 4
drwxr-xr-x. 16 admin admin 4096 Feb  7 21:52 Python-3.11.2
10.9.12.232 | CHANGED | rc=0 >>
total 4
drwxr-xr-x. 16 admin admin 4096 Feb  7 21:52 Python-3.11.2
```

```bash
##>> 安装软件
$ ansible -i hosts all -m yum -a "name=unzip state=latest"

##>> 删除软件
$ ansible -i hosts all -m yum -a "name=unzip state=removed"

##>> 临时开启某个仓库
$ ansible -i hosts all -m yum -a "name=unzip state=latest enablerepo='epel'"

##>> 安装组包
$ ansible -i hosts all -m yum -a "name='@Development Tools' state=latest"
```

```bash
##>> 准备工作
$ vim nginx.repo
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

$ ansible -i hosts all -m copy -a "src=nginx.repo dest=/etc/yum.repos.d/nginx.repo"
$ ansible -i hosts all -m yum -a "name=nginx state=latest enablerepo='nginx-stable'"

##>> 开启服务
$ ansible -i hosts all -m service -a "name=nginx state=started enabled=true"
$ ansible -i hosts all -m service -a "name=firewalld state=stopped enabled=false"
```

```bash
##>> 准备工作
$ vim test.sh
touch file{1..3}.txt

##>> 远程执行脚本
$ ansible -i hosts all -m script -a "chdir=/opt test.sh"
```



### 2.2 Ad-Hoc常见需求

&emsp;&emsp;对于日常运维过程中, 常见的批量运维需求有：日常巡检、批量初始化、部署服务、项目上线等, 使用ansible完成这些需求是很方便的; 其实更像是将任务写成脚本一样的;

```bash
#> 构建巡检脚本
$ vim checking.sh
#!/usr/bin/env bash
#
# author: mirschao
# email: mirschao@gmail.com
# github: https://github.com/mirschao

CPU_STAT=$(top -bn1 | egrep -v "(top|Tasks|%Cpu|MiB|PID|^$)" | awk '{stat+=$9}END{ printf "%.2f%%\n", stat }')
MEM_STAT=$(top -bn1 | egrep -v "(top|Tasks|%Cpu|MiB|PID|^$)" | awk '{stat+=$10}END{ printf "%.2f%%\n", stat }')
DISK_STAT=$(df --total | grep total | awk '{ print $(NF-1)}')
echo "{CPU: ${CPU_STAT}, MEM: ${MEM_STAT}, DISK: ${DISK_STAT}}"
```

```bash
#!/usr/bin/env bash
#
# author: mirschao
# email: mirschao@gmail.com
# github: https://github.com/mirschao
# usage: 日常巡检服务器资源

#> 获取网段内所有的在线主机并进行密钥认证
function TransPublicKey() {
  if [ ! -f /usr/bin/expect ]; then
      yum -y install expect
  fi
  local MACHINE=$1
  local PASSWD='xxxxxx'
  /usr/bin/expect <<-EOF
  spawn ssh-copy-id root@${MACHINE}
  expect "yes/no" { send "yes\r" }
  expect "password" { send "${PASSWD}\r" }
  expect eof
EOF
}

function GetOnlineMachines() {
  local NETSEGMENT='10.9'
  echo '[checking]' >/tmp/hosts
  for i in {0..255}; do
      for j in {2..254}; do
        {
          ping -c3 ${NETSEGMENT}.${i}.${j} &>/dev/null
          if [ $? -eq 0 ]; then
              echo ${NETSEGMENT}.${i}.${j} >>/tmp/hosts
              TransPublicKey ${NETSEGMENT}.${i}.${j}
          fi
        }&
      done
      wait
      echo "${NETSEGMENT}.${i}.0 segment check complete!!!"
  done
}
GetOnlineMachines

#> 执行巡检脚本
ansible -i hosts all -m script -a "chdir=/opt checking.sh" --one-line --fork=10

#> 检测站点首页可用性
URL_LISTS=(
  https://www.baidu.com
  https://www.sina.com
  https://www.taobao.com
)

for url in ${URL_LISTS[*]}; do
  ansible localhost -m uri -a "url=${url} validate_certs=yes"
done
wait
```

练习: 批量部署zabbix-agent

练习: 批量初始化云主机

练习: Wordpress源代码上线



## 三、Ansible Playbook剧本编排

![ansible-playbook-arch](https://img2018.cnblogs.com/blog/1349539/201911/1349539-20191115154741320-2032151816.png)

&emsp;&emsp;这是ansible真正的体现威力的地方, 在一个YAML文件中, 指定 hosts主机组、vars变量、tasks任务、handlers触发器从而对某些任务进行顺序执行, 就像是脚本一样; 编写剧本的时候称之为任务编排; 

&emsp;&emsp;playbook 是由一个或多个play组成的列表; play的主要功能在于将直线归并为一组的主机装扮实现通过ansible中的task定义好的角色。从根本来讲，所谓的task无非是调用ansible的一个module。将多个play组织在一个playbook内，即可以让它们联动起来按实现编排的机制唱一台大戏; playbook采用YAML语言编写

```bash
#> hosts主机组文件
$ cat hosts
[agent]
10.9.12.231
10.9.12.232
10.9.12.233
[agent:vars]
package=nginx
```

 ```yaml
 #> main.yaml ansible剧本
 $ cat main.yaml
 ---
 - hosts: agent
   vars:
     task_name: "abctest"
   tasks:
     - name: this is install nginx task name {{ task_name }}.
       yum: name=nginx state=latest
       notify: enable now nginx
       tags: installnginx
       # when: package=="nginx"
     - name: this is install apache task name {{ task_name }}.
       yum: name=httpd state=latest
       notify: enable now apache
       tags: installapache
       # when: package=="apache"
     - name: this is install many pakcages of machines.
       yum: name={{ item }} state=latest
       with_items:
         - net-tools
         - vim
         - gcc
   handlers:
     - name: enable now nginx
       service: name=nginx state=started enabled=True
     - name: enable now apache
       service: name=httpd state=started enabled=True
 ```

```bash
#> 检查剧本语法错误
$ ansible-playbook -i hosts main.yaml --syntax-check

#> 执行剧本
$ ansible-playbook -i hosts main.yaml

#> 执行剧本中的某一部分
$ ansible-playbook -i hosts -t installapache main.yaml

#> 执行剧本 根据条件
$ ansible-playbook -i hosts -e package='nginx' main.yaml
```



### 3.1 ansible常见剧本需求

&emsp;&emsp;ansible-playbook可以完成很多需求, 像是部署、上线、配置、初始化等均可以采用playbook的形式进行操作; 对于zabbix-agent部署、filebeat批量部署、测试/生产环境上线等都是常见的ansible剧本

```yaml
---
- hosts: agent
  vars:
    - zabbix_server: "10.9.12.21"
    - zabbix_repo_url: "https://repo.zabbix.com/zabbix/5.0/rhel/7/x86_64/zabbix-release-5.0-1.el7.noarch.rpm"
  tasks:
    - name: installer zabbix installcation repo file.
      yum: name={{ zabbix_repo_url }} state=present
    - name: installer zabbix-agent package.
      yum: name=zabbix-agent state=latest
    - name: transfer zabbix-agent.conf configfile.
      template: src=zabbix_agent.conf.j2 dest=/etc/zabbix/zabbix_agentd.conf
      notify:
        - enable now zabbix-agent
  handlers:
    - name: enable now zabbix-agent
      service: name=zabbix-agent state=started enabled=True
```

```yaml
---
- hosts: agent
  vars:
  tasks:
    - name: download filebeat package to dest machines.
      get_url: url=https://mirrors.hiops.icu/packages/filebeat-7.13.1-x86_64.rpm dest=/usr/local/src/ validate_certs=no
    - name: installer filebeat package to dest machines.
      yum: name=/usr/local/src/filebeat-7.13.1-x86_64.rpm state=present
    - name: configure filebeat configfile to dest machines.
      template: src=filebeat.yml.j2 dest=/etc/filebeat/filebeat.yml
      notify:
        - enable now filebeat
  handlers:
    - name: enable now filebeat
      service: name=filebeat state=started enabled=True
```

```yaml
---
- hosts: agent
  vars:
    proj_name: "helloworld"
    proj_url: "https://gitee.com/mirschao/helloworld.git"
    proj_path: "/srv/apps/helloworld"
    virtualenv_path: "/srv/envs/apps/helloword"
    requirement_file_name: "requirements.txt"
  tasks:
  - name: update {{ proj_name }} project source codes.
    git: repo={{ proj_url }} dest={{ proj_path }}
  - name: installtaion requirements site-packages.
    pip: requirements={{ proj_path }}/{{ requirement_file_name }} virtualenv={{ virtualenv_path }}
  - name: restart {{ proj_name }} project.
    supervisorctl: name={{ proj_name }} state=restarted


[helloworld]
10.9.12.231
10.9.12.232
10.9.12.233
[helloworld:vars]
ansible_python_interpreter=/usr/local/python311/bin/virtualenv
```



### 3.2 ansible roles角色剧本编写

```bash
$ git clone https://github.com/mirschao/parthree.git
$ tree roles/
roles/
├── filebeat
│   ├── handlers
│   │   └── main.yml
│   ├── tasks
│   │   └── main.yml
│   ├── templates
│   │   └── filebeat.yml.j2
│   └── vars
│       └── main.yml
├── hosts
├── logstash
│   ├── handlers
│   │   └── main.yml
│   ├── tasks
│   │   └── main.yml
│   ├── templates
│   │   └── logstash.conf.j2
│   └── vars
│       └── main.yml
└── site.yml

10 directories, 10 files
```

