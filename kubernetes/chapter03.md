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



