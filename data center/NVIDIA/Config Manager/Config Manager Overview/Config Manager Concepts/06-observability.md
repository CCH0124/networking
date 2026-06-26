# Observability

Config Manager 提供了結構化日誌（structured logs）、Prometheus 指標、選配的 PodMonitor 資源以及本地端開發的觀測性堆疊。生產環境部署可以將這些信號整合到現有的 Prometheus、Loki 或 Grafana 環境中。

## 結構化日誌 (Structured Logs)

Python 服務預設會輸出 JSON 格式的日誌。每個服務在啟動時都會呼叫 `configure_logging(service="<name>")`，而模組則透過 `get_logger(__name__, category=LogCategory.<CATEGORY>)` 取得分類過的記錄器（logger）。

主要的環境變數如下：

| 變數 | 預設值 | 說明 |
| :--- | :--- | :--- |
| `LOG_FORMAT` | `json` | 設定為 `text` 可輸出易於閱讀的本地端文字日誌。 |
| `LOG_LEVEL` | `INFO` | 標準的 Python 日誌層級。若未設定，仍會遵循舊有的 `DEBUG=1` 標記。 |

JSON 日誌記錄包含訊息（message）、層級（level）、記錄器名稱（logger name）、時間戳記（timestamp）、模組（module）、行號（line number）、服務名稱（service name）與類別（category）。類別採用點號分隔的命名方式（dotted names），以便下游工具進行寬鬆或精確的篩選。

常見的類別包括：

| 類別 | 用途 |
| :--- | :--- |
| `render`, `render.event`, `render.api` | 範本渲染、NATS 消費者以及渲染管理 API 呼叫。 |
| `dhcp`, `dhcp.data` | Kea 組態生成與 Nautobot 資料驗證。 |
| `config_store`, `config_store.api` | 組態儲存、詮釋資料富化（enrichment）以及 API 流量。 |
| `ztp`, `ztp.api` | ZTP 檔案分發、韌體串流以及置備回呼（provisioning callbacks）。 |
| `temporal.workflow`, `temporal.activity`, `temporal.api` | 工作流編排、活動程式碼以及工作流 API 流量。 |
| `nautobot`, `auth`, `nats`, `cache` | 共用的 Nautobot、身分驗證、事件處理與快取操作。 |

有關詳細的警告與錯誤日誌清單，請參閱 [日誌訊息參考資料](https://docs.nvidia.com/switch-infrastructure/config-manager/config-manager/overview/log-message-reference)。

## 自訂標籤 (Custom Labels)

在 Helm values 中設定 `global.customLabels`，即可在每一行 Config Manager 日誌以及每個收集的 Prometheus 指標中附加特定部署的標籤：

```yaml
global:
  customLabels:
    environment: prod
    region: us_west
```

Helm chart 會將此對應關係序列化為 `NV_CONFIG_MANAGER_CUSTOM_LABELS` 並提供給服務容器，同時將這些值套用為 Pod 標籤。PodMonitor 資源則會將 Pod 標籤推廣至收集到的指標樣本中。

自訂標籤的鍵（keys）必須符合 Kubernetes 標籤、Prometheus 標籤和 Python 日誌記錄屬性的規範。請使用字母、數字和底線，並避免使用保留欄位（如 `service`、`category`、`message`、`levelname`、`name`、`module` 和 `lineno`）。標籤值將被截斷至 63 個字元，以符合 Kubernetes 標籤的限制。

## 指標 (Metrics)

各個服務會在運作的 `/metrics` 端點上公開 Prometheus 指標。當目標叢集安裝了 Prometheus Operator CRD 時，可透過 `monitoring.enabled` 和 `monitoring.podMonitors.enabled` 來啟用 Helm chart 中的監控資源。

當設定了 `monitoring.probes.enabled` 且有 Blackbox Exporter 可用時，Helm chart 還可以為面向閘道的端點渲染 HTTP 探針（probes）。設定 `monitoring.grafanaUrl` 即可在 Config Manager UI 中顯示 Grafana 連結。

核心的服務指標包括：

| 服務 | 範例 |
| :--- | :--- |
| Render | 事件處理耗時、已接收事件數、已處理事件數、跳過事件數、失敗事件數。 |
| DHCP | 組態生成耗時、組態生成錯誤數、Nautobot 查詢錯誤數、快取重新整理失敗數、上次重新整理時間戳記。 |
| Config Store, ZTP, Temporal | 各組件所公開的 FastAPI 請求指標與特定服務的指標。 |

## 本地端可觀測性堆疊 (Local Observability Stack)

對於 Kind 和離線（airgapped）展示環境，安裝程式可以藉由設定 `infrastructure.monitoring.observability_enabled: true` 或在 TUI 基礎設施畫面中勾選 **Enable local observability stack** 來部署本地端的觀測性堆疊。

此途徑僅適用於本地端開發和展示。它會安裝：

| 組件 | 用途 |
| :--- | :--- |
| `prometheus-operator-crds` | 僅安裝 `monitoring.coreos.com` CRD，不會運行 Prometheus Operator Pod。 |
| Prometheus | 儲存指標並接收來自 Alloy 的遠端寫入（remote write）。它不會直接收集目標的指標。 |
| Grafana Alloy | 監控 PodMonitor、ServiceMonitor 和 Probe 資源，收集目標指標，並將樣本遠端寫入至 Prometheus。 |

此堆疊使用暫時性儲存空間（ephemeral storage）與叢集範圍的 CRD。請勿在已存在生產環境監控堆疊，或已有其他 Prometheus Operator CRD 所有者的共用叢集中啟用此功能。

要檢查本地端堆疊：

```bash
kubectl port-forward -n nv-config-manager svc/prometheus-server 9090:9090
kubectl port-forward -n nv-config-manager ds/alloy 12345:12345
```

使用位於 `http://localhost:9090` 的 Prometheus 查詢 `{namespace="nv-config-manager"}`。使用位於 `http://localhost:12345` 的 Alloy 來檢查偵測到的目標。

## Grafana 儀表板 (Grafana Dashboard)

Helm chart 中包含一個參考儀表板，並在此提供下載：

下載 JSON

該儀表板包含錯誤日誌、服務日誌、渲染事件吞吐量、DHCP 組態時效（config age）以及 HTTP 請求率等面板。

請將儀表板導入 Grafana，並為環境選擇對應的 Prometheus 和 Loki 資料來源。Loki 的串流選取器（stream selector）取決於您的日誌轉遞器（log shipper）；常見的選取器會使用如 `namespace`、`k8s_namespace_name` 或 `cluster` 等標籤。

對於 chart 內建的本地端 Grafana 路徑，當本地端觀測性覆蓋設定（local observability overlay）啟用 Grafana 時，Helm chart 也會渲染一個儀表板 ConfigMap。

---

## 重點整理

本篇說明了 NVIDIA Config Manager 的可觀測性（Observability）機制與整合手段，核心重點整理如下：

1. **結構化 JSON 日誌**：
   - Python 服務預設輸出 JSON 格式日誌，提供模組、行號、服務名稱以及點號分隔的細緻分類（如 `render.event`、`dhcp.data` 等），便於日誌收集與篩選。環境變數支援切換成文字格式（`LOG_FORMAT=text`）或調整日誌層級。

2. **自訂與彈性標籤**：
   - 可透過 Helm values 中的 `global.customLabels` 設定全局自訂標籤（如環境、區域），這些標籤會自動注入到每一行日誌和 Prometheus 指標中，便於多叢集或跨地區的監控分析。

3. **Prometheus 監控與 API 指針**：
   - 提供 `/metrics` 端點，且能在安裝了 Prometheus Operator 的環境中自動渲染 PodMonitor 資源；主要指標包含 Render 的事件吞吐、DHCP 組態生成耗時、以及各服務 API 請求指標。

4. **本地開發觀測性堆疊**：
   - 安裝程式提供了一鍵啟用本地監控堆疊的能力（包括 prometheus-operator-crds、Prometheus 和 Grafana Alloy），並透過 remote-write 整合。注意此堆疊使用暫時儲存且僅供本地開發與 demo，在已有監控基礎設施的生產叢集中不應啟用。