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
iptables 可用於創建防火牆規則和審計日誌(audit logs)、變異(NAT)和重新路由封包等。iptables 使用 Netfilter，它允許 iptables 攔截和變異封包。
