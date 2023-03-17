#!/usr/bin/env bash
#
# author: mirschao
# email: mirschao@gmail.com
# usage: transfer ssh piblic key to target machines.


filename='transfer_key_config.ini'
# 生成系统rsa密钥对儿
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -N "" -C ansible@controller -f ~/.ssh/id_rsa
fi

# 编写自动应答函数, 用于传输公钥时密码的输入
function Transfer_SSH_Key() {
PASSWD=$(awk '/\['machines:vars'\]/$1~/'password'/{print $3}' ${filename})
/usr/bin/expect<<-EOS
spawn ssh-copy-id root@${1}
expect "yes/no" { send "yes\r";exp_continue }
expect "password" { send "$PASSWD\r" }
expect eof
EOS
}

# 获取配置文件中的IP地址及密码
for ip in $(grep agent ${filename} | awk '{ print $3 }'); do
    Transfer_SSH_Key ${ip}
done
wait
echo "complete!!!"
