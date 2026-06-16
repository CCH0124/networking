# NVIDIA Software References for AI Platform

## Run:ai

AI 團隊常面臨有限的 GPU 資源競爭。訓練任務可能需要運行數小時或數天，這使得 GPU 在每次運行之間處於閒置狀態。資料科學家在排隊等待，而昂貴的 GPU 卻未被充分利用。企業組織需要一種在確保各團隊與專案之間公平分配資源的同時，最大化 GPU 利用率的方法。

[Run:ai](https://run-ai-docs.nvidia.com/) 是一款 AI 基礎設施編排平台，旨在幫助最大化 AI 開發環境中運算資源（特別是 GPU）的利用率。它作為 K8s 之上的一個圖層運作，為管理 AI 工作負載和研究實驗提供專門的功能。Run:ai 作為 [K8s Operator 安裝](https://docs.run.ai/v2.20/home/components/)在現有的 K8s 基礎設施之上。

該平台的核心功能包括動態資源分配，可以根據工作負載需求進行 GPU 資源的分段式 (Fractional) 共享或彙整。這使企業組織能夠藉由根據優先順序和需求在不同團隊和專案之間自動重新分配運算資源，來最佳化其硬體利用率。例如，當一個團隊的訓練任務完成時，這些 GPU 可以立即重新分配給另一個團隊的待處理工作負載。

Run:ai 還提供了進階的佇列 (Queuing) 與排程機制，以處理跨分散式基礎設施管理多個 AI 工作負載的複雜度。它包含用於實驗管理的功能（協助資料科學家追蹤與管理其訓練過程），並提供監控資源使用率、任務進度和系統效能的工具。該平台與常見的機器學習 (ML) 框架與開發工具整合，在支援互動式開發工作階段 (Sessions) 與生產環境訓練任務的同時，維持不同使用者與團隊之間的隔離和資源保證。

Run:ai 與常見的 ML 框架（PyTorch、TensorFlow）和開發工具（JupyterLab、VS Code）整合，支援互動式開發工作階段與生產環境訓練任務。

## NVCF

大規模的 AI 推論帶來了獨特的挑戰。模型必須跨分散式 GPU 基礎設施進行部署、處理多變的請求負載，並在高效率擴充的同時避免過度配置昂貴的 GPU 資源。開發人員需要專注於模型邏輯，而非基礎設施管理。

[NVIDIA 雲端函數 (NVIDIA Cloud Functions, NVCF)](https://docs.nvidia.com/cloud-functions/user-guide/latest/cloud-function/overview.html) 是一個無伺服器 (Serverless) 推論平台，能夠將 AI 模型部署為可擴充的 API 端點。NVCF 抽象化了 GPU 基礎設施管理，允許開發人員部署容器化模型並自動獲得自動擴充、負載平衡與 GPU 編排服務。

NVCF 註冊已配置 Kubernetes 作為編排層的叢集後端。NVCF 要求在運算節點上安裝 K8s。

NVCF 使用安裝在已安裝 K8s 運算節點之上的叢集代理程式 (Cluster agent)。該叢集代理程式有兩個用途：

1. 與 NVCF API 雲端服務進行通訊，以將該節點註冊為 NVCF 後端目標。
2. 與 K8s 進行互動，以將 AI 工作負載作為來自 NVCF 編排的目標部署至 GPU 叢集上。

本文件不強制要求使用 NVCF，但 NVCF 是 NVIDIA 的解決方案，可簡化叢集上 AI 工作負載的編排。

## Slurm

Slurm (Simple Linux Utility for Resource Management) 是一款廣泛採用的工作負載管理器，用於 HPC 和大規模 AI 訓練工作負載。雖然 Slurm 不是雲端原生解決方案，但由於其成熟的任務佇列、優先級劃分與資源排程能力，它仍然是專屬訓練任務的關鍵技術。它是許多超級電腦和研究叢集的骨幹。

對於服務擁有大規模訓練工作負載客戶的 NCP，Slurm 提供了一個經證實的單租戶部署模型，可最大化長時間運行之分散式訓練任務的 GPU 利用率。

NCP 可以部署開源版本的 Slurm 或 [NVIDIA 的 BCM Slurm](https://docs.nvidia.com/mission-control/docs/systems-administration-guide/2.0.0/slurm-workload-management.html)，後者針對 NVIDIA GPU 基礎設施進行了最佳化。BCM Slurm 包括：

1. 與 NVIDIA GPU 和高速互連的預配置整合。
2. 支援多節點 NVLink 和 InfiniBand 織網。
3. 具備 GPU 感知能力 (GPU-aware) 的排程與資源分配。
4. 與 NVIDIA 軟體堆疊（驅動程式、NCCL、cuDNN）整合。

## NeMo

NVIDIA NeMo™ 是一款全方位軟體套件，用於在 AI 代理 (AI agents) 的整個生命週期中對其進行建置、監控與最佳化。與僅解決模型訓練或推論的單點解決方案與功能不同，NeMo 提供了一個整合平台，涵蓋從資料準備到生產環境最佳化的完整過程。欲了解更多資訊，請參閱 [NeMo 框架 (NeMo Framework)](https://docs.nvidia.com/nemo-framework/user-guide/latest/overview.html) 說明文件。

NCP 可以將 NeMo 作為 AI 開發平台的一部分提供，使租戶能夠：

* 準備企業資料 —— 清理、過濾和策劃來自租戶來源的多模態資料集。
* 自訂基礎模型 —— 微調模型並使其與領域特定知識對齊。
* 建置 RAG 管線 —— 將 AI 回應立足 (Ground) 於租戶知識庫和文件中。
* 執行護欄 (Guardrails) —— 對 AI 輸出套用安全性、合規性與內容策略。
* 持續改進 —— 評估代理效能並套用增強學習 (Reinforcement learning)。

NeMo 元件以容器形式提供，可以部署在 Kubernetes 或裸機基礎設施上。NCP 可以將 NeMo 整合到其 AI 平台產品中，為租戶提供對模型自訂和代理開發能力的自助服務存取。

---

## 重點整理 (Key Takeaways)

1. **Run:ai (多租戶 GPU 資源編排)**
   * 作為 K8s Operator 運行，用以最大化開發與訓練環境中的 GPU 利用率。
   * **動態分配**：支援 GPU 資源的分段式 (Fractional) 共享，依優先級與需求自動在專案和團隊間調配與回收閒置算力。
   * 提供進階任務佇列、排程、與實驗追蹤，並與 PyTorch、VS Code、JupyterLab 等主流 AI 工具鏈無縫整合。

2. **NVCF (NVIDIA 雲端函數 / Serverless AI 推論)**
   * 無伺服器推論平台，將 AI 模型包裝成具備自動擴充、負載平衡及 GPU 編排的 API 端點，使開發者能專注於模型邏輯。
   * 透過在 Kubernetes 節點部署 Cluster Agent，向雲端 NVCF 註冊並接受編排調度。

3. **Slurm (大規模訓練資源管理器)**
   * HPC 和大規模 AI 分散式訓練的經典調度工具，提供單租戶部署模型，適合長時間、超大規模的訓練任務。
   * **NVIDIA BCM Slurm** 針對 InfiniBand、多節點 NVLink 及 GPU 感知排程做專屬優化，且預先整合了 NVIDIA 驅動程式、NCCL 與 cuDNN。

4. **NeMo (AI 代理全生命週期套件)**
   * 端到端 AI 開發平台，涵蓋資料準備、基礎模型微調、RAG (檢索增強生成) 管道建立、安全防護與內容策略護欄執行、以及強化學習評估。
   * 以容器形式提供，可靈活運行於 Kubernetes 或裸機環境。
