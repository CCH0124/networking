# Remote Direct Memory Access(RDMA)
## Direct Memory Access

InfiniBand 的高速關鍵在於 RDMA，而理解 RDMA 之前必須先了解 DMA。

什麼是 DMA ? 一種硬體層面（主機板／BIOS 層級）的功能，允許硬體裝置直接讀取或寫入系統記憶體，不需 CPU 作為中間人搬運資料。

1. 傳統傳輸方式的瓶頸（未採用 DMA）
  * 運作方式：網卡（NIC）或外部裝置要讀寫系統記憶體時，所有存取都由 CPU 控制。
  * 產生問題：
    * CPU 成為瓶頸（Bottleneck）：資料必須從「裝置 → CPU → 記憶體」或反向搬運，CPU 淪為純粹的資料搬運工。
    * CPU 負載極高：單純為了資料傳輸，CPU 使用率可能飆升至 90%～100%，無法專注於核心運算。
2. DMA 的運作機制
  * 引入 DMA 控制器（DMA Controller）：主機板上負責協調的晶片或邏輯單元。
  * 建立 DMA 通道（DMA Channel）：
    * 當網卡需要讀寫記憶體時，CPU 僅負責指派並開放一個 DMA 通道。
    * 通道建立後，CPU 便功成身退。
  * 直接傳輸：網卡透過 DMA 通道，直接將資料寫入系統記憶體，或直接從記憶體讀取，完全繞過（Bypass）CPU。
  * 廣泛應用：現代大部分裝置均支援 DMA，如硬碟、音效卡、USB 裝置、網卡等。

傳統方式 vs. DMA 效益比較

| 比較項目 | 傳統架構（CPU 中介） | 引入 DMA 架構 |
| :--- | :--- | :--- |
| **CPU 角色** | 負責全程複製與搬運資料 | 僅負責通道建立與完成通知（Setup & Notification） |
| **資料路徑** | 裝置 $\leftrightarrow$ CPU $\leftrightarrow$ 記憶體 | 裝置 $\leftrightarrow$ 記憶體（直接傳輸） |
| **CPU 使用率** | 高達 **90% ～ 100%** | 大幅降至 **5% ～ 10%** |
| **傳輸效能** | 較慢，受限於 CPU 頻寬 | 傳輸速度提升 **10 ～ 100 倍** |
| **運算效率** | CPU 忙於搬運，無法運算 | 釋放 CPU 資源，專注執行核心運算 |

## RDMA (Remote Direct Memory Access)

1. 什麼是 RDMA？
* 「跨越網路的 DMA」（DMA over the network）
* 允許一台電腦透過網路，直接讀取或寫入另一台電腦的記憶體，過程中完全不需要雙方的 CPU 或作業系統（OS）介入（Zero-copy、Kernel Bypass）。

2. 傳統網路傳輸 vs. RDMA
* 傳統網路傳輸（CPU 是瓶頸）：
  * 當主機 A 要讀寫主機 B 的資料時，請求必須先經過兩邊的作業系統與 CPU。
  * CPU 必須負責封包拆解、搬移資料到記憶體，導致 CPU 運算負載過高、延遲增加。
* RDMA 運作方式：
  * 結合兩端主機的 DMA 能力，搭配高效能網路（如 InfiniBand）。
  * 在硬體網卡與遠端記憶體之間直接建立 RDMA Channel（傳輸通道）。
  * 資料直接在兩台主機的記憶體之間移動，徹底繞過兩端的 CPU 與作業系統核心。
3. RDMA 的三大核心優勢
  * 大幅釋放 CPU 資源：雙方 CPU 完全不參與資料搬運，可全速投入實際運算任務。
  * 極致降低延遲（Ultra-low Latency）：少了 OS 核心與 CPU 中介的排程等待，網路通訊延遲顯著下降。
  * 大幅提升系統吞吐量（High Throughput）：讓網路頻寬得到最大化的利用。

4.  應用場景與支援的網路技術

  * 主要應用領域：
    * 高效能運算（HPC, High-Performance Computing）。
    * AI / GPU 叢集運算（如 NVIDIA 在多 GPU 節點互連上的大量應用）。
  * 支援 RDMA 的網路技術（不限於 InfiniBand）：
    * InfiniBand：RDMA 最初就是作為 InfiniBand 規格的一部分而誕生，原生支援度與效能最佳。
    * RoCE（RDMA over Converged Ethernet）：讓企業可以在標準無損乙太網路上運行 RDMA。
    * iWARP：透過標準的 TCP/IP 協定來傳遞 RDMA 流量。

基於 InfiniBand 的跨節點 RDMA 完整架構圖:

在 InfiniBand 架構中，網卡稱為 HCA（Host Channel Adapter），網路拓撲由 Subnet Manager（子網管理器） 統一管理。兩端節點透過 InfiniBand 交換機直接進行記憶體對讀寫：

```text
+=============================================================================+
|                                主機 A (Host A)                              |
|                                                                             |
|  +-------------------+                      +----------------------------+  |
|  |       CPU A       | --- 建立連線通道 ---> | 作業系統 / 驅動 (OFED 等)    |  |
|  |   (初始化完成後    |                      +----------------------------+  |
|  |    即退出資料路徑) |                                   |                        |
|  +-------------------+                                    | (通道就緒)             |
|                                                           v                 |
|  +-------------------+    直接 DMA 讀寫     +----------------------------+  |
|  |   系統記憶體 A     | <=================> |     InfiniBand 網卡        |  |
|  |  (System Memory)  |   (Zero-Copy 路徑)  |        (HCA 卡)            |  |
|  +-------------------+                      +--------------+-------------+  |
+============================================================|================+
                                                             |
                                               InfiniBand 實體鏈路 (QSFP 纜線)
                                                             |
                                                             v
                   +---------------------------------------------------+
                   |         InfiniBand 網路交換網路 (IB Fabric)       |
                   |                                                   |
                   |        +---------------------------------+        |
                   |        |   InfiniBand 交換機 (IB Switch) |        |
                   |        +----------------+----------------+        |
                   |                         |                         |
                   |        +----------------+----------------+        |
                   |        | 子網管理器 (Subnet Manager, SM)  |        |
                   |        | (負責路徑規劃、LID 配置與路由排程) |        |
                   |        +---------------------------------+        |
                   +-------------------------+-------------------------+
                                             |
                               InfiniBand 實體鏈路 (QSFP 纜線)
                                             |
+============================================|================================+
|                                主機 B (Host B) v                            |
|                                                                             |
|  +-------------------+    直接 DMA 讀寫     +----------------------------+  |
|  |   系統記憶體 B     | <=================> |     InfiniBand 網卡        |  |
|  |  (System Memory)  |   (Zero-Copy 路徑)  |        (HCA 卡)            |  |
|  +-------------------+                      +----------------------------+  |
|                                                                             |
|  +-------------------+                                                      |
|  |       CPU B       | <--- 完全不被打擾！無中斷（Interrupt-Free）           |
|  |  (100% 專注於     |                                                      |
|  |   AI / HPC 運算)  |                                                      |
|  +-------------------+                                                      |
+=============================================================================+
```

## Data Transfer Using Traditional Network
1. 傳統 TCP/IP 網路的運作流程
  表面上看似是「應用程式與網卡溝通」，但實際上經過了繁複的軟體層層中介：
    * 應用程式（Application）：呼叫 Socket 函式庫建立連線。
    * 作業系統核心（OS Kernel / TCP/IP 堆疊）：負責 TCP/IP 封包封裝、連線狀態控制、緩衝區排程。
    * 網卡驅動程式（NIC Driver）：作業系統通知驅動程式準備傳輸。
    * 實體網卡（NIC）：將資料送上實體網路纜線。

> [!NOTE]
> 核心問題：作業系統（OS）與 CPU 在整個過程中扮演了沉重的「中間人」（Middleman），大量消耗主機的運算資源。
>

2.  傳統網路面臨的三大瓶頸與限制
  * 高延遲（High Latency）：
    * 封包必須穿越多個軟體層（Socket $\rightarrow$ TCP/IP 堆疊 $\rightarrow$ Driver）。
    * 使用者空間（User Space）與核心空間（Kernel Space）頻繁發生**環境切換（Context Switch）**，每一層軟體處理都需要時間累積。
  * **CPU 成為效能與擴展性瓶頸（CPU Bottleneck & Scalability Issue）**：
     * 所有的傳輸控制、中斷處理（Interrupts）、校驗和計算均由 CPU 掌控。
     * 資料傳輸量愈大，CPU 使用率愈高，限制了叢集的横向擴展能力。
  * **無效率的多次記憶體複製（Multiple Memory Copies）**：
     * 資料在抵達對端應用程式前，必須經歷**多次記憶體搬移**。
3.  傳統傳輸的「記憶體複製鏈」（Memory Copies）
  資料流路徑說明傳統方式有多耗費資源：

```text
【發送端主機】
1. 應用程式緩衝區 (App Memory)
   └── (CPU 複製) ──> 2. 作業系統核心緩衝區 (Kernel Buffer)
                       └── (DMA 搬移) ──> 3. 發送端網卡 (NIC)
                                               │
                                               │ [實體網路傳輸]
                                               ▼
【接收端主機】
6. 接收端應用程式緩衝區 (App Memory)
   ▲── (CPU 複製) ── 5. 作業系統核心緩衝區 (Kernel Buffer)
                       ▲── (DMA 搬移) ── 4. 接收端網卡 (NIC)
```

> [!NOTE]
> * **痛點**：資料被重複拷貝多次，佔用大量的記憶體頻寬與 CPU 快取（Cache），大幅拖慢了整體資料傳輸速度。
>

## RDMA - Analogy

1. RDMA 解決問題的三大核心手段
  RDMA 能大幅超越傳統網路效能，關鍵在於落實了以下三件事：
  1. **去除多餘層級（Removes the layers）**：直接繞過作業系統核心與 TCP/IP 堆疊（Kernel & Stack Bypass）。
  2. **卸載 CPU 負擔（Offloads the CPU）**：資料傳輸與協定處理完全交由專屬硬體網卡負責。
  3. **消除記憶體複製（Eliminates copy）**：實現真正的 **Zero-Copy（零複製）**。

2. RDMA 的實際運作機制
  * **不再建立傳統 Socket**：應用程式不再透過傳統的 Socket Library 建立 TCP 連線。
  * **引入 RDMA Verbs 與 RDMA Library**：
    * 應用程式透過 **RDMA** 發出讀寫請求。
    * 由 **RDMA Library** 直接將請求轉交給支援 RDMA 的硬體網卡（RNIC / HCA）。
  * **極簡資料路徑**：
    $$\text{應用程式 (Verbs)} \xrightarrow{\text{RDMA Library}} \text{RDMA 網卡} \xrightarrow{\text{實體網路}} \text{遠端記憶體}$$
    **整個過程完全沒有作業系統（OS）與 CPU 的介入**
3. 比喻：傳統快遞 vs. 即時專差直達

  用寄送包裹做了一個非常精闢的對比：

  1. 傳統 TCP/IP 網路 $\approx$ 傳統郵政物流（如郵局、USPS、英國皇家郵政）
    * **流程**：你把包裹交給收件員 $\rightarrow$ 送進**本地倉庫** $\rightarrow$ **分揀（Sorting）** $\rightarrow$ **重複拆箱打包（Repackaging）** $\rightarrow$ 轉運至多個中繼轉運站（Hubs） $\rightarrow$ 每個倉庫逐一**掃描條碼（Scanning）** $\rightarrow$ 最終由外送員送達。
    * **技術對照**：
      * 倉庫與轉運站 $=$ 作業系統核心的緩衝區（Kernel Buffers）。
      * 分揀與拆箱打包 $=$ TCP/IP 堆疊的標頭封裝與解封裝、分段。
      * 流程繁瑣、多次搬動，**導致整體延遲高、耗費大量人力（CPU 負載高）**。

  2. RDMA $\approx$ 點對點專差直達（如印度的 Porter、台灣的 Lalamove）
    * **流程**：你在 App 下單 $\rightarrow$ 專差外送員到你家門口拿包裹 $\rightarrow$ **不進轉運倉庫、不分揀、不重新包裝** $\rightarrow$ 直接騎車狂奔送到目的地收件人家門口交付。
    * **技術對照**：
      * **無中轉倉庫** $=$ 繞過作業系統（Kernel Bypass）。
      * **無重複打包** $=$ 無多次記憶體複製（Zero-Copy）。
      * **專差直達** $=$ RDMA 網卡與通道直接對傳，速度提升數十至數百倍。

### 核心架構對照表

| 特性 / 環節 | 傳統 TCP/IP 網路 | RDMA 網路 |
| :--- | :--- | :--- |
| **連線/操作介面** | Socket API | **RDMA API** |
| **通訊協定堆疊** | OS TCP/IP 軟體堆疊 | **全硬體卸載（繞過 TCP/IP）** |
| **作業系統 (OS)** | 關鍵中介人（耗損嚴重） | **完全退出（Bypass）** |
| **CPU 角色** | 負責封包組裝與記憶體複製 | **完全不參與資料傳輸** |
| **記憶體複製次數** | 3 ~ 4 次（App $\rightarrow$ Kernel $\rightarrow$ NIC） | **0 次（Zero-Copy，直通網卡）** |
| **比喻** | 逐站分揀掃描、轉運集散倉 | **專人點對點取貨直達** |

## Zero-Copy Transfers


### 1. 傳統網路傳輸的「4 次拷貝」陷阱

在傳統 TCP/IP 網路中，一筆資料從發送端 App 傳到接收端 App，一共要經歷 **4 次記憶體拷貝**，且每次都需要 CPU 介入：

```text
【發送端 (Source)】
  [1. App 記憶體] ──(第 1 次拷貝: CPU 介入)──> [2. Kernel 核心記憶體]
  [2. Kernel 記憶體] ──(第 2 次拷貝: CPU 介入)──> [3. 網卡硬體緩衝區]
                                                      │
                                                      │ (實體網路傳輸)
                                                      ▼
【接收端 (Destination)】
  [6. App 記憶體] <──(第 4 次拷貝: CPU 介入)── [5. Kernel 核心記憶體]
  [5. Kernel 記憶體] <──(第 3 次拷貝: CPU 介入)── [4. 網卡硬體緩衝區]
```
* **代價**：寶貴的 CPU 運算週期（CPU Cycles）與記憶體頻寬全部浪費在「把資料搬過來、搬過去」的無效作業中。

### 2. RDMA 如何實現「零複製（Zero-Copy）」？

RDMA 並非「不用傳輸資料」，而是指**完全消除了作業系統核心緩衝區的中轉拷貝**。其運作分為兩大階段：

##### 階段 1：交換記憶體位址與金鑰（Handshake / Permission）
1. **劃定記憶體**：接收端主機先在自己的系統記憶體中，劃出一塊專屬的記憶體區塊。
2. **核發金鑰（Key）**：接收端為此區塊綁定存取權限與安全金鑰（`rkey`）。
3. **通知發送端**：接收端把「記憶體位址範圍（Address Range）」與「金鑰」直接告知發送端：「你可以直接把資料寫到我這塊空間，不用走繁瑣的拷貝流程」。

##### 階段 2：硬體直接 DMA 對傳（Direct Data Transfer）
1. **呼叫 RDMA Verbs**：發送端 App 透過 RDMA Verbs 指令通知自己的網卡（RNIC/HCA）準備傳送。
2. **網卡直接讀取**：發送端網卡利用本機 DMA，**直接從發送端 App 記憶體讀取資料**。
3. **攜帶金鑰送出**：封包內夾帶了目標記憶體位址與金鑰，送上網路。
4. **硬體驗證並直寫**：
   * 接收端網卡收到封包，硬體晶片自動比對金鑰與位址，確認合法。
   * 接收端網卡直接透過 DMA **將資料寫入接收端的指定記憶體位置**。
5. **App 直接取用**：接收端 App 直接從該記憶體讀取資料，**雙方 CPU 在傳輸過程中完全沒有參與任何資料拷貝**


### 核心對照：4 次拷貝 vs. 零複製

| 比較項目 | 傳統網路傳輸 | RDMA 傳輸（Zero-Copy） |
| :--- | :--- | :--- |
| **記憶體複製次數** | **整整 4 次**（App $\leftrightarrow$ Kernel $\leftrightarrow$ NIC） | **0 次**（直接從記憶體 $\leftrightarrow$ 網卡） |
| **資料流向** | App $\rightarrow$ 核心 $\rightarrow$ 網卡 $\rightarrow$ 網卡 $\rightarrow$ 核心 $\rightarrow$ App | **發送端 RAM $\xrightarrow{\text{硬體直連}}$ 接收端 RAM** |
| **安全性控制** | 由作業系統核心（OS Kernel）層層把關 | 透過硬體驗證的 **Memory Key（金鑰權限）** 保障安全 |
| **CPU 消耗** | 雙端 CPU 深度參與每一次拷貝 | **雙端 CPU 0% 介入資料複製** |
| **延遲表現** | 毫秒（ms）或高微秒級 | **極低微秒級（Sub-microsecond）** |


```text
======================= Traditional Data Transfer ======================= | ===================== RDMA Data Transfer (Zero-Copy) =====================
Data copied by CPU multiple times through TCP/IP stack before reaching     | Data moved directly to destination memory by NICs using DMA.
application memory                                                         | No CPU Involvement, zero copies.
-------------------------------------------------------------------------- | --------------------------------------------------------------------------
                                                                           |
 [CPU]                               [CPU]                                 | <------- Shares: Memory address & rkey (permission) -------
+-----------------+   +-----------------+                                  | +-----------------+   +-----------------+
|   Source Host   |   |   Destn. Host   |                                  | |   Source Host   |   |   Destn. Host   |
|                 |   |                 |                                  | |                 |   |                 |
| [App]    [Data] |   | [Data]    [App] |                                  | | [App]    [Data] |   | [Data]    [App] |
|        |        |   |        ^        |                                  | |        |        |   |        ^        |
|     [ COPY ]    |   |     [ COPY ]    |                                  | |        |        |   |        |        |
|        v        |   |        |        |                                  | |        |        |   |        |        |
| [Kernel] [Data] |   | [Data] [Kernel] |                                  | |        | (DMA)  |   |  (DMA) |        |
|        |        |   |        ^        |                                  | |        |        |   |        |        |
|     [ COPY ]    |   |     [ COPY ]    |                                  | |        |        |   |        |        |
|        v        |   |        |        |                                  | |        v        |   |        |        |
| [ NIC ]  [Data] |   | [Data]  [ NIC ] |                                  | | [ NIC ]  [READ] |   | [WRITE] [ NIC ] |
+--------+--------+   +--------+--------+                                  | +--------+--------+   +--------+--------+
         |                     ^                                           |          |                     ^
         |   +-------------+   |                                           |          |   +-------------+   |
         +-->|Data Transfer|---+                                           |          +-->|Data Transfer|---+
             |   Network   |                                               |              |   Network   |
             +-------------+                                               |              +-------------+
```

## RDMA API

1. 什麼是 RDMA Verbs

  定義：RDMA Verbs 是應用程式用來直接與網路硬體（網卡）對話的低階指令集（Low-level Commands）或 API。
  角色定位：它取代了傳統 Socket API（如 connect(), send(), recv()），讓應用程式可以直接跨過作業系統核心，向支援 RDMA 的網卡下達記憶體讀寫任務。

2. 為什麼叫做「Verbs（動詞）」？

* **字面意義**：就像英文文法中的「動詞（Verb）」代表**動作**一樣，RDMA Verbs 的每一個 API 都是在對硬體宣告一項具體的物理動作：
  * **`register`**（註冊）：向網卡註冊一塊記憶體區塊。
  * **`create`**（建立）：建立通訊通道或佇列對（Queue Pair）。
  * **`send`**（發送）：將本地資料主動推送至對端。
  * **`write`**（寫入）：**直接將資料寫入遠端主機的記憶體**。
  * **`read`**（讀取）：**直接從遠端主機的記憶體抓取資料**。
  * **`poll`**（輪詢）：向網卡查詢傳輸完成狀態。

3. RDMA Verbs 運作架構圖解

```text
+-----------------------------------------------+
|             應用程式 (Application)            |
+-----------------------------------------------+
                       |
                       | 呼叫 RDMA Verbs API (發出動作指令)
                       | 例如: "RDMA Write to Remote Addr 0x1234"
                       v
+-----------------------------------------------+
|         RDMA 函式庫 (libibverbs / 驅動)        |
+-----------------------------------------------+
                       |
                       | (Kernel Bypass 直接旁路傳遞)
                       v
+-----------------------------------------------+
|         支援 RDMA 的網卡 (HCA / RNIC)          |
+-----------------------------------------------+
```

* **應用程式下達指令的方式非常直觀**：
  * *「把這批資料直接寫入那台機器的記憶體區塊」*（RDMA Write）
  * *「直接去抓取那台機器特定記憶體區塊的資料」*（RDMA Read）
  * 網卡硬體接到 Verbs 指令後，便在背景自動利用 DMA 完成跨網路的記憶體搬運。

4. 專業補充 - Verbs 的兩大傳輸模式

在 RDMA Verbs 中，主要分為以下兩種通訊操作模式：
1. **單邊操作（One-Sided Operations，如 RDMA Write / Read）**：
   * 發送端只要擁有對方的記憶體位址和 `rkey`，就可以**直接讀寫對端記憶體**。
   * **對端的 CPU 完全不知情、不需做任何回應**，是極致效能的代表。
2. **雙邊操作（Two-Sided Operations，如 RDMA Send / Receive）**：
   * 發送端發送 `Send`，接收端必須預先掛上 `Receive` 佇列來接收。
   * 類似傳統訊息傳遞，但傳輸過程依然維持零複製與繞過作業系統。


## RDMA Demo

1. ib_write_bw
```bash
$ sudo ib_write_bw -d mlx5_0
************************************
* Waiting for client to connect... *
************************************
---------------------------------------------------------------------------------------
                    RDMA_Write BW Test
 Dual-port       : OFF          Device         : mlx5_0
 Number of qps   : 1            Transport type : IB
 Connection type : RC           Using SRQ      : OFF
 PCIe relax order: ON           Lock-free      : OFF
 ibv_wr* API     : ON           Using Enhanced Reorder      : OFF
 CQ Moderation   : 1
 CQE Poll Batch  : Dynamic
 Mtu             : 4096[B]
 Link type       : IB
 Max inline data : 0[B]
 rdma_cm QPs     : OFF
 Data ex. method : Ethernet
---------------------------------------------------------------------------------------
 local address: LID 0x22 QPN 0x0049 PSN 0x1e0543 RKey 0x1fff00 VAddr 0x007b37b4b7a000
 remote address: LID 0x22 QPN 0x004a PSN 0x2c4190 RKey 0x200000 VAddr 0x007cd02182b000
---------------------------------------------------------------------------------------
 #bytes     #iterations    BW peak[MiB/sec]    BW average[MiB/sec]   MsgRate[Mpps]
 65536      5000             40009.70            39998.67                    0.639979
---------------------------------------------------------------------------------------
```

```bash
$ sudo ib_write_bw -d mlx5_0 localhost
[sudo] password for jcda10: 
---------------------------------------------------------------------------------------
                    RDMA_Write BW Test
 Dual-port       : OFF          Device         : mlx5_0
 Number of qps   : 1            Transport type : IB
 Connection type : RC           Using SRQ      : OFF
 PCIe relax order: ON           Lock-free      : OFF
 ibv_wr* API     : ON           Using Enhanced Reorder      : OFF
 TX depth        : 128
 CQ Moderation   : 1
 CQE Poll Batch  : Dynamic
 Mtu             : 4096[B]
 Link type       : IB
 Max inline data : 0[B]
 rdma_cm QPs     : OFF
 Data ex. method : Ethernet
---------------------------------------------------------------------------------------
 local address: LID 0x22 QPN 0x004a PSN 0x2c4190 RKey 0x200000 VAddr 0x007cd02182b000
 remote address: LID 0x22 QPN 0x0049 PSN 0x1e0543 RKey 0x1fff00 VAddr 0x007b37b4b7a000
---------------------------------------------------------------------------------------
 #bytes     #iterations    BW peak[MiB/sec]    BW average[MiB/sec]   MsgRate[Mpps]
Conflicting CPU frequency values detected: 3300.000000 != 1832.459000. CPU Frequency is not max.
 65536      5000             40009.70            39998.67                    0.639979
---------------------------------------------------------------------------------------
```


* 觀察連線握手資訊中的 LID 0x22：
  * 十六進位 0x22 轉為十進位就是 34。
  * 對照拓撲：gpu-node-0005 mlx5_0 的 LID 正好就是 34
  * 這項測試是直接在 gpu-node-0005（GPU 運算節點） 上執行的。封包從該網卡打出，經過外部的 MQM9700 交換器再折返回來（Hairpin），驗證了完整的端到端實體通道。

連線設定參數解析（Header Parameters）

```text
 Dual-port       : OFF          Device         : mlx5_0
 Number of qps   : 1            Transport type : IB
 Connection type : RC           Using SRQ      : OFF
 PCIe relax order: ON           Lock-free      : OFF
 Mtu             : 4096[B]      Link type      : IB
 Data ex. method : Ethernet
```

* **`Connection type : RC`（Reliable Connection）**：採用可靠連線模式，保證封包不遺失、不重複且循序到達（相當於 RDMA 世界的 TCP）。
* **`Number of qps : 1`**：**僅使用 1 個佇列對（Single Queue Pair）** 傳輸。
* **`PCIe relax order : ON`**：啟用 PCIe 寬鬆定序（Relaxed Ordering），能減少 PCIe 匯流排等待，大幅提升現代 CPU 與網卡間的傳輸吞吐量。
* **`Mtu : 4096[B]`**：採用 **4KB MTU**，這是 InfiniBand 追求極致效能的最佳 MTU。
* **`Data ex. method : Ethernet`**：
  * **為什麼寫 Ethernet？**  
    這指的是兩端最初交換記憶體位址（VAddr）、金鑰（RKey）與 QPN 的**初始握手控制通道**是透過本機的 TCP/IP Socket（走 loopback）交換；隨後的**大量資料傳輸則是純走 InfiniBand（`Link type: IB`）**。

握手位址拆解（Address Handshake）

```text
local address:  LID 0x22 QPN 0x0049 PSN 0x1e0543 RKey 0x1fff00 VAddr 0x007b37b4b7a000
remote address: LID 0x22 QPN 0x004a PSN 0x2c4190 RKey 0x200000 VAddr 0x007cd02182b000
```
RDMA Write 屬於**單邊操作（One-Sided RDMA）**，發起端網卡直接寫入對端記憶體，完全不打擾對端 CPU。因此雙方需先透過連線交換：
* **`QPN`（Queue Pair Number）**：本地為 `0x0049`，對端為 `0x004a`。
* **`VAddr`**：對端已註冊並開放寫入的記憶體虛擬位址（Virtual Address）。
* **`RKey`**：遠端記憶體保護金鑰（Remote Key），確保只有持金鑰的 QP 才能寫入該記憶體區段。


核心效能結果解讀

```text
 #bytes     #iterations    BW peak[MiB/sec]    BW average[MiB/sec]   MsgRate[Mpps]
 65536      5000             40009.70            39998.67                    0.639979
```

| 欄位 | 數據數值 | 換算與實務意義 |
| :--- | :--- | :--- |
| **`#bytes`** | `65536` (64 KB) | 單次傳輸的封包酬載大小（Payload Size）。 |
| **`#iterations`** | `5000` 次 | 測試連續寫入 5000 次取平均。 |
| **`BW average`** | **`39998.67 MiB/sec`** | 平均頻寬達約 **40,000 MiB/s**！ |
| **`MsgRate`** | `0.639979 Mpps` | 每秒傳輸約 **64 萬個** 64KB 封包。 |


想要壓榨出 400G NDR 的理論極限，可以嘗試加入以下參數：

```bash
# 1. 使用 4 個 Queue Pairs 並行傳輸 (-q 4)
$ sudo ib_write_bw -d mlx5_0 -q 4 localhost

# 2. 測試雙向同時對傳 (-b, Bidirectional)
$ sudo ib_write_bw -d mlx5_0 -b localhost

# 3. 測試不同訊息大小的頻寬曲線 (由小到大)
$ sudo ib_write_bw -d mlx5_0 -a localhost
```

2. ib_write_lat


ib_write_lat 就是在測量一滴水從這端流到那端要花多少時間（極限延遲 Latency）**。

```bash
$ sudo ib_write_lat -d mlx5_0
\Disabling dynamic polling

************************************
* Waiting for client to connect... *
************************************
---------------------------------------------------------------------------------------
                    RDMA_Write Latency Test
 Dual-port       : OFF          Device         : mlx5_0
 Number of qps   : 1            Transport type : IB
 Connection type : RC           Using SRQ      : OFF
 PCIe relax order: OFF          Lock-free      : OFF
 ibv_wr* API     : ON           Using Enhanced Reorder      : OFF
 Mtu             : 4096[B]
 Link type       : IB
 Max inline data : 220[B]
 rdma_cm QPs     : OFF
 Data ex. method : Ethernet
---------------------------------------------------------------------------------------
 local address: LID 0x22 QPN 0x004d PSN 0xa36066 RKey 0x1ffbb9 VAddr 0x006300b0253000
 remote address: LID 0x22 QPN 0x004b PSN 0x347c72 RKey 0x1ffcba VAddr 0x0062181bbb1000
---------------------------------------------------------------------------------------
 #bytes #iterations    t_min[usec]    t_max[usec]  t_typical[usec]    t_avg[usec]    t_stdev[usec]   99% percentile[usec]   99.9% percentile[usec] 
Conflicting CPU frequency values detected: 3300.000000 != 1760.259000. CPU Frequency is not max.
Conflicting CPU frequency values detected: 3300.000000 != 5024.684000. CPU Frequency is not max.
 2       1000          1.19           2.31         1.25                1.25             0.00            1.32                    2.31   
---------------------------------------------------------------------------------------
```


```bash
$ sudo ib_write_lat -d mlx5_0 localhost
Disabling dynamic polling
---------------------------------------------------------------------------------------
                    RDMA_Write Latency Test
 Dual-port       : OFF          Device         : mlx5_0
 Number of qps   : 1            Transport type : IB
 Connection type : RC           Using SRQ      : OFF
 PCIe relax order: OFF          Lock-free      : OFF
 ibv_wr* API     : ON           Using Enhanced Reorder      : OFF
 TX depth        : 1
 Mtu             : 4096[B]
 Link type       : IB
 Max inline data : 220[B]
 rdma_cm QPs     : OFF
 Data ex. method : Ethernet
---------------------------------------------------------------------------------------
 local address: LID 0x22 QPN 0x004b PSN 0x347c72 RKey 0x1ffcba VAddr 0x0062181bbb1000
 remote address: LID 0x22 QPN 0x004d PSN 0xa36066 RKey 0x1ffbb9 VAddr 0x006300b0253000
---------------------------------------------------------------------------------------
 #bytes #iterations    t_min[usec]    t_max[usec]  t_typical[usec]    t_avg[usec]    t_stdev[usec]   99% percentile[usec]   99.9% percentile[usec] 
Conflicting CPU frequency values detected: 3300.000000 != 1760.259000. CPU Frequency is not max.
Conflicting CPU frequency values detected: 3300.000000 != 5024.684000. CPU Frequency is not max.
 2       1000          1.24           2.26         1.25                1.25             0.00            1.31                    2.26   
---------------------------------------------------------------------------------------
```

關鍵參數


1. **`Disabling dynamic polling`（關閉動態輪詢）**：
   * 為了測量絕對極限延遲，程式停用了省電或批次等待機制，改用 **CPU 死循環密集輪詢（Busy Polling）**，完成事件一抵達就被立即捕獲。
2. **`TX depth : 1`（傳送深度為 1）**：
   * 延遲測試採用嚴格的「乒乓機制（Ping-Pong）」——發出 1 個封包 $\rightarrow$ 等待對端確認收到 $\rightarrow$ 再發下一個，完全不進行管線化（Pipeline）堆疊。
3. **`Max inline data : 220[B]`（行內資料技術，關鍵！）**：
   * 這次測試的訊息大小僅有 **2 Bytes**（`#bytes 2`）。
   * 由於小於 220 Bytes，網卡啟用了 **Inline Data** 機制：**資料直接被塞進 PCIe 的 Work Queue 指令中，完全跳過了主機記憶體 DMA 讀取的步驟**，大幅減少了 PCIe 往返次數！

核心延遲數據解析

```text
 #bytes #iterations    t_min[usec]    t_max[usec]  t_typical[usec]    t_avg[usec]    t_stdev[usec]   99% percentile[usec]   99.9% percentile[usec] 
 2       1000          1.19           2.31         1.25                1.25             0.00            1.32                    2.31   
```

| 延遲指標 | 數值（微秒） | 實務代表意義 |
| :--- | :---: | :--- |
| **`t_min`（最小延遲）** | **1.19 $\mu s$** | 1000 次測試中跑出的最佳極限。 |
| **`t_avg`（平均延遲）** | **1.25 $\mu s$** | 整個往返測試的平均單向延遲。 |
| **`t_typical`（典型延遲）** | **1.25 $\mu s$** | 中位數（最常出現的延遲數值）。 |
| **`t_stdev`（標準差）** | **0.00 $\mu s$** | **極致穩定！** 幾乎所有封包的延遲都完全一致，沒有網路抖動（Jitter）。 |
| **`99% percentile`** | **1.32 $\mu s$** | 99% 的傳輸都在 1.32 微秒內完成。 |
| **`99.9% percentile`** | **2.31 $\mu s$** | 尾端延遲（Tail Latency），最慢的千分之一封包也只需 2.31 微秒。 |

如果要查看*不同大小封包*的延遲曲線，可以加上 `-a` 參數，它會自動測試從 2 Bytes 到 8 MB 的各級延遲變化：

```bash
$ sudo ib_write_lat -d mlx5_0 -a localhost
```

### 總級

#### RDMA 寫入頻寬測試 (`ib_write_bw`)
* **測試方式**：
  * 接收端（Ubuntu 2）：執行 `ib_write_bw` 等待連線。
  * 發送端（Ubuntu 1）：執行 `ib_write_bw 192.168.0.219`（用 IP 建立初期的 Socket 握手連線）。
* **終端機輸出印證的 RDMA 理論**：
  * **Transport Type**：InfiniBand。
  * **連線模式**：**RC（Reliable Connection）**，確保資料無失真送達。
  * **Queue Pair (QP)**：雙端成功建立了一組 QP。
  * **交換授權**：終端機直接印出接收端分享的 **`rkey`（Remote Key）** 與 **`Memory Address`（目標記憶體實體位址）**。
  * **測試成果**：發送 64 KB 區塊共 5000 次，測得平均頻寬（MB/s）與每秒傳輸封包數（Message Rate）。

---

#### 三RDMA 寫入延遲測試 (`ib_write_lat`)
* **測試方式**：
  * 接收端：`ib_write_lat`
  * 發送端：`ib_write_lat 192.168.0.219`
* **重點現象**：
  * 每次執行測試時，接收端都會動態指派**不同的 rkey 與不同的記憶體位址**，保障傳輸安全性。
  * 測試封包極小（通常為 2 bytes），著重在計算端到端的往返反應時間。
  * 提供平均時間、標準差以及高百分位數（99.99% Tail Latency），單位為**微秒（$\mu s$）**。

#### 區別

NVIDIA 網路認證考試常會給定應用情境，測驗考生應使用哪一套工具：

| 比較項目 | `ib_write_bw`（頻寬測試） | `ib_write_lat`（延遲測試） |
| :--- | :--- | :--- |
| **測試核心** | **速度 / 吞吐量（Throughput）** | **延遲 / 響應能力（Responsiveness）** |
| **資料區塊大小** | 大封包（如 64 KB） | 極小封包（預設 2 Bytes） |
| **度量指標 (Metrics)** | **MB/s** 或 **Gbps**、Message Rate | **微秒（$\mu s$, Microsecond）**、百分位延遲 |
| **適用評估場景** | 評估大規模模型資料搬運、儲存寫入的最大頻寬 | 評估高頻交易、分散式鎖定、訊號同步的極致低延遲 |
