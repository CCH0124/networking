# Unified Fabric Manager

### 為什麼需要 UFM？（小規模實驗 vs. 大規模生產）

| 評估維度 | 傳統 CLI 模式（無 UFM） | 現代化平台模式（導入 UFM） |
| --- | --- | --- |
| **主要工具** | 仰賴指令工具（`ibstat`、`ibnetdiscover`、`opensm` 等）手動排查。 | 單一 Web 集中式儀表板（UFM Enterprise GUI）。 |
| **配置方式** | 各節點手動修改設定檔、撰寫零碎腳本，維護成本高。 | 集中化自動配置、規則範本化下發與版本控管。 |
| **維運模式** | **被動排查（Reactive）**：故障發生後才 SSH 登入個別設備除錯。 | **主動與預測（Proactive & Predictive）**：異常預警、趨勢分析。 |
| **適用規模** | 2～10 個節點的小型實驗室、概念驗證（PoC）。 | **100+ 節點以上、上千張 GPU 的大規模 AI / HPC 叢集**。 |

---

### NVIDIA UFM 的官方定義與核心價值

* **官方定義**：UFM 是 NVIDIA 針對高效能網路 Fabric（包含 InfiniBand 與 AI 乙太網）設計的**集中化監控、管理與最佳化平台**。
* **機場塔台比喻（Airport Control Tower Analogy）**：
  * **機場塔台**：透過雷達追蹤飛機位置、高度與速度，引導起降、防止相撞、預警突發氣候風險。
  * **UFM 平台**：監控全網伺服器（HCA）、交換器與實體光纖線路，即時追蹤延遲、壅塞與硬體錯誤（BER），動態調度流量、防止死鎖與封包遺失。
---

### UFM 帶來的 7 大核心效益

1. **全網可視化（Full Fabric Visibility）**：提供從最底層的主機 HCA 網卡、Leaf 交換器到頂層 Spine 的端到端實體與邏輯拓撲視圖。
2. **加速故障排查（Faster Troubleshooting）**：集中告警儀表板，點擊即可精確定位到具體故障的實體 Port、異常線纜或特定節點。
3. **遙測與效能監控（Telemetry & Performance Monitoring）**：即時收集全網吞吐量、封包計數、壅塞計數（如 `PortXmitWait`）與流量熱點。
4. **AI 驅動的預測性分析（Predictive Analysis / UFM Cyber-AI）**：利用機器學習建立網路基線，能在光纖訊號劣化、封包誤碼率上升但尚未徹底斷線前提早發出更換預警。
5. **多租戶與邏輯隔離（Multi-Tenancy & Isolation）**：配合 Partition Key (P_Key) 與 QoS 規則，直觀劃分不同 AI 訓練任務與租戶邊界。
6. **自動化維運與權限控管（Automation & Control）**：提供 REST API 整合叢集調度器（如 Slurm、Kubernetes），並具備基於角色的存取控制（RBAC）。
7. **彈性擴展管理（Scale Management）**：支援叢集在無中斷狀態下平滑擴展節點與交換器。

### UFM 產品體系架構概覽（考試常考架構分類）

在實際部署中，UFM 通常劃分為以下層級版本：

  * **UFM Telemetry**：專注於高頻率硬體數據採集，透過 REST API / Prometheus 匯出遙測指標。
  * **UFM Enterprise**：內建完整的 OpenSM 子網管理器、拓撲可視化 GUI、P_Key/QoS 管理與自動化維運功能。
  * **UFM Cyber-AI**：頂級智慧模組，專注於利用演算法進行網路安全異常檢測、微小退化預警與大象流模式分析。

## UFM Architecture

### UFM 核心三層分層架構

依據架構圖，UFM 平台可切分為清楚的「南北向三層結構」：

```text
  [ 上層：使用者介面、生態整合與可觀測性系統 ]
   • Web-based GUI  • Python SDK  • Slurm / K8s / Azure / OpenStack
   • Observability: Fluentbit / Syslog / SNMP / E-mail
                             ^
                             | (Northbound REST APIs)
  +--------------------------|------------------------------------+
  | UFM Server Software                                           |
  |  +---------------------+ +------------------+ +---------------+ |
  |  | InfiniBand Perf     | | Subnet Manager   | | Aggregation   | |
  |  | Monitoring (IBPM)   | | (SM)             | | Manager       | |
  |  | Software            | |                  | | (SHARP)       | |
  |  +---------------------+ +------------------+ +---------------+ |
  +---------------------------------------------------------------+
                             |
                             v (MAD / Southbound IB Management)
  [ 底層：實體受控資源 (Fabric Infrastructure) ]
   • RDMA Network Adapters (HCAs)   • MLNX-OS Switches
   • Externally Managed Switches    • Compute / Storage Servers

```

---

### UFM 內部三大核心引擎（中間主體）

UFM 伺服器軟體並非單一工具，而是將大型 AI/HPC 叢集所需的三大控制模組高度整合：

1. **Subnet Manager (SM)**

  * 內建高效能子網管理器，取代零散手動維運的獨立 OpenSM。
  * 集中負責拓撲掃描、LID 指派、LFT 轉發表計算、QoS 與 P_Key 隔離原則派送。

2. **InfiniBand Performance Monitoring (IBPM) 軟體**

  * 高頻率收集全網交換器與網卡暫存器指標（Throughput、Packet Rate、BER 誤碼率、`PortXmitWait` 壅塞等待計數等）。


3. **Aggregation Manager (SHARP)**

  * 負責管理 NVIDIA 的 **In-Network Computing（網路內運算）** 技術——**SHARP (Scalable Hierarchical Aggregation and Reduction Protocol)**。
  * 在 AI 模型訓練進行跨節點 AllReduce 梯度聚合時，直接由交換器晶片硬體完成數值累加，大幅降低 GPU 間的往返資料量與同步時間。



---

### 北向整合介面與生態系串接（Northbound Integration）

UFM 具備豐富的對外開放能力，能融入現代雲端與企業現有的維運體系中：

* **人機操作介面**：
  * **Web-based GUI**：直觀視覺化儀表板，支援拓撲地圖檢視、節點即時狀態、流量熱點圖形化。
  * **Python SDK & REST APIs**：提供完整的北向 API，方便自動化腳本調用與自訂工具開發。

* **既有監控與日誌整合（Observability）**：
  * **Fluentbit**：收集遙測與指標日誌並轉發至 Elastic / Prometheus 等平台。
  * **Syslog & SNMP Trap**：即時發送硬體異常、鏈路斷線告警至傳統資料中心網管中心。
  * **E-mail**：關鍵故障即時郵件通報。

* **雲端與作業調度排程整合（Job Scheduler / Cloud Integration）**：
  * **Slurm & Platform LSF**：與 HPC/AI 作業調度器無縫聯動，作業啟動時可動態查詢 UFM 拓撲資訊，將任務優先排程在距離最近、無壅塞的交換器樹狀路徑上。
  * **Kubernetes / OpenStack / Azure**：支援容器化環境與雲端平台的租戶網路隔離與多租戶配額控管。


---

### 南向納管的實體資源（Bottom Resources）

UFM 向下相容並能同時統一管理多元的 Fabric 硬體設備：

* **RDMA Network Adapters (HCAs)**：監控伺服器端 ConnectX 網卡的鏈路速率、韌體版本與溫度。
* **內部管理型交換器（Switches with MLNX-OS）**：具備本機作業系統與管理 CPU 的交換器。
* **外部管理型交換器（Externally Managed Switches）**：不帶管理 CPU 的純 ASIC 交換器（通常為未託管型或刀鋒模組），由 UFM 伺服器集中接管其控制邏輯。
* **運算與儲存伺服器（Standard Servers）**。

## UFM Platform Capabilities

### UFM 三大版本功能階層關係

三個版本並非互相孤立，而是呈現「包容遞進」的堆疊架構：

```text
    +-------------------------------------------------------------+
    |                    UFM Cyber-AI (頂配版)                    |
    |  • 包含 Telemetry 監控 + Enterprise 控制管理                 |
    |  • 加入 AI/ML 預測性分析、早期故障預警與網路安全異常威脅偵測   |
    +-------------------------------------------------------------+
                                   ^
                                   | 疊加
    +-------------------------------------------------------------+
    |                    UFM Enterprise (標準旗艦)                 |
    |  • 包含 Telemetry 基礎監控                                  |
    |  • 加入 Web GUI、內建 Subnet Manager、QoS/P_Key 管理與自動化|
    +-------------------------------------------------------------+
                                   ^
                                   | 疊加
    +-------------------------------------------------------------+
    |                    UFM Telemetry (輕量基礎版)               |
    |  • 專注高頻率底層遙測資料採集 (頻寬、錯誤計數、壅塞指標)     |
    |  • 透過 REST API / Fluentbit 串接既有監控平台 (Prometheus等)|
    +-------------------------------------------------------------+

```

---

### 三大版本深度橫向對比

| 版本名稱 | 核心定位與功能 | 部署方式 | 適用場景 / 考試關鍵字 |
| --- | --- | --- | --- |
| **UFM Telemetry** | **純監控與數據採集**<br> 高頻率即時採集計數器<br> 不提供控制面配置與 Web GUI | Linux 主機直接安裝<br> Docker 容器化部署 | **只要遙測數據（Just Telemetry）**<br> 企業已建置成熟的 Prometheus/Grafana 監控體系，僅需 IB 數據匯流排。 |
| **UFM Enterprise** | **可視化、集中控制與管理**<br>整合 Web GUI 儀表板<br>內建 Subnet Manager、SHARP 管理<br> 支援 High Availability (HA) 容錯移轉 | Linux 主機直接安裝<br>Docker 容器化部署<br> 實體專屬硬體設備（Appliance） | **網路可視化與自動化控制（Visibility & Control）**<br>100+ 節點以上、需要單一入口集中管理拓撲、P_Key 與 QoS 的 AI/HPC 資料中心。 |
| **UFM Cyber-AI** | **智慧分析與安全偵測**<br> 整合 Enterprise 全套功能<br>內建 AI/ML 演算法建立全網行為基線<br> 纜線物理退化預測、微小異常通報<br> 網路安全威脅與異常流量偵測 | **專用硬體設備（Appliance Only）**<br>*(即插即用、預先調優)* | **AI/ML 預測分析與威脅偵測（Predictive Analytics & Threat Detection）**<br>超大規模 AI 超級叢集，需在硬體完全斷線前主動預測並更換問題組件。 |

---
### 部署模式補充：實體硬體設備（Appliance）與高可用（HA）

* **軟體部署 vs. 硬體設備**：
  * **軟體/Docker 模式**：彈性高，直接部署在現有 Linux 節點上（如講者的測試環境）。
  * **Appliance 專屬硬體模式**：開箱即用、硬體效能經過官方認證與調校，對於運算資源要求極高的 Cyber-AI 模組，硬體專屬設備能確保分析演算法不佔用一般伺服器算力。


* **高可用性（High Availability, HA）**：
  * UFM Enterprise 支援 Active/Standby HA 架構。
  * 透過內部的 DRBD 或心跳機制，當主節點當機時，備援節點能立即接管 Web 服務與 Subnet Manager，確保 Fabric 的轉發控制不中斷。

[Nvidia | ufm](https://www.nvidia.com/en-gb/networking/infiniband/ufm/)

## UFM Traffic Map

### 解讀 UFM Traffic Map 的 4 階層架構（4-Tier Network Flow）

![](https://resource.fs.com/mall/generalImg/20240510114948q5ibxu.jpg)

在標準的 Fat-Tree（Leaf-Spine）拓撲中，UFM 將整個端到端的封包路徑精確拆解為四個傳輸階段（Tiers）：

```text
                  [ Spine 交換器層 ]
                     ^          |
    (上行 Tier 2)   /            \   (下行 Tier 3)
                   /              v
                  [ Leaf 交換器層 ]
                     ^          |
    (上行 Tier 1)   /            \   (下行 Tier 4)
                   /              v
                  [  運算主機 (Host) ]

```

| 階層 (Tier) | 流量流向 | 實體意義與瓶頸判斷 |
| --- | --- | --- |
| **Tier 1** | **Host $\rightarrow$ Leaf** | **運算節點上行流量**：伺服器將資料送入第一層接入交換器。若此處壅塞，通常代表主機端 HCA 發送速率過載或線纜協商降速。 |
| **Tier 2** | **Leaf $\rightarrow$ Spine** | **叢集跨交換器上行流量**：Leaf 交換器將跨 Rack 流量打往核心 Spine。**如圖片所示，此處出現紅色壅塞（Congestion）**，代表多個 Leaf 的上行鏈路頻寬不足，或發生了大象流雜湊碰撞。|
| **Tier 3** | **Spine $\rightarrow$ Leaf** | **核心下行收斂流量**：Spine 將資料分流派送回目標節點所在的 Leaf。此處若壅塞，代表多個節點同時向同一台 Leaf 交換器回傳資料（Many-to-One 聚集）。 |
| **Tier 4** | **Leaf $\rightarrow$ Host** | **終端節點下行流量**：Leaf 將封包送達目標伺服器。此處通常不易塞車，除非目標主機記憶體或 PCI 接收頻寬飽和（Incast 瓶頸）。 |

> **圖表色彩解讀**：
> * **綠色長條（Traffic）**：表示該層級的頻寬利用率（包含 Min、Avg、Max）。
> * **紅色長條（Congestion）**：表示該層級當前的壅塞嚴重度。從範例中可一眼看出問題集中在 **Tier 2 與 Tier 3（骨幹 Spine 鏈路）**，而邊緣節點（Tier 1/4）則完全通暢。
> 

---

### UFM 儀表板核心元件解析

除了 Traffic Map 之外，UFM Enterprise 首頁整合了即時維運所需的關鍵儀表盤：

1. **資產清單與狀態（Inventory & Severity）**：
* 統計全網 HCAs、Switches、Cables、Gateways 與 Routers 數量。
* 依照狀態標註顏色：Info（綠）、Warning（黃）、Minor（橘）、Critical（紅）。


2. **Top 5 關鍵排行矩陣**：
* **Top 5 Servers / Switches By Bandwidth**：抓出頻寬佔用最高的機器與交換器埠口（定位潛在大象流）。


* **Top Congestion Servers / Switches**：列出 `PortXmitWait` 或排隊延遲最嚴重的熱點設備。
* **Top Utilized P_Keys**：監控各租戶/分區（Partition Keys）的資源消耗佔比。


3. **即時動態與日誌（Recent Activities）**：
* 滾動顯示硬體狀態變更事件（如電源模組狀態 `PS status is fatal`、風扇轉速異常、新 Multicast 群組建立等）。


4. **時光回溯拉桿（Time Slider）**：
* 位於儀表板頂端，可拖曳回溯過去數小時或數天前的網路狀態，以利在事後復盤訓練作業當機或延遲異常時的當下網路表現。


---

### 左側主導航選單功能分類

| 選單項目 | 功能與管理範疇 |
| --- | --- |
| **Dashboard** | 首頁即時健康度、Traffic Map 與 Top 5 監控看板。 |
| **Network Map** | 互動式全網實體拓撲圖，可展開機架、交換器並檢視各 Port 連線狀態。 |
| **Managed Elements** | 實體設備庫（交換器、伺服器 HCA、模組、光纖線纜）的細部狀態與韌體版本管理。 |
| **Logical Elements** | 邏輯面配置：P_Key 分區劃分、QoS 規則、Virtual Lanes 與 Multicast 群組管理。 |
| **Events & Alarms** | 告警閥值規則設定、未解除警報清單與歷程記錄。 |
| **Telemetry** | 即時與歷史計數器視覺化圖表（吞吐、延遲、錯誤封包）。 |
| **Jobs** | 與排程器（如 Slurm）聯動的作業拓撲關聯監控。 |
| **Settings** | 系統帳號權限（RBAC）、HA 高可用性、外接 Syslog/SNMP 與 API Token 設定。 |

## UFM Message

### UFM 常見核心告警與處置對照表

| UFM 告警訊息 (Alert) | 核心成因與物理意涵 (What it Means) | 標準處置與排除步驟 (Typical Resolution) |
| --- | --- | --- |
| **Link Down / Port Down** | 實體線路故障或中斷<br> 線纜鬆脫、損壞<br>管理員手動關閉埠口（Admin Down） | 1. 檢查本機實體線纜與連接埠狀態。<br>2. 檢查對端設備（Remote Device）開機與介面狀態。<br>3. 若為人為 Administrative Down，執行介面啟用（`no shutdown`）。 |
| **High Symbol Error Rate**<br>*(例: Symbol Error Counter High on port 1/17)* | **訊號完整性異常（Signal Integrity Issue）**<br>光纖線纜老化、彎折或污染<br>光學收發模組（Transceiver/Optics）異常<br> 電磁干擾（Interference） | 1. **軟體調整無效**，必須從實體層處理。<br>2. 測試鏈路品質（Link Quality）。<br>3. 直接**更換故障線纜或光學收發模組**。 |
| **Congestion / High Port Utilization** | • 流量瓶頸引發佇列堆積、延遲暴增與效能下降<br> 發生大象流碰撞或多對一匯聚（Incast） | 1. 重新調整負載平衡策略（Balance Traffic）。<br>2. 切換或調整路由演算法（如啟用 Adaptive Routing）。<br>3. 針對擁塞層級（如 Tier 2/3）擴充上行實體頻寬。 |
| **SM (Subnet Manager) Not Active / Flapping** | 無穩定運作的 Active Subnet Manager<br> 主備 SM 搶佔主控權造成震盪（Flapping）<br> 承載 SM 的節點作業系統或連線異常 | 1. 確保全網**僅存在單一 Active SM**。<br>2. 檢查各節點 OpenSM 的優先級（`sm_priority`）配置。<br>3. 檢查 UFM HA 高可用機制心跳與容錯切換配置。 |
| **Wrong Neighbour** | 線纜插錯非預期的交換器或節點埠口<br>透過 LLDP/GUID 偵測發現實體連線與規劃拓撲檔不符 | 1. 調閱基準拓撲檔案（Topology Config File）。<br>2. 對比實際布線與拓撲規劃，修正實體跳線對應（Correct Mapping）。 |

### 實務排查高頻考點

1. **High Symbol Error Rate 的不可調和性**：
  * 若出現 Symbol Error、Bit Error Rate (BER) 暴增，**任何調整路由參數、重算 LFT、微調 QoS 的軟體手段皆無法根治**，正確答案皆為**更換實體光纖線纜或光模組（Replace Cable / Transceiver）**。

2. **Wrong Neighbour 的偵測機制**：
  * UFM 主要利用 **LLDP (Link Layer Discovery Protocol)** 與設備回報的 **GUID** 進行鄰居識別，並與預先匯入的拓撲定義檔進行 Diff 比對。

3. **SM Flapping 的核心防護**：
  * 當叢集內多個 SM（例如交換器內建 SM 與主機端 OpenSM）設定相同優先權時，容易引發頻繁的 Master 選舉震盪，必須透過明確的 `sm_priority` 數值將主備分級。

## RBAC

### RBAC 的核心運作機制

RBAC 遵循三層式的授權模型，**不直接將權限賦予使用者**：

```text
+-------------------+      +-------------------+      +-------------------+
|  1. 定義角色      | ---> |  2. 關聯細部權限  | ---> |  3. 將使用者綁定角色 |
|     (Roles)       |      |   (Permissions)   |      |      (Users)      |
+-------------------+      +-------------------+      +-------------------+
(例: Operator, Admin)      (例: ~311 個 API 權限)        (例: Ash 取得 Operator)

```

1. **定義角色（Define Roles）**：依照工作職責建立角色（如 Admin、Operator、Viewer 等）
2. **分配權限（Assign Permissions to Roles）**：UFM 內建約 300+ 項細部 API 與介面權限，針對每個角色明確指定 `Allow` 或 `Deny`。
3. **使用者指派（Assign Users to Roles）**：在使用者管理介面中建立帳號（如 Ash），並將特定角色綁定給該使用者。



---

### 為什麼 RBAC 對 InfiniBand / UFM 至關重要？

在大型 AI/HPC 資料中心中，InfiniBand 是整個運算叢集的通訊命脈，實施 RBAC 具有三大不可替代的價值：

* **安全性（Security）**：防止未授權的人員變更關鍵網路配置（如關閉連接埠、修改拓撲）。
* **穩定性（Stability）**：避免因人為誤操作導致全網動盪。若一般維運人員誤改了**路由演算法（Routing Engine）、分區金鑰（P_Key）或 QoS 仲裁權重**，可能直接引發全網重算（Heavy Sweep）、Credit Loop 死鎖或線上 AI 訓練作業集體中斷。
* **多租戶受控存取（Multi-Tenancy）**：讓不同的業務團隊或租戶僅能檢視與其自身運算作業相關的邏輯分區與儀表板，無法跨越邊界干預其他租戶的硬體資源。



---

### UFM Enterprise 4 大預設內建角色

在 UFM 的 `Settings -> REST Roles Access Control` 介面中，系統預先定義了 4 種開箱即用的權限角色：

| 預設角色名稱 | 權限範圍與定位 | 典型適用對象 |
| --- | --- | --- |
| **Monitoring Only** | 純唯讀檢視權限。僅能瀏覽儀表板、Traffic Map、計數器與警報，無法下發任何指令或配置。 | 外部監控人員、L1 輪班值勤人員。 |
| **Fabric Operator** | 日常維運權限。可查看全網拓撲與日誌，執行受限的診斷操作（如重置部分計數器、檢視特定纜線狀態），但不可更改核心網路原則。 | 負責日常機房硬體維護與告警確認的網路工程師。 |
| **Fabric Admin** | 網路層級最高管理員。可完整配置 Subnet Manager、變更路由演算法、調整 QoS/SL2VL 映射表與劃分 P_Key 分區。 | 核心 InfiniBand 網路架構師與資深網管。 |
| **System Admin** | 系統與平台層級管理員。除了網路管理外，還具備 UFM 系統本身的帳號管理（RBAC）、HA 高可用性設定、備份還原與系統升級權限。 | 資料中心系統架構師、UFM 平台管理員。 |

---

### 介面實務配置工作流程

1. **檢視與自訂角色**：進入 `Settings` $\rightarrow$ `REST Roles Access Control`，可查看各預設角色允許/拒絕的 API 清單，亦可自訂包含特定 API 子集的新角色。
2. **建立與授權使用者**：切換至 `User Management` $\rightarrow$ 點擊 `Add User`，輸入使用者名稱（如 `Ash`）與密碼，並從下拉選單中指派相應的角色（如 `Fabric Operator`）。
3. **驗證隔離效果**：該使用者登入後，其 Web GUI 導航選單與操作按鈕將依照權限自動過濾，無權操作的項目（如修改 QoS 或 P_Key）將直接隱藏或呈現唯讀狀態。


