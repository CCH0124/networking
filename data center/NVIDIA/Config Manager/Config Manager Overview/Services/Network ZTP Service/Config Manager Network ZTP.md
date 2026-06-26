# Config Manager Network ZTP

NVIDIA Config Manager Network ZTP 服務是一個 FastAPI 應用程式，在零接觸部署（Zero Touch Provisioning, ZTP）期間為網路裝置提供引導指令碼（boot scripts）、已渲染的組態以及韌體映像檔。

零接觸部署 (ZTP) 是一種無需人工介入即可自動設定與部署網路裝置的方法。當新裝置開機時，它會自動從中央伺服器檢索其組態、韌體和引導指令碼，從而實現快速部署並確保整個網路基礎設施中的組態一致性。

Config Manager Network ZTP 伺服器是一個 REST API 服務，旨在促進網路裝置的零接觸部署。它作為裝置檢索以下內容的中央控制點：

* **Boot scripts** - 引導裝置完成置備（provisioning）流程的初始化指令碼
* **Configuration files** - 從範本渲染而成的特定裝置組態
* **Firmware images** - 裝置運作所需的平台特定韌體版本

ZTP 伺服器與 Nautobot 整合以進行裝置管理，確保僅有獲得授權的裝置能夠存取其組態，並在整個置備過程中正確追蹤裝置的狀態。

## 關鍵特色 (Key Features)

**自動化裝置置備 (Automated Device Provisioning)**：

* 裝置在首次開機時會自動檢索其引導指令碼、組態與韌體。
* 裝置本身無須進行任何手動設定。
* 確保所有裝置的組態一致性。

**安全性 (Security)**：

* **裝置與使用者授權** - 裝置發送的要求必須來自已註冊的 IP 位址；當啟用單一登入（SSO）時，使用者要求必須以已驗證使用者身分通過 Envoy 閘道
* **序號驗證** - 裝置在置備前必須先驗證其序號
* **安全檔案傳輸** - 所有檔案傳輸均使用 HTTPS 並進行總和檢查碼（checksum）驗證

**與 Nautobot 整合 (Integration with Nautobot)**：

* 在 Nautobot 中管理裝置資訊與 IP 位址。
* ZTP 成功完成後，裝置狀態會自動更新為 `Provisioned`。
* 從裝置的組態上下文（config context）中檢索指定的韌體版本。

**彈性的檔案管理 (Flexible File Management)**：

* 依平台與版本組織韌體檔案。
* 支援多種檔案類型（韌體映像檔、安裝程式、組態檔案）。
* 所有檔案皆進行 SHA256 總和檢查碼驗證。
* 針對大型韌體檔案提供高效的串流傳輸（streaming）。

---

## 開始使用 (Getting Started)

### 前提條件 (Prerequisites)

在使用 ZTP 伺服器前，請確保：

1. **裝置註冊** - 裝置已在 Nautobot 中註冊，並包含：
   * 裝置 UUID
   * 裝置序號
   * IP 位址
   * 平台資訊
   * 韌體版本（於組態上下文中指定）

2. **網路設定** - DHCP 伺服器已設定為提供：
   * IP 位址分配
   * 指向 ZTP 伺服器的引導檔案 URL (Boot file URL)

3. **韌體可用性** - 已將適用於您裝置平台的韌體映像檔上傳至 ZTP 伺服器。

### 快速入門 (Quick Start)

1. **檢視 API 說明文件** - 熟悉可用的端點。
   * 請參閱 [API 說明文件](https://docs.nvidia.com/switch-infrastructure/config-manager/services/network-ztp/ztp-api) 以取得完整的端點參考。

2. **設定您的裝置** - 設定 DHCP 與裝置註冊。
   * 請參閱 [設定指南](https://docs.nvidia.com/switch-infrastructure/config-manager/services/network-ztp/configuration) 以瞭解詳細的設定說明。

3. **測試置備** - 部署一台測試裝置以驗證設定。
   * 監控裝置日誌與 ZTP 伺服器的回應。
   * 驗證 Nautobot 中的裝置狀態更新（例如，ZTP 完成後狀態變更為 `Provisioned`）。

4. **部署至生產環境** - 擴展至生產環境裝置。
   * 確保適當的網路安全性。
   * 監控置備成功率。
   * 設定失敗時的告警機制。

---

## 運作原理 (How It Works)

### 置備工作流 (Provisioning Workflow)

1. **裝置開機** - 一台新的網路裝置開機，並透過 DHCP 請求網路設定。
2. **DHCP 回應** - DHCP 伺服器為該裝置提供一個 IP 位址與 ZTP 引導檔案 URL。
3. **下載引導指令碼** - 裝置自 ZTP 伺服器下載其引導指令碼。
4. **下載韌體** - 裝置下載適用於其平台的韌體映像檔。
5. **載入組態** - 裝置檢索並套用其組態檔案。
6. **序號驗證** - 裝置驗證其序號是否符合 Nautobot 中的記錄。
7. **置備完成** - 裝置將自己標記為已置備（provisioned），並觸發備份工作流。

### 授權模型 (Authorization Model)

ZTP 伺服器接受來自已註冊裝置的裝置端點要求；若啟用了單一登入（SSO），則接受經由 Envoy 閘道通過身分驗證之使用者的要求：

* 源自裝置的要求，其發送 IP 位址必須與 Nautobot 中該裝置註冊的 IP 一致。
* 源自使用者的要求，若部署啟用了 SSO，必須透過 Envoy 閘道作為已驗證的使用者傳入。
* 管理（Admin）端點要求必須經過身分驗證的使用者才能存取。

---

## 使用場景 (Use Cases)

### 新裝置部署 (New Device Deployment)

部署新網路裝置時：

1. 在 Nautobot 中註冊裝置，並填入其 IP 位址與平台資訊。
2. 設定 DHCP 伺服器以提供 ZTP 引導檔案 URL。
3. 將裝置送電開機 — 它將會自動完成置備。

### 韌體更新 (Firmware Updates)

要更新裝置韌體：

1. 將新的韌體映像檔上傳至 ZTP 伺服器 — 請參閱 [上傳映像檔至 ZTP 伺服器](https://docs.nvidia.com/switch-infrastructure/config-manager/services/network-ztp/upload-images)。
2. 在 Nautobot 組態上下文中更新裝置的韌體版本。
3. 重新啟動裝置 — 它將會自動下載並安裝新韌體。

### 組態更新 (Configuration Updates)

要更新裝置組態：

1. 在組態儲存庫（configuration store）中更新組態範本。
2. 重新啟動裝置或觸發組態重新載入（configuration reload）。
3. 裝置會自動檢索並套用更新後的組態。

---

## 後續步驟 (Next Steps)

1. **閱讀 API 說明文件** — 瞭解可用的端點及使用方式。
2. **檢閱設定指南** — 學習如何為 ZTP 設定裝置。
3. **探索系統架構** — 瞭解系統內部的運作方式。
4. **開始置備** — 開始使用 ZTP 部署裝置。

* [設定](https://docs.nvidia.com/switch-infrastructure/config-manager/services/network-ztp/configuration)
* [上傳映像檔至 ZTP 伺服器](https://docs.nvidia.com/switch-infrastructure/config-manager/services/network-ztp/upload-images)
* [架構](https://docs.nvidia.com/switch-infrastructure/config-manager/services/network-ztp/architecture)
* [API 參考資料](api:ztp-api)

---

## 重點整理

本篇介紹了 NVIDIA Config Manager Network ZTP（零接觸部署服務），其核心要點如下：

1. **服務定位與提供內容**：
   - 作為 FastAPI 應用程式運行的 REST API 服務，專門在裝置引導開機時提供：引導指令碼（Boot scripts）、預先渲染好的組態（Configuration files）與平台所屬的韌體映像檔（Firmware images）。

2. **工作流與整合**：
   - 裝置開機 ➡️ DHCP 指引 ZTP URL ➡️ 下載引導指令碼 ➡️ 下載對應韌體 ➡️ 載入預期組態 ➡️ 驗證設備序號 ➡️ 置備完成。
   - 與 Nautobot 深度整合：ZTP 完成後，裝置狀態會自動在 Nautobot 中由 ZTP 更新為 `Provisioned`；韌體版本資訊也是從 Nautobot 的組態上下文（config context）中讀取。

3. **安全授權機制**：
   - **來源 IP 驗證**：源自裝置的要求，發送 IP 必須與 Nautobot 中註冊的裝置管理 IP 相符。
   - **使用者身分驗證**：管理（Admin）端點與非裝置的要求，必須通過 Envoy 閘道進行身分驗證（支援單一登入 SSO）。
   - **傳輸與校驗**：使用 HTTPS 進行安全傳輸，並強制使用 SHA256 總和檢查碼進行完整性校驗。
