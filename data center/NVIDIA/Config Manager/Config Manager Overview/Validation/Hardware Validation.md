# Cumulus Hardware Validation

硬體驗證（Hardware Validation）工作流用於對站點內的 Cumulus Linux 網路裝置進行健康檢查。它會平行收集每台裝置的平台、環境與庫存資料，並將結果彙整為單一的 Excel 報告。這是在整批交換器中探索硬體問題（例如風扇故障、電源供應器 PSU 損壞、電壓異常、狀態 LED 燈非綠色以及非預期的硬體庫存）的標準工具，維運人員無須手動登入每台裝置進行檢查。

該工作流會直接針對 Nautobot 中已登錄的裝置執行完整流程，不需要手動輸入每台裝置的資訊。

## 前提條件 (Prerequisites)

在執行硬體驗證之前，請確認以下各項已就緒：

* **裝置已存在於 Nautobot 中**，且其平台（platform）設定為 Cumulus Linux 相關值、具有主要 IPv4 位址，以及任何必要的組態上下文（config contexts）。工作流會將目標清單篩選為 Cumulus 裝置，非 Cumulus 平台的裝置將會被自動跳過。
* **裝置為可連線狀態**：可從 Config Manager 透過管理網路連線至裝置，且金鑰儲存庫中存在該站點的憑證。每個收集器會透過裝置的管理 API 使用 NVUE / NV CLI 來讀取平台與環境資料。
* **裝置已完成置備。** 收集器預期與已完成設定的裝置進行通訊。仍在 ZTP 階段、處於維護狀態且管理介面關閉，或因其他原因無法連線的裝置，將會傳回錯誤而非結果，並顯示在報告的錯誤區段中。
* **已確認篩選條件。** 您需要指定站點、租戶，以及要包含的角色、狀態和（選填）裝置類型。這些是 Config Manager 工作流中通用的標準 Nautobot 篩選欄位。

## 執行工作流 (Running the workflow)

1. 導覽至您環境的 Config Manager URL。
2. 點擊右上角的 **+** 並選擇 **ValidateHardwareWorkflow**。
3. 參考下方欄位說明填寫表單並提交。

| 欄位 | 說明 | 是否必填 |
| :--- | :--- | :--- |
| **Site (站點)** | 要驗證的站點。 | 是 |
| **Roles (角色)** | 要包含的裝置角色（可多選）。 | 是 |
| **Device Status (裝置狀態)** | 要包含的裝置狀態（可多選）。通常為 `Provisioned`。 | 是 |
| **Tenant (租戶)** | 執行此流程的 Nautobot 租戶。 | 是 |

提交後，系統會顯示一個狀態頁面，呈現各個階段的執行狀況。六個資料收集階段會針對範圍內的所有裝置平行執行，因此總執行時間大約等於最慢裝置的資料收集時間加上報告生成階段的時間，一般規模的站點通常只需幾分鐘。

## 檢查項目 (What gets checked)

六個收集器階段分別查詢裝置上不同的 NVUE / NV CLI 端點。除了 `ok` 以外的狀態值（或就 LED 而言，除了 `green` 以外的顏色）都會在各階段的畫面中被標記，並呈現在彙整報告中。

* **Device info (裝置資訊)**：自 Nautobot 提取。提供裝置名稱、機櫃、機櫃位置、角色與平台，用於標示報告中的每一列。
* **Platform (平台)**：使用 `nv show platform`。包含型號、序號、ASIC、系統記憶體及其他頂層平台屬性。
* **Fan (風扇)**：使用 `nv show platform environment fan`。包含每個風扇的狀態、轉速與最小/最大臨界值。任何未報告 `ok` 的風扇都會被標記。
* **LED (指示燈)**：使用 `nv show platform environment led`。包含每個 LED 的顏色。任何非 `green` 的顏色（通常是代表硬體故障的黃色/紅色）都會被標記。
* **PSU (電源供應器)**：使用 `nv show platform environment psu`。包含每個 PSU 的狀態與電器讀數。非 `ok` 的狀態（如故障、缺失、未送電）會被標記。
* **Voltage (電壓)**：使用 `nv show platform environment voltage`。包含每個電壓軌（rail）的電壓量測值以及最小/最大臨界值。超出範圍的電壓軌會以實際值/最小值/最大值等詳細資訊進行標記。
* **Inventory (硬體清冊)**：使用 `nv show platform inventory`。包含裝置上的光纖模組、模組及其他現場可更換單元（FRU）。

## 執行階段 (Execution stages)

該工作流定義了九個階段。前兩個階段循序執行以建立裝置集合；接著六個收集器平行執行；最後報告生成階段會等待這六個收集器全部完成。所有階段皆不需要人工審核。

1. **`get_devices_to_validate` — 依篩選條件查詢裝置。**

   使用提供的站點、租戶、角色、狀態和裝置類型 ID 呼叫 Nautobot，然後過濾出平台欄位包含 `cumulus` 的裝置。畫面上會報告找到了多少台 Cumulus Linux 裝置。

2. **`get_device_info` — 依 ID 索引裝置記錄。**

   建立裝置 ID 對應至 Nautobot 裝置資料的記憶體內對照表，供各個收集器階段迭代使用。

3. **`get_platform` — 收集平台資訊。**

   平行對每台裝置執行平台查詢，記錄裝置名稱、型號、序號與平台屬性。

4. **`get_environment_fan` — 收集風扇狀態。**

   收集每個風扇的狀態、轉速與臨界值，並標記非 `ok` 的風扇。

5. **`get_environment_led` — 收集 LED 狀態。**

   收集每個 LED 的顏色，並標記非 `green` 的 LED。

6. **`get_environment_psu` — 收集 PSU 狀態。**

   收集每個 PSU 的狀態與電器讀數，並標記非 `ok` 的 PSU。

7. **`get_environment_voltage` — 收集電壓讀數。**

   收集每個電壓軌的電壓與最小/最大臨界值，並標記超出範圍的讀數。

8. **`get_inventory` — 收集硬體清冊。**

   收集每台裝置上存在的光纖模組、模組及其他可更換零件。

9. **`generate_consolidated_report` — 建立 Excel 彙整報告。**

   將所有收集器的輸出合併為一個活頁簿（每個類別一張工作表），並在工作流狀態頁面上提供可下載的附件。

每個收集器活動具有 30 秒的超時時間，且在發生暫時性錯誤時最多重試 5 次。若裝置在特定收集器上所有重試均宣告失敗，該裝置會顯示在該階段的錯誤區段中，但不會阻礙工作流其餘部分的執行。

## 判讀彙整報告 (Interpreting the consolidated report)

最終階段會在工作流狀態頁面附加一個 Excel 活頁簿。該活頁簿為每個收集器類別設有一個工作表（Platform、Fan、LED、PSU、Voltage、Inventory）。每個工作表的前三欄完全相同 — **Device name (裝置名稱)**、**Rack name (機櫃名稱)**、**Rack position (機櫃位置)** — 後面接著是類別特定的欄位，且每個欄位皆已啟用自動篩選（AutoFilters），讓您無須使用其他工具即可直接進行排序或篩選。

**若要快速檢視新執行的結果：**

* **在 LED 工作表上篩選「Color」**，尋找任何非 `green` 的欄位。
* **在 Fan、PSU 和 Voltage 工作表上篩選「State」**，尋找任何非 `ok` 的欄位。對於電壓，Actual/Min/Max 欄位會顯示該電壓軌超出範圍的幅度。
* **比對 Inventory 工作表** 與站點的物料清單（BOM），缺失的光纖或模組會呈現在此處。
* **將被標記的資料列與工作流狀態頁面上的「各階段顯示畫面」進行交叉比對。** 階段畫面已依裝置將標記進行分組，並包含機櫃名稱和機櫃位置，使機房維運人員的現場排查（DC Ops walk-down）變得非常直接。

每個收集器階段的顯示畫面也會在最上方呈現三個錯誤分組：**Unsupported endpoints (不支援的端點)**（裝置未實作該 NVUE / NV CLI 端點）、**Connectivity issues (連線問題)**（裝置無法連線）以及 **Other errors (其他錯誤)**（其他所有錯誤）。屬於這些分組的裝置將會從該類別的工作表中排除 — 請在底層問題修復後，僅針對這些裝置重新執行工作流。

## 常見問題 (Common issues)

**未找到任何裝置。**

篩選器未傳回任何 Cumulus Linux 裝置。請確認站點、租戶、角色與狀態與 Nautobot 中的資料相符，且裝置的平台（platform）欄位已填入 Cumulus 相關值。其他網路作業系統（NOS）平台的裝置會被刻意跳過。

**收集器回報部分裝置有 `Unsupported endpoints (不支援的端點)`。**

較舊的 Cumulus 版本（or 特定硬體平台）未實作收集器所呼叫的所有 NVUE 端點。這些裝置在支援的類別中會正常成功，並在此處未支援的類別中浮現。如果需要缺失的資料，請將裝置升級至支援的 Cumulus Linux 版本。

**收集器回報部分裝置有 `Connectivity issues (連線問題)`。**

在執行期間，無法從 Config Manager 透過管理網路連線至該裝置。待裝置恢復連線後，重新執行工作流即可；若問題持續，請排查連線與憑證問題。請參閱《新站點啟用》指南中的 [監控 DHCP 與 ZTP](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/new-site-bringup#monitoring-dhcp-and-ztp) 區段，以取得正規的疑難排解流程。

**被標記的硬體異常最後證實為誤報（false positive）。**

請先重新執行工作流；暫時性的感測器讀數偶爾會觸發臨界值警報。如果電壓軌或風扇持續被標記，請登入裝置並以互動方式重新執行底層的 `nv show platform environment ...` 指令，在向廠商申請 RMA 換修之前確認讀數。

**報告階段缺失 Excel 附件。**

在收集器執行成功後，報告生成階段失敗 — 收集器的資料在每個階段的顯示畫面上仍清晰可見。此時可以僅重新執行報告階段，或是重新執行完整工作流；收集器為唯讀操作，重複執行非常安全。

## 相關指南 (Related guides)

* [新站點啟用](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/new-site-bringup) — 完整的啟用程序；硬體驗證是繼佈線驗證之後，最終的硬體錯誤檢查步驟。
* [佈線驗證](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/validation/cable-validation) — 同屬驗證類型的工作流，用於比對佈線是否符合 Nautobot 中規劃的預期拓撲。

---

## 重點整理

本篇說明了針對運行 Cumulus Linux 的裝置進行自動化硬體健康檢查的工作流（Hardware Validation），其核心要點如下：

1. **核心功能與整合**：
   - 使用 `NVUE` / `NV CLI`（透過管理 API）平行收集全網 Cumulus 交換器的平台、環境與硬體清冊資料，並自動將其彙總至單一 Excel 報告中。
   - 可有效找出風扇故障、PSU 毀損、電壓異常、LED 警示燈異常（非綠色）及光纖模組缺失等硬體狀況。

2. **檢查項目與平行執行**：
   - 階段共分為九個：前兩個確認裝置集（篩選 `cumulus` 平台裝置）；隨後六個收集器平行執行（收集 Platform, Fan, LED, PSU, Voltage, Inventory 資訊）；最後一階段彙整產生 Excel 活頁簿。
   - 所有收集器皆具備 30 秒超時與 5 次重試機制，個別交換器連線失敗不會中斷其他裝置的檢驗。

3. **報告解讀與錯誤分組**：
   - 生成的 Excel 檔案預設啟用自動篩選（AutoFilters），前三欄均為裝置名稱、機櫃名稱及機櫃位置，極大簡化了機房維運人員現場排查（DC Ops walk-down）的難度。
   - 收集器會將無法順利收集的裝置分流為三個錯誤群組：不支援的端點、連線問題與其他錯誤，避免混淆正常的硬體警告。
