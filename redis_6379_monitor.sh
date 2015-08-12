#! /bin/bash
PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/java/default/bin:/bin::/root/bin'
export PATH
logfile=/var/log/redis_6379__monitor.log
external_ip=''
mail_to=''
serverip='127.0.0.1'
redisport=6379
slave_target=1
mem_target=0.95
cpu_target=0.9
error_msg=''
down_msg='Redis was down!! IP:${external_ip} PORT:6379. It was restarted, Please keep an eyes on it and ensure redis working fine '
#restart_cmd="/usr/local/bin/redis-server /etc/redis/redis_6379.conf"
echo $(date) >> $logfile
pid=$(ps -ef | grep redis-server | grep 6379 | grep -v grep | awk '{print $2}')
if [ "$pid" = '' ] ; then
    echo "[ERROR]Redis is shutdown" >>$logfile
    `/usr/local/bin/redis-server /etc/redis/redis_6379.conf`
    error_msg=$down_msg
    echo $error_msg | mail -s "${external_ip}-6379-redis_monitor" ${mail_to}
    exit
else
    echo "[INFO]pid:$pid" >>$logfile

    maxmemory=$(redis-cli -p $redisport config get maxmemory | awk 'NR==2 {print $1}')
    used_memory=$(redis-cli -p $redisport info memory | grep used_memory: | awk -F : '{print $2}' | sed 's/\r//g')
    mem_ratio=$(awk 'BEGIN {printf("%.2f",'${used_memory}'/'${maxmemory}')}')
    if [ $(echo "scale=2;${mem_ratio}>${mem_target}" | bc) -eq 1 ] ; then
        echo "[ERROR]used_memory:${used_memory}" >>$logfile
        echo "[ERROR]mem_used_ratio:${mem_ratio}" >> $logfile
        error_msg=$error_msg"mem_target=${mem_target}"
        error_msg=$error_msg","\ "used_memory=${used_memory}"
        error_msg=$error_msg","\ "mem_used_ratio=${mem_ratio}"
    else
        echo "[INFO]used_memory:${used_memory}" >>$logfile
        echo "[INFO]mem_used_ratio:${mem_ratio}" >> $logfile
    fi   
    cpu_ratio=$(top -b -p $pid -n 1 | grep $pid | awk '/redis-server/{print $9}' | sed 's/\r//g')
    if [ $(echo "scale=2;($cpu_ratio/100)>$cpu_target" |bc) -eq 1 ] ; then
		echo "[ERROR]cpu_ratio:${cpu_ratio}" >> $logfile
		error_msg=$error_msg","\ "cpu_target=$(echo "${cpu_target}*100" | bc)"
		error_msg=$error_msg","\ "cpu_ratio=${cpu_ratio}"
    else
		echo "[INFO]cpu_ratio:${cpu_ratio}" >> $logfile
    fi

	#slave_count=$(redis-cli -p $redisport info replication | awk -F : '/connected_slaves:/{print $2}' | sed 's/\r//g')
	# if [ $slave_count -ne $slave_target ] ; then
		# echo "[ERROR]slave:$slave_count" >> $logfile
		# error_msg=$error_msg"+slave_target#$slave_target"
		# error_msg=$error_msg"+slave#$slave_count"
	# else
		# echo "[INFO]slave:$slave_count" >> $logfile
	# fi
fi

if [ "$error_msg" != '' ] ; then
	#curl $alert_url$error_msg
	echo ${error_msg} | mail -s "${external_ip}-6379-redis_monitor" ${mail_to}
fi
