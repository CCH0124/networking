- [Iptables on ubuntu](#iptables-on-ubuntu)
- [How Linux Firewall Works](#how-linux-firewall-works)
  * [Firewall Types](#firewall-types)
- [iptables Firewall Tables](#iptables-firewall-tables)
- [Table Chains](#table-chains)
- [Chain Policy](#chain-policy)
- [Adding iptables Rules](#adding-iptables-rules)
- [Iptables Rules Order](#iptables-rules-order)
- [List iptables Rules](#list-iptables-rules)
- [Deleting Rules](#deleting-rules)
- [Replacing Rules](#replacing-rules)
- [Listing Specific Table](#listing-specific-table)
- [Iptables User Defined Chain](#iptables-user-defined-chain)
- [Redirection to a User Defined Chain](#redirection-to-a-user-defined-chain)
- [Setting The Default Policy for Chains](#setting-the-default-policy-for-chains)
- [SYN Flooding](#syn-flooding)
  * [SYN Cookies](#syn-cookies)
- [Drop INVALID State Packets](#drop-invalid-state-packets)
- [Drop Fragmented Packets](#drop-fragmented-packets)
- [Save iptables Rules](#save-iptables-rules)
- [example](#example)
  * [Block Facebook on IPtables Firewall](#block-facebook-on-iptables-firewall)
  * [Block Ping ICMP Requests](#block-ping-icmp-requests)
  * [scenario](#scenario)
- [Ref](#ref)

## Iptables on ubuntu
查看 iptables 是否安裝
```shell=
$ whereis iptables
iptables: /sbin/iptables /usr/share/iptables /usr/share/man/man8/iptables.8.gz
```

## How Linux Firewall Works
Iptables firewall 可用於 Linux 內核中用於過濾 packet

### Firewall Types
- **Stateless firewall**
    - 封包有設定才放行，沒設定就不放行，所以管理者必須要很清楚所有封包往返的流量，他不會紀錄已出去的封包狀態
    - 只能逐一檢視每個封包，但不能進一步分析封包之間的關聯性
- **Stateful firewall**
    - 可以紀錄封包內的資料（例如 SYN 與 ACK 序號），以便分析不同封包之間的關聯性，因此能夠分辨出不同的 session，做出更精確的防範

Netfilter 包含 **tables**；這些 tables 包含 **chains**；chains 包含單獨的 **rules**。

如果傳遞的 packet 與任何 rules 匹配，則將對該 packet 應用規則 **action**。

action 包含，**accept**、**reject**、**ignore**、**pass** 將數據包傳遞給其它規則以進行更多處理。

Netfilter 可以使用 IP address 和 port number 處理傳入或傳出流量。

Netfilter 由 iptables 命令管理和配置。

## iptables Firewall Tables
netfilter 主要有三個 tables 可以處理 rule。其處裡順序為 `raw -> mangle -> nat -> filter`
- filter table
    - 是處理流量的主要 table
    - INPUT
        - 發往本地 sockets的 packet
    - FORWARD 
        - 透過系統路由的 packet，經過本機的 packet
    - OUTPUT 
        - 本機端生成的 packet
- nat table
    - 處理 NAT 規則
    - PREROUTING
        - SNAT，源地址轉換
        - 收到 packet 後立即更改 packet
    - OUTPUT 
        - 更改本機端生成的 packet
    - POSTROUTING 
        - DNAT，目標地址轉換
        - packet 即將發佈時更改 packet
- mangle table
    - 修改 packets
    - PREROUTING
        - 用於更改傳入連線 
    - OUTPUT
        - 更改本機端生成的 packet
    - INPUT
        - 傳入的 packet
    - POSTROUTING 
        - packet 即將發佈時更改 packet
    - FORWARD
        - 透過路由轉發的 packet，經過本機的 packet
- raw table
    - 做連接追蹤
## Table Chains

iptables Firewall Tables 說明的每個 tables 都包含 chains，這些 chains 是 iptables 規則的集合。

- filter table 
    - FORWARD
    - INPUT
    - OUTPUT

>可以創建自定義 chain 以保存 rules。

如果 packet **經過本地主機**，將由 **INPUT chain** 規則處理。
如果 packet 要去另一個主機，它將由 **OUTPUT chain** 規則處理。
**FORWARD chain** 用於處理已訪問主機但發往另一主機的 packet。

## Chain Policy
filter table 中的每個 chain 都有一個策略，該策略是預設操作。

- Policy
    - DROP
        - 不通知 client 的情況下丟棄 packet
    - REJECT
        - 會丟棄 packet 並通知發送人
    - ACCEPT
        - 允許 packet 通過防火牆

>從安全角度來看，應該 DROP 所有進入主機的 packet，並僅接受來自可信來源的 packet。

## Adding iptables Rules

add a new rule
```shell=
$ sudo iptables -A INPUT -i ens33 -p tcp --dport 80 -d 192.168.15.128 -j ACCEPT
# -A 添加新規則，默認情況下，除指定另一個 table，否則所有新規則都將添加到 filter table 中。
# -i 哪個網路介面卡進入主機的流量。如果未指定網路介面卡，則無論網路介面卡如何，該規則都將應用於所有傳入流量。
# -p 指定要處理的 packet protocol，範例為 TCP。
# -dport 指定目標 port number，範例為 80。
# -d 指定目標 IP address。如果未指定目標 IP address，則該規則將應用於 eth1 上的所有傳入流量，而不管 IP address 如何。
# -j 指定要執行的操作或 JUMP 操作，這裡我們使用 ACCEPT Policy 接受 packe。
```
```shell=
$ sudo iptables -A OUTPUT -o ens33 -p tcp --sport 80 -j ACCEPT
# -A 用於向 OUTPUT chain 添加規則
# -o 指定用於傳出流量的網路卡介面
# -sport 指定來源 port number
```
>可使用 http 或 https 等服務名稱，而不是 sport 或 dport 上的 port number。服務名稱可以在 `/etc/services` 檔案中找到。

```shell=
$ sudo iptables -A INPUT -s 192.168.200.121 -j DROP # Block Specific IP Address in IPtables Firewall
$ sudo iptables -A INPUT -p tcp -s 192.168.200.121 -j DROP # block TCP traffic
```
## Iptables Rules Order

添加 rules 時，會將其添加到 chain 的末尾。
可使用 `-I` 選項將其添加到頂部。
可以使用 `I` flag 將規則準確插入到所需的位置。

>rules 的順序很重要

```shell=
$ sudo iptables -I INPUT 2 -i ens33 -p udp -j ACCEPT
$ sudo iptables -I INPUT 3 -i ens33 -p udp --dport 80 -j DROP
```

第一條規則將接受所有 UDP 流量，然後第二條規則將被忽略，因為第一條規則已經接受了所有 UDP 流量，因此這裡的第二條規則毫無意義。

>chain 中規則的順序很重要。

## List iptables Rules
- -L 列出 chain 中的 rules
```shell=
$ sudo iptables -L INPUT
Chain INPUT (policy ACCEPT)
target     prot opt source               destination
ACCEPT     tcp  --  anywhere             Docker               tcp dpt:http
ACCEPT     udp  --  anywhere             anywhere
DROP       udp  --  anywhere             anywhere             udp dpt:80
```
- -line-numbers 顯示 rule 的行號
```shell=
$ sudo iptables -L INPUT --line-numbers
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    ACCEPT     tcp  --  anywhere             Docker               tcp dpt:http
2    ACCEPT     udp  --  anywhere             anywhere
3    DROP       udp  --  anywhere             anywhere             udp dpt:80
```
- 該列表顯示了服務名稱，您可以使用 -n 選項顯示 port number
```shell=
$ sudo iptables -L INPUT -n --line-numbers
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    ACCEPT     tcp  --  0.0.0.0/0            192.168.15.128       tcp dpt:80
2    ACCEPT     udp  --  0.0.0.0/0            0.0.0.0/0
3    DROP       udp  --  0.0.0.0/0            0.0.0.0/0            udp dpt:80
```
- 列出所有 chain 的所有 rules
```shell=
$ sudo iptables -L -n --line-numbers
```
- 獲取每個 rules 處理的 packet 數量，使用 -v 標誌
```shell=
$ sudo iptables -L -v
```
>使用 -Z 標誌將計數器重置為零

## Deleting Rules
- 使用 -D 刪除 rules
    - 使用 order number 刪除規則
```shell=
$ sudo iptables -D INPUT 3
$ sudo iptables -L INPUT --line-numbers # 原本的第三條規則被刪除
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    ACCEPT     tcp  --  anywhere             Docker               tcp dpt:http
2    ACCEPT     udp  --  anywhere             anywhere
```
- -F 標誌刪除特定 chain 中的所有 rules，刷新所有規則
```shell=
$ sudo iptables -L OUTPUT --line-number
Chain OUTPUT (policy ACCEPT)
num  target     prot opt source               destination
1    ACCEPT     tcp  --  anywhere             anywhere             tcp spt:http
$ sudo iptables -F OUTPUT
$ sudo iptables -L OUTPUT --line-number
Chain OUTPUT (policy ACCEPT)
num  target     prot opt source               destination
```
>使用 -F 時忘記提及 chain 名稱，則將刪除所有鏈規則。

## Replacing Rules
- -R 參數用自己新的規則替換現有規則
```shell=
$ sudo iptables -I INPUT  -i ens33 -p udp -j ACCEPT
$ sudo iptables -L INPUT --line-number
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    ACCEPT     udp  --  anywhere             anywhere
$ sudo iptables -R INPUT  1 -i ens33 -p tcp -j ACCEPT #新的規則替換 INPUT chain 中的第一個規則
$ sudo iptables -L INPUT --line-number
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    ACCEPT     tcp  --  anywhere             anywhere
```

## Listing Specific Table
- -t
    - 列出特定的 tables，使用帶有 tables 名稱
```shell=
$ sudo iptables -L -t filter
$ sudo iptables -L -t nat
```

## Iptables User Defined Chain
- -N
    - 創建用戶定義的 chain
```shell=
$ sudo iptables -N cch_chain
$ sudo iptables -L cch_chain
Chain cch_chain (0 references)
target     prot opt source               destination
```
- -E
    - 重新命名
```shell=
$ sudo iptables -L cchong_chain
iptables: No chain/target/match by that name.
$ sudo iptables -L cch_chain
Chain cch_chain (0 references)
target     prot opt source               destination
$ sudo iptables -E cch_chain cchong_chain # 從新命名
$ sudo iptables -L cchong_chain
Chain cchong_chain (0 references)
target     prot opt source               destination
$ sudo iptables -L cch_chain
iptables: No chain/target/match by that name.
```
- -X
    - 刪除使用者定義的 chain
```shell=
$ sudo iptables -L cchong_chain
Chain cchong_chain (0 references)
target     prot opt source               destination
$ sudo iptables -X cchong_chain # 刪除 chain
$ sudo iptables -L cchong_chain
iptables: No chain/target/match by that name.
```
>使用 -X 參數，沒給 chain 名稱，則將刪除所有用戶定義的 chains。但，無法刪除 `INPUT` 和 `OUTPUT` 等原生 chains。

## Redirection to a User Defined Chain
- -j
    - 將 packet 重定向到用戶定義的 chains，如：原生鏈
```shell=
$ sudo iptables -N CCH_ICMP # 建立新 chain
$ sudo iptables -L CCH_ICMP  # 列出 CCH_ICMP chain
Chain CCH_ICMP (0 references)
target     prot opt source               destination
$ sudo iptables -A INPUT -p icmp -j CCH_ICMP # 將此規則重定向至 CCH_ICMP
$ sudo iptables -L CCH_ICMP # 其中有一條規則參照
Chain CCH_ICMP (1 references)
target     prot opt source               destination
```

## Setting The Default Policy for Chains
- -p
    - 設置特定 chains 的預設策略。預設策略可以是 ACCEPT、REJECT 和  DROP。
```shell=
$ sudo iptables -P INPUT DROP # INPUT chain 丟棄任何 packet，除非編寫規則以允許傳入流量。
```

## SYN Flooding
攻擊者在不完成 TCP handshake 的情況下發送 SYN packets，因此接收主機將有許多打開的連接，使得伺服器變得太忙而無法回應其他客戶端。

使用 iptables 防火牆的 `limit module` 保護免受 SYN flooding
```shell=
$ sudo iptables -A INPUT -i ens33 -p tcp --syn -m limit --limit 5/second -j ACCEPT
# 僅指定每秒 5 個 SYN packet。可以根據網路需求調整此值
```
> 如果會限制網路，可以使用 `SYN Cookie`

### SYN Cookies
```shell=
$ sudo vi /etc/sysctl.conf
net.ipv4.tcp_syncookies = 1
$ sudo sysctl -p # save and reload
```

## Drop INVALID State Packets
INVALID 狀態 packets 不屬於任何連接的 packet，應該丟棄。

```shell=
$ sudo iptables -A INPUT -m state --state INVALID -j DROP # DROP 所有傳入的 INVALID packet
```

## Drop Fragmented Packets
Fragmented Packets 是大型 packet 的碎片，應該丟棄。

- -f
    - 告訴 iptables 防火牆選擇所有 Fragmented。如果不使用iptables 作為路由器，則可以丟棄 Fragmented Packets。
    ```shell=
    $ sudo iptables -A INPUT -f -j DROP
    ```

## Save iptables Rules
重新啟動 service，iptables 所有規則都不會保存，用以下方法保留它們
```shell=
$ sudo iptables-save > /etc/working.iptables.rules
$ sudo iptables-restore < /etc/working.iptables.rules
```
```shell=
$ sudo iptables - save - t filter # 保存特定的表
```
```shell=
$ sudo apt-get install iptables-persistent -y
$ sudo netfilter-persistent save
run-parts: executing /usr/share/netfilter-persistent/plugins.d/15-ip4tables save
run-parts: executing /usr/share/netfilter-persistent/plugins.d/25-ip6tables save
$ sudo  netfilter-persistent reload
run-parts: executing /usr/share/netfilter-persistent/plugins.d/15-ip4tables start
run-parts: executing /usr/share/netfilter-persistent/plugins.d/25-ip6tables start
```
## example
### Block Facebook on IPtables Firewall
```shell=
$ whois 157.240.15.35 | grep CIDR
CIDR:           157.240.0.0/16
$ sudo iptables -A OUTPUT -p tcp -d 157.240.0.0/16 -j DROP
$ sudo iptables -L OUTPUT
Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination
DROP       tcp  --  anywhere             157.240.0.0/16
```
### Block Ping ICMP Requests
```shell=
$sudo iptables -A INPUT --proto icmp -j DROP
```
### scenario
Say there is a machine the local ip address of which is 192.168.0.6. You need to block connections on port 21, 22, 23, and 80 to your machine
```shell=
$ sudo  iptables -A INPUT -s 192.168.0.6 -p tcp -m multiport --dport 21,22,23,80 -j DROP
```

## Ref
[iptables](https://www.tecmint.com/linux-iptables-firewall-rules-examples-commands/)
