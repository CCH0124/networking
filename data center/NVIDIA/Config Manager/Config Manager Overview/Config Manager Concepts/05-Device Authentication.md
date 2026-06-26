# Device Authentication

Config Manager 使用專用的服務帳戶來連線至受管理的裝置。預設的服務帳戶使用者名稱為 `nv-config-manager`。在生產環境部署中，請將該帳戶密碼儲存在 Vault 或 OpenBao 中，並透過 External Secrets Operator 將其公開給 Config Manager。Kubernetes 密鑰（secrets）對於本地端開發和受限的實驗室安裝非常有用，但它們並非生產環境首選的單一真理源（source of truth）。

Render（渲染服務）使用該服務帳戶密鑰，將經雜湊處理的裝置帳戶寫入預期組態（intended configuration）中。ZTP 會在引導（bootstrap）期間套用該組態。Temporal worker 則使用同一個密鑰在備份、部署、重新置備（reprovision）和密碼旋轉（password rotation）等工作流中對裝置進行身分驗證。

## 推薦的密鑰來源 (Recommended Secret Source)

在生產環境中，建議搭配 Vault 或 OpenBao 使用 `secrets.method: eso`：

```yaml
secrets:
  method: eso
  vault:
    server: https://vault.example.com
    secrets_path: nv-config-manager/secrets
    mount_path: auth/kubernetes/prod
    role: nv-config-manager-vault-agent
    auth:
      method: jwt
    paths:
      network:
        path: secrets/nv-config-manager/global/network
        keys:
          user: user
          password: password
network_secrets:
  - name: Config Manager Service Account Password
    secret_key: api_user_key
    source: vault
    rotation: r1
  - name: Hash Salt
    secret_key: hash_salt
    source: vault
    rotation: ""
sites:
  - name: dc01
    vault_path: secrets/nv-config-manager/site/dc01/config_secrets
```

Vault/OpenBao 的網路路徑為運行時的 `[device]` 組態區段提供了全域的裝置使用者名稱與備用密碼：

```text
username = nv-config-manager
password = <service-account-password>
```

每個站點的 `vault_path` 會指向一個獨立的 Vault/OpenBao 鍵值對（KV）路徑，其中包含站點範圍的網路密鑰。這些鍵（keys）是最終的組態密鑰欄位名稱，包括使用旋轉後綴的名稱：

```text
api_user_key_r1 = <service-account-password>
root_password_r1 = <breakglass-or-root-password>
bgp_password_r1 = <bgp-password>
hash_salt = <random-salt>
```

External Secrets Operator 會讀取這些 Vault 路徑，並建立由 Config Manager 掛載的運行時投影（runtime projections）。請將這些掛載的檔案視為 Vault 資料的投影，而非真理源本身。

## 憑證流程 (Credential Flow)

在 Vault/OpenBao 模式下，憑證生命週期包含三個階段：

1. **Vault/OpenBao**：網路路徑儲存全域裝置使用者名稱與備用密碼，而每個站點路徑則儲存支援旋轉的密鑰（例如 `api_user_key_r1`）。
2. **Render 與 ZTP**：渲染服務（render）讀取投影的站點密鑰，將每個平台的站點密碼進行雜湊處理，並將帳戶寫入預期組態中，ZTP 則在引導期間套用該組態。
3. **Temporal**：面向裝置的工作流會先讀取投影的站點密鑰，在沒有站點旋轉金鑰時，再退回使用 Vault 投影的 `[device]` 密碼。

這能使 Vault/OpenBao 保持為生產環境的真理源，同時仍可為 Pod 提供渲染範本與工作流 worker 所期望的檔案格式。請勿將此方式與安裝程式建立的 `device-creds` 混用；該路徑屬於 Kubernetes 密鑰模式。

## Render 與 ZTP

裝置帳戶的建立是由每台裝置的 Nautobot 組態上下文（config context）控制。`password_mappings` 區塊將作業系統使用者名稱對應至基礎密鑰、旋轉後綴以及平台角色：

```yaml
password_mappings:
  nvConfigManager:
    password: api_user_key
    rotation: r1
    role: system-admin
  cumulus:
    password: root_password
    rotation: r1
    role: system-admin
```

在渲染期間，`password: api_user_key` 加上 `rotation: r1` 會變為 `password_key: api_user_key_r1`。平台範本接著會從裝置站點投影的 `config-secrets.ini` 中載入該金鑰。若該平台預期使用雜湊密碼，範本會使用站點的 `hash_salt` 對其進行雜湊處理，並將該使用者寫入啟動組態中。

當裝置開機時，DHCP 會將其導向 ZTP 服務。ZTP 引導指令碼會從 Config Store 取得預期的啟動組態，將其套用至裝置，然後呼叫已置備端點（provisioned endpoint）。此時，裝置已安裝了服務帳戶，且 Config Manager 可以使用 Vault/OpenBao 中對應的密鑰進行身分驗證。

## 工作流身分驗證 (Workflow Authentication)

Temporal worker 會在連線時解析裝置憑證：

1. 使用者名稱來自 `nv-config-manager.ini [device] username`。
2. 裝置站點來自傳入工作流的 Nautobot 資料。
3. 密碼版本是從 `config-secrets.ini` 中相符的 `[site.<slug>]` 區段讀取。
4. Worker 會先嘗試最新的 `api_user_key_rN` 密碼，並在旋轉期間嘗試舊版本。

這使工作流能夠容忍分階段的旋轉（staged rotations）。已接收到新渲染組態的裝置會接受最新密碼；尚未收到更新的裝置在部署完成前仍可接受上一個修訂版本。

## 密碼旋轉工作流 (Password Rotation Workflows)

密碼旋轉是一個由渲染（render）驅動的工作流。該工作流本身不會產生新的密鑰。維運人員必須先將新值寫入 Vault/OpenBao，然後更新裝置的密碼對應，使渲染指向新的修訂版本。

對於 Config Manager 服務帳戶，典型的旋轉步驟如下：

1. 將 `api_user_key_r2` 新增至每個受影響站點的 Vault/OpenBao 路徑。
2. 將目標使用者名稱適用的 `password_mappings` 組態上下文從 `rotation: r1` 更新為 `rotation: r2`。
3. 讓渲染服務為受影響的裝置重新生成預期組態。
4. 針對單一裝置執行 [裝置密碼旋轉](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/lifecycle/device-password-rotation)，或針對經篩選的站點範圍執行 [站點密碼旋轉](https://docs.nvidia.com/switch-infrastructure/config-manager/user-guides/lifecycle/site-password-rotation)。
5. 確認工作流已完成且存在最新的備份。
6. 當每台裝置都已接受新憑證且回復期結束後，從 Vault/OpenBao 中移除 `api_user_key_r1`。

裝置工作流會驗證候選的差異（candidate diff）僅修改了所選使用者的密碼，並會自動核准該僅限密碼的變更。站點工作流會為每個相符的裝置分發一個裝置旋轉子工作流，並彙總結果。

## Kubernetes 密鑰模式 (Kubernetes Secret Mode)

`secrets.method: kubernetes` 會直接將相同的 `config-secrets.ini` 格式建立為 Kubernetes 密鑰。這適用於本地端開發、CI 和無法使用 Vault/OpenBao 的小型實驗室安裝。掛載密鑰後，其渲染、ZTP、Temporal 和密碼旋轉行為皆與先前相同，但維運所有權不同：旋轉意味著更新由 Kubernetes 管理的密鑰資料，而非更新 Vault/OpenBao。

在此模式下，安裝程式還會為服務帳戶使用者名稱建立 `device-creds`。這與上述 Vault/OpenBao 路徑是互斥的：請選擇使用 Vault/OpenBao 或由 Kubernetes 管理的 `device-creds`，不要兩者混用。

## 疑難排解 (Troubleshooting)

如果渲染輸出不包含預期的帳戶，請檢查裝置的 `password_mappings` 組態上下文，並確認對應的鍵存在於該站點的 Vault/OpenBao 路徑中。

如果工作流無法連線，請確認 External Secrets Operator 已同步運行時密鑰、`NV_CONFIG_MANAGER_CONFIG_SECRET_PATH` 已掛載於 Temporal worker pod 中、`[site.<slug>]` 區段存在，且裝置的 Nautobot 站點 slug 與該區段名稱相符。

如果密碼旋轉回報無差異，則預期組態可能仍然指向舊的密鑰版本。請在重新執行旋轉工作流之前，確認新的 Vault/OpenBao 金鑰已存在、組態上下文旋轉已變更，且渲染服務已重新生成預期組態。

---

## 重點整理

本篇說明了 NVIDIA Config Manager 的裝置驗證與密碼管理機制，核心重點整理如下：

1. **認證金鑰真理源**：
   - 生產環境部署推薦使用 `Vault` 或 `OpenBao`（搭配 `External Secrets Operator`）作為單一真理源。
   - 本地開發或小型實驗室可使用 Kubernetes Secret 模式，但兩者架構與檔案（`device-creds`）互斥，不可混用。

2. **憑證生命週期的三階段流程**：
   - **儲存**：Vault/OpenBao 分別儲存全域帳戶密碼與各站點支援旋轉的密鑰（例如 `api_user_key_r1`）。
   - **渲染與引導**：渲染服務讀取掛載的金鑰檔案（`config-secrets.ini`），在範本中進行密碼雜湊，並寫入組態供 ZTP 在裝置引導時套用。
   - **工作流執行**：Temporal 在執行網路維運（如備份、部署）時，會先嘗試站點的最新旋轉密鑰，若無則退回使用全域預設密碼。

3. **密碼旋轉工作流**：
   - 密碼旋轉是由渲染所驅動。其步驟為：在 Vault 寫入新密碼版本（如 `r2`）➡️ 修改 Nautobot 中 `password_mappings` 的版本對應 ➡️ 渲染服務重新生成預期組態 ➡️ 觸發裝置或站點級的密碼旋轉工作流 ➡️ 驗證並於最後刪除舊密碼。
   - 工作流支援「分階段旋轉」，即使有裝置尚未更新到最新組態，亦能使用舊密碼完成連線，避免因更新進度不同而導致斷線。
