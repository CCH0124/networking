# NVIDIA Software for Container as a Service

## 部署 Kubernetes (Provisioning Kubernetes)

安裝 K8s 有多種方式。NVIDIA 提供了兩種方法，但也有多種來自生態系統的 K8s 安裝選項可供選擇。在叢集上安裝 K8s 存在許多自助式開源或第三方供應商解決方案，這些方案記錄在 [Kubernetes 官方安裝指南](https://kubernetes.io/docs/setup/production-environment/tools/) 或供應商的官方文件中。也可以使用 Base Command Manager Essentials 在已配置的運算節點上安裝 K8s。其實作指引記錄在《[容器化手冊 (Containerization Manual) 第 4.2 節 —— Kubernetes 設定](https://support.brightcomputing.com/manuals/10/containerization-manual.pdf)》中。Base Command Manager Essentials 處理所有的 K8s 元件，包括：

* 網路基礎 (Networking fundamentals)
* 容器網路介面 (CNI, Container networking interface)
* `kubeadm` 元件
* CoreDNS
* NGINX Ingress 控制器 (NGINX ingress controllers)
* 儀表板 (Dashboard)
* 指標伺服器 (Metrics server)

此外，Base Command Manager 還會安裝 Helm 作為套件管理器，以簡化工作負載編排。

使用 Base Command Manager (BCM) 來安裝 Kubernetes，在為 NCP 建置代管或多租戶環境時可能會面臨一些挑戰。BCM 不提供營運商和租戶角色之間的隔離。單一管理平面被同時用於叢集配置與租戶工作負載。BCM 託管的 Kubernetes 非常適合單租戶或專屬叢集。對於必須強制執行營運商和租戶邊界的代管使用場景，必須使用本文件[資料中心檢視 (Data Center View)](/dsx/ncp/software-reference-guide/data-center-architecture#data-center-view)章節中所描述的架構來指導部署選擇。

NVIDIA 提供了一個名為 [Cloud Native Stack (CNS)](https://github.com/NVIDIA/cloud-native-stack/) 的公開儲存庫，它會安裝 K8s 以及可搭配 NVIDIA GPU 運作的特定元件。這是在測試與概念驗證 (PoC) 環境中部署支援 AI 的 K8s 堆疊最簡單且最快速的方法之一。CNS 不建議用於生產環境中，但它可作為一個參考架構，列出所有經過共同驗證的元件。應將此 CNS 參考架構作為生產環境部署的規範說明。

## 動態資源分配 (Dynamic Resource Allocation, DRA)

Kubernetes (v1.34+) 管理需要虛擬化支援、驅動程式和共享能力的 GPU（帶有 RoCE 網卡）的分配。NVIDIA 技術（例如多執行個體 GPU (MIG) 和多程序服務 (MPS)）透過將單個實體 GPU 劃分為獨立的執行個體，進一步提高了 GPU 利用率，從而實現資源的高效共享。

## IMEX (多節點 NVLink)

Kubernetes 調度器正在演進以更好地支援 GPU 共享和多租戶，並具備用於遠端（非節點本機）資源的 API，例如透過 IMEX 存取的多節點 NVLink。IMEX 使 Kubernetes 能夠調度跨多個透過 NVLink (GB200 NVL72) 連接之節點的工作負載。這對於以下方面至關重要：

* 需要比單個節點提供更多 GPU 的大型模型訓練
* 具備 GPU 池化 (GPU pooling) 的解耦推論 (Disaggregated inference)
* 用於集體通訊運作且感知拓撲的成組排程 (Topology-aware gang scheduling)

在多租戶環境中，IMEX 需要 NMX-M 來進行 NVLink 分割區管理。

## GPU Operator

為了確保容器擁有所有必要的驅動程式、程式庫和執行期 (Runtimes)，NVIDIA 提供了 [GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/overview.html) 作為 K8s 框架的一部分，以簡化部署和生命週期管理。GPU Operator 是在 K8s 中將這些叢集與 NVCF 以及與之相關的 NIM 搭配使用的必要條件。

GPU Operator 可以由 Base Command Manager Essentials 在新叢集上自動安裝（《[容器化手冊第 4.3.2 節](https://support.brightcomputing.com/manuals/10/containerization-manual.pdf)》），或者在現有叢集上進行反應式安裝（《[容器化手冊第 4.3.3 節](https://support.brightcomputing.com/manuals/10/containerization-manual.pdf)》）。此 Operator 也可以使用傳統的 Kubernetes 方法（例如 [Helm charts](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/25.3.2/getting-started.html)）進行安裝。

## Container Toolkit

對於使用 Docker 進行編排的容器環境，NVIDIA® Container Toolkit 被用於最佳化容器部署以使用 GPU。NVIDIA Container Toolkit 使用傳統的 Linux 套件管理器進行[安裝](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)。

## Network Operator

NVIDIA Network Operator 簡化了 Kubernetes 叢集中 NVIDIA 網路資源的配置和管理。它為 RDMA、SR-IOV 和驅動程式管理提供[支援](https://docs.nvidia.com/networking/display/kubernetes2570/index.html#networking-features)。該 Network Operator 專門針對 [NVIDIA ConnectX®-6、NVIDIA® ConnectX®-7 和 NVIDIA® BlueField®](https://docs.nvidia.com/networking/display/kubernetes2570/platform-support.html) 系列網卡。

---

## 重點整理 (Key Takeaways)

1. **Kubernetes 部署與多租戶界限**
   * **BCM 安裝限制**：可利用 BCM Essentials 安裝與配置 CNI、Helm、kubeadm 等，但因其無營運商與租戶之間的權限隔離，僅適合單租戶或專屬叢集；多租戶代管應遵循「資料中心檢視」架構進行部署。
   * **CNS 測試框架**：NVIDIA **Cloud Native Stack (CNS)** 是 PoC/測試環境下快速安裝 GPU 最佳化 K8s 的首選參考架構，可作為生產配置的軟體相容規格指南。

2. **先進 GPU 共享與排程 (v1.34+)**
   * **DRA (動態資源分配)**：K8s 結合實體 GPU 虛擬化 (MIG/MPS) 在驅動層級進行細粒度資源配置與高效共享。
   * **IMEX (多節點 NVLink 調度)**：支援調度跨多個以 NVLink 直連節點 (GB200 NVL72) 的分散式任務。使大規模模型訓練、解耦 GPU 池化推論、以及拓撲感知成組排程成為可能。多租戶下需配合 NMX-M 管理。

3. **NVIDIA 容器與網路加速軟體**
   * **Container Toolkit**：使 Docker 等容器核心能夠直接存取實體 GPU 算力。
   * **GPU Operator**：自動化佈署核心驅動、運行時與裝置外掛程式，為 K8s 叢集運行 NIM 推論微服務或對接 NVCF 雲端函數的必備前置條件。
   * **Network Operator**：專為 ConnectX-6/7 與 BlueField DPU 設計，自動化配置與生命週期管理 RDMA、SR-IOV 等高速網路資源。
