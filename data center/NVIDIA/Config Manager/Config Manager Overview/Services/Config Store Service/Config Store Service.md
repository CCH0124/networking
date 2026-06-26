# Config Store Service

Config Store 服務提供基於 PostgreSQL 的組態儲存空間，具備版本控制、壓縮與細粒度鎖定（fine-grained locking）功能。

## 概述

Config Store 服務可以：

* 儲存具備版本控制的裝置組態（預期組態與備份組態）。
* 與 Nautobot 整合以進行裝置詮釋資料（metadata）的富化（enrichment）。
* 提供用於組態管理的 REST API。
* 包含用於瀏覽與比對組態的網頁 UI。

## 特色功能

* **版本化儲存**：完整的版本歷史記錄，並可設定保留策略。
* **檔案類型**：區分 `intended`（預期）與 `backup`（備份）組態。
* **差異生成 (Diff Generation)**：比對任何兩個版本。
* **批次操作**：針對單一裝置的多個檔案進行批次寫入。
* **現代化網頁 UI**：瀏覽、搜尋與比對組態。

有關詳細的功能說明與系統架構，請參閱 [Config Store 架構](https://docs.nvidia.com/switch-infrastructure/config-manager/services/config-store/architecture#components)。

## 檔案類型 (File Types)

此服務追蹤兩種不同的檔案類型：

| 類型 | 說明 | 來源 |
| :--- | :--- | :--- |
| `intended` (預期) | 已渲染/預期的組態 | Render 服務 |
| `backup` (備份) | 實際的裝置備份 | Temporal 工作流 |

這種區隔可實現：

* **配置漂移偵測 (Drift Detection)**：比對預期與備份組態。
* **獨立鎖定 (Independent Locking)**：寫入操作互不阻礙。
* **合規稽核 (Compliance Auditing)**：追蹤預期狀態與實際狀態。

關於鎖定機制的詳細資訊，請參閱 [並行寫入處理](https://docs.nvidia.com/switch-infrastructure/config-manager/services/config-store/architecture#concurrent-write-handling)。

## API 端點 (API Endpoints)

### 組態操作 (Configuration Operations)

`file_type` 用於區隔預期組態與備份組態。對於 `GET /v1/config/{device_uuid}/{filename}`、`GET /v1/config/{device_uuid}/{filename}/versions` 與 `GET /v1/config/{device_uuid}/{filename}/diff`，請將 `file_type` 作為選填的查詢參數（query parameter）傳遞。若省略，則預設為 `intended`。

對於 `POST /v1/config/{device_uuid}/{filename}`，請在要求主體（request body）中以 `ConfigCreateRequest.file_type` 傳遞 `file_type`。若省略同樣預設為 `intended`。

```bash
# 寫入預期組態檔案 (intended config)
POST /v1/config/{device_uuid}/{filename}
{
    "content": "hostname device01\n...",
    "author": "user@example.com",
    "commit_message": "Triggered from nb dcim.device update on leaf01 by netops at 2026-05-26T18:42:00Z",
    "file_type": "intended"
}

# 讀取最新版本
GET /v1/config/{device_uuid}/{filename}
GET /v1/config/{device_uuid}/{filename}?file_type=backup

# 讀取特定版本
GET /v1/config/{device_uuid}/{filename}?version=5

# 列出所有預期版本
GET /v1/config/{device_uuid}/{filename}/versions

# 列出所有備份版本
GET /v1/config/{device_uuid}/{filename}/versions?file_type=backup

# 取得預期版本之間的差異 (diff)
GET /v1/config/{device_uuid}/{filename}/diff?from_version=4&to_version=5

# 取得備份版本之間的差異 (diff)
GET /v1/config/{device_uuid}/{filename}/diff?from_version=4&to_version=5&file_type=backup

# 取得單一裝置的所有組態
GET /v1/config/device/{device_uuid}

# 為單一裝置批次寫入多個預期組態檔案
POST /v1/config/{device_uuid}/batch
{
    "files": [
        {
            "filename": "boot-script",
            "content": "...",
            "author": "user@example.com",
            "commit_message": "Triggered from nb dcim.device update on leaf01 by netops at 2026-05-26T18:42:00Z",
            "file_type": "intended"
        },
        {
            "filename": "startup.yaml",
            "content": "...",
            "author": "user@example.com",
            "commit_message": "Triggered from nb dcim.device update on leaf01 by netops at 2026-05-26T18:42:00Z",
            "file_type": "intended"
        }
    ]
}
```

在正常維運下，批次要求（batch requests）應為單一組態類型。預期組態的批次寫入通常會同時寫入 `boot-script` 與 `startup.yaml`。渲染服務會為批次中的每個檔案傳遞相同的、衍生自 Nautobot 變更的 `commit_message`。備份擷取通常是單一檔案寫入，發送至 `POST /v1/config/{device_uuid}/{filename}` 並帶有 `"file_type": "backup"`。

批次端點會傳回已建立或更新之檔案的版本詮釋資料（version metadata），以及因為內容已與最新儲存的版本相同而被跳過的檔案名稱清單：

```json
{
  "created": [
    {
      "version": 7,
      "file_type": "intended",
      "author": "user@example.com",
      "commit_message": "Triggered from nb dcim.device update on leaf01 by netops at 2026-05-26T18:42:00Z",
      "created_at": "2026-05-26T18:42:00Z",
      "content_hash": "4c9f..."
    }
  ],
  "skipped": ["boot-script"]
}
```

完全成功範例：

```json
{
  "created": [
    {
      "version": 3,
      "file_type": "intended",
      "author": "render@config-manager.example.com",
      "commit_message": "Triggered from nb dcim.device update on leaf01 by netops at 2026-05-26T18:42:00Z",
      "created_at": "2026-05-26T18:42:00Z",
      "content_hash": "f2a1..."
    },
    {
      "version": 3,
      "file_type": "intended",
      "author": "render@config-manager.example.com",
      "commit_message": "Triggered from nb dcim.device update on leaf01 by netops at 2026-05-26T18:42:00Z",
      "created_at": "2026-05-26T18:42:00Z",
      "content_hash": "9d31..."
    }
  ],
  "skipped": []
}
```

等冪（Idempotent）無操作範例：

```json
{
  "created": [],
  "skipped": ["boot-script", "startup.yaml"]
}
```

失敗範例：

```json
{
  "detail": "Failed to batch create configs"
}
```

此批次操作在資料庫交易層級（transaction level）是原子性（atomic）的。若批次中的任何一個檔案在處理過程中失敗，服務將傳回非 2xx 的錯誤並回復（rollback）整個要求；它不會僅提交失敗批次中的一部分檔案。要求驗證錯誤會在進行任何寫入之前傳回。

關於重試行為，請將相同內容視為等冪處理。若要求因伺服器錯誤而失敗，或用戶端在讀取回應前斷開連線，請重試整個同類型的批次。內容相同且已提交的檔案將會被跳過，而未提交的檔案則會被寫入。若您需要復原備份擷取，請重試單一備份檔案的寫入，而非將其混入預期組態的批次中。

### 管理員操作 (Admin Operations)

```bash
# 資料庫統計資料
GET /v1/admin/stats

# 列出所有含有組態的裝置
GET /v1/admin/devices

# 依名稱搜尋裝置並取得最新的組態詮釋資料
GET /v1/admin/devices/search?q=leaf&file_type=intended&include_inactive=false

# 永久刪除裝置的所有組態版本
DELETE /v1/admin/devices/{device_uuid}

# 檢查 Nautobot 詮釋資料快取狀態
GET /v1/admin/cache/status

# 測試快取中是否存在特定裝置的詮釋資料
GET /v1/admin/cache/test/{device_uuid}

# 確認服務所看見的呼叫端身分
GET /whoami
```

## 網頁 UI (Web UI)

Config Store 包含一個 Next.js 網頁介面。

### 功能

* **裝置瀏覽器 (Device Browser)**：依裝置 UUID 或名稱搜尋並瀏覽。
* **版本歷史記錄 (Version History)**：檢視所有版本及其詮釋資料。
* **差異檢視器 (Diff Viewer)**：並排比較任何版本。
* **裝置搜尋 (Device Search)**：依名稱尋找裝置，並在預期組態與備份組態檢視之間切換。
* **Nautobot 整合**：豐富的裝置詮釋資料顯示。

### 存取網頁 UI (Accessing the UI)

```bash
# 透過 Ingress (整合式 UI)
https://config-manager.example.com

# 透過連接埠轉發 (Port-forward)
kubectl port-forward -n nv-config-manager svc/nv-config-manager-ui 3000:80
# 開啟 http://localhost:3000
```

## 配置設定 (Configuration)

### INI 設定

Config Manager INI 的相關區段如下：

```ini
[config_store]
# 資料庫連線
database_url = postgresql+asyncpg://user:pass@localhost:5432/configstore
database_pool_size = 20
database_max_overflow = 10

# 壓縮
compression_level = 6

# 保留策略
max_version_history = 1000
retention_days = 365

[redis]
# 用於裝置詮釋資料快取
host = redis.nv-config-manager.svc.cluster.local
port = 6379
db = 0

[nautobot]
# 用於詮釋資料富化
url = https://nautobot.config-manager.example.com
token = your-api-token
```

## 快取重新整理服務 (Cache Refresh Service)

有一個背景服務負責讓 Redis 快取與 Nautobot 保持同步：

```bash
# 檢視快取重新整理日誌
kubectl logs -n nv-config-manager deployment/nv-config-manager-config-store-cache-refresh -f

# 強制重新整理快取
kubectl exec -n nv-config-manager deployment/nv-config-manager-config-store-api -- \
    python -c "from nv_config_manager.config_store.cache_refresh_service import refresh; refresh()"
```

## 指標 (Metrics)

Prometheus 指標可在運行的 `/metrics` 端點取得。有關可用指標及其說明的資訊，請參閱 [Prometheus 指標](https://docs.nvidia.com/switch-infrastructure/config-manager/services/config-store/architecture#prometheus-metrics)。

## 疑難排解 (Troubleshooting)

一般性指引：

* 如果您看到大量的 503 錯誤或高延遲，請擴展（scale up）複本（replicas）數量。
* 檢查 Pod 狀態與日誌：

  ```bash
  # 取得 Pod 狀態
  kubectl get pods -n $NAMESPACE

  # 檢驗有問題的 Pod 詳細資訊
  kubectl describe pod -n $NAMESPACE <pod-name>

  # 檢視日誌
  kubectl logs -n $NAMESPACE <pod-name>
  ```

* 檢查特定應用程式（例如 `redis` 或 `postgres`）的狀態與日誌：

  ```bash
  # 取得 Pod 狀態
  kubectl get pods -n $NAMESPACE -l app=<app-name>

  # 檢視日誌
  kubectl logs -n $NAMESPACE -l app=<app-name>
  ```

### Nautobot 整合問題 (Nautobot Integration Issues)

檢查服務日誌是否有 Nautobot 連線錯誤：

```bash
kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=config-store --all-containers | grep -i nautobot
```

### 閘道無法運作 (Gateway Not Working)

檢查閘道（Gateway）是否已取得位址並已完成規劃（programmed）：

```bash
$ kubectl get gateway -n $NAMESPACE

NAME           CLASS           ADDRESS      PROGRAMMED   AGE
config-manager-gateway   envoy-gateway   172.18.0.7   True         96m
```

確保所有路由（HTTPRoutes）皆已正確安裝：

```bash
$ kubectl get httproutes -n $NAMESPACE

# 這應會產生類似以下的輸出：

NAME                    HOSTNAMES                         AGE
config-store-api        ["config-store.config-manager.example.com"]   96m
nautobot                ["nautobot.config-manager.example.com"]       96m
network-dhcp            ["dhcp.config-manager.example.com"]           96m
network-ztp             ["ztp.config-manager.example.com"]            96m
render-service          ["render.config-manager.example.com"]         96m
workflow-api            ["workflow.config-manager.example.com"]       96m
config-manager-ui       ["config-manager.example.com"]                96m
temporal-web            ["temporal.config-manager.example.com"]       96m
```

有關 Envoy 閘道的進一步資訊，請參閱 [Envoy 說明文件](https://gateway.envoyproxy.io/latest/)。

## 相關說明文件 (Related Documentation)

* [Render 服務](https://docs.nvidia.com/switch-infrastructure/config-manager/services/render/config-manager-render-service) — 寫入預期組態。
* [Temporal](https://docs.nvidia.com/switch-infrastructure/config-manager/services/temporal/overview) — 寫入備份組態。
* [ZTP 服務](https://docs.nvidia.com/switch-infrastructure/config-manager/services/network-ztp/overview) — 讀取裝置組態。
* [API 參考資料](https://docs.nvidia.com/switch-infrastructure/config-manager/services/config-store/overview)
