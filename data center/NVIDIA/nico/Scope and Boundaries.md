# Scope and Boundaries (範圍與邊界)

NICo 負責管理基礎設施生命週期層：硬體發現、韌體管理、DPU 資源建置、網路隔離以及租戶淨化。任何高於啟動移交（Boot handoff）以及低於實體網路底層（Physical network underlay）之處，皆超出 NICo 的管理範圍。

本頁面定義了 NICo 與其上層平台、協調（Orchestration）或自動化層之間的邊界 —— 讓營運人員與整合人員能瞭解哪些是由 NICo 處理，哪些是他們自己的軟體所需要涵蓋的。

---

## 主機作業系統與應用程式層 (Host OS and Application Layer)

| NICo 處理的部分 | 你的平台處理的部分 |
|---|---|
| 透過 PXE/iPXE 進行 OS 映像檔交付 | OS 修補、升級與執行階段組態設定 |
| UEFI 啟動順序與安全啟動（Secure Boot）設定 | 應用軟體（Kubernetes、SLURM、儲存裝置） |
| 接入時及租戶移轉間的主機證明（Attestation） | 租戶使用期間的頻內（In-band）監控與代理程式 |

NICo 負責建置作業系統並在開機時完成移交。在租戶使用期間，NICo 不會在主機 OS 內部執行任何代理程式或精靈（Daemon），也不會持續對主機進行證明 —— 證明僅在接入（Ingestion）時與租戶移轉（Tenant transition）之間發生。

---

## 叢集組裝與工作負載排程 (Cluster Assembly and Workload Scheduling)

| NICo 處理的部分 | 你的平台處理的部分 |
|---|---|
| 個別主機的資源建置與生命週期管理 | 將主機組裝至叢集中（SLURM、K8s） |
| 透過 API 定義執行個體類型與進行主機分配 | 工作負載排程與資源分配 |
| 每個租戶的網路隔離 | 叢集網路（CNI、服務網格/Service Mesh） |

NICo 負責建置主機，並透過 API 將其作為執行個體（Instance）分配給租戶。將這些主機建立為可正常運作的叢集 —— 安裝 Kubernetes、設定 SLURM、部署工作負載 —— 是由取用 NICo API 的獨立軟體開發商（ISV）控制平面、裸金屬即服務（BMaaS）層或協調系統負責。

---

## 網路底層 (Network Underlay)

| NICo 處理的部分 | 你的網路團隊處理的部分 |
|---|---|
| DPU 層的租戶隔離（透過 HBN 的乙太網路） | 葉端交換器（Leaf switch）、脊端交換器（Spine switch）與路由器組態設定 |
| 透過 UFM API 進行 InfiniBand 分區分配 | UFM 部署與管理 |
| 透過 NMX-M API 進行 NVLink 分區管理 | NMX-M 部署與管理 |
| 來自 DPU 的 BGP 路由宣告 | 實體底層（Underlay）設計與佈線 |

NICo 執行隔離而無須重新設定實體交換器 —— 實體底層網路預期是穩定且預先配置完成的。*NICo 不會在交換器上安裝或管理 Cumulus Linux*，亦不管理 UFM 或 NetQ 等網路可觀測性工具。

---

## 外部依賴項 (External Dependencies)

NICo 依賴數個必須預先部署且在外部進行管理的服務。NICo 與這些服務協調配合，但並不負責安裝、設定或運行它們。如需包含設定詳細資訊的完整清單，請參閱 [Prerequisite Components](https://docs.nvidia.com/infra-controller/documentation/overview/what-is-nico#prerequisite-components)。

---

## 重點整理 (Key Takeaways)

1. **主機與應用層邊界（開機即移交）**：NICo 只負責引導作業系統映像檔（透過 PXE/iPXE）與基礎開機設定（如 UEFI），不干涉作業系統啟動後的執行階段組態（如修補升級）、應用軟體堆疊（如 Kubernetes, SLURM）及頻內監控。
2. **叢集與排程邊界（專注於單機生命週期）**：NICo 本質上是管理單一主機的生命週期並提供租戶網路隔離 API，更高階的叢集組建和任務排程由上層的控制平面或 BMaaS 系統呼叫 NICo API 來實現。
3. **實體網路底層邊界（底層需預先配置）**：NICo 是在 DPU 層（透過 HBN）執行網路隔離並傳遞 BGP 路由，不負責設定實體交換器（Leaf/Spine）與物理路由器，也不直接管理 Cumulus Linux 開關、UFM 或網路遙測工具（如 NetQ）。
4. **依賴外部元件**：NICo 的運作高度依賴於預先部署的外部基礎設施服務（如 NMX-M、UFM 等），NICo 負責與其串接和協調，而非直接部署或經營這些依賴元件。
