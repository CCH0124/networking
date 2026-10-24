以下文章內容參考了 [nvidia | accelerating-io](https://developer.nvidia.com/blog/tag/accelerating-io/)。

## Magnum IO Architecture
這篇文章的核心在於介紹計算架構的轉變，以及 Magnum IO 如何作為解決方案來應對這些變化。

#### 1. 計算單元的典範轉移 (Paradigm Shift)
* **從單機到資料中心**：過去計算受限於單一伺服器（機殼），現在「資料中心」本身就是新的計算單元。
* **資源分散化**：資源不再集中於單一盒子內，而是物理上分散，數據跨節點分片或串流。

#### 2. 現代工作負載的特徵與挑戰
* **複雜的工作流**：結合了 HPC、AI 深度學習、數據分析與視覺化。
* **微服務架構**：HPC 領域也開始普及 Kubernetes 與容器化，導致數據流向與服務位置動態且不可預測。
* **通信需求**：需要高效的「東西向流量」（伺服器間的橫向溝通）。
* **性能瓶頸**：分散式資源需要高頻寬、低延遲，且不能過度依賴 CPU（需卸載工作負載）。

#### 3. NVIDIA Magnum IO 的解決方案
* **定位**：現代加速資料中心的 IO 子系統。
* **核心功能**：
    * 提供**抽象層 (Abstractions)**：隱藏底層硬體與軟體的複雜度。
    * **關注點分離**：讓開發者專注於數據應用，而不必處理複雜的數據管理細節。
    * **效能優化**：支援 GPUDirect 等技術，減少 CPU 負載，實現網內運算。
### Magnum IO architecture
#### 1. 名稱與定義
* **名稱由來**：Magnum IO 代表 **M**ulti-**G**PU, **M**ulti-**N**ode **I**nput/**O**utput。
* **核心任務**：透過 API、函式庫和程式模型，對 NVIDIA 硬體（GPU 與網路）上的數據進行控制與抽象化管理。

#### 2. 資料中心的資源層級 (Hierarchy)
資料中心的資源管理呈現階層式結構，Magnum IO 需處理以下各層級的運算、記憶體與儲存：
* **GPU 層級**
* **節點 (Node) 層級**
* **子叢集 (Sub-cluster) 層級**
* **資料中心 (Data Center) 層級**

#### 3. 關鍵技術優勢
* **網內運算 (In-Network Computing)**：允許數據在網路傳輸移動的過程中同時進行運算，減少延遲。
* **安全性與隔離 (Security via DPU)**：利用 DPU（Data Processing Unit）處理數據管理，將其與 CPU 上潛在的惡意程式碼隔離開來，提升安全性。
* **一致性與效率**：無論底層硬體配置如何，都能提供統一的高效率、可靠性與可維護性。

### Architectural principles

核心在於介紹 **Magnum IO** 如何將 **CUDA** 的成功原則從單一 GPU 擴展到整個資料中心的 IO 與網路溝通。

#### **1. 四大核心原則比較**
| 原則 | CUDA (運算核心) | Magnum IO (資料中心 IO) |
| :--- | :--- | :--- |
| **並發性 (Concurrency)** | 利用 GPU 核心進行大規模平行運算。 | 透過執行緒、多 GPU、多節點平行處理 IO；使用 **RDMA** 減少 CPU 負擔。 |
| **非同步性 (Asynchrony)** | 利用 Streams (串流) 避免阻塞，延遲執行以提升效率。 | 提供串流導向的 API (如 **NCCL**, **NVSHMEM**) 來處理通訊。 |
| **階層性 (Hierarchy)** | 透過 Grid/Block/Thread 階層管理資料局部性。 | 利用節點、叢集到資料中心的階層來優化記憶體與儲存的局部性。 |
| **工具與遙測** | 監控單一 GPU 資源與應用程式內部。 | 擴展至**全資料中心**的即時監控、效能分析與故障偵測。 |

#### **2. Magnum IO 的獨特之處**
* **靈活抽象 (Flexible Abstraction)：** 這是 Magnum IO 特有的第五原則。它提供「低階介面」（高控制權）與「高階抽象」（自動優化效能與路由），讓開發者能依需求選擇。

#### **3. 架構層級 (由上而下)**

![](https://developer-blogs.nvidia.com/wp-content/uploads/2020/10/magnum-io-stack-625x417.png) The Magnum IO architecture underlies some of higher-level CUDA-X and domain-specific offerings in the software stacks of a data center.

整個軟體堆疊依賴於底層的 IO 效能：
1.  **Verticals (垂直應用)：** 最上層的專業應用 (如醫療 CLARA, 自動駕駛 DRIVE)。
2.  **CUDA-X：** 基於 CUDA 的函式庫 (如 AI 與 HPC)。
3.  **CUDA：** 核心平行運算平台。
4.  **Magnum IO：** 最底層的基礎，包含 **網路 IO**、**儲存 IO**、**網內運算**與 **IO 管理**。

#### **4. 誰需要關心這個架構？**
* **終端用戶：** 享受效能提升。
* **App 開發者：** 獲得更簡單的效能優化路徑。
* **中介軟體開發者：** 獲得底層開發工具 (SDK)。
* **系統管理員：** 獲得更好的監控與故障排除工具。

### Magnum IO components

這張圖表將 Magnum IO 的技術版圖具體化，強調它不僅僅是一個軟體，而是一整套解決資料「傳輸」、「儲存」與「運算」瓶頸的生態系統。

![](https://developer-blogs.nvidia.com/wp-content/uploads/2020/10/magnum-io-components-3-625x271.png) Current Magnum IO components, with historical and new offerings in all areas of data movement, data access, and data management.

#### **1. Magnum IO 的四大支柱**
Magnum IO 將技術分為四個關鍵領域，以處理資料生命週期的不同階段：
* **網路 IO (Network IO)：** 專注於加速資料傳輸，核心技術包括 **NCCL** (多 GPU 通訊) 和 **GPUDirect RDMA** (讓 GPU 直接存取網路，不經 CPU)。
* **儲存 IO (Storage IO)：** 專注於快速存取資料，核心技術是 **GPUDirect Storage (GDS)**，讓 GPU 直接讀取儲存設備，大幅降低延遲。
* **網內運算 (In-Network Compute)：** 利用網路設備 (如交換機) 本身進行簡單運算 (如 **SHARP**)，減少資料在端點間來回傳輸的次數。
* **IO 管理 (IO Management)：** 負責監控與維護整個架構的健康狀況 (如 **UFM**)。

#### **2. 關鍵設計哲學 (五大主題)**
以下總結了 Magnum IO 設計背後的邏輯：
* **釋放 CPU：** 這是最重要的核心。透過 **CPU Offload (卸載)**，將網路和儲存的工作交給網卡或 GPU 處理，避免 CPU 卡死，並增加安全性（隔離）。
* **易用性與深度並存：**
    * 對**一般開發者**：提供高階抽象介面（好上手）。
    * 對**專家**：保留底層微調的權限（可極致優化）。
    * 對**硬體商**：在不改變上層介面的情況下，可以在底層持續創新硬體。
* **長期維護性：** 強調管理工具的可視性，確保資料中心能長期穩定運作。

上圖解釋了 NVIDIA 如何解決 **"資料搬運比資料運算還慢"** 的問題。
* 傳統架構：硬碟 -> CPU -> 記憶體 -> GPU (路徑長，CPU 累)。
* Magnum IO 架構：儲存/網路 -> **直接** -> GPU (路徑短，CPU 休息)。

## Network IO

![](https://developer-blogs.nvidia.com/wp-content/uploads/2020/10/gdr-direct-connection-for-gpus-1.png)

這篇文章拆解了 **Magnum IO 在「網路 (Network)」層面** 的具體武器庫。重點在於如何讓資料在「節點內」與「節點間」都能高速移動，且盡量不打擾 CPU。

#### **1. 四大核心網路軟體技術**
針對不同的應用場景，Magnum IO 提供了四種關鍵工具：
* **ASAP²：** 負責在交換機層面加速封包處理，減輕 CPU 負擔。
* **MPI & UCX (搭配 GPUDirect)：** 針對 **HPC (高效能運算)** 的標準通訊協定，重點在於讓傳統科學運算也能利用 GPU 加速。
* **NCCL：** 針對 **AI 深度學習** 訓練優化的通訊庫（例如多卡同步參數），能自動適應不同的硬體連接方式。
* **NVSHMEM：** 針對需要頻繁、小量資料交換（細粒度）的場景，降低延遲。

#### **2. 硬體與傳輸協定基礎**
這些軟體技術是建立在強大的硬體基礎上的：
* **節點內 (Intra-node)：** 使用 **NVLink**，讓同一台伺服器裡的 GPU 互傳資料像在同一個晶片上一樣快。
* **節點間 (Inter-node)：** 使用 **InfiniBand** 或 **乙太網路**，速度高達 200 Gbps。
* **關鍵技術 RDMA / RoCE：** 這是網路 IO 的靈魂。它允許 A 電腦的記憶體直接傳資料給 B 電腦的記憶體，**完全跳過 CPU**（零複製），這是降低延遲的關鍵。

#### **3. GPUDirect 的角色**
文中最後提到一個關鍵概念：所有的通訊函式庫 (MPI, NCCL 等) 其實底層都依賴 **GPUDirect** 系列技術。這意味著 GPUDirect 是實現「GPU 直接存取網路卡」的底層驅動力量。

### ASAP²

核心在於解決**用昂貴的 CPU 處理網路封包太浪費**的問題，並提出了 ASAP² 作為解決方案。

#### **1. 基本概念：SDN 的大腦與手腳**
* **SDN (軟體定義網路)：** 現代資料中心的網路管理方式，靈活且自動化。
* **控制平面 (Control Plane)：** 負責*決定*規則（大腦），例如防火牆策略、路由路徑。
* **資料平面 (Data Plane)：** 負責*執行*規則（手腳），例如實際傳送或丟棄封包。

#### **2. 問題點**
如果把「大腦」和「手腳」的工作都丟給伺服器的主 CPU 做，會導致：
* CPU 資源被佔用，無法專心做運算。
* 效能瓶頸。

#### **3. 解決方案：ASAP² 的兩種卸載 (Offload) 模式**
ASAP² 技術將這些工作從 CPU 移交給專門的網路硬體：

| 卸載程度 | 使用硬體 | 運作方式 | 優勢 |
| :--- | :--- | :--- | :--- |
| **僅卸載資料平面(Just the data plane)** | **ConnectX** (網卡) | 主機 CPU 決定規則，網卡負責**執行** (查表、轉發)。 | 降低 CPU 使用率，封包處理變快。 |
| **全卸載 (控制+資料)(Both the control plane and data plane)** | **BlueField** (DPU) | 網卡上有自己的 Arm CPU，**自己決定並執行**所有規則。 | 主機 CPU 完全解脫 (Zero-CPU overhead)，安全性最高。 |

#### **4. 帶來的效益**
* **效能提升：** 網路處理速度更快。
* **安全性 (隔離)：** 這是關鍵點。如果主機 CPU 被駭客入侵或應用程式當機，因為網路控制權在網卡 (DPU) 上，網路功能不會受到影響，駭客也難以透過網路擴散攻擊。

### MPI and UCX with GPUDirect RDMA in HPC-X

關於如何打通 GPU 叢集「任督二脈」的技術細節，重點在於**軟體 (UCX)** 如何完美調度**硬體 (GPUDirect)**。

#### **1. UCX：通訊的總指揮**
* **角色：** UCX 是一個開源的中介軟體，它像是一個「萬能轉接頭」，連接著上層應用 (MPI, Spark) 與下層硬體 (GPU, 網卡, CPU)。
* **優勢：** 它會自動幫你選「最快的一條路」。開發者不需要自己去寫程式碼判斷要走 PCIe 還是 InfiniBand，UCX 會自動處理。
* **應用：** 不只傳統的科學運算 (HPC) 用它，現代的資料科學 (Spark, RAPIDS) 也直接用它來加速。

#### **2. GPUDirect RDMA (GDR)：效能的引擎**
這是 Magnum IO 網路效能的核心技術（如圖 1 所示）：

![](https://developer-blogs.nvidia.com/wp-content/uploads/2020/10/gdr-direct-connection-for-gpus-625x298.png)

* **傳統路徑 (慢)：** GPU -> 記憶體 -> CPU -> 記憶體 -> 網卡 -> (網路) -> ... (對方重複流程)。路徑長，且 CPU 必須參與搬運。
* **GDR 路徑 (快)：** GPU -> 網卡 -> (網路) -> 網卡 -> GPU。
* **關鍵數據：**
    * **延遲 (Latency)：** 從 26.6 微秒降至 **3.4 微秒** (快了近 8 倍)。
    * **頻寬 (Bandwidth)：** 從 71 GB/s 提升至 **192 GB/s** (快了近 3 倍，且隨 GPU 數量線性成長)。

![](https://developer-blogs.nvidia.com/wp-content/uploads/2020/10/mpi-latency-improvements-1.png)

#### **3. 擴展性 (Scaling) 的雙重維度**
Magnum IO 同時解決了兩種擴充需求：
* **Scale Up (單機內)：** 利用 **NVLink** 或 PCIe 讓單台機器內的 8 顆 GPU 快速互傳。
* **Scale Out (跨機器)：** 利用 **InfiniBand** 與 **RDMA** 讓不同機器間的 GPU 快速互傳。
* **混合模式 (Hybrid)：** 圖 4 的測試顯示，同時結合 **IB + NV (InfiniBand + NVLink)** 能達到最高效能 (17.4 GB/s)，遠甩傳統 Python Socket (0.8 GB/s)。

![](https://developer-blogs.nvidia.com/wp-content/uploads/2020/10/ucx-comparison-625x452.png)  The Python sockets transport does not use UCX at all. UCX can work over a mix of TCP (TCP-UCX), a mix of NVLink and PCIe with CPU-CPU paths (NV), pure InfiniBand (IB), or a hybrid of NV and InfiniBand (IB+NV).

#### **4. HPC-X 套件**
NVIDIA 將上述所有好東西 (MPI, UCX, SHARP) 打包成 **HPC-X**，讓使用者開箱即用，直接獲得經由硬體優化的通訊效能。

### NCCL

為什麼 NVIDIA 在 AI 訓練領域難以被超越，核心就在於 NCCL 這個「交通指揮官」能夠極其高效地調度海量數據。

#### **1. NCCL 的核心任務**
* **解決什麼問題？** 在深度學習訓練中，GPU 算完一段後，必須跟其他 GPU 交換結果 (`AllReduce`) 才能繼續。如果交換太慢，GPU 就會空轉。NCCL 就是專門加速這個交換過程的。
* **主要功能：**
    * **資料平行 (Data Parallelism)：** 使用 `AllReduce` 同步所有 GPU 的參數。
    * **模型平行 (Model Parallelism)：** 使用 `Send/Recv` 讓不同 GPU 負責模型的不同部分。

#### **2. 智慧架構 (圖 5 解析)**
NCCL 不僅僅是傳輸資料，它非常「聰明」：
1.  **自動偵測路徑 (Topology Detection)：** 它會畫出當前系統的地圖（看這台機器有幾個 GPU、透過 NVLink 還是 PCIe 連接、網卡在哪）。
2.  **自動導航 (Graph Search)：** 根據地圖，找出資料傳輸的最快路徑（是要繞圓圈傳？還是像樹狀擴散？）。
3.  **硬體整合：** 它可以把多張網卡 (NICs) 的頻寬合併起來用，在 DGX A100 上達到了驚人的 **192 GB/s**。

![](https://developer-blogs.nvidia.com/wp-content/uploads/2020/10/nccl-architecture-1-625x265.png)

#### **3. 演算法的進化**
為了應對 GPU 數量越來越多的挑戰，NCCL 的演算法也在進化：
* **Ring (環狀)：** 最早期的演算法，適合少量 GPU，資料像接力棒一樣繞圈傳。
* **Tree (樹狀)：** 針對**大規模叢集** (Scale-out)，資料像樹根一樣分岔傳輸，效率更高（測試至 2.4 萬顆 GPU）。
* **SHARP (網內運算)：** 終極大招。利用交換機硬體直接幫忙算，減少數據在網路上的傳輸量。

#### **4. 與 MPI 的關係**
* NCCL 在功能上很像傳統 HPC 用的 **MPI**，語法也故意設計得很像，方便開發者遷移。
* **關鍵差異：** MPI 主要在 CPU 跑，NCCL 全部在 **GPU** 跑，直接調用 GPU 核心，不佔用 CPU 資源。

### NVSHMEM

介紹了 **NVSHMEM** 如何改變 GPU 叢集的通訊規則，從「CPU 指揮」轉變為「GPU 自主」。

#### **1. 核心痛點：MPI 的限制**
* **傳統方式 (MPI)：** 運算歸運算，通訊歸通訊。GPU 算完停下來 -> 通知 CPU -> CPU 搬資料 -> 通知 GPU 繼續算。
* **缺點：** 產生「核心邊界 (Kernel Boundary)」，造成 CPU-GPU 頻繁同步，浪費時間（高延遲、高開銷）。

#### **2. 解決方案：NVSHMEM (GPU 自主通訊)**
* **運作原理：** 允許 GPU 在**執行 Kernel (運算) 的同時**，直接發起資料傳輸，完全不經過 CPU。
* **技術基礎：** 基於 OpenSHMEM 標準 (PGAS 模型)，支援單邊通訊 (One-sided communication)。
* **優勢：**
    * **隱藏延遲：** 通訊時間可以被運算時間掩蓋 (Overlap)。
    * **低開銷：** 不需要複雜的標籤匹配 (Tag Matching)。
    * **細粒度：** 適合頻繁交換小量資料的場景。

#### **3. 效能與生產力證明**
* **效能 (LBANN 卷積測試)：** 在 32 顆 GPU 上，NVSHMEM (綠條) 明顯快於 MPI (藍條) 和優化過的 Aluminum (橘條)。
* **生產力 (Kokkos 案例)：** 實現同樣功能的程式碼，MPI+CUDA 需要 **1000 行**，而 NVSHMEM 只需要 **<200 行** (由下圖可見)，且效能更好。
* **實際應用 (Lattice QCD)：** 在科學運算中，透過將通訊融合進運算 Kernel，獲得了 **1.3~1.46 倍** 的加速，這在 HPC 領域是巨大的提升。

![](https://developer-blogs.nvidia.com/wp-content/uploads/2020/10/complexity-by-loc-cgsolve.png)

#### **4. 關鍵區別圖解 (下圖)**
* **MPI:** [運算] -> [等待] -> [通訊] -> [運算] (序列式，有空窗期)
* **NVSHMEM:** [運算 + 通訊 + 運算] (混合式，並行處理，無縫接軌)

![](https://developer-blogs.nvidia.com/wp-content/uploads/2020/10/mpi-nvshmem-communication-comparison-625x278.png) NVSHMEM’s GPU-centric vs. MPI’s CPU-centric sequential communication styles.

**總結這系列 Magnum IO 的邏輯：**
1.  **Magnum IO** 是大架構。
2.  **GPUDirect** 是底層硬體通道 (讓 GPU 直通網卡/硬碟)。
3.  **UCX** 是通訊總管 (幫你選路)。
4.  **NCCL** 專攻 AI 大量資料同步 (`AllReduce`)。
5.  **NVSHMEM** (本文) 專攻科學運算中的細碎、頻繁通訊，讓 GPU 邊算邊傳。

## Computing and IO Management

### HDR 200G InfiniBand and NDR 400G, the next-generation network

支撐 Magnum IO 的硬體骨幹——**InfiniBand**，並重點宣傳了新一代 **NDR 400G** 的強大性能。

#### **1. 為什麼 InfiniBand 是首選？ (四大優勢)**
InfiniBand 之所以統治超級電腦界 (Top 10 佔了 8 台)，依靠的是這四點設計哲學：
* **聰明的端點 (Smart Endpoints)：** 網卡自己能做事 (Offload)，不打擾 CPU/GPU (支援 RDMA)，能釋放 CPU 或 GPU 時間專注於實際應用程式。
* **極簡交換架構 (SDN)：** InfiniBand 交換機不需要在每個交換設備內嵌入伺服器來管理交換機及運行作業系統，把空間留給「網內運算 (In-Network Computing)」，讓交換機也能幫忙算數據 (SHARP)。
* **集中管理：** 一個大腦管理整個網路，設定簡單，適合各種拓撲。可以使用通用的 IB 交換機模組來設計和建構任何類型的網路拓撲，並針對目標應用客製化與優化資料中心網路。不需要針對網路的不同部分建立不同的交換機配置，也無需處理複雜的網路演算法。InfiniBand 的誕生就是為了提升效能並降低營運成本 (OPEX)。
* **相容性：** 新舊設備都能互通，保障投資。InfiniBand 是開源的，並擁有開放的 API。

#### **2. NDR 400G 的躍進 (第七代架構)**
相較於上一代 HDR 200G，新的 NDR 400G 帶來了巨大的效能飛躍：
* **速度翻倍：** 頻寬從 200G 變成 **400Gb/s**。
* **AI 加速 (SHARP)：** 這是亮點。AI 訓練中最常用的資料聚合操作，容量提升了 **32 倍**，這對大模型訓練至關重要。
* **MPI 效能：** 科學運算常用的全對全通訊快了 **4 倍**。
* **超大規模連接：** 單一交換機可支援更多孔 (高基數)，使得只需經過 3 層交換機 (3 hops) 就能連接 **100 萬台** 伺服器。

#### **3. 關鍵名詞解釋**
* **SHARP (Scalable Hierarchical Aggregation and Reduction Protocol)：** 這就是文中不斷提到的「網內運算」核心技術。它讓交換機在傳遞資料的過程中，順便把數據加總或平均 (Reduction)，這樣傳到目的地時已經是算好的結果，大幅減少網路壅塞。
* **Radix (基數)：** 指交換機上的插孔數量。基數越高，能連的機器越多，網路層數就越少，延遲就越低。

### High-speed Ethernet: 200G and 400G Ethernet

雖然 InfiniBand 是高效能運算的首選，但這篇文章解釋了 NVIDIA 如何讓 **乙太網路 (Ethernet)** 也能勝任 AI 與 HPC 的工作。

#### **1. 為什麼還要選乙太網路？**
即便 InfiniBand 效能超群，客戶仍選擇乙太網路的原因通常有三點：
* **生態系與習慣：** 企業已經習慣使用 Ansible、Puppet 等工具管理網路，且許多舊有儲存設備只支援乙太網路。
* **安全性需求：** 只有乙太網路支援 **IPSec** 加密協定。
* **特殊應用：** 高頻交易 (HFT) 需要 **PTP (精確時間協定)** 進行超高精度校時，這是乙太網路的強項。

#### **2. 核心挑戰：RoCE 的複雜度**
* **問題：** 要讓 GPU 直接存取網路 (GPUDirect)，必須要有 RDMA 功能。在乙太網路上，這叫做 **RoCE**。但在一般交換機上，RoCE 非常難設定。
* **NVIDIA 的解法：** 將複雜的設定簡化為**「單一指令」**，讓 RoCE 變得好用且易於管理。

#### **3. 效能對決：NVIDIA vs. 一般交換機**
* **擁塞控制：** 下圖展示了關鍵差異。一般的交換機 (Merchant Switches) 在處理大量資料時容易「阻塞」或「暫停」，導致延遲忽高忽低（左圖）。
* **ROCE DONE RIGHT：** NVIDIA 的交換機具備特殊的擁塞避免技術，能讓資料流保持平滑穩定（右圖），這對於 AI 訓練這種不能有延遲的應用至關重要。

![](https://developer-blogs.nvidia.com/wp-content/uploads/2021/01/switches-on-roce-625x291.jpg)

#### **4. 規格現狀**
* 支援 200G 與 **400G** 頻寬。
* 採用標準的 Leaf-Spine 拓撲，可擴展性高。

### NVIDIA InfiniBand in-network compute
介紹了 InfiniBand 交換機和網卡如何變身為「運算單元」，而不僅僅是傳輸工具。這就是 **"In-Network Compute" (網內運算)** 的核心概念。

#### **1. 兩大核心技術**
這篇文章將網內運算分為兩個主要應用場景：
* **針對點對點通訊 (MPI Point-to-Point)：** 使用 **硬體標籤匹配 (Hardware Tag Matching)**。
* **針對集合通訊 (Collectives)：** 使用 **SHARP** 技術。

#### **2. 硬體標籤匹配 (Hardware Tag Matching)**
* **問題：** 在傳統科學運算 (HPC) 中，MPI 程式會發送大量帶有「標籤」的訊息。CPU 必須像郵局分信員一樣，把每個訊息拿起來看標籤，再決定丟到哪個信箱，這非常消耗 CPU 時間。
* **解決方案：** **ConnectX-6** 或更新網卡內建了硬體引擎，直接在網卡上就把「分信」的工作做完了。
* **效益：**
    * CPU 不用管分信，可以專心做運算。
    * 通訊延遲大幅降低。
    * 應用程式整體效能提升。

#### **3. SHARP (交換機幫你算)**
這是 AI 訓練和大規模 HPC 的殺手級功能。
* **問題 (無 SHARP)：** 當 100 台電腦要算一個平均數時，資料必須在電腦和交換機之間來回跑 4 趟 (送出 -> 集中到某台電腦算 -> 算完送回交換機 -> 發給大家)。
* **解決方案 (有 SHARP)：** 資料傳到交換機時，**交換機直接把數字加總/平均**，然後直接把結果發回去。
* **效益：**
    * **路徑減半：** 4 趟變 2 趟。
    * **頻寬翻倍：** 網路塞車情況減少一半。
    * **延遲降低 7 倍：** 對於 `AllReduce` 這種操作極度有效。
    * **AI 實戰：** 下圖證明，在 BERT、GNMT 等大型 AI 模型訓練中，開啟 SHARP 能帶來約 **1.18 倍** 的整體效能提升（這在硬體不變的情況下是非常可觀的增益）。

![](https://developer-blogs.nvidia.com/wp-content/uploads/2021/01/sharp-acceleration-1-625x242.jpg) Acceleration with In-Network Computing SHARP technology: improving NCCL AllReduce throughput and reducing MPI latency.

### InfiniBand and Ethernet IO management

Magnum IO 架構的「大腦」——管理層。針對兩種不同的網路協定，NVIDIA 提供了兩套不同的管理工具。

#### **1. 乙太網路管理：NetQ**
* **定位：** 現代化、支援 **NetDevOps** 的維運工具。
* **核心技術：WJH (What Just Happened)**
    * **痛點：** 傳統網路出問題時，工程師通常只能看統計數據「猜」原因，或是用採樣 (Sampling) 的方式，很容易漏掉關鍵封包。
    * **WJH 解法：** 利用交換機晶片 (ASIC) 的硬體能力，以**全速 (Line-rate)** 檢查**所有封包**。
    * **效益：** 不用猜，直接告訴你異常原因（是軟體錯？還是硬體錯？），大幅縮短除錯時間。
* **部署：** 支援雲端服務模式，易於維護與升級。

#### **2. InfiniBand 管理：UFM (Unified Fabric Manager)**
* **定位：** 針對高效能運算 (HPC) 和 AI 叢集的集中式管理平台。
* **三大版本分級：**
    1.  **Telemetry (基礎版)：** 只負責看 (監控、驗證、收集數據)。
    2.  **Enterprise (企業版)：** 負責看與管 (配置、排程器整合如 Slurm、安全管理)。
    3.  **Cyber-AI (AI 版)：** 負責預測 (Predictive)。
* **Cyber-AI 的亮點：**
    * 利用**深度學習**來學習資料中心的「心跳」(正常運作的模式)。
    * 能夠在故障發生**之前**預測效能下降或硬體故障。
    * 能夠自動執行修正動作，節省營運成本 (OPEX) 並確保服務品質 (SLA)。

#### **3. 總結比較**
| 特性 | NetQ (乙太網路) | UFM (InfiniBand) |
| :--- | :--- | :--- |
| **核心技術** | **WJH** (硬體封包檢測) | **Cyber-AI** (深度學習預測) |
| **主要用途** | 故障排除、DevOps 流程 | 預防性維護、排程器整合 |
| **解決問題** | "為什麼網路變慢/斷線？" (事後分析強) | "哪個設備快要壞了？" (事前預測強) |

## Magnum IO Storage
加速運算需要加速 IO。 否則，運算資源會因為缺乏資料而陷入飢餓狀態 (starved)。鑑於能夠將所有資料完全放入記憶體的工作負載比例正在縮小（意即資料集越來越大，記憶體放不下），優化儲存 IO 的重要性日益增加。

此外，儲存資料的價值、竊取或破壞資料的企圖，以及保護資料的法規要求，這一切都在不斷攀升。因此，市場對於能夠提供更佳隔離性——將使用者與其不應存取的資料隔離開來——的資料中心基礎設施，需求正日益增長。

### GPUDirect Storage

揭示了高效能運算 (HPC) 與 AI 領域的一個重大典範轉移。

#### **1. 傳統路徑 vs. GDS 路徑**
* **傳統痛點 (Bounce Buffer)：** 以前，資料要從硬碟進 GPU，必須先經過「硬碟 -> 系統記憶體 (RAM) -> CPU -> GPU 記憶體」。這中間的「系統記憶體」就是所謂的 Bounce Buffer，產生了多餘的複製與延遲。
* **GDS 優化 (Direct Path)：** GDS 讓資料直接從「硬碟 (NVMe) -> GPU 記憶體」。**CPU 完全不用插手**。

#### **2. 為什麼說是「角色逆轉 (Role Reversals)」？**
這是這段文字最震撼的觀點：
* **過去的常識：** CPU 旁邊的記憶體 (DRAM) 一定比遠端的硬碟 (Storage) 快。
* **現在的現實：** 透過 GDS 加上高速網路 (如 InfiniBand)，**「遠端儲存餵資料給 GPU 的速度」竟然比「CPU 餵資料給 GPU」還要快**。
* **意義：** 這意味著在設計 AI 系統時，我們可以更依賴高速儲存與網路，而不必擔心 CPU 記憶體頻寬成為瓶頸。

### The newest member of the GPUDirect family

NVIDIA 如何逐步打通 GPU 的資料通道。

#### **1. GPUDirect 的演進史**
* **過去 (Memory-to-Memory)：** 以前的 GPUDirect 主要處理「記憶體」之間的搬運。
    * 例如 **GPUDirect P2P** (GPU 記憶體互傳)。
    * 例如 **GPUDirect RDMA** (網卡記憶體直傳 GPU 記憶體)。
* **現在 (Storage-to-Memory)：** 隨著 **GDS** 的加入，終於把「硬碟 (Storage)」也納入直通範圍。

#### **2. GDS 的關鍵突破**
* **CUDA 支援檔案 IO：** 這是這段文字強調的 "Significant step"。以前 CUDA 核心只能處理運算，讀寫檔案要靠 CPU；現在 GDS 讓 CUDA 能直接處理檔案 IO。
* **通吃本地與遠端：** 無論是插在主機上的 **NVMe SSD** (Local)，還是透過網路連接的 **儲存伺服器** (Remote)，GDS 都能加速。

#### 總結 Magnum IO 的完整圖像

結合之前提供的所有餒榮，我們現在可以畫出 **Magnum IO** 的完整技術版圖了：

1.  **想讓 GPU 互相傳資料快一點？** $\rightarrow$ 用 **NVLink** 和 **NCCL** (針對 AI)。
2.  **想讓 GPU 透過網路傳資料快一點？** $\rightarrow$ 用 **GPUDirect RDMA** 和 **InfiniBand**。
3.  **想讓 GPU 讀硬碟資料快一點？** $\rightarrow$ 用 **GPUDirect Storage (GDS)** (本篇)。
4.  **想讓 CPU 完全休息？** $\rightarrow$ 用 **SHARP** (交換機幫忙算) 和 **Offload** (網卡幫忙處理)。

### GDS description and benefits

這張圖是 GDS 技術價值的最強證明，它透過數據證實了「儲存直通 GPU」比「用 CPU 記憶體當緩衝」還要快。

<img width="936" height="637" alt="image" src="https://github.com/user-attachments/assets/df616d73-ddb4-4035-991f-f85f67457d7a" />

GDS software stack, where the applications use cuFile APIs, and the GDS-enabled storage drivers call out to the nvidia-fs.ko kernel driver to obtain the correct DMA address.

#### **1. 運作原理：這是一條「直達車」**
* **Without GDS (傳統慢車)：** 資料必須先下車 (CPU RAM)，換車 (CPU 處理)，再上車 (PCIe)，最後才到目的地 (GPU)。這叫 **Bounce Buffer (跳板緩衝區)** 效應，造成塞車。
* **With GDS (高鐵直達)：** 資料直接由 DMA 引擎搬運，從 SSD/網卡直接寫入 GPU 記憶體。CPU 只要負責「蓋章批准 (Setup DMA)」就好，不用親自搬運。

#### **2. 三大效能**
* **頻寬暴增 (Bandwidth):** 實測可達 **8 倍** 增益。
* **延遲驟降 (Latency):** 減少資料搬運次數，延遲降低 **3 倍**。
* **CPU 使用率 (CPU Utilization):** CPU 不用忙著搬資料，負載降低 **3 倍**，可以專心做邏輯運算。

#### **3. 歷史性的反轉 (A Remarkable Reversal of History)**
這是本文最關鍵的洞察（從數據來看）：
* **過去的常識：** DRAM (記憶體) 很快，Storage (硬碟/網路) 很慢。所以資料放不進 GPU 時，我們傾向這把資料暫存在 CPU DRAM。
* **現在的現實：** 在 DGX A100 上，從**遠端網路儲存 (NICs)** 讀資料的速度 (**185+ GB/s**)，竟然比從 **CPU 本地記憶體** 讀資料 (**100 GB/s**) 還要快將近兩倍！
* **結論：** 現在如果 GPU 記憶體不夠用，直接讀寫遠端儲存，反而比退回系統主記憶體還要高效。

#### **4. 軟體層面的優化 (cuFile)**
* GDS 不只是硬體直通，NVIDIA 還提供了 `cuFile` API 和 `libcufile` 函式庫。
* 開發者不需要自己處理麻煩的記憶體對齊 (alignment) 或緩衝區固定 (pinning)，函式庫會自動處理這些底層髒活。

## How GDS works

解釋了 NVIDIA 如何在 Linux 核心還沒準備好的情況下，透過「偷天換日」的手法實現 GDS。

#### **1. 核心難題：Linux 認不得 GPU**
* **現狀：** Linux 的檔案系統 (VFS) 只認得 CPU 記憶體位址。如果你直接把 GPU 的記憶體位址丟給它，它會報錯 (Error)。
* **標準化進度：** 雖然未來會有標準解法 (`dma_buf`)，但 NVIDIA 認為效能太重要，不能等。

#### **2. 解決方案：位址替換大法 ( The Swap Trick)**
GDS 的運作流程就像一場魔術表演：
1.  **攔截 (User Space):** 當程式呼叫 `cuFileRead` 時，`libcufile.so` 會先把 GPU 的位址藏起來，隨便拿一個 **「代理 CPU 位址」** 丟給 Linux 系統，騙它說：「嘿，我要寫入這個 CPU 記憶體喔。」
2.  **欺騙 (Kernel VFS):** Linux 系統 (VFS) 檢查這個 CPU 位址沒問題，就核准了，並一路往下傳。
3.  **還原 (Driver Level):** 就在硬碟準備要寫入資料的前一刻，NVIDIA 的專用驅動程式 `nvidia-fs.ko` 會跳出來喊卡，把那個假的 CPU 位址拿掉，**換回原本真的 GPU 位址**。
4.  **執行 (DMA):** 硬碟 (DMA 引擎) 拿到真的 GPU 位址，直接把資料寫進 GPU。

#### **3. 為什麼不用標準 API 就好？**
文中特別提到，即使未來 Linux 原生支援了 GPU 直讀 (`dma_buf`)，`cuFile` API 也不會消失。
* **原因：** `cuFile` 包含了很多 NVIDIA 獨家的優化功能（例如：走 **NVLink** 通道、動態路由選擇），這些是通用 Linux 標準無法提供的。這呼應了 Magnum IO 的**「靈活抽象」**原則。

#### **4. 架構圖解**

![](https://developer-blogs.nvidia.com/wp-content/uploads/2021/08/GDS-software-stack-625x542.png) GDS software stack, where the applications use cuFile APIs, and the GDS-enabled storage drivers call out to the nvidia-fs.ko kernel driver to obtain the correct DMA address.

這張圖展示了 GDS 的軟體堆疊：

* **上層 (綠色)：** 開發者用的 `cuFile` 函式庫。
* **中層 (灰色)：** 標準的 Linux 檔案系統層 (VFS, File System)。
* **旁路 (綠色 `nvidia-fs.ko`)：** 這是 GDS 的靈魂，它像一個外掛，繞過了標準路徑的限制，確保底層硬體拿到正確的 GPU 位址。

