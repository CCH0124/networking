# Redfish Workflow (Redfish 工作流程)

NICo 使用 [DMTF Redfish](https://www.dmtf.org/standards/redfish) 透過 BMC（基板管理控制器）介面來發現、建置與監控裸金屬主機及其 DPU。本文件追蹤了從初始 DHCP 發現到持續監控的端對端工作流程。

如需瞭解 NICo 的整體架構與組件職責，請參閱 [Overview and components](https://docs.nvidia.com/infra-controller/documentation/architecture/overview-and-components) 頁面。該頁面中描述的 Site Explorer 組件是 Redfish API 的主要取用端。

---

## 工作流程摘要 (Workflow Summary)

```
DHCP 請求 (BMC)
  → NICo DHCP (Kea 鉤子)
    → NICo Core (gRPC discover_dhcp)
      → Site Explorer 探測 Redfish 端點
        → 進行身分驗證、收集硬體清單
          → 透過序號比對將 DPU 與主機配對
            → 資源建置（Provisioning）：
               1. 將 DPU 啟動設定為 HTTP IPv4 UEFI
               2. 透過 Redfish 重啟 DPU 電源
               3. DPU 透過 PXE 啟動 nico.efi
               4. BIOS 組態設定（SR-IOV 等）
               5. 設定主機啟動順序（DPU 優先）
               6. 透過 Redfish 重啟主機電源
            → 持續監控：
               - 韌體清單（定期）
               - 感測器資料收集（每 60 秒）
               - 匯出 Prometheus 指標
```

---

## 1. DHCP 發現 (DHCP Discovery)

當 Underlay 底層網路上的 BMC 發送 DHCP 請求時，NICo DHCP 伺服器（一個 Kea 鉤子外掛程式）會擷取該請求並將發現資訊轉發給 NICo Core。

Kea 鉤子（Kea hook）被實現為一個具有 C FFI 綁定的 Rust 程式庫。當 DHCP 封包到達時，該鉤子會：

1.  從 DHCP 封包中提取 MAC 位址、廠商類別字串（Vendor class string）、中繼位址、電路 ID（Circuit ID）以及遠端 ID。
2.  使用這些欄位建立一個 `Discovery` 結構。
3.  向 NICo Core 發送一個帶有 MAC 和廠商字串的 gRPC `discover_dhcp()` 請求。
4.  接收回傳的 `Machine` 回應，其中包含要返回給 BMC 的網路組態設定（IP 位址、閘道器等）。

系統會解析廠商類別字串以識別 BMC 類型和功能。DHCP 記錄會在資料庫中透過 MAC 位址進行追蹤，並與機器介面相關聯。

**關鍵檔案：**
*   `crates/dhcp/src/discovery.rs` — `Discovery` 結構和 FFI 入口點（`discovery_fetch_machine`）
*   `crates/dhcp/src/machine.rs` — `Machine::try_fetch()` 用於發送 gRPC 發現請求
*   `crates/dhcp/src/vendor_class.rs` — 廠商類別解析與 BMC 類型識別
*   `crates/api-model/src/dhcp_entry.rs` — `DhcpEntry` 資料庫模型

---

## 2. Redfish 端點探測與硬體清單 (Redfish Endpoint Probing and Inventory)

一旦 NICo 透過 DHCP 得知 BMC IP，Site Explorer 組件就會持續透過 Redfish 對其進行探測和盤點。

### 探測 (Probing)

Site Explorer 首先向 `/redfish/v1`（Redfish 服務根目錄）發送一個匿名（未經身分驗證）的 GET 請求，以偵測 BMC 廠商。`RedfishVendor` 列舉（Enum）會從服務根目錄回應中識別廠商，從而決定後續操作中特定廠商的行為。

### 身分驗證 (Authentication)

偵測到廠商後，Site Explorer 會使用以下三種方法之一建立經過身分驗證的 Redfish 工作階段：

*   **匿名 (Anonymous)** — 僅用於初始探測。
*   **直接 (Direct)** — 來自預期機器清單（Expected Machines Manifest）的使用者名稱/密碼（出廠預設值）。
*   **金鑰 (Key)** — 透過 BMC MAC 位址進行憑證金鑰查詢（在憑證輪替之後）。

### 硬體清單收集 (Inventory Collection)

建立安全工作階段後，Site Explorer 會查詢一組完整的 Redfish 資源，並產生包含以下內容的 `EndpointExplorationReport`：

| 收集的資料 | Redfish 來源 | 用途 |
|---|---|---|
| 系統序號 | `GET /redfish/v1/Systems/{id}` | 機器識別 |
| 機箱序號 | `GET /redfish/v1/Chassis/{id}` | 備用識別 |
| 網路介面卡與序號 | `GET /redfish/v1/Chassis/{id}/NetworkAdapters` | DPU 與主機配對 |
| PCIe 裝置與序號 | `GET /redfish/v1/Systems/{id}` (PCIeDevices) | DPU 與主機配對 |
| 管理員資訊 | `GET /redfish/v1/Managers/{id}` | BMC 韌體版本 |
| 乙太網路介面 | `GET /redfish/v1/Managers/{id}/EthernetInterfaces` | BMC 網路資訊 |
| 韌體版本 | `GET /redfish/v1/UpdateService/FirmwareInventory` | 版本追蹤 |
| 啟動組態設定 | `GET /redfish/v1/Systems/{id}/BootOptions` | 啟動順序狀態 |
| 電源狀態 | `GET /redfish/v1/Systems/{id}` (PowerState) | 目前狀態 |

序號會被修剪掉首尾空白。如果遺失 `system.serial_number`，則會使用機箱序號作為備用。

**關鍵檔案：**
*   `crates/site-explorer/src/redfish.rs` — `RedfishClient`：`get_redfish_vendor()`、`create_redfish_client()`、硬體清單查詢
*   `crates/site-explorer/src/bmc_endpoint_explorer.rs` — `BmcEndpointExplorer` 協調整合憑證查詢和探測
*   `crates/api-model/src/bmc_info.rs` — `BmcInfo` 模型（IP、連接埠、MAC、韌體版本）

---

## 3. DPU 與主機配對 (DPU-Host Pairing)

當 Site Explorer 探測完主機 BMC 和 DPU BMC 後，它會使用序號關聯將它們配對成「主機-DPU 對」。這是回答「哪個 DPU 屬於哪台主機？」的核心邏輯。

### 配對演算法 (Matching Algorithm)

此演算法有三種策略，並依序嘗試：

**步驟 1 — 建立 DPU 序號對照表：**
對於每個已探測的 DPU 端點，提取其 `system.serial_number` 並建立對照表：`DPU 序號 → 已探測端點`。

**步驟 2 — 透過 PCIe 裝置進行主要配對：**
對於每台主機，反覆運算其 `system.pcie_devices`。對於 `is_bluefield()` 回傳為真的每個裝置（BF2、BF3 或 BF3 Super NIC），在 DPU 序號對照表中尋找 `pcie_device.serial_number`。若是匹配，則表示此 DPU 實體安裝在該主機中。

**步驟 3 — 透過機箱網路介面卡進行備用配對：**
若未發現任何 BlueField PCIe 裝置（步驟 2 匹配數為 0），則反覆運算 `chassis.network_adapters`。對於 `is_bluefield_model(part_number)` 為真的每個介面卡，在 DPU 序號對照表中尋找 `network_adapter.serial_number`。

**步驟 4 — 透過預期機器清單進行最終備用配對：**
如果探測到的配對不完整，檢查 `expected_machine.fallback_dpu_serial_numbers` 以獲取手動指定的主機對 DPU 關聯。

### 驗證 (Validation)

在接受配對之前，NICo 會驗證：
*   **DPU 模式**：DPU 必須處於 DPU 模式，而非 NIC 模式。處於 NIC 模式的 BlueField 會被排除在配對之外。
*   **DPU 型號組態設定**：`check_and_configure_dpu_mode()` 驗證 DPU 是否針對其型號進行了正確設定。配備錯誤設定 DPU 的主機將不會被接入。
*   **完整性**：探測到的 DPU 數量必須與主機回報的 BlueField 裝置數量一致。不完整的配對將會被延遲處理。

### 接入 (Ingestion)

一旦所有 DPU 匹配並驗證完畢，主機即進入「可接入」狀態，Site Explorer 會透過 ManagedHost 狀態機啟動接入流程。

**關鍵檔案：**
*   `crates/site-explorer/src/lib.rs` — `identify_managed_hosts()` 包含完整的配對演算法

---

## 4. DPU 資源建置 (DPU Provisioning)

配對完成後，必須為 DPU 建置 NICo 軟體。這是透過 Temporal 工作流程（位於 `nico-rest` 中）以及 Redfish 電源控制（位於 `infra-controller` 中）協調整合而成。

### 啟動組態設定 (Boot Configuration)

DPU 被設定為自 HTTP IPv4 UEFI 啟動，將其導向至 NICo PXE 伺服器。PXE 伺服器根據硬體架構提供不同的引導成品：

*   **ARM (BlueField DPU)**：`nico.efi` 以及包含 `machine_id` 和 `server_uri` 的 cloud-init 使用者資料。
*   **x86 (主機)**：`scout.efi` 以及機器發現參數（`cli_cmd=auto-detect`）。

### 電源週期 (Power Cycle)

透過 Redfish 重啟 DPU 電源以觸發網路開機：

```
POST /redfish/v1/Systems/{system_id}/Actions/ComputerSystem.Reset
Body: {"ResetType": "GracefulRestart"}
```

電源控制操作支援多種重設類型：`On`、`ForceOff`、`GracefulShutdown`、`GracefulRestart`、`ForceRestart`、`ACPowercycle`、`PowerCycle`。

### 安裝 (Installation)

PXE 啟動後，DPU 會：
1.  透過 HTTP 從 NICo PXE 伺服器獲取 `nico.efi`。
2.  接收帶有其 `machine_id` 和 NICo API 端點的 cloud-init 組態設定。
3.  安裝並啟動 DPU 代理程式（`dpu-agent`），該代理程式透過 gRPC 連線回 NICo Core。

**關鍵檔案：**
*   `crates/api/src/ipxe.rs` — 針對每個架構產生 iPXE 指令
*   `pxe/ipxe/local/embed.ipxe` — iPXE 開機腳本範本
*   `nico-rest/workflow/pkg/workflow/instance/reboot.go` — `RebootInstance` Temporal 工作流程
*   `nico-rest/site-workflow/pkg/grpc/client/instance_powercycle.go` — 向站點代理程式發送重啟電源 gRPC 呼叫

---

## 5. 主機組態設定與開機 (Host Configuration and Boot)

在建置妥 DPU 後，NICo 會透過 Redfish 設定主機 BIOS 和啟動順序。

### BIOS 屬性設定 (BIOS Attribute Setting)

NICo 設定裸金屬基礎設施運行所需的 BIOS 屬性。這包括啟用 SR-IOV 以及其他平台專屬設定。BIOS 操作使用 libredfish 的 `Redfish` Trait：

*   `bios()` — 讀取目前的 BIOS 屬性。
*   `set_bios()` — 設定 BIOS 屬性值。
*   `machine_setup()` — 套用基礎設施專屬的 BIOS 組態設定。
*   `is_bios_setup()` / `machine_setup_status()` — 檢查組態設定狀態。

這些會轉換為 Redfish 呼叫：
```
GET   /redfish/v1/Systems/{id}/Bios           — 讀取屬性
PATCH /redfish/v1/Systems/{id}/Bios/Settings — 寫入屬性（暫存，於下次重開機套用）
```

### 啟動順序組態設定 (Boot Order Configuration)

設定主機啟動順序，使 DPU 的網路介面成為主要啟動裝置：

```rust
set_boot_order_dpu_first(bmc_ip, credentials, boot_interface_mac)
```

這會將 UEFI 啟動順序設定為優先考慮 DPU 的 PF MAC 位址，確保主機透過 DPU 的網路路徑進行開機。

### 主機重開機 (Host Reboot)

在變更 BIOS 和啟動順序後，主機會透過 Redfish 重新啟動電源以套用組態設定：

```
POST /redfish/v1/Systems/{system_id}/Actions/ComputerSystem.Reset
Body: {"ResetType": "GracefulRestart"}
```

重啟電源操作具有速率限制（Rate-limited），以避免過度重啟（藉由比對 `time_since_redfish_powercycle` 與 `config.reset_rate_limit` 來檢查）。

**關鍵檔案：**
*   `crates/site-explorer/src/redfish.rs` — `set_boot_order_dpu_first()`、`redfish_powercycle()`
*   `crates/site-explorer/src/bmc_endpoint_explorer.rs` — 透過憑證查詢協調整合開機順序

---

## 6. 持續監控 (Ongoing Monitoring)

一旦主機建置完成，`nico-hw-health` 服務會持續透過 Redfish 監控**主機 BMC 與 DPU BMC**。端點發現會呼叫帶有 `include_dpus: true` 的 `find_machine_ids`，因此 NICo 已知的每個 BMC（主機和 DPU）都會獲得自己的一組收集器：

*   **健康監控器 (Health monitor)** — 感測器收集與健康警報回報
*   **韌體收集器 (Firmware collector)** — 韌體清單輪詢
*   **日誌收集器 (Logs collector)** — BMC 事件日誌收集

每個收集器針對每個 BMC 端點獨立執行，這代表一台配備兩個 DPU 的主機將擁有三組收集器（一組用於主機 BMC，每個 DPU BMC 各一組）。

### 韌體清單 (Firmware Inventory)

`FirmwareCollector` 會定期使用 **nv-redfish** 查詢每個 BMC 的韌體清單：

```rust
let service_root = ServiceRoot::new(bmc.clone()).await?;
let update_service = service_root.update_service().await?;
let firmware_inventories = update_service.firmware_inventories().await?;
```

這會轉換為：
```
GET /redfish/v1
GET /redfish/v1/UpdateService
GET /redfish/v1/UpdateService/FirmwareInventory
GET /redfish/v1/UpdateService/FirmwareInventory/{id}  （針對每個項目）
```

每個韌體項目的名稱與版本會匯出為帶有以下標籤的 Prometheus Gauge 指標：
*   `serial_number` — 機器機箱序號
*   `machine_id` — NICo 機器 UUID
*   `bmc_mac` — BMC MAC 位址
*   `firmware_name` — 組件名稱（例如 "BMC_Firmware", "DPU_NIC"）
*   `version` — 韌體版本字串

### 感測器收集 (Sensor Collection)

感測器資料（溫度、風扇速度、功耗、電流消耗）以可設定的間隔進行收集：

| 組態設定參數 | 預設值 | 說明 |
|---|---|---|
| `sensor_fetch_interval` | 60 秒 | 感測器輪詢頻率 |
| `sensor_fetch_concurrency` | 10 | 同時進行的最大 BMC 感測器查詢數 |
| `include_sensor_thresholds` | true | 是否包含臨界值（Threshold） |

感測器資料讀取自：
```
GET /redfish/v1/Chassis/{id}/Sensors
GET /redfish/v1/Chassis/{id}/Sensors/{sensor_id}
```

感測器類型包括：溫度（Cel）、旋轉/風扇（RPM）、功率（W）和電流（A）。

所有感測器資料都會在 `/metrics` 端點（連接埠 9009）上以 Prometheus 指標形式匯出，並透過 `RecordHardwareHealthReport` 送入 NICo Core 進行健康狀態彙整。

**關鍵檔案：**
*   `crates/health/src/firmware_collector.rs` — 使用 nv-redfish 的 `FirmwareCollector`
*   `crates/health/src/discovery.rs` — 建立並管理每個端點的收集器
*   `crates/health/src/config.rs` — 輪詢間隔與並行性組態設定

---

## Redfish 程式庫 (Redfish Libraries)

NICo 同時使用兩個 Redfish 用戶端程式庫。隨著時間推移，**nv-redfish** 正在逐步取代 **libredfish**。版本在工作空間依賴項 `Cargo.toml` 中鎖定。

| 程式庫 | 版本 | 語言 | 用途 | 程式碼位置 |
|---|---|---|---|---|
| [libredfish](https://github.com/NVIDIA/libredfish) | v0.43.11 | Rust | Site Explorer：發現、啟動設定、電源控制、BIOS、帳戶管理 | `crates/site-explorer/`，透過 `crates/redfish/` |
| [nv-redfish](https://github.com/NVIDIA/nv-redfish) | 0.7.1 | Rust | Site Explorer 探測與硬體健康清單收集 | `crates/site-explorer/`、`crates/redfish/`、`crates/health/src/` |

**libredfish** 提供了一個具有廠商專屬實現（Dell、HPE、Lenovo、Supermicro、NVIDIA DPU/GB200/GH200/Viking）的 `Redfish` Trait。它處理了廣泛的 BMC 操作。

**nv-redfish** 使用程式碼產生方式：在建置時將 CSDL（Redfish 綱要 XML）編譯為強型別的 Rust。它透過功能閘（Feature-gated）進行控制，因此僅編譯所需的 Redfish 服務。目前在 NICo 中啟用的功能包括：`std-redfish`、`update-service`、`resource-status`。

兩個程式庫皆在工作空間 `Cargo.toml` 中宣告。

---

[Redfish Endpoints Reference](https://docs.nvidia.com/infra-controller/documentation/architecture/redfish/redfish-endpoints-reference)

## 重點整理 (Key Takeaways)

1.  **端對端工作流程機制**：
    *   **發現**：從 BMC 的 DHCP 請求觸發，Kea DHCP 鉤子（Rust/C FFI）擷取 MAC 與 Vendor 類別，經由 gRPC 通知 NICo Core。
    *   **探測**：Site Explorer 匿名偵測廠商後，再使用預設憑證或輪替後的金鑰登入 Redfish 收集序號、適配器、電源等資料。
2.  **DPU 與主機配對演算法**：
    *   主要策略為比對主機 PCIe 裝置（BlueField 裝置）與 DPU `system.serial_number`。
    *   次要策略透過機箱網路適配器（Network Adapters）進行序號比對。
    *   最終備用機制則依賴 `expected_machines.json` 的手動指定，配對時亦會嚴格驗證 DPU 是否處於 DPU 模式。
3.  **資源建置（Provisioning）與開機控制**：
    *   設定 DPU 從 HTTP IPv4 UEFI 啟動，拉取 PXE `nico.efi`，自動安裝並啟動 `dpu-agent`。
    *   接著設定主機 BIOS（啟用 SR-IOV）和啟動順序（DPU 優先，即對齊 DPU 的 PF MAC），並透過 Redfish（速率限制機制）執行電源重啟套用。
4.  **分層健康與感測監控**：
    *   `nico-hw-health` 會為受控主機中**所有的 BMC**（包含主機和每個 DPU）分別建立獨立的收集器（Health, Firmware, Logs）。一台配置兩片 DPU 的主機將同時運行三組監控器。
    *   每 60 秒定期抓取 `/Sensors` 端點資料，匯出為 Prometheus 指標（連接埠 9009 `/metrics`），並回報給主系統作為機器 SLA 健康度評估。
5.  **並行 Redfish 程式庫架構**：
    *   同時使用 **libredfish**（用於較複雜的 BIOS 與帳戶管理、電源控制）與 **nv-redfish**（以 CSDL XML 靜態代碼產生的強型別庫，用於健康狀態和更新盤點），nv-redfish 將逐步取代 libredfish。
