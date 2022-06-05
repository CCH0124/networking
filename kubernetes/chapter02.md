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
|NF_IP_PRE_ROUTING|PREROUTING|當風包從外部機器或系統到達時觸發，剛進入網路層的封包|
|NF_IP_LOCAL_IN|INPUT|當封包透過路由表目標 IP 地址與本機匹配時觸發|
|NF_IP_FORWARD|NAT|觸發來源和目的地都不匹配主機 IP 地址的封包。表示這台主機代表其他主機路由的封包|
|NF_IP_LOCAL_OUT|OUTPUT|當來自主機的封包離開主機時觸發，即向外轉發|
|NF_IP_POST_ROUTING|POSTROUTING|無論來源的任何封包離開主機時觸發|

`Netfilter` 在封包透過內核的過程中的特定階段觸發每個鉤子，`iptables` 直接將鏈的概念映射到 `Netfilter hooks`。

![Netfilter hooks](https://flylib.com/books/3/475/1/html/2/images/0131777203/graphics/20fig01.gif) from "https://flylib.com"

