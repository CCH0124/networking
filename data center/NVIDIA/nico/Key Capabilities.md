# Key Capabilities

## 硬體準備與驗證 (Hardware Readiness and Validation)

NICo (NVIDIA Infra Controller) 在主機提供給租戶之前，會自動化硬體上架 (Onboarding) 流程：

- **透過 Redfish 自動搜尋**：透過頻外 (OOB) 網路自動搜尋 BMC，並透過 LLDP 和序號比對來自動配對 DPU 和實體主機。
- **SKU 驗證**：確認每台機器均具備預期的硬體元件，並標記不完整或配置錯誤的主機。
- **硬體燒機與測試**：在佈署前驗證單節點和多節點的設定，包括 NVLink 和 InfiniBand 連線能力。
- **韌體基準執行**：在接納時盤點 UEFI 和 BMC 韌體，並在主機可用之前使任何超出基準的主機符合規範。

## DPU 生命週期管理 (DPU Lifecycle Management)

NICo 在整個生命週期中管理 BlueField DPU：

- 安裝 DPU 作業系統並配置 HBN（主機端網路，包含容器化的 Cumulus，並透過 NVUE 進行設定）。
- 管理所有 DPU 韌體元件：BMC、NIC、UEFI、ATF。
- 執行 DPU 代理程式，該代理程式定期透過 gRPC 從 NICo 獲取所需的配置並執行配置指令。
- 停用自主機內部的頻內 (In-band) BMC 存取，強制執行僅限頻外的管理(out-of-band)。

## 安全多租戶與網路隔離 (Secure Multi-Tenancy and Network Isolation)

NICo 在所有網路平面上強制執行工作負載隔離，而無需重新配置實體交換器：

| 網路平面 (Plane) | 機制 (Mechanism) |
|---|---|
| 乙太網路 (南北向 N/S) | BlueField HBN — L3 VXLAN/EVPN, VRF, 網路安全群組 (Network Security Groups) |
| InfiniBand (東西向 E/W) | 基於 UFM 為每個租戶分配 P_Key 分割區 |
| NVLink | NMX-M API 分割區管理 |
| Spectrum-X (東西向 E/W) | 用於高效能東西向流量的 Spectrum-X 分割區 (SP-X partitioning) |

VPC 和子網配置皆為 API 驅動。租戶切換時會完全清除並重新建立隔離邊界。

## 信任與證明 (Trust and Attestation)

NICo 預設將每個主機視為不可信：

- **主機證明 (Host attestation)**：透過已度量啟動 (Measured Boot) PCR 檢查，以及透過 TPM 製造商 CA 進行 TPM 簽章驗證。
- **使用期間的 UEFI 鎖定**：在租戶佔用主機期間防止未經授權的 BIOS 變更。
- **受控的管理憑證**：管理 BMC 憑證（每個站點）與 UEFI 憑證（每個裝置）。
- **安全擦除**：在租戶使用之間，安全擦除 NVMe 儲存、GPU 記憶體與系統記憶體。
- **僅限頻外監控**：NICo 從不依賴頻內主機報告來做出安全決策。

## 持續合規與韌體控制 (Continuous Compliance and Firmware Control)

NICo 持續維持整個伺服器叢集的硬體基準一致性：

- 在健康、未被佔用的主機上安排 UEFI 和 BMC 韌體更新。
- 透過 Redfish 和 DPU 代理程式持續監控硬體健康狀況。
- 以 Prometheus 格式匯出指標，以便與營運商的監控堆疊整合。
- 針對與站點基準不符的韌體或配置偏差發出警報。
- 維護每個站點、每台機器的韌體版本完整資產清單。

## 彈性部署與整合 (Flexible Deployment and Integration)

- **API 優先**：為營運商和 ISV 整合提供 REST API、為直接管理提供 gRPC API 和管理員 CLI，以及為工程使用提供偵錯 UI。
- **JWT 驗證**：與 Keycloak 和相容的 IAM 方案整合。
- **支援任何作業系統 (OS)**：支援任何可透過 iPXE 安裝的作業系統；NICo 對作業系統沒有特定要求。
- **自備監控 (BYO monitoring)**：提供 Prometheus 指標匯出，可與 Grafana、Loki 以及相容於 OpenTelemetry 的堆疊整合。
- **Kubernetes 原生**：可部署在任何符合規範的 Kubernetes v1.30+ 環境中。
- **廣泛的硬體支援**：支援 NVIDIA L40/L40S PCIe, HGX/DGX A100/H100/B200, GB200 NVL72, 僅含 CPU 的 x86 以及 Grace 系統。

## GB200 NVL72 與機櫃級能力 (GB200 NVL72 and Rack-Scale Capabilities)

針對 GB200 NVL72 超級叢集 (SuperCluster) 部署，NICo 將生命週期管理延伸至機櫃級別：

**NICo 流 (NICo Flow)** 將機櫃和 NVL 領域視為第一等管理實體，而非個別主機的集合。它在機櫃組件之間安全地安排電源操作、韌體更新和維護工作流程的順序，防止不安全的操作並確保密集的、多托盤系統之間的正確順序。

**NVLink 叢集化 (NVLink Clustering)** 管理 NVLink 領域的形成、健康監控和分割區管理。NICo 將實例分配限制在叢集就緒狀態下 —— 如果 NVLink 織網不健康或未完全形成，則會阻止配置。

**漏液檢測 (Leakage Detection)** 整合了樓宇管理系統 (BMS) 和托盤感測器信號，並套用可配置的、基於策略的響應：對受影響的托盤進行正常關機、對漏液源下方的托盤進行重力感知處理，以及做出機櫃級隔離決策。關鍵安全操作仍由 BMS 處理；NICo 負責處理非關鍵條件下的編排與自動化。

**領域電源配置 (Domain Power Provisioning)** 支援每個實例的 Max-P 和 Max-Q 電源配置檔。NICo 在生命週期事件（開機、韌體更新、維護）前後與外部電源引擎進行協調，以防止不安全的電源狀態並實現機櫃間的最佳電源利用率。

---

## 重點整理 (Key Takeaways)

1. **自動化硬體驗證與準備**
   * 透過 Redfish OOB 自動搜尋並利用 LLDP/序號自動配對主機與 DPU。
   * 執行實體 SKU 規格比對、硬體燒機測試（含 InfiniBand/NVLink 連線）以及 UEFI/BMC 韌體基準強制更新，確保提供給租戶的主機百分之百健康。

2. **BlueField DPU 全生命週期管理**
   * 自動部署 DPU OS、配置 HBN (Host-Based Networking) 虛擬疊加網路，並透過 gRPC 代理與 NICo 互動接收配置。
   * 封鎖從主機端（頻內）對 BMC 模組的存取，確保管理通道之物理與邏輯隔離。

3. **租戶隔離與零信任安全架構**
   * **硬體分區隔離**：支援在乙太網 (HBN/VXLAN)、InfiniBand (UFM/P_Keys) 及 NVLink (NMX-M) 平面上進行 API 驅動的動態租戶硬體隔離。
   * **生命週期安全擦除**：租戶轉移時，自動安全抹除 NVMe 儲存、GPU 記憶體和系統記憶體中的殘留資料。
   * **信任驗證**：利用 Measured Boot 與 TPM 簽章做主機身分與韌體完整性遠端證明，並在租戶使用期間鎖定 UEFI 防止 BIOS 修改。

4. **API 優先與多樣化相容**
   * 提供 REST/gRPC API、管理員 CLI 及 Prometheus 監控匯出。支援任何以 iPXE 啟動的 OS，並相容主流 NVIDIA GPU 系統 (包括 B200, GB200 NVL72) 與 CPU 架構。

5. **GB200 NVL72 機櫃級 (Rack-Scale) 管理**
   * **NICo Flow**：將機櫃整體視為單一實體安全管理，依序調度多托盤系統的電源、韌體升級與維護順序。
   * **漏液控制自動化**：結合感測器與 BMS 執行重力感知漏液控制、托盤安全關機與機櫃級隔離。
   * **機櫃級電源與 NVLink 調度**：限制實例分配於 NVLink 正常就緒時，並動態調節 Max-P/Max-Q 機櫃電源以防不安全負載。
