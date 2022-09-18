假設一個程式在 Linux 服務器上運行，並且外部客戶端向 `/` 路徑發出請求。服務器上會發生什麼？首先，我們的程式需要監聽地址和端口。我們的程式為該地址和端口創建一個套接字(socket)並綁定到地址和端口。套接字將接收發往指定地址和端口的請求。

使用 docker 運行一個 nginx。
```bash
$ docker ps -a
CONTAINER ID   IMAGE                                COMMAND                  CREATED       STATUS                   PORTS                               NAMES
7b860261207f   nginx                                "/docker-entrypoint.…"   2 weeks ago   Up 19 seconds            0.0.0.0:80->80/tcp, :::80->80/tcp   peaceful_greider
```

使用 `ss` 查看該主機上監聽的應用程式服務，在啟動 nginx 容器後，主機監聽了 80 port。

```bash
$ ss -lt
State         Recv-Q        Send-Q               Local Address:Port               Peer Address:Port       Process
LISTEN        0             4096                       0.0.0.0:http                    0.0.0.0:*
LISTEN        0             4096                          [::]:http                       [::]:*
```

有多種方法可以檢查套接字(socket)，下面使用 ` ls -lah /proc/<server proc>/fd`。

```bash
$ ps -aux | grep "nginx"
root     10130  0.0  0.0   8852  6060 pts/0    Ss+  16:15   0:00 nginx: master process nginx -g daemon off;
...
```

```bash
# 當 process 運行時會產生 PID，會映射 fd 到目錄
$ sudo su -c "ls -lah /proc/10130/fd"
[sudo] password for cch:
total 0
dr-x------ 2 root root  0 May 29 16:15 .
dr-xr-xr-x 9 root root  0 May 29 16:15 ..
lrwx------ 1 root root 64 May 29 16:15 0 -> /dev/pts/0
lrwx------ 1 root root 64 May 29 16:15 1 -> /dev/pts/0
lrwx------ 1 root root 64 May 29 16:19 10 -> 'socket:[98195]'
lrwx------ 1 root root 64 May 29 16:19 11 -> 'socket:[98196]'
lrwx------ 1 root root 64 May 29 16:19 12 -> 'socket:[98197]'
...
```

內核將給定的封包映射到特定的連接，並使用內部狀態機來管理連接狀態。像套接字一樣，可以通過各種工具檢查連接。 Linux 用一個*檔案*表示每個連接，接受連接需要內核向我們的程序發出通知，然後程序能夠將內容傳輸到檔案和從檔案中送出。


## Network Interface
電腦或服務器使用網路介面(Network Interface)且會帶有 IP 位置與外部通訊，它可以是實體乙太網路(Ethernet network controller) 或是虛擬，但虛擬網路介面不會與實體硬體做對應。

使用 `ifconfig` 或是 `ip add`，可看到所有網路介面和配置。

```bash
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:50:56:23:b5:ce brd ff:ff:ff:ff:ff:ff
    altname enp2s1
    inet 192.168.133.130/24 brd 192.168.133.255 scope global ens33
       valid_lft forever preferred_lft forever
    inet6 fe80::250:56ff:fe23:b5ce/64 scope link
       valid_lft forever preferred_lft forever
3: cilium_net@cilium_host: <BROADCAST,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 8e:a6:79:db:61:d4 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::8ca6:79ff:fedb:61d4/64 scope link
       valid_lft forever preferred_lft forever
4: cilium_host@cilium_net: <BROADCAST,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 22:24:69:3e:78:8b brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.100/32 scope link cilium_host
       valid_lft forever preferred_lft forever
    inet6 fe80::2024:69ff:fe3e:788b/64 scope link
       valid_lft forever preferred_lft forever
5: cilium_vxlan: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether 3e:d0:98:44:99:56 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::3cd0:98ff:fe44:9956/64 scope link
       valid_lft forever preferred_lft forever
7: lxc_health@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether d2:78:8d:aa:6f:9f brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::d078:8dff:feaa:6f9f/64 scope link
       valid_lft forever preferred_lft forever
```

`loopback` 網路介面是和主機通訊的特殊介面，`127.0.0.1` 是該網路介面的 IP 位置。**封包發送至該介面封包是不會離開該主機**，因此該網路介面上監聽的行程將只能*被同一主機上的其他行程訪問*。運行容器時主機上的每個 POD 會創建一個虛擬網路介面(cilium_net、lxc_health 等)。

>CVE-2020-8558 was a past Kubernetes vulnerability, in which kube-proxy rules allowed some remote systems to reach 127.0.0.1. The loopback interface is
commonly abbreviated as lo.

## Bridge Interface
橋街介面是第二層網路，允許 POD 和各自的網路介面透過節點(Kubernetes 群集的節點)的網路介面與進行交互。

![image](https://user-images.githubusercontent.com/17800738/172036783-41a254a8-42bd-4143-b5eb-b05fbdafb1a4.png)

`veth` 是本地端的 `Ethernet tunnel`，它是*成對建立的*，當不同 namespace 要進行通訊時，使用 `veth` 來實現，在上圖中的 POD 和主機通訊就是如此。但在 Kubernetes 中使用 CNI 來進行管理。

>更詳細的介紹可以看[networking bridge](https://wiki.linuxfoundation.org/networking/bridge)

## Packet Handling in the Kernel
Linux 內核負責封包之間的轉換。路由和防火牆是 Kubernetes 中的關鍵，嚴重依賴於 Linux 的底層封包管理。

### Netfilter
Netfilter 是封包處理關鍵組件，是一個 kernel hook，*允許使用者空間(userspace)程式代表內核處理封包*，這過程要將程式註冊到 Netfilter hook。該程式可以通知 kernel 丟棄該封包或修改等動作。

Netfilter 有以下 hook
| Netfilter hook | Iptables chain name | Description |
| ---| ---| ---|
|NF_IP_PRE_ROUTING|PREROUTING|當封包從外部機器或系統到達時觸發，剛進入網路層的封包，在進行任何路由判斷之前|
|NF_IP_LOCAL_IN|INPUT|當封包透過路由表目標 IP 地址與本機匹配時觸發，即目的是本機|
|NF_IP_FORWARD|NAT|觸發來源和目的地都不匹配主機 IP 地址的封包。表示這台主機代表其他主機路由的封包，即目的是其他機器|
|NF_IP_LOCAL_OUT|OUTPUT|當來自主機的封包離開主機時觸發，即向外轉發，即本機產生的準備發送的封包|
|NF_IP_POST_ROUTING|POSTROUTING|無論來源的任何封包離開主機時觸發，在經過路由判斷之後|

`Netfilter` 在封包透過內核的過程中的特定階段觸發每個鉤子，`iptables` 直接將鏈的概念映射到 `Netfilter hooks`。

![Netfilter hooks](https://flylib.com/books/3/475/1/html/2/images/0131777203/graphics/20fig01.gif) from "https://flylib.com"

數據包的 `Netfilter` hook 流程取決於兩件事：
- 數據包來源是否是主機
- 數據包目標是否是主機

如果一個行程發送一個發往同一主機的封包，它會在*重新進入*系統並觸發 `NF_IP_PRE_ROUTING` 和 `NF_IP_LOCAL_IN` 之前觸發 `NF_IP_LOCAL_OUT` 和 `NF_IP_POST_ROUTING`。

|Packet source |Packet destination| Hooks (in order)|
|---|---|---|
|Local machine |Local machine |NF_IP_LOCAL_OUT, NF_IP_LOCAL_IN|
|Local machine |External machine |NF_IP_LOCAL_OUT, NF_IP_POST_ROUTING|
|External machine| Local machine |NF_IP_PRE_ROUTING, NF_IP_LOCAL_IN|
|External machine| External machine |NF_IP_PRE_ROUTING, NF_IP_FORWARD, NF_IP_POST_ROUTING|

從機器到自身的封包將觸發 `NF_IP_LOCAL_OUT` 和 `NF_IP_POST_ROUTING`，然後*離開*網路介面，它們會*重新進入*並被視為來自任何其他來源的封包。NAT 僅影響 `NF_IP_PRE_ROUTING` 和 `NF_IP_LOCAL_OUT` 中的本地路由決策。

程式可調用 `NF_REGISTER_NET_HOOK`（Linux 4.13 之前的 NF_REGISTER_HOOK）來註冊 hook。每次封包匹配時都會調用該 hook。根據返回值，`Netfilter` 掛鉤可以觸發多種操作：
- Accept : 繼續封包處理
- Drop : 丟棄封包，無需進一步處理
- Queue : 將封包傳遞給用戶空間程式
- Stolen : 不執行進一步的 hook，並允許用戶空間程式獲得封包所有權
- Repeat : 讓封包*重新進入* hook 並被重新處理

[a-deep-dive-into-iptables-and-netfilter-architecture](https://www.digitalocean.com/community/tutorials/a-deep-dive-into-iptables-and-netfilter-architecture)
[a-deep-dive-into-iptables-and-netfilter-architecture 中文](https://arthurchiao.art/blog/deep-dive-into-iptables-and-netfilter-arch-zh/#1-iptables-%E5%92%8C-netfilter-%E6%98%AF%E4%BB%80%E4%B9%88)
### Conntrack
Conntrack 是 Netfilter 的一個組件，用於追蹤與機器的連接狀態。如果沒有連接追蹤，封包流將更不透明。因此，Conntrack 在處理防火牆或 NAT 的系統上很重要，其可以讓防火牆區分回應和任意的封包。舉個例子，可以允許應用程式建立出站連接並執行 HTTP 請求，而遠程服務器則無法發送數據或入站連接，如下圖。

![](https://arthurchiao.art/assets/img/conntrack/node-conntrack.png) From arthurchiao.art

NAT 依賴於 Conntrack 運行，iptables 將 NAT 分為兩種類型：SNAT（source NAT，iptables 重寫來源地址）和 DNAT（destination NAT，iptables 重寫目標地址）。透過連線追蹤來修改 SNAT/DNAT，這可以實現一致的路由決策，例如將負載均衡器中的連接*固定*到特定的後端或機器。*在 Kubernetes 中，kube-proxy 通過 iptables 實現了服務負載均衡*。

Conntrack 透過元組識別連接，由 source address、source port、destination address、destination port 和 L4 protocol 組成。所有 L4 連線在連線的每一側都有一個地址和端口，因為，*網際網路使用地址進行路由，而計算機使用端口進行應用程式映射*。Conntrack 將這些連線稱為流(Flow)，流包含有關連線及其狀態的元數據。

Conntrack 將流儲存在哈希表(Hash Table)中，如下圖，但可能發生的一個嚴重問題是，當 Conntrack 用完用於連線追蹤的空間，並且無法建立新連接。如果主機直接暴露在 Internet 上運行，則使用短暫或不完整的連接來壓倒 Conntrack 是導致拒絕服務 (DOS) 的簡單方法。

![image](https://user-images.githubusercontent.com/17800738/183283565-e5431e89-eef3-4f13-a94b-d654075e722b.png)

>在 CT(連線追蹤、conntrack) 中，一個元组（tuple）定義的一條流（flow ）就表示一條連接（connection），因此與 TCP 連接是不同的概念

Conntrack 最大大小設置在 `/proc/sys/net/netfilter/nf_conntrack_max`，哈希表大小是 `/sys/module/nf_conntrack/parameters/hashsize`。可以藉由 `sysctl` 進行數值上調整
```bash
/proc/sys/net/netfilter$ ls
nf_conntrack_acct                nf_conntrack_helper                   nf_conntrack_tcp_timeout_last_ack
nf_conntrack_buckets             nf_conntrack_icmp_timeout             nf_conntrack_tcp_timeout_max_retrans
nf_conntrack_checksum            nf_conntrack_icmpv6_timeout           nf_conntrack_tcp_timeout_syn_recv
nf_conntrack_count               nf_conntrack_log_invalid              nf_conntrack_tcp_timeout_syn_sent
nf_conntrack_events              nf_conntrack_max                      nf_conntrack_tcp_timeout_time_wait
nf_conntrack_expect_max          nf_conntrack_tcp_be_liberal           nf_conntrack_tcp_timeout_unacknowledged
nf_conntrack_frag6_high_thresh   nf_conntrack_tcp_loose                nf_conntrack_udp_timeout
nf_conntrack_frag6_low_thresh    nf_conntrack_tcp_max_retrans          nf_conntrack_udp_timeout_stream
nf_conntrack_frag6_timeout       nf_conntrack_tcp_timeout_close        nf_log
nf_conntrack_generic_timeout     nf_conntrack_tcp_timeout_close_wait   nf_log_all_netns
nf_conntrack_gre_timeout         nf_conntrack_tcp_timeout_established
nf_conntrack_gre_timeout_stream  nf_conntrack_tcp_timeout_fin_wait

/sys/module/nf_conntrack/parameters$ ls
acct  expect_hashsize  hashsize  nf_conntrack_helper
```

一個 Conntrack 數據包含一個連接狀態，它是其中四種狀態之一。需要注意的是，作為第 3 層（Network layer）工具，Conntrack 狀態不同於第 4 層（Protocol layer）狀態。下表詳細說明了這四種狀態。

|State|Description|Example|
|---|---|---|
|NEW| 發送或接收有效封包，但未看到回應 | 接收到 TCP SYN |
|ESTABLISHED| 封包有收有發| 接收到 TCP SYN 且發送 TCP SYN/ACK 回應|
|RELATED| 打開一個附加連接，其中元數據表示它與*原始連接相關*| 具有 ESTABLISHED 連接的 FTP 應用程式會打開其他數據連接|
|INVALID| 封包本身無效，或與另一個 Conntrack 連接狀態不正確匹配| 接收到 TCP RST，但沒有先前的連接|

要啟用 Conntrack 需要有 `nf_conntrack_ipv4` kernel 模組，透過 `sudo modprobe nf_conntrack` 載入它，這樣在安裝 `conntrack` 就可以使用 `conntrack` CLI 了。
```bash
$ lsmod | grep nf_conntrack
$ sudo modprobe nf_conntrack
$ lsmod | grep nf_conntrack
nf_conntrack          167936  0
nf_defrag_ipv6         24576  1 nf_conntrack
nf_defrag_ipv4         16384  1 nf_conntrack
libcrc32c              16384  3 nf_conntrack,btrfs,raid456
$ sudo apt install conntrack
$ sudo iptables -A INPUT -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT
```
```bash
# 一條 SSH 連線的追蹤
$ sudo conntrack -L -p tcp
tcp      6 431999 ESTABLISHED src=192.168.133.135 dst=192.168.133.1 sport=22 dport=52636 src=192.168.133.1 dst=192.168.133.135 sport=52636 dport=22 [ASSURED] mark=0 use=1
```

其格式會像是
```
<protocol> <protocol number> <flow TTL> [flow state>] <source ip> <dest ip> <source port> <dest port> [] <expected return
packet>
```

如果一台機器在路由器後面，發往該機器的封包將被發送到路由器，而來自該機器的封包將以機器地址而不是路由器地址作為來源。

## Routing

kernel 必須決定將封包發送到哪裡。在大多數情況下，目標機器不會在同一個網路中。但你的計算機可以做的最好的事情是將其傳遞給更接近能夠達到 1.2.3.4 的另一台主機。路由表透過將已知子網映射到網關 IP 地址和接口來實現此目的。我們可以使用 `route` 列出已知路由，通常機器有一個本地網路的路由和一個 0.0.0.0/0 的路由。以下是本地網路上可以訪問 Internet 機器的路由表：

```bash
$ ip route list
default via 192.168.133.2 dev ens33 proto static
192.168.133.0/24 dev ens33 proto kernel scope link src 192.168.133.135
```
路由會匹配較小的地址集，如果我們有兩條具有相同特異性的路由，那麼具有較低度量(權重)的路由將是首選的。

### iptables
iptables 可用於創建防火牆規則和審計日誌(audit logs)、變異(NAT)和重新路由封包等。iptables 使用 Netfilter，它允許 iptables 攔截和變異封包。有許多工具可以提供更簡單的界面來管理 iptables 規則，例如 ufw 和 firewalld 這樣的防火牆工具。Kubernetes 組件特別是 kubelet 和 kube-proxy 以這種方式生成 iptables 規則，了解 iptables 對於了解大多數集群中 pod 和節點的訪問和路由非常重要。

iptable 有三個關鍵分別是，table(表)、chain(鏈) 和 rule(規則)。它們被認為是分層的，table 包含 chain，chain 包含 rule。

iptables 將表組合在一起，三個最常用的表是 `Filter`（用於防火牆相關規則）、`NAT`（用於 NAT 相關規則）和 `Mangle`（用於非 NAT 封包規則），而 iptables 以特定順序執行 table。

chain 包含了一系列的 rule，*當一個封包觸發一個 chain 時，chain 中的 rule 按順序進行比對*。chain 存在於 table 中，並根據 Netfilter 鉤子組織規則。有五個內置的 chain，每個都對應一個 Netfilter 鉤子。

*rule 是條件和動作的組合，可以稱為 `target`*。例如，如果一個封包的地址是 22 port，則丟棄它。

##### iptables tables
iptables 中的表映射到特定的功能集合，其中每個表負責特定類型的操作。更具體說，一個表只能包含特定的目標類型，並且許多目標類型只能在特定的表中使用。下表為 iptables 的分類型

| Table | Purpose |
|---|---|
|Filter| Filter 表處理封包要接受或拒絕|
|NAT| NAT 表用於修改源或目標 IP 地址|
|Mangle| Mangle 表可以執行封包的頭(header)通用編輯，但它不適用於 NAT。它還可以使用 iptables-only 元數據*標記*數據包|
|Raw| Raw 表允許在處理 connection tracking 和其他表之前進行封包變更。它最常見的用途是禁用某些封包的 connection tracking|
|Security| SELinux 使用 Security 表進行封包處理。它不適用於未使用 SELinux 的機器|

*iptables 以特定順序執行表 Raw、Mangle、NAT、Filter*。然而執行順序是鏈(chain)，然後是表(table)。

##### iptables chains
當一個封包觸發或通過一個鏈時，每個規則都會被依次比對，直到封包匹配一個 *terminating target*（如 DROP），或者封包到達鏈的末端。內置的鏈是 `PREROUTING`、`INPUT`、`NAT`、`OUTPUT` 和 `POSTROUTING`，這些由 Netfilter 鉤子整合。下表為對應

|iptables chain | Netfilter hook|
| --- | --- |
|PREROUTIN|NF_IP_PRE_ROUTING|
|INPUT|NF_IP_LOCAL_IN|
|NAT|NF_IP_FORWARD|
|OUTPUT|NF_IP_LOCAL_OUT|
|POSTROUTING|NF_IP_POST_ROUTING|

下圖可以推斷給定封包的 iptables 鏈執行和排序的等效圖。
![image](https://user-images.githubusercontent.com/17800738/183914378-016c3d24-7421-421c-9156-d87e02fd6f8c.png)

讓我們以三台機器為例，IP 地址分別為 10.0.0.1、10.0.0.2 和 10.0.0.3。我們將從機器 1（IP 為 10.0.0.1）的角度展示一些路由場景。

| Packet description | Packet source | Packet destination | Tables processed |
|---|---|---|---|
| 從別台機器進入的封包 | 10.0.0.2  |  10.0.0.1  | PREROUTING、INPUT|
| 從別台機器進入的封包但目的地非此機器| 10.0.0.2  | 10.0.0.3 | PREROUTING、NAT、POSTROUTING|
| 從本機出去的封包，目的為另一台機器| 10.0.0.1 | 10.0.0.2 |OUTPUT、POSTROUTING|
| 本機產生的封包，目的也為本機| 127.0.0.1 | 127.0.0.1 | OUTPUT、POSTROUTING(然後 PREROUTING、INPUT 隨著封包透過 loopback 接口重新進入) |


回想一下，當一個封包觸發一個鏈(chain)時，iptables 會按以下順序執行該鏈中的表，特別是每個表中的規則：
1. Raw
2. Mangle
3. NAT
4. Filter

大多數鏈不包含所有表，但是，相對執行順序保持不變，這是減少冗餘的設計決策。下表列出了包含每個鏈的表

 | |Raw| Mangle| NAT| Filter|
 |---|---|---|---|---|
 | PREROUTING |✓ | ✓|✓ | |
 | INPUT | | ✓|✓ |✓ |
 | FORWARD | | ✓| | ✓|
 | OUTPUT |✓ |✓ |✓ |✓ |
 | POSTROUTING| |✓ |✓ | |
 
 可以使用 `iptables -L -t <table>` 自己列出與表對應的鏈
 
 ```bash
 $ sudo iptables -L -t filter
Chain INPUT (policy ACCEPT)
target     prot opt source               destination

Chain FORWARD (policy DROP)
target     prot opt source               destination
DOCKER-USER  all  --  anywhere             anywhere
DOCKER-ISOLATION-STAGE-1  all  --  anywhere             anywhere
ACCEPT     all  --  anywhere             anywhere             ctstate RELATED,ESTABLISHED
DOCKER     all  --  anywhere             anywhere
ACCEPT     all  --  anywhere             anywhere
ACCEPT     all  --  anywhere             anywhere
ACCEPT     all  --  anywhere             anywhere             ctstate RELATED,ESTABLISHED
DOCKER     all  --  anywhere             anywhere
ACCEPT     all  --  anywhere             anywhere
ACCEPT     all  --  anywhere             anywhere

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination

Chain DOCKER (2 references)
target     prot opt source               destination

Chain DOCKER-ISOLATION-STAGE-1 (1 references)
target     prot opt source               destination
DOCKER-ISOLATION-STAGE-2  all  --  anywhere             anywhere
DOCKER-ISOLATION-STAGE-2  all  --  anywhere             anywhere
RETURN     all  --  anywhere             anywhere

Chain DOCKER-ISOLATION-STAGE-2 (2 references)
target     prot opt source               destination
DROP       all  --  anywhere             anywhere
DROP       all  --  anywhere             anywhere
RETURN     all  --  anywhere             anywhere

Chain DOCKER-USER (1 references)
target     prot opt source               destination
RETURN     all  --  anywhere             anywhere
 ```
 
>NAT 表有一個要注意的點，`DNAT` 可以在 `PREROUTING` 或 `OUTPUT` 中執行，而 `SNAT` 只能在 `INPUT` 或 `POSTROUTING` 中執行。

舉個例子，假設有一個發往我們主機的入站封包。執行順序是

1. PREROUTING
a. Raw
b. Mangle
c. NAT
2. INPUT
a. Mangle
b. NAT
c. Filter

下圖為經過 iptables 的封包流
![image](https://user-images.githubusercontent.com/17800738/184113205-6981849f-c1a6-436c-a843-b44d97c59f0f.png)

所有 iptables 規則都屬於一個表和鏈，它們可能的組合在上途中用一個類似點的物件表示。iptables 根據封包觸發的 Netfilter 鉤子的順序評估鏈和規則。對於給定的鏈，iptables 會在它所在的每個表中該鏈，如果我們追蹤來自本地主機的封包流，會看到將按順序評估以下表/鏈對
1. Raw/OUTPUT
2. Mangle/OUTPUT
3. NAT/OUTPUT
4. Filter/OUTPUT
5. Mangle/POSTROUTING
6. NAT/POSTROUTING

##### Subchains
用戶可以定義自己的子鏈(Subchain)並用 `JUMP` 執行它們。iptables 會以相同的方式逐個目標執行這樣的鏈，直到終止目標匹配。 iptables 有效率針對進出系統的每個封包運行數十、數百或數千個 if 語句，這對封包延遲、CPU 使用和網路吞吐量具有顯著的影響。但在 Kubernetes 中，iptables 的性能在具有多個 pod 的服務中仍然是一個問題，這使得其他使用較少或不使用 iptables 的解決方案，例如 IPVS 或 eBPF 這更具吸引力。

##### iptables rules
規則有兩部分：*匹配條件*和*動作*（target）。匹配條件描述封包屬性，如果封包匹配，則執行該操作；如果封包不匹配，iptables 將檢查下一條規則。

匹配條件檢查給定封包是否滿足某些條件，像是是否具有特定的來源地址。但要注意的是 table/chain 操作順序很重要，下表顯示了一些匹配類型

|Match type |Flag(s)| Description|
|---|---|---|
|Source|-s, --src, --source|封包是否符合指定來源位置|
|Destination|-d, --dest, --destination|封包是否符合指定目標位置|
|Protocol|-p, --protocol|封包是否符合指定協定|
|In interface |-i, --in-interface|封包是否符合指定進入的網路接口|
|Out interface |-o, --out-interface|封包是否符合指定離開的網路接口|
|State|-m state --state \<states\>|封包是否符合來自處於逗號分隔狀態之一的連接的封包。這使用了 Conntrack 狀態（NEW、ESTABLISHED、RELATED、INVALID）|

有兩種目標()動作：終止(terminating )和非終止(nonterminating)。*終止目標將不繼續 iptables 檢查鏈中的後續目標，本質上充當最終決定*；非終止目標則反之。`ACCEPT`、`DROP`、`REJECT` 和 `RETURN` 都是終止目標。`ACCEPT` 和 `RETURN` 僅在其鏈內終止，也就是說，*如果封包在子鏈中命中 `ACCEPT` 目標，則父鏈將恢復處理並可能丟棄或拒絕該目標*。

下表為 iptables 目標類型和行為

| Target type| Applicable tables| Description |
|---|---|---|
|AUDIT| All | 記錄有關放行、丟棄或拒絕封包的數據| 
|ACCEPT| Filter | 放行封包且無需進一步修改| 
|DNAT| NAT |  修改目的地址 | 
|DROPs| Filter | 丟棄封包 | 
|JUMP |All | 讓封包去執行另一個鏈。一旦該鏈完成執行，父鏈的執行將繼續|
|LOG | All| 透過 kernel log 記錄封包內容|
|MARK | All| *為封包設置一個特殊的整數*，用作 Netfilter 的標識符。該整數可用於其他 iptables 決策，並且不會寫入封包本身|
|MASQUERADE | NAT| 修改封包的來源地址，將其替換為指定網路接口的地址。這類似於 SNAT，但不需要事先知道機器的 IP 地址|
|REJECT | Filter| 丟棄封包並發送拒絕原因 |
|RETURN | All| 停止處理當前鏈或子鏈。**這不是終止目標(nonterminating)，如果存在父鏈，則該鏈將繼續處理**|
|SNAT | NAT| 修改封包的來源地址，將其*替換為固定地址*|    


下表為 iptables 範例

|Command| Explanation|
|---|---|
|iptables -A INPUT -s 10.0.0.1 | 來源地址為 10.0.0.1，且是進入的封包 |
|iptables -A INPUT -p ICMP|接受 ICMP 協定封包，且是進入的封包|
|iptables -A INPUT -p tcp --dport 443 |接受協定為 TCP 且目標 port 是 443 並且也是進入的封包|
|iptables -A INPUT -p tcp --dport 22 -j DROP|協定為 TCP 且目標 port 是 22 並且也是進入的封包，則將該封包丟棄|

目標(target)既屬於表(table)又屬於鏈(chain)，它們控制 iptables 何時對給定數據包執行上述目標。

##### Practical iptables
你可以如下顯示 iptables 規則

```bash
$ sudo iptables -L
[sudo] password for itachi:
Chain INPUT (policy ACCEPT)
target     prot opt source               destination
ACCEPT     all  --  anywhere             anywhere             ctstate NEW,RELATED,ESTABLISHED

Chain FORWARD (policy ACCEPT)
target     prot opt source               destination

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination
```

`--line-numbers` 顯示鏈中每個規則的編號，這在插入或刪除規則時會很有幫助。`-I <chain> <line>` 指定插入至某編號的一條規則，在該行的前一條規則之前。

通常設定 iptables 規則是 `iptables [-t table] {-A|-C|-D} chain rule-specification`，`-A` 表示附加；`-C` 表示確認(check)；`-D` 表示刪除。

>iptables 規則不會在重啟後保留。iptables 提供 `iptables-save` 和 `iptables-restore` 工具，可以手動使用也可以透過簡單的自動化來捕獲或重新加載規則。這是大多數防火牆工具透過在每次系統啟動時自動創建自己的 iptables 規則來覆蓋。

在 Kubernetes 中，儘管 POD 有一個唯一 IP 位置，但透過偽裝可以讓 POD 使用節點的 IP 位置。這對於存取集群外部服務是必要的，因為 POD 無法直接透過私有 IP 與外部網路通訊。`MASQUERADE` 目標類似於 SNAT；但是，它不需要預先知道和指定 `--source-address`，因為對每個封包都會動態獲取指定輸出網卡的 IP，因此如果網卡的 IP 發生了變化，`MASQUERADE` 規則不受影響。

```bash
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```
iptables 可以執行連接級別的負載平衡，或更準確的說連接服務執行時需要關聯其他系統的行為。**該技術依賴於 DNAT 規則和隨機選擇（避免每個連接都被路由到第一個 DNAT 目標）**：

```bash
$ iptables -t nat -A OUTPUT -p tcp --dport 80 -d $FRONT_IP -m
statistic \
--mode random --probability 0.5 -j DNAT --to-destination
$BACKEND1_IP:80
$ iptables -t nat -A OUTPUT -p tcp --dport 80 -d $FRONT_IP \
-j DNAT --to-destination $BACKEND2_IP:80
```

上面範例，有 50% 機會會被路由至第一個後端服務(BACKEND1_IP)，否則會被路由至下一條規則，保證會連接至第二個後端(BACKEND2_IP)。**為了有平等的機會路由到任何後端，第 n 個後端必須有 `1/n` 的機會被路由到**。如果有三個後端，則機率需要為 `0.3333....`、`0.5` 和 `1`。

當 Kubernetes 對服務使用 iptables 負載均衡時，它會創建一個鏈，如下:

```bash
Chain KUBE-SVC-I7EAKVFJLYM7WH25 (1 references)
target prot opt source destination
KUBE-SEP-LXP5RGXOX6SCIC6C all -- anywhere anywhere
statistic mode random probability 0.25000000000
KUBE-SEP-XRJTEP3YTXUYFBMK all -- anywhere anywhere
statistic mode random probability 0.33332999982
KUBE-SEP-OMZR4HWUSCJLN33U all -- anywhere anywhere
statistic mode random probability 0.50000000000
KUBE-SEP-EELL7LVIDZU4CPY6 all -- anywhere anywhere
```
但使用 DNAT 的附載均衡有幾個要注意的點。*總是將同一連接上的應用程式等級查詢映射到同一後端*。

儘管 iptables 在 Linux 中被廣泛使用，但*存在大量規則時它會變得很慢*，且只提供有限的負載均衡功能。

### IPVS
IP Virtual Server (IPVS) 是一個 L4 的 Linux  負載均衡器。

![image](https://user-images.githubusercontent.com/17800738/188311915-d0f6e9c0-97e8-42c3-bcd2-6bf8a8614511.png)

iptables 透過各個 DNAT 規則的權重決定路由連接來進行簡單的 L4 負載均衡。與 iptables 相比，IPVS 支持多種負載均衡模式，如下表

IPVS modes supported in Kubernetes
|Name|Shortcode|Description|
|---|---|---|
|Round-robin |rr| 在一個循環中將後續連線發送到下一個主機位置。與 iptables 啟用的隨機路由相比，這增加了發送到給定主機的後續連線之間的時間。|
|Least connection|lc|將連接發送到當前被連線最少的主機。|
|Destination hashing|dh|根據連線的目標地址，確定性的將連線發送到特定主機|
|Source hashing|sh |根據連線的來源地址，確定性的將連線發送到特定主機|
|Shortest expected delay|sed|將連線發送到具有最低連接權重比的主機|
|Never queue|nq|將連線發送到沒有連線的任何主機，否則使用 `shortest expected delay` 策略|

更詳細可[參考](http://www.linuxvirtualserver.org/docs/scheduling.html)該鏈結。

IPVS 支援封包轉發模式
- NAT 重寫來源地址和目標地址
- DR 將 IP 資料包封裝在 IP 資料包(datagrams)中
- IP 隧道(tunnel)透過將資料框(data frame)的 MAC 地址改寫為所選後端服務器的 MAC 地址，直接將封包路由到後端服務

>DR 是一種附載均衡模式

當 iptables 作為負載均衡器的問題時，需要考慮三個方面
##### Number of nodes in the cluster
一個例子是在一個 5000 個節點的集群中使用 `NodePort`，如果有 2000 個 `service` 物件並且每個 `service` 有 10 個 pod，這將導致每個工作節點上至少有 20000 條 iptables 記錄，這會使內核非常忙碌。

##### Time
當有 5,000 個 `service`（40,000 條規則）時，添加一條規則所花費的時間為 11 分鐘。對於 20,000 個 `service`（160,000 條規則），需要 5 小時。

##### Latency
訪問服務存在延遲，即路由延遲；每個封包必須遍歷 iptables 列表，直到匹配。添加/刪除規則存在延遲，從廣泛的列表中插入和刪除是一項大規模的密集操作。 


IPVS 還支持援 *session affinity*，它作為 `service` 物件中的一個選項 `Service.spec.sessionAffinity` 和 `Service.spec.sessionAffinityConfig`。在 *session affinity* 時間窗口內的重複連線將路由到同一主機，這對於最小化緩存未命中等場景很有用。

要創建具有兩個相同權重目標的基本負載均衡器，可指定 `ipvsadm -A -t <address> -s <mode>`。`-A`、`-E` 和 `-D` 分別用於添加、編輯和刪除虛擬服務；對應的小寫字母 `-a`、`-e` 和 `-d` 分別用於添加、編輯和刪除主機後端。

```bash
ipvsadm -A -t 1.1.1.1:80 -s lc
ipvsadm -a -t 1.1.1.1:80 -r 2.2.2.2 -m -w 100
ipvsadm -a -t 1.1.1.1:80 -r 3.3.3.3 -m -w 100
```

可使用 `-L` 列出 IPVS 主機，顯示了每個虛擬服務器（唯一的 IP 地址和端口組合）和後端：
```bash
ipvsadm -L
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
-> RemoteAddress:Port Forward Weight ActiveConn InActConn
TCP 1.1.1.1.80:http lc
-> 2.2.2.2:http Masq 100 0 0
-> 3.3.3.3:http Masq 100 0 0
```

`-L` 還可搭配多個選項，例如 `--stats`，以顯示其他連接統計訊息。

### eBPF
eBPF 是一個編程系統，它允許特殊的沙盒在內核中運行，而無需在內核(kernel)和用戶(User)空間之間來回傳遞，就像在 `Netfilter` 和 `iptables` 中看到的那樣。

在 eBPF 之前，有 Berkeley Packet Filter (BPF)。BPF 是一種在內核中使用的技術，可用於分析網路流量。BPF 支援過濾封包，它允許用戶空間行程提供一個過濾器來指定它想要檢查的封包，BPF 的用例之一是 tcpdump。當在 tcpdump 上指定過濾行為時，它會將其編譯為 BPF 程式並將其傳遞給 BPF，BPF 中的技術已經擴展到其他行程和內核操作。

eBPF 程式可以直接訪問 *syscall*。eBPF 可以直接監看和阻止*syscall*，無需向用戶空間添加內核掛鉤(hook)。也因為效能突出，常被寫成網路軟體。

除了 *socket* 過濾，內核中其支援的附加點如下
- **Kprobes**
    - 內部內核組件的動態內核追蹤
- **Uprobes**
    - 用戶空間追蹤
- **Tracepoints**
    - 內核靜態追蹤。這些由開發人員編碼到內核中，並且與 `kprobes` 相比更穩定，`kprobes` 可能會在內核版本之間發生變化
- **perf_events**
    - 數據和事件的定時採樣
- **XDP**
    - 專門的 eBPF 程式可以低於內核空間以訪問驅動程序空間以直接作用於封包

將 eBPF 與 Kubernetes 一起使用的原因有很多
- **Performance (hashing table versus iptables list)**
對於添加到 Kubernetes 的每個 `serviuce` 物件，要遍歷的 iptables 規則列表呈指數增長。因為缺少增量更新，每次添加新規則時都必須替換整個規則列表。

- **Tracing**
我們可以收集 pod 和容器級別的網路統計訊息。在 Linux 4.10 中引入的 cgroup-bpf 允許將 eBPF 程式附加到 cgroups。連接後，該程式將對進入或退出 cgroup 中任行程的所有數據包進行動作。

- **Auditing kubectl exec with eBPF**
使用 eBPF，可以附加一個程式，該程式將記錄在 `kubectl exec` 會話中執行的任何命令，並將這些命令傳遞給記錄這些事件的用戶空間程式。

- **Security**
    - **Seccomp**
    限制允許的 `syscall` 的安全計算。 `Seccomp` 過濾器可以用 eBPF 編寫

>Falco: Open source container-native runtime security that uses eBPF.

eBPF 在 Kubernetes 中最常見的用途像是 Cilium、CNI 和一些服務實現。*Cilium 取代了 kube-proxy*，`kube-proxy` 透過編寫 iptables 規則將服務的 IP 地址映射到其對應的 Pod。

*通過 eBPF，Cilium 可以直接在內核中攔截和路由所有封包，速度更快，並允許應用程式級（第 7 層）別負載平衡。*

## Network Troubleshooting Tools

| Case  | Tools |
|---|---| 
|Checking connectivity | traceroute, ping, telnet, netcat | 
| Port scanning |  nmap | 
|Checking DNS records| dig, commands mentioned in Checking Connectivity|
|Checking HTTP/1| cURL, telnet, netcat|
|Checking HTTPS| OpenSSL, cURL|
|Checking listening programs| netstat、ss|

### ping
ping 是一個將 ICMP `ECHO_REQUEST` 封包發送到網路設備的簡單應用程式。這是測試從一台主機到另一台主機的網路連接性的一種常見且簡單的方法。

Kubernetes `service` 物件支援 TCP 和 UDP，但沒有 ICMP。因此，需要使用 `telnet` 或 `cURL` 等更高級別的工具來檢查與服務的連通性。但根據網路的配置，POD 依就可以使用 ping 進行存取。

ping 可以基本使用是 `ping <address>`，address 可以是 IP 或是域名。且，可以搭配 `-c <count>`，來指定觸發次數。

```bash
$ ping -c 2 k8s.io
PING k8s.io (34.107.204.206) 56(84) bytes of data.
64 bytes from 206.204.107.34.bc.googleusercontent.com (34.107.204.206): icmp_seq=1 ttl=53 time=53.6 ms
64 bytes from 206.204.107.34.bc.googleusercontent.com (34.107.204.206): icmp_seq=2 ttl=53 time=40.6 ms

--- k8s.io ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1002ms
rtt min/avg/max/mdev = 40.622/47.103/53.585/6.481 ms
```
### traceroute
traceroute 顯示從一台主機到另一台主機的網絡路由。這使用戶可以輕鬆驗證和調試從一台機器到另一台機器所採用的路由或路由失敗的地方。traceroute 發送具有特定 IP 生存時間值(RRL)的封包，當主機收到一個封包並將 TTL 減為 0 時，它會發送一個 `TIME_EXCEEDED` 封包並丟棄原始封包。

### dig
dig 是一個 DNS 查找工具。可以使用它進行 DNS 查詢並顯示結果。指令可以是 `dig [options] <domain>`。預設情況下，dig 將顯示 `CNAME`、`A` 和 `AAAA` 記錄。

### telnet
telnet 曾經用於遠端登錄，其方式類似於 SSH。SSH 具有更好的安全性而佔據主導地位，但 telnet 對於調試使用基於文本的協議的服務器仍然非常有用，像是 `HTTP/1`。使用方式會像是 `telnet <address> <port>`，這將建立連接並提供交互式命令行界面，最後可以用 `Ctrl-J` 離開介面。 

要完整利用 telnet，需要了解使用的應用程式協定是如何工作的。telnet 是調試 `HTTP`、`HTTPS`、`POP3`、`IMAP` 等服務器的經典工具。

### nmap
nmap 是一個**端口掃描器**，它可以探索和檢查網路上的服務。基本使用方式 `nmap [options] <target>`，target 可以是域名、IP 或是 IP CIDR。

### netstat
netstat 可以顯示有關機器網路堆棧和連接的廣泛訊息，可以使用 `-a` 參數顯示所有連接或 -l 僅顯示在監聽的連接。netstat 的一個常見用途是檢查哪個行程正在偵聽特定端口。

### netcat
netcat 是一個多用途工具，用於建立連線、發送數據或偵聽套接字(socket)。當使用 `netcat <address> <port>` 時，netcat 可以連接到服務器，與 telnet 類似有個交互式的介面。

### Openssl
openssl 可以做一些事情，例如建立密鑰(key)和證書(certificates)、簽署證書(signing certificates)，以及最相關的測試 `TLS/SSL` 連接。

使用通常是 `openssl [sub-command] [arguments] [options]`。`openssl s_client -connect` 將連接到服務器並顯示有關服務器證書的詳細訊息，同時也是默認調用：

```bash
$ openssl s_client -connect k8s.io:443
CONNECTED(00000003)
depth=2 C = US, O = Google Trust Services LLC, CN = GTS Root R1
verify return:1
depth=1 C = US, O = Google Trust Services LLC, CN = GTS CA 1D4
verify return:1
depth=0 CN = k8s.io
verify return:1
---
Certificate chain
 0 s:CN = k8s.io
   i:C = US, O = Google Trust Services LLC, CN = GTS CA 1D4
 1 s:C = US, O = Google Trust Services LLC, CN = GTS CA 1D4
   i:C = US, O = Google Trust Services LLC, CN = GTS Root R1
 2 s:C = US, O = Google Trust Services LLC, CN = GTS Root R1
   i:C = BE, O = GlobalSign nv-sa, OU = Root CA, CN = GlobalSign Root CA
---
Server certificate
...
```

如果是使用的是自 self-signed CA，則可以使用 `-CAfile <path>` 來使用該 CA。這允許根據 self-signed CA 建立和驗證連接。

### cURL
cURL 是一種數據傳輸工具，支援多種協定，特別是 `HTTP` 和 `HTTPS`。基本使用是 `curl [options] <URL>`，預設是 GET 請求方法。
```bash
$ curl example.org
<!doctype html>
<html>
<head>
    <title>Example Domain</title>
...    
```

預設是不能重新定向，但只要使用 `-L` 參數就可使用。`-X` 參數可以指定 HTTP 動詞，像是 `DELETE`、`POST`、`PUT` 等。帶參數方式可以使用 `-d` 參數，如下
- URL encoded: `-d "key1=value1&key2=value2"`
- JSON: `-d '{"key1":"value1", "key2":"value2"}'`
- As a file in either format: `-d @data.txt`

使用 `-H` 參數可添加 HTTP 標頭。

cURL 有許多的附加功能，例如使用超時(timeouts)、自定義 CA 證書、自定義 DNS 等的能力。


