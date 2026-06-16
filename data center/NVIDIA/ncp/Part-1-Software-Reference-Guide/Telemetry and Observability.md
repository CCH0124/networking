# Telemetry and Observability

AI 資料中心的可觀測性 (Observability) 遵循與傳統資料中心相似的模式，但其規模和複雜度會顯著增長。具體的挑戰包括：GPU 和加速器產生的高容量遙測 (Telemetry) 數據、多樣化的高速網路（乙太網路、InfiniBand、NVLink）需要統一監控、更高的數據吞吐量要求高效的收集與儲存，以及大規模訓練協調需要跨數千個 GPU 的關聯信號。AI 資料中心需要一個統一的可觀測性解決方案，以提供對維運狀況的可見性，從而實現大規模的高效能並滿足租戶的服務層級協定 (SLA)。

![可觀測性實作架構](https://files.buildwithfern.com/nvidia-dsx.docs.buildwithfern.com/dsx/056004fdfb0043113b71c51dfd78e5db01b7d67883649722404f50218dd8b19e/_dot_dot_/docs/ncp/software-reference-guide/assets/images/ncp-srg-observability-arch.png)

該架構依賴三種信號類型：**日誌 (Logs)**（來自應用程式、系統服務與硬體的事件記錄）、**指標 (Metrics)**（系統行為的測量值，例如延遲、吞吐量和 GPU 利用率）以及**追蹤 (Traces)**（請求或操作在分散式系統中的端到端路徑）。這些信號在整個資料中心進行收集，並透過 OpenTelemetry (OTel) 管線進行標準化與關聯。透過時間戳記、資源 ID 和追蹤 ID 進行關聯，對於將信號相互關聯並準確歸屬給特定租戶或服務至關重要。該架構旨在保持供應商中立 (Vendor-neutral)，允許合作夥伴在為其系統進行檢測 (Instrument) 的同時，平衡運作速度與長期儲存成本。

* **資料產生與收集 (Data Generation and Collection)**：資料來源於三個面向：應用程式（透過 OpenTelemetry SDK 產生的指標與追蹤）、基礎設施（系統日誌以及透過 DCGM Exporter 產生的 GPU 遙測）和網路設備（透過 gNMI/OpenConfig 監控的織網健康狀況）。每個節點上皆運行一個 OTel Collector Agent (收集代理程式)，在將數據透過 OTLP 轉發至閘道之前進行本機批次處理 (Batching) 與豐富化 (Enrichment)。
* **引入與處理 (Ingestion and Processing)**：OTel Collector Gateway (收集器閘道) 提供集中式處理：過濾、抽樣、轉換，以及向多個後端的扇出 (Fan-out) 路由。串流處理器（如 Kafka）在閘道與儲存之間緩衝資料，防止在大規模 GPU 叢集產生流量尖峰時導致後端超載。
* **儲存後端 (Storage Backends)**：儲存分為熱路徑 (Hot path) 與冷路徑 (Cold path)。熱路徑使用專用的儲存庫（Loki 用於日誌、Tempo 用於追蹤、Prometheus 用於指標）進行即時監控、警報和事件響應，資料保留一到兩週。冷路徑則將資料寫入遙測資料湖 (Telemetry Data Lake，物件儲存上的 Parquet 格式) 以進行長期分析、容量規劃和歷史調查，資料保留數月至數年。

---

## 重點整理 (Key Takeaways)

1. **AI 資料中心可觀測性的挑戰**
   * 由於 GPU 產生的高容量遙測數據、多樣化的高速網路（乙太網路、InfiniBand、NVLink）、極高吞吐量以及跨數千個 GPU 的信號關聯需求，必須採用統一的可觀測性解決方案才能確保高效能並滿足租戶 SLA。

2. **核心信號與 OpenTelemetry 數據管線**
   * **三大觀測信號**：日誌 (Logs，事件記錄)、指標 (Metrics，系統狀態) 與追蹤 (Traces，分散式系統端到端請求路徑)。
   * **收集與閘道**：在節點本機執行 OTel Collector Agent 進行批次與豐富化，並透過 OTel Collector Gateway 執行集中式過濾、抽樣與分流路由。
   * **緩衝機制**：使用 Kafka 等串流處理器在閘道與儲存端之間進行緩衝，防止大規模 GPU 叢集流量暴增時造成後端超載。

3. **儲存的冷熱分流路徑**
   * **熱路徑 (Hot Path)**：聚焦即時監控與警報。使用 Loki、Tempo 及 Prometheus 作為儲存後端，資料僅保留 1~2 週。
   * **冷路徑 (Cold Path)**：聚焦長期分析與容量規劃。將數據以 Parquet 檔案格式寫入物件儲存的遙測資料湖 (Telemetry Data Lake) 中，保存數月至數年。
