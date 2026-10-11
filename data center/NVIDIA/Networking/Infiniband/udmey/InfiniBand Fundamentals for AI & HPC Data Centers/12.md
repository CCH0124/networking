# Traffic Isolation in InfiniBand
## Traffic Isolation in InfiniBand
### 為什麼共用 InfiniBand 需要流量隔離？

在超大型 GPU / HPC 叢集中，若所有流量都在同一個未受控的通道上流動，會引發資安外洩、效能干擾與維運風險。列舉了**四大應用情境**：

1. **多租戶 AI 叢集（Multi-tenant AI Clusters）**：
   * 多個研發團隊或客戶共用同一套 GPU 基礎設施時，防止資料外洩與相互爭搶頻寬（避免「吵鬧鄰居」效應）。
2. **環境隔離（Dev / Test / Prod）**：
   * 嚴格區隔開發、測試與正式生產環境，避免測試階段的意外廣播或錯誤流量癱瘓生產線。
3. **法規合規與資料隱私（Compliance & Privacy）**：
   * 醫療照護（Healthcare）、金融與機密科研等需要嚴格合規審查的專屬工作負載。
4. **混合工作負載保護（Mixed Workloads）**：
   * AI 訓練、高速儲存存取、科學模擬常常同時並存，透過隔離確保各負載的頻寬與低延遲 SLA 不受干擾。

> 核心價值：無需採購多套獨立的實體網路硬體，在單一實體 InfiniBand 網路上即可同時達成極致安全、可預測的效能、以及最高的硬體利用率。
---

### 核心技術：什麼是 P-key（Partition Key）？
* **定義**：InfiniBand 封包標頭中的一個 **16-bit（位元）欄位**。
* **功能**：在同一套實體 InfiniBand Fabric 內，**邏輯性地劃分出不同的獨立子網路**。
* **概念比喻**：非常類似乙太網路中的 **VLAN（虛擬區域網路）**，只有帶有相同/合法 P-key 的節點才能互相溝通。
* **與 VLAN 的主要差異**：P-key 具備特殊的**成員屬性機制（Membership Types：Full vs. Limited）**，能實現比一般 VLAN 更細緻的存取控制（下一單元會深入介紹）。

---

### P-key 的運作機制：控制平面 vs. 資料平面

InfiniBand 的流量隔離不是由單一交換機各自為政，而是由集中式大腦協同各節點硬體共同完成：

```text
================ 控制平面 (Control Plane) ================
        +----------------------------------------+
        |   子網管理器 (Subnet Manager, SM)       |
        +----------------------------------------+
           | 1. 定義 Partition 規則與 P-key
           | 2. 將 P-key 表格 (P-key Table) 下發至各節點
           | 3. 將 PKey 配置表廣播發布到全網 (Distributes PKey Tables)
           v
================ 資料平面 (Data Plane) ===================
    [ 發送端主機 (Node A) ]                   [ 接收端主機 (Node B) ]
+----------------------------+           +----------------------------+
| 維護自己的 P-key Table      |           | 維護自己的 P-key Table      |
|                            |           |                            |
| 3. 送出封包時 (as they leave)|           | 4. 收到封包時比對 P-key:    |
|    打上指定的 P-key Tag     |           |    • 合法符合 ──> 接收     |
|             │              |           |    • 不符合   ──> 硬體拋棄  |
+-------------│--------------+           +--------------▲-------------+
              │                                         │
              └───────── 透過實體網路傳送 ─────────────────┘
```

1. **控制平面（Subnet Manager）**：
   * 集中定義整個網路的 Partition 規則。
   * 將配發的 P-key 分送並同步到全網路各節點的 **P-key Table** 中。
2. **資料平面（各主機節點 HCA / 網卡）**：
   * **出站打標（Egress Tagging）**：封包送出主機時，硬體自動加上指定的 P-key。
   * **入站驗證（Ingress Filtering）**：封包抵達目標節點時，網卡比對自身的 P-key Table。
   * **硬體隔離**：若 P-key 不合法或成員資格不符，**網卡在硬體層直接拋棄（Drop）封包**，未經授權的流量完全進不了系統記憶體與作業系統。

## Power of Partition Key(PKey)

### 1. PKey 設定基礎

* **配置檔案**：在 Subnet Manager (SM) 主機上的 `partitions.conf` 檔案中定義 Partition 與各節點的成員關係。
* **分區數量上限**：系統最多可建立 **128 個 Partitions**。

### 2. 兩種成員資格（Membership Types）

在同一個 Partition 內，節點可被指定為以下兩種身分之一：

| 成員資格類型 | 通訊規則 | 說明 |
| --- | --- | --- |
| **Full（完全成員）**| 可與同分區內的**所有成員**通訊 | • Full $\longleftrightarrow$ Full（允許）<br> Full $\longleftrightarrow$ Limited（允許） |
| **Limited（受限成員）** | **僅能與 Full 成員通訊**，絕不能與其他 Limited 成員通訊 | Limited $\longleftrightarrow$ Full（允許）<br> Limited $\longleftrightarrow$ Limited（**禁止 / 阻斷**） |

### 3. 實務架構範例（運算節點 vs. 儲存節點）

常見於 AI/HPC 叢集中需要「運算節點存取儲存，但運算節點之間彼此隔離」的場景：

* **配置設計（Partition 1）**：
  * **Storage Node**：設定為 **Full**。
  * **Compute Node 1**：設定為 **Limited**。
  * **Compute Node 2**：設定為 **Limited**。
 
```text
+---------------------------------------------------------------+
|                          Partition 1                          |
|                                                               |
|   +------------------+             +----------------------+   |
|   |  Compute Node 1  |             |     Storage Node     |   |
|   |    (Limited)     |<----------->|        (Full)        |   |
|   +------------------+  [ 允許通訊 ] +----------------------+   |
|            ^                                   ^              |
|            |                                   |              |
|            |                                   |              |
|       [ 阻斷通訊 ]                           [ 允許通訊 ]      |
|            x                                   |              |
|            v                                   v              |
|   +------------------+                         |              |
|   |  Compute Node 2  |<------------------------+              |
|   |    (Limited)     |                                        |
|   +------------------+                                        |
|                                                               |
+---------------------------------------------------------------+
```

* **通訊結果**：
  * Compute Node 1 與 Compute Node 2 均可正常讀寫 Storage Node。
  * Compute Node 1 與 Compute Node 2 之間**無法互相通訊**，達成工作負載與流量隔離。

### 4. 關鍵核心原則：控制平面永遠放行

* **PKey 僅影響資料平面（Data Plane Traffic）**：資料的讀寫、運算等實際應用通訊受限於 PKey 規則。
* **控制平面（Control Plane Traffic）永遠不受限制**：
  * 即使節點被設定為 Limited，它與 **Subnet Manager (SM)** 之間的管理通訊（例如 LID 分配、拓撲更新等 SMP 封包）**絕對不會被阻斷**。
  * 這確保了整個 InfiniBand Fabric 隨時處於可維護與健康運作狀態。
 
## Configuring Partitions

### 1. OpenSM PKey 設定檔基礎

* **設定檔位置**：通常為 `partitions.conf`（啟動 OpenSM 時可透過參數指定路徑，例如：`opensm -P <路徑>/partitions.conf`）。

* **預設分區（Default Partition）**：
  * 用於未被明確指派至特定分區的節點。
  * **安全性建議**：設定為 `ALL=limited;`（更安全，預設成員間無法互通）；若為測試叢集可暫時設為 `ALL=full;`。
  * **套用方式**：修改檔案後，需**重啟 OpenSM 服務**使設定生效。

### 2. 實務情境：混合 Compute、GPU 與 Storage 的隔離需求

在現代 AI/HPC 架構中，通常有以下通訊約束需求：

  * **Storage Node**：必須同時允許 Compute 節點與 GPU 節點存取。
  * **Compute Nodes**：需存取 Storage，但彼此之間禁止互通。
  * **GPU Nodes**：分散式訓練高度依賴節點間通訊，GPU 彼此間必須暢通（Full），且需存取 Storage。
  * **隔離邊界**：Compute 節點與 GPU 節點之間**禁止跨類別互通**。

單一分區無法滿足此邏輯（若將 GPU 節點設為 Full 放進 Partition 1，Compute 節點將能存取 GPU 節點）。因此，必須使用雙分區（Multiple Partitions）方案。

### 3. 設定檔內容解析

```text
# Default partition
Default=0xffff : ALL=limited;

# Partition 1 (PKey 0x8001) - 運算與儲存分區
Node_Partition=0x8001:
    Storage_GUID=full;
    Node_1_GUID=limited;
    Node_2_GUID=limited;

# Partition 2 (PKey 0x8002) - GPU 與儲存分區
GPU_Partition=0x8002:
    Storage_GUID=full;
    GPU_Node_1_GUID=full;
    GPU_Node_2_GUID=full;

```

> ![NOTE]
> GUID 需填入 HCA 具體 Port 的硬體識別碼，可透過 `ibstat` 等指令查詢。


* **Storage Node** 同時加入兩個 Partition 且均為 **Full**，因此兩個分區的成員皆能正常與其通訊。
* **Compute Nodes** 位於 `0x8001` 且身分為 **Limited**：只能連線到 Storage，彼此被隔離。
* **GPU Nodes** 位於 `0x8002` 且身分為 **Full**：既能存取 Storage，GPU 彼此之間也能高頻通訊。
* **跨分區隔離**：由於不在同一個 PKey 分區內，Compute 節點與 GPU 節點無法跨網通訊。


```text
       +---------------------------------------------------------------+
       |                   Partition 1 (PKey 0x8001)                   |
       |                                                               |
       |   +-------------------+                                       |
       |   |  Compute Node 1   |                                       |
       |   |     (Limited)     |---+                                   |
       |   +-------------------+   |                                   |
       |             ^             |                                   |
       |        [ 阻斷通訊 ]        |                                   |
       |             x             |                                   |
       |             v             |     +-------------------------+   |
       |   +-------------------+   +---->|      Storage Node       |<--+---+
       |   |  Compute Node 2   |         | (Full in P1 & Full in P2) |   |   |
       |   |     (Limited)     |-------->+-------------------------+   |   |
       |   +-------------------+                                       |   |
       +---------------------------------------------------------------+   |
                                                                           |
       +---------------------------------------------------------------+   |
       |                   Partition 2 (PKey 0x8002)                   |   |
       |                                                               |   |
       |   +-------------------+                                       |   |
       |   |    GPU Node 1     |                                       |   |
       |   |      (Full)       |---------------------------------------+   |
       |   +-------------------+                                           |
       |             ^                                                     |
       |        [ 允許通訊 ]                                                |
       |             v                                                     |
       |   +-------------------+                                           |
       |   |    GPU Node 2     |                                           |
       |   |      (Full)       |-------------------------------------------+
       |   +-------------------+                                       |
       |                                                               |
       +---------------------------------------------------------------+
         [!] Compute 節點 (0x8001) 與 GPU 節點 (0x8002) 跨分區無法通訊

```

##  Node Partitioning

### 實作流程與設定檔內容

#### 步驟 1：編輯分區設定檔

編輯 `/etc/opensm/partitions.conf`：

```text
# Default partition（未指派節點皆為 limited，提升安全性）
Default=0x7fff, ipoib : ALL=limited;

# Partition 1 (自訂 AI 分區)
AI_Partition=0x1234, ipoib, indx0 :
    0x0002c90300f97611=full,
    0x0002c90300409251=limited,
    0x248a070300769e81=limited;

```

(設定檔將 Ubuntu 1 設為 `full`，Ubuntu 2 與 3 設為 `limited`。)

#### 步驟 2：重啟 OpenSM 服務生效

```bash
sudo systemctl restart opensm

```

(修改完成後重啟 OpenSM，設定會立即在硬體網卡與交換器上套用。)

---

### 核心診斷與除錯指令

* **`smpquery PKeys <LID> <PORT>`**：
  * 查詢特定連接埠上載入的 128 組 PKey 槽位值。

  * **數值變化解析**：
    * `Limited` 成員：顯示原始設定值 `0x1234`。
    * `Full` 成員：最高位元（Membership bit）被硬體置位（`0x8000 | 0x1234`），在數值上呈現為 `0x9234`（影片中提及的數學轉換）。

* **`ibdiagnet`**：
  * 掃描整個 Fabric 並輸出拓撲與分區日誌檔（如 `ibdiagnet2.pkey`），可檢視各 LID 節點所屬的 Partition 與 Membership 列表。

