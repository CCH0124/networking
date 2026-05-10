# Why InfiniBand ?

## Why do we need faster network ?

1. **資料量爆炸性成長 (Data Growth Explosion)：** 來自 AI、數據分析與各種應用程式的資料量巨幅增加，傳統網路已無法負荷，成為系統的傳輸瓶頸。
2. **分散式運算需求 (Distributed Computing Needs)：** 現代 AI 工作負載通常跨越由多台機器（運算節點）組成的叢集來執行，這需要極度快速的節點對節點 (Node-to-node) 通訊能力。
3. **AI/ML 訓練的嚴苛要求 (AI / ML Training Demands)：** 在訓練人工智慧模型時，GPU 與節點之間需要進行極為頻繁的資料同步，若網路速度緩慢，將會直接拉長整體的模型訓練時間。
4. **最大化運算資源使用率 (Maximizing Compute Utilization)：** 緩慢的網路會導致昂貴的 CPU 與 GPU 處於閒置狀態 (Idle) 以等待資料送達，更快的網路能確保這些昂貴硬體設備的效能被全面利用，避免投資浪費。
5. **即時與極低延遲需求 (Real-Time & Low-Latency Requirements)：** 許多應用程式需要微秒 (microseconds) 等級的即時回應，例如交易系統、模擬系統與即時數據分析。

### 網路資料流向分析 (Data Flow) 與架構對比

為了滿足上述高速網路的需求，NVIDIA 生態系通常採用 InfiniBand 網路搭配 RDMA (Remote Direct Memory Access) 與 GPU Direct RDMA 技術。我們來對比一下傳統網路與 AI 高速網路的資料流向差異：

*   **傳統 Ethernet (TCP/IP) 資料流向：** 
    封包從 Server A 傳到 Server B，流向為 `GPU 記憶體 -> CPU -> 系統主記憶體 -> 網路卡 -> 網路交換器 -> 網路卡 -> 系統主記憶體 -> CPU -> GPU 記憶體`。
    這種複製轉發 (Copy-based) 會耗費大量 CPU 資源處理核心中斷，並帶來約 10~100 微秒的較高延遲。
*   **AI 高速網路 (InfiniBand + GPU Direct RDMA) 資料流向：**
    資料完全繞過 (Bypass) CPU 與作業系統核心，流向為 `Server A GPU 記憶體 -> 透過 PCIe 進入 ConnectX 網卡 -> InfiniBand 交換器 -> Server B ConnectX 網卡 -> Server B GPU 記憶體`。
    這種架構達成了真正的零複製 (Zero-copy) 傳輸，不僅釋放了 CPU 資源，更將端到端延遲大幅降低至 1~2 微秒，甚至低於 1 微秒 (如 HDR / NDR 規格)。

### 網路問題排查與範例配置

在建置這類高速網路時，如果我們需要驗證節點間的連線狀態，我們不會使用傳統 IP 網路的 `ping`，而是使用工作於 InfiniBand 網路層 (基於 LID/GUID) 的專屬工具 `ibping`。

**驗證配置與指令範例：**
若要測試 Server A 與 Server B 之間的 InfiniBand 連線：
1.  在 Server B (作為伺服器端) 啟動監聽模式：
    ```bash
    ibping -S
    ```
2.  在 Server A (作為客戶端) 對 Server B 的 LID (Local Identifier) 發起測試：
    ```bash
    ibping -L <Server_B_LID>
    ```
    *(註：此指令不依賴 IP，而是直接測試 InfiniBand 底層的高速連線狀態。)*

如果在資料中心內發現網路吞吐量未達預期（例如 H100 叢集未能跑滿頻寬），請優先檢查實體層的線材與收發器規格。在 InfiniBand 網路中，如果將 NDR400 (400 Gbps) 的網路環境誤接成 NDR200 的分支線材 (Breakout Cable)，即便網路卡與交換器晶片皆支援最高速率，實際的傳輸帶寬仍會被降級限制在 200 Gbps。

## Evolution of Infinband

### InfiniBand 的歷史與生態系演進
*   **1999–2001 年 (誕生期)：** 由 Intel、IBM、Cisco 與 Sun 等科技巨頭共同發起，最初的目標是為了解決傳統 PCI 匯流排與乙太網路 (Ethernet) 的傳輸瓶頸，打造高頻寬、低延遲的架構。
*   **2001–2009 年 (Mellanox 崛起)：** Mellanox Technologies 逐漸成為 InfiniBand 商業化的主要推動者與領導品牌，使 IB 成為超級電腦 (HPC) 的預設互連標準。
*   **2019–2020 年 (NVIDIA 併購與 AI 骨幹化)：** NVIDIA 成功收購 Mellanox，並將 InfiniBand 重新定位為「不只是網路，而是 AI 專屬的網路架構 (AI fabric)」，透過將其與 GPU 深度垂直整合，確立了 IB 在 AI 基礎架構訓練中的核心地位。

### InfiniBand 速率與規格演進 (Evolution of Speeds)
InfiniBand 的實體層速率隨著世代不斷翻倍，以滿足 AI 模型訓練頻繁且龐大的資料同步需求。以下為各世代的演進時程與速率：
*   **SDR (Single Data Rate):** 10 Gbps (約 2002 年)
*   **QDR (Quad Data Rate):** 40 Gbps (約 2008 年)
*   **FDR (Fourteen Data Rate):** 56 Gbps (約 2011 年)
*   **EDR (Enhanced Data Rate):** 100 Gbps (約 2015 年)
*   **HDR (High Data Rate):** 200 Gbps (約 2018 年)
*   **NDR (Next Data Rate):** 400 Gbps (約 2021 年)
*   **XDR (eXtream Data Rate):** 800 Gbps (約 2023 年)
*   **GDR (Gigabit* Data Rate):** 1600 Gbps (預計 2026 年)

### 網路資料流向 (Data Flow) 與架構優勢

InfiniBand 能在各個世代保持效能領先，主要歸功於其底層的 **RDMA (Remote Direct Memory Access)** 與 **GPU Direct RDMA** 技術。

**資料流向解析：**
傳統乙太網路使用 TCP/IP 堆疊，封包轉發 (Copy-based) 處理會經過作業系統核心，並帶來約 10~100 微秒的較高延遲，且消耗大量 CPU 資源。
而在 InfiniBand 的高速架構中，資料流向為：
`伺服器 A 的 GPU 記憶體` -> `透過 PCIe 進入 ConnectX 網路卡 (HCA)` -> `InfiniBand 交換器` -> `伺服器 B 的 ConnectX 網路卡` -> `伺服器 B 的 GPU 記憶體`。

此過程達成真正的零複製 (Zero-copy)，資料傳輸完全繞過 (Bypass) CPU 與作業系統核心。這使得端到端的極致延遲能降至約 1~2 微秒，在 HDR 與 NDR 世代甚至可低於 1 微秒。

### 網路問題排查與配置範例

隨著網路速率不斷攀升，實體層的相容性與連線問題排查變得更為重要。可使用以下指令來確認 InfiniBand 介面的連線與協商狀態。

**在主機端 (Host) 檢視介面演進速率與配置：**
使用 `ibstat` 指令可以查看 ConnectX 網路卡的詳細硬體狀態與目前的連線速率。
```bash
admin1@ubuntu1:~$ ibstat
CA 'mlx5_0'
   CA type: MT4123
   Number of ports: 1
   Firmware version: 20.28.1002
   Port 1:
      State: Active
      Physical state: LinkUp
      Rate: 200 # (代表當前協商為 HDR 200Gbps 速率)
      Base lid: 5
      Link layer: InfiniBand
```

**在 MLNX-OS (NVIDIA 交換器端) 確認與強制速率：**
如果在不同世代的設備（例如 EDR 與 HDR）混用時發生相容性降速，我們可以登入交換器介面檢視，或強制設定該連接埠允許支援的演進速率。
```bash
# 檢視特定連接埠目前的連線速率 (例如顯示為 NDR 400Gbps)
switch (config) # show interfaces ib status
Interface   Description   IB Subnet          Speed   Current line rate   Logical port state
---------   -----------   ----------------   -----   -----------------   ------------------
IB1/1/1                   infiniband-default ndr     400.0 Gbps          Active

# (可選) 進入特定連接埠，配置其允許協商的 InfiniBand 速率清單
switch (config) # interface ib 1/1/1
switch (config interface ib 1/1/1) # speed fdr edr hdr ndr
```

此配置能確保該交換器連接埠可向下相容，與舊有世代的網路卡進行正確的速率協商。

## InfinBand Connections

在 NVIDIA AI 資料中心與高效能運算 (HPC) 環境中，InfiniBand 連線 (Connections) 不僅僅是將網路線插上而已，它涵蓋了從主機端網卡、實體傳輸線材、交換器介面，一直到子網路管理員 (Subnet Manager, SM) 進行邏輯配置的完整生命週期。

以下我將為你拆解 InfiniBand 連線的硬體元件、分支與拓撲邏輯、連線建立的資料流向，以及日常維運的排查指令。

### 實體連線元件 (Physical Connectivity Components)
InfiniBand 的實體連線主要由三個核心硬體組成,：
*   **HCA (Host Channel Adapter):** 這是安裝在運算節點或 GPU 伺服器上的網路卡（例如 NVIDIA ConnectX 系列）。它的作用等同於乙太網路中的網卡，但它具備強大的 CPU 卸載 (Offload) 能力，讓應用程式能透過 RDMA (Remote Direct Memory Access) 直接進行記憶體存取。
*   **交換器 (InfiniBand Switch):** 負責處理核心的資料轉發。以最新的 NDR 世代為例，NVIDIA Quantum-2 晶片的 QM9700 與 QM9790 交換器能在 1U 的機箱空間內，提供 64 埠高達 400Gb/s 的非阻塞 (non-blocking) 傳輸能力，並使用 OSFP 連接器介面,。
*   **線材與收發器 (Cables & Transceivers):** 決定連線品質與距離的關鍵，主要分為兩種技術：
    *   **DAC (Direct Attached Copper，直連銅纜):** 透過電訊號傳輸。優點是極低的功耗與較低的成本；缺點是傳輸距離短（通常在 5 到 7 公尺以內）、線材較粗重且缺乏彈性，同時容易受到電磁干擾 (EMI)。
    *   **AOC (Active Optical Cable，主動式光纜):** 透過內建的光電轉換晶片將訊號轉為光傳輸。優點是傳輸距離長（可達 100 公尺以上）、線材細且輕盈，並對電磁干擾免疫；缺點是功耗較高且成本較為昂貴。

### 邏輯拓撲與分支線纜 (Breakout / Splitting)
在實際建置資料中心時，為了最大化交換器的連接埠密度與彈性，我們經常使用 **分支線纜 (Breakout Cable)**。
*   **分割機制 (Split):** 在 QM9700/QM9790 交換器上，面板上的每個 OSFP 籠 (Cage) 實際上包含了兩個 400G 的 NDR 埠，且每一個 NDR 埠還可以進一步被拆分 (Split)。例如，我們可以使用特殊的線材，將一個 400G 的埠拆分為兩個 200G (NDR200) 的連線來連接兩台主機。
*   **介面命名規則 (Port Notation):** 為了精準對應這些分支埠，NVIDIA Quantum-2 交換器採用 `<ASIC>/<Cage>/<Port>/<Split>` 的邏輯命名格式。例如 `1/3/1/1` 和 `1/3/1/2` 代表的是第 3 個 Cage 內的第 1 個實體埠被拆分出來的兩個邏輯介面。如果要啟用這個功能，必須先將交換器的 System Profile 配置為 `split-ready`,。

### 網路資料流與連線建立過程 (Bring-up Data Flow)
當我們將 HCA 與交換器透過線材連接後，兩節點 (2-Node) 之間的 InfiniBand 連線必須經歷以下四個階段，RDMA 資料流才能真正開始傳輸：
1.  **硬體連接 (Hardware Setup):** 實體線材接上後，交換器與網卡的實體層 (Physical Layer) 完成協商，Link LED 指示燈亮起（通常初期會是橘燈，邏輯連線建立後轉為綠燈）,。
2.  **驅動載入 (Driver Installation):** 伺服器端載入 OFED 驅動程式與 RDMA 軟體堆疊，你可以透過主機上的 `ibv_devinfo` 指令確認硬體已就緒。
3.  **子網路管理員介入 (Subnet Manager):** 這是最關鍵的一步。在 InfiniBand 網路中，必須有 Subnet Manager (SM) 來發現新的連接埠，並為每一個連接埠分配一個獨一無二的 **LID (Local Identifier)**，這相當於該節點在子網路內的門牌號碼。
4.  **Fabric 發現 (Fabric Discovery):** SM 更新路由表後，節點間可以透過 `ibhosts` 或 `ibnodes` 互相看見彼此，至此端到端的 RDMA 傳輸通道正式建立。

###  與 Ethernet 環境的整合架構
AI 資料中心通常會有高速計算用的 InfiniBand 網路，以及對外服務或存取冷資料的 Ethernet 網路。NVIDIA 提供了三個層級的整合方式：

##### 專屬橋接設備：InfiniBand-to-Ethernet Gateway (硬體層級)
針對需要將龐大的 HPC / AI 運算叢集連接到 Ethernet Data Lake (資料湖) 或是雲端儲存的場景，NVIDIA 提供了專屬的閘道器設備（例如基於 Quantum-2 或 Quantum-X800 的設備）。
* 運作原理與資料流： Gateway 連接 IB 交換器與 Ethernet 交換器。當伺服器發出封包時，Gateway 會在底層進行協定轉換 (Protocol translation, 將 InfiniBand 轉換為 IP/Ethernet)。
* 優勢： 允許資料中心在不汰換現有 Ethernet 網路設備的情況下，無縫且具成本效益地讓 IB 運算叢集存取 Ethernet 儲存資源。

##### VPI (Virtual Protocol Interconnect) 技術 (網卡層級)

NVIDIA ConnectX 系列網卡具備 VPI 功能，這意味著*同一張網卡，可以同時支援 InfiniBand 與 Ethernet (包含 RoCE)*。

* 應用場景： 伺服器上的雙埠網卡，可以設定其中一埠連接 InfiniBand 交換器進行極低延遲的 AI 模型參數同步，另一埠則切換為 Ethernet 模式連接傳統 Ethernet 交換器進行外部管理或服務存取，提供極高的部署彈性。

##### IPoIB (IP over InfiniBand) 技術 (軟體/協定層級)

如果部分應用程式不支援原生的 RDMA 協定（例如某些舊版的管理工具或檔案傳輸軟體），只能透過傳統的 TCP/IP 溝通，我們可以開啟 `IPoIB`。

* 運作原理： 在 InfiniBand 的邏輯分區 (Partition) 之上建立一個虛擬的網路介面（例如 Linux 作業系統中的 ib0），將 IP 封包封裝在 InfiniBand 封包內傳送。
* 配置流向範例： 在 SM (Subnet Manager) 的配置中建立 Partition，並開啟 ipoib 標記，同時可指定 MTU 與傳輸速率 (Rate)。這讓 IB 節點間能擁有 IP 位址並互 Ping，進而與 Gateway 介接傳統網路。

### 維運排查與範例配置
在維運 InfiniBand 網路時，最常遇到的問題是*連線無法建立 (Link Down)*或*速率降級 (Speed Degradation)*。可以登入 MLNX-OS 交換器，使用以下指令進行排查：

**1. 檢查介面狀態與協商速率：**
  我們需要確認實體層與邏輯層是否都已啟動，並檢查速率是否達標。
  ```bash
  switch (config) # show interfaces ib status
  ```
  *資料流向與解析：* 輸出中會顯示 `Physical port state` (如 LinkUp) 與 `Current line rate` (如 400.0 Gbps)。如果發現兩端支援 NDR，但卻降級跑在 200 Gbps，你可以透過 `interface ib <port>` 進入介面，並使用 `speed fdr edr hdr ndr` 強制規範允許協商的速率範圍。

**2. 驗證線材與收發器 (Transceiver) 狀態：**
  若是懷疑線材插錯或不相容，可以直接讀取線材 EEPROM 的硬體資訊。
  ```bash
  switch (config) # show interfaces ib 1/1/1 transceiver
  ```
  *資料流向與解析：* 系統會透過 I2C 匯流排讀取收發器資訊，列出模組類型 (如 Optical module)、支援速率 (如 EDR, HDR)、廠商名稱、線材長度與產品序號。注意：如果插入了不支援的高功率收發器（如 LR4），系統會為了保護設備而強制保持 Link Down，並在介面顯示不支援的警告。

**3. 深層實體層診斷 (Link Diagnostics)：**
  如果連線時常中斷或丟包，可以透過內部診斷工具查看錯誤碼。
  ```bash
  switch (config) # show interfaces ib link-diagnostics
  ```
  *資料流向與解析：* 此指令會列出每個 Port 的硬體狀態碼。例如：
  *   **Code 0:** 連線正常 (No issue was observed)。
  *   **Code 2:** Auto-Negotiation 失敗，通常是兩端設定的 FEC (Forward Error Correction) 模式不對等或速率不匹配。
  *   **Code 15 / Code 52:** Bad signal integrity，代表實體層出現高頻率的原始位元錯誤 (Raw BER)。這通常是因為光纖端面髒污、收發器故障，或兩端傳輸功率 (Tx/Rx Power) 異常所導致的,。遇到這種情況，我們第一步通常是拔下線材進行清潔 (Cleaning the fiber)。

**4. 檢查本機 HCA 網卡的連線與 LID 分配狀態** 
  在伺服器端執行 `ibstat`，確認實體層與邏輯層是否都已上線，以及是否獲得 SM 分配的路由識別碼。
  ```bash
  admin1@ubuntu1:~$ ibstat
  CA 'mlx5_0'
     CA type: MT4123
     Number of ports: 1
     Port 1:
        State: Active
        Physical state: LinkUp
        Rate: 400           # 代表當前協商為 NDR 400Gbps 速率
        Base lid: 5         # 由 Subnet Manager 分配的 LID 門牌
        Link layer: InfiniBand
  ```

**5. 掃描與檢視全局拓撲 (Fabric Discovery) **
  要確認 IB 節點是否成功連接，或者想找出網路中的 Gateway 節點，可以使用 `ibnetdiscover` 工具。

  ```bash
  # 掃描整個 InfiniBand 子網，列出所有 Switch、HCA 主機與連結狀態
  admin1@ubuntu1:~$ ibnetdiscover
  ```
  此指令會輸出人類可讀的拓撲結構，包含所有的 GUID、節點類型（Switch, CA, Router）以及它們相互連接的埠號。若在整合環境中發現效能不如預期，可以先透過此指令檢查是否有實體鏈路降速（例如 NDR 400G 因線材問題降級至 200G 等情況）。
