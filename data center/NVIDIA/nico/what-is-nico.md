# 什麼是 NICo

NICo (NVIDIA Infra Controller) 是一個開源的微服務套件，用於站點本地 (site-local)、零信任的裸金屬生命週期管理。它能自動執行硬體探索、韌體驗證、DPU 配置、網路隔離和租戶清理 (tenant sanitization) — 協助 NVIDIA 雲端合作夥伴 (NCPs) 和基礎設施營運商建立並運作 AI 工廠級 (AI factory-scale) 的基礎設施。

NICo 採用 Apache 2.0 授權條款開源。

## 為什麼需要 NICo
AI 工廠級的基礎設施需要機櫃級 (rack-level) 管理、主機生命週期自動化和網路隔離，而現有的工具並未提供此類整合式解決方案。在缺乏專門構建的基礎設施管理下，營運商將面臨：

- 手動的硬體探索、韌體比對和網路設定，這會減慢機櫃上架的速度
- 無法在 Ethernet、InfiniBand 和 NVLink 上統一強制執行工作負載隔離
- 需使用自訂腳本進行租戶清理、認證與信任重建模組
- 混合硬體世代間的韌體與設定漂移

NICo 填補了這一空白 — 它讓實體伺服器能像雲端執行個體一樣運作：透過 API 來部署、管理和擴充裸金屬基礎設施。

## NICo 的功能
NICo 管理裸金屬主機的完整生命週期 — 從最初的機櫃探索，到租戶配置、持續營運和安全重複使用。

每台受管理的主機都是**配備一或多個 BlueField DPU 的主機伺服器**。連接的 DPU 作為網路隔離和安全性的強制界限；NICo 直接配置並管理它們，與主機上運行的內容無關。

NICo 的核心職責：

- 配置並管理 DPU OS、韌體和 HBN (主機架構網路) 設定
- 維護所有受管理主機的硬體清單 (Inventory)
- 透過 Redfish (頻外管理) 自動進行探索、驗證和認證 (Attestation)
- 持續監控硬體健康狀態並對健康狀態變化做出反應
- 管理主機韌體 (UEFI、BMC) 並強制執行安全鎖定 (Lockdown)
- 透過 Redfish管理每個裝置的 BMC 和 UEFI 憑證
- 分配 IP 位址、設定 BGP 路由和管理 DNS
- 在 Ethernet、InfiniBand 和 NVLink 平面上強制執行網路隔離
- 協調主機配置 (PXE/iPXE)、租戶釋放和清理

## 架構概述
![NICo 架構圖](https://files.buildwithfern.com/nvidia-ncx-infra-controller.docs.buildwithfern.com/infra-controller/32f21b066655bd35d46189c48e647e83b39fe241e105e63eddedb9b4ac50eb8d/_dot_dot_/docs/static/nico_arch_diagram.svg)

NICo 作為一組微服務部署在與其所管理資料中心共置的 Kubernetes 叢集上。這套微服務組成了控制面，稱為**站點控制器 (Site Controller)**。該 Kubernetes 叢集至少需要三個節點以實現高可用性，所有 NICo 控制面服務均透過 mTLS/gRPC 進行通訊。

架構圖中的綠色方塊是 NICo 提供的服務。

**站點控制器 (Site Controller) 服務：**

- **API 服務 (NICo Core)** — 中央控制面與單一真實來源 (Single Source of Truth)。所有其他 NICo 服務皆透過 mTLS/gRPC 與其通訊。它是唯一可讀寫 PostgreSQL 的服務。它實作了所有受管理資源 (主機、網路區段、InfiniBand 和 NVLink 分割區) 的狀態機。此外，它透過帶有 OIDC 認證的 HTTPS，在 `/admin` 上向營運商公開除錯網頁 UI。
- **DHCP 伺服器** — 回應所有底層 (Underlay) 裝置 (主機 BMC、DPU BMC、DPU 頻外 (OOB) 介面) 的 DHCP 請求。它是無狀態的 — 將 DHCP 請求轉換為向 API 服務發送的 gRPC 呼叫，由 API 服務執行實際的 IP 位址管理。
- **PXE 服務** — 透過 HTTP 向受管理的主機和 DPU 提供開機構件 (Boot Artifacts，如 iPXE 腳本、cloud-init 使用者資料、OS 映像檔)。透過 mTLS/gRPC 向 API 服務獲取每台主機的正確構件。
- **硬體健康監控 (Hardware Health)** — 透過 Redfish HTTPS 擷取主機和 DPU BMC 的感測器數據 (溫度、風扇速度、電壓、電流) 和韌體清單。在 Prometheus 的 `/metrics` 端點匯出指標，並透過 mTLS/gRPC 向 API 服務報告健康警報。
- **SSH 主控台服務 (SSH Console Service)** — 維持至所有主機 BMC 的持續 SSH/IPMI 連線，以進行序列主控台存取。將主控台輸出串流至 Loki 進行日誌記錄，並向租戶和管理員提供即時的主控台存取。透過 mTLS/gRPC 連接至 API 服務。
- **授權 DNS 服務 (Authoritative DNS Service)** — 處理來自站點控制器和受管理節點的 DNS 查詢。對 NICo 委派的區域具有授權。透過 mTLS/gRPC 連接至 API 服務。
- **遞迴 DNS (Recursive DNS, unbound)** — 透過頻外 (OOB) 網路向受管理的機器和租戶執行個體提供遞迴 DNS 解析。
- **站點代理 (Site Agent)** — 維持至 NICo REST (JSON API) 的 Temporal 連線，同步數據並將 gRPC 請求委派給本地的 API 服務。這使得 NICo REST 可以部署在雲端中央，而站點控制器則在本地端 (On-premises) 運作。
- **JSON API (NICo REST)** — 將 NICo 功能公開為 REST API，供營運商和獨立軟體廠商 (ISV) 使用。可與站點控制器共置部署，或集中部署在雲端。協調器和管理員透過 HTTP/JWT 連接。多個站點控制器可以透過其各自的站點代理，連接到單個 NICo REST 部署。
- **管理員 CLI (Admin CLI)** — 供站點管理員使用的命令列介面，透過 mTLS/gRPC 直接連接到 API 服務。

**受管理主機代理 (Managed Host Agents)：**

- **Scout** — 在探索階段 (指派租戶前) 運行於 x86 主機上的臨時代理。收集無法透過頻外管理確定的硬體清單，執行機器驗證測試，並透過 mTLS/gRPC 向 API 報告。
- **DPU 代理 (DPU Agent)** — 運行在 DPU (ARM OS) 上的常駐精靈。每 30 秒輪詢一次 API 服務以獲取所需的網路設定，並透過 HBN (基於主機的網路，使用容器化 Cumulus) 套用該設定，然後將觀察到的狀態回報。它還負責管理 DPU 健康檢查、元數據服務 (Metadata Service)、自動更新與熱修復 (Hotfix) 部署。
- **元數據服務 (Metadata Service, FMDS)** — 運行在 DPU 上。透過主機面向介面上的本地 HTTP API，向租戶工作負載提供執行個體元數據 (機器 ID、開機資訊)。
- **DHCP (DPU)** — 運行在 DPU 上的每主機 (Per-host) DHCP 伺服器。在本地處理所有主機 DHCP 請求，使主機的 DHCP 流量永遠不會到達底層網路。由 DPU 代理進行設定。

架構圖中的白色方塊是 NICo 依賴但非自行構建的現成服務。這些服務必須在安裝 NICo 之前部署。請參閱 [軟體先決條件](/infra-controller/documentation/getting-started/prerequisites/software) 以瞭解驗證過的版本與設定詳細資訊。

- **PostgreSQL** — 在 `nico_system_nico` 資料庫中儲存所有 NICo 系統狀態。只有 API 服務會對其進行讀寫。參考部署使用帶有 Spilo-15 的 Zalando Postgres Operator。
- **Vault** — 提供用於憑證核發的 PKI 引擎，以及用於認證資料儲存的 KV 機密引擎。由 API 服務和 credsmgr (cloud-cert-manager) 取用。使用 Kubernetes 認證來授權 NICo 服務帳戶。
- **Temporal** — 用於 NICo REST 執行多步驟操作 (執行個體配置、重開機、釋放) 的工作流程協調引擎。站點代理透過 Temporal 連接至 NICo REST。需要註冊命名空間：`cloud`、`site` 和每個站點的 UUID。
- **cert-manager** — 發行並輪替 NICo 服務在 mTLS/gRPC 通訊中所使用的 TLS 憑證。包含用於憑證請求授權的 approver-policy。
- **External Secrets Operator (ESO)** — 將 secrets 從 Vault 同步至 Kubernetes Secret 物件中，使認證資料 (資料庫、PKI、啟動引導資料) 可供每個命名空間中的 NICo 工作負載使用。
- **遙測與日誌記錄 (Telemetry and Logging - Prometheus, Grafana, OpenTelemetry, Loki)** — 收集所有 NICo 服務與受管理主機的指標和日誌。Prometheus 擷取硬體健康的 `/metrics` 端點。Loki 聚合來自 SSH 主控台服務與 DPU 代理的日誌。OpenTelemetry Collector 傳送來自站點控制器和 DPU 的遙測數據。此為選用項目，但強烈建議安裝。
- **MetalLB** — 在 Kubernetes 叢集上為 NICo 服務提供負載平衡的虛擬 IP (VIP)，使其可從底層網路連通。
- **ArgoCD** — 用於部署與更新 NICo 元件的 GitOps 持續交付工具。選用。
- **NGC 登錄表 (NGC Registry)** — NVIDIA 的容器登錄表，用於在部署和升級期間拉取 NICo 服務映像檔。
- **IDP (KeyCloak)** — 用於管理員網頁 UI 透過 OIDC 進行認證的身分識別提供者。選用。

若要深入瞭解每個元件和狀態機設計，請參閱 [架構：概述與元件](/infra-controller/documentation/architecture/overview-and-components)。

NICo 位於 Kubernetes 和平台層之下。它公開了 REST 和 gRPC API，供更高層級的系統 (如 BMaaS、VMaaS、協調引擎、ISV 控制面) 直接取用。它不干涉其上方的排程、租戶政策或工作負載管理。

```
┌─────────────────────────────────────┐
│   ISV / NCP 控制面 (Control Plane)  │
├─────────────────────────────────────┤
│   Kubernetes / BMaaS / VMaaS        │
├─────────────────────────────────────┤
│   NICo  ◄── 你在此處                │
├─────────────────────────────────────┤
│   BlueField DPU + 主機硬體          │
└─────────────────────────────────────┘
```

NICo 是使硬體具備可預測性、可重複性和安全性的關鍵層 — 讓上層系統能將裸金屬視為可靠的建置組塊。

## 總結

### NICo (NVIDIA Infra Controller) 重點整理

#### 1. 什麼是 NICo？
* **定義**：NICo 是一個開源（Apache 2.0 授權）的微服務套件，專為**站點本地（site-local）**和**零信任（zero-trust）的裸金屬（bare-metal）生命週期管理**所設計。
* **主要目標**：協助 NVIDIA 雲端合作夥伴（NCPs）和基礎設施營運商，建立並操作 AI 工廠級（AI factory-scale）的基礎設施。

#### 2. 解決的痛點（為何需要 NICo）
傳統基礎設施管理缺乏整合工具，營運商常面臨：
* 手動硬體探索、韌體比對及網路設定，拖慢機櫃上架速度。
* 無法在 Ethernet、InfiniBand 和 NVLink 上統一強制隔離工作負載。
* 需依賴自訂腳本進行租戶清理（Tenant Sanitization）、認證與信任重建。
* 不同世代硬體間容易產生韌體與設定漂移。
* **NICo 的價值**：讓實體伺服器能像雲端執行個體（Cloud Instances）一樣，完全透過 API 進行部署、管理與擴充。

#### 3. 核心功能與職責
NICo 管理裸金屬主機（配備一或多個 **BlueField DPU**）的完整生命週期：
* **安全隔離**：將 DPU 作為安全與網路隔離的強制界限，獨立於主機上運行的工作負載。
* **自動化管理**：透過 Redfish（頻外管理）自動探索硬體、驗證、監控健康狀態、管理 BMC/UEFI 憑證，並強制執行安全鎖定。
* **網路配置**：分配 IP 位址、配置 BGP 路由、管理 DNS，並在 Ethernet、InfiniBand 與 NVLink 平面執行網路隔離。
* **佈署與回收**：協調主機配置（PXE/iPXE）以及租戶釋放後的硬體清理與重置。

#### 4. 架構與元件組成
NICo 部署在資料中心本地的 Kubernetes 叢集上（至少 3 節點以達高可用性），內部元件均透過 **mTLS/gRPC** 通訊：
* **控制面（Site Controller）服務**：
  * **API Service (NICo Core)**：控制面核心，唯一讀寫 PostgreSQL 的服務，實作狀態機。
  * **DHCP / PXE / DNS 服務**：處理底層設備的 DHCP 請求、分發開機構件（iPXE 腳本、OS 映像檔）與 DNS 解析。
  * **Hardware Health**：透過 Redfish 擷取感測器數據並導出 Prometheus 指標。
  * **SSH Console**：維持與主機 BMC 的持續連線，並將日誌串流至 Loki。
  * **Site Agent & JSON API**：將本地控制面與雲端中央的 REST API 對接。
* **受管理主機代理（Host Agents）**：
  * **Scout**：主機探索階段（指派租戶前）在 x86 主機運行的臨時代理，用以收集硬體清單並執行驗證。
  * **DPU Agent**：運行在 DPU（ARM OS）的常駐精靈，負責設定 HBN 網路、健康檢查及熱修復部署。
  * **Metadata Service (FMDS) & DPU DHCP**：向租戶提供執行個體元數據，並在本地處理主機的 DHCP 請求。
* **外部依賴**：整合了開源成熟技術，如 PostgreSQL (Zalando)、Vault (秘密/憑證管理)、Temporal (工作流編排)、cert-manager、ESO、Prometheus/Loki/OpenTelemetry (遙測) 與 MetalLB (VIP)。

#### 5. 系統所處層級
* **分層關係**：
  ```text
  ┌─────────────────────────────────────┐
  │   ISV / NCP 控制面 (Control Plane)  │
  ├─────────────────────────────────────┤
  │   Kubernetes / BMaaS / VMaaS        │
  ├─────────────────────────────────────┤
  │   NICo  ◄── 位於此層                │
  ├─────────────────────────────────────┤
  │   BlueField DPU + 主機硬體          │
  └─────────────────────────────────────┘
  ```
* NICo 位於 Kubernetes 與平台層（BMaaS / VMaaS）之下、實體硬體與 DPU 之上。它將複雜的底層硬體轉化為可預測、可重複且安全的「可靠建置組塊」，但不干涉上層的調度、租戶政策或工作負載管理。
