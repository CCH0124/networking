# Linux Networking

## Basics (基礎知識)

1. **應用程式與通訊埠 (Ports)：**
    * 一個最小化的 Go 語言 Web 伺服器範例，通常監聽在特定的 IP 位址和通訊埠（例如 `8080`）。
    * **非特權埠：** 慣例上，應用程式應監聽非特權埠（如 1024 以上，常見 8080），因為埠號 1–1023 需要 `root` 權限才能綁定。
    * **萬用字元位址 (Wildcard Addresses)：** `0.0.0.0` (IPv4) 和 `[::]` (IPv6) 是萬用字元位址，允許服務綁定在主機所有可用的 IP 位址上。

2. **Socket 與系統呼叫 (Syscalls)：**
    * 程式透過創建並綁定一個 **Socket** 來監聽特定的位址和埠。
    * 核心 (Kernel) 會將傳入的封包映射到特定的連線，並使用內部狀態機管理連線狀態。
    * 使用 `strace` 工具可以觀察伺服器進行的網路相關系統呼叫 (Syscalls)，例如 `socket`（創建 Socket）、`setsockopt`（設定選項）、`bind`（綁定埠）、`listen`（開始監聽）和 `epoll_wait`（等待請求）。

### 範例

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

有多種方法可以檢查套接字(socket)，下面使用 `ls -lah /proc/<server proc>/fd`。

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

網路介面是電腦與外部世界通訊的通道，可以是實體（如乙太網卡）或虛擬的。

1. **IP 位址分配：** IP 位址被分配給網路介面，一個介面可以擁有多個 IPv4 或 IPv6 位址。
2. **回環介面 (Loopback Interface, `lo`):** 這是專門用於同主機通訊的特殊虛擬介面，標準 IP 位址為 `127.0.0.1`。發送到此介面的封包不會離開主機，但需要注意它**並非**一個安全邊界。
3. **工具：** `ifconfig` 或 `ip` 命令可用於檢視和設定網路介面的配置。在 Kubernetes 節點上，容器運行時會為每個 Pod 創建虛擬介面，因此列表會更長。


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

> CVE-2020-8558 was a past Kubernetes vulnerability, in which kube-proxy rules allowed some remote systems to reach 127.0.0.1. The loopback interface is commonly abbreviated as lo.

## Bridge Interface

橋接介面允許系統管理員在單一主機上創建多個第二層 (L2) 網路。

1. **功能：** 橋接器 (Bridge) 作用類似網路交換器，將主機上的多個網路介面無縫連接。它使得 Pods 能夠透過節點的網路介面與更廣泛的網路互動。
2. **虛擬乙太網對 (Veth Pair)：** `veth` 設備是一對創建的虛擬乙太網路隧道。發送到其中一端的封包會立即在另一端被接收。
3. **網路命名空間 (Namespaces) 連接：** `veth` 對用於連接不同的網路命名空間（例如容器）與主機的主命名空間。
    * *範例：* 創建兩個網路命名空間 `net1` 和 `net2`，並使用 `ip link add veth1 netns net1 type veth peer name veth2 netns net2` 將它們連接起來。Kubernetes 使用 CNI 項目結合 `veth` 配置來管理容器的網路命名空間。

![image](https://user-images.githubusercontent.com/17800738/172036783-41a254a8-42bd-4143-b5eb-b05fbdafb1a4.png)

`veth` 是本地端的 `Ethernet tunnel`，它是*成對建立的*，當不同 namespace 要進行通訊時，使用 `veth` 來實現，在上圖中的 POD 和主機通訊就是如此。但在 Kubernetes 中使用 CNI 來進行管理。

>更詳細的介紹可以看[networking bridge](https://wiki.linuxfoundation.org/networking/bridge)

## Packet Handling in the Kernel

Linux 核心負責在網路封包和應用程式數據流之間進行轉換。

1. **Netfilter 框架：**
    * Netfilter 是一個核心框架，提供鉤子 (Hooks) 允許使用者空間的程式攔截和處理封包。它與 `iptables` 共同設計，`iptables` 直接將其鏈 (Chains) 映射到 Netfilter 鉤子。
    * **五個核心鉤子**（及其對應的 `iptables` 鏈）：
        * `NF_IP_PRE_ROUTING` (`PREROUTING`): 封包剛抵達時觸發。
        * `NF_IP_LOCAL_IN` (`INPUT`): 封包目的地是本機時觸發。
        * `NF_IP_FORWARD` (`FORWARD`): 封包既非源自本機，目的地也非本機（即正在被轉發）時觸發。
        * `NF_IP_LOCAL_OUT` (`OUTPUT`): 封包源自本機並正要離開時觸發。
        * `NF_IP_POST_ROUTING` (`POSTROUTING`): 所有封包在離開本機前觸發。

2. **Conntrack (連線追蹤)：**
    * Conntrack 是 Netfilter 的一個組件，用於追蹤進出機器的連線狀態（流，Flows）。這對防火牆和 NAT 功能至關重要。
    * **識別連線：** 連線透過五個元素的元組 (tuple) 識別：源位址、源埠、目的位址、目的埠和 L4 協議。
    * **Conntrack 狀態：** 包括 `NEW` (收到第一個有效封包)、`ESTABLISHED` (雙向皆有封包)、`RELATED` (相關連線) 和 `INVALID` (無效封包)。
    * **DoS 風險：** Conntrack 流表大小是可配置的；如果被短命或不完整的連線淹沒，可能導致新的連線無法建立，造成拒絕服務 (DoS)。

路由和防火牆是 Kubernetes 中的關鍵，嚴重依賴於 Linux 的底層封包管理。

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
    - `Accept` : 繼續封包處理
    - `Drop` : 丟棄封包，無需進一步處理
    - `Queue` : 將封包傳遞給用戶空間程式
    - `Stolen` : 不執行進一步的 hook，並允許用戶空間程式獲得封包所有權
    - `Repeat` : 讓封包*重新進入* hook 並被重新處理

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

核心必須決定封包的去向。路由表（Route Table）負責將已知的子網路映射到網關 IP 位址和介面。

* **路由決策邏輯：** Linux 優先根據**特異性 (Specificity)** 路由（選擇匹配最小子網路範圍的路由），然後再依據**權重/度量 (Metric)** 選擇（選擇較低的 metric）。

kernel 必須決定將封包發送到哪裡。在大多數情況下，目標機器不會在同一個網路中。但你的計算機可以做的最好的事情是將其傳遞給更接近能夠達到 1.2.3.4 的另一台主機。路由表透過將已知子網映射到網關 IP 地址和接口來實現此目的。我們可以使用 `route` 列出已知路由，通常機器有一個本地網路的路由和一個 0.0.0.0/0 的路由。以下是本地網路上可以訪問 Internet 機器的路由表：

```bash
$ ip route list
default via 192.168.133.2 dev ens33 proto static
192.168.133.0/24 dev ens33 proto kernel scope link src 192.168.133.135
```

## High-Level Routing

1. **iptables：**
    * **結構：** 依據層級組織：**表 (Tables)** 包含 **鏈 (Chains)**，鏈包含 **規則 (Rules)**。
    * **表類型：** 常見的有 `Filter` (防火牆/允許拒絕)、`NAT` (修改源或目的 IP 位址) 和 `Mangle` (通用封包頭編輯)。
    * **執行順序：** 表的執行順序為：`Raw` -> `Mangle` -> `NAT` -> `Filter`。
    * **目標 (Targets)：** 規則定義了條件和動作，例如 `ACCEPT`、`DROP`、`REJECT`、`SNAT` (修改源地址) 或 `DNAT` (修改目的地址)。
    * **Kubernetes 應用：** Kubernetes 的 `kube-proxy` 預設使用 `iptables` 模式來實現服務 (Services) 的負載平衡。

2. **IPVS (IP Virtual Server)：**
    * IPVS 是一個 Linux 第四層 (L4) 連線負載平衡器，提供比 `iptables` 更高效的負載平衡。
    * **負載平衡模式 (Kubernetes 支援)：** 輪詢 (`rr`)、最少連線 (`lc`)、源雜湊 (`sh`)、最短預期延遲 (`sed`) 等。
    * **優勢：** 解決了大規模 Kubernetes 叢集中 `iptables` 規則數量巨大導致的性能瓶頸問題。

3. **eBPF (Extended Berkeley Packet Filter)：**
    * eBPF 允許在核心中執行特殊沙盒程式，避免了核心與使用者空間之間的頻繁切換。
    * **性能：** 由於避免了遍歷巨大的 `iptables` 規則列表，eBPF 在網路軟體中表現出卓越的性能。
    * **Kubernetes 應用：** Cilium 等 CNI 解決方案使用 eBPF 直接攔截和路由封包，並可實現應用層 (L7) 負載平衡和安全。

### iptables

1. **`iptables` 是什麼？**
    `iptables` 是 Linux 系統管理員的核心工具，長年被用於建立防火牆、稽核日誌、修改和轉送封包，甚至能實現連線分流。它透過 `Netfilter` 框架來攔截和修改封包。

2. **`iptables` 的應用與複雜性**
    `iptables` 規則可能變得非常複雜，因此有 `ufw` 和 `firewalld` 等簡化工具。在 Kubernetes (K8s) 中，`kubelet` 和 `kube-proxy` 會自動產生 `iptables` 規則，因此理解 `iptables` 對於掌握 K8s 中 Pod 和節點的存取與路由至關重要。

3. **`nftables` 的崛起（注意事項）**
    多數 Linux 發行版正用 `nftables`（一個基於 Netfilter 且效能更好）來取代 `iptables`。但 Kubernetes 在處理 `iptables/nftables` 過渡時有許多已知問題，因此**強烈建議**在可預見的未來，**不要**使用 `nftables` 版本的 `iptables`。

4. **`iptables` 的核心階層**
    `iptables` 的概念具有階層性，依序為：**表 (Tables)** 包含 **鏈 (Chains)**，而 **鏈** 則包含 **規則 (Rules)**。

5. **核心概念詳解**
    * **表 (Tables):** 依照「效果類型」來組織規則。最常見的三個表是：`Filter`（防火牆相關）、`NAT`（網路位址轉換相關）和 `Mangle`（非 NAT 的封包修改）。
    * **鏈 (Chains):** 包含一個規則列表。鏈存在於表中，並根據 Netfilter 鉤子 (hooks) 來組織規則（有五個內建的頂層鏈）。選擇哪條鏈，決定了封包在什麼時間點會被規則評估。
    * **規則 (Rules):** 是「條件」和「動作（target）」的組合。例如：「如果一個封包的目標是 port 22，就丟棄它」。

#### iptables tables

iptables 中的表映射到特定的功能集合，其中每個表負責特定類型的操作。更具體說，一個表只能包含特定的目標類型，並且許多目標類型只能在特定的表中使用。下表為 iptables 的分類型

| Table | Purpose |
|---|---|
|Filter| Filter 表處理封包要接受或拒絕|
|NAT| NAT 表用於修改源或目標 IP 地址|
|Mangle| Mangle 表可以執行封包的頭(header)通用編輯，但它不適用於 NAT。它還可以使用 iptables-only 元數據*標記*數據包|
|Raw| Raw 表允許在處理 connection tracking 和其他表之前進行封包變更。它最常見的用途是禁用某些封包的 connection tracking|
|Security| SELinux 使用 Security 表進行封包處理。它不適用於未使用 SELinux 的機器|

*iptables 以特定順序執行表 Raw、Mangle、NAT、Filter*。然而執行順序是鏈(chain)，然後是表(table)。

#### iptables chains

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

> NAT 表有一個要注意的點，`DNAT` 可以在 `PREROUTING` 或 `OUTPUT` 中執行，而 `SNAT` 只能在 `INPUT` 或 `POSTROUTING` 中執行。

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

#### Subchains

1. **什麼是子鏈 (Subchains)？**
    除了內建的頂層鏈（入口鏈），使用者可以自訂「子鏈」。

2. **如何使用？**
    透過 `JUMP` 動作 (target) 來執行。`iptables` 會進入子鏈，逐一執行規則，直到遇到一個「終止動作」。

3. **為何使用？（優點）**
    * **邏輯分離：** 將相關規則打包，使結構更清晰。
    * **重複使用：** 類似程式碼中的「函式 (function)」，可以在多個情境中被呼叫，避免重複撰寫規則。

4. **效能影響**
    * **問題：** `iptables` 會對「每一個」進出系統的封包運行大量（數十到數千個）的 `if` 檢查，這會對封包延遲、CPU 使用率和網路吞吐量造成可觀的效能衝擊。
    * **優化：** 組織良好的鏈（和子鏈）可以透過消除多餘的檢查或動作來減少這種效能開銷。

5. **Kubernetes 的瓶頸**
    * 儘管可以優化，但在 Kubernetes 環境中，當一個服務 (Service) 擁有大量 Pod 時，`iptables` 的效能仍然是一個大問題。
    * **替代方案：** 這使得其他使用較少或完全不使用 `iptables` 的解決方案更具吸引力，例如 `IPVS` 或 `eBPF`。

```bash
$ sudo iptables -L -nv --line-numbers
[sudo] password for itachi:
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination

Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination
1     6279 2121K DOCKER-USER  0    --  *      *       0.0.0.0/0            0.0.0.0/0
2        0     0 DOCKER-FORWARD  0    --  *      *       0.0.0.0/0            0.0.0.0/0

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination

Chain DOCKER (2 references) # 自定義
num   pkts bytes target     prot opt in     out     source               destination
1        0     0 DROP       0    --  !br-610672ec014e br-610672ec014e  0.0.0.0/0            0.0.0.0/0
2        0     0 DROP       0    --  !docker0 docker0  0.0.0.0/0            0.0.0.0/0

Chain DOCKER-BRIDGE (1 references) # 自定義
num   pkts bytes target     prot opt in     out     source               destination
1        0     0 DOCKER     0    --  *      br-610672ec014e  0.0.0.0/0            0.0.0.0/0
2        0     0 DOCKER     0    --  *      docker0  0.0.0.0/0            0.0.0.0/0

Chain DOCKER-CT (1 references) # 自定義
num   pkts bytes target     prot opt in     out     source               destination
1        0     0 ACCEPT     0    --  *      br-610672ec014e  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
2        0     0 ACCEPT     0    --  *      docker0  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED

Chain DOCKER-FORWARD (1 references) # 自定義
num   pkts bytes target     prot opt in     out     source               destination
1        0     0 DOCKER-CT  0    --  *      *       0.0.0.0/0            0.0.0.0/0
2        0     0 DOCKER-ISOLATION-STAGE-1  0    --  *      *       0.0.0.0/0            0.0.0.0/0
3        0     0 DOCKER-BRIDGE  0    --  *      *       0.0.0.0/0            0.0.0.0/0
4        0     0 ACCEPT     0    --  br-610672ec014e *       0.0.0.0/0            0.0.0.0/0
5        0     0 ACCEPT     0    --  docker0 *       0.0.0.0/0            0.0.0.0/0

Chain DOCKER-ISOLATION-STAGE-1 (1 references) # 自定義
num   pkts bytes target     prot opt in     out     source               destination
1        0     0 DOCKER-ISOLATION-STAGE-2  0    --  br-610672ec014e !br-610672ec014e  0.0.0.0/0            0.0.0.0/0
2        0     0 DOCKER-ISOLATION-STAGE-2  0    --  docker0 !docker0  0.0.0.0/0            0.0.0.0/0

Chain DOCKER-ISOLATION-STAGE-2 (2 references) # 自定義
num   pkts bytes target     prot opt in     out     source               destination
1        0     0 DROP       0    --  *      docker0  0.0.0.0/0            0.0.0.0/0
2        0     0 DROP       0    --  *      br-610672ec014e  0.0.0.0/0            0.0.0.0/0

Chain DOCKER-USER (1 references) # 自定義
num   pkts bytes target     prot opt in     out     source               destination
1        0     0 RETURN     0    --  *      *       0.0.0.0/0            0.0.0.0/0
```

#### iptables rules

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

有兩種目標動作：終止(terminating )和非終止(nonterminating)。*終止目標將不繼續 iptables 檢查鏈中的後續目標，本質上充當最終決定*；非終止目標則反之。`ACCEPT`、`DROP`、`REJECT` 和 `RETURN` 都是終止目標。`ACCEPT` 和 `RETURN` 僅在其鏈內終止，也就是說，*如果封包在子鏈中命中 `ACCEPT` 目標，則父鏈將恢復處理並可能丟棄或拒絕該目標*。

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

下表為 `iptables target` 範例

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

> iptables 規則不會在重啟後保留。iptables 提供 `iptables-save` 和 `iptables-restore` 工具，可以手動使用也可以透過簡單的自動化來捕獲或重新加載規則。這是大多數防火牆工具透過在每次系統啟動時自動創建自己的 iptables 規則來覆蓋。

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

重點整理後，可以總結以下

1. **封包偽裝 (Masquerading)**
      * `iptables` 可以「偽裝」連線，讓封包看起來像是從節點（主機）自己的 IP 位址發出的，而不是來自內部的 Pod IP。
      * 這對於 K8s 叢集來說是**必要的**，因為 Pod 的內部 IP 通常無法直接與外部網際網路通訊。
      * `MASQUERADE` 動作類似 `SNAT`，但它不需要預先知道來源 IP（會自動抓取出口介面的 IP），因此更具彈性，但效能略遜於 `SNAT`。

2. **使用 `iptables` 進行負載平衡**

      * `iptables` 可以透過 `nat` 表中的 `DNAT` 規則（目的地位址轉換）來實現連線層級的負載平衡。
      * 它藉助 `statistic` 模組和 `--probability`（機率）參數，以隨機方式將流量導向不同的後端。
      * 圖片中的 K8s 範例（`KUBE-SVC-...` 和 `KUBE-SEP-...` 鏈）顯示了它如何使用 `random probability` 將流量分散到不同的 Pod (SEP = Service Endpoint)。

3. **`iptables` 負載平衡的嚴重缺陷 (Caveats)**

      * **無健康檢查：** `iptables` 無法感知後端（Pod）的實際負載或健康狀況。
      * **「黏性」連線 (Sticky Connections)：** 這是最大的問題。`DNAT` 的決策是在連線建立時（例如 TCP 握手時）決定的，並且**在該連線的整個生命週期中都會保持不變**。
      * **導致負載不均：** 如果應用程式使用**長連線**（例如 gRPC、WebSocket 或資料庫連線），`DNAT` 會導致客戶端「黏在」同一個後端 Pod 上。
      * **無法動態擴展：** 舉例來說，一個 gRPC 服務有 2 個副本，當您將其擴展到 10 個副本時，**原有的 gRPC 客戶端將繼續連線到那 2 個舊副本**，新增加的 8 個副本完全接收不到流量，導致嚴重的負載不均。

4. **結論與替代方案**

      * 雖然 `iptables` 被廣泛使用，但它在處理負載平衡時速度較慢，且功能有限（尤其是上述的長連線問題）。
      * 因此，`IPVS` 是一個更具吸引力的替代方案，它是**專為負載平衡而設計的**。

### IPVS

IPVS 在 Linux 網路堆疊中扮演關鍵角色，作為高效能的第 4 層 (L4) 連線負載平衡器。在 Kubernetes 環境中，它常被用來取代預設的 `iptables` 模式，以解決大規模服務部署時的性能瓶頸問題。

![image](https://user-images.githubusercontent.com/17800738/188311915-d0f6e9c0-97e8-42c3-bcd2-6bf8a8614511.png)

#### 1. 核心定義與定位

* **功能定位**：IPVS 是一個 Linux 連線 (L4) 負載平衡器。它屬於高階路由管理工具，提供網路連線層級的流量分發能力。
* **優勢對比**：相較於 `iptables` 透過隨機路由實現的簡單連線分流，IPVS 支援多種負載平衡演算法，能更有效地分散流量。在大規模集群中，當 `iptables` 規則數量龐大導致性能下降時，IPVS 成為一個更優的解決方案。
* **性能考量**：`iptables` 的性能與規則數量呈線性相關，每次封包處理都需要遍歷冗長的規則列表，造成延遲。IPVS 透過其設計和演算法，有效避免了這種瓶頸，提升了路由速度。

#### 2. Kubernetes 整合與 kube-proxy 模式

iptables 透過各個 DNAT 規則的權重決定路由連接來進行簡單的 L4 負載均衡。與 iptables 相比，IPVS 支持多種負載均衡模式，如下表

IPVS modes supported in Kubernetes

|模式名稱 |縮寫|負載平衡策略描述|路由特性
|---|---|---|---|
|Round-robin |rr| 將後續連線依序傳送到「下一個」主機，是 IPVS 的預設模式，與 `iptables` 行為最接近 (儘管 `iptables` 不是真正的輪詢)。|分散連接|
|Least connection|lc|將連線發送到當前開啟連線數最少的主機。|考量負載|
|Destination hashing|dh|根據連線的目標位址，確定性地將連線發送到特定主機。| 確定性路由 |
|Source hashing|sh |根據連線的源位址，確定性地將連線發送到特定主機。 | 確定性路由 |
|Shortest expected delay|sed|將連線發送到「連線數與權重比率」最低的主機。 | 考量負載/權重 |
|Never queue|nq| 將連線發送到任何沒有現有連線的主機；若所有主機都有連線，則採用 `Shortest expected delay` 策略。 | 優先新連線 |

更詳細可參考[linuxvirtualserver | scheduling](http://www.linuxvirtualserver.org/docs/scheduling.html)。

#### 3. 封包轉發機制 (Packet Forwarding Modes)

IPVS 支援三種封包轉發模式，用於處理服務到後端伺服器（Pod）的流量：

* NAT 重寫來源地址和目標地址
* DR 將 IP 資料包封裝在 IP 資料包(datagrams)中
* IP 隧道(tunnel)透過將資料框(data frame)的 MAC 地址改寫為所選後端服務器的 MAC 地址，直接將封包路由到後端服務

> DR 是一種附載均衡模式

當 iptables 作為負載均衡器的問題時，需要考慮三個方面

##### Number of nodes in the cluster

一個例子是在一個 5000 個節點的集群中使用 `NodePort`，如果有 2000 個 `service` 物件並且每個 `service` 有 10 個 pod，這將導致每個工作節點上至少有 20000 條 iptables 記錄，這會使內核非常忙碌。

##### Time

當有 5,000 個 `service`（40,000 條規則）時，添加一條規則所花費的時間為 11 分鐘。對於 20,000 個 `service`（160,000 條規則），需要 5 小時。

##### Latency

訪問服務存在延遲，即路由延遲；每個封包必須遍歷 iptables 列表，直到匹配。添加/刪除規則存在延遲，從廣泛的列表中插入和刪除是一項大規模的密集操作。

#### Kubernetes 整合 Service

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

#### 5. 高階功能與操作細節

* **會話黏性 (Session Affinity)**：IPVS 支援會話黏性（或稱會話保持），這透過 Kubernetes Service 的配置（例如 `Service.spec.sessionAffinity`）暴露給使用者。在會話黏性時間窗口內，重複的連線將被路由到相同的主機，這對於最小化快取遺失等場景非常有用。
* **規則同步週期**：IPVS 規則的刷新週期可通過 `kube-proxy` 的啟動參數 `--ipvs-sync-period duration` 進行配置，預設值為 30 秒。
* **管理工具**：在 Linux 系統上，可以使用 `ipvsadm` 命令列工具來管理 IPVS 服務。例如，使用 `-A`、`-E`、`-D` 旗標來新增、編輯和刪除虛擬服務 (Virtual Services)，使用小寫的 `-a`、`-e`、`-d` 旗標來管理後端主機 (Backends)。
* **性能指標**：有資料顯示，在測試中，新增 20,000 個服務（約 160,000 條 `iptables` 規則）可能需要長達 5 小時的時間，這突顯了 IPVS 在大規模部署中的性能優勢。

總結來說，IPVS 作為 Kubernetes 服務的底層 L4 實現，為集群管理員提供了比傳統 `iptables` 更加靈活、高效和可擴展的負載平衡解決方案，尤其適用於需要精確控制流量分發策略和應對大規模服務變更的環境。

### eBPF

作為一名資深網路架構師，我認為 eBPF（擴展式柏克萊封包過濾器）是 Linux 網路領域近年來最重要的創新之一，它在 Kubernetes 大規模部署中，徹底改變了服務網格和網路政策的底層實現方式。

以下是針對 eBPF 章節的詳細重點整理，著重於其技術原理、性能優勢以及在 Kubernetes 環境中的應用：

---

### eBPF (Extended Berkeley Packet Filter)

#### 1. eBPF 的核心定義與架構優勢

eBPF 是一種**核心內編程系統（programming system）**，它允許特殊的沙箱程式（sandboxed programs）直接在 Linux 核心中執行，無需在核心空間（kernel space）與使用者空間（user space）之間來回切換。

* **性能突破**：相較於傳統的 Netfilter/iptables 框架，eBPF 的設計繞開了複雜的資料路徑和系統呼叫（syscalls）開銷。eBPF 程式可以直接存取系統呼叫，並在不依賴核心掛鉤（kernel hooks）的情況下，觀察或阻擋（watch and block）系統呼叫。
* **演進關係**：eBPF 繼承並擴展了早期的 BPF (Berkeley Packet Filter) 技術。BPF 最初用於分析網路流量和封包過濾，例如被 `tcpdump` 工具所使用。當您在 `tcpdump` 中指定過濾條件時，它會將其編譯為 BPF 程式，並傳遞給核心執行。

#### 2. 核心集成與程式附著點 (Attach Points)

eBPF 提供了多個核心附著點，使其能夠在封包旅程的不同階段介入並執行邏輯，這對於撰寫網路軟體尤其適合。

| 附著點 (Attach Point) | 描述 (Description) | 應用 (Application) |
| :--- | :--- | :--- |
| **Kprobes** | 動態追蹤核心內部元件。 | 核心程式碼的動態檢測與除錯。 |
| **Uprobes** | 使用者空間追蹤。 | 應用程式層面的行為監控。 |
| **Tracepoints** | 核心靜態追蹤，由開發者編程到核心中，相較於 Kprobes 更穩定。 | 關鍵核心事件的穩定監控。 |
| **perf_events** | 計時資料和事件的取樣。 | 性能計量與資料採集。 |
| **XDP** | 專門的 eBPF 程式，能夠在核心空間之下，直接存取**驅動程式空間（driver space）**，對封包進行操作。 | 提供極致的封包處理效能，用於高效能網路卡驅動程式。 |

此外，eBPF 程式會使用 **Maps（映射）** 作為資料結構，以鍵值對（key-value pairs）的形式與使用者空間或其他 BPF 程式交換資料。

#### 3. Kubernetes 網路架構中的性能瓶頸與 eBPF 的解決方案

在 Kubernetes 中，eBPF 解決了傳統 `iptables` 模式在處理大規模服務時的重大性能問題。

* **iptables 的規模限制**：`iptables` 的性能與規則數量成正比。當服務數量龐大時，每次封包處理都需要遍歷冗長的規則列表，導致延遲（routing latency）。例如，測試數據顯示，新增 20,000 個服務（約 160,000 條 `iptables` 規則）可能需要長達 **5 小時**才能完成，且規則列表的插入和移除是一個密集的擴展操作。
* **eBPF 的性能優勢**：eBPF 採用**雜湊表（hashing table）**來取代 `iptables` 的線性列表遍歷，從根本上提高了查找效率，避免了隨著規則數量增加而帶來的性能呈指數級下降的問題。

#### 4. eBPF 在 Kubernetes 中的關鍵應用

eBPF 程式因其卓越的性能特性，被廣泛應用於 Kubernetes 網路和安全層面：

* **Cilium 核心技術**：eBPF 在 Kubernetes 中最常見的應用是透過 **Cilium** 專案，作為 CNI（Container Network Interface）和服務實現。Cilium 用來取代 `kube-proxy`，能夠直接在核心中攔截和路由所有封包。
  * **L7 負載平衡**：Cilium 基於 eBPF，能夠在核心內進行**應用程式層（Layer 7）**的負載平衡，這比傳統的 L4 負載平衡器（如 IPVS 或 `kube-proxy` 的 iptables 模式）更快速且功能更強大。
  * **身份識別網路安全**：Cilium 是一個 L7/HTTP 感知的 CNI，能夠使用獨立於網路定址的**基於身份（identity-based）**的安全模型，在 L3 至 L7 層級強制執行網路政策。

* **追蹤與可觀察性 (Tracing and Observability)**：
  * **cgroup-bpf**：從 Linux 4.10 版本引入，允許將 eBPF 程式附加到 cgroups（控制群組），用於收集 Pod 和容器層級的網路統計資訊。
  * eBPF 提供了直接存取系統呼叫的能力，可用於稽核 `kubectl exec` 會話中執行的任何命令，並將這些事件記錄到使用者空間程式。

* **安全強化 (Security)**：eBPF 程式可用於安全領域，例如：
  * **Seccomp**：限制允許的系統呼叫（syscalls）。
  * **Falco**：一個開源的容器原生執行時安全工具，使用 eBPF 技術。

#### 5. 與其他工具的對比

eBPF 的出現提供了一個根本性的替代方案，以解決傳統 Linux 網路工具在現代高密度、高彈性的雲原生環境中遇到的限制。它與 IPVS 和 `iptables` 並列為 Linux 高階路由的三大主要工具。IPVS 雖然提供了比 `iptables` 更好的 L4 負載平衡機制和演算法，但 eBPF 透過將邏輯移入核心且無需上下文切換，達到了更高的性能和更低的延遲。

## Network Troubleshooting Tools

| 工具名稱 | 簡述 | 應用範例/功能 |
| :------: | :--- | :------------ |
| **ping** | 使用 ICMP 測試主機間的連通性。| `ping <address> -c 5` (發送五個封包)。 |
| **traceroute** | 顯示封包到達目的地的網路路徑，利用 IP 封包的 TTL (Time-To-Live) 值。 | 追蹤路由故障點。 |
| **dig** | DNS 查詢工具。| `dig kubernetes.io` (查詢 A 記錄)。 |
| **telnet** | 用於建立連線，常用於手動測試基於文字的協議（如 HTTP/1），可手動發送請求。 | |
| **nmap** | 埠掃描器。| 檢查遠端主機哪些埠是開放的。 |
| **netstat** | 顯示網路堆疊、連線狀態、路由表和埠監聽狀態。| `netstat -lp` (顯示監聽中的連線及其程式 ID)。 |
| **netcat (nc)** | 多功能工具，用於建立連線、發送數據或在 Socket 上監聽。| |
| **OpenSSL** | 測試和除錯 TLS/SSL 連線，提供詳細的憑證資訊。| |
| **cURL** | 數據傳輸工具，支援多種協議，`-v` 旗標提供詳盡的請求/回應細節，有利於 L7 協議除錯。 | |

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

* URL encoded: `-d "key1=value1&key2=value2"`
* JSON: `-d '{"key1":"value1", "key2":"value2"}'`
* As a file in either format: `-d @data.txt`

使用 `-H` 參數可添加 HTTP 標頭。

cURL 有許多的附加功能，例如使用超時(timeouts)、自定義 CA 證書、自定義 DNS 等的能力。
