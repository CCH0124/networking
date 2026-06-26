# Cable Validation

佈線驗證（Cable Validation）工作流用於驗證實體佈線是否符合 Nautobot 中規劃的預期拓撲。它會將每台交換器透過 LLDP 回報的資訊（在無法使用 LLDP 的情況下，則使用其轉發資料庫 FDB 和 ARP 表所顯示的資訊）與 Nautobot 中規劃的佈線進行比對，並針對每個介面產生所有不一致處的報告。

提供兩種變體：

* **站點佈線驗證 (Site Cable Validation)**：平行擴展至站點內所有符合範圍的裝置。適用於新站點啟用（bringup）期間，以及您想要了解完整佈線健康狀態的任何時候（例如維護空檔前、大規模重新佈線後、定期審計等）。
* **裝置佈線驗證 (Device Cable Validation)**：針對單一裝置。用於在修正特定的佈線、MAC 或主機名稱問題後進行重新驗證，無須重新執行整個站點。

站點工作流會將裝置工作流作為子工作流針對每台裝置執行，因此兩者的報告格式、問題類別和底層驗證邏輯完全相同，僅有範圍不同。

佈線驗證可偵測出：

* 線路接錯（Cable swaps）
* 未送電的伺服器
* 機櫃擺放錯誤（Swapped racks）
* 合作夥伴提供的 MAC 位址錯誤
* 購買了錯誤的線材

## 前提條件 (Prerequisites)

在執行佈線驗證之前，請確認以下各項已就緒：

* **裝置已完成 ZTP**，且在 Nautobot 中達到 `Provisioned`（或 `Active`）狀態。對仍在進行置備或無法連線的裝置執行驗證會產生大量的錯誤干擾。請參閱 [新站點啟用](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/new-site-bringup) 以瞭解啟用順序。
* **預期佈線已登錄於 Nautobot 中。** 工作流會比對 LLDP 和 FDB 的輸出與 Nautobot 中的線路清單，因此 Nautobot 的資料必須反映實際設計。若 Nautobot 中存在不需進行驗證的連線，其介面必須標有 `cable-validation-ignore` 標籤。
* **裝置運行於支援的平台**：Cumulus Linux、NVOS 或 Arista EOS。其他平台的裝置會被自動篩選掉。
* **Config Manager 到每個範圍內裝置之管理位址的網路可達性**，以便工作流查詢 LLDP 鄰近裝置與 MAC/ARP 表。

## 執行站點佈線驗證 (Running site cable validation)

在新站點啟用或需要了解全網狀態時使用。

1. 導覽至您環境的 Config Manager URL。
2. 點擊右上角的 **+** 並選擇 **SiteCableValidationWorkflow**。

   ![Workflow form](https://files.buildwithfern.com/config-manager.docs.buildwithfern.com/switch-infrastructure/config-manager/00231264971b4e35ed03f0cfca7d44d586310f15d5f1ce17332a39babc0806c5/_dot_dot_/assets/images/cable-validation-workflow-form.png)

   參考下方欄位說明填寫表單。

   | 欄位 | 說明 | 是否必填 |
   | :--- | :--- | :--- |
   | **Site (站點)** | 要驗證的站點。 | 是 |
   | **Roles (角色)** | 要包含的裝置角色（可多選）。在 InfiniBand 站點上，請排除 CIN 裝置，因為它們是由另一個獨立工作流來驗證。 | 是 |
   | **Device Types (裝置類型)** | 選填的裝置類型篩選器。設定後，僅包含 Nautobot 裝置類型 ID 符合此清單的裝置。 | 否 |
   | **Device Status (裝置狀態)** | 要包含的裝置狀態（可多選）。通常為 `Provisioned`，這是 ZTP 完成後裝置所處的狀態。 | 是 |
   | **Tenant (租戶)** | 執行此流程的 Nautobot 租戶。 | 是 |

3. 提交表單。系統會顯示一個狀態頁面，呈現工作流的三個執行階段。每台裝置子工作流的進度會逐步更新；當剩下不到 10 台裝置時，頁面會直接提供剩餘子工作流的連結，方便您追蹤進度落後的裝置。由於工作流需要連線至範圍內的每台裝置，此過程可能需要幾分鐘。
4. 當工作流執行完成後，點擊左側選單中的 **Generate Cable Validation report (產生佈線驗證報告)** 檢視報告。

   ![Report link](https://files.buildwithfern.com/config-manager.docs.buildwithfern.com/switch-infrastructure/config-manager/eea364cc1caba4fb8d6eb6ca39c01e104af3d0d8c6301ef669303f146fdf794a/_dot_dot_/assets/images/cable-validation-report-link.png)

   ![Report example](https://files.buildwithfern.com/config-manager.docs.buildwithfern.com/switch-infrastructure/config-manager/e2bd39855bab20b96e9cdba9f5496571f496a63a64ddac1c9a78f81e0e280e86/_dot_dot_/assets/images/cable-validation-report-example.png)

5. 處理發現的問題，然後重新執行工作流以確認問題已解決。

## 執行裝置佈線驗證 (Running device cable validation)

用於在修正特定問題後重新驗證單一裝置，而無須重新執行整個站點。

1. 導覽至您環境的 Config Manager URL。
2. 點擊右上角的 **+** 並選擇 **DeviceCableValidationWorkflow**。
3. 參考下方欄位說明填寫表單並提交。

| 欄位 | 說明 | 是否必填 |
| :--- | :--- | :--- |
| **Site (站點)** | 目標裝置的站點，會影響下方的裝置清單。 | 是 |
| **Tenant (租戶)** | 選填的 Nautobot 租戶篩選器，用以縮小裝置清單範圍。 | 否 |
| **Status (狀態)** | 選填的裝置狀態篩選器，用以縮小裝置清單範圍。 | 否 |
| **Device (裝置)** | 目標裝置。清單將根據上述選擇進行篩選。 | 是 |
| **Ignore No Neighbor (忽略無鄰近裝置)** | 選填。啟用時，會隱藏此裝置執行中的 `Link is up, but no neighbor found (連結已連線但未找到鄰近裝置)` 發現。這在部分啟用（部分對端裝置尚未上線）時非常實用。 | 否 |

典型的單一裝置執行可在不到一分鐘內完成，其時間主要取決於查詢 LLDP 和 FDB 的來回時間。

## 執行階段 (Execution stages)

### 站點佈線驗證 (Site cable validation)

站點工作流包含三個執行階段，皆不需要人工審核。

1. **`get_devices_to_validate` — 自 Nautobot 解析裝置清單。**

   向 Nautobot 查詢所有符合站點、角色、狀態、租戶和裝置類型篩選條件的裝置，並過濾掉不支援平台（Cumulus Linux、NVOS、Arista EOS）的裝置。解析出的裝置清單會以 Markdown 表格呈現在此階段的頁面上。若無符合篩選條件的裝置，剩餘階段將標記為無法執行（Unreachable），工作流會立即結束並傳回說明訊息。

2. **`validate_devices` — 針對每台裝置執行裝置佈線驗證子工作流。**

   針對每台裝置，站點工作流會啟動一個裝置佈線驗證子工作流，複製父工作流的搜尋屬性（`User`、`ReadRoles` 和 `ExecuteRoles`），並附加該裝置的 `DeviceID`。此階段會等待所有子工作流完成，並逐步更新頁面資訊（`N/total completed` 已完成數、成功/失敗計數，並在剩下不到十台時列出剩餘的裝置名稱）。失敗的子工作流會記錄在 `failed_devices` 中，而不會中斷整個階段，因此單一台無法連線的交換器不會阻礙其他報告的產出。

3. **`format_result` — 將每台裝置的結果彙整至站點報告中。**

   將所有子工作流的介面檢驗結果合併為統一的 Markdown 報告，並將 `failed_devices` 清單完整呈現在報告頂端，以便維運人員了解哪些交換器被跳過，哪些已完成驗證且無問題。報告會直接呈現在階段頁面中，並提供 CSV 下載連結（適用於結果過多而無法在網頁 UI 完整呈現的情況）。

### 裝置佈線驗證 (Device cable validation)

裝置工作流包含六個階段。在主機名稱檢查通過後，三個資料收集階段（`get_device_intended_neighbors`、`get_device_actual_neighbors`、`get_device_mac_table`）會平行執行。

1. **`get_device_data` — 自 Nautobot 取得裝置記錄。**

   透過 UUID 載入裝置資訊，並將裝置搜尋屬性附加到工作流中以利觀測。當工作流是作為站點佈線驗證的子工作流啟動時，父工作流會直接傳遞已獲取的記錄，因此在此階段實際上是不執行任何操作（no-op）。

2. **`validate_device_hostname` — 確認裝置運行中的主機名稱與 Nautobot 一致。**

   登入裝置並讀取其設定的主機名稱，然後與 Nautobot 中的名稱進行比對。如果名稱不符，工作流會在進行任何佈線檢測前結束並宣告失敗，因為對錯誤的裝置進行佈線驗證會產生誤導的結果。

3. **`get_device_intended_neighbors` — 自 Nautobot 讀取預期佈線。**

   自 Nautobot 提取裝置上每個介面的預期 LLDP/MAC 鄰近裝置清單，包含用以排除比對的 `cable-validation-ignore` 標籤。

4. **`get_device_actual_neighbors` — 自裝置讀取實際觀測到的佈線。**

   查詢裝置上每個介面的 LLDP 鄰近表。這是實體連接狀態的最高真理源。

5. **`get_device_mac_table` — 自裝置讀取 FDB 與 ARP 表。**

   從裝置提取 MAC 表（FDB）與 ARP 表。MAC 與 ARP 項目是針對無法使用 LLDP 的連結（最常見的是與主機的 IPMI/BMC 連接）的備用驗證工具。當 LLDP 缺失時，FDB 中的 MAC 位址必須符合 Nautobot 中記錄的 MAC 位址。

6. **`validate_connections` — 比對預期與實際狀態並產生報告。**

   合併上述三種資料來源，分類每一種介面不一致處（連結中斷、錯誤的鄰近裝置、未找到鄰近裝置、非預期的連線），將發現的結果標記上各個執行批次間不變的穩定 `ID` 雜湊值，並格式化為單一裝置的 Markdown 報告。此階段無法重試，若驗證邏輯發生異常，執行會直接宣告失敗，避免將真實的 Bug 隱藏在重試機制之後。

工作流的最終輸出為 `DeviceCableValidationResult`，其 `interfaces` 欄位會將每個異常的介面名稱與其發現進行對應。

## 判讀報告 (Interpreting the report)

### 實際 vs 預期 (Actual vs. Intended)

報告中的結果會顯示正在驗證的裝置/連接埠對（Start Device/Port），以及預期連接（基於 Nautobot 中的設定）與在裝置上實際觀測到的連接之間的對比。

### 問題 (Issue)

不一致處的類別 — 請參閱下方的 [佈線驗證問題](#佈線驗證問題) 以瞭解完整目錄。

### 疑難排解資訊 (Troubleshooting Info)

選填的欄位，包含裝置提供關於此連結的任何額外資訊，可協助維運人員診斷問題。此資訊完全取決於被驗證的裝置，但通常很有幫助（例如指出連接埠未插入纜線或光纖，或是已插線但無光訊號）。請參閱裝置文件以取得這些訊息的進一步協助。

### ID 欄位 (ID Field)

報告中特定欄位的雜湊值，在多次報告中會保持不變。由於每個（起始裝置、起始連接埠、目標裝置、目標連接埠）群組的 ID 保持一致，這有助於追蹤在多次執行之間已被修復的問題。

### CSV 報告 (CSV Report)

結果頁面中包含下載 CSV 報告的連結。如果結果集太大而無法在 UI 中顯示，CSV 仍會包含完整的結果。

## 佈線驗證問題 (Cable validation issues)

可能的驗證失敗類型如下：

**`Link is down (連結中斷)`**

預期應存在且連通的連結實際上處於關閉狀態。可能是纜線/光纖損壞，或是連結的其中一端被停用了。

**`Incorrect cabling, actual should match intended (佈線錯誤，實際應與預期相符)`**

在 Nautobot 中規劃的佈線與網路上發現的實際狀態不符。這可能是因為：

* **LLDP 數據**：實體佈線與 Nautobot 中規劃的架構不符。
* **MAC 位址**：在交換器 FDB 中看見的 MAC 位址與 Nautobot 中的預期 MAC 不符。可能是 Nautobot 中的 MAC 記錄錯誤，或是實體線路接錯。這通常在 LLDP 不可用（例如 IPMI/BMC 連線）時作為驗證依據。

**`Link is up, but no neighbor found (連結已連線但未找到鄰近裝置)`**

連結已通，但未找到 LLDP 鄰近裝置或 MAC 位址，因此無法完成驗證。重試驗證可能會解決此問題。如果問題持續，請檢查兩端裝置的狀態，以確定它們未能正常運作的原因。當線路規格不符導致光衰（low-light condition）時也可能出現此錯誤。

**`Unexpected connection found (發現非預期的連線)`**

發現了未在 Nautobot 中規劃的鄰近裝置。這可能表示 Nautobot 資料已過期，或是該連線超出了 Config Manager 驗證的範圍（常見於站點的自訂線路或與非 Nautobot 管理裝置的連線）。

如果 Nautobot 中存在不需驗證的連線，請在這些介面加上 `cable-validation-ignore` 標籤，然後重新執行佈線驗證工作流以取得乾淨的報告。

## 常見問題與疑難排解 (Common issues and troubleshooting)

**一台或多台裝置顯示為失敗（failed）。**

裝置失敗代表該裝置的子工作流本身出錯 — 通常是因為無法透過管理 IP 連線至裝置，或是其主機名稱與 Nautobot 不符。該裝置的檢驗發現會被排除在報告之外；請修正底層問題，然後重新執行站點工作流，或針對該裝置執行特定的裝置佈線驗證。結果頁面會分開列出無法連線的裝置，並在報告中排除其結果。

**主機名稱驗證失敗。**

裝置上設定的主機名稱與 Nautobot 不符。可能是裝置在 Nautobot 中被重新命名但尚未重新套用組態，或者是您對錯誤的裝置執行了驗證。請協調兩端的名稱（通常是透過重新渲染並重新套用裝置的組態），然後重新執行。

**`get_device_actual_neighbors` 或 `get_device_mac_table` 階段失敗。**

裝置無法連線、管理憑證錯誤，或者裝置處於不支援的平台上。確認裝置可透過其管理 IP 連線、ZTP 已完成，且 Nautobot 中的平台（platform）欄位設定正確。如果裝置剛完成置備，請給 LLDP 一到兩分鐘的時間來載入資料，然後再重試。

**報告中針對同一個連結顯示重複的發現。**

在可能的情況下，驗證會從連結의 兩端分別執行。雖然已套用部分去重機制，但雙方仍可能對同一條線路報告不同的錯誤。請將其視為單一實體問題，一次解決即可。

**多次執行時，同一個連接埠報告不同的 MAC 位址。**

不穩定的 FDB 通常代表連結的其中一端裝置運作異常 — 請調查鄰近的交換器或主機，而非盲目重試驗證。

**伺服器連結在多次執行之間發生閃斷（flapping）。**

若伺服器在部分置備的站點中卡在 PXE 開機迴圈中，可能會頻繁變更 LLDP/MAC 狀態。在伺服器端置備完成前，請在 Leaf 交換器端的介面加上 `cable-validation-ignore` 標籤，完成後再移除標籤。在 InfiniBand 站點上，伺服器連結超出此處的範圍，它們會由另一個獨立的工作流進行驗證。

**多個連結上顯示 `Link is up, but no neighbor found`。**

這些介面的 LLDP 和 FDB 皆為空。請先嘗試重試工作流 — 在連接埠閃斷後，LLDP 可能會短暫遺失鄰近裝置。如果問題持續存在，請檢查每個連結對端的鄰近裝置；未送電或設定錯誤的鄰近裝置是最常見的原因。在裝置工作流中將 `Ignore No Neighbor` 設定為 true 可以從報告中隱藏這些錯誤，這在部分啟用時是適當的，但不應作為預設設定。

**驗證發現了合理但超出範圍的非預期連線。**

對於存在於 Nautobot 中但不需要進行驗證的連線（自訂站點佈線、非 Nautobot 管理的鄰近裝置），請在這些介面上附加 `cable-validation-ignore` 標籤並重新執行以取得乾淨的報告。

## 相關指南 (Related guides)

* [新站點啟用](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/new-site-bringup) — 包含在站點交付過程中執行站點佈線驗證的啟用程序。
* [已連線主機中繼資料](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/validation/connected-host-metadata) — 在不執行驗證的情況下，透過 LLDP + FDB 探索連接至交換器的裝置。
* [硬體驗證](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/validation/hardware-validation) — 用於硬體健康狀態的同類型站點級驗證。
* [網路拓撲要求](https://docs.nvidia.com/switch-infrastructure/config-manager/deployment/network-topology-requirements) — 驗證機制所遵循的拓撲與佈線約束。
