# Day 0 / Day 1 / Day 2 Lifecycle (Day 0 / Day 1 / Day 2 生命週期)

NICo 將裸金屬生命週期管理（Bare-metal Lifecycle Management）組織為三個階段：Day 0（啟用）、Day 1（設定）與 Day 2（運維）。

---

## Day 0 — 發現、驗證與接入 (Discovery, Validation, and Ingestion)

Day 0 涵蓋了從硬體送達機架到宣告主機已準備好供租戶使用的所有過程。其設計目標是「零接觸」（Zero-touch）：一旦主機上架並連接好線纜，NICo 便會處理從發現到就緒供建置的整個過程。

*   **硬體發現 (Hardware discovery)**
    NICo 透過頻外（OOB）網路利用 Redfish 來發現硬體。站點控制器（Site Controller）的爬蟲會探測 BMC 端點，收集完整的硬體清單（包含 CPU、GPU、NIC、DPU 和儲存裝置），並透過 LLDP 和序號比對將每個 DPU 連結至其主機伺服器。不需要手動輸入硬體清單。
*   **SKU 驗證與燒機測試 (SKU validation and burn-in)**
    在接入（Ingestion）之前，NICo 會驗證每部機器是否與預期的 SKU 符合，並標示任何缺失或非預期的組件。接著它會執行硬體與連線測試，包括針對參與 InfiniBand 或 NVLink 網狀架構之系統的多節點測試。
*   **韌體基準線 (Firmware baseline)**
    NICo 會列出 UEFI 和 BMC 韌體清單，並在提供主機使用之前，更新任何未達到站點基準線的主機。無法達到基準線的主機將會被自動隔離（Quarantine）。
*   **DPU 資源建置 (DPU provisioning)**
    NICo 會安裝 DPU 作業系統、配置 HBN（使用容器化 Cumulus 的主機端網路,Host-based Networking），並設定所有 DPU 韌體組件（BMC、NIC、UEFI、ATF）。DPU 代理程式（Agent）在建置後啟動，定期透過 gRPC 從 NICo 獲取所需的組態設定，並將套用後的狀態回報。
*   **證明 (Attestation)**
    NICo 在主機進入可用資源池之前，會透過度量啟動（Measured Boot）PCR 檢查和 TPM 簽章驗證來對每台主機進行證明。
*   **網路與 IP 設定 (Network and IP setup)**
    IP 位址池（BGP、環回/loopback、主機 OS）、DHCP 以及 DNS 都會在接入工作流程中自動配置與設定。

---

## Day 1 — 隔離、鎖定與資源建置 (Isolation, Lockdown, and Provisioning)

Day 1 涵蓋了隔離邊界的組態設定，以及為租戶使用建置主機資源。

*   **網路隔離 (Network isolation)**
    在將主機分配給租戶之前，NICo 會在所有適用的網路平面上建立隔離：
    *   **乙太網路 (Ethernet)** — BlueField HBN 強制執行 L3 VXLAN/EVPN 邊界以及每個租戶的 VRF。*不需要變更葉端交換器（Leaf Switch）的設定*。
    *   **InfiniBand** — UFM 會為特定租戶分配 P_Key 分區到主機的 IB 連接埠。
    *   **NVLink** — NMX-M API 會針對租戶的 NVL 網域設定 NVLink 分區分配。
*   **主機鎖定 (Host lockdown)**
    NICo 會套用 UEFI 鎖定（防止租戶使用期間未授權的 BIOS 變更）、設定 BMC 安全性設定，並停用頻內（In-band）主機到 BMC 的通訊。
*   **作業系統建置 (OS provisioning)**
    NICo 協調 PXE/iPXE 啟動順序以安裝租戶選擇的 OS 映像檔。它會設定 UEFI 啟動順序、套用安全性設定，並在主機啟動時移交給呼叫端。除了啟動移交之外，NICo 不會管理安裝的內容 —— 作業系統的設定是由營運人員或租戶自行負責。
*   **執行個體管理 (Instance management)**
    營運人員可以定義執行個體類型（Instance types，例如 GPU 節點組態等硬體類別），並透過 REST API 或 gRPC API 將主機作為執行個體分配給租戶。對於 GB200 NVL72 系統，分配會按 NVL 網域進行批次處理，以維持 NVLink 拓撲結構的完整性。

---

## Day 2 — 運維、健康狀態與租戶移轉 (Operations, Health, and Tenant Transitions)

Day 2 涵蓋了動態基礎設施的持續運作，以及租戶使用之間的生命週期過渡。

*   **持續監控 (Continuous monitoring)**
    NICo 透過 Redfish 輪詢與 DPU 代理程式遙測，持續監控硬體健康狀態。指標以 Prometheus 格式匯出，可供營運人員的監控工具堆疊（Grafana、Loki、OpenTelemetry）取用。硬體事件與健康異常會透過 NICo API 以及告警整合系統呈現。
*   **韌體更新 (Firmware updates)**
    NICo 會在健康且未被佔用的主機上安排 UEFI 和 BMC 韌體更新 —— 這些更新完全是頻外（Out-of-band）進行的，不會中斷使用中的租戶。更新會參照站點基準線套用，並記錄在每部機器的韌體清單中。
*   **租戶移轉與淨化 (Tenant transitions - sanitization)**
    當租戶釋放主機時，NICo 會在主機重新進入可用池之前執行完整的清理序列：
    1.  安全抹除（Secure erase）所有 NVMe 儲存裝置。
    2.  清除 GPU 記憶體與系統記憶體（Wipe）。
    3.  重設 TPM。
    4.  透過度量啟動（Measured Boot）與 TPM 驗證進行重新證明（Re-attestation）。
    5.  重新驗證韌體完整性。
    6.  清除網路隔離狀態，並為下一位租戶重新建置。
*   **故障修復 (Break-fix)**
    NICo 支援針對故障修復工作流程的定向建置（Directed provisioning）：將特定機器的建置指向特定主機、使用機器標籤來追蹤維修中的機器，以及提供問題回報 API 以便與服務管理工具整合。
*   **機櫃級健康回應 (Rack-scale health response - GB200)**
    對於 GB200 NVL72 系統，NICo 的機櫃級管理層會對健康訊號（例如漏液事件、電力異常、NVLink 結構降級）做出反應，採取可設定且基於策略的自動化回應，包括安全地關閉工作負載、機櫃隔離以及復原順序。

---

## 重點整理 (Key Takeaways)

1.  **全自動化的 Day 0 發現與接入**：NICo 設計為零接觸（Zero-touch），透過頻外（OOB）Redfish 和 DPU 的 LLDP 等機制自動偵測、比對並驗證硬體，無需手動建立硬體清單。此外還能自動套用韌體基準線，並將異常設備進行隔離。
2.  **多維度的 Day 1 租戶隔離與鎖定**：支援在乙太網路（L3 VXLAN/EVPN VRF）、InfiniBand（P_Key）與 NVLink 等多種通訊結構上建立嚴格的網路邊界，同時實施 UEFI/BMC 主機鎖定，確保租戶間的安全性，並藉由 PXE/iPXE 自動化安裝作業系統。
3.  **無中斷的 Day 2 運維與高標準淨化**：運維期間可透過 Redfish 與 DPU 代理程式持續監控並匯出 Prometheus 格式指標；當租戶移轉時，NICo 會進行深度「淨化」（Sanitization），包括 NVMe 安全抹除、記憶體清理、TPM 重設與安全重新證明，確保下一位租戶的資料安全。
4.  **針對 GB200 NVL72 的機櫃級最佳化**：對於 GB200 這類高度緊密的 AI 基礎設施，NICo 在 Day 1 會按 NVL 網域批次分配以保護 NVLink 拓撲；在 Day 2 則提供機櫃級健康監控，可在偵測到漏液、電力異常或 Fabric 效能退化時，自動執行安全關閉與隔離策略。
