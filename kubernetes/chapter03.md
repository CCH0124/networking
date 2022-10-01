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

