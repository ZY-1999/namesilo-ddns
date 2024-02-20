# namesilo-ddns
ddns for namesilo

### 需求
1. 更新namesilo 域名映射的ip
2. 变更时发送通知

### 实现
1. 通过namesilo提供的 api 进行变更参考 https://www.namesilo.com/api-reference#dns
    - 通过 dnsListRecords 接口获取id
    - 通过 dnsUpdateRecord 接口更新ip
2. 通知方式直接使用钉钉webhook 内容关键字校验方式
3. 定时执行使用crontab