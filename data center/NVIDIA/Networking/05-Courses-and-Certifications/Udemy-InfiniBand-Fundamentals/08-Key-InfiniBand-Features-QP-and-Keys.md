## Key InfiniBand Features

**為什麼 InfiniBand 是運行 RDMA 的理想選擇**。核心原因在於它具備以下 4 大關鍵特性：

1. **隊列對（Queue Pair, QP）機制**
* 傳輸主要介面，由 **Send Queue（發送隊列）** 與 **Receive Queue（接收隊列）** 成對組成。
* **硬體層面直接實現**：直接在底層核心建立隊列，無需走傳統作業系統的 Socket 機制。


2. **記憶體註冊與金鑰機制（Memory Registration & Key Mechanism）**
* 可在可用記憶體中鎖定（Pin/Block）特定區域。
* 綁定 **Local Key（本地金鑰）** 與 **Remote Key（遠端金鑰）**，使遠端節點能安全地直接操作與讀寫該記憶體。


3. **硬體卸載能力（Hardware Offload）**
* 傳輸請求直接交由網卡（NIC / HCA）硬體處理，繞過作業系統核心與 CPU 干預，降低延遲與處理器負載。


4. **無損與基於信用的流量控制（Lossless / Credit-based Flow Control）**
* 採用 Credit-based 機制防止緩衝區溢位，確保網路傳輸不掉包（Lossless），滿足 RDMA 對極致穩定與低延遲的要求。

## Queue Pair

1. 什麼是 Queue Pair (QP)？

* **基本定義**：InfiniBand/RDMA 中的**基礎通訊端點（Communication Endpoint）**。所有應用程式的資料傳輸與接收皆透過 QP 進行。
* **組成結構**：成對存在，包含一個 **Send Queue（發送隊列）** 與一個 **Receive Queue（接收隊列）**。每個 QP 都會被分配一個唯一的編號（QPN），單一應用可依需求建立多個 QP。

以下為應用程式透過 **Queue Pair (QP)** 與 **Completion Queue (CQ)** 進行內核旁路（Kernel Bypass）與資料傳輸的系統架構圖：

```text
+-----------------------------------------------------------------------------------+
|                                 Host A (Initiator)                                |
|  [ User Space Application ]                                                       |
|        |                                                                          |
|        | (1) Post WQE (Send / Read / Write) via libibverbs (Kernel Bypass)        |
|        v                                                                          |
|  +-----------------------------------------------------------------------------+  |
|  |                   ConnectX HCA (Hardware Adapter)                           |  |
|  |                                                                             |  |
|  |  +--------------------------- Queue Pair (QP) ---------------------------+  |  |
|  |  |                                                                       |  |  |
|  |  |  [ Send Queue (SQ) ]    --> 保存待發送/寫入之工作請求 (Work Queue Entry)  |  |  |
|  |  |  [ Receive Queue (RQ) ] --> 保存預先配置之接收緩衝區請求                |  |  |
|  |  +-----------------------------------------------------------------------+  |  |
|  |                                     |                                       |  |
|  |                                     | (2) DMA Transfer & Processing         |  |  |
|  |                                     v                                       |  |
|  |  +-----------------------------------------------------------------------+  |  |
|  |  |  [ Completion Queue (CQ) ] --> 任務完成時生成 CQE (Completion Entry)    |  |  |
|  |  +-----------------------------------------------------------------------+  |  |
|  +------------------------------------|----------------------------------------+  |
+---------------------------------------|-------------------------------------------+
                                        |
                 [ InfiniBand / RoCE High-Speed Fabric ]
                                        |
+---------------------------------------v-------------------------------------------+
|                                  Host B (Target)                                  |
|  +-----------------------------------------------------------------------------+  |
|  |                   ConnectX HCA (Hardware Adapter)                           |  |
|  |  +--------------------------- Queue Pair (QP) ---------------------------+  |  |
|  |  |  [ Send Queue (SQ) ]                                                  |  |  |
|  |  |  [ Receive Queue (RQ) ] --> 匹配對端 RDMA/Send 操作                      |  |  |
|  |  +-----------------------------------------------------------------------+  |  |
|  |  +------------------------- [ Completion Queue (CQ) ] -------------------+  |  |
|  +------------------------------------|----------------------------------------+  |
|                                       | (3) Direct Memory Access (Zero-Copy)      |
|                                       v                                           |
|  [ User Space Application Memory / GPU Memory (NVIDIA PeerDirect) ]               |
+-----------------------------------------------------------------------------------+
```


2. QP 與傳統 Socket 的核心差異

| 比較維度 | 傳統 Socket 通訊 | RDMA Queue Pair (QP) |
| --- | --- | --- |
| **運作層級** | 作業系統核心（OS）+ TCP/IP 協定棧 | 網卡（NIC/HCA）硬體層直接維護隊列 |
| **主要驅動者** | **CPU-driven**（高度消耗 CPU 資源與引發中斷） | **NIC-driven**（硬體驅動，完全卸載至網卡） |
| **介面方式** | 經由 OS Socket Library 封裝成 Black Box | 經由 **RDMA Verbs** 函式庫直接操作硬體 |

3. QP 資料傳輸完整流程

1. **建立隊列（Create QP）**
* 應用程式透過 RDMA Verbs API（如 `ibv_create_qp`）向網卡申請建立 QP。


2. **提交工作請求（Post Work Request）**
* 應用程式將傳輸描述（Work Request, WR）放入 Send Queue。
* **關鍵點**：放入隊列的**不是資料本體**，而是傳輸指令（例如：本地記憶體位址範圍 A~B、遠端目標記憶體位址範圍 XYZ~PQR，以及對應的金鑰 Key）。


3. **硬體直接抓取並發送（DMA Fetch & Send）**
* 本地網卡從 Send Queue 讀取請求，透過 **DMA（Direct Memory Access）** 直接從本地記憶體抓取資料。
* 呼叫底層發送操作（`ibv_post_send`）將資料封裝並經由 InfiniBand Fabric 網路送出。


4. **遠端寫入（Remote Placement）**
* 遠端網卡收到封包後，依據先前提供的金鑰核驗許可，直接將資料寫入目標記憶體位址，**不打擾遠端 CPU**。


5. **完成通知（Completion Queue, CQ）**
* 資料傳輸完成後，網卡會將完成事件寫入**完成隊列（Completion Queue, CQ）**。
* 應用程式透過輪詢 CQ（如 `ibv_poll_cq`）確認傳輸狀態與結果。

## Memory Registration

1. 什麼是記憶體註冊（Memory Registration, MR）？

* **基本定義**：將系統記憶體（RAM）中的特定區塊向 RDMA 網卡進行註冊與鎖定，使網卡能夠直接對該區塊執行 DMA 操作。
* **解決的傳統痛點**：
  * **傳統模式**：任何存取 RAM 的動作都必須經過 CPU 處理與搬移。
  * **RDMA 模式**：劃分出專屬記憶體區塊交由網卡自主管理，**實現零拷貝（Zero-copy）**，無需 CPU 介入。
* **核心防護**：在硬體層級強制實施**存取權限控管與記憶體保護**，防止未授權操作或被其他應用惡意覆寫。

2. 雙金鑰授權機制（Two Keys Mechanism）

每次完成記憶體註冊時，系統會產生兩把專屬金鑰，用來嚴格限制存取權限：

| 金鑰類型 | 全名 | 用途與權限 |
| --- | --- | --- |
| **L_Key** | Local Key（本地金鑰） | 提供給**本地授權應用程式**。本地網卡在讀取或寫入這塊註冊記憶體時，會使用 L_Key 來驗證內部存取權限。 |
| **R_Key** | Remote Key（遠端金鑰） | 事先共享給**遠端節點（Remote Host）**。遠端節點發起 RDMA 讀寫操作時必須出示此金鑰，網卡確認符合設定權限（如唯讀或讀寫）才允許存取。 |

3. 比喻：智慧快遞密碼箱（Smart Delivery Box）

為了便於理解，使用智慧收件箱的比喻：

* **傳統郵筒 vs. 智慧密碼箱**：普通信箱任何人都能投遞；但智慧密碼箱設有密碼/金鑰，只有擁有權限的人才能打開存放包裹，避免被盜。
* **對應關係**：
  * **包裹（Package）** $\rightarrow$ 要傳輸的**資料（Data）**。
  * **智慧收件箱的空間** $\rightarrow$ 註冊好的**記憶體區間（Memory Range / MR）**。
  * **開箱密碼（Passcode）** $\rightarrow$ 存取驗證用的 **Key（L_Key / R_Key）**。
  * **屋主無需在家等候** $\rightarrow$ 傳輸過程**無需 CPU 在場等待或親自搬移資料**，既非同步又保證安全。
 
## Hardware Offload

**InfiniBand 主機通道適配器（HCA）** 如何透過「硬體卸載（Hardware Offload）」將傳統 CPU 與軟體堆疊的負擔完全轉移至專用硬體，並具體歸納了 **硬體層面執行的 5 大核心功能**：

1. 什麼是 InfiniBand 的硬體卸載？

* **核心概念**：傳統網路中由 CPU 和作業系統軟體堆疊（如 TCP/IP Stack）處理的傳輸邏輯、資料搬移及流控機制，被徹底轉移至專用的 InfiniBand HCA（Host Channel Adapter）硬體執行。
* **直接效益**：大幅降低 CPU 負載與傳輸延遲，實現極高吞吐量與硬體級的執行效率。

2. HCA 在硬體層執行的 5 大核心任務

1. **傳輸層處理（Transport Processing）**
    * **硬體實現**：封包序號管理（Sequencing）、確認信號（ACK）、逾時重傳（Retransmission）與按序交付（In-order delivery）。
    * **對比 TCP/IP**：TCP 需靠 OS 協定棧軟體算 Window Size、做握手與處理重傳；InfiniBand 全部在網卡晶片內部以硬體線路處理，速度顯著提升。


2. **零拷貝資料搬移（Data Movement via DMA）**
    * 透過硬體 DMA 實現端到端（End-to-End）直接「記憶體對記憶體」搬移。
    * 資料傳輸過程中**完全不經過系統中介緩衝區拷貝（No Memory Copies）**，傳輸工作完全卸載給網卡。


3. **RDMA 請求執行（RDMA Operation Processing via QP）**
    * 應用程式發起工作請求後，HCA 直接在硬體層級維護與調度 Queue Pair（QP）。
    * 傳輸指令直接在硬體上被解析與執行，無需進入核心態（Kernel Mode）呼叫驅動程式。


4. **封包分段與重組（Packetization & Reassembly）**
    * 大塊資料在送入網路前所需的**分段（Segmentation）**，以及接收端收到封包後的**重組（Reassembly）**，均由網卡硬體自動完成。
    * 上層軟體與 CPU 完全感知不到分段過程，無需介入計算。


5. **記憶體保護與存取控制（Memory Protection & Access Control）**
    * 整合先前提到的 **L_Key（Local Key）** 與 **R_Key（Remote Key）** 機制。
    * 存取合法性校驗直接由網卡晶片在硬體層級強制執行（Hardware-enforced），未授權或無金鑰的節點絕對無法讀寫受保護的記憶體區段。
  
### 核心硬體卸載技術架構

根據 NVIDIA ConnectX-5、ConnectX-6 與 ConnectX-7 官方技術手冊，HCA 的硬體卸載涵蓋以下五大技術維度：

#### 1. RDMA 與核心旁路卸載 (RDMA & Kernel Bypass Offload)
*   **Transport Offload**：HCA 在硬體層級處理 InfiniBand 傳輸層協定（如 Reliable Connected, Unreliable Datagram），直接透過硬體 DMA 控制器管理 Queue Pair (QP)、Work Queue Entry (WQE) 與 Completion Queue Entry (CQE)。
*   **NVIDIA PeerDirect™ (GPUDirect RDMA)**：消除 PCIe 匯流排上跨組件的次數與不必要複製（例如直接由 GPU 記憶體跨網卡發送至遠端 GPU 記憶體，無需經過 CPU 記憶體複製），顯著降低應用程式執行時間與延遲。

#### 2. 網路虛擬化與封包處理卸載 (Network Virtualization & Packet Processing Offload)
*   **Overlay Network Offloads**：針對 VXLAN 與 NVGRE 等隧道覆蓋網路，HCA 內建專用硬體引擎直接執行封包的封裝（Encapsulation）與解封裝（Decapsulation），防止標頭隱藏導致的 CPU 額外開銷。
*   **ASAP² (Accelerated Switch and Packet Processing)**：提供可彈性配置的 Match-Action 流表（Flow Tables），將 Open vSwitch (OVS) 的數據轉發與比對完全卸載至 HCA 網卡硬體。
*   **SR-IOV (Single Root I/O Virtualization)**：透過硬體提供虛擬機器（VM）專屬的適配器資源，確保硬體層級的隔離與保護。

#### 3. AI 與 HPC 集合通訊與協定卸載 (Collective & MPI Accelerations)
*   **Tag Matching & Rendezvous Protocol Offload**：在 MPI 通訊中，將訊息標籤比對（Tag Matching）與 Rendezvous 握手協定交由 HCA 硬體處理，避免 CPU 輪詢與插隊造成的處理延遲。
*   **Collective Operations Offloads**：支援向量集合運算卸載（Vector Collective Operations）與 `MPI_Alltoall` 卸載，結合網路結構中的 SHARP™（Scalable Hierarchical Aggregation and Reduction Protocol）將歸約（Reduction）等計算直接於網路/網卡硬體內完成。
*   **Burst Buffer Offloads**：將背景檢查點寫入（Background Checkpointing）任務卸載至硬體，加速大規模模型訓練的恢復點保存。

#### 4. 高效能儲存加速卸載 (Storage Acceleration Offloads)
*   **NVMe-oF & NVMe over TCP Offloads**：針對 Target/Host 端，將 NVMe over Fabrics 與 NVMe over TCP 傳輸協定直接由 HCA 硬體進行拆解與加速。
*   **Data Integrity & Computation**：硬體自動執行糾刪碼（Erasure Coding）計算與 T10-DIF（Data Integrity Field）簽章檢查（Signature Handover），確保資料完整性且不消耗 CPU 算力。

#### 5. 精準時脈與安全性硬體卸載 (Precision Timing & Security Offloads)
*   **Hardware Clock (PHC) & 5T**：內建硬體時脈（PHC），可提供低於 20 微秒（\\(<20\,\mu\text{s}\\)）的精準度，並支援時間觸發排程（Time-Triggered Scheduling）與基於時間的發送加速。
*   **Block-Level Encryption**：支援硬體級區塊加密（Block-level Encryption）與 Checksum 卸載，保障數據安全。

## Lossless, Credit-Based Flow Control

1. 設計哲學對比：TCP/IP vs. InfiniBand

| 比較維度 | 傳統 TCP/IP | InfiniBand |
| --- | --- | --- |
| **核心假設** | 假設網路隨時可能掉包、出錯或中斷 | 假設底層為高效能、低延遲的受控環境 |
| **應對策略** | **事後補救**：先送再說，若丟包則觸發逾時與重傳 | **事前預防**：只在接收端確認能收時才送，根本避免丟包 |
| **延遲代價** | 丟包引發重傳與擁塞視窗收縮，導致延遲劇增 | 無緩衝溢位丟包，維持極低且穩定的傳輸延遲 |

2. 基於信用的流量控制（Credit-based Flow Control）

* **何謂 Credit（信用）**：在資料傳輸中，Credit 就是「預先核准的發送許可」（代表接收端目前可用的緩衝區空間大小）。
* **運作機制**：
  1. **發放額度**：接收端主動告知發送端目前的可用緩衝區（例如：給予 20 個封包的額度）。
  2. **消耗額度**：發送端依據擁有的額度發送封包，額度隨發送逐步扣減。
  3. **額度耗盡即暫停**：一旦 Credit 歸零，發送端**立即停止發送**，主動等待，絕不強行灌爆對方的緩衝區。
  4. **額度回充**：接收端處理完資料、騰出緩衝空間後，發送回饋返還 Credit；發送端額度恢復，繼續傳輸。

3. 比喻

* **倉庫儲位比喻**：工廠要寄送貨物到倉庫，必須先確認倉庫有空位。倉庫告知「目前有 5 個空位」，工廠就只送 5 箱；在倉庫通知有新空位之前，工廠原地待命，絕不盲目出貨導致爆倉或貨物遺失。
* **信用卡額度比喻**：銀行核發信用額度 $\rightarrow$ 刷卡消費消耗額度 $\rightarrow$ 額度用盡停止消費 $\rightarrow$ 還款後額度恢復，重啟消費。

4. 為什麼 InfiniBand 是 RDMA 的天作之合？

這四項核心特性相輔相成，構成了 RDMA 極致效能的硬體基石：

1. **Queue Pair (QP)**：硬體直接實現的收發隊列，繞過作業系統 Socket 與核心協定棧。
2. **Memory Registration (MR)**：鎖定記憶體並以 L_Key / R_Key 提供硬體層級的安全存取，實現真正的零拷貝。
3. **Hardware Offload**：將分段、重組、傳輸邏輯與連線狀態全部卸載至 HCA 晶片硬體執行。
4. **Credit-based Flow Control**：事前預防緩衝區溢位，以無損網路特性消除了封包重傳帶來的延遲與效能抖動。
