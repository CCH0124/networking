# Container-as-a-Service

## Kubernetes

[Kubernetes](https://kubernetes.io/) (K8s) 被用作工作負載編排引擎，而本參考架構 (RA) 即是圍繞著 K8s 架構所建置。

Kubernetes 是一個容器編排工具，由於其靈活性和可擴充性，它已成為大規模營運雲端環境的業界事實標準。正如雲端原生運算基金會 (CNCF) 所定義的，雲端原生技術使企業組織能夠在現代、動態的環境中使用容器、服務網格 (Service meshes)、微服務、不可變基礎設施以及宣告式 API 來運行可擴充的應用程式。這種方法帶來了具備彈性、易於管理和可觀測的系統，以極低的維運開銷促進了可預測的適應性。對於 AI 基礎設施供應商而言，Kubernetes 提供了能夠支持機器學習 (ML)/AI 推論與訓練工作負載所要求的嚴苛規模之基礎抽象。

當 AI 模型使用符合開放容器倡議 (OCI) 標準（例如 NVIDIA 的可延伸推論微服務 NIM）打包成容器時，Kubernetes 會被同時用於這些模型的訓練與部署。容器化對於 AI 工作負載尤為重要，因為不同的模型需要不同且可能存在衝突的依賴項，因此在容器內隔離這些依賴項能為模型部署提供極大靈活性。

預設的 K8s 使用 `containerd` 執行期 (Runtime) 進行容器編排。營運商可以進一步選擇支援一種部署選項，即在專屬實體主機的專屬節點上運行某些可能需要最嚴格隔離的工作負載。

租戶的 K8s 叢集被配置為從該租戶擁有存取權限的 NVIDIA NGC™ 容器登錄庫 (Container Registry) 中檢索程式碼和資料。為此，租戶會在營運商的 K8s 叢集佈署過程中，提供其 NVIDIA AI Enterprise 的存取憑證。

對於 Kubernetes 或 CaaS 方案，可以有三種形式：

* **NCP 託管式 K8s (NCP-managed K8s)**：NCP 為每個租戶營運一個專屬的 K8s 叢集，負責處理控制平面的生命週期、升級和擴充。租戶會收到 kubeconfig 以存取其叢集。
* **ISV 託管式 K8s (ISV-managed K8s)**：由 ISV 管理平台在雲端原生佈署的基礎設施或由 NVIDIA Infra Controller 管理的基礎設施上配置與管理 K8s 叢集。ISV 處理多租戶編排，並提供營運商和租戶入口網站。
* **租戶自管式 K8s (Tenant-managed K8s)**：NCP 提供裸機或虛擬機，由租戶自行安裝並管理其 K8s 叢集。此模型提供了最大的靈活性，但將維運負擔轉移給了租戶。

Kubernetes 滿足了 GPU 服務供應商的兩個主要使用場景：

* **託管利用自訂資源定義 (CRD) 進行 API 延伸的 K8s 原生控制平面**：營運商可以利用 CRD 來管理服務以延伸 Kubernetes 的功能。SDN 和 SDS 控制器通常由 K8s 原生控制平面託管。整體的編排應採用專屬的單租戶 K8s 叢集，或類似且符合使用場景的隔離機制。
* **託管具備可觀測性、可服務性且安全的 GPU 工作負載（訓練與推論）**：
  * **可觀測性 (Observability)**：雲端原生工具（如 OpenTelemetry 和 Prometheus）對於監控負載、存取率、回應延遲和模型效能至關重要，可用以檢測模型漂移 (Drift) 並確保可靠性。
  * **可服務性 (Serviceability)**（節點健康檢測與故障修復）：Kubernetes 節點以 `Unschedulable=false` 狀態運作以表示就緒。NCP 預期需要支持故障修復 (Break-fix) 程序與備品 (Sparing) 策略，不論是針對單個 GPU 節點還是整個機櫃級的故障領域 (Fault domains)。
  * **安全性 (Security)**（DevSecOps 與策略執行）：將 AI 模型作為 OCI 產出物進行容器化，可以實現軟體供應鏈的最佳實踐，包括產出物簽章、驗證和證明 (Attestation)。像 Kyverno 這樣的策略執行工具可確保容器化工作負載以最小權限運行，並符合安全策略。

Kubernetes 運行在由基礎設施 (IaaS) 層所配置的運算資源之上。對於託管式 K8s 方案，NCP 或 ISV 營運 K8s 控制平面，並向租戶提供其專屬叢集的 kubeconfig 存取權。

### 所需能力 (Capabilities Required)

經 GPU 優化的託管式 Kubernetes 具備以下能力：

* 抽象化 K8s 控制平面 (CP) 節點，使雲端消費者僅需指定 K8s 控制平面所需的高可用性 (HA) 和/或可擴充性即可。
* 支援 K8s 版本 1.34 或更高版本，這能啟用動態資源分配 (Dynamic Resource Allocation, DRA) 以實現靈活的 GPU 共享與分配，並支援機櫃級 GPU 叢集中的 IMEX (Instant Messaging and Elastic eXchange / 跨節點 NVLink 互連技術)。
* 允許雲端消費者攜帶其自備的 GPU 優化節點作業系統 (OS)，或提供與其他託管服務整合的作業系統。
* 支援託管節點組 (Managed-node groups) 和/或叢集節點自動擴充（例如 Karpenter.sh）。
* 提供針對雲端供應商的儲存與網路服務進行優化的業界標準儲存 (CSI) 和網路 (CNI) 整合。
* 支援軌道對齊 (Rail-aligned) 叢集中國客端 (Worker) 節點的拓撲搜尋 (Topology discovery)。這為分散式訓練與解耦推論 (Disaggregated inference) 工作負載啟用了感知拓撲的成組排程 (Gang-scheduling)。
* 與雲端原生運算基金會 (CNCF) 保持一致，具體包括：
  * 符合 CNCF 對 K8s 發行版的認證。
  * 符合 CNCF 新興的雲端原生 AI (Cloud Native AI) 一致性倡密。

### K8s 原生 ML/AI 框架與工具 (K8s-Native ML/AI Frameworks and Tools)

[NVIDIA AI Enterprise](https://docs.nvidia.com/ai-enterprise/index.html) 是用於 MLOps 和代理型 (Agentic) 應用程式的雲端原生 AI (CNAI) 工具之最佳範例，它利用了宣告式 API、可組合性與可移植性等 Kubernetes 原則。它為 ML 生命週期的每個階段實作了獨立的微服務，使用如用於分散式訓練的 Kubeflow Training Operator，以及 K8s 原生的 Dynamo 用於模型提供 (Serving)。

為了實現高效的 ML/AI，進階調度支援正在透過 NVIDIA KAI 和 Grove 等專案不斷演進。KEDA (Kubernetes Event Driven Autoscaling) 非常適合用於事件驅動的託管，能最佳化資源使用率並降低成本。此外，通用型分散式運算引擎（如 Ray）搭配 KubeRay 提供了統一的 ML 平台，透過專注於運算來補充雲端原生生態系統，並與 Kubernetes 社群廣泛合作以提升生產環境中的 ML 管線 (Pipeline) 效能並大幅降低推論成本。JupyterLab 與 Kubernetes 的整合讓 AI 從業者能在熟悉的環境中更快速地進行迭代，從而抽象化了複雜的 Kubernetes 細節。

### 適用於 ML/AI 的 Kubernetes 架構 (Kubernetes Architecture for ML/AI)

Kubernetes 用於 ML/AI 的架構優勢在於其能夠高效編排複雜的分散式工作流程。GPU 服務供應商必須支援生成式 AI 的獨特需求，這需要來自專用硬體的極高運算能力、用於訓練的海量且多樣化的資料集、複雜的迭代訓練，以及用於模型服務的高可擴充性與彈性的基礎設施。

動態資源分配 (DRA) 在 K8s v1.34 中已成為正式發佈 (GA) 的 API，為管理專用硬體提供了更大的靈活性。

Kubernetes 管理需要虛擬化支援、驅動程式和共享能力的 GPU（帶有 RoCE 網卡）的分配。NVIDIA® 技術（例如多執行個體 GPU (MIG) 和多程序服務 (MPS)）透過將單個實體 GPU 劃分為獨立的執行個體，進一步提高了 GPU 利用率，從而實現資源的高效共享。為了獲得最佳的成本控制與永續性，最佳資源大小調整與反應式調度 (Reactive scheduling) 至關重要，特別是對於昂貴且競爭激烈的 GPU 加速器。

Kubernetes 調度器正在演進以更好地支援 GPU 共享和多租戶，並具備用於遠端（非節點本機）資源的 API，例如透過 IMEX 存取的多節點 NVLink (Multi-Node NVLink)。

高效能儲存對於生成式 AI 至關重要，負責處理多樣化的資料類型並提供低延遲存取。高頻寬與低延遲網路對於分散式訓練期間的資料傳輸和模型同步至關重要。Kubernetes 容器儲存 (CSI) 和網路 (CNI) 介面提供了標準介面來抽象化整合。

透過擁抱 Kubernetes，CSP 和 NCP 可以提供一個強大、可擴充且具成本效益的平台，以應對 ML/AI 領域獨特且不斷變化的需求，從而在競爭激烈的市場中提供策略優勢。

## 適用於容器即服務的 NVIDIA 軟體 (NVIDIA Software for Container-as-a-Service)

NVIDIA 提供容器工具與 Kubernetes Operator 來啟用 GPU 工作負載：

### 容器平台 (Container Platform)

[NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/index.html) 是一系列程式庫和公用程式的集合，使用戶能夠建置和運行 GPU 加加速的容器。它為容器化環境中的 GPU 存取提供了基礎。

### Kubernetes Operators

NVIDIA 提供 Kubernetes Operators，透過自訂資源定義 (CRD) 來延伸叢集功能：

**NVIDIA Kubernetes Operators**

| Kubernetes Operators | 功能 (Function) |
| -------------------- | --------------------------------------------------------------------------------------------------------------- |
| GPU Operator         | 自動化 GPU 驅動程式、執行期 (Runtime) 以及裝置外掛程式 (Device plugin) 的佈署 |
| Network Operator     | 配置 RDMA、SR-IOV 和 GPUDirect 網路資源 |
| DPU Operator         | 管理 BlueField DPU 的生命週期、韌體以及 DOCA 執行期。與 Network Operator 協調 DPU 的佈署 |
| NIM Operator         | 自動化佈署與管理用於生成式 AI 推論工作負載的 NVIDIA NIM™ 微服務生命週期 |

這些 Operator 啟用了 Kubernetes 原生功能，例如用於 GPU 共享的動態資源分配 (DRA) 以及用於多節點 NVLink 調度的 IMEX。有關每個元件的詳細描述，請參閱 [第二部分：適用於容器即服務的 NVIDIA 軟體](/dsx/ncp/part-2-software-components/nvidia-software-for-container-as-a-service)。

---

## 重點整理 (Key Takeaways)

1. **Kubernetes 作為 AI 編排核心**
   * Kubernetes (K8s) 是本架構的工作負載編排引擎。透過容器化（符合 OCI 標準，如 NVIDIA NIM）隔離不同 AI 模型的依賴項，從而消除相依性衝突，提供高度靈活的模型佈署。

2. **CaaS 的三種維運模式**
   * **NCP 託管式 K8s**：NCP 負責控制平面生命週期、升級與自動擴充，向租戶提供 kubeconfig 存取。
   * **ISV 託管式 K8s**：ISV 在 IaaS 基礎設施或由 NVIDIA Infra Controller 管理的底座上配置叢集，並提供雙端入口網站。
   * **租戶自管式 K8s**：NCP 僅提供裸機/VM，租戶自行安裝與管理，靈活性最大但維運成本最高。

3. **GPU 優化 K8s 必備能力 (K8s v1.34+)**
   * 啟用 **DRA (動態資源分配)** 與 **IMEX (跨節點多主機 NVLink 互連)** 實現彈性 GPU 共享與排程。
   * 支援託管節點組與 Karpenter 等自動擴充工具。
   * 支援軌道對齊 (Rail-aligned) 的拓撲搜尋，為分散式訓練與解耦推論工作負載啟用感知拓撲的成組排程 (Gang-scheduling)。
   * 支援雲端原生 AI (CNCF CNAI) 一致性規範。

4. **NVIDIA 容器與 Operators 軟體堆疊**
   * **NVIDIA Container Toolkit**：為容器環境中直接存取 GPU 算力提供底層程式庫。
   * **GPU Operator**：自動化佈署 GPU 驅動程式、容器執行期及裝置外掛。
   * **Network Operator**：動態配置 RDMA、SR-IOV 與 GPUDirect 網路加速資源。
   * **DPU Operator**：負責 BlueField DPU 韌體生命週期與 DOCA 執行期管理，並與 Network Operator 協調。
   * **NIM Operator**：自動化佈署與管理用於生成式 AI 推論工作負載的 NVIDIA NIM™ 微服務生命週期。
