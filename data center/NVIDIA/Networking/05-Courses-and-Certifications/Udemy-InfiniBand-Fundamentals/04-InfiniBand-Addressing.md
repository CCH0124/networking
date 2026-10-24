# InfiniBand Addressing

## Getting Details of IB Adapter

`ibstat` 是一個以二進位（binary）形式實作的 InfiniBand 診斷工具，主要用於顯示主機通道介面卡（Host Channel Adapter, HCA）及其連接埠的詳細狀態與硬體資訊。

### ibstat 指令

1. **硬體層 (實體規格)：**
    `ibstat` 能夠直接向底層的 ConnectX 網路卡晶片（例如 MT4099 等 Mellanox/NVIDIA 晶片）進行查詢，提取硬體的出廠寫入資訊（如 64-bit GUID）、韌體版本（Firmware version）以及實體連接埠狀態（Physical state）。
2. **傳輸層 (InfiniBand 協定)：**
    在傳輸層面，該指令會揭露 InfiniBand 網路運作的關鍵定址資訊。包含由 Subnet Manager (SM) 分配的 16-bit 本地識別碼（Base LID）、管理多重路徑的 LID 遮罩控制（LMC, LID Mask Control），以及當前的傳輸速率（Rate）。
3. **管理層 (遙測與診斷)：**
    在維運層面，`ibstat` 提供了多種參數來過濾節點資訊，例如使用 `ibstat -l` 列出所有的 CA 名稱，或使用 `ibstat -p` 列出特定連接埠的 GUID。它被廣泛應用於確認本地 HCA 是否已成功與 Fabric 中的集中式大腦（Subnet Manager）建立連線。

### 輸出結果

```bash
$ ibstat
CA 'mlx5_0'
        CA type: MT41692
        Number of ports: 1
        Firmware version: 32.41.1300
        Hardware version: 1
        Node GUID: 0xc470bd0300c25136
        System image GUID: 0xc470bd0300c25136
        Port 1:
                State: Active
                Physical state: LinkUp
                Rate: 400
                Base lid: 1
                LMC: 0
                SM lid: 1
                Capability mask: 0xa751e84a
                Port GUID: 0xc470bd0300c25136
                Link layer: InfiniBand
CA 'mlx5_1'
        CA type: MT41692
        Number of ports: 1
        Firmware version: 32.41.1300
        Hardware version: 1
        Node GUID: 0xc470bd0300b98054
        System image GUID: 0xc470bd0300b98054
        Port 1:
                State: Active
                Physical state: LinkUp
                Rate: 200
                Base lid: 0
                LMC: 0
                SM lid: 0
                Capability mask: 0x00010000
                Port GUID: 0x68bee4fffec92bd9
                Link layer: Ethernet
CA 'mlx5_2'
        CA type: MT41692
        Number of ports: 1
        Firmware version: 32.41.1300
        Hardware version: 1
        Node GUID: 0xc470bd0300b98055
        System image GUID: 0xc470bd0300b98054
        Port 1:
                State: Active
                Physical state: LinkUp
                Rate: 40
                Base lid: 0
                LMC: 0
                SM lid: 0
                Capability mask: 0x00010000
                Port GUID: 0x68bee4fffec92bd9
                Link layer: Ethernet
```


當在 Linux 終端機輸入 `ibstat` 時，系統會回傳類似以下的層級式資訊：

* **CA type:** 顯示轉接卡的硬體晶片型號（例如 `MT4099` 代表特定的 Mellanox 晶片架構）。
* **Firmware / Hardware version:** 顯示當前 HCA 的底層韌體與硬體修訂版本。
* **Node GUID / System image GUID:** 顯示製造商燒錄於硬體中的 64-bit 全球唯一識別碼，這是 SM 用來辨識並分配 LID 的絕對依據。
* **State / Physical state:**
  * `State`: 邏輯狀態，若顯示為 `Active`，代表該埠已完全加入 InfiniBand 網路並可進行資料轉發。
  * `Physical state`: 實體層狀態，若顯示為 `LinkUp`，代表實體線材（如 DAC 或光纖）與對端交換器的物理訊號已成功建立。
  * `Initializing (Init)`: 物理連線已建立（Physical Link: Up），但尚未被 Subnet Manager 配置，或正在握手協議。
* **Rate:** 當前的傳輸頻寬（例如顯示 40 代表 QDR 40 Gb/sec，若為 NDR 則對應更高頻寬）。
* **Base lid:** 由 Subnet Manager (SM) 分配給該連接埠的 16-bit 本地識別碼，用於子網內的硬體線速路由。
* **LMC (LID Mask Control):** 控制分配給該連接埠的 LID 數量。
  * 若顯示為 `0`，代表僅分配單一 LID(代表該實體埠口僅分配 $2^0 = 1$ 個 LID)，未啟用基於 LID 的多重路徑（Multipathing）傳輸。
* **SM lid:** 控制該子網的 Subnet Manager (SM) 的 LID 位址。這能讓維運人員知道是哪一台 SM 節點在管控當前網路。

> [!TIP]
> 
> 若 Base LID == SM LID（例如兩者皆為 5）：代表這台主機自身正兼任 Subnet Manager（正在執行 OpenSM）
>
> 若 Base LID != SM LID：代表這台主機是一般運算節點，由另一台主機或交換器擔任 SM。
>
> 若 SM LID = 0：代表網路上根本沒有運作中的 Subnet Manager，網路無法通訊。

## Global Unique Identifier(GUID)

在 InfiniBand 網路中，GUID 是用來唯一識別硬體設備的核心標誌。Subnet Manager（SM）透過識別各節點發布的 GUID，來決定如何為其指派動態轉發所需的 LID（Local Identifier）。

1. 硬體層 (實體規格)： GUID 是一個 64 位元 (64-bit) 的數值，由製造商（如 NVIDIA）在生產時直接燒錄於硬體元件中，且無法更改。在實體設備上，通常可以在 ConnectX HCA 網路卡的實體標籤上找到這組識別碼。在硬體層次上，它又可細分為：
    * Node GUID (節點 GUID)： 每張 HCA 網卡被視為一個獨立的 InfiniBand 節點，擁有自己專屬的 Node GUID。
      * 主機板上有幾張 HCA 卡，系統就會顯示幾個 Node GUID
    * Port GUID (連接埠 GUID)： 一張多埠網卡上的每一個實體連接埠，皆具備獨立的 Port GUID。
    * System Image GUID (系統映像 GUID)： 用於代表整個系統（例如包含多個節點的 DGX 系統或刀鋒伺服器機箱）。
      * 用於代表一個系統群組（Group of Systems）或硬體機箱（Chassis） 
  
    InfiniBand 將識別碼細分為三個層次，這在管理大規模叢集時至關重要：
    ```
    [ System Image GUID ]  ── 邏輯系統 / 機箱群組層級（Chassis / DGX / Blade）
         │
    [ Node GUID ]      ── 實體介面卡層級（每張 HCA 卡即為一個 Node）
         │
    [ Port GUID ]      ── 實體連接埠層級（每個 Port 各自擁有一個）
    ```
    
3. 傳輸層 (InfiniBand 協定定址)： 在傳輸與網路層中，GUID 提供的是*全域身份 (Global Identity)*，但它不直接用於子網內的硬體路由轉發。當封包需要進行跨子網 (Inter-subnet) 的 L3 傳輸時，InfiniBand 路由器會將這組 64-bit 的 GUID 與 64-bit 的子網前綴 (Subnet Prefix) 結合，構成 128-bit 的全域識別碼 (GID, Global Identifier) 來進行跨網段尋址。

4. 管理層 (Subnet Manager 與遙測自動化)： 在管理平面，集中式的控制大腦 Subnet Manager (SM) 高度依賴 GUID 來探索網路拓樸。SM 會掃描 Fabric 中所有的 GUID，並據此動態指派 16-bit 的本地識別碼 (LID) 給每一個連接埠，以建立硬體轉發的路由表。在管理層面上，維運人員可透過 ibstat 等指令或 NetQ 遙測工具，透過 GUID 來精確鎖定特定的硬體狀態。

> [!TIP]
> 當伺服器故障更換 HCA 網卡時，其 Node GUID 與 Port GUID 一定會跟著改變

### Subnet Manager 與 ASIC

GUID 展現了 InfiniBand 網路中軟硬體分離的優雅互操作性。 硬體端（ConnectX 晶片或 Quantum 交換器 ASIC）僅負責提供不可篡改的 64-bit GUID 身份；而軟體端（Subnet Manager）則負責收集這些 GUID 並進行邏輯運算。當設備上線時，硬體會透過管理資料報 (MADs) 將其 GUID 上報給 SM；SM 計算完成後，會將對應的 16-bit LID 寫回硬體 ASIC 中。這種機制使得網路硬體轉發層不需記錄冗長的全域位址，只需依賴極短的 16-bit LID 進行線速 (Wire-speed) 查表轉發，達成了極低的納秒/微秒級硬體處理延遲。

## Local Identifier

我們可以如下理解

GUID（Globally Unique Identifier）：回答 「我是誰？（Who you are）」 —— 硬體天生的身分證。
LID（Local Identifier）：回答 「我在網路的哪裡？（Where you are）」 —— 網路拓撲中的位置座標。

### InfiniBand LID 架構

在 InfiniBand 網路中，LID 是用於子網內部資料轉發的核心定址機制。

1. **硬體層 (實體規格)：**
    LID 是一個 16 位元 (16-bit) 的位址，有效數值範圍從 `0x0001` 到 `0xFFFE`。當設備加入網路後，這個位址會被寫入主機通道介面卡 (HCA) 以及交換器 ASIC 的硬體暫存器中，作為實體層轉發的絕對依據。
2. **傳輸層 (InfiniBand 協定定址)：**
    在傳輸層面，LID 專門用於單一子網 (Subnet) 內的封包路由。交換器會透過查找基於 LID 建立的線性轉發表 (Linear Forwarding Tables, LFTs)，在硬體層級決定封包的輸出連接埠，從而實現無損且高效的線速 (Wire-speed) 轉發。
3. **管理層 (Subnet Manager 與自動化)：**
    與硬體出廠即固定的 MAC 或 GUID 不同，LID 是一個動態標籤。它完全由集中式的控制大腦——子網管理員 (Subnet Manager, SM) 進行動態指派 (Dynamically assigned)。SM 會在網路拓樸探索階段收集各節點資訊，並精確分配 LID 給每一個活躍的連接埠。

### LID 與 GUID 的比較

在 InfiniBand 架構中，LID 與 GUID 扮演著截然不同但相輔相成的角色，其核心差異在於「身分」與「位置」的解耦：

| 比較維度 (Feature) | Local Identifier (LID) | Global Unique Identifier (GUID) |
| :--- | :--- | :--- |
| **長度格式** | 16-bit (16 位元) | 64-bit (64 位元) |
| **作用範圍 (Scope)** | 僅限於本地子網 (Local / Subnet) | 全域唯一 (Global) |
| **指派者 (Assigned by)**| 由 Subnet Manager (SM) 動態分配 | 由硬體製造商在生產時燒錄於晶片 |
| **可變性 (Changes)** | 是 (Yes) - 隨網路拓樸或 SM 重配而改變 | 否 (No) - 永久固定且無法竄改 |
| **路由用途 (Routing)**| 是 (Yes) - 交換器依賴 LID 進行硬體轉發 | 否 (No) - 僅作身分識別與 SM 拓撲發現，不用於子網內路由 |
| **乙太網路對照** |	類似 MAC 位址|	類似 區域網路內的 IP / 轉發標籤|

### 核心價值

在大型 AI 訓練叢集（如 DGX SuperPOD）中，GPU 之間依賴 RDMA (Remote Direct Memory Access) 進行龐大神經網路參數的同步，這類流量被稱為「大象流 (Elephant flows)」。將通訊尋址從 64-bit 的 GUID 解耦，轉而依賴 16-bit 的 LID，其核心價值在於**極致的硬體查表優化**。由於 LID 長度極短，交換器 ASIC 可以將整個線性轉發表 (LFT) 完全載入至最快速的晶片內建記憶體 (SRAM) 中。這種設計讓 InfiniBand 網路能將端到端的傳輸延遲壓縮至極低的 1 到 2 微秒 (µs)，徹底打破了傳統網路在處理高吞吐量時的延遲瓶頸，確保高昂的 GPU 算力不會因等待網路 I/O 而閒置。

InfiniBand 為了追求極致的超高頻寬與超低延遲，特意引入 LID 機制：

1. 硬體轉發極速化（Hardware-level Fast Lookup）：
  * 16-bit 的長度遠小於 64-bit。
  * 交換器（Switch）的 ASIC 晶片只需維護一張非常小巧且緊湊的快速查找表（Lookup Table / LFT），封包一進來直接硬體比對轉發，大幅降低交換延遲。
2. 身分與位置解耦（Decoupling Identity from Location）：
  * 將「硬體識別碼（GUID）」與「網路轉發路徑（LID）」分開。
  * 即使硬體故障更換卡片（GUID 改變），SM 仍可將相同或新的 LID 分配給該位置；或者主機調整接線時，SM 只要重新調整 LID 分配與轉發路徑即可，軟體應用層不需綁死笨重的 64-bit GUID。

### LID 與 GUID

LID 與 GUID 的協作完美體現了軟硬體分離的互操作性。當設備上線時，底層硬體（ConnectX 網卡）會將其全球唯一的 GUID 上報給軟體層（Subnet Manager）。SM 隨後完成拓樸計算，並將動態生成的 16-bit LID 規則透過管理資料報 (MAD) 寫回硬體 ASIC 中,。當叢集發生實體斷線或節點重啟時，SM 能夠快速識別出相同的 GUID，並選擇保留或重新指派 LID，這種由軟體集中控制、硬體無縫執行的機制，達成了極高的網路自癒能力與維運彈性。

### AI 資料中心 (InfiniBand) vs. 傳統資料中心 (Ethernet)

* **傳統資料中心 (Ethernet / MAC 位址)：**
    在傳統的乙太網路中，設備的身分與路由高度綁定於 48-bit 的 MAC 位址上。交換器必須依賴分散式的廣播 (Broadcast) 與學習機制來建立 MAC 轉發表。在擁有數千個節點的叢集中，這會產生龐大的控制層負載與延遲抖動，難以滿足 AI 對網路穩定性的苛刻要求。
* **AI 資料中心 (InfiniBand / LID + GUID 解耦)：**
    InfiniBand 針對超級運算與 AI 場景重新設計了網路邏輯，將「我是誰 (GUID)」與「我在哪裡/如何抵達 (LID)」徹底分開。這種集中式的架構消除了廣播學習的負擔，交換器只需盲目且極速地依據 SM 派發的 LID 執行硬體轉發。這是現代 AI 基礎設施能實現決定性低延遲 (Deterministic Latency) 的底層架構精髓。
