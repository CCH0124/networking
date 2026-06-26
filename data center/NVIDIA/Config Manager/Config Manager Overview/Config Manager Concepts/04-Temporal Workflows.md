# Temporal Workflows

NVIDIA Config Manager 使用 Temporal 進行工作流編排，提供了耐久性（durability）、可觀測性（observability）與複雜工作流處理能力。請參閱 Config Manager [Temporal 說明文件](https://docs.nvidia.com/switch-infrastructure/config-manager/services/temporal/overview) 以取得關於工作流的更詳細資訊。

面向裝置（Device-facing）的工作流需要裝置處於可連線狀態。使用模擬數據的本地端部署雖然可以顯示工作流表單和已渲染的產出物（artifacts），但無法驗證 SSH/API 裝置行為、ZTP（零接觸部署）、佈線驗證、密碼變更、部署差異對比、備份、重新置備（reprovisioning）或硬體收集等功能。

## 推薦優先執行的工作流

對於實際的實驗室或生產環境，請在進行廣泛變更前，先從證明「可達性（reachability）」和「可視性（visibility）」的工作流開始。

| 工作流 | 適用時機... |
| :--- | :--- |
| [組態備份](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/configuration-deploy/configuration-backup) | 您需要確認憑證、管理連線狀態並建立運行中組態的基準擷取。 |
| [組態部署](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/configuration-deploy/configuration-deploy) | 您有已審核過的預期組態變更，需要套用至單一台裝置。 |
| [多裝置部署](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/configuration-deploy/multi-device-deploy) | 單一裝置部署已通過驗證，且您需要針對特定角色進行群組式的差異核准。 |
| [佈線驗證](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/validation/cable-validation) | 裝置為可達狀態，且需要比對 Nautobot 中的佈線數據與實際觀測到的 LLDP/FDB/ARP 數據。 |

在核准、拒絕、重試或終止執行中的工作流之前，請參閱 [控制執行中的工作流](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/controlling-running-workflows)。

## 工作流介面特色 (Workflow Interface Features)

**工作流詳細資訊檢視 (Workflow Details View)**

* 工作流名稱與說明
* 站點與使用者歸屬
* 開始時間與持續時間
* 目前狀態 (IN PROGRESS, COMPLETE, FAILED)

**階段追蹤 (Stage Tracking)**

* 具有清晰進展的多階段工作流
* 每個階段顯示：
  * 階段名稱與說明
  * 開始與結束時間
  * 持續時間
  * 狀態指標 (COMPLETE, IN PROGRESS)

**輸出與歷史記錄 (Output and History)**

* 即時輸出顯示
* 帶有時間戳記的狀態歷史記錄
* 組態變更摘要

## 工作流類型 (Workflow Types)

Config Manager 支援多個工作流類別，可在 Temporal UI 中進行檢視：

* `BackupWorkflow`
* `BatchDeployWorkflow`
* `ConnectedHostMetadataWorkflow`
* `DeployWorkflow`
* `DeviceCableValidationWorkflow`
* `DevicePasswordRotationWorkflow`
* `HelloWorld` (範例/測試工作流)
* `HelloWorldApproval` (含審批流程的範例)
* `InfinibandCableValidationWorkflow`
* `InfinibandGetUnhealthyPortsWorkflow`
* `InfinibandMlnxOSUpgradeWorkflow`
* `MultiDeployWorkflow`
* `NVLinkSwitchFirmwareUpgradeWorkflow`
* `PortLLDPInfoWorkflow`
* `RedfishProvisioningWorkflow`
* `ReprovisionWorkflow`
* `SiteCableValidationWorkflow`
* `SitePasswordRotationWorkflow`
* `SwitchOSUpgradeWorkflow`
* `TenantDeployWorkflow`
* `ValidateHardwareWorkflow`
* `VpcAssignmentWorkflow`
* `VpcCreationWorkflow`
* `VpcDeletionWorkflow`
* `VpcTenantChangeWorkflow`

## 工作流 API 端點 (Workflow API Endpoints)

### 工作流管理 (Workflow Management)

可透過 REST API 在 `/v1/workflow/` 進行管理：

| 端點 | 方法 | 說明 |
| :--- | :--- | :--- |
| `/` | GET | 列出工作流 |
| `/types` | GET | 取得註冊的工作流類型 |
| `/{workflow_id}` | GET | 取得工作流執行詳細資訊 |
| `/{workflow_id}/approve/{stage_name}` | POST | 核准工作流階段 |
| `/{workflow_id}/reject/{stage_name}` | POST | 拒絕工作流階段 |
| `/{workflow_id}/retry/{stage_name}` | POST | 重試工作流階段 |
| `/{workflow_id}/terminate` | POST | 終止工作流 |

### 工作流執行 (Workflow Execution)

每個內建工作流都有一個具體的 POST 端點，例如 `POST /v1/workflow/ngc/backup`。範例：

| 端點 | 說明 |
| :--- | :--- |
| `/backup` | 執行 BackupWorkflow |
| `/batch_deploy` | 執行 BatchDeployWorkflow |
| `/connected_host_metadata` | 執行 ConnectedHostMetadataWorkflow |
| `/cumulus_hardware_validation` | 執行 ValidateHardwareWorkflow |
| `/deploy` | 執行 DeployWorkflow |
| `/device_cable_validation` | 執行 DeviceCableValidationWorkflow |
| `/device_password_rotation` | 執行 DevicePasswordRotationWorkflow |
| `/infiniband_cable_validation` | 執行 InfinibandCableValidationWorkflow |
| `/infiniband_get_unhealthy_ports` | 執行 InfinibandGetUnhealthyPortsWorkflow |
| `/infiniband_mlnx_os_upgrade` | 執行 InfinibandMlnxOSUpgradeWorkflow |
| `/multi_deploy` | 執行 MultiDeployWorkflow |
| `/nvlinkswitch_firmware_upgrade` | 執行 NVLinkSwitchFirmwareUpgradeWorkflow |
| `/port_lldp_info` | 執行 PortLLDPInfoWorkflow |
| `/redfish_provisioning` | 執行 RedfishProvisioningWorkflow |
| `/reprovision` | 執行 ReprovisionWorkflow |
| `/site_cable_validation` | 執行 SiteCableValidationWorkflow |
| `/site_password_rotation` | 執行 SitePasswordRotationWorkflow |
| `/switch_os_upgrade` | 執行 SwitchOSUpgradeWorkflow |
| `/tenant-deploy` | 執行 TenantDeployWorkflow |
| `/vpc-tenant-change` | 執行 VpcTenantChangeWorkflow |
| `/vpc_assignment` | 執行 VpcAssignmentWorkflow |
| `/vpc_creation` | 執行 VpcCreationWorkflow |
| `/vpc_deletion` | 執行 VpcDeletionWorkflow |

## 工作流 CLI 指令 (Workflow CLI Commands)

執行連線主機詮釋資料（connected host metadata）工作流：

```bash
uv run workflow-cli connected-host-metadata \
  -H config-manager.example.com \
  --device-name rno1-m04-c10-spine1-hss-tan-lab1 \
  --verbose
```

驗證硬體組件：

```bash
uv run workflow-cli validate-hardware \
  -H config-manager.example.com \
  --site datacenter01 \
  --tenant tenant01 \
  --roles leaf-switch,spine-switch \
  --status active \
  --raise-for-invalid true
```

---

## 重點整理

本篇說明了 NVIDIA Config Manager 中基於 Temporal 的工作流機制，核心重點如下：

1. **底層架構**：使用 **Temporal** 進行工作流編排，確保了高耐久性、可觀測性與對複雜流程的處理能力。
2. **本地端模擬限制**：本地部署若使用模擬資料，雖能呈現前端表單與渲染產出，但無法測試裝置的 SSH/API 實際連線與硬體控制、ZTP、密碼旋轉與實體佈線驗證等功能。
3. **首推的入門工作流**：對於實際環境，建議先以「組態備份（Backup）」開始驗證連線基準，接著逐步實作「單一裝置部署（Deploy）」、「多裝置部署（Multi-Device Deploy）」與「佈線驗證（Cable Validation）」。
4. **豐富的控制與執行方式**：
   - **介面特色**：提供實時進度追蹤（如 COMPLETE, IN PROGRESS）、明細檢視、以及每個階段的審核控制。
   - **介面與 API**：支援高達 20 餘種工作流類型（例如密碼旋轉、硬體驗證、VPC 建立/刪除/指派、各型號 Switch/OS 升級等），且所有工作流均有對應的 REST API。
   - **CLI 工具**：提供 `workflow-cli` 指令工具（基於 Python `uv` 執行），支援從終端機直接觸發主機連線中繼資料與硬體組件驗證等操作。
