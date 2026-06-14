# Infrastructure-as-a-Service

Infrastructure-as-a-Service (IaaS) 層向使用者提供可擴充的裸機與虛擬機（兩者皆稱為執行實例 instances），允許租戶在不需要管理底層實體基礎設施的情況下運行其應用程式。IaaS 層應提供一系列可由 NCP 自訂的方案，配置通用運算大小、記憶體、儲存與 GPU 容量等維度。

## IaaS 架構 (IaaS Architecture)

下圖定義了被視為資料中心管理 (Data Center Management, DCM) 功能一部分的 IaaS 系統之主要元件。這包括雲端控制平面 (CCP)、軟體定義網路 (SDN)、運算服務 (Compute Service) 以及軟體定義儲存 (SDS)。

![基礎設施即服務元件](https://files.buildwithfern.com/nvidia-dsx.docs.buildwithfern.com/dsx/04667648a2eb344b397cf5ad9a18187631f7d686471ca610469d2a33d3a438e7/_dot_dot_/docs/ncp/software-reference-guide/assets/images/ncp-srg-iaas-arch.png)

這些元件協同運作，建置出一個類似 CSP 的基礎設施即服務 (IaaS) 系統。

### 元件描述 (Component Descriptions)

**基礎設施即服務元件**

| 元件 (Component) | 描述 (Description) |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 雲端控制平面 (Cloud Control Plane, CCP) | 面向公眾的控制平面，提供 API/UI 來佈署與管理運算、網路和儲存。處理身分驗證、授權、配額執行以及計量 (Metering)。 |
| 軟體定義網路 (Software Defined Network, SDN) | 啟用集中式、可程式化的網路管理，以實現自動化、擴充性與多租戶隔離。 |
| 運算服務 (Compute Service) | 管理裸機與虛擬機實例的生命週期，包括租戶之間的佈署、放置 (Placement)、監控以及清理消毒 (Sanitization)。 |
| 軟體定義儲存 (Software Defined Storage, SDS) | 管理區塊、檔案與物件儲存的配置、池化 (Pooling) 與擴充。 |
| 身分與存取管理 (Identity and Access Management, IAM) | 終端使用者的身分驗證與授權。 |

每個 IaaS 元件都需要特定的能力，才能營運一個經 AI 優化的多租戶資料中心。建置完整的 IaaS 層需要整合所有這些元件的軟體。NVIDIA 提供一系列用於網路管理、運算管理與儲存加速的基礎設施軟體。NCP 和 ISV 可以將這些軟體元件與他們所選擇的作業系統、超級監督器 (Hypervisor) 和儲存供應商進行整合。

### 網路管理 (Network Management)

重溫自 [資料中心檢視 (Data Center View)](/dsx/ncp/software-reference-guide/data-center-architecture#data-center-view)，一個 AI 資料中心運行著多個網路織網：

**資料中心網路 (Data Centre Networks)**

| 網路 (Network) | 用途 (Purpose) | 技術 (Technology) |
| ---------------------------------- | ---------------------------------------------------------------- | -------------------------------------------- |
| 租戶存取網路 (Tenant Access Network, TAN) | 南北向流量：租戶存取儲存與外部服務 | 乙太網路 (Spectrum) |
| 叢集互連網路 (Cluster Interconnect Network, CIN) | 東西向流量：跨節點的 GPU 對 GPU 通訊 | InfiniBand (Quantum) 或 乙太網路 (SpectrumX) |
| NVLink 網路 (NVLink Network) | 縱向擴充 (Scale-up)：機櫃內部的 GPU 對 GPU 通訊 | NVLink (GB200/GB300) |
| 安全管理網路 (Secure Management Network, SMN) | 頻外 (OOB) 基礎設施管理 | 乙太網路 (1GbE) |
| 共享服務 (Shared Services) | 租戶存取共享服務（登錄庫 registry、IAM） | TAN 上的邏輯疊加網路 (Logical overlay) |

網路管理涵蓋了對這些織網進行配置、設定和隔離，以支援多租戶 AI 工作負載。

#### 所需能力 (Capabilities Required)

* **乙太網路織網佈署**：為 TAN 以及基於乙太網路的 CIN 配置 Leaf-Spine 織網。
* **乙太網路可見性與遙測**：監控織網健康狀況、驗證變更並進行故障排除。
* **InfiniBand 織網管理**：配置用於高效能 CIN 的 InfiniBand 織網。
* **NVLink 領域管理**：配置機櫃級的 NVLink (GB200/GB300)。
* **租戶網路隔離**：透過疊加網路 (VXLAN) 或分割區鍵 (Partition Keys, PKeys) 建立隔離的 VPC。

#### 軟體定義網路 (Software Defined Networking, SDN)

透過軟體定義網路，網路控制平面與資料平面分離，以啟用集中式與可程式化的網路行為管理。因此，系統管理員不再需要手動前往交換器和路由器來更新行為，而是可以完全由 SDN 控制器進行程式化更新。

下圖展示了建置在 NVIDIA 技術之上的 SDN 系統。雖然這不是建構 SDN 的唯一方法，但此處的展示是用於解釋相關技術。

![基於 NVIDIA 軟體元件建置的軟體定義網路](https://files.buildwithfern.com/nvidia-dsx.docs.buildwithfern.com/dsx/59972af126bca389971fc36d149900f9229c18b914dc66fa9012f65470ceb555/_dot_dot_/docs/ncp/software-reference-guide/assets/images/ncp-srg-sdn.png)

DCM SDN 層包含網路管理器 (Network Manager) 和 SDN 控制器 (SDN Controller) —— 這些通常是 ISV 或 NCP 自建的元件，用以處理控制平面邏輯。

在右側，運算節點 (Compute Node) 執行 SDN 代理程式 (SDN Agent)，而 BlueField DPU 則運行 DOCA/HBN 以在邊緣終止租戶的疊加網路。

在下方，NVIDIA 軟體負責管理每個網路織網：NMX 管理基於 NVSwitch 的 NVLink 領域，UFM 管理運行 MLNX-OS 的 InfiniBand交換器，而 NetQ 則為運行 Cumulus 的 Spectrum 交換器提供可見性。

### 運算管理 (Compute Management)

運算服務負責管理裸機 (BM) 和虛擬機 (VM) 實例及其完整生命週期。這適用於資料中心內的所有運算，包括 GPU 節點、通用節點以及潛在的軟體定義儲存節點。運算服務處理：

* 實例生命週期（建立、啟動/停止、終止、重新啟動、放置）
* 實例管理（例如：取得虛擬機狀態、附加磁碟區）
* 監控實例（取得日誌、取得指標）
* 實例網路（為實例分配 IP、為實例附加虛擬網卡 vNIC）
* 在租戶之間清理消毒運算資源
* 租戶隔離

#### 所需能力 (Capabilities Required)

**運算管理能力矩陣 (Compute Management Capability Matrix)**

| 能力 (Capability) | 用途 (Purpose) |
| ----------------------- | ------------------------------------------------------ |
| 機器搜索 (Machine Discovery) | 搜尋實體機器並將其納入資產清單 (Inventory) 中 |
| 裸機佈署 (Bare Metal Provisioning) | 大規模進行 PXE 啟動、韌體更新與作業系統安裝 |
| 實例生命週期 (Instance Lifecycle) | 建立、啟動/停止、終止、重新啟動、放置 |
| 實例管理 (Instance Management) | 取得狀態、附加磁碟區、分配 IP、附加虛擬網卡 (vNIC) |
| 硬體證明 (Hardware Attestation) | 在分配之前驗證節點與韌體的完整性 (Integrity) |
| 節點健康檢查 (Node Health Check) | 壓力測試以在分配之前驗證效能 |
| 節點清理消毒 (Node Sanitization) | 在租戶之間安全地擦除/抹除節點數據 |
| GPU 虛擬化 (GPU Virtualization) | 跨虛擬機共享 GPU（時間分片 Time-sliced 或 MIG） |
| GPU 可觀測性 (GPU Observability) | 監控 GPU 健康、指標與診斷資訊 |
| 機櫃級生命週期 (Rack-Scale Lifecycle) | 電源順序控制、散熱冷卻、協調的韌體更新 |

以下描述了構成運算服務的邏輯元件。特定的實作可能會進行不同的劃分，但這些能力都應該存在。

* **機器生命週期管理器 (Machine Lifecycle Manager)**：搜尋、接納、放置、佈署、清理消毒、韌體更新、BMC 管理、IP 分配、作業系統安裝。
* **實例資料庫 (Instance Database)**：維護所有實體機器和實例的狀態。
* **VM 控制平面 (VM Control Plane)**：接收已佈署的 Bare Metal 節點，處理虛擬機請求、裝箱 (Bin-packing)、事件監控。這應用於節點級別；對於機櫃級和更大規模的部署（例如：可擴充單元 SU 劃分），應考慮相同的行為和放置決策，以實現最佳的網路頻寬和延遲。NVIDIA 推薦在 Kubernetes 上使用 KubeVirt。
* **PXE 啟動伺服器 (PXE Boot Server)**：PXE（預啟動執行環境）啟動伺服器回應來自啟動中節點的請求，並載入最小作業系統和佈署代理程式。該佈署代理程式可用於測試節點、更新平台上的所有韌體，並安裝裸機映像檔（租戶作業系統與 cloud-init 配置）或虛擬機映像檔（基礎作業系統/超級監督器 + 核心元件）。這在邏輯上可能是生命週期管理器的一部分。

### 儲存管理 (Storage Management)

裸機伺服器和虛擬機需要存取儲存。儲存分為兩類：暫存儲存 (Ephemeral storage) 與持續性儲存 (Persistent storage)。暫存儲存是透過存取（通常是本機的）硬碟來提供，這些硬碟在租戶之間會被擦除。持續性儲存則提供透過網路存取混合的區塊、檔案和物件儲存。對於後者，軟體定義儲存 (SDS) 負責管理這三種儲存類型的配置、池化與擴充，這可以透過雲端控制平面進行存取。

![NVIDIA 軟體參考架構中的儲存系統](https://files.buildwithfern.com/nvidia-dsx.docs.buildwithfern.com/dsx/8dd4ce65e9d47c71aa8b1d13ba40a81043912cc8dccf8bfd49b37a31255958d4/_dot_dot_/docs/ncp/software-reference-guide/assets/images/ncp-srg-storage-system.png)

SDS 系統有兩個主要元件：

#### SDS 控制器 (SDS Controller)

這是面向租戶的控制平面：

* 提供北向 API（例如：CreateVolume、DeleteVolume、SetPolicy）
* 提供策略引擎以執行配額、服務品質 (QoS) 和安全性
* 命名空間管理器 (Namespace Manager) 以追蹤儲存的邏輯檢視
* 南向驅動程式，將命令轉換為正確的儲存目標機制

#### 叢集編排器 (Cluster Orchestrator)

這是面向基礎設施的控制平面：

* 節點管理器 (Node Manager) 管理實體節點生命週期
* 放置引擎 (Placement Engine) 將實體約束應用於放置（例如：跨電源領域的複本 replicas）
* 偵測故障並管理復原、管理升級等等。

除了 SDS 控制器 and 叢集編排器之外，還有實際的儲存目標（如 VAST、WEKA、Lustre、NFS）以及潛在的資料平面服務（例如：快照、資料匯入）。

#### 所需能力 (Capabilities Required)

**儲存管理能力矩陣 (Storage Management Capability Matrix)**

| 能力 (Capability) | 用途 (Purpose) |
| --------------------------- | ------------------------------------------------------------------- |
| 區塊儲存 (Block Storage) | 將持續性磁碟區附加至執行實例 |
| 檔案儲存 (File Storage) | 用於資料集與檢查點 (Checkpoint) 的共享檔案系統 |
| 物件儲存 (Object Storage) | 用於資料湖 (Data lakes) 和產出物 (Artifacts) 的 S3 相容儲存 |
| 儲存租戶隔離 (Storage Tenant Isolation) | 磁碟區存取控制、命名空間隔離、每個租戶的加密 |
| 儲存服務品質 (Storage QoS) | 執行每個租戶的頻寬/IOPS 限制，以防止吵鬧鄰居 (Noisy neighbor) 效應 |
| 高效能資料路徑 (High-Performance Data Path) | 繞過 CPU，實現 GPU 對儲存的直接資料傳輸 (GPUDirect) |
| 儲存網路整合 (Storage Network Integration) | 連接至支援 NVMe-oF、RDMA 的儲存織網 |

## 適用於基礎設施即服務的 NVIDIA 軟體 (NVIDIA Software for Infrastructure-as-a-Service)

NVIDIA 提供軟體來解決上述特定的 IaaS 能力。使用 NVIDIA 提供的軟體是選配的，取決於 NCP 所做的架構決策。NCP 可以與 ISV 合作夥伴生態系統合作，以整合所提供的特定軟體元件。

**適用於 IaaS 的 NVIDIA 軟體元件 (NVIDIA Software Components for IaaS)**

| 功能區域 (Functional Area) | NVIDIA 軟體實作 (NVIDIA Software Implementation) |
| -------------------- | -------------------------------------------------------------- |
| 網路管理 (Network Management) | Cumulus, NetQ, UFM, NMX, DOCA/HBN, NVIDIA Infra Controller[1] |
| 運算管理 (Compute Management) | NVIDIA Infra Controller |
| 儲存連線 (Storage Connectivity) | GPUDirect Storage, GPUDirect RDMA |
| 維運操作 (Operations) | DCGM |

有關每個元件的詳細描述，請參閱 [第二部分：適用於基礎設施即服務的 NVIDIA 軟體](/dsx/ncp/part-2-software-components/nvidia-software-for-infrastructure-as-a-service)。

[1]: NVIDIA Infra Controller 提供整合式多租戶基礎設施管理，跨所有三個網路領域（透過 HBN 的乙太網路、透過 UFM 的 InfiniBand、透過 NMX 的 NVLink）編排裸機生命週期與租戶網路隔離。

---

## 重點整理 (Key Takeaways)

1. **IaaS 層級的核心定位**
   * 為租戶提供可伸縮的裸機 (Bare Metal, BM) 與虛擬機 (VM) 實例，使其能在免除管理底層硬體的情形下運行 AI 工作負載。IaaS 能依需求自訂運算大小、記憶體、儲存與 GPU 容量。

2. **IaaS 架構三大管理支柱**
   * **網路管理 (SDN)**：透過 SDN 將控制平面與資料平面分離，支援中央編程式更新。運算節點安裝 SDN 代理，並由 BlueField DPU 運行 DOCA/HBN 在邊緣終止租戶的 VXLAN 疊加網路 (VPC 隔離)。
   * **運算管理**：管理機器資產、PXE 自動安裝引導、硬體完整性證明 (Hardware Attestation)、健康度壓力測試、機器在租戶轉移時的安全清理消毒 (Sanitization)、以及 GPU 虛擬化 (時間分片或 MIG)。
   * **儲存管理 (SDS)**：分為暫存儲存 (租戶輪替時清除) 與網路持續性儲存 (區塊、檔案、物件)。透過 SDS 控制器 (面向租戶) 與叢集編排器 (面向硬體) 管理實體配置，並透過 GPUDirect Storage/RDMA 連接。

3. **NVIDIA 關鍵軟體堆疊對照**
   * **網路管理**：NVSwitch 由 NMX 管理，InfiniBand 由 UFM 管理，Cumulus 乙太網路交換器由 NetQ 提供監控遙測，BlueField DPU 則藉由 DOCA/HBN 進行邊緣封裝。
   * **NVIDIA Infra Controller**：扮演極重要角色，提供整合式多租戶基礎設施編排，能夠跨乙太網路 (HBN)、InfiniBand (UFM)、以及 NVLink (NMX) 等三大領域統一管理裸機生命週期與租戶隔離。
   * **加速傳輸與維運**：利用 GPUDirect Storage/RDMA 繞過 CPU 達成 GPU 至儲存直接傳輸，並使用 DCGM 監控 GPU 健康狀態。
