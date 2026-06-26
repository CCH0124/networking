# Connected Host Metadata

已連線主機中繼資料（Connected Host Metadata）工作流會將交換器的 MAC 轉發表（FDB）和 LLDP 鄰近裝置表，與 Nautobot 中的主機庫存進行關聯（join），以產生該裝置上每個介面所連線硬體的完整輪廓。這是抽查交換器上實際插線狀態的標準工具 — 當啟用新裝置、排查未正常出現在預期位置的主機，或是驗證 Nautobot 的主機模型是否符合實際時非常有用。

## 前提條件 (Prerequisites)

在執行工作流之前，請確認以下各項已就緒：

* **裝置已存在於 Nautobot 中**，具有主要 IPv4 位址與支援的平台。此工作流會直接查詢裝置的 FDB 和 LLDP 表，因此平台（platform）欄位將決定所使用的 CLI 語法。
* **裝置為可連線狀態**：可從 Config Manager 透過管理位址連線至該裝置，且金鑰儲存庫中存在相關憑證。
* **要涵蓋的交換器連接埠已啟用 LLDP**。對於沒有啟用 LLDP 的連接埠，工作流會退而使用僅限 MAC 的比對，但啟用 LLDP 能提供更乾淨、明確的結果。
* **Nautobot 中已建立對應的主機模型**，以供關聯解析。若主機的 MAC 位址投射不存在於 Nautobot 中，報告的主機欄位將會顯示為空，但該資料列仍會顯示 MAC 位址與連接埠。

## 執行工作流 (Running the workflow)

1. 導覽至您環境 Config Manager URL。
2. 點擊右上角的 **+** 並選擇 **ConnectedHostMetadataWorkflow**。
3. 參考下方欄位說明填寫表單並提交。

| 欄位 | 說明 | 是否必填 |
| :--- | :--- | :--- |
| **Site (站點)** | 欲檢查裝置所屬的站點，會影響下方的裝置清單。 | 是 |
| **Tenant (租戶)** | 選填的 Nautobot 租戶篩選器，用以縮小裝置清單範圍。 | 否 |
| **Status (狀態)** | 選填的裝置狀態篩選器，用以縮小裝置清單範圍。 | 否 |
| **Device (裝置)** | 目標裝置。清單將根據上述選擇進行篩選。 | 是 |

提交後，系統會顯示一個狀態頁面，呈現三個執行階段。典型的執行可在不到一分鐘內完成。

## 執行階段 (Execution stages)

該工作流包含三個執行階段。前兩個階段彼此獨立且平行執行；第三個階段會等待前兩個階段完成。所有階段皆不需要人工審核。

1. **`get_device_mac_table` — 自裝置讀取 FDB。**

   查詢裝置的 MAC 轉發表，過濾掉沒有 VLAN 的項目（通常是 CPU/本地端 MAC），並將結果呈現為 (Interface, MAC, VLAN) 的 Markdown 表格。當 FDB 為空時，此階段會顯示「No MAC Addresses found on device (在裝置上未找到 MAC 位址)」，而不會宣告失敗。

2. **`get_device_neighbors` — 自裝置讀取 LLDP 鄰近表。**

   查詢裝置的 LLDP 鄰近裝置，並呈現 (Interface, Neighbor Device, Neighbor Interface, Link Status)。當鄰近表為空時，此階段會顯示「No LLDP neighbors found on device (在裝置上未找到 LLDP 鄰近裝置)」，而不會宣告失敗。

3. **`get_connected_host_data` — 將 MAC + LLDP 與 Nautobot 進行關聯比對。**

   此階段依賴前兩個階段的結果。針對有 MAC 或 LLDP 項目的每個介面，工作流會執行：
   * 透過 `get_host_data_by_macs` 依 MAC 位址查詢主機。
   * 透過 `get_host_data_by_names` 依裝置名稱查詢主機（當 LLDP 鄰近裝置名稱解析為 Nautobot 主機時使用）。
   * 針對有多個候選 MAC 的介面，優先選擇 MAC 與已知 Nautobot 主機相符的項目；否則優先選擇最新的 FDB 項目。
   * 輸出最終表格，欄位包含：Network Interface (網路介面), Host (主機), LLDP Name (LLDP 名稱), Alias (別名), Connected Interface (已連線介面), MAC Address (MAC 位址), Tenant (租戶), VLAN。

   若 FDB 與 LLDP 階段皆回報空資料，此階段會直接跳轉為無法執行（UNREACHABLE），而不會執行關聯操作。

工作流在完成前會封存結果。活動超時時間很短（1 分鐘），且在發生暫時性錯誤時最多重試 3 次。

## 驗證結果 (Verifying outcomes)

當工作流回報成功後，請確認：

* **三個階段皆顯示為綠色**（已完成）。
* **每個開啟（up）的介面在彙整表格中至少有一列資料**，或出現在僅限 LLDP / 僅限 MAC 的備用顯示中。缺失的介面通常代表該連接埠未啟用 LLDP 且無流量通過，或者是該介面已被管理性關閉（administratively down）。
* **預期應在 Nautobot 中的主機，其主機（Host）欄位已被填入資料。** 若有效的 MAC 位址旁主機欄位為空，表示該主機可正常連通，但尚未在 Nautobot 中建立模型。

## 常見問題 (Common issues)

**階段 1 或 階段 2 回報 `UNREACHABLE (無法連線)`。**

裝置無法連線或管理憑證錯誤。請確認裝置在管理 IP 上處於開機狀態，且 Config Manager 的站點憑證是最新且正確的。請參閱《新站點啟用》指南中的 [監控 DHCP 與 ZTP](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/new-site-bringup#monitoring-dhcp-and-ztp) 區段，以取得標準的連線疑難排解流程。

**預期有主機的介面上，主機欄位為空（`--`）。**

實體網路上的 MAC 位址與 Nautobot 中的任何主機皆不吻合，或者是主機已被重新命名或移動。確認 FDB 回報的 MAC 位址並與 Nautobot 進行核對。對於依名稱建立模型的主機（由 LLDP 衍生），確認 LLDP 系統名稱與 Nautobot 裝置名稱完全一致。

**同一個介面在多次執行之間顯示不同的 MAC 位址。**

代表 FDB 不穩定 — 這通常發生在多個主機共用網段的 Trunk 連接埠，或者伺服器正頻繁切換 MAC（如 PXE 重試、連結閃斷）。請調查對端裝置，而非盲目重試工作流。

**兩個階段皆傳回空資料。**

工作流會直接跳轉結束，並將 `get_connected_host_data` 標記為無法執行（UNREACHABLE）。請確認該裝置是否有任何運作中（live）的連接埠 — 一台沒有流量且已停用 LLDP 的交換器將沒有任何資訊可以回報。

## 相關指南 (Related guides)

* [新站點啟用](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/new-site-bringup) — 完整的啟用程序，通常在實體佈線完成後呼叫此工作流。
* [佈線驗證](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/validation/cable-validation) — 相似的驗證工作流，用於將實際觀測到的佈線與 Nautobot 預期拓撲進行對比。

---

## 重點整理

本篇說明了 NVIDIA Config Manager 中用於查詢與驗證交換器介面所連線裝置之「已連線主機中繼資料（Connected Host Metadata）」工作流，其核心要點如下：

1. **工作原理與用途**：
   - 透過將交換器的 `MAC 轉發表 (FDB)` 和 `LLDP 鄰近表` 與 Nautobot 的主機庫存進行交叉比對，產出詳細的介面連線清單。
   - 用於新裝置啟用時抽查連線、排查主機連線位置與驗證 Nautobot 的主機資訊是否與實際狀況一致。

2. **三階段並行執行流程**：
   - **階段 1 & 2 (平行)**：同時自交換器取得 FDB 表和 LLDP 鄰近表。即使 FDB 或 LLDP 為空，該階段亦只會顯示警告，而不會中斷工作流。
   - **階段 3 (彙整關聯)**：依據前兩階段資料，先後透過 MAC 與設備名稱查詢 Nautobot 的主機資訊並進行關聯，產出最終的關聯表格。

3. **疑難排解與結果判讀**：
   - 若 FDB 與 LLDP 雙雙為空，工作流將自動短路並將第三階段標記為無法執行（UNREACHABLE）。
   - 若有效 MAC 位址旁的主機欄位顯示為空（`--`），代表該主機雖然有流量連通，但在 Nautobot 中並未登記建模。
   - 若在多次執行間同個介面出現不同 MAC，代表該連接埠可能為 Trunk 埠或對端裝置（如伺服器）狀態不穩定。
