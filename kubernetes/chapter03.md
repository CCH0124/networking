# Container Networking Basics

## Applications
一個通用的作業系統盡可能支援多樣應用類型，所以它的內核包括各種驅動程式、協定庫和調度程式。從網路的角度來看，對於一個作業系統，就有一個 TCP/IP 堆棧。

![image](https://user-images.githubusercontent.com/17800738/191271665-34c5a1fe-904f-4bb0-aa55-03f605edc089.png)

## Hypervisor
Hypervisor 模擬來自主機的硬體資源、CPU 和記憶體，以創建客戶作業系統或虛擬機。其允許系統管理員與多個客戶操業系統共享底層硬體，如下圖。這種資源共享提高了主機的效率。

![image](https://user-images.githubusercontent.com/17800738/191272491-41f9294d-f208-4c5b-ae83-24ca98d7c82c.png)

其架構還為每個應用程式開發團隊提供了一個單獨的網路堆棧，從而*消除了共享系統上的端口衝突問題*。

## Containers

下圖為一個容器化應用程式的架構，每個容器都是*獨立*的；*每個應用程式，無須依賴底層的函式庫或者作業系統*；每個容器都有自己的網路堆棧。容器允許開發人員打包和部署應用程式，同時保持主機的效率。

![image](https://user-images.githubusercontent.com/17800738/191274871-9145ec33-3963-45b1-85a4-3673bb829fce.png)

**Container** 一個被運行的 image
**Image** 容器 image 是從倉庫服務器中拉下的檔案，並在啟動容器時在本地用作掛載點
**Container engine** 透過該介面，接受使用者指令行選項請求以提取 image 並運行容器
**Container runtime** 是 `Container engine` 中處理容器運行的更底層軟體
**Base image** 容器 Image 的基礎。為了減少構建的大小和復雜性，使用者可以從基礎 Image 開始並在其之上進行增量更改
**Image layer** 儲存庫(repository)中的 Image，其層是以父子關係連接。每個 Image 的層代表其自身與父層之間的變化
**Image format** `Container engine` 有自己的容器 Image 格式，如 LXD、RKT 和 Docker
**Registry** 其儲存容器 Image，並允許使用端上傳、下載和更新容器 Image
**Repository** 其可以等同於容器 Image。重要的區別是儲存庫由有關 Image 的層和元數據組成
**Tag** 是使用者為容器 Image 的不同版本定義的名稱
**Container host** 容是使用 `Container engine` 運行容器的系統
**Container orchestration** 為 `Container host` 集群動態調度容器工作負載

>Cgroups 和 namespaces 是用於創建容器的 Linux 基礎

低層級容器運行(container runtime)功能
- Creating containers
- Running containers

高層級容器運行(container runtime)功能
- Formatting container images
- Building container images
- Managing container images
- Managing instances of containers
- Sharing container images

低層級容器運行(Low-level container runtimes)
- LXC C API for creating Linux containers
- runC CLI for OCI-compliant containers

高層級容器運行(High-level container runtimes)
- containerd Container runtime split off from Docker, a graduated CNCF project
- CRI-O  Container runtime interface using the Open Container Initiative (OCI) specification,
an incubating CNCF project
- Docker Open source container platform
- lmctfy Google containerization platform
- rkt CoreOS container specification

#### OCI
OCI 定義開放標準和規範使容器技術通用。為容器 Image 格式和運行時(runtimes)創建正規的規範，允許容器在所有作業系統和平台上可移植，以確保沒有過度的技術障礙。

*Composable*(可組合性)
管理容器的工具應該需要有公正的介面。它們也不應該綁定特定的平台或一些框架，應該要在所有平台上運行。

*Decentralized*(去中心化)
格式與運行應由社群開發而非一個組織。 OCI 專案的另一個目標是運行相同容器的工具並個別獨立實現。

*Minimalist*(盡量少的)
最小化和穩定，並支持創新和實驗

#### LXC
LXC 整合了 `cgroup` 和 `namespace`，為運行應用程式提供了一個*隔離環境*。LXC 的目標是創建一個盡可能接近標準 Linux 的環境，而不需要各自的內核。

#### runC
runC 是最廣泛使用的容器運行(container runtime)。runC 是一個指令工具，用於運行根據 OCI 格式打包的應用程式，並且是實現 OCI 規範。runC 對於 Docker 來說是其中一個組件，runC 特性包括以下:
- 完全支援 Linux namespace，包括 `user namespace`
- 對 Linux 中可用的所有安全功能的原生支援
  - `SELinux`、`AppArmor`、`seccomp`、`control groups`、`capability drop`、`pivot_root`、`UID/GID dropping` 等
- Win10 容器的支援
- 計劃為整個硬體製造商的生態系統提供原生支援

#### containerd
containerd 是從 Docker 中分離出來的高層級容器運行工具。containerd 是一個背景服務，充當各種容器運行時和作業系統的 API 街口。containerd 是適用於 Linux 和 Windows 的服務，用於管理其主機系統的完整容器生命週期、Image 傳輸、儲存、容器執行和網路連接。`ctl` 是 containerd 除錯和開發工具，可以直接與 containerd 溝通。`containerd-shim` 是無背景程序（Daemonless）容器的組件，也作為容器行程的父級存在，方便一些事情，像是 containerd 允許 runC 在啟動容器後退出。如果 `containerd-shim` 沒有運行，則父端將關閉，容器退出，`containerd-shim` 還允許將容器的退出狀態回報給 Docker 等更高級別的工具，而無需容器進程的實際父級執行此操作。

>最初是作為 Docker 的一部分開發的，後來被提取為單獨的工具和庫

#### lmctfy
#### rkt
#### Docker
具有供開發人員創建、維護和部署容器的所有功能：

- Formatting container images
- Building container images
- Managing container images
- Managing instances of containers
- Sharing container images
- Running containers

![官方](https://docs.docker.com/engine/images/architecture.sv)

Docker 服務器作為守護進程運行，以管理運行容器的數據捲和網路。客戶端透過 *Docker API* 與服務器通訊，使用 `containerd` 來管理容器生命週期，並使用 `runC` 來生成容器行程。

現今的 Docker 要運行容器，Docker engine 會創建 Image 並將其傳遞給 `containerd`，`containerd` 調用 `containerd-shim`，它再使用 `runC` 來運行容器。

Docker 為應用程式開發人員和系統管理員提供了關注點分離。前者聚焦於建置開發產品的應用程式，後者專注於佈署。整體提供了快速開發的生命週期，像是使用基礎 Image 對應用程式進行測試。Docker 可以快速配置新容器以實現可擴展性，並在一台主機上運行更多應用程式，從而提高該機器的效率。

>第一個 CRI 實現是 dockershim，它在 Docker 引擎前面提供了一個抽象層。

#### CRI-O
CRI-O 是 Kubernetes CRI，基於 OCI 的實現，而 OCI 是容器運行(container runtime)引擎必須實現的規範。CRI 是一個插件接口，允許 Kubernetes 透過 Kubelet 與任何實現 CRI 接口的容器運行(container runtime)進行通訊。CRI-O 是一個輕量級的 CRI runtime，它基於 `gRPC` 和 `Protobuf` 在 UNIX 套接字(socket)上構建，且是特定於 Kubernetes 的高層級 runtime(運行)。

![](https://github.com/containerd/cri/raw/release/1.4/docs/architecture.png)

## Container Primitives
每個容器都有 Linux 原生物件，稱為 **control group** 和 **namespace**。下圖為一個例子，`cgroup` 為我們的容器控制對內核資源的存取，`namespace` 是單獨的資源切片，與根命名空間(namespace)即主機，分開管理。

![image](https://user-images.githubusercontent.com/17800738/193398251-a4954d0a-e5fb-427d-b718-6ee09f1007f5.png)

### Control Groups
簡而言之，`cgroup` 是一種 Linux 內核功能，用於限制、說明和隔離資源使用。這些獨立的子系統在內核中維護各種 cgroup：

*CPU*
該行程可以保證最小數量的 CPU 使用核心。

*Memory*
設置了行程的內存限制。

*Disk I/O*
該裝置和其他裝置透過裝置的 cgroup 子系統進行控制

*Network*
這由 `net_cls` 維護並標記離開 cgroup 的封包。

runC 在創建時為容器創建 `cgroup`。*`cgroup` 控制容器可以使用多少資源*，而*命名空間控制容器內的行程可以看到的內容*。

>lscgroup 是一個工具，可以列出系統中當前的所有 cgroup
>
### Namespaces
命名空間是 Linux 內核的特性，用於*隔離*和*虛擬化行程*集合的系統資源。以下是虛擬化資源的物件：

*PID namespace*
行程 ID，用於行程隔離

*Network namespace*
管理網路接口和單獨的網路堆棧

*IPC namespace*
管理對行程間通訊 (IPC) 資源的訪問

*Mount namespace*
管理檔案系統掛載

*UTS namespace*
UNIX分時( time-sharing)；允許單個主機為不同的行程擁有不同的主機名和域名

*UID namespaces*
使用者 ID，透過單獨的用戶(user)和組(group)分配隔離行程所有權


行程的用戶和組 ID 在用戶命名空間內外可能不同。一個行程可以在用戶命名空間之外擁有一個非特權用戶 ID，同時在容器用戶命名空間內擁有一個用戶 ID 為 0，該行程具有在用戶命名空間內執行的 root 特權，但*對命名空間外的操作沒有特權*。

一個行程的所有訊息都在 Linux 的 `/proc` 檔案系統上。PID 1 的 PID 命名空間是 4026532192，列出所有命名空間表明 PID 命名空間 ID 匹配。

```bash
$ sudo ps -p 1 -o pid,pidns
  PID      PIDNS
    1 4026532192
$ sudo ls -l /proc/1/ns
total 0
lrwxrwxrwx 1 root root 0 Oct  1 16:05 cgroup -> 'cgroup:[4026531835]'
lrwxrwxrwx 1 root root 0 Oct  1 16:03 ipc -> 'ipc:[4026532191]'
lrwxrwxrwx 1 root root 0 Oct  1 16:03 mnt -> 'mnt:[4026532189]'
lrwxrwxrwx 1 root root 0 Oct  1 16:03 net -> 'net:[4026531992]'
lrwxrwxrwx 1 root root 0 Oct  1 16:03 pid -> 'pid:[4026532192]'
lrwxrwxrwx 1 root root 0 Oct  1 16:05 pid_for_children -> 'pid:[4026532192]'
lrwxrwxrwx 1 root root 0 Oct  1 16:03 user -> 'user:[4026531837]'
lrwxrwxrwx 1 root root 0 Oct  1 16:03 uts -> 'uts:[4026532190]'
```

上面兩個 Linux 原生物件有效允許應用程式開發人員控制和管理他們的應用程式與主機和其它應用程式分開，或在容器中或透過在主機運行。

![image](https://user-images.githubusercontent.com/17800738/193400024-94a03c84-8f12-487b-a8b6-0330cad4d8bc.png)


### Setting Up Namespaces
範例將會透過低層級的方式完成容器網路建置部分
1. 建立根網路命名空間的主機
2. 建立新網路命名空間
3. 建立相對應的 `veth` 對
4. 將 veth 對的一邊移動到新的網路命名空間中
5. 新網路命名空間內 veth 對的地址設置
6. 建立 bridge 網路介面卡
7. bridge 網路介面卡設置
8. bridge 網路介面卡附加至本機介面卡
9. 將 veth 對的一邊連接到bridge 網路介面卡
10. 完成

以下是建立網路命名空間、bridge 和 veth 對。並將它們連接在一起所需的流程

`ip_forward` 是作業系統在一個網路接口上接受傳入網路封包、識別另一個接口並相應的將它們傳遞到該接口網路的能力。啟用後，`ip_forward` 允許 Linux 主機接收傳入的封包並轉發它們。充當普通主機的 Linux 機器不需要啟用 `ip_forward`，因為它會為其生成和接收 IP 流量。

```bash
$ sudo su -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
$ sysctl net.ipv4.ip_forward
net.ipv4.ip_forward = 1
```

建立一個網路命名空間，預設環境下是沒有任何一個

```bash
$ sudo ip netns add net1
$ sudo ip netns list
net1
```

現在容器有了一個新的網路命名空間，但需要一個 `veth pair` 在根網路命名空間和容器網路命名空間 `net1` 之間進行通訊。

```bash
$ sudo ip link add veth0 type veth peer name veth1
$ ip link list
...
6: veth1@veth0: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether d6:22:62:e1:01:28 brd ff:ff:ff:ff:ff:ff
7: veth0@veth1: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 7e:96:a7:f5:ec:77 brd ff:ff:ff:ff:ff:ff
```
> veth 是成對出現的，它充當網路命名空間之間的管道，因此來自一端的封包會自動轉發到另一端
> 網路接口 6 和 7 是 ip 指令輸出中的 veth 對。我們可以看到哪些是相互配對的，`veth1@veth0` 和 `veth0@veth1`

將 `veth1` 移動到之前創建的新網路命名空間中，我們透過 `ip netns exec` 驗證配置，驗證 `veth1`

```bash
$ sudo ip link set veth1 netns net1
$ sudo ip netns exec net1 ip link list
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
6: veth1@if7: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether d6:22:62:e1:01:28 brd ff:ff:ff:ff:ff:ff link-netnsid 0
```

網路命名空間是 Linux 內核中完全獨立的 TCP/IP 堆棧。作為容器中一個新網路接口和一個新的網路命名空間，`veth` 網路接口需要 IP 地址，以便將封包從 `net1` 命名空間傳送到根命名空間並往主機外發送，但與主機網路接口一樣，它們需要被打開

```bash
$ sudo ip netns exec net1 ip addr add 192.168.133.150/24 dev veth1
$ sudo ip netns exec net1 ip link set dev veth1 up
$ sudo ip netns exec net1 ip link list veth1
6: veth1@if7: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN mode DEFAULT group default qlen 1000
    link/ether d6:22:62:e1:01:28 brd ff:ff:ff:ff:ff:ff link-netnsid 0
```

狀態現在已轉換為 `LOWERLAYERDOWN`。 `NO-CARRIER` 狀態指向的方向(The status NO-CARRIER points in
the right direction.)，以太網路需要連接電纜(cable)，我們的上游 `veth pair` 也尚未啟動，但 `veth1` 網路接口已啟動並已被分配地址，但實際上仍未被啟用。

接下來配置 `veth0 pair`
```bash
$ sudo ip link set dev veth0 up
$ sudo ip link list
...
7: veth0@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 7e:96:a7:f5:ec:77 brd ff:ff:ff:ff:ff:ff link-netns net1
$ sudo ip netns exec net1 ip link list veth1
6: veth1@if7: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether d6:22:62:e1:01:28 brd ff:ff:ff:ff:ff:ff link-netnsid 0
```

`veth pair` 的雙方狀態都已 `UP`，我們需要將根命名空間 `veth` 端連接到 bridge 網路接口。

```bash
$ sudo ip link add br0 type bridge
$ ip link list br0
9: br0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 3a:33:71:ac:28:a4 brd ff:ff:ff:ff:ff:ff
$ sudo ip link set dev br0 up # dev 表示 Device
$ sudo ip link set ens33 master br0
$ sudo ip link set veth0 master br0

```
我們可以看到 ens33 和 veth0 是 bridge br0 網路街口的一部分，master br0 狀態是 `UP`。

```bash
$ ping 192.168.133.150 -c 4
...
From 192.168.133.140 icmp_seq=1 Destination Host Unreachable
From 192.168.133.140 icmp_seq=2 Destination Host Unreachable
...
```

該新網路命名空間沒有默認路由，因此它不知道將我們的封包路由到哪裡來處理 ping 請求。

```bash
$ sudo ip netns exec net1 ip route add default via 192.168.133.150
$ sudo ip netns exec net1 ip r
192.168.133.0/24 dev veth1 proto kernel sacope link src 192.168.133.150
```
### Container Network Basics

*None*

沒有網路會禁用容器的網路，當容器不需要網路訪問時使用此模式。

*Bridge*
在橋接網路中，容器在主機內部的私有網路中運行，但與網路中其他容器的通訊是開放的。與主機外部服務的通訊在離開主機之前要經過網路地址轉換 (Network Address Translation, NAT)。

>當未指定 --net 選項時，橋接模式是默認的網路模式

*Host*
在主機網路中，容器與主機共享相同的 IP 地址和網路命名空間。在此容器內運行的行程與直接在主機上運行的服務具有相同的網路功能。*如果容器需要訪問主機上的網路資源，此模式很有用*。容器在這種網路模式下*失去了網路分段的好處*，無論誰部署容器，都必須管理和應對運行該節點的*服務端口*。

*Macvlan*
Macvlan 使用父接口。該接口可以是主機接口（例如 eth0）、子接口(subinterface)，甚至可以是綁定主機適配器，將以太網接口捆綁到單個邏輯接口中。像所有 Docker 網路一樣，*Macvlan 網路是相互分割的，提供網路內的訪問，而不是網路之間的訪問*。Macvlan 允許物理接口使用 Macvlan 子接口擁有多個 MAC 和 IP 地址。Macvlan 有四種類型：`Private`、`VEPA`、`Bridge`（Docker 默認使用）和 `Passthrough`。使用網橋(Bridge)；使用 NAT 進行外部連接；使用 Macvlan 外部連接，由於主機直接映射到實體網路，因此可以使用主機的同一 DHCP 服務器和交換機完成。

*IPvlan*
IPvlan 與 Macvlan 類似，但有一個顯著區別：IPvlan 不會為建立的子接口分配 MAC 地址。*所有子接口共享父接口的 MAC 地址，但使用不同的 IP 地址*。IPvlan 有兩種模式，L2 或 L3。在 L2 中，模式類似於 Macvlan 橋接模式。 L3 模式偽裝成子接口和父接口之間的第 3 層(layer 3)設備。

*Overlay*
Overlay 允許在容器集群中的主機之間擴展相同的網路。Overlay 網路實際上位於 underlay/physical 網路之上。

>overlay 的流量需要跑在 underlay 之上

*Custom*
自定義橋接網路與橋接網路相同，但使用為該容器明確的創建橋接。使用它的一個例子是在 DB 橋接網路上運行的容器，一個單獨的容器可以在默認和 DB 橋接上具有一個網路接口，使其能夠根據需要與兩個網路進行通訊。

*容器定義的網路允許一個容器共享另一個容器的地址和網路配置*。這種共享實現了容器之間的行程隔離，每個容器運行一個服務，但服務仍然可以在 127.0.0.1 上相互通訊。

當安裝玩 Docker 服務時，預設會建立下面三種類型網路，bridge、host 和 none
```bash
$ docker network ls
NETWORK ID     NAME                  DRIVER    SCOPE
ba341fad24df   bridge                bridge    local
f35812c84422   host                  host      local
69b247239876   none                  null      local
...
```

預設是一個 Docker bridge(docker0)，一個容器被附加到它上面，並使用 `172.17.0.0/16` 默認子網中的 IP 地址進行配置。

```bash
$ ip add
...
10: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default
    link/ether 02:42:34:02:36:b3 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
```

下面使用 `docker run` 命令啟動了一個 `busybox` 容器，並請求 Docker 返回容器的 IP 地址。 Docker 預設的 NAT 地址是 `172.17.0.0/16`，該 busybox 容器獲取 `172.17.0.2` 地址。

```bash
$ docker run --rm -it busybox ip a
Unable to find image 'busybox:latest' locally
latest: Pulling from library/busybox
f5b7ce95afea: Pull complete
Digest: sha256:9810966b5f712084ea05bf28fc8ba2c8fb110baa2531a10e2da52c1efc504698
Status: Downloaded newer image for busybox:latest
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: tunl0@NONE: <NOARP> mtu 1480 qdisc noop qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0
3: sit0@NONE: <NOARP> mtu 1480 qdisc noop qlen 1000
    link/sit 0.0.0.0 brd 0.0.0.0
15: eth0@if16: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
       valid_lft forever preferred_lft forever
```

在容器的網路命名空間中運行 `ip r`，可以看到容器的路由表也自動設置好了

```bash
$ docker run -it --rm busybox /bin/sh
/ # ip r
default via 172.17.0.1 dev eth0
172.17.0.0/16 dev eth0 scope link  src 172.17.0.2
```

可以在同一主機的網路命名空間上看到 `Docker` 為容器 `veth63f314e@if15` 設置的 `veth` 接口。它是 `docker0` bridge 接口的成員，並且狀態是行的 `master docker0 state UP`

```bash
$ ip add
...
16: veth63f314e@if15: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master docker0 state UP group default
    link/ether f2:bd:e3:9b:17:76 brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet6 fe80::f0bd:e3ff:fe9b:1776/64 scope link
       valid_lft forever preferred_lft forever
```

Ubuntu 主機的路由表顯示了 Docker 到達主機上運行的容器的路由
```bash
$ ip r
default via 172.26.32.1 dev eth0
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1
172.18.0.0/16 dev br-6488defa258e proto kernel scope link src 172.18.0.1 linkdown
172.19.0.0/16 dev br-5874b1804224 proto kernel scope link src 172.19.0.1
172.21.0.0/16 dev br-6d65fc981fcd proto kernel scope link src 172.21.0.1 linkdown
172.26.32.0/20 dev eth0 proto kernel scope link src 172.26.33.250
```

*預設下，Docker 不會將它創建的網路命名空間添加到 `/var/run`其中 `p netns list` 要新創建的網路命名空間*。從 ip 命令列出 Docker 網路命名空間需要三個步驟：

1. 獲取以運行的 container ID
2. 將網路命名空間從 `/proc/PID/net/` 軟鏈(Soft link)接到 `/var/run/netns`
3. 列出網路命名空間

`docker ps` 可察看主機 PID 命名空間上正在運行的 PID 所需的容器 ID

```bash
$ docker ps
CONTAINER ID   IMAGE      COMMAND                  CREATED         STATUS                  PORTS                                       NAMES
8e9c64e97c1d   busybox    "/bin/sh"                2 minutes ago   Up 2 minutes                                                        fervent_greider
```

`docker inspect` 允許解析輸出並獲取主機進程的 PID。如果在主機 PID 命名空間上運行 `ps -p`，可以看到它正在運行 `sh`，它會同步 `docker run` 命令

```bash
$ docker inspect 8e9c64e97c1d -f '{{.State.Pid}}'
5292
$ ps -p 5292
  PID TTY          TIME CMD
 5292 pts/0    00:00:00 sh
```

8e9c64e97c1d 是容器 ID，5292 是運行 sh 的 busybox 容器的 PID，現在可以使用以下命令為 Docker 創建的容器的網路命名空間創建一個符號鏈接到 ip 期望的位置

```bash
$ ln -sfT /proc/5292/ns/net /var/run/docker/netns/8e9c64e97c1d
```

當使用 `ip netns exec` 時返回與 `docker exec` 相同的 IP 地址 172.17.0.2

```bash
$ sudo ip netns exec  8e9c64e97c1d ip a
```

Docker 啟動我們的容器，創建 network namespace、veth pair 和 docker0 bridge（如果它不存在）。

### Docker Networking Model
Libnetwork 是 Docker 對容器網路的看法，其設計理念是容器網路模型 (container networking model, CNM)。Libnetwork 實現 CNM 並在三個元件中工作，sandbox、endpoint 和 network。

sandbox 實現了對主機上運行的所有容器的 Linux 網路命名空間的管理
network 實現同一網路上的端點集合
endpoint 是網路上的主機

網路控制器透過 Docker engine 中的 API 管理這些所有。

*在端點上，Docker 使用 iptables 進行網路隔離，容器發布一個可供外部訪問的端口*。容器也不接收公有 IPv4 地址，反而是接收私有地址。預設安裝完 Docker 服務後，會建立 `docker0` 橋接網路介面，它會在兩個連接的設備之間傳遞封包，就像物理網橋一樣。因此，*每個新容器都有一個接口自動連接到 docker0 橋接*。

![](https://docs.docker.com/engine/tutorials/bridge1.png)

以下是網路模式和 Docker engine 等效列表
*Bridge*
預設 Docker 橋接

*Custom or Remote*
用戶定義的橋接介面，或允許用戶創建或使用他們的插件

*Overlay*
Overlay

*Null*
沒有網路選項

橋接網路適用於在同一主機上運行的容器；運行在不同主機上的容器通訊可以使用 overlay 網路。Docker 使用本地和全域驅動程式的概念，本地驅動程序（網橋）以主機為中心，不進行跨節點協調。其是 Overlay 等全域驅動程序的工作，全域驅動程式依賴於 libkv（一種鍵值儲存抽象）來跨機器進行協調。*CNM 不提供 key-value 存儲，因此需要 Consul、etcd 和 Zookeeper 等外部儲存*。

### Overlay Networking
對於運行在不同節點上的容器中的應用程式進行通訊，需要解決幾個問題，像是如何協調主機之間的路由訊息、端口衝突以及 IP 地址管理等。然而，`VXLAN` 是一種有助於容器主機之間路由的技術。

