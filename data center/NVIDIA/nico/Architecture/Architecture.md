# Architecture (架構)

本頁面討論運行 NVIDIA Infra Controller (NICo) 站點的高階架構。

NICo 透過一組協作的控制平面服務，來協調整合「[受控主機](#受控主機-managed-hosts)」與其他資源的生命週期。這些控制平面服務必須部署在一個至少包含 3 個節點的 Kubernetes 叢集上（以實現高可用性）。

![NICo 架構圖](https://files.buildwithfern.com/nvidia-ncx-infra-controller.docs.buildwithfern.com/infra-controller/32f21b066655bd35d46189c48e647e83b39fe241e105e63eddedb9b4ac50eb8d/_dot_dot_/docs/static/nico_arch_diagram.svg)

Kubernetes 叢集需要部署多種服務：

1.  [**NICo 控制平面服務**](#nico-控制平面服務-nico-control-plane-services)：這些是 NICo 特有的服務，必須共同部署才能允許 NICo 管理主機的生命週期。
2.  [**依賴服務**](#依賴服務-dependency-services)：NICo 需要預先部署且可存取的「現成」依賴項，例如 Postgres、Vault 以及遙測服務。
3.  [**選用服務**](#選用服務-optional-services)：部署中與 NICo 互動的各種服務和工具，但它們並不是控制平面運作所持續必需的。

以下章節將詳細討論上述內容。

![NICo 站點控制器](https://files.buildwithfern.com/nvidia-ncx-infra-controller.docs.buildwithfern.com/infra-controller/55e24c57bd7ca22df55fef618ee38b0034d690bfeba151bcc15b707c54862886/_dot_dot_/docs/static/site-controller-overview.png)

---

## 受控主機 (Managed Hosts)

「受控主機」是指其生命週期由 NICo 管理的主機。

受控主機由多個內部組件組成，這些組件均屬於同一個機箱或托盤（Tray）：

*   實際的 x86 或 ARM 主機，配備任意數量的 GPU。
*   插在主機上的一或多個 DPU（型號為 BlueField-2 或 BlueField-3）。
*   用於管理主機的 BMC。
*   用於管理 DPU 的 BMC。

NICo 會在這些主機的生命週期不同時間點部署一組二進位檔案：

### Scout

[scout](https://github.com/NVIDIA/infra-controller/blob/main/crates/scout) 是 NICo 在受控主機的主機與 DPU 上執行的代理程式，用於執行多種任務：

*   **「硬體清單（Inventory）」收集**：Scout 收集主機的硬體屬性並傳送至 [NICo Core](#nico-core-1)，這些屬性是無法透過頻外（OOB）工具確定的。
*   **清理任務執行**：每當使用者釋放使用該主機的裸金屬執行個體時，執行清理任務。
*   **機器驗證測試執行**。
*   **定期健康檢查**。

### DPU 代理程式 (DPU Agent)

[dpu-agent](https://github.com/NVIDIA/infra-controller/blob/main/crates/agent) 是 NICo 以精靈（Daemon）形式專門在 NICo 管理的 DPU 上執行的代理程式。

DPU 代理程式執行以下任務：

*   在主機生命週期的任何狀態下，根據需要設定 DPU。此過程在 [DPU configuration](https://docs.nvidia.com/infra-controller/documentation/architecture/dpu_configuration.md) 中有更深入的描述。
*   在 DPU 上執行定期健康檢查。
*   運行 NICo 中繼資料服務（FMDS），該服務為裸金屬執行個體上的使用者提供一個基於 HTTP 的 API，以檢索有關其執行中執行個體的資訊。使用者可以例如使用 FMDS 來確定其機器 ID（Machine ID）或特定的啟動/OS 資訊。
*   啟用 dpu-agent 本身的自動更新。
*   為 DPU OS 部署熱修復（Hotfix）。這些熱修復減少了執行完整 DPU OS 重新安裝的需求，從而避免因 OS 更新而導致使用者的裸金屬執行個體無法使用。

### DHCP 伺服器

NICo 在 DPU 上運行一個[自訂 DHCP 伺服器](https://github.com/NVIDIA/infra-controller/blob/main/crates/dhcp-server)，該伺服器處理實際主機的所有 DHCP 請求。這意味著主機主要網路介面上的 DHCP 請求永遠不會離開 DPU 並出現在 Underlay 底層網路上 —— 這提供了更高的安全性與可靠性。

該 DHCP 伺服器由 dpu-agent 進行設定。

---

## NICo 控制平面服務 (NICo Control Plane Services)

NICo 控制平面由數個服務組成，這些服務協同工作以協調整合受控主機的生命週期：

*   **[nico-core](https://github.com/NVIDIA/infra-controller/blob/main/crates/api)**：NICo Core 服務是進入控制平面的入口點。它提供了一個 [gRPC](https://grpc.io) API，所有其他組件以及使用者（站點提供者/租戶/站點管理員）都與之進行互動，並實現了所有 NICo 管理資源（VPC、前綴、InfiniBand 與 NVLink 分區以及裸金屬執行個體）的生命週期管理。[NICo Core](#nico-core-1) 章節對此進行了更詳細的描述。
*   **[nico-dhcp (DHCP)](https://github.com/NVIDIA/infra-controller/blob/main/crates/dhcp)**：此 DHCP 伺服器響應 Underlay 底層網路上所有裝置的 DHCP 請求。這包括主機 BMC、DPU BMC 和 DPU OOB 位址。`nico-dhcp` 可以被視為一個無狀態代理（Stateless Proxy）：它實際上並不執行任何 IP 位址管理 —— 它只是將 DHCP 請求轉換為 gRPC 格式，並將基於 gRPC 的 DHCP 請求轉發給 nico-core。
*   **[nico-pxe (iPXE)](https://github.com/NVIDIA/infra-controller/blob/main/crates/pxe)**：PXE 伺服器在開機時透過 HTTP 向受控主機提供 iPXE 指令碼、iPXE 使用者資料和 OS 映像檔等開機成品。它透過向 nico-core 請求特定主機的相關資料來確定要提供哪些 OS 資料 —— 因此 PXE 伺服器也是無狀態的。目前，受控主機設定為一律從 PXE 開機。如果找到本機可開機裝置，主機會從該裝置開機。對於無狀態組態，主機也可以設定為一律從特定映像檔開機。
*   **[nico-hw-health (硬體健康狀態)](https://github.com/NVIDIA/infra-controller/blob/main/crates/health)**：此服務向 NICo 已知的所有主機和 DPU BMC 收集系統健康資訊。它會提取風扇速度、溫度和漏液指標等測量值。這些測量值在連接埠 9009 上的 `/metrics` 端點以 Prometheus 指標形式發出。此外，該服務會呼叫 nico-core API `RecordHardwareHealthReport`，根據指標中識別出的問題設定健康警報。這些警報會在 nico-core 內部合併為彙整主機健康狀態（aggregated-host-health）—— 這會發佈在整體健康指標中，並用於決定主機是否可用作租戶的裸金屬執行個體。
*   **[ssh-console](https://github.com/NVIDIA/infra-controller/blob/main/crates/ssh-console)**：SSH 主控台為裸金屬租戶和站點管理員提供對 NICo 管理的主機的虛擬序列主控台（Serial Console）存取權。`ssh-console` 服務還會將每台主機序列主控台的輸出傳送到記錄系統（Loki），以便使用 Grafana 和 logcli 進行查詢。為了提供此功能，`ssh-console` 服務會**持續**連線到所有主機 BMC。`ssh-console` 服務僅在使用者（「裸金屬租戶」）連線到服務並通過身分驗證時，才會向他們轉發記錄。
*   **[nico-dns (DNS)](https://github.com/NVIDIA/infra-controller/blob/main/crates/dns)**：網域名稱服務（DNS）功能由兩個服務處理。`nico-dns` 服務處理來自站點控制器和受控節點的 DNS 查詢，且對委派的區域（Delegated zones）具有授權（Authoritative）。

---

## NICo Core (NICo 核心服務)

NICo Core 是在 NICo 控制平面中提供最基本服務的二進位檔案。

它提供了一個 [gRPC](https://grpc.io) API，所有其他組件以及使用者（站點提供者/租戶/站點管理員）都與之進行互動，並實現了所有 NICo 管理資源（VPC、前綴、InfiniBand 與 NVLink 分區以及裸金屬執行個體）的生命週期管理。

NICo Core 可以被視為「部署在同一個二進位檔案中的獨立組件合集」。這些組件如圖所示，並在下方進一步說明：

NICo Core 是 NICo 中唯一與 Postgres 資料庫進行互動的組件。這簡化了整個產品生命週期中資料庫遷移（Migration）的部署。

![NICo 核心組件圖](https://files.buildwithfern.com/nvidia-ncx-infra-controller.docs.buildwithfern.com/infra-controller/d8ead2cb9c02c73fcef23d301d49effe7cf9cfda2dc930106c36a9729af37bec/_dot_dot_/docs/static/nico-core.png)

### NICo Core 組件 (NICo Core Components)

#### gRPC API 處理常式 (gRPC API Handlers)

API 處理常式接收來自 NICo 使用者和系統內部組件的 gRPC 請求。它們向使用者提供檢查系統目前狀態的能力，並修改各種組件的期望狀態（Desired State，例如建立或重新設定裸金屬執行個體）。

API 處理常式都在 Trait / 介面 `rpc::nico::nico_server::NICo` 內實現。各種實現委派給 `handlers` 子目錄。對於 NICo 管理的資源，API 處理常式並不直接變更資源的實際狀態（例如主機的建置狀態）。相反地，它們僅變更期望的狀態（例如「需要建置」、「需要終止」等）。狀態的變更將由狀態機執行（詳情見下文）。nico-core gRPC API 支援 [gRPC 反射（Reflection）](https://github.com/grpc/grpc/blob/master/doc/server-reflection.md)，以提供機器可讀的 API 描述，便於用戶端自動產生程式碼與用戶端中的 RPC 函數。

#### 除錯網頁介面 (Debug Web UI)

NICo Core 在 `/admin` 端點下提供了一個除錯使用者介面（Debug UI）。該除錯 UI 允許透過各種 HTML 網頁來檢查 NICo 管理的所有資源狀態。例如，它允許列出有關所有受控主機和 DPU 的詳細資訊，或者有關 NICo Core 章節中描述的其他組件之內部狀態。

該除錯 UI 還提供了對各種管理員級別工具的存取權。例如，它可以：

*   變更主機的電源狀態、重設 BMC 以及變更啟動順序。
*   檢查 NICo 管理的任何 BMC 的 Redfish 樹狀結構。
*   允許管理員以經同儕審查（Peer-reviewed）且可稽核的方式對 BMC 進行變更（透過 HTTP POST）。
*   檢查 UFM 回應。

#### 狀態機 (State Machines)

NICo 為 NICo 管理的所有資源實現了狀態機（State Machines）。狀態機被實現為冪等（Idempotent）的狀態處理函數呼叫，並由系統進行排程。

不同資源類型的狀態處理是獨立實現的，例如，主機的生命週期是由與 InfiniBand 分區生命週期不同的任務和程式碼來管理的。

NICo 為以下項目實現了狀態機：

*   受控主機（主機 + DPU）
*   網路區段（Network Segments）
*   InfiniBand 分區
*   NVLink 邏輯分區

有關 NICo 狀態處理實現的詳細資訊，可以參考 [Reliable State Handling](https://docs.nvidia.com/infra-controller/documentation/architecture/reliable-state-handling) 頁面。

#### 站點探測器 (Site Explorer)

Site Explorer 是 `nico-api` 二進位檔案中的一個背景模組，它持續監控在 Underlay 底層網路上偵測到的所有 BMC 狀態。其實現存在於獨立的 `crates/site-explorer` Crate 中，以保持 `crates/api` Crate 更小，但它仍作為 NICo Core 的一部分啟動並執行。

此程序扮演「爬蟲（Crawler）」的角色。它持續嘗試對 NICo Core 提供的 Underlay 底層網路上的所有 IP 執行 Redfish 請求，並記錄 NICo 稍後管理主機所需的資訊。NICo 收集的資訊包括：

*   序號
*   特定硬體清單資料，例如 DPU 的數量、類型和序號
*   電源狀態
*   組態設定資料，例如啟動順序、鎖定（Lockdown）模式
*   韌體版本

NICo 使用者可以使用 `FindExploredEndpoints` API 以及使用 NICo 除錯網頁介面來檢查 Site Explorer 發現的資料。

Site Explorer 需要部署一個「預期機器（Expected Machines）」清單。預期機器描述了預期由該 NICo 執行個體管理的機器集合 —— 它編碼了這些機器的 BMC MAC 位址、硬體預設密碼及其他詳細資訊。該清單可以使用一組 API 進行更新，例如 `ReplaceAllExpectedMachines`。

除了基礎的 BMC 資料收集外，Site Explorer 還執行以下任務：

1.  它根據兩個組件的 Redfish 報告將主機與相關的 DPU 進行配對 —— 例如，主機和 DPU 都需要引用同一個 DPU 序號。
2.  一旦主機處於「可接入」狀態（找到所有組件且其具有最新的韌體版本），它就會啟動主機的接入流程。

Site Explorer 發出的指標具有前綴 `nico_endpoint_exploration_` 和 `nico_site_explorer_`。

#### 接入前管理員 (Preingestion Manager)

Preingestion Manager 是 `nico-api` 二進位檔案內的一個背景模組。其實現存在於獨立的 `crates/preingestion-manager` Crate 中，以保持 `crates/api` Crate 更小，但它仍作為 NICo Core 的一部分啟動並執行。

Preingestion Manager 會更新低於接入所需最低韌體版本的主機。通常，主機的韌體更新是在主機的正常生命週期中部署的，並由 ManagedHost 狀態機管理。

在某些罕見情況下（例如使用非常舊的主機或 DPU BMC），由於 BMC 無法提供將主機映射到 DPU 所需的必要資訊，因此無法啟動主機接入程序。在此情況下，必須在接入之前更新韌體，而 Preingestion Manager 就負責執行此任務。它還驅動了在正常接入開始之前必須完成的接入前重設流程，以及 DPU BFB 還原/複製流程。

#### 機器更新管理員 (Machine Update Manager)

Machine Update Manager 是主機與 DPU 韌體更新的排程器。它會選擇軟體版本過時的機器以進行自動更新。

機器更新管理員會參考各種標準來決定機器是否應該更新：

*   目前的機器狀態 —— 例如，它是否被租戶佔用。目前只有處於 `Ready` 狀態的機器才會被選中進行自動軟體更新。
*   機器是否健康（機器上沒有記錄健康警報）。
*   有多少機器已經在更新中，以及該機器群組中健康主機的整體數量。Machine Update Manager 絕不會一次更新所有機器，且在機器臨時中斷會導致站點低於機器健康服務層級協定（SLA）的情況下，不會安排額外的更新。

Machine Update Manager 本身並不執行實際的更新 —— 它只負責排程/篩選。更新反而是在 ManagedHost 狀態機內部套用。選擇此方法是為了確保在任何時間點只有單一組件（ManagedHost 狀態機）在管理主機的生命週期。

Machine Update Manager 是一個選用組件，可以予以停用。

#### 主機電源管理員 (Host Power Manager)

Host Power Manager 是一個負責協調整合針對 BMC 電源動作的組件。

#### IB (InfiniBand) 網狀架構監控器 (IB Fabric Monitor)

InfiniBand Fabric Monitor 是 NICo 內部的一個週期性程序，使用 UFM API 執行與 InfiniBand 網狀架構的所有互動。

在每次運行中，IBFabricMonitor 執行以下任務：

*   透過執行 API 呼叫來檢查結構管理器（UFM）的健康狀態。
*   檢查 UFM 上是否套用了所有用於多租戶的安全組態設定，並在設定不當時發出警報。
*   獲取由 NICo 管理之每台主機上每個 InfiniBand 連接埠的實際套用 InfiniBand 分區資訊，並將其儲存在 NICo 中。該資料可以在 gRPC API 的 `Machine::ib_status` 欄位中進行檢查。
*   調用 UFM API，根據每台主機的組態設定將連接埠（GUID）綁定到分區（P_Key）。這是持續進行的，基於比對主機的預期 InfiniBand組態設定（無論是否由租戶使用，以及租戶如何設定 InfiniBand 介面）與實際套用的組態設定（在步驟 3 中確定）。

InfiniBand Fabric Monitor 是一個選用組件。只有在需要 NICo 管理的 InfiniBand 時才需要啟用。

IB Fabric Monitor 發出的指標具有前綴 `nico_ib_monitor_`。

#### NVLink 管理員 (NVLink Manager)

NVLink Manager 是 `nico-api` 二進位檔案內的一個背景模組。其實現存在於獨立的 `crates/nvlink-manager` Crate 中，以保持 `crates/api` Crate 更小，但它仍作為 NICo Core 的一部分啟動並執行。

其 `NvlPartitionMonitor` 會調和（Reconcile）NVLink 邏輯分區的期望狀態與 NMX-M 回報的狀態。在每次運行中，它會從資料庫中載入具有 MNNVL 功能的機器和 NVLink 分區記錄、向 NMX-M 查詢 GPU 和分區狀態、記錄 `MachineNvLinkStatusObservation` 資料，並根據需要建立、更新或移除 NMX-M 分區。

---

## 依賴服務 (Dependency Services)

除了 NICo API 伺服器組件外，還有其他支援服務在 K8s 站點控制器節點內執行。

### K8s 持久化儲存物件 (K8s Persistent Storage Objects)

某些站點控制器節點服務需要持久且耐用的儲存來維持其伴隨 Pod 的狀態。控制器節點上運行著三個不同的 K8s StatefulSet：

*   **[Loki](https://grafana.com/oss/loki/)** — `loki/loki-0` Pod 實例化一個單一 50GB 的持久性磁碟區（PV），用於儲存站點控制器組件的記錄。
*   **[Hashicorp Vault](https://www.vaultproject.io/)** — 由 Kubernetes 用於憑證簽署請求（CSR）。Vault 使用三個（每個 K8s 控制節點一個）10GB 的 `data-vault` 和 `audit-vault` PV，以在缺乏共享儲存解決方案的情況下保護並發佈資料。
*   **[Postgres](https://www.postgresql.org/)** — 用於為需要它的任何 NICo 或站點控制器組件儲存狀態，包括主要的 「nicodb」。部署了三個 10GB 的 `pgdata` PV，以在缺乏共享儲存解決方案的情況下保護並發佈資料。`nicodb` 資料庫即儲存於此。

---

## 選用服務 (Optional Services)

設定站點控制器的目的在於管理已進駐租戶受控主機的站點。

每個受控主機都是 BlueField（BF）-2 或 -3 DPU 與主機伺服器的配對（目前僅測試過最多兩個 DPU）。在初始部署期間，[scout](https://github.com/NVIDIA/infra-controller/blob/main/crates/scout) 會執行並將任何偵測到的 DPU 通知給 nico-api。NICo 完成在 DPU 上的服務安裝，並開機進入一般運作模式。隨後，`nico-dpu-agent` 以精靈形式啟動。

每個 DPU 都會執行 `nico-dpu-agent`，後者透過 gRPC 連線至 NICo 中的 API 服務以取得組態設定指令。

`nico-dpu-agent` 還運行著 NICo 中繼資料服務（FMDS），該服務為裸金屬執行個體上的使用者提供一個基於 HTTP 的 API，以檢索有關其執行中執行個體的資訊。使用者可以例如使用 FMDS 來確定其機器 ID 或特定的開機/OS 資訊。

---

## 重點整理 (Key Takeaways)

1.  **控制平面高可用部署**：NICo 控制平面元件運行在至少 3 節點的 Kubernetes 叢集（站點控制器）上，主要透過一系列微服務來管理受控主機的整個生命週期。
2.  **受控主機內部代理**：
    *   **Scout**：跑在主機與 DPU 上，負責收集頻外無法獲取的硬體清單、健康檢查和釋放清理。
    *   **DPU Agent**：跑在 DPU 上，處理 DPU 設定、熱修復與 FMDS 中繼資料服務。
    *   **自訂 DHCP**：直接運行在 DPU 上攔截主機 DHCP 請求，不流向實體網路，提高安全性。
3.  **核心元件 NICo Core**：
    *   單一二進位檔內包含多個獨立組件（gRPC API, Admin UI, 各類背景管理員）。
    *   是唯一與外部 Postgres（儲存主 nicodb）交互的組件。
    *   **狀態機**：獨立地且冪等地管理主機、網路、Infiniband 與 NVLink 分區。
    *   **Site Explorer & Preingestion Manager**：扮演爬蟲探測 OOB 網路中的 BMC，做 DPU 配對並引導主機接入（Ingestion）或韌體前置更新。
4.  **三方網路與硬體整合**：
    *   **IB Fabric Monitor** 與 UFM API 交互以配置多租戶分割與 GUID 綁定。
    *   **NVLink Manager** 與 NMX-M API 交互管理 NVLink 邏輯分區。
5.  **基礎設施依賴**：利用 K8s StatefulSet 管理 Loki 日誌、Hashicorp Vault 憑證安全與 Postgres 資料庫等無共享儲存的高可用持久化。
