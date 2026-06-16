# NVIDIA Software for Infrastructure as a Service

以下 NVIDIA 軟體支援第一部分中所描述的 IaaS 管理領域：網路管理、運算管理與儲存管理。

## 網路管理 (Network Management)

### NVIDIA 統一架構管理器 (NVIDIA Unified Fabric Manager, UFM)

用於高效能 GPU 對 GPU 通訊的 InfiniBand 織網需要集中式管理，以監控健康狀況、檢測擁塞、隔離租戶並解決問題。[NVIDIA UFM®](https://docs.nvidia.com/networking/software/management-software/index.html#ufm-enterprise) 平台透過結合增強的即時網路遙測技術與 AI 驅動的網路智能分析，來支援東西向橫向擴充的 InfiniBand 連接資料中心，從而徹底改變了資料中心網路管理。UFM Telemetry 提供網路驗證工具以監控網路效能和狀況。UFM Enterprise 將 UFM Telemetry 的優勢與增強的網路監控和管理相結合。UFM Cyber-AI 進一步增強了 UFM Telemetry 和 UFM Enterprise 的效益，提供預防性維護和網路安全防護。

### NVIDIA 使用者體驗 (NVIDIA User Experience, NVUE)

乙太網路交換器在大規模的 Leaf-Spine 織網中需要一致且可程式化的配置。手動的 CLI 配置無法擴充且容易出錯。[NVIDIA 使用者體驗 (NVUE)](https://docs.nvidia.com/networking-ethernet-software/cumulus-linux-513/System-Configuration/NVIDIA-User-Experience-NVUE/) 是 Cumulus Linux 隨附的軟體。它是一個提供 Cumulus Linux 系統結構化模型 (Schema-driven model) 的公用程式，包含硬體和軟體的管理。NVUE 有多種互動方式，包括命令列、API 和物件模型。NVUE 包含在 [Cumulus Linux](https://docs.nvidia.com/networking-ethernet-software/cumulus-linux-515/) 中，並運行在每個 Spectrum 交換器上。SDN 控制器可以與 NVUE 的 REST API 進行互動以推送配置，營運商也可以使用 CLI 進行直接存取。參考指令可以在[說明文件](https://docs.nvidia.com/networking-ethernet-software/cumulus-linux-515/Whats-New/New-and-Changed-NVUE-Commands/#all-new-nvue-commands)中找到。

### NVIDIA NetQ

[NVIDIA NetQ™](https://www.nvidia.com/en-us/networking/ethernet-switching/netq/) 是一個高度可擴充的現代網路維運工具集，可即時提供 Cumulus 織網的可見性、故障排除和驗證。NetQ 利用遙測技術並提供關於資料中心網路健康狀況的可操作分析，將織網整合到 DevOps 生態系統中。

**NVIDIA NetQ 功能**

| 功能 (Feature) | 描述 (Description) |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 網路管理 (Network management) | 按下一顆按鈕，即可存取強大的工具來管理您的 NVIDIA® Cumulus Linux™ 和 SONiC 環境。 |
| 進階遙測 (Advanced telemetry) | 收集即時資料，以便從單一 GUI 進行深度故障排除、可見性分析和自動化工作流程。 |
| 快照與比較 (Snapshot and compare) | 輕鬆將先前的網路配置與進行網路變更後的配置進行比較，以消除中斷的風險。 |
| 全網可見性 (Network-wide visibility) | 使用 NetQ 豐富的 GUI 查看關於網路健康狀況的即時視覺化資訊。 |
| 串流流量遙測 (Flow telemetry) | 分析整個織網的延遲和緩衝區佔用數據（針對 4 元組或 5 元組流量的所有路徑），以識別擁塞點。 |
| 預防性驗證 (Preventive validation) | 在將配置投入生產環境之前，減少手動錯誤。 |
| 診斷故障排除 (Diagnostic troubleshooting) | 使用進階診斷工具診斷狀態偏差的根本原因。 |
| RoCE 支援 (RoCE support) | 使用 NetQ 監控基於融合乙太網路的遠端直接記憶體存取 (RoCE) 環境，以獲得高效能網路的可操作分析。 |

### NVIDIA NMX

GB200 和 GB300 機櫃級系統使用 [基於 NVSwitch 的 NVLink](https://www.nvidia.com/en-us/data-center/nvlink/) 互連，以在機櫃內提供高頻寬的 GPU 對 GPU 通訊。這些 NVLink 領域需要專屬的管理（與傳統乙太網路和 InfiniBand 織網分開），以便在多機櫃部署中進行配置、健康監控和協調。[NVIDIA NMX](https://docs.nvidia.com/networking/display/nmxcv11/nmx+introduction) 是基於 NVSwitch 互連的管理與分析平台。它由四個協同運作的元件組成，用以管理 GPU 機櫃內的 NVLink 縱向擴充網路。

**NVIDIA NMX 元件**

| 元件 (Component) | 名稱 (Name) | 運行位置 (Where it runs) | 功能 (Function) |
| --------- | -------------- | --------------------------- | --------------------------------------------------------- |
| NMX-C | NMX 控制器 (NMX Controller) | 每個 NVLink 交換器托盤上 | 單櫃級控制器，負責為個別 NVSwitch 進行配置 |
| NMX-T | NMX 遙測 (NMX Telemetry) | 每個 NVLink 交換器托盤上 | 從 NVLink 交換器收集遙測與指標 |
| NMX-M | NMX 管理器 (NMX Manager) | 集中式（控制平面） | 跨多個 NVLink 交換器機櫃進行集中管理彙整 |
| NMX Oasis | Oasis | 集中式 | 用於遙測資料的 API 閘道、ETL 以及儀表板 |

### DOCA / HBN

多租戶雲端環境需要在運算邊緣進行網路隔離。傳統的基於軟體的疊加網路 (Overlay) 會消耗主機 CPU 週期並增加延遲。透過將 SDN 功能卸載到 DPU，NCP 可以執行租戶隔離而不影響工作負載效能，同時也在租戶和基礎設施之間提供硬體根源的安全邊界。

[DOCA](https://docs.nvidia.com/doca/sdk/doca-hbn-service-guide/index.html) 是適用於 NVIDIA® BlueField® DPU 的 SDK 與執行期。DOCA-OFED 驅動程式在主機上提供最佳化的網路連接。主機端網路 (Host-Based Networking, HBN) 將 L2/L3 疊加網路（VXLAN、EVPN）卸載到 DPU 上，從而在運算邊緣實現租戶 VPC 隔離。

HBN 還啟用了共享服務網路。SDN 控制器透過極少的路由洩漏 (Route leaks) 為 DPU 進行配置，允許租戶存取共享服務，同時保持彼此之間的隔離。

## 運算管理 (Compute Management)

### NVIDIA 基礎設施控制器 (NVIDIA Infra Controller)

[NVIDIA Infra Controller](https://github.com/NVIDIA/ncx-infra-controller-core/tree/main) 提供裸機基礎設施生命週期管理。NVIDIA Infra Controller 作為 Kubernetes 上的站點本機 (Site-local) 元件運作，自動化從硬體搜尋到租戶就緒之裸機的完整生命週期，這對於營運商和 NCP 在機櫃級 GB200/GB300 上支援多租戶 AI 雲端平台至關重要。傳統的叢集管理工具需要為每個租戶進行一次部署，從而帶來了線性擴充挑戰。NVIDIA Infra Controller 透過以下方式解決了此問題：

* 基於 DPU 的隔離 —— 透過 BlueField DPU 執行硬體強制的租戶隔離
* 共享基礎設施 —— 單一 NVIDIA Infra Controller 實例即可管理所有租戶
* API 優先架構 —— 啟用具備管理員和租戶檢視的 ISV 雲端入口網站

NVIDIA Infra Controller 被設計為 API 優先平台，顯露了 gRPC API，NCP 和 ISV 可將其整合到其雲端控制平面與編排系統中。這啟用了：

* 對所有裸機生命週期維運的程式化控制
* 與現有 NCP 配置工作流程的整合
* 與身分識別提供者 (IdP，例如 Keycloak) 整合的 JWT 權杖驗證，以實現角色型存取控制 (RBAC)
* 讓 NCP 能夠靈活地在 NVIDIA Infra Controller 原語 (Primitives) 之上建置差異化服務。

**NVIDIA 基礎設施控制器功能**

| 功能 (Feature) | 描述 (Description) |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 網路隔離 (Network Isolation) | - 乙太網路：透過 DPU 上的 HBN 為租戶 VPC 配置 VXLAN/EVPN 疊加網路<br />- InfiniBand：透過 UFM 配置分割區鍵 (P\_Keys) 以實現 CIN 隔離<br />- NVLink：透過 NMX-M 編排 NVLink 分割區的建立，以實現機櫃級 GPU 隔離 |
| 機器生命週期管理 (Machine Lifecycle management) | - 硬體搜尋 (Hardware Discovery)：透過 Redfish API 自動搜尋新硬體<br />- 主機-DPU 配對 (Host-DPU pairing)：將主機與其附加的 BlueField DPU 進行關聯<br />- 機器驗證 (Machine Validation)：燒機測試 (Burn-in test) 以確認主機功能<br />- 韌體管理 (Firmware management)：針對 BMC、UEFI 和 DPU 韌體進行自動化更新 |
| DPU 生命週期管理 (DPU Lifecycle management) | - DPU 配置 (DPU Provisioning)：將 DPU 作業系統安裝至 BlueField DPU 上<br />- HBN：部署容器化網路堆疊 |
| 安全性 (Security) | - 受度量啟動 (Measured Boot) 與主機證明 (Host attestation)<br />- BMC/UEFI 鎖定以防止租戶存取管理介面<br />- 兩次分配之間的租戶清理消毒 (Tenant Sanitization) |

在 NVIDIA Infra Controller 工作流程完成後，NCP 將獲得一個經過驗證、韌體最新、網路隔離的裸機主機。此裸機主機已準備好直接分配給租戶，或安裝超級監督器以運行虛擬化工作負載。

從營運商的角度來看，NVIDIA Infra Controller 將機架上的硬體轉化為經過驗證、韌體最新且網路隔離的裸機；隨時可以進行直接的租戶分配或超級監督器安裝，或者整合至 Base Command Manager 等工作負載管理平台。這完成了裸機配置階段，為上方所有的運算服務提供了基礎。

雖然硬體管理不一定需要 NVIDIA Infra Controller，但它是 NVIDIA 提供的軟體，可簡化機櫃級系統上多租戶硬體管理的複雜度。

### 虛擬化 (Virtualization)

對於基於虛擬機的部署，NCP/ISV 在像 NVIDIA Infra Controller 這樣的雲端原生配置層或原生裸機上部署虛擬化層。虛擬化的主要實現者是超級監督器 (Hypervisor)。NVIDIA 不提供超級監督器軟體；然而，NCP 和 ISV 可以根據營運需求從生態系統中選擇產品（例如基於 KVM 的超級監督器）。

請向您的 NVIDIA 銷售代表索取《NVIDIA Grace™ I/O 虛擬化指南》（NVIDIA Grace™ I/O Virtualization Guide，PID 1144496）。

### 適用於運算的 NVIDIA vGPU (NVIDIA vGPU for Compute)

多租戶 AI 基礎設施通常需要在虛擬機之間共享 GPU 資源，同時維持隔離與效能。NCP 需要對 GPU 進行虛擬化以最大化硬體利用率、支援多樣化的租戶工作負載，並提供靈活的 GPU 分配，而無需為每個 VM 配備專屬的實體 GPU。NVIDIA vGPU 軟體在領先的超級監督器平台上啟用了 GPU 虛擬化。

* **虛擬 GPU 管理器 (Virtual GPU Manager)** —— 運行在超級監督器主機上，管理 GPU 資源分配
* **客端驅動程式 (Guest Drivers)** —— 安裝在每個虛擬機中以啟用 GPU 存取

vGPU 允許有多個虛擬機共享單個實體 GPU，並具有可配置的設定檔 (Profiles)，這些設定檔定義了分配給每個 VM 的 GPU 記憶體和運算能力。這使 NCP 能夠向租戶提供分段式 (Fractional) GPU 實例。欲了解更多資訊，請閱讀：
[NVIDIA AI Enterprise and NVIDIA vGPU for Compute](https://docs.nvidia.com/ai-enterprise/release-7/latest/infra-software/vgpu.html)

### Base Command Manager

[Base Command Manager (BCM)](https://docs.nvidia.com/base-command-manager/index.html) 是一款簡化配置、工作負載管理與基礎設施監控的軟體。它解決了與管理 AI 基礎設施及其上運行的工作負載相關的許多需求。本節僅提及其中一部分。完整清單可在以下網址取得：
[Base Command Manager Feature Matrix](https://support.brightcomputing.com/feature-matrix/)。
該軟體包含在 NVIDIA AI Enterprise 套件中。BCM 作為工作負載管理層運行在已配置的基礎設施之上。運算節點和超級監督器可以透過平台專屬工具或透過 Base Command Manager 進行配置，後者支援使用 PXE 進行作業系統部署。Base Command Manager 還可以管理[網路基礎設施](https://support.brightcomputing.com/manuals/10/admin-manual.pdf)，並且專門與 Cumulus Linux 搭配運作，將其作為網路作業系統。

Base Command Manager 不是一個營運平台。它用於在運算節點（客端 OS）上配置與安裝作業系統。Base Command Manager 還具備在這些運算節點上部署 Slurm 和 K8s 的能力，以協助建置完整的編排堆疊。它可以建立多個網路，並管理電源控制和遙測。

雖然本文件不強制要求使用 Base Command Manager，但它是 NVIDIA 提供的解決方案，可簡化運算節點上的工作負載配置。BCM 旨在用於單租戶部署，不用於多租戶 NCP 裸機管理。可考慮使用例如 [NVIDIA Infra Controller](#nv-software-components-iaas-ncx-infra-controller) 等軟體元件。

### 搭配虛擬機使用 Base Command Manager (Base Command Manager with Virtual Machines)

本文件利用虛擬機來提供安全且高效能的多租戶環境。因此，需要對叢集中的虛擬機進行編排與管理。

Base Command Manager 無法直接配置虛擬機。相反地，它在雲端平台中建立並使用範本，一旦虛擬機完全啟動，就可以將其加入到 Base Command Manager Essentials 管理領域中。

《系統管理員手冊》第 5.7 節 —— [添加新節點 (Adding New Nodes)](https://support.brightcomputing.com/manuals/10/admin-manual.pdf) 描述了如何大規模向 Base Command Manager 添加虛擬機。其他文件可在《安裝手冊》第 1.3 節 —— [引導常規節點 (Booting Regular Nodes)](https://support.brightcomputing.com/manuals/10/installation-manual.pdf) 中找到，其中虛擬機可以在本機進行分配。

雖然本文件不強制要求使用 Base Command Manager 來配置和管理虛擬機，但它是 NVIDIA 提供的解決方案，可簡化虛擬機的管理。
如需更多資訊，請造訪以下連結：

* [NVIDIA Base Command Manager 說明文件](https://docs.nvidia.com/base-command-manager/index.html)
* [NVIDIA Base Command Manager 系統管理員手冊](https://support.brightcomputing.com/manuals/10/admin-manual.pdf)
* [NVIDIA Base Command Manager 安裝手冊](https://support.brightcomputing.com/manuals/10/installation-manual.pdf)

### NVIDIA Mission Control

[NVIDIA Mission Control (NMC)](https://www.nvidia.com/en-us/data-center/mission-control/) 提供與 BCM 類似的配置和工作負載管理，並針對 GB200/300 NVL72 提供了專屬支援：用於漏液檢測、水冷散熱與硬體監控的 Redfish API，以及 NVLink 拓撲與管理。NMC 是 DGX B200/B300 和 DGX GB200/300 NVL72 系統的推薦管理選項。NMC 旨在用於單租戶或工作負載層，不適用於多租戶 NCP 裸機管理。

隨附於 Mission Control 的軟體元件可在 [Mission Control SBOM](https://docs.nvidia.com/pdf/sbom-2-2-0.pdf) 中找到。NMC 旨在用於單租戶或工作負載層，不適用於多租戶 NCP 裸機管理。

## 儲存管理的軟體參考 (Software References for Storage Management)

### GPUDirect Storage (GDS)

[NVIDIA® GPUDirect® Storage (GDS)](https://docs.nvidia.com/gpudirect-storage/getting-started/contents.html) 啟用了在 GPU 記憶體與儲存之間進行直接記憶體存取 (DMA) 傳輸的直接資料路徑，從而避免了透過 CPU 進行緩衝區複製 (Bounce buffer)。此直接路徑提高了系統頻寬，並降低了 CPU 的延遲與利用率負載。

### GPUDirect RDMA (GDR)

[GPUDirect RDMA](https://docs.nvidia.com/cuda/gpudirect-rdma/) 是一項技術，可利用 PCI Express 的標準功能，在 GPU 與第三方對等裝置 (Peer device) 之間啟用直接的資料交換路徑。

---

## 重點整理 (Key Takeaways)

1. **網路管理元件堆疊**
   * **UFM (統一架構管理器)**：專用於東西向 InfiniBand 橫向擴充網路，即時監控、Congestion 擁塞檢測與租戶安全隔離。
   * **NVUE & NetQ**：NVUE 內建於 Cumulus，為 Spectrum 交換器提供 API 程式化管理模型；NetQ 則為全網 Cumulus 交換機實作即時遙測、配置快照比較與故障診斷。
   * **NMX (NVLink 網管監控)**：包含 Controller、Telemetry、Manager、Oasis 四大核心模組，統管 NVSwitch/NVLink 縱向擴充架構。
   * **DOCA / HBN (DPU 卸載)**：藉由 BlueField DPU 將 L2/L3 VPC 疊加網路 (VXLAN/EVPN) 在運算邊緣硬體化終止，釋放主機 CPU。

2. **運算管理元件堆疊**
   * **NVIDIA Infra Controller (NCX)**：提供自動化機器搜尋、主機-DPU配對、燒機壓力驗證、以及藉由 UFM (InfiniBand/P_Keys)、HBN (Ethernet/VXLAN)、NMX (NVLink 分區) 提供硬體強制性多租戶隔離，是機櫃級裸機生命週期的管理大腦。
   * **vGPU for Compute**：在超級監督器與虛擬機上管理 GPU 資源分配，提供分段式 (Fractional) GPU 配置。
   * **BCM (Base Command Manager)**：AI 基礎設施與單租戶工作負載配置（PXE裝機、K8s/Slurm部署），不適用於多租戶 NCP 裸機管理。
   * **NVIDIA Mission Control (NMC)**：專為 GB200/300 NVL72 量身打造（支援漏液檢測與 NVLink 拓撲管理），用於單租戶/工作負載層。

3. **儲存管理加速元件**
   * **GPUDirect Storage (GDS)**：繞過 CPU 緩衝區複製，直接在 GPU 記憶體與外部儲存設備之間建立 DMA 傳輸路徑，大幅降低 CPU 延遲與負載。
   * **GPUDirect RDMA (GDR)**：利用 PCIe 標準功能，在 GPU 與第三方設備之間進行直接的資料交換。
