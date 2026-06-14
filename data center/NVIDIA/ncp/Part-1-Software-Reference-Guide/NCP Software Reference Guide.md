# NCP Software Reference Guide

NCP 軟體參考指南引入了在 NCP 硬體參考設計 (NCP Hardware RA) 之上實作 AI 服務的分層架構概念。此抽象分層架構可以拆分為兩種視角：**租戶運算視角 (Tenant Compute View)** 以及 **營運商視角 (Operator View)**。

## 租戶運算視角 (Tenant Compute View)

租戶所消耗的運算資源可以拆分為以下抽象層級，如「租戶運算視角」架構圖所示。

![租戶運算視角的軟體參考架構](https://files.buildwithfern.com/nvidia-dsx.docs.buildwithfern.com/dsx/89395a298ab80c6c3e5fde1637937103c46bd3ac156de5240a188763f5bae9e4/_dot_dot_/docs/ncp/software-reference-guide/assets/images/ncp-srg-tenant-view.png)

* **基礎設施即服務 (IaaS, Infrastructure-as-a-Service)**：此層負責提供裸機 (Bare Metal, BM) 與虛擬主機 (Virtual Machine, VM) 作為可消耗的基礎設施。為了實現動態資源分配，此服務會響應 UI 或 API 呼叫，為租戶建立隔離且經過清理消毒 (Sanitized) 的基礎設施。
* **容器即服務 (CaaS, Container-as-a-Service)**：這是建置在 IaaS 層之上的託管式 Kubernetes (K8s) 層，為終端使用者提供 K8s 的所有優勢（例如：擴充性、模組化、API 驅動、自動擴充、簡化的調度），同時提供託管服務的維運抽象化與自動化。此 CaaS 層可以被解耦並獨立提供，或者作為 NCP 整合式平台解決方案的一部分。
* **AI 平台即服務 (PaaS, AI Platform-as-a-Service)**：這是啟用基於 GPU 的 AI 工作負載之主要應用程式。雖然 Slurm 目前廣泛用於訓練和高效能運算 (HPC) 場景，但越來越多的組織正遷移至其他適合模型開發、推論和訓練的雲端原生 AI 平台（例如 Run.AI 以及許多其他業界平台）。
* **Slurm**：Slurm 雖然不是雲端原生的 AI PaaS，但它是眾所皆知的單租戶 AI 平台，特別適用於 HPC 和模型訓練任務。在執行 Slurm 時，NCP 可以選擇使用開源版本，或者使用針對 NVIDIA GPU 進行深度優化的 NVIDIA® BCM Slurm。
* **輔助運算/原生工作負載 (Ancillary compute/Native workloads)**：這些是資料中心核心/輔助服務中可用的通用運算伺服器。這些工作負載（例如：商業邏輯、負載平衡器、資料庫服務）必須被 NCP 軟體堆疊視為第一等公民 (First-class citizens) 來提供服務。

## 營運商視角 (Operator View)

預期用於運行 **AI 工作負載執行 (AI workload execution)** 以及 **控制與管理 (Control & Management)** 堆疊之服務與功能的通用檢視圖如下所示：

![營運商視角的軟體參考架構](https://files.buildwithfern.com/nvidia-dsx.docs.buildwithfern.com/dsx/36cfd18e2d4da35bedf48e411b03e7c66d11978cab032afef2d77cd547db6799/_dot_dot_/docs/ncp/software-reference-guide/assets/images/ncp-srg-operator-view.png)

其中幾項服務是 NCP 軟體參考指南的關鍵技術，例如軟體定義網路 (SDN) 控制器和 AI 平台控制平面，稍後將在本文件中進行討論。

此營運商視角展示了軟體參考架構中每一層所提供之核心能力。

---

## 重點整理 (Key Takeaways)

1. **雙重架構視角 (Two Structural Views)**
   * **租戶運算視角 (Tenant Compute View)**：面向終端租戶，由下至上劃分為基礎設施服務 (IaaS)、容器編排服務 (CaaS)、AI 平台服務 (PaaS/Slurm) 以及輔助通用運算。
   * **營運商視角 (Operator View)**：面向基礎設施管理，劃分為「AI 工作負載執行」與「控制與管理」兩大系統堆疊。

2. **租戶運算層級核心功能**
   * **IaaS 層 (基礎設施)**：透過自動化回應 API/UI，動態建立隔離且乾淨的裸機或虛擬機環境。
   * **CaaS 層 (容器)**：提供託管型 Kubernetes，簡化容器編排與調度複雜度，支援自動擴充。
   * **AI PaaS 層 (AI 平台)**：核心是使 GPU 算力可供 AI 工作負載使用。除了傳統排程器 Slurm 外，更強調向雲端原生 AI 平台 (如 Run.AI) 遷移。
   * **輔助運算層 (非 GPU 工作負載)**：資料庫、業務邏輯及負載平衡器等輔助伺服器也是不可或缺的，必須在軟體堆疊中被視為第一等公民進行整合。

3. **營運商維運核心**
   * 包含軟體定義網路 (SDN) 控制器、控制/管理平面以及監控遙測系統，是支撐多租戶安全隔離與動態資源彈性分配的底座。
