# Key Components of DGX SuperPOD

## Components

DGX SuperPOD Hardware Components by NVIDIA:

| 元件名稱 (Component) | 採用的 NVIDIA 技術 (NVIDIA Technology) | 技術描述與功能 (Description) |
| --- | --- | --- |
| 運算節點(Compute Nodes) | **NVIDIA DGX RUBIN NVL8 系統** (搭載 8 顆 Rubin GPU) | 全球領先的專用 AI 運算系統，內建 8 顆 Rubin Tensor Core GPU，全面整合第六代 NVIDIA NVLink 與第六代 NVSwitch™ 技術。 |
| 運算節點收發器與線纜(Compute Node Transceiver/Cable)| **NVIDIA OSFP 雙埠平頂收發器、MMF 被動光纖線纜** | 用於運算節點（DGX）高速網路介面卡（NIC）與交換器之間的物理互連連接線材。 |
| 運算網路織網(Compute Fabric) | **NVIDIA Quantum-X800 / Quantum-3 800 Gbps InfiniBand** 或 **Spectrum-X™** | 提供高速、超低延遲且非阻塞（Non-blocking）的雙平面 Fat-Tree（胖樹）拓撲架構，專為下一代極大規模的 AI 工廠節點互連量身打造。 |
| InfiniBand 儲存網路織網(InfiniBand Storage Fabric) | **NVIDIA Quantum QM9700 NDR 400 Gbps InfiniBand 交換器** | 專門獨立出來的儲存專用網路，經過優化，可完美匹配並釋放經認證的高效能平行儲存陣列（HPS）之最高吞吐效能。 |
| 儲存網路交換器收發器與線纜(Storage Switch Transceiver/Cable) | **NVIDIA QSFP 單埠平頂收發器、MMF 被動光纖線纜** | 專用於 InfiniBand 儲存交換器端的高速光纖收發模組與連接線材。 |
| Ethernet 儲存網路織網(Ethernet Storage Fabric - 選配) | **NVIDIA Spectrum-4 SN5610 / SN5600D 800 Gbps 乙太網路交換器** | 為採用乙太網路（如基於 RoCE 或 NFS）的企業級儲存解決方案，所提供的高頻寬選配儲存網路織網。 |
| Ethernet 儲存交換器收發器與線纜(Ethernet Storage Switch Transceiver/Cable) | **網卡端：QSFP 單埠平頂 800GB**；**交換器端：OSFP 雙埠帶鰭片 1600GB MMF 被動光纖** | 專為 Spectrum-4 乙太網路交換器設計的高密度高頻寬傳輸線材，採鰭片式（Finned）散熱設計。 |
| 儲存 InfiniBand 網路管理(Storage IB Fabric Management) | **NVIDIA Unified Fabric Manager (UFM) 3.5 設備 (企業版)** | 將高級的即時網路遙測技術，與 AI 驅動的網路智能分析相結合，用以集中調度、監控並保護大規模 InfiniBand 資料中心網路。 |
| 頻內管理網路(In-band Management Network) | **NVIDIA SN5610 / SN5600D 乙太網路交換器** | 提供高達 64 埠 800 Gbps（或透過拆分提供最多 256 埠 200 Gbps）的高密度乙太網路，負責傳輸節點間的管理數據、叢集作業調度及用戶主目錄檔案系統的存取。 |
| 頻內管理交換器收發器與線纜(In-band Switch Transceiver/Cable) | **QSFP 單埠平頂 400GB** 或 **OSFP 雙埠帶鰭片 800GB MMF 被動光纖** | 用於頻內管理網路交換器的高可靠度通訊元件。 |
| 頻外管理網路(Out-of-band Management Network) | **NVIDIA SN2201(M) 乙太網路交換器** | 具備 48 埠 1 Gbps RJ45 銅纜埠與 4 埠 100 Gbps 上行埠的交換器，以極低的物理複雜度，專門負責伺服器 BMC、電源機架等硬體底層的帶外（OOB）遠端開關機與硬體監控。 |

## Design Requirements

1. 系統總體設計 (System Design)

    * **模組化 SU（可擴充單元）**：以 **72 台 DGX RUBIN NVL8** 為一個基礎 SU。
    * **標準規模**：完整測試的系統標準可達 **16 個 SU**，並可依客戶需求進一步放大。
    * **單櫃密度**：單個機櫃最高可容納 8 台 DGX RUBIN NVL8（需視資料中心電力與散熱能力彈性調整）。

2. 計算網路（Compute Fabric / East-West 流量）

    * **架構**：採用 **Rail-optimized（軌道優化）、Full-Fat Tree（全胖樹）** 的拓撲架構。
    * **硬體**：由 **Quantum-X800** 交換器組成，搭配 UFM（統一架構管理器）進行網管。
    * **頻寬**：透過 ConnectX-9 提供單節點高達 **800 Gb/s** 的極致頻寬與超低延遲。

3. 乙太網路架構（Ethernet Fabric / North-South 流量）

    乙太網路在物理層上為單一架構（由 **Spectrum-4 SN5600D 800 Gbps 交換器**組成），但在邏輯上劃分為兩個獨立網路：

    * **儲存網路（Storage Network）**：
    * 連接 BlueField-4 DPU，提供高速、低延遲的共用儲存存取。
    * 支援 **RoCE（RDMA over Converged Ethernet）** 以將 CPU 開銷降至最低。

    * **帶內管理網路（In-Band Management Network）**：
    * 用於節點配置、數據傳輸與網際網路存取。
    * 計算與管理節點的連線速率為 **400 Gb/s**，採 Layer-3 權重等價多路徑（wECMP）路由，並與儲存網路共享物理線路實現自動故障轉移。

4. 帶外管理網路（Out-of-Band Management, OOB）

    * 負責連接伺服器的 BMC（Baseboard Management Controller）等管理接口。
    * 採用 **SN2201M 交換器**（48 埠 1 Gbps 銅纜 + 4 埠 100 Gbps），與用戶環境物理隔離，確保基礎維護的安全與低複雜度。

5. 儲存架構要求 (Storage Requirements)

    系統將儲存依性能與用途區分為兩大類：

    1. **高效能儲存 (High-Performance Storage, HPS)**
        * **目的**：用於 AI 模型訓練與檢查點（Checkpointing）等需要極大吞吐量的場景。
        * **特點**：支援符合 POSIX 標準、針對多節點並行讀寫優化的**並行檔案系統**。全面支援 InfiniBand 或 Ethernet 的 RDMA 技術，並運用本地系統 RAM 和 Flash 快閃記憶體進行透明緩存（Caching）。

    2. **用戶儲存 (User Storage)**
        * **目的**：用於使用者家目錄（Home directory）、行政暫存區（Scratch space）、管理軟體的高可用性共享空間及日誌檔。
        * **特點**：主要透過乙太網路運行 **NFS 協定**，要求具備高元數據（Metadata）處理效能與高 IOPS。基本頻寬要求至少 **100 Gb/s**（支援 100-400 Gb/s）。

## DGX SuperPOD Architecture

1. **系統組成元素**：
    DGX SuperPOD 架構是高度整合的維度，包含 DGX 計算節點、乙太網路（Ethernet Fabric）、InfiniBand 網路（Compute Fabric）、管理節點（Management Nodes）與儲存設備。
2. **標準機櫃配置與高密度挑戰**：
    * 在 NVIDIA 的標準參考設計中，**一個標準機櫃內可容納 8 台 DGX RUBIN NVL8 系統**。
    * **驚人的功耗**：單一個滿載 8 台 DGX 的機櫃，其功耗高達 **~225 kW**！
    * **彈性部署**：官方強調，資料中心必須依據自身的電力分配與水冷/風冷散熱能力，來彈性調整單一機櫃內實際安插的 DGX 數量與擺放位置。

    ![DGX RUBIN NVL8 in Racks](https://docs.nvidia.com/dgx-superpod/reference-architecture/scalable-infrastructure-rubinx86/latest/_images/image5.png)

3. **管理機櫃（Management Rack）**：
    除了計算節點，1 個 SU（Scalable Unit，可擴充單元）還會搭配獨立的管理機櫃，內部部署網路交換器（Networking Switches）、管理伺服器（Management Servers）、儲存陣列（Storage Arrays）以及 UFM（Unified Fabric Manager）網管技術設備。

    ![Management Rack Configuration with Networking Switches](https://docs.nvidia.com/dgx-superpod/reference-architecture/scalable-infrastructure-rubinx86/latest/_images/image6.png)
4. **超大規模擴充能力**：
    此架構的核心設計重點在於「規模化（Scaling）」。該文件以 8 個 SU（576 個 DGX 節點）作為主要的基準設計，但整個系統完全具備擴充至 **72 個 SU 以上（超過 2000 個 DGX RUBIN NVL8 節點）** 的能力。

### DGX SuperPOD Scalability

下表展示了隨著 SU（可擴充單元）數量翻倍時，整個系統的計算核心（Node、GPU）以及**計算網路（Compute Fabric/InfiniBand）** 交換器與線材的精準配比：

| SU 數量 | Node 數量 (計算節點) | GPU 數量 | Leaf 交換器 | Spine 交換器 | Node-Leaf 線材 | Leaf-Spine 線材 |
| --- | --- | --- | --- | --- | --- | --- |
| **1** | 72 | 576 | 8 | 4 | 576 | 576 |
| **2** | 144 | 1152 | 16 | 8 | 1152 | 1152 |
| **4** | 288 | 2304 | 32 | 18 | 2304 | 2304 |
| **8** | 576 | 4608 | 64 | 36 | 4608 | 4608 |
| **16** | 1152 | 9216 | 128 | 64 | 9216 | 9216 |

1. Node Count (計算節點數) 與 GPU Count (GPU 總數)

    * **含意**：代表整個叢集的總計算威力。
    * **計算公式**：
        * $\text{Node Count} = \text{SU 數量} \times 72$ （因為 1 個標準 SU 包含 72 台 DGX RUBIN NVL8）。
        * $\text{GPU Count} = \text{Node Count} \times 8$ （因為每台 DGX 內建 8 顆 Rubin GPU）。
        * *範例 (1 SU)*: $72 \times 8 = 576$ 顆 GPU。

2. Leaf 交換器數量 (Leaf Switches)

    * **含意**：第一層（下層）交換器，直接用線材與 DGX 節點相連。
    * **計算邏輯**：
        * 每台 DGX RUBIN NVL8 需要 **8 埠（Ports）** 連向計算網路（Compute Fabric）。
        * 採用的 Quantum-X800 交換器（如 Q3400-RD 系列）通常具備 **144 埠 (以 800Gbps 計算)**。
        * 1 個 SU 有 72 台節點，總共需要 $72 \times 8 = 576$ 個網路埠。
        * 因此所需的 Leaf 交換器數量 = $576 \div 72 \text{ (每台交換器分配給下層 Node 的埠數)} = \mathbf{8}$ 台。
        * 隨著 SU 翻倍，Leaf 交換器數量直接呈線性翻倍（1 SU 需 8 台、2 SU 需 16 台...以此類推）。

3. Spine 交換器數量 (Spine Switches)

    * **含意**：第二層（上層）骨幹交換器，負責橫向連接所有的 Leaf 交換器，實現無阻塞（Non-blocking）的 Fat-Tree（胖樹）拓撲。
    * **計算與架構邏輯（無阻塞 1:1 收斂比）**：
        * 在「全胖樹（Full-Fat Tree）」架構中，Leaf 交換器往上連向 Spine 的總頻寬，必須等於往下連向 Node 的總頻寬。
        * **以 1 SU 為例**：576 條線從 Node 連到 Leaf（佔用 8 台 Leaf 的下半部埠），那麼這 8 台 Leaf 的上半部也必須拉出 576 條線連向 Spine。
        * 為了均勻分流，576 條線平均分給上層的 Spine 交換器。NVIDIA 在此處進行了優化配置（包含考量了 Twin-plane 雙平面或 Rail-optimized 軌道優化設計）。在 1 SU 時需要 **4 台 Spine**。
        * 隨著規模擴大（到 4 SU 或 8 SU 時），因為跨 SU 的東西向流量大增，Spine 需要更多的交換容量來兜住所有的 Leaf。
        * **注意 4 SU 和 8 SU 的微調**：
        * 4 SU 的 Spine 為 **18 台**（非單純等比的 16 台）。
        * 8 SU 的 Spine 為 **36 台**（非單純等比的 32 台）。
        * 這是因為當叢集擴大時，為滿足超大規模下各軌道（Rails）與平面間的完美互聯與備援，官方調整了胖樹的上層配置以避免任何邊界效能瓶頸。到 16 SU 時，則收斂回 **64 台 Spine** 來實現超大型規模的完美對稱。

4. Node-Leaf 與 Leaf-Spine 線材數量 (Cable Count)

    * **含意**：
    * **Node-Leaf**：從 DGX 伺服器網卡連到 Leaf 交換器的線材總數。
    * **Leaf-Spine**：從 Leaf 交換器連到 Spine 骨幹交換器的線材總數。

    * **計算邏輯**：
        * 由於架構維持 **1:1 的不收斂（Non-oversubscribed）設計**（即進去 Leaf 的流量等於出來的流量）。
        * 所有的線材數量完全等於 $\text{Node Count} \times 8$。
        * *範例 (8 SU)*: 576 台 Node $\times$ 8 埠/Node = **4608 條 Node-Leaf 線材**。
        * 為了對稱，Leaf 往上拉到 Spine 的線材同樣也是 **4608 條**。這確保了任意兩顆 GPU 之間通訊時，不論跨多少個機櫃，都能享有最極致、無卡頓的 800 Gbps 全速頻寬。

## Network Fabrics

1. 運算網路 (Compute Fabric / East-West)
    * 技術與頻寬：採用 InfiniBand XDR（Quantum-X800 交換器） 網路，每台 DGX RUBIN NVL8 節點透過 ConnectX-9 網卡提供 8 個 OSFP 埠 連接。
    * 軌道優化（Rail-Aligned）：單個 SU 內每 72 個節點以 8 條軌道對齊。在同一軌道內，節點間的通訊只需經過一台 Leaf 交換器（單跳，One switch away），極大地降低跨節點通信延遲。跨 SU 或跨軌道流量則交由 Spine 層處理。

2. 乙太網路架構 (Ethernet Fabric / North-South)
    * 為了提高成本效益，此架構沿用了 Blackwell（GB200/300）世代的乙太網路設計，方便客戶將 Rubin 平台平滑接入現有的儲存與帶內（In-band）基礎設施。
    * BlueField-4 DPU 的關鍵角色：擔任主機端網路切分的終端點。它獨立執行軟體定義網路、儲存與安全引擎，將這些基礎架構工作從主機的 CPU/GPU 中完全卸載，並提供 HBN（Host-Based Networking） 介面。
    * 物理與邏輯分離：硬體上主要採用 Spectrum-4 SN5600D 800 Gbps 交換器，但在邏輯上透過 VXLAN 疊加網路（Overlay） 劃分為：
    * 儲存網路（Storage Network）：使用 RoCEv2 協定，提供遠端直接記憶體存取的安全高速儲存通道。在儲存 Leaf 交換器上設計有 2:3 的收斂比（Uplink-to-downlink oversubscription）。
    * 帶內管理網路（In-Band Network）：處理叢集管理、控制平面、低速 NFS 儲存存取，並作為對外連接（如連至外部 NGC 鏡像庫、代碼庫、用戶登入節點等）的通道。
    * 現代化網路協定 (EVPN-MH)：整個乙太網路是一個 Layer 3 (L3) 路由網路，底層運行 eBGP。它放棄了傳統的 Layer 2 MLAG 設計，全面採用 EVPN 多主機歸屬（EVPN-Multihoming）。透過 10 位元組的 ESI（Ethernet Segment Identifier），讓 BlueField-4 DPU 能夠以「全雙活（All-active）」路徑同時連到多台 Leaf 交換器，利用 ECMP 進行動態負載平衡，實現次秒級（Sub-second）的超快速故障轉移。

3. 帶外管理網路 (Out-of-Band Network, OOB)
    * 物理與邏輯完全隔離：主要承載 IPMI（智慧平台管理介面） 控制流量。
    * 連接對象：涵蓋所有基礎設施的維護端口（包括 DGX 系統 BMC、BlueField-4 DPU BMC、所有的 InfiniBand/Ethernet 交換器、PDU、電源機架等）。
    * 硬體：使用 SN2201 作為 Top-of-Rack (TOR) 交換器，上層經由 SN5600D 交換器匯總。同樣採用基於 EVPN-MH 的 L3 路由設計，普通用戶無法存取。

4. 客戶端邊界與 NFS 連接 (Customer Edge)
    * 客戶需要自行準備三種連線對接：NFS 家目錄儲存、走主路由的對外主上行鏈路（Main uplink）、僅供管理用的 OOB 上行鏈路。
    * 路由遞交採用 BGP 對等（Peering） 宣告。

### Ethernet Fabric Design

![Ethernet Fabric Design](https://docs.nvidia.com/dgx-superpod/reference-architecture/scalable-infrastructure-rubinx86/latest/_images/image11.png)

上圖，核心用意，是向系統架構師展示如何用最經濟、高效率且具備高可用性（HA）的物理實體線路，來承載所有非計算（North-South）的流量。

一個標準的二層（2-Tier）無阻塞網路拓撲，分為：

* Spine（脊交換器層）：位於最上層。在 16 個 SU（9216 顆 GPU）的最大標準配置下，這裡會部署 16 台 Spectrum-4 SN5600D 交換器。所有的 Leaf 交換器都會上連至所有的 Spine 交換器，提供極大的橫向頻寬。
* Leaf（葉交換器層）：位於下層，直接與伺服器或儲存設備對接。

功能導向的 Leaf 交換器分組 (Functional Leaf Grouping)

關鍵的設計在於*物理分流、邏輯收攏*。它將 Leaf 層的交換器依據*連接的對象與傳輸效能需求*，明確劃分為四大群組：

* 高效能儲存葉交換器群組 (Dedicated Storage Leaf Group)：
  * 連接對象：專門連接各大儲存合作夥伴（如 NetApp, Weka, VAST 等）的 HPS（高效能並行儲存系統）。
  * 配置：通常由 2 台交換器組成一個群組，提供高達 $128 \times 400\text{ Gb/s}$ 的非阻塞（1:1）儲存總頻寬（每 SU 可達 400 GB/s），以滿足 AI 訓練頻繁讀寫大模型權重與 Checkpoint 的嚴苛需求。
* 運算節點儲存葉交換器 (Compute Storage Leaf)：
  * 連接對象：連接每台 DGX RUBIN NVL8 上的 BlueField-4 DPU。
  * 設計亮點（2:3 收斂比）：這裡特意設計了 2:3 的下行對上行收斂比，平衡了成本與 AI 訓練時的集體儲存吞吐量。
* 控制平面與 NFS 葉交換器 (Control Plane & NFS Leaf)
  * 連接對象：專門用來連接所有的控制平面節點（Management Servers）以及較低速的用戶儲存（如家目錄的 NFS 伺服器）。
  * 配置：獨立成一對交換器，提供每對 Leaf-Spine $1 \times 400\text{ Gb/s}$ 的上行容量，確保系統在派發部署（Provisioning）或執行叢集控制時，有專屬的綠色通道，不會與運算節點搶頻寬。
* 管理葉交換器 (Management Leaf)：
  * 連接對象：連接持久性日常儲存、叢集管理維護節點，並向上對接帶外管理（OOB）的脊交換器。

BlueField-4 DPU 的雙活與備援機制 (EVPN-MH)

* 在實體線路的連接上，上圖呈現了高可用性（High Availability）的連線方式：
* 每台 DGX 節點的 BlueField-4 DPU，都會同時拉出實體線路，交叉連向兩台不同的 Spectrum-4 Leaf 交換器。
* 這在架構上呼應了文件提到的 EVPN-MH（多主機歸屬） 技術。一旦其中一台 Leaf 交換器或某一條線路斷線，系統能在次秒級（Sub-second）內完成故障轉移，AI 訓練任務絕不中斷。

#### Spine and Leaf Switch Requirements for Scale Out

| #GPU | #SU | Spines | Compute Leafs | N/S Mgmt Leafs | N/S Mgmt Spines |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **576** | 1 | 4 | 8 | 4 | 2 |
| **1152** | 2 | 8 | 16 | 8 | 4 |
| **2304** | 4 | 18 | 32 | 16 | 8 |
| **4608** | 8 | 36 | 64 | 32 | 16 |
| **9216** | 16 | 72 | 128 | 44 | 32 |

上表展現了當 DGX SuperPOD 從 1 個 SU 擴充到 16 個 SU（規模化，Scale Out）時，其 **乙太網路架構（Ethernet Fabric）所需實體交換器的精準配置數量**。這張表是網絡架構師在進行資料中心採購與機櫃佈線（Provisioning）時最重要的依據，它確保了整個叢集不論擴充到多大，其儲存與管理網路都能維持在最穩定的 L3 路由傳輸效能。


##### 欄位數值的核心用意

這張表共有 6 個欄位，其數值用意如下：

* **#GPU**：叢集內 Rubin GPU 的總顆數。
* **#SU**：可擴充單元（Scalable Unit）的數量（1 SU = 72 台 DGX）。
* **Spines**：位於核心最高層的 **Ethernet Spine（脊）交換器總數**（均採用 800 Gbps 的 Spectrum-4 SN5600D）。
* **Compute Leafs**：**直接連接計算節點（DGX 上的 BlueField-4 DPU）的 Leaf 交換器總數**。
* **N/S Mgmt Leafs**：南北向管理與儲存葉交換器總數（負責連接外部高性儲存 HPS、NFS、控制伺服器等）。
* **N/S Mgmt Spines**：專門為南北向管理/帶外（OOB）等控制流獨立出來或切分出的骨幹交換器總數（部分規模下會與主骨幹進行邏輯或物理整合）。

##### 數值如何計算與其架構邏輯

乙太網路架構（Ethernet Fabric）的計算邏輯，與 InfiniBand 運算網路（Compute Fabric）的 1:1 胖樹不同。它引入了 **2:3 的收斂比（Oversubscription）** 與 **功能分組（Functional Grouping）** 的概念：

1. Compute Leafs (計算葉交換器) 的計算

    * **架構規則**：每台 DGX RUBIN NVL8 的 BlueField-4 DPU 會拉出雙活（EVPN-MH）連線。在官方設計中，為了達到經濟效益與效能的平衡，設計了 **2:3 的下行對上行收斂比**。
    * **計算邏輯**：
        * 在標準 1 SU（72 台 Node）的配置中，為了滿足雙活備援與 2:3 的收斂帶寬計算，固定需要 **8 台 Compute Leaf 交換器**。
        * 這是一個標準的模組化基數。當 SU 數量翻倍時，Compute Leafs 的數量就會呈**完全線性翻倍**。
        * $$\text{Compute Leafs} = \text{SU 數量} \times 8$$
    * *驗證*：16 SU $\rightarrow 16 \times 8 = \mathbf{128}$ 台。

2. Spines (核心脊交換器) 的計算

    * **架構規則**：Spine 交換器負責兜住所有的 Compute Leaf，提供大跨度的橫向互聯。
    * **計算邏輯**：
        * 在 1 SU 到 2 SU 的小規模部署中，Compute Leaf 總數較少（8 ~ 16 台），因此只需要 **4 台 到 8 台 Spine** 就能提供充足的背板頻寬來滿足 2:3 的收斂需求。
        * 當規模擴大到 4 SU（32 台 Leaf）或 8 SU（64 台 Leaf）時，跨機櫃的儲存吞吐量暴增，Spine 數量必須對應增加至 **18 台** 與 **36 台**。
        * 到了 **16 SU** 的極致規模（128 台 Leaf）時，上層需要 **72 台 Spine** 才能拉住下方所有的計算葉交換器，維持超大規模 AI 叢集所需的 L3 動態路由（eBGP / EVPN-MH）極速傳輸。

3. N/S Mgmt Leafs (南北向管理/儲存葉交換器) 的計算

    * **架構規則**：這群交換器不連 DGX，而是連接高效能並行儲存（HPS）、NFS 伺服器和控制平面伺服器。
    * **計算邏輯**：
        * 儲存與管理交換器是**依據叢集的總儲存吞吐需求**來推算的，而非單純看 SU 數量。
        * 在 1 SU 時，基本配置需要 **4 台**（一對給 HPS 高效能儲存，一對給 NFS/控制平面）。
        * 隨著 SU 增加（運算節點變多，代表對儲存設備的併發存取暴增），這群交換器需要線性增加以串接更多、更大容量的第三方認證儲存陣列。
        * 到了 16 SU 時，為了掛載龐大的 AI 數據集儲存群，N/S Mgmt Leafs 數量會擴展到 **44 台**。

4. N/S Mgmt Spines (南北向管理脊交換器) 的計算

    * **架構規則**：用來匯總管理與帶外（OOB）網絡流量的核心交換器。
    * **計算邏輯**：
        * 在 1 SU 規模時，管理流量較小，僅需要 **2 台** Spine 作為管理骨幹。
        * 隨著 SU 數量提升，整個 SuperPOD 內成百上千個組件（包含幾千個 BMC 端口、數百台交換器網管埠、數百個 PDU 等）的帶外管理流量大增。
        * 為了維持 Layer 3 路由的穩定性與備援（HA），管理脊交換器會逐步倍增：1 SU（2台）$\rightarrow$ 2 SU（4台）$\rightarrow$ 4 SU（8台）$\rightarrow$ 8 SU 以上則封頂維持在 **16 台**，這足以應付 9000 多顆 GPU 叢集規模下的所有日常遙測（Telemetry）與運維管理流量。

### Network Segmentation of Ethernet Fabric

![Network Segmentation Diagram](https://docs.nvidia.com/dgx-superpod/reference-architecture/scalable-infrastructure-rubinx86/latest/_images/image12.jpeg)

上圖核心要表達的，是 NVIDIA 如何在同一個物理乙太網路上，利用虛擬化技術，實現邏輯上的交通管制與安全隔離。本質就是，**透過 VXLAN 技術，將單一實體乙太網完美化身為高效能儲存專線、叢集管理公道、以及安全維運後門這三條平行宇宙，在效率、成本與安全之間取得最佳平衡。**

1. 物理融合，邏輯分離（Shared Physical, Isolated Logical）

    在超大型 AI 叢集裡，若為每種流量都建立一套獨立的實體交換器和線路，成本與複雜度會極高。

    * 上圖表達了 DGX SuperPOD 如何將多種不同屬性的流量，**融合（匯聚）在同一個由 Spectrum-4 交換器組成的實體乙太網路**上。
    * 透過 **VXLAN Overlay（疊加網路）** 技術，在物理骨幹之上切割出數條「互不干涉的虛擬隧道」，確保數據傳輸具備硬體級的隔離與安全性。

2. 三大核心網路切片（Network Segments）的定義與用意

    該圖清楚勾勒出非計算流量被切分成的三大區塊，每種區塊的用途與優先權截然不同：

    * **儲存網路（Storage Network）——「極速專用道」**
        * **通訊協定**：採用 **RoCEv2（RDMA over Converged Ethernet）**。
        * **用意**：這是乙太網中**優先權最高**的流量。AI 訓練時需要從高效能儲存（HPS）讀取海量數據集（Dataset），或寫入巨大的模型檢查點（Checkpoint）。RoCEv2 允許數據繞過 CPU 直接寫入，圖 11 表達了這條通往 HPS 的虛擬通道是完全獨立且受到頻寬保障的。

    * **帶內管理網路（In-Band Network）——「叢集控制與對外通道」**
        * **通訊協定**：標準的 TCP/IP 乙太網路。
        * **用意**：負責傳輸叢集內部的管理與調度流量（如 Mission Control、Base Command Manager、Slurm 派發任務、Kubernetes 通訊）。同時，它也負責處理較低速的用戶儲存（NFS）存取，以及**對外世界**的連線（例如讓工程師登入 Head Node、叢集連到 NVIDIA NGC 下載最新的 AI 容器鏡像或程式碼庫）。

    * **帶外管理網路（Out-of-Band Management Network）——「維運後門通道」**
        * **通訊協定**：獨立的 L3 路由網（底層由 SN2201 交換器實體串接）。
        * **用意**：專供系統管理員使用的 **IPMI 控制流量**。這條通道與上述兩個生產網路（Production Network）在邏輯與物理上徹底隔離。它的用意是確保當業務網路因為高負載塞車、甚至當機時，管理員依然有一條乾淨的後門通道可以連入設備的 BMC 進行遠端重啟、遙測或災難恢復。

3. BlueField-4 DPU 的邊界隔離功能

    該圖還表達了一個極為重要的架構演進：**「網路切分的壓力被完全卸載到主機邊緣」**。

    * 在傳統架構中，作業系統需要自己用軟體去標記和分離儲存與管理流量（消耗寶貴的 CPU 週期）。
    * 在圖 11 的架構中，**NVIDIA BlueField-4 DPU 成為了網路切分的實體終端點（Endpoint）**。DGX 伺服器本體只需要把數據丟給 DPU，DPU 內部的硬體加速引擎就會自動將流量貼上對應的 VXLAN 標籤，並分流到正確的虛擬通道中。

### Storage and In-Band Network

![HBN Configuration Diagram](https://docs.nvidia.com/dgx-superpod/reference-architecture/scalable-infrastructure-rubinx86/latest/_images/image13.jpeg)

在 Storage and In-Band Network（儲存與帶內網路）中，該圖核心要表達的是，如何透過 BlueField-4 DPU 的 HBN（Host-Based Networking，基於主機的網路）技術，在簡化運算主機（Host）網路複雜度的同時，提供超高頻寬與硬體級的高可用性（HA）備援。基本上，對上（主機層）極致簡化，對下（網絡層）硬體加速與極致備援。它是透過 NVIDIA HBN 技術，在維持系統高可用性與 800 Gbps 超高頻寬的同時，解放運算伺服器效能的關鍵技術實踐圖。

此圖則是將焦點拉近到「單台 DGX 伺服器節點內部與 Leaf 交換器之間」的微觀網絡架構。

1. 主機作業系統端的極簡化

    在傳統的大型叢集架構中，伺服器若要同時處理儲存（RoCEv2）、管理、帶內通信等多種流量，作業系統內部必須建立非常複雜的虛擬網路介面（如多個不相同的 VLAN、VXLAN 隧道或 Bond 介面），這會消耗大量的 CPU 算力與系統維護成本。

    * **此圖核心表達**：透過 BlueField-4 DPU 的封裝，**運算主機（Compute Host）的作業系統端只會看見兩個極其單純的介面**：
        1. **一個帶內管理介面（In-Band Interface）**：走標準 TCP/IP，負責叢集控制與日常通訊。
        2. **一個儲存介面（Storage Interface）**：走 RoCEv2，專門負責與高效能儲存（HPS）對接。

    * **歷史相容性**：這種雙介面的簡化設計，與前一代基於 Blackwell（GB200/300）架構的 SuperPOD 保持完全一致，讓既有客戶在移轉到 Rubin 新平台時可以無縫接軌，不需重寫底層的維運腳本。

2. 基礎架構工作完全硬體卸載

    該圖展示了所有複雜的網路邏輯都「下沉」到了 DPU（Data Processing Unit）硬體層面。

    * 當主機將數據丟給這兩個簡化介面後，**BlueField-4 DPU 會在幕後接手所有重活**。
    * DPU 內部的 HBN 韌體會自動將主機的儲存流量與帶內流量，分別打包封裝進各自獨立的 **VXLAN 疊加網路（Overlay）** 中。這不僅保證了流量的邏輯隔離，也將網絡封包處理的壓力從主機 CPU/GPU 上 100% 卸載下來，確保寶貴的計算週期能完全留給 AI 訓練與推論。

3. EVPN-MH 技術

    該圖在實體連線上清楚描繪了 DPU 如何與上層的 Spectrum-4 乙太網路交換器對接，以保障高可用性：

    * **全雙活路徑（All-Active Paths）**：單台 DPU 會同時拉出多條實體線路，**交叉連接到多台不同的 Spectrum-4 Leaf 交換器**。
    * **ESI 邏輯聚合**：網絡架構採用 **EVPN 多主機歸屬（EVPN-Multihoming, EVPN-MH）** 技術。系統會為 DPU 連向不同 Leaf 交換器的線路分配一個相同的 10 位元組 **ESI（Ethernet Segment Identifier，乙太網路段識別碼）**。
    * **動態負載平衡與備援**：整個乙太網骨幹會將這幾台不同的 Leaf 交換器視為同一個邏輯實體。流量會透過五元組雜湊（5-tuple hashing）在整個架構中利用 **ECMP（等價多路徑路由）** 進行完美的雙活負載平衡，提供高達 **800 Gb/s** 的驚人吞吐量。
    * **次秒級自動恢復**：一旦其中一台 Leaf 交換器或某一條實體線路發生故障，系統能夠在**次秒級（Sub-second）內完成自動故障轉移**，數據流會瞬間切換到其他健康的雙活線路上，確保底層的 AI 訓練任務完全不會因為網路斷線而崩潰中斷。

### Out-of-Band Management Network

![](https://docs.nvidia.com/dgx-superpod/reference-architecture/scalable-infrastructure-rubinx86/latest/_images/image14.png)

上圖的核心用意，是向系統架構師展示 **如何建立一條與業務、計算完全『物理隔離』的獨立維運綠色通道，以確保叢集在任何極端狀況下都能被安全管理**。

1. 物理與邏輯的「絕對隔離」

    * **核心原則**：帶外（OOB）管理網路在**物理硬體**與**邏輯網路**上，皆與生產數據（Production Data）網路、控制平面（Control Plane）網路完全分開。
    * **主要用意**：承載所有與 **IPMI（智慧平台管理介面）** 相關的控制與監控流量。這種隔離設計確保了即使業務網路因高負載嚴重塞車、遭受攻擊或完全當機，管理員依然擁有一條百分之百乾淨、不受干擾的「後門」進入系統。

2. 「天羅地網」般的全面覆蓋連接

    上圖的架構圖清楚描繪了 SuperPOD 基礎設施中，所有具備管理接口的組件都必須接入此網路，包含：

    * **運算節點雙 BMC**：每台 DGX RUBIN NVL8 主機板本體的 BMC，以及 **BlueField-4 DPU 的 BMC**。
    * **網路設備**：所有的 InfiniBand 交換器、Spectrum-4 乙太網路交換器。
    * **基礎設施基礎元**：管理伺服器（Management Servers）、儲存設備（Storage Appliances）。
    * **機櫃配電單元**：機櫃內部的 **PDUs** 以及 **Power Shelves（電源機架）**。

3. 以 SN2201 交換器為核心的 L3 路由架構

    在實體與虛擬架構的串聯上，展現了現代化機房的管理封裝：

    * **Top-of-Rack (TOR) 配置**：每個機櫃內部使用 **NVIDIA Spectrum SN2201 交換器**（48 埠 1 Gbps 銅纜 + 4 埠 100 Gbps）作為接入層，利用銅纜的低成本與低複雜度特性收攏所有維護端口。
    * **彙總與虛擬化（VXLAN）**：這些 TOR 交換器的流量向上匯總至 SU 的聚合層（Spine 層），並被打包進一個**專屬的 VXLAN 虛擬網絡**中。
    * **高可用性（HA）**：OOB 網路同樣捨棄了傳統的 L2 設計，採用 **Layer 3 路由設計**。上層的 OOB Spines 交換器（採用 SN5600D）透過 **EVPN 多主機歸屬（EVPN-Multihoming）** 技術進行雙活備援，確保管理骨幹本身不具備單點故障風險。

4. 嚴格的安全防護與客戶端對接

    * **非特權用戶隔離**：圖強調，一般使用者、資料科學家或非特權管理者，在任何情況下都**不需要也不允許**直接存取這些 OOB 端口。系統在邏輯上施加了嚴格的訪問控制（Access Control）。
    * **專屬上行鏈路（Dedicated Uplink）**：圖 13 的邊界處表明，客戶端的企業網路必須為 OOB 乙太網路提供一條**完全獨立、專用的外接上行鏈路**，以便與客戶自身的企業網管中心或災害復原（Disaster Recovery）系統進行安全對接。
