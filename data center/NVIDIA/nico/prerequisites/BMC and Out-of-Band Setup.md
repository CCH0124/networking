# BMC and Out-of-Band Setup (BMC 與頻外設定)

本頁面涵蓋了在 NICo 能夠發現並管理主機之前，所需的頻外（Out-of-band, OOB）網路組態設定與 BMC 準備工作。

---

## OOB 網路與 DHCP 中繼 (OOB Network and DHCP Relay)

當主機的 BMC 透過 OOB 網路發送 DHCP 請求時，NICo 便會發現這些主機。OOB 網路必須設定為將這些請求轉發至 NICo DHCP 服務。

**需求：**
*   一個專屬的 OOB 管理網路，將所有主機 BMC 和 DPU BMC 連接至站點控制器。
*   在 OOB 交換器上設定 DHCP 中繼（DHCP relay），指向 NICo DHCP 服務 IP（`NICo_DHCP_EXTERNAL`）。
*   為 DPU BMC 提供獨立的 OOB 管理連線。

NICo 會管理管理網路的 IP 分配 —— OOB 交換器僅需轉發 DHCP 流量，而不需指派位址。如需完整的交換器組態設定需求，請參閱 [Network Prerequisites](https://docs.nvidia.com/infra-controller/documentation/getting-started/prerequisites/network) 頁面。

---

## BMC 憑證 (BMC Credentials)

NICo 需要每台主機的出廠預設 BMC 憑證，以便在初始發現期間向 BMC 進行驗證。在發現主機後，NICo 會將這些憑證輪替（Rotate）為站點管理的專屬數值。

### 每台主機所需的資訊 (Information Required per Host)

對於每個要接入（Ingest）的主機，需要以下數值：

| 欄位 | 說明 |
|---|---|
| BMC MAC 位址 | 主機 BMC 介面的 MAC 位址 |
| 機箱序號 | 用於驗證 BMC MAC 是否與實際機箱符合 |
| BMC 使用者名稱 | 出廠預設使用者名稱（通常為 `root`） |
| BMC 密碼 | 出廠預設密碼 |

### 預期機器清單 (Expected Machines Manifest)

此資訊會以名為 `expected_machines.json` 的 JSON 清單檔案提供給 NICo。只有在此清單中列出的主機才會被發現並接入。

```json
{
  "expected_machines": [
    {
      "bmc_mac_address": "C4:5A:B1:C8:38:0D",
      "bmc_username": "root",
      "bmc_password": "default-password1",
      "chassis_serial_number": "SERIAL-1"
    },
    {
      "bmc_mac_address": "C4:5A:FF:FF:FF:FF",
      "bmc_username": "root",
      "bmc_password": "default-password2",
      "chassis_serial_number": "SERIAL-2"
    }
  ]
}
```

請在開始主機接入之前準備好此檔案。如需上傳檔案與管理憑證的詳細資訊，請參閱 [Ingesting Hosts](https://docs.nvidia.com/infra-controller/documentation/provisioning-day-0/ingesting-hosts) 頁面。

---

## 全站點憑證 (Site-Wide Credentials)

在接入主機之前，你還必須設定 NICo 在取得擁有權後，將在 BMC 和 UEFI 上設定的憑證：

*   **主機 BMC 憑證**：在接入後套用到所有主機 BMC。
*   **DPU BMC 憑證**：在接入後套用到所有 DPU BMC。
*   **主機 UEFI 密碼**：受控主機的每台設備 UEFI 密碼。
*   **DPU UEFI 密碼**：受控 DPU 的每台設備 UEFI 密碼。

這些憑證是在部署 NICo 後透過 `nico-admin-cli` 進行設定。請參閱 [Ingesting Hosts](https://docs.nvidia.com/infra-controller/documentation/provisioning-day-0/ingesting-hosts) 頁面以取得憑證設定命令。

---

## BMC Redfish 需求 (BMC Redfish Requirements)

NICo 專門透過 Redfish 與主機 BMC 及 DPU BMC 進行通訊。BMC 必須支援以下 Redfish 操作：

| 操作 | 用途 |
|---|---|
| 電源控制 | 開機、關機以及重設受控主機與 DPU。 |
| 啟動順序組態設定 | 設定 UEFI 啟動順序（DPU 優先）。 |
| UEFI 安全啟動（Secure Boot）切換 | 啟用/停用安全啟動（Secure Boot）。 |
| 韌體清單 | 盤點 UEFI、BMC 以及網卡（NIC）的韌體版本。 |
| 韌體更新 | 以頻外（Out-of-band）方式套用韌體更新。 |
| Serial-over-LAN | 啟用 SSH 主控台（Console）存取受控主機。 |
| IPv6 | 支援 IPv6 協定；用於 BMC 通訊。 |

如需 Redfish 端點與所需回應欄位的完整清單，請參閱 [Redfish Endpoints Reference](https://docs.nvidia.com/infra-controller/documentation/architecture/redfish/redfish-endpoints-reference) 頁面。

---

## 重點整理 (Key Takeaways)

1. **OOB DHCP 轉發機制**：NICo 是透過主機 BMC 於 OOB 網路發送的 DHCP 請求來發現主機。因此，實體 OOB 交換器必須設定 DHCP 中繼（DHCP relay），將封包引導至 NICo 的 DHCP 服務 IP（`NICo_DHCP_EXTERNAL`）。
2. **預期清單安全機制**：只有在 `expected_machines.json` 清單中註冊了 BMC MAC 地址和機箱序號的設備才會被接入。初次發現時會使用出廠預設憑證登入，接入完成後 NICo 會將其自動輪替為自訂密碼。
3. **全站點憑證覆蓋**：NICo 接管設備後，會透過管理命令（`nico-admin-cli`）統一重新設定主機與 DPU 的 BMC 憑證以及 UEFI 密碼，保證接管後的架構安全性。
4. **Redfish API 依賴**：NICo 與主機及 DPU BMC 的互動完全基於 Redfish 協定。*BMC 必須支援關鍵的 Redfish 功能，包括電源控制、引導順序調整（必須設定為 DPU 優先以完成建置）、韌體盤點與更新，以及 Serial-over-LAN*。
