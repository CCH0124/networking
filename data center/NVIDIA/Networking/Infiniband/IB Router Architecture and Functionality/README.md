# IB 路由器架構與功能 (IB Router Architecture and Functionality)

> 原文連結：[NVIDIA Enterprise Support Portal | IB Router Architecture and Functionality](https://enterprise-support.nvidia.com/s/article/ib-router-architecture-and-functionality)


## 簡介 (Introduction)

InfiniBand (IB) 路由器主要用於將一個超大型網路切割（Segmentation）成數個由 IB 路由器互聯的較小子網（Subnets）。  
這種網路分割技術可用於：
* **子網隔離 (Isolation)**：將特定子網彼此隔開，提升安全性、穩定性與故障隔離能力。
* **超大規模擴展 (Scalability)**：構建出規模極其龐大的超大型運算網路。

本文將深入探討 IB 路由器的架構設計與運作功能。


## 術語表 (Terminology)

| 英文術語 | 中文翻譯 | 詳細技術解釋 |
| :--- | :--- | :--- |
| **SM** (Subnet Manager) | 子網管理器 | InfiniBand 網路的核心集中式控制器（SDN Controller），負責整個子網的拓撲探索、LID 指派、路由計算與網路初始化。 |
| **SA** (Subnet Administration) | 子網管理介面 | SM 提供的帶內 (In-band) 查詢服務介面，主機端透過 SA 查詢路徑資訊 (PathRecord) 與分區資訊。 |
| **OpenSM** | 開源子網管理器 | 符合 InfiniBand 規範標準的開源子網管理器軟體實作。 |
| **OpenMPI** | 開源訊息傳遞介面 | HPC 平行運算中廣泛使用的 MPI 通訊函式庫。 |
| **SRQ** (Shared Receive Queue) | 共享接收隊列 | 讓多個 QP (隊列對) 共享同一個接收緩衝池，大幅降低大規模並行通訊時記憶體緩衝區的消耗。 |
| **Per Peer QP** | 對等點專屬隊列對 | 每個通訊端點 (Peer) 建立專屬的獨立 Queue Pair (QP)。 |
| **LID** (Local Identifier) | 本地識別碼 | InfiniBand 的 Layer 2 (連結層) 位址 (16-bit)，由 SM 動態指派，相當於乙太網的 MAC 位址。 |
| **DLID** (Destination LID) | 目的端 LID | 封包於 L2 標頭 (LRH) 中所填寫的目的端 LID。 |
| **GID** (Global Identifier) | 全域識別碼 | InfiniBand 的 Layer 3 (網路層) 位址 (128-bit，IPv6 格式)，用於跨子網全域路由。 |
| **Multi-SWID** (Multi Switch-ID) | 多重交換器 ID | 在單台實體 InfiniBand 交換機晶片上，虛擬化出多個邏輯交換器介面的技術。 |
| **P_Key** (Partition Key) | 分區金鑰 | 限制特定流量存取的邏輯隔離標籤（類似 Ethernet VLAN，但基於成員金鑰嚴格匹配）。 |
| **FLID** (Floating LID) | 浮動 LID | 用於從本地子網路由到遠端子網分葉交換機 (Leaf Switches) 的動態 LID 機制。 |

## 概述 (Overview)

### 1. 為什麼需要 IB 路由器？
* **管理效率與故障隔離：** 將網路劃分為多個小子網，可顯著縮短子網管理器 (SM) 的計算與掃描回應時間。當單一子網內發生鏈路故障或拓撲變更時，SM 的拓撲重算僅限於該子網，完全不影響其他子網的正常運行。
* **突破叢集規模上限：** InfiniBand 單一子網的 16-bit LID 尋址空間限制了最大節點數（扣除保留位址後約 42,000 ～ 48,000 個端點）。IB 路由器能打破單子網規模上限，支援數萬至數十萬節點的超大型叢集。

### 2. 高效能路由架構
Mellanox IB 路由器採用 **「演算法路由 (Algorithmic Routing)」**。硬體不需要在最後一跳維護並查詢龐大的 L3-to-L2 (GID 到 LID) 對應表，而是直接從 L3 GID 計算出 L2 LID，從而實現**極低延遲**與**全線速 (Wire-speed)** 轉發。

### 3. 當前關鍵限制 (Limitations)
* **僅支援單跳 (Single-hop) 路由：** 兩個子網之間只能經過一台/一層路由器，不支援跨越多個路由器的多跳 (Multi-hop) 轉發。
* **不支援跨子網多播 (Multicast)：** 跨子網目前僅支援單播 (Unicast) 流量。
* **路由器設備能力限制：** 啟用 IB 路由功能的設備（例如 SB7780 交換機）**不能**同時運行嵌入式子網管理器 (Embedded SM) 或 SHARP (網路運算卸載加速)。


## 單跳拓撲 (Single Hop Topologies)

### 1. 支援架構：單跳拓撲 (Single Hop)
兩個子網之間的所有 Layer 3 通訊，必須透過**直連的至少一台 IB 路由器**進行連接：
* **架構：** `Subnet 0` $\longleftrightarrow$ `IB Router` $\longleftrightarrow$ `Subnet 1`。
    ![Single Hop Topology](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnNI&feoid=00N8Z000003jPco&refid=0EM8Z000003DU55)
* 流量從來源子網進入路由器後，下一跳必須直接進入目的子網。

### 2. 不支援架構：多跳拓撲 (Multi-Hop)
當兩個子網沒有透過同一組路由器直接相連，若流量需要經過多個路由器連續跳躍才能抵達：
* **架構：** `Subnet 0` $\longleftrightarrow$ `Router 1` $\longleftrightarrow$ `中間網路/Router 2` $\longleftrightarrow$ `Subnet 1`。
    ![Multi-Hop Topology with Two Subnets L3 routing between these subnets is Not Supported](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnNI&feoid=00N8Z000003jPco&refid=0EM8Z000003DU5F)
* **結論：** 在當前 IB 路由規範下，此類子網之間**不支援** L3 路由通訊。


## 網路拓撲設計 (Network Topology Design)

### 1. 避免信用循環 (Credit-Loop Freedom)
InfiniBand 是無損網路 (Lossless Fabric)，採用基於 Credit（信用額度）的硬體流量控制。若緩衝區路徑形成封閉迴路且資源耗盡，會造成嚴重的**死鎖 (Deadlock)**。
* **子網內部：** 由各子網的 SM 運行 **Up/Dn (上/下)** 演算法，強制規定流量「禁止先下後上 (Down-to-Up)」，以保證信用無環路。
* **跨子網時：** 當多個子網透過路由器互聯時，必須特別注意跨邊界流量造成的循環依賴。可透過精確的階層規劃，或搭配 **虛擬通道 (Virtual Lanes, VL)** 與 **服務等級 (Service Levels, SL)** 來杜絕信用循環。

### 2. 兩種官方推薦拓撲方案
* **方案 A（適用於新建全新叢集）：**
  * 將 IB 路由器部署在所有子網的**最頂端 (Top)**，扮演類似 Core / Super-Spine 的角色。

  ![First optional simple topology place routers at "top"](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnNI&feoid=00N8Z000003jPco&refid=0EM8Z000003DU5P)

* **方案 B（適用於擴充既有叢集，如外接儲存）：**
  
  ![Second optional simple topology place routers at "top" of common subnet and below the old subnets](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnNI&feoid=00N8Z000003jPco&refid=0EM8Z000003DU5U)

  * 將 IB 路由器部署在「新建共用子網（如 Storage Subnet）」的**頂端**，但置於「既有舊子網（如 Compute Subnet）」的**下方**。

### 3. 配置規範要求
* 連接至同一個子網的所有路由器連接埠，必須配置完全相同的 **`subnet_prefix`**。
* 必須部署足夠數量的路由器以滿足跨子網所需的聚合頻寬。
* OpenSM 支援 Fat-tree、Torus 和 Mesh 等多種路由引擎拓撲組合。


## 分區金鑰隔離 (Partitions & P_Key)

即使各子網間存在實體路由器連線，管理員依然可以透過 **P_Key (Partition Key)** 達成嚴格的邏輯隔離：

![P_Key Number Sharing](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnNI&feoid=00N8Z000003jPco&refid=0EM8Z000003DU5e)

### 1. P_Key 跨子網規則
* **必須共享相同 P_Key：** 兩個子網內的節點若要跨路由器通訊，雙方**必須配置相同的 P_Key 數值**。
* **無 P_Key 轉換機制：** IB 規範**不允許**路由器在轉發時改寫或轉換 P_Key（即無法將來源的 `P_Key A` 改為目的地的 `P_Key B`）。

### 2. 典型架構（共享資源與租戶隔離）
* **S1 (核心共享儲存區)：** 同時具備 `P_Key 2` 與 `P_Key 3`。
* **S2 (租戶 A / 運算區)：** 僅配置 `P_Key 2`。
* **S3 (租戶 B / 運算區)：** 僅配置 `P_Key 3`。

**通訊結果：**
* `S1` $\longleftrightarrow$ `S2`：通訊成功（雙方皆持有 `P_Key 2`）。
* `S1` $\longleftrightarrow$ `S3`：通訊成功（雙方皆持有 `P_Key 3`）。
* `S2` $\longleftrightarrow$ `S3`：**完全阻斷**（無共同 P_Key，即使接在同一台實體路由器上也絕對無法通訊）。

> **價值：** 透過單一組實體路由器即可提供多租戶隔離，大幅降低硬體建置成本。

## IP over InfiniBand (IPoIB)

* **核心限制：**
  * IB 路由器是專為 InfiniBand RDMA 原生協定設計的硬體設備，**不會原生轉發 IPoIB 流量**（因為 IPoIB 封裝缺乏演算法路由相容的 GRH 標頭）。
* **解決方案：**
  1. **方案 A（專用乙太網路）：** 額外架設 Out-of-band Ethernet 網路專門處理 IP 業務與管理流量（推薦方案）。
  2. **方案 B（Linux 軟體 IP 路由器）：**
     * 為各 IB 子網分配不同的 IP 網段。
     * 在子網間部署一台配置多張 IPoIB 網卡的 Linux 主機。
     * 開啟 Linux 核心的 IP 轉發（`net.ipv4.ip_forward = 1`），由 Linux 主機代為轉發跨子網的 IP/IPoIB 封包。

## 演算法路由器架構 (Algorithmic Router Architecture)

這是 Mellanox 實現線速低延遲路由的核心機制：

### 1. 設計目標
消除傳統 L3 路由器在轉發末端需要維護並查詢龐大「L3 GID $\to$ L2 LID」對應表的硬體負擔與延遲開銷。

### 2. 核心機制：GID 直接映射 LID
* **傳統方式：** 收到跨網封包後，透過查表或 ARP 機制得知目的 GID 對應的本地 LID。
* **演算法路由：** 直接將目標節點的 L2 地址 (LID) **內嵌** 於 L3 地址 (GID) 中。
  * **GID 格式：** 採用特定可路由 GID 格式（Routable GID）：
    ![Routable GID Format](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnNI&feoid=00N8Z000003jPco&refid=0EM8Z000003DU5j)
    * 前 64 位元：子網字首 (Subnet Prefix)
    * 中間 48 位元：保留位元 (Reserved)
    * **後 16 位元 (16 LSB)：目的端節點的真實 LID**
* **硬體轉發：** 路由器硬體只需直接提取 DGID 的最後 16 位元作為新的 DLID，不需查表即可全速轉發。

[Nvidia | LRH and GRH InfiniBand Headers](https://enterprise-support.nvidia.com/s/article/lrh-and-grh-infiniband-headers)


## IB 路由逐步運作流程 (How does IB Routing Work? A Step-by-Step Description)

**InfiniBand 路由運作原理：逐步流程說明**

### 1. 網路設定 (Network Setup)

在網路建置期間，各子網的 OpenSM 必須為終端連接埠（end-ports）同時分配 LID 與可路由的 GID（Routable GID）。自 2016 年 5 月起，MOFED 解決方案仰賴 `ibacm` 來提供 IP 到 GID 的解析服務。所有終端主機皆需預先發布已填入資料的 `ibacm` 快取，其中包含 IP 對應至可路由 GID 的對照表。名稱至 IP 的解析可透過 DNS 或 `/etc/hosts` 檔案完成，無論採用哪種方式，都必須事先定義名稱與 IP 的對應關係。

為支援上述三項設定作業，MOFED 提供了一套 `ib2ib*` 指令稿。這套機制可用於收集各子網的 GUID 與 IP，並產生 SM 的 `guid2lid`、`ibacm` 快取檔案，以及 `/etc/hosts` 和 `dhcp.db`。

### 2. 名稱解析 (Name Resolution)

如前所述，名稱至 IP 的解析可經由 DNS 或 `/etc/hosts` 檔案來完成。


### 3. 連線建立 (Connection Establishment)

取得目的端的 IP 後，應用程式應呼叫 `librdmacm`；接著該程式會進一步使用 `ibacm` 服務，或者當核心已具備掛鉤（hook）機制時，也會呼叫 `ibacm` 進行解析。連線請求（Connection Request）中所提供的資訊，必須包含從本地來源端 HCA 埠、穿過路由器、最後抵達目的地主機埠的 PathRecord。因此，解析的第一步是找出目的地的可路由 GID，接著找出轉發流量所需的路由器 L2 位址。

完成解析後，系統會向遠端節點的連線管理員（CM，透過 QP1）發送連線請求以啟動連線。位於另一子網節點上的連線管理員（CM），通常會要求在連線請求中夾帶從該節點返回發起節點的反向 PathRecord。然而，當發起端連接埠與 CM 節點不在同一個子網時，實際上會略過這些欄位，改為直接使用封包標頭（packet headers）中所提供的資訊，因此不需要額外提供反向 PathRecord。

### 4. IP 至 GID 位址解析 (IP to GID Address Resolution)

在 2016 年 5 月版本中，IP 到 GID 的解析是基於 `ibacm` 快取完成的。快取檔案已於設定階段產生並發派至叢集中的所有節點。當呼叫 `librdmacm` 時，它會優先呼叫 `ibacm` 執行解析，隨後 `ibacm` 會在其快取中查詢對應的 IP 至 GID 記錄。

### 5. 下一跳（L2）位址解析 (Next Hop (L2) Address Resolution)

在發送任何 InfiniBand 流量之前，用戶端應用程式或核心模組必須取得一筆描述目的地 L2 位址的 PathRecord。PathRecord 是透過提供來源端與目的端 GID，向子網管理代理（SA, Subnet Administrator）查詢取得。

此處至關重要的是，所提供的目的端 GID（Destination GID）必須包含目的地的子網前綴（Subnet Prefix）以及其 GUID。具備路由器支援功能的 OpenSM 會檢查可連接至目的端子網的可用路由器，並可進一步依據路由器策略檔（Router policy file）或 PathRecord 查詢中指定的條件進行篩選。例如，若查詢中指定了特定的 P_Key，則僅允許經由在兩端子網連接埠上皆支援該 P_Key 的路由器進行轉發。接著，SM 會執行以目的地為基準的路由（destination-based routing），在候選路由器中選出負責轉發流量的節點，並將該路由器的 LID 作為 DLID 填入回傳的 PathRecord 中。

### 6. 將可路由流量發送至網路 (Sending Routable Traffic to the Network)

發送流量時必須附帶正確的可路由 SGID，以便位於路由器另一端的接收節點能夠查詢 PathRecord 並進行回覆。InfiniBand 規範提供了讓 SM 為每個連接埠配置子網前綴的機制，同時也允許 SM 將多個 GUID 關聯至同一個連接埠。

問題在於：設備在發送封包時，如何得知該使用哪一個 GUID？答案是：為了讓 `librdmacm` 與其他核心用戶端能套用正確的 GUID，我們必須在設定階段將該 IB 埠的 IPoIB 與特定的可路由 GID 建立關聯。

### 7. 經由路由器轉發 (Forwarding Through the Router)

在單跳路由（single-hop routing）架構下，路由器本身僅需執行最基礎的處理工作：將封包的 DLID 替換為最終目的地的 DLID，而該目的地 DLID 可直接從封包全域路由標頭（GRH, Global Route Header）中的 DGID 擷取出來。