# Troubleshotting InfiniBand
## Troubleshooting Issues


排查體系依層級（由上而下：應用層到最底層實體線纜）劃分為兩大工具陣營：

1. **開源標準工具（Common OS Utilities / Upstream）**：源自 Linux OFED / OpenFabrics 標準庫的原生開源工具。
2. **NVIDIA / Mellanox 專屬工具（Downstream）**：由原廠基於硬體 ASIC、驅動與 GPU 架構進行深度客製化與擴展的高階診斷套件。

---

### InfiniBand 7 層故障排查堆疊對照全表

| 階層 (Layer) | 常見 OS 原生工具 (Upstream) | NVIDIA / Mellanox 專用工具 (Downstream) | 排查目標與核心功能 |
| --- | --- | --- | --- |
| **1. Application**<br>*(上層應用)* | **Application logs**<br>*(框架/排程器原生日誌)* | **NCCL tests**<br>**DCGM** (Data Center GPU Manager)<br>**UFM dashboards** | 檢驗分散式 AI 訓練通信、GPU 健康狀態、PCIe/NVLink 吞吐與全網綜合看板。 |
| **2. RDMA**<br>*(傳輸效能)* | **`ib_write_bw`** (頻寬測試)<br>**`ib_write_lat`** (延遲測試) | **NCCL performance tests**<br> **UFM telemetry** | 驗證節點間 RDMA 讀寫極限頻寬、微秒級延遲，以及集合通訊（AllReduce）效率。 |
| **3. Fabric**<br>*(全網拓撲)*| **`ibdiagnet`** (全網健康掃描)<br>**`ibtracert`** (路徑追蹤)<br>**`ibnetdiscover`** (拓撲發現)<br>`ibnodes`, `ibhosts`, `ibswitches` | **UFM**<br>*(Topology 視圖、Path Analysis 路徑分析、即時 Telemetry 遙測)* | 探索全網交換器與主機連接關係、追蹤封包路由走向、定位全網壅塞與死鎖節點。 |
| **4. Subnet Manager**<br>*(控制平面)* | **`sminfo`** (查詢 Active SM)<br>**`smpquery`** (查詢暫存器/LFT/SL2VL)<br> **`saquery -s`** (查詢 Subnet Admin 屬性) | **UFM**<br>*(內建 SM 監控、HA 容錯移轉與原則控制)* | 確認 Master SM 所在節點、優先級（`sm_priority`）、路由演算法配置與子網健康狀態。 |
| **5. HCA**<br>*(網卡端點)* | **`ibstat`** (檢視連接埠狀態/LID)<br>**`ibv_devinfo`** (檢視韌體/支援的 VL 數量) | **`nvidia-smi`** *(部分網卡資訊)*<br> **`mlxconfig`** *(查詢與燒錄網卡硬體韌體參數)* | 確認 HCA 實體埠狀態（`Active` / `Down`）、PCIe 速度、韌體版本與硬體 RoCE/IB 模式切換。 |
| **6. Link**<br>*(鏈路狀態)* | **`iblinkinfo`**<br>*(查詢全網所有埠的寬度與速率)* | **`mlxlink`** (進階訊號診斷)<br> **UFM** (鏈路測試) | 檢查鏈路協商速率（如 NDR 400G、HDR 200G）、是否發生降速（4X 降至 1X）或閃斷。 |
| **7. Cables**<br>*(實體線纜)* | **None**<br>*(開源工具無法直接讀取光學模組底層暫存器)* | **`mlxlink`** | 讀取光纖收發器（Transceiver）溫度、光功率（Tx/Rx Power）、誤碼率（BER）與眼圖品質。 |

---

### 實務排查重點

1. **實體線纜層（Cables）的排他性**：
  * 在開源 Upstream 體系中，**沒有任何開源工具能直接診斷光學線纜的物理指標（顯示為 None）**。
  * 若詢問如何查看光纖線纜收發光功率、溫度或誤碼率，正確為 NVIDIA 專屬工具 **`mlxlink`**。

2. **AI 集合通訊排查利器**：
  * 通用 RDMA 測試使用 `ib_write_bw`，但在 NVIDIA GPU AI 叢集中，定位 GPU 通訊瓶頸必須仰賴 **NCCL Performance Tests（如 `all_reduce_perf`）** 與 **DCGM**。


3. **全網全域診斷首選**：
  * 在 CLI 環境下全面掃描 Fabric 錯誤計數（如 `SymbolErrors`、`PortXmitWait`）的首選工具為 **`ibdiagnet`**。

* 在圖形化集中維運環境下，則透過 **UFM Topology 與 Telemetry** 進行端到端關聯排查。

## Performance Issues

### 效能排查核心速查表

| 症狀 / 問題 (Symptom / Issue) | 推薦使用指令 | 檢查重點與合格標準 (What to Check) | 指令語法 (Command Syntax) |
| --- | --- | --- | --- |
| **需驗證 RDMA 吞吐量**<br>*(確保網路未成為 AI 訓練瓶頸)* | **`ib_write_bw`** | 測量兩端點間的 RDMA Write 頻寬。<br> 觀察是否達到**接近實體線速（Near-line-rate）**。<br> 檢視不同 SL（Service Level）下的頻寬劃分。 | **Server 端**：<br>`ib_write_bw`<br>**Client 端**：<br>`ib_write_bw -d <device> <server_ip>` |
| **需驗證端到端點對點延遲**<br>*(新設備上線或延遲敏感型任務)* | **`ib_write_lat`** |測量**奈秒級（Nanosecond）的 RDMA Write 延遲。<br>驗證是否符合次微秒級（Sub-microsecond，通常 < 1 µs）**標準。 | **Server 端**：<br>`ib_write_lat`<br>**Client 端**：<br>`ib_write_lat -d <device> <server_ip>`|

---

### 工具運作機制與實務參數詳解

#### `ib_write_bw`（RDMA 頻寬壓力測試）

* **運作模式（Client-Server）**：
    1. 伺服器端先執行 `ib_write_bw` 開啟接聽佇列。
    2. 客戶端透過乙太網路（TCP/IP）進行初始交握（Data Exchange），交換彼此的 QP（Queue Pair）資訊與 Key。
    3. 隨後直接繞過作業系統核心與 TCP 協定棧，在 InfiniBand 鏈路上進行純硬體零拷貝（Zero-copy）RDMA 封包傳輸。


* **高階常用參數**：
* `-d <dev>`：指定實體 HCA 裝置名稱（如 `mlx5_0`、`mlx5_1`）。
* `-i <port>`：指定 HCA 卡上的實體連接埠編號（如 `-i 1`）。
* **`-s <SL>`**：**指定 Service Level 標籤（0~15）**。此參數極其關鍵，可用於實地打流驗證上一章節配置的 `qos_sl2vl` 與 `qos_vlarb_high` 頻寬切分是否真正生效。
* `-F`：關閉 CPU 頻率告警（Fail if CPU freq changes）。
* `-q <num>`：設定平行傳輸的 QP 數量（Queue Pairs），模擬多流高負載併發。

####`ib_write_lat`（RDMA 奈秒級極限延遲測試）

* **測試指標**：
  * 主要關注 `Typical / Average Latency`（平均延遲）與 `Percentiles`（P99/P99.9 長尾延遲）。
  * 在健康的 HDR (200G) / NDR (400G) InfiniBand 網路中，單跳點對點 RDMA 延遲應穩定維持在 **600ns ~ 800ns（次微秒 sub-microsecond）** 範圍內。
  * 若延遲跳升至數微秒（µs）以上，通常代表中途存在交換器轉發擁塞、PCIe 匯流排插槽速率協商不全（如掉到 Gen3 或 x4），或是光纖跳線存在誤碼。

## Connectivity Issues

### 連線問題核心指令速查表

| 症狀 / 問題 (Symptom / Issue) | 推薦使用指令 | 檢查重點與診斷指標 (What to Check) | 標準語法範例 (Command Syntax) |
| --- | --- | --- | --- |
| **懷疑全網連線問題，需全網完整健康報告** | **`ibdiagnet`** | 全網錯誤計數器收集（Performance Counters）<br>交換器與 HCA 設備配置傾印<br>路由規則驗證（Unicast / Adaptive / Multicast） | `ibdiagnet --pc --pm`<br>*(常用參數：`-pc` 重置/檢查計數器，`-pm` 檢查效能計數)* |
| **特定兩節點間傳輸緩慢，懷疑路徑非最優（Suboptimal Path）** | **`ibtracert`** | 追蹤來源端到目標端的**逐跳（Hop-by-Hop）轉發路徑**<br> 定位中途經過的交換器 LID、輸出埠號與瓶頸鏈路 | `ibtracert <src_lid> <dst_lid>` |
| **需驗證基本的節點間 IB 雙向連通性** | **`ibping`** | 透過發送 **MAD（管理數據包）** 驗證目標端回應<br>驗證 SM 轉發路由是否通暢、延遲是否穩定 | **Server 端**：`ibping -S`<br>**Client 端**：<br>`ibping -L <dest_lid>`<br>`ibping -G <dest_guid>` |
| **連接埠卡在 Initializing 狀態**<br>*(Base LID = 0 且 SM LID = 0)* | **`ibstat`** | 檢查 `State`（應為 Active）、`Physical state`（LinkUp）<br> 若 `State: Initializing` 且 `SM lid: 0`，代表**全網無正在運作的 Subnet Manager** | `ibstat -d <device>` |
| **需確認哪台伺服器正擔任 Master Subnet Manager** | **`sminfo` + `smpquery**` | **步驟 1**：取得 Master SM 的 LID、GUID、優先級（Priority）與狀態。<br>**步驟 2**：將 SM LID 解析為人類可讀的主機名稱/節點描述符（Hostname / Node Description）。| `sminfo` 取得 LID 後執行：<br>`smpquery nodedesc <lid>`<br>*(或縮寫 `smpquery ND <lid>`)* |
| **新伺服器接入交換器，需映射新連接埠、LID 與鏈路速率** | **`ibnetdiscover`** | 執行全網拓撲深度掃描：收集 GUID、LID、Port 編號、鏈路速率（如 QDR、HDR、NDR）。<br> 清楚列出「哪台交換器的哪個實體埠」連接到「哪台主機的哪個 HCA 埠」。 | `ibnetdiscover`<br>`ibnetdiscover -p` *(僅輸出埠口連接列表)*|
| **擴充 Fabric 後，需快速清點節點與交換器總數** | **`ibnodes`** | 條列全網所有具備 LID 的設備（包含 HCA 運算節點、交換器、路由器）。<br> 驗證預期上線的新硬體是否全部成功加入 Fabric。 | `ibnodes` |
| **快速統計/過濾主機節點** | **`ibhosts`** |僅條列 Channel Adapters（HCAs，伺服器主機端），過濾掉交換器。<br>檢查主機 HCA 埠數量與 GUID。 | `ibhosts` |
| **快速統計/過濾交換器設備** | **`ibswitches`** | 僅條列交換器晶片（Switches），顯示每台交換器的實體埠總數（如 36-port、64-port）與交換器 LID。 | `ibswitches` |

---

### 指令實作要點與機制詳解

#### 1. `ibdiagnet`（全網綜合健康體檢）

* **運作模式**：自動掃描子網內的所有節點，產生詳細的報告檔案（預設存於 `/var/tmp/ibdiagnet2/`）。


* **關鍵產出檔案**：
  * `ibdiagnet2.log`：總體執行日誌與警告（Warnings / Errors）。
  * `ibdiagnet2.pm`：交換器與 HCA 的 Port Counters（包含丟包、FEC 誤碼、`PortXmitWait` 等）。
  * `ibdiagnet2.netdump`：全網實體拓撲連線明細。

#### 2. `ibtracert`（LID 路由路徑追蹤）

* **運作特性**：
  * 類似乙太網的 Traceroute，但**直接基於 InfiniBand LID 進行查詢**。
* **任意節點查詢**：查詢者**不需要**位於來源節點或目標節點上，可在 Fabric 內任意一台機器上發出指令，查詢任意節點 A（`src_lid`）到節點 B（`dst_lid`）的實體交換路徑。
* **輸出解讀**：列出封包離開來源 HCA 後，依序經過的每台交換器型號、GUID、LID 以及各交換器的 Ingress/Egress 實體埠號。

#### 3. `ibping`（基於 MAD 的連通性驗證）

* **與乙太網 Ping 的差異**：
  * 乙太網 ping 發送 ICMP 封包，而 `ibping` 是由 HCA 硬體發送與處理 **MAD 封包**。

* **Server-Client 模式**：目標端必須先啟動 `ibping -S` 進入伺服接聽狀態，發送端才能對其打流。
* **排查價值**：若 IP 層（TCP/IP）不通，可先用 `ibping` 驗證 InfiniBand 硬體與 SM 路由是否正常；若 `ibping` 正常而 IP 傳輸失敗，問題通常出在上層 IPoIB（IP over InfiniBand）介面或 ARP 設定。

#### 4. `ibstat`（本機 HCA 埠狀態診斷）

* **狀態機判斷**：
  * **正常狀態**：
    * `State: Active`（已取得 LID，且受 SM 管理）
    * `Physical state: LinkUp`（實體層訊號正常、光纖連線通暢）
    * `SM lid: X`（顯示當前 Master SM 的 LID）


* **典型故障狀態**：
  * 若 `Physical state: LinkUp` 但 `State: Initializing` 且 **`SM lid: 0`**，代表實體光纖完全通暢，但**子網內沒有啟動 Subnet Manager（或 SM 當機）**，無法為該連接埠分配 LID 與設定路由。
  * 若 `Physical state: Polling`，通常是實體線纜未接好、光模組故障或對端交換器埠關閉（Admin Down）。

#### 5.. 兩步驟精確定位 Master SM（`sminfo` $\rightarrow$ `smpquery ND`）

在大規模叢集中可能配置了多個 SM 作為容錯備援，要找出「當前是哪台主機在控管網路」需採取兩步法：

1. **執行 `sminfo` 抓取管理身分**：
    輸出會顯示 `smlid 8 smguid 0x... state : 3 SMINFO_MASTER priority: 0`。


* `state: 3` 即代表當前 Active Master。
* 記下回傳的 `smlid`（例如 `8`）。




2. **透過 `smpquery` 發送 MAD 查詢節點字串**：
    執行 `smpquery nodedesc 8`（或 `smpquery ND 8`），交換器或網卡暫存器會回傳設定的 `NodeDescription` 字串（如 `ubuntu-1 HCA-1`），直接鎖定實體主機。



#### 6. `ibnetdiscover`（拓撲自動掃描與接線驗證）

* **自動拓撲建立 vs. 手動排查**：
    新設備接入或交換器開機時，Subnet Manager 會**自動探測並更新轉發表**，平時維運並不需要手動執行指令；但當管理員需要**核對現場機房配線是否與規劃圖相符**時，`ibnetdiscover` 是最權威的拓撲掃描工具。


* **延伸排查指令**：
    若透過 `ibnetdiscover` 發現某台交換器的 LID（例如 LID 4），可進一步結合 `ibroute <LID>` 查詢該交換器當前寫入的線性轉發表（LFT），檢視其轉發走向與各連接埠對應規則。


#### 7. 設備盤點三劍客（`ibnodes`、`ibhosts`、`ibswitches`）的過濾差異

* **`ibnodes`**：全景檢視，回傳所有節點（`Ca` + `Switch` + `Router`）。
* **`ibhosts`**：自動過濾掉網路交換設備，通常用於搭配 `wc -l` 快速計算伺服器 HCA 連線總數，確認是否有伺服器因硬體或線路故障失聯。
* **`ibswitches`**：自動過濾掉主機，展示所有交換器實體埠數（例如 36-port switch），用於快速盤點交換器骨幹健康度。

## Hardware/Physical Issues

在高速網路環境下，光纖與 DAC 銅線容易因彎折過度、接頭髒污鬆脫或周邊電磁干擾引發訊號衰減，進而導致鏈路閃斷（Link Flapping）或微碼錯誤。

---

### 實體層核心排查速查表

| 症狀 / 問題 (Symptom / Issue) | 推薦工具 | 檢查重點與診斷指標 (What to Check) | 標準指令 / 操作途徑 |
| --- | --- | --- | --- |
| **鏈路頻繁閃斷 (Link Flapping)**<br>*(需進行實體層底層訊號診斷)* | **`mlxlink`** | 檢查實體鏈路狀態、協商寬度（如 4X）與速率。<br>檢驗 FEC（前向錯誤更正）狀態與環回模式。 | `mlxlink -d <device>`<br>*(例如: `mlxlink -d mlx5_0`)* |
| **需測量鏈路誤碼率 (BER)**<br>*(評估訊號完整性與眼圖品質)* | **`mlxlink`** | 檢查 **Raw BER**（原始誤碼率）與 **Effective BER**（校正後誤碼率）。<br>觀察各實體 Lane 的**眼圖開度（Eye Opening）**電壓與時間餘量。| `mlxlink -d <device> -c -e`<br>*(備註：講者使用 `-c -e` 擷取計數器與眼圖)* |
| **CVT 回報 Underperforming BER**<br>*(DAC 銅線訊號完整性存疑)* | **CVT (Cable Validation Tool)**<br>*(整合於 UFM)* | 在 6 小時監控窗口內，若 **Effective BER 超過門檻值**，代表 FEC 已達修復極限，**線纜必須更換**。<br>檢視全網接線拓撲品質與進階閃斷監控。 | 透過 UFM Web GUI 介面中的 **Cable Validation Tool** 模組執行 Golden BER 測試。 |
| **需確認本機 IB 介面狀態與鏈路協定** | **`ibstat`** | 確認 `State: Active` 且 `Physical State: LinkUp`。<br>確認 `Link layer: InfiniBand`（而非 Ethernet/RoCE 模式）。 | `ibstat`<br>`ibstat -d <device>` |

---

### 關鍵機制與技術深度解析

#### 1. Raw BER vs. Effective BER（前向錯誤更正 FEC 概念）

以文書編輯器的自動拼字校正（Auto-Correct）比喻硬體 **FEC (Forward Error Correction)** 機制：

* **Raw Physical BER（原始誤碼率）**：
  實體電氣/光學訊號穿過實體線路時，**在尚未經過 FEC 晶片運算修復前**所發生的原始位元錯誤率。

* **Effective Physical BER（有效誤碼率）**：
  **經過 FEC 演算法修補後的最終誤碼率**，即上層應用與 GPU 實際看見的傳輸資料品質。


* **判定原則**：
  正常鏈路下的 Effective BER 應落在極低數值（例如 $10^{-15}$ 以下）。當 Raw BER 居高不下、導致 **Effective BER 超過系統預警閾值**時，代表雜訊與錯誤已逼近 FEC 的修正上限，隨時會造成封包遺失與重傳，**唯一解法是立即更換實體線纜或光模組**。

#### 2. 眼圖開度分析（Eye Opening Monitor）

在高速串列傳輸（如 4X 10G/25G/50G/100G PAM4 每通道）中，`mlxlink -e` 能繪製或列出實體接收端取樣點的裕度：

* **高度（Eye Height，以毫伏 mV 表示）**：訊號振幅與雜訊容限。
* **寬度（Eye Width，以皮秒 ps 表示）**：抖動（Jitter）與時間裕度。

* 若眼圖呈現扁平或閉合，代表訊號嚴重衰減失真，可能源自接頭未插到底、接點氧化或線路彎折牛角半徑過小。

#### 3. CVT (Cable Validation Tool) 大規模叢集接線驗證

* **架構定位**：CVT 是 NVIDIA 針對超大規模資料中心提供的線纜品質自動化驗證工具，採用 **Collector（集中收集器）** 與部署在交換器上的 **Agents（代理端）** 架構。

* **核心功能**：
    1. **Golden BER Test**：叢集上線前對全網線纜進行高負載傳輸打標，建立基準性能值。
    2. **Advanced Flapping Monitoring**：自動捕獲間歇性脫落或微秒級抖動的劣質鏈路。
    3. **自動化換線清單**：精確標註特定機櫃、特定埠號之間未達標的 DAC 或主動光纖（AOC）。
