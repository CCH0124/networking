# Performance Requirements

本節描述了在同一部工作主機上託管多個虛擬機 (VM) 時，滿足 AI 訓練與推論工作負載效能需求所需的實作細節。

為了滿足多節點 AI 工作負載的效能需求，工作負載必須具備對網路、GPU 和儲存的原生存取權限 (Native access)。這適用於裸機 (Bare Metal)、Linux 上的 K8s，或是運行在虛擬機 (VM) 內部等所有情況。因此，實作此處討論的硬體直通技術 (Hardware passthrough techniques) 以獲得最佳效能至關重要。

本參考架構 (RA) 還概述了如何在「專屬的實體工作主機」或「共享的工作主機」上運行多 GPU 和多節點 AI 推論與訓練工作負載，以最大化硬體利用率。NVIDIA 軟體（如 NIM 和 NeMo 微服務）已針對其運行的 GPU 實例進行了效能最佳化。此外，NVIDIA [GPUDirect®](https://developer.nvidia.com/gpudirect)（包括 RDMA 和儲存 GPUDirect Storage）加速了 GPU 之間、GPU 與記憶體之間，以及 GPU 與儲存之間的資料流動。

適用於 NCP 的 NVIDIA® 硬體參考架構是使用專為最佳 AI 效能打造的 NVIDIA 認證系統 (NVIDIA-Certified systems)。這些系統利用了 NVIDIA NVLink 織網 (NVLink Fabric) 及其經過最佳化的 PCIe 拓撲，在虛擬化系統時必須保留這些特性。虛擬機需要一個能將已最佳化之 PCIe 拓撲顯露給虛擬機內部的虛擬 PCIe 拓撲。

有關最佳 PCIe 拓撲，以及在使用虛擬機時將 vCPU 綁定 (vCPU pinning) 和記憶體配置到合適的 NUMA 節點等其他效能最佳化資訊，請參閱輔助[文件](https://docs.nvidia.com/ai-enterprise/planning-resource/optimizing-vm-configuration-ai-inference/latest/introduction.html)。

## 虛擬機網路 (Virtual Machine Networking)

網路是 AI 中最關鍵的效能向量之一。運行容器或虛擬機時，營運商必須將一個完全配置好的 SR-IOV 虛擬網卡 (virtual NIC) 連接至容器或虛擬機中。根據您採用的 SDN 系統，有幾種眾所皆知的方法可以實現這一點。以下是將 SR-IOV 網卡分配給虛擬機的標準範例流程：

1. VMaaS 向 SDN 發出基於意圖的請求，將虛擬機 X 加入 VPC Y。
2. SDN 執行對應對接（分配 VPC、配置資源等等）。
3. SDN 觸發 PCIe 熱插拔 (Hotplug) 事件，使新定義的 SR-IOV 虛擬功能 (VF, Virtual Function) 顯露給主機 Linux 核心。
4. SDN 控制器將 VF 綁定至 VFIO/QEMU。

隨後，當虛擬機啟動時，便會存在直通網路裝置 (Passthrough networking device)，虛擬機可以直接與網卡硬體進行通訊，而不需要中間有任何來自實體主機的軟體介入。這適用於任何高效能網路路徑需求。對於其他效能要求較低的 Pod 服務，使用更標準的 CNI 連接路徑（或根據營運商的需求使用其他 SR-IOV 網卡資源）可能是可以接受的。

此外，應考慮兩個效能功能。首先，必須仔細思考如何配置網路服務以避免對負載封包 (Payload) 進行額外的封裝 (Encapsulation)。應該要能夠為租戶的疊加網路啟用單一隧道 (Single tunnel)。其次，VMaaS 編排器應具備拓撲感知 (Topology-aware) 能力，以便能夠以最佳化集體通訊 (Collectives) 連線的方式來投放工作任務。

## 虛擬機流量加速 (Virtual Machine Traffic Acceleration)

為了在虛擬化環境中滿足多節點 AI 工作負載的效能需求，虛擬機需要硬體加速網路以確保最佳效能與隔離性。

NCP 參考架構定義了三種網路類型：

* **運算網路 (Compute Network)**：使用 ConnectX 和 BlueField SuperNIC 的高頻寬、低延遲 GPU 對 GPU 或 GPU 對 CPU 連線 (InfiniBand/乙太網路)。
* **融合網路 (Converged Network)**：使用 BlueField DPU (乙太網路) 的高效能儲存與頻內管理。
* **頻外 (OOB) 管理網路 (Out-of-band Management Network)**：低速管理連線（1 Gbps 連接埠）。

為了與虛擬機實現高效能網路連線，超級監督器 (Hypervisor) 必須向租戶虛擬機分配硬體加速網路功能。這些功能可確保虛擬機能夠高效地存取運算網路和融合網路。

兩項關鍵技術啟用了虛擬機流量加速與隔離：

* **單根 I/O 虛擬化 (SR-IOV, Single Root I/O Virtualization)**：此技術允許網路封包繞過超級監督器 CPU/核心，直接透過網卡硬體進行轉發。這降低了延遲，並卸載了 CPU 的處理開銷。
* **加速交換與封包處理 (ASAP, Accelerated Switching and Packet Processing)**：建置在 SR-IOV 之上，增加了進階功能，例如軟體定義網路 (SDN) 和虛擬私有雲 (VPC)，確保租戶工作負載有更大的靈活性與擴充性。

一旦這些加速網路功能被分配給租戶虛擬機，NVIDIA® Network Operator 就可以在用戶的 K8s 叢集內將它們配置為 NVIDIA 網路資源。

## 虛擬化 GPU (Virtualizing a GPU)

如同網路功能一樣，為虛擬機或容器提供對 GPU 硬體的直通存取 (Direct access)，對於獲得最佳 AI 效能至關重要。有四種不同的方式來顯露 GPU：

**GPU 虛擬化類型 (Types of GPU Virtualization)**

| 使用場景 (Use Case) | 方法 (Method) | 備註 (Comments) |
| ----------------------------------------- | -------------------------------------------------- | -------------------------------------------------------------- |
| 虛擬機專屬的 GPU (Exclusive GPU for a VM) | VFIO/QEMU | 標準的 SR-IOV 機制 |
| 容器專屬的 GPU (Exclusive GPU to container) | NVIDIA Container Toolkit | 綁定掛載 (Bind mounts) 節點並注入程式庫 |
| 用於虛擬機/容器的多執行個體 GPU (MIG) | MIG 管理器 + VFIO/QEMU | 依 GPU 進行硬體分割。安全性仍低於獨佔模式。 |
| 時間分片「分段式」GPU (Time-sliced fractional GPU) | NVIDIA vGPU Manager，直通 vGPU 切片 (vGPU slide) | 最不安全的模型 |

這通常由 VMaaS 或 BMaaS 定義。在大多數情況下，主要方法是將一整顆 GPU 分配給虛擬機，然後該虛擬機再決定如何將其顯露給內部的任何容器。

有關適用於虛擬化的 NVIDIA 軟體元件，請參閱[虛擬化](/dsx/ncp/part-2-software-components/nvidia-software-for-infrastructure-as-a-service#virtualization)章節以及 [用於運算的 vGPU 章節](/dsx/ncp/part-2-software-components/nvidia-software-for-infrastructure-as-a-service#nvidia-vgpu-for-compute)。

## 啟用多租戶與隔離 (Enabling Multitenancy and Isolation)

在多租戶環境中，超級監督器與虛擬機編排解決方案必須提供嚴格的隔離與效能保證，即使來自多個租戶的工作負載共存於同一個實體主機上也是如此。虛擬機網路可以透過利用 NVIDIA BlueField DPU 和 ConnectX SuperNIC（結合 SR-IOV 和 ASAP2 等技術）上的硬體加速，來實現多租戶 AI 部署所需的效能和隔離。這些技術啟用了網路資源的直接、硬體強制分割 (Hardware-enforced partitioning)，從而最小化 CPU 開銷並降低延遲。透過將關鍵的網路和安全功能卸載到硬體上，它們在維持高吞吐量和可預測效能的同時，確保了嚴格的租戶隔離。

## 儲存連線 (Storage Connectivity)

儲存應該獨立於該解決方案之外，並以具備多租戶能力服務的形式提供給租戶。這種儲存服務模式同時適用於控制平面儲存（例如：用於虛擬機的集中式儲存）以及租戶儲存（例如：區塊儲存即服務），這些儲存可以連接到 Pod 以供工作負載啟動和運行時的資料存取。有關外部儲存實作的詳細需求，請參閱「高效能儲存參考架構」。

## 虛擬儲存 (Virtual Storage)

儲存對於 AI 工作負載的效能同樣至關重要。實體機器、虛擬機或容器可能需要存取高效能儲存。有幾個實用的選項可用：

* **暫存儲存 (Ephemeral Storage)**：本機暫存儲存可以提供良好的效能。根據基礎設施的不同，這可能僅適用於裸機。用途很多，但主要的效能驅動因素在於本機 AI 應用程式（推論或訓練）快取本機資料與模型映像檔。為了支持這一點，NVMe 硬碟（或可能是分割區）應該被顯露為本機磁碟區，例如 `/dev/nvme01`。
* **高效能平行儲存 (High Performance Parallel Storage)**：VAST 和 WEKA 等供應商提供了高效能的檔案系統與物件儲存，而 DDN 等其他供應商則專注於檔案系統。對於不同的使用場景，不同的選擇都是合理的。當將高效能儲存顯露為檔案系統時，必須將儲存路徑顯露給使用者。在虛擬機的情況下，VMaaS 層可以簡單地向虛擬機提供 SR-IOV 儲存網卡，而虛擬機負責安裝儲存用戶端（例如：Vast / WEKA / DDN 的 NFS 用戶端）並掛載該硬碟。
* 應考慮將 GPU 叢集本機儲存 (local storage) 作為高效能/低延遲推論工作負載的解決方案。

低效能的檔案系統或啟動磁碟路徑可以使用標準的 K8s CSI 機制顯露。

---

## 重點整理 (Key Takeaways)

1. **效能優化的核心原則：硬體直通與拓撲保留**
   * 無論在裸機、容器或 VM 中運行，AI 訓練與推論工作負載皆必須獲得對網路、GPU 和儲存的**原生存取權限**。
   * 虛擬化系統時，必須保留 NVIDIA 認證系統特有的 PCIe 與 NVLink 拓撲結構，利用虛擬 PCIe 拓撲將其顯露給虛擬機，並結合 vCPU 綁定與 NUMA 記憶體放置進行優化。

2. **虛擬機網路與流量加速**
   * 使用 **SR-IOV**（讓網路封包繞過虛擬化 CPU/Kernel）與 **ASAP/ASAP2**（加速交換與封包處理）技術，將硬體加速網路功能直接分配給 VM，降低 CPU 開銷，滿足運算網路與融合儲存網路的高頻寬需求。
   * 透過拓撲感知 (Topology-aware) 排程最佳化任務放置，避免疊加網路中多餘的封裝。

3. **GPU 虛擬化與硬體級隔離**
   * Expose GPU 的四種主要方式：虛擬機專屬 (VFIO/QEMU)、容器專屬 (NVIDIA Container Toolkit)、多執行個體 GPU (MIG) 及時間分片 (vGPU)；其中以專屬模式具備最嚴格的安全性。
   * 利用 BlueField DPU 和 ConnectX 的硬體加速實現對網路資源的直接、硬體強制分割 (Hardware-enforced partitioning)，保障多租戶環境下的效能與嚴格安全隔離。

4. **虛擬儲存配置與 GPUDirect**
   * 支援本機 NVMe ephemerals（直通為本機磁碟區如 `/dev/nvme01`）以供 AI 推論/訓練快取資料與模型。
   * 利用 GPUDirect Storage/RDMA 繞過 CPU 達成 GPU 至儲存直接傳輸。VM 透過 SR-IOV 儲存網卡搭配本機用戶端（如 Vast、Weka 或 DDN 的 NFS 用戶端）直接掛載高效能平行檔案系統。
