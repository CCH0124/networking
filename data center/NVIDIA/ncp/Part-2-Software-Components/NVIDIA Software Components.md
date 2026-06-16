# NVIDIA Software Components

本節提供了有關 NVIDIA 提供的軟體元件之詳細資訊，這些元件解決了 [軟體參考指南 (Software Reference Guide)](/dsx/ncp/part-1-software-reference-guide/ncp-software-reference-guide) 中所述的能力。每個元件皆與其支援的架構層級進行了對應。使用 NVIDIA 軟體是選配的，取決於 NCP 或 ISV 所做的架構決策。NCP 可以與合作夥伴生態系統合作以整合這些元件，或實作替代解決方案。

本節按功能區域進行組織，鏡像對照了「軟體參考架構」章節的結構：

* 基礎設施平台 (Infrastructure Platform)：
  * 網路管理 (Network Management) —— 用於管理乙太網路、InfiniBand 和 NVLink 織網的軟體
  * 運算管理 (Compute Management) —— 用於裸機生命週期、GPU 虛擬化和可觀測性的軟體
  * 儲存 (Storage) —— 用於高效能 GPU 對儲存連線的軟體
* 容器平台 (Container Platform) —— 適用於 GPU 加速容器 and Kubernetes 的軟體
* AI 平台 (AI Platforms) —— 用於訓練和推論工作負載管理的軟體

## 關鍵軟體元件 (Key Software Components)

NVIDIA 提供的關鍵軟體元件列於下表。

**關鍵 NVIDIA 軟體元件**

| 元件 (Component) | 描述 (Description) |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 虛擬 GPU 軟體 (Virtual GPU Software) | 與平台硬體通訊，在主機 (Host) 與客端 (Guest) 之間分配 GPU 資源。 |
| 網卡/交換機架構管理器 (Fabric Manager) | 為高效能多 GPU 工作負載對 NVSwitch 進行程式化配置。 |
| NVIDIA DOCA™ 軟體 (NVIDIA DOCA™ software) | 包括 DOCA-OFED 驅動程式以及 DOCA 加速程式庫與服務，以啟用 AI 工作負載的加速網路。 |
| NVIDIA 資料中心 GPU 管理器 (DCGM) | DCGM 提供 GPU 監控、診斷與遙測能力。啟用自動化故障修復與基礎設施可觀測性。 |
| NVIDIA 基礎設施控制器 (NVIDIA Infra Controller) | NVIDIA Infra Controller 是 NVIDIA 的雲端原生裸機配置平台，提供由 DPU 編排的硬體生命週期管理。 |
| Base Command Manager | 透過工作負載佈署來管理 AI 基礎設施。 |
| 容器工具包 (Container Toolkit) | 啟用容器執行期 (Container runtimes) 以在容器內存取 GPU 硬體。 |
| NVIDIA K8s Operators | **GPU Operator**：標準化 K8s 中的 GPU 管理，實現更好的 GPU 效能、利用率與遙測。**Network Operator**：簡化 K8s 叢集中 NVIDIA 網路資源的配置與管理。**NIM Operator**：自動化佈署與管理用於生成式 AI 應用程式的 NVIDIA NIM™ 微服務生命週期。此外也包括允許 GPU 在 K8s 上運作的 **NVIDIA GPU 驅動程式**。 |
| Run:ai | 透過利用 K8s 編排來最佳化工作負載部署。 |
| NVIDIA 雲端函數 (NVIDIA Cloud Functions, NVCF) | 一個無伺服器 (Serverless) API，允許使用者在 GPU 上部署和管理 AI 工作負載，提供儲存容量、安全性與可靠性，可透過 HTTP 輪詢、串流或 gRPC 協定存取。K8s 整合可以透過 NVIDIA 叢集代理程式 (NVCA) 來實現。 |
| NVIDIA 推論微服務 (NIM) | 一套易於使用的微服務，旨在跨雲端、資料中心與工作站安全、可靠地部署高效能 AI 模型推論。 |
| NVIDIA NeMo™ 微服務 (NVIDIA NeMo™ microservices) | 提供模型自訂的端到端工作流程，使企業能夠高效地使大型語言模型適應其特定需求。 |

下表所示的其他軟體可用於完整基礎設施管理，其中包括網路元件。這些元件在 [適用於基礎設施即服務的 NVIDIA 軟體](/dsx/ncp/part-2-software-components/nvidia-software-for-infrastructure-as-a-service) 中有詳細介紹。

**其他適用於基礎設施元件的 NVIDIA 軟體**

| 元件 (Component) | 層級 (Layer) | 功能 (Function) |
| --------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- | ----------------------------------------------------------------------------------------------- |
| [統一架構管理器 (UFM)](https://docs.nvidia.com/networking/display/ufmenterpriseumv6190/installing+ufm+server+software) | 網路管理 | 透過 MLNX-OS 管理 Quantum InfiniBand 交換器 |
| [NVIDIA 使用者體驗 (NVUE)](https://docs.nvidia.com/networking-ethernet-software/cumulus-linux-513/System-Configuration/NVIDIA-User-Experience-NVUE/) | 網路管理 | 透過 Cumulus Linux 管理 Spectrum 乙太網路交換器 |
| [NetQ](https://docs.nvidia.com/networking-ethernet-software/cumulus-netq-414/NetQ-Overview/NetQ-Basics/NetQ-Components/) | 監控與可見性 | 提供網路和主機的可見性 |
| [NVIDIA Air](https://air.nvidia.com/) | 部署驗證 | 提供部署驗證的模擬環境 |
| [NMX](https://docs.nvidia.com/networking/software/nvlink-management-software/index.html) | 網路管理 | 管理基於 NVSwitch 的 NVLink 互連。NMX 包含三個元件：NMX-C、NMX-M 和 NMX-T。 |

以下元件補足了 NVIDIA 軟體，並被選用以完整整個系統堆疊。以下基礎設施元件可由 NCP、ISV 或開源生態系統提供：

**基礎設施軟體元件**

| 元件 (Component) | 層級 (Layer) | 描述 (Description) |
| ------------------------------ | ----- | ------------------------------------------------------------------------------------------ |
| 作業系統 (Operating System) | IaaS | 用於運算主機的 Linux 發行版 |
| 超級監督器 (Hypervisor) | IaaS | 將實體主機資源配置給客端虛擬機 |
| 雲端控制平面 (Cloud Control Plane) | IaaS | 面向租戶的控制平面，提供 API/UI 以配置運算、網路和儲存 |
| SDN 控制器 (SDN controller) | IaaS | 將網路意圖翻譯對接至實體硬體 |
| 儲存系統 (Storage System) | IaaS | 區塊、檔案、物件儲存 |
| 身分與存取管理 (Identity and Access Management) | IaaS | 租戶身分驗證與授權 |
| Kubernetes | CaaS | 容器編排平台 |
| Slurm | CaaS | 用於作業排程的 HPC 工作負載管理器 |
| PyTorch | CaaS | 具備 Python 前端且經 GPU 加速的張量運算框架 |
| AI 平台 (AI Platform) | SaaS | 面向租戶的訓練和推論工作負載平台 |

---

## 重點整理 (Key Takeaways)

1. **NVIDIA 官方軟體元件庫的定位**
   * 本章節為 NCP 軟體參考指南的 Part 2 元件庫，明列各架構層級中 NVIDIA 官方提供的軟體與技術，旨在協助合作夥伴整合特定功能。使用與否為選配架構決策。

2. **核心基礎設施管理與監控**
   * **NVIDIA Infra Controller**：提供由 DPU 編排的裸機硬體全生命週期管理。
   * **Fabric Manager / NMX**：負責 NVSwitch/NVLink 的配置與多 GPU 大規模互連。
   * **UFM / NVUE / NetQ**：對 Quantum InfiniBand、Spectrum 乙太網交換器進行管理、網路遙測及主機可見性診斷。
   * **DCGM (資料中心 GPU 管理器)**：提供硬體監控、診斷與遙測，為自動化故障修復及可觀測性的核心。

3. **高階容器排程與生成式 AI 微服務**
   * **NVIDIA K8s Operators**：整合了 GPU Operator、Network Operator 與 NIM Operator，標準化 Kubernetes 叢集中的 GPU、RDMA 網路及 NIM 微服務部署生命週期。
   * **NVIDIA NIM (推論微服務)**：提供開箱即用、安全且經效能優化的 AI 推論微服務。
   * **NeMo 微服務**：提供大語言模型定製化與模型微調的端到端管線流程。
   * **Run:ai**：藉由 K8s 原生編排與彈性調度最大化硬體利用率。

4. **硬體與生態系軟體整合**
   * 強調整套架構除了 NVIDIA 軟體外，還必須完美整合底層 OS (Linux)、虛擬化層 (Hypervisor)、SDN 控制器、平行儲存系統，以及上層開源 AI/ML 框架 (如 Kubernetes、Slurm、PyTorch)，以建構完整的 AI 雲端服務堆疊。
