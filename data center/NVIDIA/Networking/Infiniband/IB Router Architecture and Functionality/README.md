
* **網路分割 (Segmentation)：** InfiniBand (IB) 路由器的主要功能是將一個超大型的網路，切割成數個較小的子網 (Subnets)。
* **功能優勢：**
    * **隔離性 (Isolation)：** 可以將特定的子網彼此隔開，提升安全性或故障隔離能力。
    * **擴展性 (Scalability)：** 透過這種架構，能夠構建出規模極大的網路環境。
* **文章主旨：** 該篇文章後續將深入探討 IB 路由器的「架構」與「功能」。

## Terminology

|英文術語|中文翻譯|詳細技術解釋|
|---|---|---|
|SM (Subnet Manager)|子網管理器|InfiniBand 網路中的 SDN (軟體定義網路) 控制器。它負責網路的初始化、路由計算與資源分配。|
|SA (Subnet Administration)|子網管理 (介面/服務)|負責處理 SM 的帶內 (in-band) 北向介面的軟體。它實作了一種服務，讓 InfiniBand 用戶端軟體可以查詢 SM 並與之互動 (例如查詢路徑記錄)。|
|OpenSM|OpenSM|符合 InfiniBand 標準的「子網管理器」與「管理」軟體 (通常指開源的實作版本)。|
|OpenMPI|OpenMPI|開放訊息傳遞介面 (Message Passing Interface) 的實作版本，常用於高效能運算 (HPC) 的平行處理溝通。|
|SRQ (Shared Receive Queue)|共享接收隊列|一種減少接收緩衝區 (Receive Buffer) 資源消耗的方法。透過讓多個 QP (隊列對) 共享同一個接收緩衝池，而非每個 QP 獨佔。|
|Per Peer QP|對等點隊列對|每個通訊對等點 (Peer) 專用的 Queue Pair (QP)。|
|LIDs (Local Identifier)|本地識別碼|InfiniBand 使用的 Layer 2 (連結層) 位址 (由 SM 負責分配)。類似於乙太網的 MAC，但在 IB 中是動態分配的。|
|DLID (Destination LID)|目的端 LID|封包要傳送到的目的地 LID。|
|multi-swid (Multi Switch-ID)|多重交換器 ID|在單一台實體 InfiniBand 交換器上，虛擬化出多個邏輯交換器的技術。|
|P_Key (Partition Key)|分區金鑰|InfiniBand 用來限制特定流量發送、接收或轉發的方式。概念上類似於乙太網的 VLAN，但機制有所不同 (用於邏輯隔離)。|
|Floating LID (FLID)|浮動 LID|用於從本地子網路由到遠端子網上的分葉交換機 (leaf switches)。|
|multi-swid (Multi Switch-ID)|多重交換機 ID|在單一實體 InfiniBand 交換機上虛擬化出多個交換機的技術。|

>> **SM 與 LIDs 的關係：** 在 InfiniBand 網路中，設備插上線並不會自動通訊，必須等待 SM 掃描整個網路拓撲後，指派 LID 給每一個 Port，網路才會「活」過來。

>> **P_Key vs VLAN：** 雖然文中提到類似 VLAN，但 P_Key 是基於金鑰的成員資格檢查。如果兩個設備的 P_Key 不匹配，它們甚至無法建立連線或交換封包，隔離層級非常嚴格。


## Overview
* **為什麼需要 IB Router？**
    * **隔離與效能：** 將網路切割成小子網，可以加快子網管理器 (SM) 的回應速度，並隔離不同節點間的流量 (例如將儲存網路與運算網路分開)。
    * **超大規模擴展：** 支援超過 42,000 個節點 (Hosts) 的超大型叢集。
* **高效能路由技術：** Mellanox IB 路由器使用 **「演算法路由 (Algorithmic Routing)」**。它不需要查表 (Table lookups) 就能直接從 L3 位址算出 L2 位址，因此能達到極低延遲與線速 (Line rate) 傳輸。
* **關鍵限制 (Limitations)：**
    * 目前僅支援 **單跳 (Single hop)** 路由，不支援跨越多個路由器的傳輸。
    * 跨子網目前 **不支援多播 (Multicast)**。(此功能計畫在後續階段推出)
    * 路由器本身 (如 SB7780) **不能** 運行 Embedded SM (嵌入式子網管理器) 或 SHARP (網路運算卸載) 功能。
 
## Single Hop Topologies

單跳拓撲是指一種網路拓撲結構，假設兩個子網之間的所有 L3 連線需求，都必須透過至少一個路由器連接，如圖 1 所示。

* **圖 1 (Figure 1)：** 單跳拓撲 (正確架構)。顯示 Subnet 0 與 Subnet 1 透過中間的一個 Router 直接相連。

當有兩個子網未透過路由器直接相連時，若流量需要經過多個路由器跳躍 (hops) 才能從一端到達另一端，我們稱此拓撲為多跳 (multi-hop)。

* **圖 2 (Figure 2)：** 包含兩個子網的多跳拓撲 (不支援的架構)。
* **結論：** 在截至 2016 年 5 月的 IB 路由規範下，這些子網之間將 **無法** 進行 L3 路由通訊 (如圖中紅色 X 所示)。

## Network Topology Design

* **避免信用循環 (Credit-Loop Freedom)：** 設計多子網拓撲時，最關鍵的挑戰是防止跨路由器的流量形成「緩衝區依賴循環 (buffer dependency loops)」。使用 **Up/Dn (上/下) 路由演算法** 是一種簡單有效的方法，它限制了流量的路徑 (禁止「先下後上」的轉向)。
  * **單一子網內**的信用循環自由由 SM (子網管理器) 保證，它會防止形成信用循環。
  * **跨子網時**，當我們連接多個子網時，涉及跨越路由器的多個流量流可能會產生此類依賴循環的風險。為了避免信用循環，通常需要詳細且精確的設計，這可能涉及使用 InfiniBand **虛擬通道 (Virtual Lanes)** 和**服務等級 (Service Levels)** 來支援多樣化的拓撲集合。
* **兩種建議的拓撲方案：**
    * **方案 A (新叢集)：** 將 IB 路由器放置在所有子網的**頂端 (Top)**。這適合全新設計的環境。
      ![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka08Z000000hvTG&feoid=00N8Z000003jPco&refid=0EM8Z000003DU5P)
    * **方案 B (擴充現有子網)：** 當需要將多個「現有的舊子網」連接到一個「新的共用子網 (如儲存區)」時，路由器應位於**新子網的頂端**，但在**舊子網的下方**。
      ![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka08Z000000hvTG&feoid=00N8Z000003jPco&refid=0EM8Z000003DU5U)
* **配置要求：**
    * 必須確保同一子網使用的所有連接埠都配置了相同的 **subnet_prefix**。
    * 路由器數量需足夠，以維持所需的頻寬。
    * 路由器可直接支援 Fat-tree、Torus 和 Mesh 拓撲，無需複雜的路由鏈配置。
    * OpenSM 路由引擎鏈 (Routing engine chains) 提供了許多單一引擎無法支援的路由拓撲選項
 
## Partitions
* **管理控制與隔離：** 即使有路由器連接，您仍可透過 P_Key 禁止特定子網間的通訊。這是一種具成本效益的解決方案，讓單一路由器能服務多個隔離群組。
* **P_Key 配置規則：**
    * 若要讓兩個子網通訊，它們**必須共用相同的 P_Key 號碼**。IB 規範不允許跨子網更改 P_Key。
    * **無法路由轉換：** 不可能在同一個或不同子網上，將封包從一個 P_Key 路由到另一個 P_Key。
* **實作方式：** P_Key 的分配由各子網的 SM 執行，並透過 `partitions.conf` 檔案進行設定。

![Figure 4 - P_Key Number Sharing](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka08Z000000hvTG&feoid=00N8Z000003jPco&refid=0EM8Z000003DU5e)

這張圖表展示了如何利用 **P_Key (Partition Key)** 在 InfiniBand 網路中實現「即使有路由器連接，也能達成邏輯隔離」的架構。

這是一個典型的 **「共享資源 vs. 隔離用戶」** 的應用場景（例如：多個部門共享同一台儲存設備，但部門之間不可互通）。

以下是詳細的技術解構：

### 1. 架構圖解分析
圖中有三個子網 (S1, S2, S3) 透過中間的綠色線條（代表 IB 路由器）連接在一起。

* **S1 (核心/共享資源區)：**
    * **配置：** 同時擁有 **P_Key2** 和 **P_Key3**。
    * **角色：** 這通常是「共享儲存設備 (Storage)」或「管理節點」。因為它擁有多把鑰匙，所以它能跟不同群組的人溝通。
* **S2 (用戶區 A)：**
    * **配置：** 只有 **P_Key2**。
    * **角色：** 只能跟持有同樣鑰匙 (P_Key2) 的對象通訊。
* **S3 (用戶區 B)：**
    * **配置：** 只有 **P_Key3**。
    * **角色：** 只能跟持有同樣鑰匙 (P_Key3) 的對象通訊。

### 2. 通訊邏輯 (誰可以跟誰說話？)

根據文件中的規則：「若要讓兩個子網通訊，它們**必須共用相同的 P_Key 號碼**」。

* **S1 <---> S2 (⭕ 通訊成功)：**
    * S1 有 P_Key2，S2 也有 P_Key2。
    * 兩者擁有共同的 P_Key，因此封包可以順利通過路由器傳輸。
* **S1 <---> S3 (⭕ 通訊成功)：**
    * S1 有 P_Key3，S3 也有 P_Key3。
    * 擁有共同鑰匙，通訊成功。
* **S2 <---> S3 (❌ 通訊阻斷)：**
    * S2 只有 P_Key2。
    * S3 只有 P_Key3。
    * **結果：** 雖然它們物理上都接在同一台路由器上，但因為**沒有共同的 P_Key**，路由器會拒絕轉發這兩者之間的流量。這就是圖表下方文字 "S2 and S3 can't talk" 的意思。

### 3. 這個架構解決了什麼問題？

這張圖強調了 IB 路由的一項重要限制與特性：**路由器無法進行 P_Key 的轉換 (Mapping/Translation)**。

* **不能這樣做：** 你不能要求路由器把 S2 送來的 P_Key2 封包，「改標籤」變成 P_Key3 後送給 S3。
* **只能這樣做：** 封包出發時是什麼 P_Key，到達目的地時必須是同一個 P_Key。

**總結來說：**
這張圖展示了一種**低成本的隔離方案**。你不需要買兩台物理路由器來分開 S2 和 S3，只需要在一台路由器上配置不同的 P_Key，就能讓 S2 和 S3 都能存取 S1 (共享資源)，但 S2 和 S3 彼此完全隔離，互不干擾。

## IPoIB
InfiniBand 路由器 (IB Router) 無法直接傳輸 IP 封包，因此需要額外的配置來解決跨網段的 IP 通訊問題。

**1. 核心限制**
* **IB 路由器不處理 IP：** IB 路由器只處理 InfiniBand 協議，不會處理或轉發 IPoIB (IP over InfiniBand) 流量，因為這些封包缺少 GRH 標頭。
* **應用需求：** 許多管理介面或儲存系統仍需依賴 IP 協議進行通訊。

**2. 解決方案 (二選一)**
* **方案 A（使用外部網路）：** 另外架設一套乙太網路 (Ethernet) 來專門處理 IP 通訊。
* **方案 B（使用 Linux 作為 IP 路由器）：**
    * 在每個 IB 子網上劃分不同的 IP 網段（Subnet）。
    * 在子網之間放置一台 Linux 主機，配置多個 IPoIB 介面。
    * 讓這台 Linux 主機擔任「軟體路由器」的角色來轉發 IP 封包。
    * *優點：* 不需要額外的乙太網路硬體，且因為這類管理流量通常不大，普通 Linux 主機即可勝任。

**3. 最佳實踐建議**
* **推薦做法：** 為每個 IB 子網設定**不同**的 IPoIB 網段，並透過路由器轉發。
* **不推薦做法：** 強行將所有 IB 子網設定在同一個 IPoIB 大網段下（這可能導致廣播風暴或邏輯錯誤）。

https://www.tecmint.com/setup-linux-as-router/

## Algorithmic Router Architecture

核心在於解決 InfiniBand 網路中，跨子網路由時「地址轉換」帶來的延遲問題。

**1. 設計目的**
* **極致效能：** 為了實現全線速 (Wire Speed) 轉發並將延遲降至最低。
* **簡化架構：** 消除傳統路由器在最後一跳需要維護龐大對映表 (Mapping Table) 來將 GID 轉換為 LID 的負擔。

**2. 核心機制：GID 直接映射 LID**
* **傳統方式：** 路由器收到封包後，需查表得知目的地的 GID 對應哪個 LID，才能進行二層轉發。
* **演算法路由方式：** 直接將 L2 地址 (LID) **嵌入** 到 L3 地址 (GID) 中。
    * 具體做法是取 **GID 的最後 16 個位元 (16 LSB)** 直接作為 **LID**。
    * 路由器不需要「學習」或「查找」LID，只需「提取」即可。

**3. 限制與特性**
* **固定參數：** 為了追求速度，除了地址之外的其他 L2 參數（如 P_Key, Service Level, MTU 等）無法動態調整，路由器會直接複製進入封包的原始設定到送出封包中。
* **特定格式：** 必須使用特定的 GID 格式（如下圖所示），這被稱為「演算法可路由 GID」。
  ![Routable GID Format](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka08Z000000hvTG&feoid=00N8Z000003jPco&refid=0EM8Z000003DU5j)

**簡單來說：** 這是一種透過規範 IP/GID 地址格式（將硬體地址藏在軟體地址的尾端），讓硬體路由器能「無腦」快速轉發的技術。

[nvidia | lrh-and-grh-infiniband-headers](https://enterprise-support.nvidia.com/s/article/lrh-and-grh-infiniband-headers)

## How does IB Routing Work? A step by step description

此章節描述了 InfiniBand 跨子網路由的詳細工作流程，主要解決了「如何找到路徑」與「如何轉發封包」的問題。

**1. 初始化與環境準備 (Setup Phase)**
* **分配 ID：** OpenSM 負責分配 LID 和 GID。
* **快取分發：** 為了加速解析，IP 與 GID 的對映表會預先寫入 `ibacm` 快取並分發到所有主機。
* **工具：** 使用 `ib2ib` 腳本自動化收集並建立這些設定檔。

**2. 連線建立流程 (The Flow)**
* **第一步 (App -> IP)：** 應用程式知道目標 IP，透過 DNS/Hosts 解析。
* **第二步 (IP -> GID)：** 透過 `ibacm` 快取，將目標 IP 轉換為 IB 的 Global ID (GID)。
* **第三步 (GID -> L2 Path)：** 在發送任何 InfiniBand 流量之前，客戶端應用程式或核心模組必須取得描述目的地 L2 位址的路徑記錄 (PathRecord)
    * 主機向 Subnet Administrator (SA) 詢問：「我要去這個 GID，該怎麼走？」
      * PathRecord 是透過提供來源和目的地 GID 向子網管理器 (SA) 取得的。
    * OpenSM 計算路徑，選擇合適的路由器（考慮 P_Key 等權限），並回傳該**路由器的 LID** 作為下一跳地址。

**3. 關鍵轉發機制 (Forwarding Mechanism)**
* **來源端：** 發送封包時，必須使用正確的 Source GID (SGID)，這是在 IPoIB 設定階段就綁定好的。
* **路由器端：** 路由器執行極簡化的轉發（這與前一張圖片提到的「演算法路由器」呼應）。它不需要查表，而是直接從封包標頭的 DGID 中**提取**出最終目的地的 LID，替換掉原本的 DLID，然後將封包送往目標子網。

**一句話總結：**
IB 路由透過預先填充的 IP-GID 對映表來加速解析，並由 OpenSM 指派最佳路由器，最後路由器透過從 GID 直接提取 LID 的方式實現快速轉發。
