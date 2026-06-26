# Configuration Management

NVIDIA Config Manager 將裝置組態儲存在 [Config Store 服務](https://docs.nvidia.com/switch-infrastructure/config-manager/services/config-store/overview)。Config Manager 使用版本控制的範本以及來自 Nautobot 的裝置資料，[渲染](https://docs.nvidia.com/switch-infrastructure/config-manager/services/render/overview) 每台裝置的組態。接著，它會將預期組態（intended configuration）寫入 Config Store 服務。當裝置開機時，Config Manager 會從 Config Store 服務中檢索預期組態，並透過 [Temporal 工作流](https://docs.nvidia.com/switch-infrastructure/config-manager/services/temporal/overview)（或在 Day Zero 時透過 [ZTP](https://docs.nvidia.com/switch-infrastructure/config-manager/services/network-ztp/overview)）將其套用至該裝置。

Config Store 介面提供了預期組態與備份組態的比較檢視畫面：

* **差異統計 (Diff statistics)**：新增與刪除的行數統計。
* **並排比較 (Side-by-side comparison)**：舊組態與新組態的比對。
* **以顏色區分的變更 (Color-coded changes)**：標示哪些行被新增、刪除或保持不變。

## 範例組態檔案 (Example Configuration Files)

### boot-script

* 執行作業系統/韌體升級。
* 將預期組態載入至裝置。
* 載入任何額外的檔案/服務（例如 node exporter）。
* 成功時向主控端回報（phones home）。

### 預期組態 (Intended Configuration)

裝置運行中的網路組態為供應商特定的格式，可能包含以下資訊：

* 介面定義 (Interface definitions)
* 位址分配 (Addressing)
* 服務設定 (Services configuration)
* 平台設定 (Platform settings)
* BGP 路由實例 (BGP routing instances)
* 自治系統設定 (Autonomous system configuration)
* 路由器 ID 設定 (Router ID settings)
* VRF 定義 (VRF definitions)
* 來源介面 (Source interfaces)
* ACL 設定 (ACL configurations)

## 檔案詮釋資料 (File Metadata)

每個組態檔案都會追蹤：

* **Version (版本)**：語意化版本號（例如 v3）。
* **Author (作者)**：進行變更的使用者。
* **Modified (修改時間)**：上次修改的時間戳記。
* **Hash (雜湊值)**：用於驗證的 Git 提交雜湊值（commit hash）。
* **Commit message (提交訊息)**：包含以下之一：
  * Nautobot 物件被何人修改的說明。
  * 範本版本變更以及用於渲染的版本。
  * 手動觸發渲染時由使用者產生的提交訊息。

## 範本變更部署 (Template Change Deployment)

1. 將範本變更提交至 Git。
2. Render Service 使用新的範本版本重新生成所有組態。
3. 工作流引擎（Workflow engine）編排部署流程。
4. 將變更套用至裝置。
5. 備份工作流擷取新的裝置狀態。

---

## 重點整理

本篇介紹了 NVIDIA Config Manager 的組態管理機制，核心重點如下：

1. **組態渲染與儲存流程**：
   - 使用 Nautobot 的裝置資料與版本控制的 Jinja2 範本進行每台裝置的組態渲染。
   - 渲染後的預期組態（Intended Configuration）會存儲在 PostgreSQL 後端的 Config Store 服務中。
   - 裝置開機時或進行 Day Two 變更時，透過 Temporal 工作流將組態套用至裝置。

2. **版本控制與可追蹤性**：
   - 每個組態檔案均追蹤詳細的詮釋資料 (Metadata)，如語意化版本、作者、修改時間、Git commit 雜湊值與詳細的提交訊息（例如誰修改了 Nautobot 的哪個物件）。
   - 提供直觀的組態比對介面（如行數統計、並排比對、顏色標示差異），方便稽核變更。

3. **範本變更的部署生命週期**：
   - Git 範本變更提交 ➡️ Render Service 重新渲染所有設定 ➡️ 工作流引擎部署 ➡️ 裝置套用 ➡️ 備份工作流備份新狀態。
