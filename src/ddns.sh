#!/bin/sh

############### FUNCTIONS #############

# 获取公网IPv4地址
get_public_ip() {
    # 使用curl命令从ipinfo.io网站获取IP地址信息 --noproxy "*" 强制不走代理
    ip_info=$(curl --noproxy "*" -s https://ipinfo.io)
    # 使用grep和awk命令提取IPv4地址
    ip=$(echo "$ip_info" | grep "\"ip\"" | awk -F '"' '{print $4}')
    # 返回IPv4地址
    echo "$ip"
}

# 推送 dingding 消息
pushDingTalk() {
    # 钉钉通知使用关键词校验方式
    accessToken=$1
    messageKey=$2
    content=$3
    webhook="https://oapi.dingtalk.com/robot/send?access_token=${accessToken}"
    dateStr=$(date +%Y-%m-%d\ %H:%M:%S\ %z)
    data="{
          \"msgtype\": \"text\",
          \"at\": {
            isAtAll: true
          },
          \"text\": {
                    \"content\": \"${messageKey}\n${dateStr}\n==========\n${content}\n\"
                    }
         }"

    curl --insecure \
        --noproxy "*" \
        --request POST \
        --url "${webhook}" \
        --header "Content-Type: application/json" \
        --data "${data}"
}

# 获取记录id type默认="A"
get_ip_record_id() {
    apiKey=$1
    domain=$2
    host=$3
    type=${4:-"A"}
    result=$(curl --noproxy "*" -s "https://www.namesilo.com/api/dnsListRecords?version=1&type=xml&key=${apiKey}&domain=${domain}")
    # 返回结果为xml 较简单直接使用了正则匹配
    ids=($(grep -oP '<record_id>\K.*?(?=</record_id>)' <<< ${result}))
    hosts=($(grep -oP '<host>\K.*?(?=</host>)' <<< ${result}))
    types=($(grep -oP '<type>\K.*?(?=</type>)' <<< ${result}))
    # 遍历通过host和type匹配 
    for index in "${!ids[@]}"; do
        _id=${ids[$index]}
        _host=${hosts[$index]}
        _type=${types[$index]}
        if [ "${_host}" = "${host}.${domain}" ] && [ "${_type}" = "${type}" ]; then
            resultId=$_id
        fi
        index=$index+1
    done
    echo "$resultId"
}


# 更新 dns 信息
put_dns_record() {
    apiKey=$1
    domain=$2
    newHost=$3
    newIp=$4
    type=$5
    recordId=$(get_ip_record_id "$apiKey" "$domain" "$newHost" "$type")
    curl --noproxy "*" "https://www.namesilo.com/api/dnsUpdateRecord?version=1&type=xml&key=${apiKey}&domain=${domain}&rrid=${recordId}&rrhost=${newHost}&rrvalue=${newIp}" 
}

############### FUNCTIONS ###############

# 配置
apiKey="xxxx"
domain="330000.top"
host="dev"
dingdingAccessToken="xxxx"
dingdingMessageKey="小艺通知"

# 上一次脚本执行时候的 ip 地址 [用来和当前地址比较，两次结果不一致会更新 DNS IP、并推送钉钉]
mkdir -p "../log"
read -r ipOld <"../log/ip_old.txt"
# 获取 wan 口的公网 ip 地址
ipNew=$(get_public_ip)
echo "[$(/bin/date)] 执行ip更新 [${ipOld}] -> [${ipNew}]" >>"../log/log.txt"
if [ "${ipNew}" != "${ipOld}" ]; then
    # 更新 dns
    put_dns_record "$apiKey" "$domain" "$host" "$ipNew"
    pushDingTalk "$dingdingAccessToken" "$dingdingMessageKey" "[${host}.${domain}]ip更新: [${ipOld}] -> [${ipNew}]"
    # 记录新的 ip 地址
    echo "${ipNew}" >"../log/ip_old.txt"
    # 记录每次dns更新
    echo "[$(/bin/date)] ip更新 [${ipOld}] -> [${ipNew}]" >>"../log/dns.txt"
fi
