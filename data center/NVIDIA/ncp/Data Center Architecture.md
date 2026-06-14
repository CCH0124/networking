# Data Center Architecture

NCP 軟體參考指南是建立在 NCP 資料中心與 [NCP 硬體參考設計 (NCP Hardware Reference Design)](https://www.nvidia.com/en-us/data-center/gpu-cloud-computing/partners/) 高度一致且偏離極小的假設之上。此假設適用於所有版本的 NCP 軟體參考指南。

## GPU 運算節點 (GPU Compute Node)

建置於 NVIDIA MGX™ 開放運算平台 (OCP) 標準機櫃中的每個運算托盤 (Compute Tray) 內容如下表所述。

| 功能/元件 (Feature) | GB200 | GB300 |
| :--- | :--- | :--- |
| **通用處理器 (General Purpose Processor)** | 2 x Grace ARM CPU，每個插槽 72 個 ARM Neoverse V2 核心，最高支援 1 TB LPDDR5 | （與 GB200 相同） |
| **GPU** | 4 x B200 Blackwell GPU，總計 720GB HBM3 記憶體 | 4 x B300 Blackwell Ultra GPU，總計 1.152TB HBM3e 記憶體 |
| **本機儲存 (Local Storage)** | 最多 8 x NVMe 資料硬碟 + 1 x NVMe 啟動硬碟 | （與 GB200 相同） |
| **TAN 網路連線 (TAN Network Connectivity) (又稱南北向 N/S)** | 2 x 400GbE BF3，每個配置為 2x200GbE | 1 x 400GbE BF3，配置為 2x200GbE |
| **CIN 網路 (CIN Network) (又稱東西向 E/W)** | 4 x 400Gb CX7，可配置為 InfiniBand 或乙太網路 | 4 x 800Gb CX8，可配置為 InfiniBand 或乙太網路 |
| **SMN 網路 (SMN Network)** | 1 x 1GbE | 1 x 1GbE |

## 網路 (Networking)

在 NVIDIA® NCP 硬體參考設計資料中心內，包含四個獨特的網路：

* **TAN — 租戶存取網路 (Tenant Access Network)**：又稱為南北向 (North/South) 或前端 (Front End) 網路，是互連資料中心各個部分的主要網路，其中儲存系統是主要的流量消耗者。
* **SMN — 安全管理網路 (Secure Management Network)**：此頻外 (Out-of-band) 管理網路提供了一個安全、高可靠性的網路，用以配置和管理整個資料中心。
* **CIN — (GPU) 叢集互連網路 (Cluster Interconnect Network)**：又稱為東西向 (East/West) 或橫向擴充 (Scale Out) 網路。這是用於連接所有 GPU NVL72 機櫃以進行 GPU 對 GPU 通訊的網路。
* **NVLink**：又稱為縱向擴充 (Scale Up) 網路，是單一機櫃內的超高頻寬領域，提供本機 GPU 對 GPU 的通訊。每個 GPU 機櫃有一個獨立的 NVLink 領域。

TAN 和 SMN 一律使用乙太網路 (Ethernet)；CIN 可配置為乙太網路或 InfiniBand，而 NVLink 則是 NVIDIA 的專有標準。

## GPU 運算機櫃 (GPU Compute Rack)

GB200 和 GB300 機櫃架調度非常相似，皆包含：
* 18 個運算托盤 (Compute Trays)
* 9 個 NVL72 NVLink 交換器托盤 (Switch Trays)
* 基礎設施元件（電源機架 power shelves、加強結構 stiffeners 等等）。

![](https://app.buildwithfern.com/_next/image?url=https%3A%2F%2Ffiles.buildwithfern.com%2Fnvidia-dsx.docs.buildwithfern.com%2Fdsx%2Fd3e5b5fb68deea236b903e04d1de0f7633d848a43ca3e2a07457145fae674d77%2F_dot_dot_%2Fdocs%2Fncp%2Fsoftware-reference-guide%2Fassets%2Fimages%2Fncp-srg-gb200-gb300-compute-tray.png&w=1200&q=75)

## 儲存 (Storage)

儲存是 AI 的關鍵元件，且有多種不同的實作方式。不同的應用程式對儲存有不同的偏好（高速檔案系統與物件儲存），且頻寬需求也不同。不同的 NCP 可能希望以不同的方式提供儲存（第三方商業解決方案、開源、專有技術）。同樣地，每個 GPU 的儲存頻寬 (BW) 也會根據工作負載、模型和效能要求而有極大的差異。

NCP 硬體參考設計假設存在一個檔案儲存叢集和一個選配的物件儲存叢集。NVIDIA DGX™ Cloud 硬體設計補充規範指定了支援 24 顆硬碟機器的需求，這些機器能夠支援各種不同的儲存解決方案，包括來自 WEKA、VAST、DDN 等公司針對 AI 的產品。這些系統可以提供區塊儲存 (Block storage)、高速檔案儲存 (High-speed file storage) 和物件儲存 (Object storage) 的混合服務。

NCP 軟體參考指南假設大多數基礎設施供應商都將提供遠端區塊儲存、高速檔案系統和物件儲存的存取權，編譯出每種類型在各種 AI 工作負載中都有其眾所皆知的用途。此外，本機 NVMe 硬碟的主要使用場景包括暫存日誌 (Ephemeral logs) 或 Kubernetes 映像檔快取 (k8s image caches)。每個 NCP 應根據其個別需求來決定其具體的產品供應。

## 資料中心檢視 (Data Center View)

綜合以上所有元件，整個資料中心的架構可以如「資料中心檢視」圖所示。

![](https://app.buildwithfern.com/_next/image?url=https%3A%2F%2Ffiles.buildwithfern.com%2Fnvidia-dsx.docs.buildwithfern.com%2Fdsx%2F448a5281672ca471278c4b751e71ea95cac918ba52a274a1b5dc75a57f0ce40c%2F_dot_dot_%2Fdocs%2Fncp%2Fsoftware-reference-guide%2Fassets%2Fimages%2Fncp-srg-data-center-view.png&w=1920&q=75)

NCP 硬體參考設計支援 1 到 64 個 GPU POD（每個 POD 包含高達 1152 顆 GPU）和一個核心 POD (Core POD)。下表列出了資料中心中常見的各種運算節點類型。

### 資料中心檢視關鍵元件 (Key Data Center View Components)
| 功能 (Function) | 所在 POD | 說明 (Comment) |
| :--- | :--- | :--- |
| GPU 運算 (GPU Compute) | GPU POD | GPU 組織在專屬的 POD 中，每個 POD 包含高達 1152 顆 GPU |
| 控制節點 (Control Nodes) | 核心 POD (CORE POD) | 控制節點是執行各種控制平面與營運商服務的運算資源 |
| 通用節點 (Gen Purpose Nodes) | 核心 POD (CORE POD) | 可供使用者工作負載或其他服務使用的非 GPU 運算資源 |
| 高速儲存 (High speed Storage) | 核心 POD (CORE POD) | 伺服器專屬的軟體定義儲存 (SDS) 節點或儲存設備 |
| 公用程式叢集 (Utility Cluster) | 核心 POD (CORE POD) | 用於引導 (Bootstrap) 資料中心的基礎元件 |
| 資料中心邊緣叢集 (DC Edge Cluster) | 核心 POD (CORE POD) | 與外部世界連接的網路介面，包含防火牆 |

此處的 **POD** 結構不應與 Kubernetes Pod 混淆。資料中心裡的 **POD** 指的是資料中心的標準化實體建置模塊 (Standardized physical building block)；而 Kubernetes pod 則是 Kubernetes 的最小佈署單元。

---

## 重點整理 (Key Takeaways)

1. **運算平台升級 (GB200 vs. GB300)**
   * **處理器與儲存保持一致**：兩者皆使用雙 Grace ARM CPU (共 144 核心) 及最高 1TB LPDDR5，並支援最多 8x NVMe 資料硬碟。
   * **GPU 與記憶體大幅提升**：GB200 搭載 4 顆 B200 GPU (共 720GB HBM3)；GB300 升級為 4 顆 B300 Blackwell Ultra GPU (共 1.152TB HBM3e)。
   * **東西向網路頻寬翻倍**：GB200 的 CIN 網路採用 4 個 400Gb CX7 網卡；GB300 升級為 4 個 800Gb CX8 網卡。

2. **四大基礎網路架構**
   * **TAN (租戶存取網路 / 南北向)**：主要負責與高速儲存系統連接，使用乙太網路。
   * **SMN (安全管理網路 / 頻外)**：獨立的頻外管理通道，用以安全地配置與控制基礎設施，使用 1GbE 乙太網路。
   * **CIN (叢集互連網路 / 東西向 / 橫向擴充)**：專為多機櫃 GPU 之間大規模通訊設計，可配置為 InfiniBand 或乙太網路。
   * **NVLink (縱向擴充)**：單一機櫃內 GPU 之間的高頻寬專利互連通道。

3. **實體機櫃與儲存設計**
   * **機櫃組成**：由 18 個運算托盤 (Compute Trays) 與 9 個 NVLink 交換器托盤 (Switch Trays) 組成。
   * **儲存策略**：支援遠端區塊、高速平行檔案系統 (如 WEKA、VAST、DDN) 和物件儲存之混合架構。本機 NVMe 則專用於日誌與 Kubernetes 映像檔快取。

4. **資料中心實體模組 (POD)**
   * 資料中心以 **POD (實體建置模塊)** 劃分。包含 1~64 個 **GPU POD** (每 POD 最多 1152 顆 GPU) 和一個負責控制、公用程式及安全邊緣的 **核心 POD (Core POD)**。應避免與 Kubernetes 的邏輯 Pod 混淆。
