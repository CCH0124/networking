# Inside an AI centric Data Center

### AI 數據中心的四大核心模組

AI 數據中心的核心在於支撐大規模的並行運算與數據吞吐，主要由以下四個區塊組成：

| 模組名稱 | 功能描述 | 關鍵角色 |
| --- | --- | --- |
| **運算節點 (Compute)** | 負責處理輸入請求、模型訓練與深度學習。 | 需要多個節點（伺服器）協同工作。 |
| **網路架構 (Network)** | 連結不同運算節點，確保低延遲的溝通。 | 支援並行運算 (Parallel Processing)。 |
| **儲存系統 (Storage)** | 存放原始數據、訓練完成的模型以及生成的新數據。 | 必須具備高讀寫效能。 |
| **基礎支撐 (Infrastructure)** | 提供營運所需的物理環境與安全防護。 | 包含電力、冷卻、安全性等。 |

### 部署高密度 GPU 工作負載的三大挑戰

當我們在數據中心部署大量 GPU（圖形處理單元）時，會面臨以下三個物理限制：

* **⚡ 電力容量 (Power Supply)**
  * **限制：** 每個機架 (Rack) 的電力供應有其上限。
  * **需求：** GPU 運算需要高度穩定且大量的電力供應，傳統機房的電力配置往往不足以支撐高密度部署。

* **❄️ 冷卻系統 (Cooling Mechanism)**
  * **限制：** 傳統冷卻方案可能無法及時排解 GPU 集群產生的高熱。
  * **需求：** 需要更高效率的機架級或室內級冷卻技術，否則散熱將成為效能瓶頸。

* **🏢 物理空間 (Physical Space)**
  * **限制：** 土地或機房樓層面積有限。
  * **需求：** 為了擴張運算力，需要更多的機架空間；若空間不足，則無法增加新的運算節點。

## Power Usage Effectiveness (PUE)

隨著 AI 模型越來越龐大，**能源效率**已經不再只是「省錢」的問題，更是**環境永續性**與**營運可行性**的保衛戰。

### 數據中心規模與年耗電量 (估計值)

數據中心的物理空間越大，其電力需求呈指數級增長：

| 數據中心類型 | 物理面積 (平方英尺) | 估計年耗電量 (MWh/年) |
| --- | --- | --- |
| **標準/小型** | 約 1,000 | < 500 |
| **中型** | 10,000 ~ 50,000 | 約 5,000 |
| **超大規模 (Hyperscaler)** | 數十萬以上 | 極高 (以 TWh 計) |

### 電力消耗的去向：傳統 vs. 現代

電力的使用效率決定了每一分錢是花在「算力」上，還是花在「廢熱處理」上。

* **傳統數據中心 (效率較低)：**
  * **IT 設備：** 僅佔 **50%**。
  * **非 IT 消耗：** 另外 50% 消耗在冷卻、配電損失、照明與安全系統上。


* **現代數據中心 (AI 導向/高效能)：**
  * **IT 設備：** 可高達 **90%**。
  * **非 IT 消耗：** 僅需 10% 處理冷卻與轉換。這得益於更先進的液冷技術與更高效的變壓設備。

### 核心衡量指標：PUE (能源使用效率)

**PUE (Power Usage Effectiveness)** 是衡量數據中心綠能化最標準的指標。

**1. 計算公式：**


$$PUE = \frac{\text{Total Facility Energy (數據中心總能耗)}}{\text{IT Equipment Energy (IT 設備能耗)}}$$

**2. PUE 數值的意義：**
PUE 的數值越接近 **1.0**，代表效率越高、浪費越少。

| PUE 數值 | 效率評價 | 說明 |
| --- | --- | --- |
| **1.2 或更低** | **極高效率 (Highly Efficient)** | 頂尖雲端供應商 (AWS, Google, Microsoft) 的標準。僅有 20% 的電力用於非運算用途。 |
| **1.5 ~ 1.9** | **普通/中等** | 多數企業自建數據中心的水平。 |
| **2.0** | **低效率** | 代表每花 1 瓦在運算上，就必須額外花 1 瓦在冷卻和配電，能源成本翻倍。 |

### 為什麼 PUE 對 AI 工作負載至關重要？

1. **環境影響：** AI 訓練極度耗電，低 PUE 能顯著減少碳足跡。
2. **營運成本 (OPEX)：** 對於 Hyperscaler 而言，PUE 從 2.0 降到 1.2，每年可節省數千萬美金的電費。
3. **基礎建設優化：** 幫助設計者專注於改善冷卻系統與電力分佈，而不是盲目增加電力供給。

> 請記住 **PUE 越低越好**。1.2 是現代高效能數據中心的指標，而 2.0 則被認為是效率低下的象徵。

## The Computer Power

### 運算力的兩大支柱：CPU vs. GPU

在 AI 數據中心裡，雖然 CPU 依然負責調度與邏輯控制，但真正的「搬運工」是 GPU。

| 組件 | 全稱 | 核心角色 | 特點 |
| --- | --- | --- | --- |
| **CPU** | 中央處理器 (Central Processing Unit) | 數據中心的「大腦」。 | 擅長處理複雜的序列邏輯、指令調度。 |
| **GPU** | 圖形處理器 (Graphics Processing Unit) | 數據中心的「肌肉」。 | 擁有數千個小核心，專為**大規模並行運算**（如渲染像素或矩陣運算）而設計。 |

### 為什麼 AI 非 GPU 不可？

這是一個非常有趣的技術「巧合」。**渲染 3D 畫面**（計算數百萬個像素點的顏色）本質上就是大規模的**矩陣數學運算**，而這正好與**訓練神經網路**（計算數百萬個參數的權重）所需的運算類型不謀而合。

## CPU and GPU

私人飛機 vs. 民航客機

| 特性 | **CPU (私人飛機)** | **GPU (民航客機)** |
| --- | --- | --- |
| **載客量 (核心數)** | 座位少，但極其豪華、強大。 | 座位極多（數千個），雖然簡單但數量龐大。 |
| **靈活性** | **高**。隨時起飛，去任何地方（通用運算）。 | **低**。走固定航線，適合大規模運輸（專門任務）。 |
| **核心目標** | **速度與客製化**。快速處理單一複雜任務。 | **吞吐量 (Throughput)**。一次運送大量乘客。 |
| **最佳場景** | 運送 CEO 或小團隊（少量、複雜的邏輯指令）。 | 同時運送數百名遊客（大規模並行數據）。 |

### 技術面：CPU 與 GPU 的核心差異

1. 核心設計 (Cores)

    * **CPU (中央處理器)**：擁有少數幾個（如 8、16、64 個）非常聰明的核心。它們像是「天才教授」，能處理極其複雜的數學題、邏輯判斷與指令調度。
    * **GPU (圖形處理器)**：擁有成千上萬個較簡單的核心。它們像是「大量的小學生」，雖然單獨看不如教授聰明，但如果任務是「每人算 1+1」（如計算像素亮度、矩陣乘法），一萬個小學生的速度遠超一位教授。

2. 處理方式 (Serial vs. Parallel)

    * **CPU - 序列處理 (Serial)**：一個接一個完成任務。適合運行作業系統（OS）、複雜應用程式。
    * **GPU - 並行處理 (Parallel)**：同時處理成千上萬個任務。
    * **例子**：正如提到的**油漆圍欄**，CPU 是一個人刷完全部；GPU 是找一百個人同時刷一百根木頭。

3. 性能焦點 (Latency vs. Throughput)

    * **低延遲 (Low Latency)**：CPU 追求的是*快速反應*。當你點擊滑鼠，CPU 要立即回應。
    * **高吞吐量 (High Throughput)**：GPU 追求的是*單位時間內處理的總量*。在 AI 訓練中，我們不在乎單個數據快 0.001 秒，我們在乎的是能否在一小時內處理掉數十億筆數據。

### 應用場景對比

| 應用領域 | **CPU (擅長)** | **GPU (擅長)** |
| --- | --- | --- |
| **系統層面** | 運行 Windows/Linux 作業系統、啟動軟體。 | 無。 |
| **AI / 數據** | 小規模數據處理、邏輯分支判斷。 | **生成式 AI (LLM)**、深度學習訓練。 |
| **視覺效果** | 影片播放控制。 | **3D 渲染**、影片轉碼、遊戲繪圖。 |
| **特殊領域** | 資料庫查詢與管理。 | 加密貨幣挖礦、科學模擬（天氣預測）。 |

## CPU vs GPU - Architectural difference

### CPU 與 GPU 架構對比表

| 特性 | **CPU (以 Intel i9 為例)** | **GPU (以 NVIDIA RTX 4090 為例)** |
| --- | --- | --- |
| **核心數量 (Cores)** | **少而強**：約 24 個核心。 | **多而精**：約 16,000 個核心。 |
| **控制單元 (Control Unit)** | 非常複雜，負責處理複雜的指令調度與分支預測。 | 相對簡單，主要負責同步大量核心的並行運算。 |
| **主要功能** | 序列執行與邏輯控制 (ALU/Control Unit)。 | 大規模並行處理 (Massive Parallelism)。 |
| **快取機制 (Cache)** | 階層明確 (L1, L2, L3)，強調減少延遲。 | 擁有 L1/L2 快取，但更依賴高頻寬的顯存。 |

### CPU 架構分析

CPU 就像是一個極度精密的指揮中心，其架構設計旨在快速處理各種不確定的任務。

* **多層快取 (Multi-level Cache)**：
* **L1/L2 Cache**：通常分配給個別核心，提供極速的數據存取。
* **L3 Cache**：較大的共享快取，負責在核心間同步數據。
* **算術邏輯單元 (ALU)**：雖然核心少，但每個 ALU 都能處理非常複雜的運算。

### GPU 架構分析

GPU 的構造更像是一個擁有數萬名工人的巨型工廠，所有工人在同一時間執行相似的簡單動作。

* **核心密度**：在物理尺寸相近的情況下，GPU 塞入了成千上萬個核心。
* **專屬顯存 (GPU Memory/VRAM)**：GPU 通常配備大容量的高速顯存，專門處理運算所需的龐大數據集。
* **並行結構**：控制單元與快取是為了*同時*管理大量核心而設計的，而非為了單一任務的極速響應。

### 記憶體階層：系統與設備

理解兩者如何存取數據是優化 AI 運算性能的關鍵：

1. **系統記憶體 (System Memory / RAM)**：
    * 這是電腦或伺服器的主記憶體。
    * **CPU** 直接與其通訊並管理。

2. **GPU 顯存 (GPU Memory / VRAM)**：
    * GPU 擁有自己的獨立高速記憶體。

3. **互連通訊**：
    * 根據硬體架構（如 PCIe 通道），**CPU 與 GPU 都可以存取系統記憶體**。
    * 在 AI 運算中，數據通常先載入 RAM，再搬移到 GPU 顯存中以進行高速運算。

## Data Processing Unit(DPU)

什麼是 DPU？

在 AI 資料中心裡，**CPUs 和 GPUs 負責「運算」（Compute），而 DPUs 則負責「讓運算得以順利進行」（Make it possible）**。


* **機長（CPU/GPU）：** 專注於將飛機從 A 點開到 B 點（執行核心運算任務）。機長不需要自己去加油、搬行李或檢查跑道。
* **地勤與空服團隊（DPU）：** 包含行李搬運工、移民官、空服員、塔台、維修工程師。他們各司其職，處理所有周邊與後勤支援，讓機長能百分之百專注在「飛行」上。

**DPU（Data Processing Unit，資料處理器）** 是一種專門用來處理「以資料為中心（Data-Centric）」**基礎設施工作負載的專用晶片。它的核心目的就是將原本會損耗 CPU 珍貴週期的工作**過載卸載（Offload）下來。


### DPU 的三大核心任務

DPU 主要幫 CPU 和 GPU 分擔以下三大領域的基礎設施工作：

1. 網路處理 (Networking)

    * 封包的建立與處理解析。
    * 流量負載平衡 (Load Balancing)。
    * 處理重疊與基礎網路（Overlay/Underlay Networking）。
    * 支援 **RDMA（遠端直接記憶體存取）**，讓伺服器之間能以極低延遲直接交換資料，不驚動 CPU。

2. 儲存加速 (Storage)

    * 資料的即時壓縮與解壓縮。
    * 儲存資料的加密與解密。
    * 執行資料重複刪除（Data Deduplication），優化空間。

3. 安全防護 (Security)

    * 運行硬體級防火牆與深層封包檢查 (DPI)。
    * 卸載 IPsec 或 TLS 加密協定。
    * 實作多租戶隔離（Multi-tenant Isolation）與零信任（Zero Trust）架構的安全執法。

### 核心架構大比拼：CPU vs. GPU vs. DPU


| 特性 / 元件 | **CPU (中央處理器)** | **GPU (圖形處理器)** | **DPU (資料處理器)** |
| --- | --- | --- | --- |
| **主要角色** | 通用目的運算 (General Purpose) | 平行運算加速器 (Parallel Compute) | 資料移動與基礎設施卸載 |
| **最擅長** | 執行應用程式邏輯、決策判斷、循序任務、作業系統管理 | 圖形渲染、AI/ML 模型訓練與推論、科學模擬、大規模平行數學運算 | 網路封包處理、儲存加速、硬體級加密、防火牆安全規則 |
| **缺點/不擅長** | 無法有效擴展數以千計的平行任務 | 不擅長通用邏輯控制與作業系統（OS）層級的操作 | 無法運行使用者應用程式，不具備重度數學運算能力 |
| 🚗 **交通工具比喻** | **私人飛機：** 靈活度極高、哪裡都能去，但座位（核心數）非常有限。 | **民航客機：** 能極其高效地載送成百上千人，但只能走固定航線（特定任務）。 | **機場地勤團隊：** 確保整場航空營運安全高效，但他們自己不負責飛上天。 |

### 伺服器架構的演進

#### 傳統企業伺服器 (Traditional Server)

在過去，所有的工作都塞在一個地方：

* **應用程式商業邏輯：** CPU 處理
* **作業系統控制：** CPU 處理
* **軟體定義 I/O 與網路：** CPU 處理 *(造成 CPU 的「基礎設施稅」損耗)*
* **安全防護：** CPU 處理

#### 現代 AI 優化伺服器 (Modern / NVIDIA-Certified Server)

在現代 AI 資料中心裡，元件各司其職，達到完美的分工：

* **GPU：** 專職處理**應用程式商業邏輯、AI/ML 訓練、大數據分析與專業視覺化**。
* **CPU：** 退居幕後，專注於**作業系統（OS）管理與應用程式的控制流程（Control Flows）**。
* **DPU：** 頂替所有苦力，全權負責**軟體定義 I/O、網路傳輸與安全防護（Security）**。

透過這種三位一體的架構，現代伺服器才能在不浪費任何算力的情況下，高效支撐起龐大的 AI 叢集。

## Network

在 AI 資料中心裡，光有強大的算力（CPU/GPU/DPU）還不夠，如果沒有極致優化的網路通訊，再強的晶片也只是在原地「等資料」，這就是網路織網（Network Fabric）登場的時刻。

### 為什麼 AI 資料中心需要「網路分離」？

將所有流量混在單一網路上會導致嚴重的效能瓶頸。實施物理或邏輯上的網路隔離，主要基於以下五大核心考量：

1. **效能與延遲隔離 (Performance & Latency Isolation)：** AI 訓練對延遲極度敏感。將需要高頻寬、低延遲的運算流量，與低頻寬的管理流量分開，確保運算不會被干擾。
2. **故障隔離與韌體魯棒性 (Failure Isolation & Robustness)：** 當其中一個網路發生故障或擁塞時，其他網路仍能正常運作。例如：當業務網路癱瘓時，管理網路還能用來排查問題。
3. **安全防護 (Security)：** 對外網路需要嚴格的防火牆與安全控制；對內網路（如運算與儲存）則著重於極速傳輸，採用較輕量但高效的安全策略，並實施零信任隔離。
4. **獨立擴充性 (Scalability)：** 當資料集暴增時，可以只升級「儲存網路」的容量，而不需要牽動或重新設計「運算網路」。

### NVIDIA AI 資料中心的四大網路織網 (Network Fabrics)

1. 運算網路 (Compute Fabric)

    * **核心定位：** 資料中心內最繁忙、效能要求最高的網路。
    * **主要任務：** 負責處理伺服器節點之間（Node-to-Node）的應用程式流量與並行計算（如大模型訓練時的參數同步、East-West 流量）。
    * **技術特性：** 極度追求超低延遲與高頻寬，通常採用 InfiniBand 或高效能乙太網路（RoCE）。

2. 儲存網路 (Storage Fabric)

    * **核心定位：** 資料吞吐的命脈。
    * **主要任務：** 負責將海量的訓練資料集、檢查點（Checkpoints）快速且不間斷地從儲存設備（如 NVMe 陣列）餵給運算節點。
    * **技術特性：** 追求極高的吞吐量（Throughput），確保 GPU 不會因為「餓肚子（等待資料）」而閒置。

3. 帶內管理網路 (In-Band Management Network)

    * **核心定位：** 系統運行時的政務通道。
    * **主要任務：** 當伺服器作業系統（OS）正常運行時，負責日常的組態配置、軟體更新、部署作業以及收集監控 Telemetry/Prometheus 指標數據。
    * **技術特性：** 走一般的業務網路路徑，與應用程式共享 OS 的網路堆疊。

4. 帶外管理網路 (Out-of-Band Management Network, OOB)

    * **核心定位：** 獨立於 OS 之外的「救災與終極控制通道」。
    * **主要任務：** 當作業系統崩潰、當機、甚至伺服器電源關閉時，管理員仍能遠端存取伺服器。
    * **實現方式：** 透過伺服器主機板上的專用硬體 **BMC（基板管理控制器）** 進行遠端電源控制、重開機、查看底層日誌與韌體更新。

## Network Fabric

四大網路綜合對比表

| 網路織網 (Fabric) | 核心目的 (Purpose) | 實作技術 (Implementation) | 關鍵設計特點與考量 (Design Features) |
| --- | --- | --- | --- |
| 運算網路 (Compute) | GPU 節點內與節點間通訊；AI 訓練與推論任務的骨幹 | InfiniBand；RoCE (RDMA over Converged Ethernet)；NVLink Fabric | 極致超低延遲與超高吞吐量；具備高可靠的**線性擴充性**（增加伺服器時效能不遞減） |
| 儲存網路(Storage) | 連接運算節點與儲存設備;處理檔案系統 Checkpoints 與 I/O 流量 |InfiniBand;Ethernet RoCE（依設計可單獨或混合建置） | 每節點需達到 **Multi-GB** 的高吞吐量；必須與運算流量**絕對隔離**，避免搶佔頻寬 |
| 帶內管理(In-Band Mgmt) | 叢集管理、SSH、DNS、作業排程；存取外部代碼庫以安裝套件與修補程式 | 乙太網路 (Ethernet)；物理拓撲：Leaf-Spine (葉脊網路)；邏輯隔離：VLAN, VXLAN, EVPN | 中高頻寬需求（因應大型套件下載；強調通訊可靠性與邏輯上的流量隔離 |
| 帶外管理(Out-of-Band) | 遠端硬體控制（電源開關、虛擬主控台）；當 OS 崩潰或帶內網路斷線時的終極救援 | 伺服器專用硬體（內建 BMC 或專用子卡）；獨立的物理網口與低速交換器 | **必須保證 100% 隨時可用**（Last Resort）；頻寬要求低，但**存取權限控管與安全性要求極高** |

## Ethernet vs InfiniBand

核心技術對比表

| 比較特性 | 🌐 乙太網路 (Ethernet) | 🚄 InfiniBand |
| --- | --- | --- |
| **🚗 核心比喻** | **公用高速公路系統：** 汽車、卡車、巴士都能上，但有紅綠燈與車流回堵問題。 | **新幹線/專用彈丸列車：** 專屬軌道、極少停靠站、超高速，但只能走特定路線。 |
| **⏳ 誕生背景** | 1970 年代（為了辦公室區域網路 LAN 而生，後成為全球網際網路標準）。 | 2000 年（專為超級電腦與高效能運算 HPC/AI 打造的利基技術）。 |
| **🎯 主要應用** | 通用網路、LAN、WAN、雲端計算、大眾網際網路。 | 高效能運算 (HPC)、AI 訓練叢集、高速儲存互聯（如 NVMe-oF）、資料中心。 |
| **⚡ 傳輸速率** | 1 Gbps 至 400 Gbps+（兩者在頻寬上限上是不相上下的）。 | 10 Gbps 至 400 Gbps+（最新標準甚至邁向 800 Gbps）。 |
| **📉 延遲表現** | **較高：** 約 10 至 100 微秒 (Microseconds)。 | **極低：** 僅 1 至 2 微秒，具備高度確定性 (Deterministic)。 |
| **🧠 協議棧與架構** | 傳統 **TCP/IP 協議棧**，資料傳輸需要驚動 CPU 進行多次封包拆解。 | **RDMA (遠端直接記憶體存取)**，直接繞過作業系統與 CPU。 |
| **💰 建置成本** | **低廉：** 可使用商用現貨 (Commodity Hardware)，維護生態系龐大。 | **高昂：** 需要專用的晶片、交換器與硬體線材（如 QSFPs、光纖）。 |
| **📦 軟硬體相容** | **宇宙級通用：** 所有作業系統、驅動程式與網卡 (NIC) 原生支援。 | **專用生態：** 需要專門的驅動程式與軟體堆疊（如 OFED 驅動）。 |
| **🛡️ 可靠性機制** | **可能丟包 (Lossy)：** 網路擁塞時靠 TCP 重新傳送，會造成 AI 訓練延遲。 | **硬體級無損 (Lossless)：** 透過基於信用的流控機制，確保封包絕不遺失。 |

### 為什麼 InfiniBand 的延遲能低到 1-2 微秒？

傳統的乙太網路走 TCP/IP 協議，當資料抵達伺服器時，網卡必須通知 CPU，CPU 再把資料從系統核心緩衝區（Kernel Buffer）複製到應用程式記憶體（User Space）。這個過程會偷走寶貴的 CPU 週期，並增加延遲。

InfiniBand 採用了 **RDMA（Remote Direct Memory Access，遠端直接記憶體存取）** 技術。

* **CPU 旁路 (CPU Bypass)：** 資料可以直接從 A 伺服器的記憶體，透過 InfiniBand 網卡直接寫入 B 伺服器的記憶體，全程**完全不驚動兩邊的 CPU 與作業系統**。這也是為什麼它能達到微秒級的超低延遲。

### 流量控制：無損網路 (Lossless) 的重要性

在 AI 大模型訓練中，數千張 GPU 需要同步參數（例如 All-Reduce 操作）。如果網路中途掉了一個封包，整個叢集的 GPU 都必須停下來等待 TCP 重新連線與傳送，這會導致 GPU 算力嚴重閒置。

* **Ethernet** 預設是*盡力而為（Best-Effort）*的丟包網路。
* **InfiniBand** 在硬體層面採用了 **Credit-based Flow Control（基於信用的流量控制）**。接收端會告訴發送端：*我現在還有多少緩衝空間（信用值），你才能發多少資料。*從根本上杜絕了因為接收端緩衝區溢位而導致的丟包，實作了真正的**無損網路（Lossless Network）**。

## Converged Ethernet(CE)

### 什麼是融合乙太網路 (Converged Ethernet)？

在傳統的資料中心架構中，一台伺服器後方往往像盤絲洞一樣複雜，因為不同的流量必須各走各的路：

1. **LAN 流量（區域網路）：** 負責一般的應用程式、網頁、使用者管理流量。
2. **SAN 流量（儲存區域網路）：** 專門負責連接儲存設備（如 Fiber Channel 協定），確保資料讀寫。
3. **HPC 流量（高效能運算）：** 負責伺服器之間的叢集並行計算。

**傳統痛點：** 這意味著每台伺服器需要 **3 種不同的網卡/接頭**、**3 種不同的線材**、以及 **3 套完全獨立的網路交換器（Switches）**。管理成本極高，機房後方雜亂無章。

### 融合之後的解方：三線合一

融合乙太網路的核心思想就是：***用一條高頻寬的物理乙太網路線，同時承載 LAN、SAN 和 HPC 這三種截然不同的流量。***

* **物理高冗餘：** 雖然說是合一，但為了避免單點故障（Single Point of Failure），實務上每台伺服器至少會拉兩條線（Dual-homing）到不同的交換器上實作備援。
* **高超頻寬：** 由於要同時吞吐這三種海量流量，融合乙太網路的起跳頻寬通常極高，涵蓋 **40G、100G、200G 甚至最新的 400G/800G**。
* **RoCE 的運作原理：** 它是把 InfiniBand 的網路層與傳輸層封包，直接封裝到標準的乙太網路影格（Ethernet Frame）當中。
* **核心價值：** 它讓原本成本較低的乙太網路環境，也能享有「繞過 CPU（CPU Bypass）」的超能力。這樣一來，網路卡在搬運 AI 大模型參數時，不需要扣除伺服器珍貴的 CPU 算力，同時實作了接近 InfiniBand 的極低延遲表現。

### 融合乙太網路的四大核心優勢

* **極致的成本效益 (Cost-Efficient)：** 需要購買與管理的交換器數量直接砍三分之二，大幅減少硬體採購成本。
* **降低能耗與空間 (Low Power & Space)：** 機房線路變乾淨了，交換器變少了，冷卻電力與空間佔用隨之大幅下降。
* **超低延遲 (Low Latency)：** 透過特定流量控制協議，確保對延遲敏感的運算流量不會被一般網頁流量給卡死。
* **引入 RDMA 加速：** 這就是 **RoCE** 的由來。

## Storage

**NVIDIA 本身並不直接製造儲存硬體或開發儲存軟體**。

NVIDIA 的策略是定義標準，交給夥伴。他們透過釋出如 **GPUDirect Storage (GDS)** 等頂層軟體技術棧，讓儲存大廠（如 NetApp, Pure Storage, VAST Data, Dell 等）將自己的解決方案整合進 NVIDIA 的生態系中。

>**硬體加速考點：** 透過 NVIDIA GDS 技術，第三方夥伴的儲存設備可以直接利用 RoCE/InfiniBand 網路，**將資料直接打入 GPU 記憶體（繞過 CPU）**，這完美呼應了我們前面提到的 DPU 與 RDMA 觀念，全面消除 AI 運算時的儲存瓶頸

### AI 資料中心的四種核心儲存選項

AI 任務（尤其是大型語言模型訓練）對儲存的要求可以總結為三個極致：**超高吞吐量（Throughput）、極低延遲（Low Latency）與大規模橫向擴充性（Scalability）**。實務上會部署以下四種儲存角色：

1. 本地 NVMe SSD (Local Storage)

    * **定位：** 伺服器機殼內部的「快炒區調料架」。
    * **特點：** 直接插在 GPU 伺服器主機板上，具備極高速的 I/O 讀寫能力。
    * **應用場景：** 用於模型訓練與推論過程中，需要頻繁讀寫的核心暫存資料與快取（Cache）。
    * **考點/限制：** **容量受到伺服器實體空間的嚴格限制**，無法無限制擴充。

2. 平行檔案系統 (Parallel File System / Clustered Storage)

    * **定位：** 中央大型高效能儲存庫。
    * **特點：** 屬於叢集式儲存，允許**成百上千個 GPU 節點同時、並行地存取同一個巨大資料集**，徹底打破單一儲存節點的效能瓶頸（如 Weka, Lustre, IBM Spectrum Scale 等）。
    * **應用場景：** 存放進行中（Active）的大規模 AI 訓練資料集、頻繁寫入的模型檢查點（Checkpoints）與 I/O 密集型流量。

3. 網路檔案系統 (Network File System / NFS)

    * **定位：** 廚房內共享的小型工具櫃。
    * **特點：** 傳統的分散式檔案系統，速度不如平行檔案系統，但勝在架構簡單、通用。
    * **應用場景：** 用於在各個節點之間共享容量較小、變動不頻繁的資料，例如軟體環境組態設定（Configurations）和自動化運行腳本（Scripts）。

4. 物件儲存 (Object Storage / 如 Amazon S3, MinIO)

    * **定位：** 餐廳的地下大型冷凍批發倉庫。
    * **特點：** 能夠以極低成本存放海量（PB、EB 等級）的非結構化資料，擴充性無限，但延遲較高。
    * **應用場景：** 長期封存原始未處理的原始資料集（Raw Datasets）、歷史模型快照、長期日誌（Logs）收集。

### 現代 AI 資料中心的分層儲存（Tiered Storage）策略

在實務建置中，為了在「極致效能」**與**「建置成本」**之間取得平衡，資料中心絕對不會只用一種儲存，而是採用**混合分層架構（Hybrid Approach）並搭配生命週期策略（Lifecycle Policies）：

| 資料層級 (Tier) | 儲存媒介 | 資料特性 | 廚房比喻 |
| --- | --- | --- | --- |
| **熱資料 (Hot Data)** | 本地 NVMe SSD + 平行檔案系統 | 正在進行的主模型訓練、頻繁讀寫的 Checkpoints、極度消耗 I/O 的即時資料。 | **流理台上的現成食材：** 主廚右手一伸就要立刻拿到的東西。 |
| **溫資料 (Warm Data)** | 高容量網路儲存 / 近線儲存 | 準備用於下一輪訓練的驗證資料集、近期封存的模型版本。 | **廚房後方的冷藏櫃：** 每天都會用到幾次，需要稍微走過去拿。 |
| **冷資料 (Cold Data)** | 物件儲存 (Object Storage) | 歷史訓練日誌、數年前的原始備份資料、已退役的舊模型。 | **地下室的冷凍庫：** 幾個月才進去調一次貨，便宜、空間大，但搬運耗時。 |

## Layer1 - Physical Layer

### DGX SuperPOD

單台 DGX 伺服器雖然強大，但面對動輒千億、萬億參數的基礎大語言模型（Foundational LLMs），就像是用單個頂級主廚去應付全亞洲的食客。這時我們就需要 **NVIDIA DGX SuperPOD** 這種的架構實作，將多台 DGX 節點徹底聚合，融合成一台真正的 **AI 超級電腦（AI Supercomputer）**。

#### 什麼是 NVIDIA DGX SuperPOD？

DGX SuperPOD 是一套**專為大規模 AI 和高效能運算（HPC）設計的叢集架構與超算基礎設施**。它不是單一硬體，而是由數十到數百台 DGX 節點，透過特定藍圖（Blueprint）高度整合而成的可擴充系統，能提供百億億次（Exascale）級別的頂級運算效能。

#### DGX SuperPOD 的四大支柱架構

這完美呼應了我們前面討論過的所有單元，SuperPOD 就是將算力、網路、儲存與管理發揮到極致的成果：

1. **計算節點叢集 (Compute Nodes)：** 由多台 DGX 伺服器作為基礎算力單元，內部滿載頂級 GPU。
2. **極速網路織網 (InfiniBand Fabric)：** 節點與節點之間全部採用 **InfiniBand** 互聯。這就是我們之前比喻的「專用彈丸列車軌道」，確保幾百台伺服器在同步海量模型參數時，達到微秒級的超低延遲與無損傳輸。
3. **高效能儲存系統 (Storage System)：** 整合高速的平行檔案系統（Parallel File System），確保數千張 GPU 同時讀寫龐大訓練集或寫入 Checkpoints 時，儲存端不會發生任何瓶頸。
4. **帶內/帶外與堡壘機管理 (Management & Jump Box)：**
    * **帶內/帶外管理：** 負責整個超算叢集的日常派課、資源調配（如 Slurm/Kubernetes），並透過 BMC/OOB 在硬體當機時進行底層救援。
    * **跳板機/堡壘機 (Jump Box)：** 作為安全的大門，維運人員或研究員必須先連線至 Jump Box，才能進一步存取與操控內部封閉且極度安全的超算節點。

#### 何時該用 SuperPOD？

建置 SuperPOD 需要龐大的資金、長期的機房電力與空間規劃、以及極高昂的維運人力成本，因此它有著非常明確的市場分水嶺：

完美適用場景 (Ideal Use Cases)

* **頂級企業與國家級實驗室：** 建立 AI 卓越中心 (Center of Excellence, CoE) 或國家級科研單位。
* **基礎大模型訓練：** 需要從零開始訓練（Pre-training）Foundational Models、大規模 LLM 或多模態（Multimodal）AI。
* **全球級規模部署：** 需要跨國、跨基礎設施進行大規模的聯邦學習（Federated Learning）與高效能平行運算（HPC）。
* **多租戶環境 (Multi-Tenancy)：** 科研機構內有數百個不同團隊、數千名研究員需要同時調度超算資源。

完全不適用場景 (When NOT to Use)

* **中小企業 (SMBs)：** 預算與資料量有限，使用雲端算力或單台 DGX 即可滿足需求。
* **邊緣運算與嵌入式 AI (Edge/Embedded AI)：** 邊緣端（如自駕車、工廠相機）著重低功耗與即時反應，屬於嵌入式晶片的領域。
* **純 AI 推論任務 (Pure Inferences)：** 如果只需運行已訓練好的模型進行推論（Inference），不需要如此恐怖的並行運算骨幹。
* **成本敏感型部署 (Cost-Sensitive Deployments)：** SuperPOD 的硬體、電費及冷卻系統造價極高，非一般預算型專案所能承受。

[nvidia | dgx-superpod](https://docs.nvidia.com/dgx-superpod/reference-architecture-scalable-infrastructure-h100/latest/dgx-superpod-architecture.html)

### BlueField DPU / SuperNIC

簡單來說，它是一張*自帶強大運算能力的超級智慧網卡*。傳統網卡只負責收發封包，剩下的封包解析、加密、防火牆規則通通都要丟給主機的 CPU 或 GPU 處理。而 BlueField DPU 內部直接封裝了 ARM 運算核心、網路加速引擎以及硬體加密晶片，直接在網卡上把這些雜事做完。

#### DOCA 框架 (Data Center Infrastructure on a Chip Architecture)

* CUDA： 開發者用來編寫、管理 GPU 進行 AI 與科學運算的軟體平台。
* DOCA： 開發者用來編寫、管理 DPU 進行網路、儲存與安全加速的軟體框架。

有了 DOCA，工程師不用去研究底層晶片的暫存器，可以直接調用 API 來實作零信任安全、軟體定義網路（SDN）與硬體級儲存加速。

#### BlueField DPU 的核心四大超能力

| 能力項目 | 具體實作內容 | 帶來的核心效益 |
| --- | --- | --- |
| 基礎設施卸載(Infrastructure Offload) | 處理封包封裝/解封裝（VXLAN/NVGRE）、網路流量負載平衡（Load Balancing）。 | 釋放主機 CPU/GPU 的珍貴週期，讓它們專注於 AI 模型計算。 |
| 零信任安全安全(Zero-Trust Security) | 線速（Line-rate）硬體加密/解密（IPsec, TLS）、深層封包檢查與硬體防火牆。 | 實作多租戶隔離（Multi-tenant Isolation），即便主機 OS 被黑，網卡端的防線依舊穩固。 |
| 儲存虛擬化加速(Storage Acceleration) | 實作 NVMe-oF（NVMe over Fabrics），在網路傳輸中直接進行資料壓縮與解壓縮。 | 讓遠端儲存設備讀起來就像本地的 NVMe SSD 一樣快。 |
| 雲端原生加速(Cloud-Native Acceleration) | 加速容器化環境（Kubernetes）的網路外掛（CNI），優化微服務通訊。 | 完美契合超大規模（Hyperscale）與雲端服務商（CSP）的資料中心架構。 |

#### 什麼時候不需要部署 BlueField？

* **無卸載需求：** 正常的傳統單機工作負載，CPU 還有大把閒置空間時，不需要多花錢買 DPU。
* **無多租戶/安全隔離需求：** 封閉、單一使用者、且對安全防禦要求不高的環境。
* **低吞吐量環境：** 網路頻寬需求很低（例如一般的辦公室網路），完全不需要動用到 SuperNIC 與 NVIDIA Spectrum 交換器的極速組合。

### Understanding GPU Cores

大眾常誤以為 GPU 是一個單一的巨大算力怪獸，但實際上它是一個高度分工的專業團隊。現代 NVIDIA GPU 內部並非只有一種核心，而是由多種專用硬體單元（Execution Units）組合而成：

1. CUDA 核心 (CUDA Cores)

    * **🧠 硬體本質：** 負責處理基礎的**純量（Scalar）與向量（Vector）數學運算**（如單精度 FP32、整數 INT32）。
    * **AI/計算角色：** 負責執行傳統的圖形渲染、基本的資料預處理，以及 AI 模型中非矩陣類型的通用邏輯與數學運算。

2. Tensor 核心 (Tensor Cores)

    * **🧠 硬體本質：** 專為矩陣數學運算（Matrix Multiplication and Accumulate, MMA）打造的硬體加速器，支援混合精度（如 FP16、BF16、FP8、INT8）。
    * **AI/計算角色：** **大模型訓練與推論的真正核心（AI 的火箭引擎）**。深度學習的本質就是海量的矩陣乘法，Tensor 核心可以在單個時脈週期內吞吐巨大的矩陣運算，速度比 CUDA 核心快上數十倍。

3. 光線追蹤核心 (Ray Tracing / RT Cores)

    * **🧠 硬體本質：** 專門用來加速**邊界體積階層（BVH）射線遍歷**與**射線-三角形相交測試**的專用硬體。
    * **AI/計算角色：** 專職負責 3D 遊戲與專業動畫中的即時光線追蹤（Real-time Ray Tracing）。在 AI 領域中，它們也被應用於物理模擬、3D 生成式 AI（如 NeRF 或 3D 空間重建）的光影渲染。


#### 驅動程式與 API 框架

有了這群身懷絕技的核心，還需要一個強大的校長（管理階層）來調度資源，這就是 NVIDIA 的軟體生態系：

* **校長的行政藍圖 (APIs & Frameworks)：** 像是 **CUDA Toolkit、TensorRT、OptiX**，甚至是頂層的 PyTorch 和 TensorFlow。
* **校長的廣播系統 (NVIDIA Drivers)：** 將軟體發出的高階指令（例如：這是一堂深度學習課），精準地指派給正確的老師（Tensor 核心負責矩陣乘法，CUDA 核心負責啟動函數與資料搬移）。

#### NVIDIA GPU 產品線與核心配置邏輯

**為什麼資料中心 GPU 沒有 RT 核心？**

硬體設計的最高原則是，每一寸矽晶圓（Silicon）都極度昂貴，因此不同場景的 GPU，其內部空間配置截然不同：

| 產品系列 (Families) | 適用場景 | CUDA 核心 | Tensor 核心 (AI 奧數專家) | RT 核心 (光影藝術家) | 設計邏輯解析 |
| --- | --- | --- | --- | --- | --- |
| **GeForce GTX** (如 GTX 1080) | 早期電競與傳統繪圖 | ✅ 有 | ❌ 無 | ❌ 無 | 舊時代架構，純靠 CUDA 核心硬幹所有算力，無專屬硬體加速。 |
| **GeForce RTX** (如 RTX 4090) | 現代高階電競與創作者 | ✅ 有 | ✅ 有 | ✅ 有 | 消費級旗艦，需要兼顧遊戲基礎畫質（CUDA）、AI 增強（Tensor/DLSS）與極致光影（RT）。 |
| **Data Center (如 A100, H100)** | AI 訓練、LLM、超算中心 | ✅ 有 | ✅ 有 **(面積與效能極大化)** | ❌ 無 | **資料中心不需要螢幕，不需要算光影！** 省下 RT 核心的矽片空間，全部塞滿最強大、最巨大的 Tensor 核心來加速 AI 矩陣運算。 |
| **Jetson (如 Orin)** | 邊緣運算 (自駕車、無人機) | ✅ 有 | ✅ 有 | ❌ 無 | 邊緣設備需要即時 AI 推論（如物件辨識），需要 Tensor 核心，但不需華麗的光追特效。 |

#### 核心數量 (Core Count) 的迷思

這是一個經典的硬體架構考點：**為什麼消費級的 RTX 4090 有 16,000 個 CUDA 核心，而售價貴了幾十倍的資料中心 A100 只有不到 7,000 個 CUDA 核心？**

> **核心解答：不能跨架構只比數字大小**

1. **核心大小與複雜度：** A100 內部的每一個 CUDA 核心與 Tensor 核心，在物理面積、暫存器（Register）大小、記憶體頻寬上，都比消費級 RTX 卡大得多、強壯得多。
2. **雙精度浮點數 (FP64)：** A100 的核心具備極其強大的 FP64（雙精度）運算能力，這對於科學模擬（如氣象預測、分子動力學）是剛需；而消費級的 RTX 4090 在硬體上幾乎砍掉了 FP64 效能。
3. **記憶體架構：** A100 配備了頻寬極高、造價昂貴的 **HBM（高頻寬記憶體）**，而 RTX 4090 只是使用 GDDR6X。對於 AI 訓練來說，記憶體頻寬往往比純粹的核心數量更決定了最終效能。

只有在同一個產品系列（架構）內（例如 H100 vs. H200），去比較核心數量的多寡才有實質的效能對比意義。

### DGX Platform

#### Timeline

DGX 並非縮寫，而是一個專屬的產品線品牌名稱。它是 NVIDIA 針對 AI、機器學習與深度學習工作負載所量身打造的一體化企業級硬體平台。在業界，DGX 代表的就是出廠即滿配、軟硬體深度優化、開箱即用的頂級 AI 算力伺服器。

DGX 不僅僅存在於冷氣房裡的機架伺服器（Rack Server），它還涵蓋了不同的實體形態以滿足不同場景：

* 資料中心伺服器 (Data Center Servers)： 如 DGX A100 / H100 / B200，是搭建 SuperPOD 超級電腦的基本磚塊。
* 工作站 (Workstations)： 如 DGX Station A100 / H100，具備靜音水冷設計，可以直接放在資料科學家的辦公桌旁進行模型開發。
* 桌上型裝置 (Desktop)： 如最新的 DGX Spark (GB10)，讓個人開發者也能享有 Grace Blackwell 架構帶來的本地化運算能力。

#### 為什麼 NVIDIA 要自己做 Grace CPU？

這是架構設計中最關鍵的一環。在 GH200 之前，GPU 必須透過主機板上的 PCIe 匯流排來與 Intel 或 AMD 的 CPU 溝通。**PCIe 的頻寬就是那個致命的瓶頸。**

##### NVIDIA Grace CPU 的誕生與優勢

1. **基於 ARM 架構：** Grace 是一顆 72 核心的 ARM 架構 CPU，專為高吞吐量、高能源效率的資料中心設計。
2. **超級晶片 (Superchip) 概念：** NVIDIA 將 Grace CPU 與 Hopper/Blackwell GPU 封裝在同一塊超級板（Superchip）上。
3. **打破頻寬之牆 (NVLink-C2C)：**
    * 這是 Grace 最重要的價值。CPU 與 GPU 之間不再使用傳統的 PCIe，而是使用 NVIDIA 自家的 **NVLink-C2C (Chip-to-Chip)** 技術相連。
    * 這種連線的頻寬高達 **900 GB/s**，是傳統 PCIe Gen5 的 **7 倍以上**。
    * **結果：** GPU 可以以前所未有的速度直接存取 CPU 旁邊的海量系統記憶體（LPDDR5X），徹底解決了訓練超大模型時 GPU 記憶體容量不足的問題。

> * 看到 **"A", "H", "B"** 就知道是指代 GPU 架構（Ampere, Hopper, Blackwell）。
> * 看到型號前面加了 **"G"**（如 GH200, GB200），就代表它採用了 NVIDIA 革命性的 **Grace CPU** 組合而成的 Superchip，具備打破傳統 CPU-GPU 頻寬限制的 NVLink-C2C 技術。

#### NVIDIA DGX 平台

##### 部署與採購策略 (Deployment Options)

* **地端自建 (On-Prem)：** 買斷硬體，適合重視資安合規、有本地資料限制的企業。
* **公有雲隨需租用 (Public Cloud)：** 透過 AWS, Azure, GCP, Oracle 以 Pay-as-you-go 模式租用，免付龐大硬體建置費 (OpEx)。
* **雲端合作夥伴 (DGX Cloud Partners)：** 專門提供 AI 算力訂閱制的供應商。

##### 家族成員與適用場景 (DGX Family)

* **DGX Workstation (工作站)：** 辦公室用，針對在地端開發與初期原型測試 (Prototype)。
* **DGX Servers (伺服器)：** 機房用，針對正式上線的生產環境 (Production)。
* **DGX SuperPOD (超級叢集)：** 超算中心用，結合大量伺服器打造 AI 超級電腦。

##### 硬體 (Hardware Components)

* **CPU：** 雙路 AMD / Intel Xeon，或最新的 NVIDIA Grace。
* **GPU：** **8 張** 頂級 Tensor Core GPU (如 A100 / H100)。
* **內部互聯 (Interconnect)：** **NVLink & NVSwitch** (解決 GPU 間的通訊瓶頸) + PCIe Gen 5。
* **儲存與網路 (Storage & Network)：** 高速本地 NVMe SSD 陣列 + 雙/四埠 InfiniBand 與高速 Ethernet。
* **網路：** InfiniBand / Ethernet

##### 軟體生態系 (Software Stack)

* **底層作業系統：** **DGX OS** (專為 DGX 硬體調優的系統)。
* **監控與驅動：** GPU 驅動程式、`nvidia-smi`。
* **AI 訓練加速庫：** **CUDA** (並行計算)、**cuDNN** (神經網路)、**NCCL** (多 GPU 通訊)。
* **叢集管理大腦：** **NVIDIA Base Command Manager**。

## Layer2 Data Movement and I/O Accleration

### NVLink

**NVLink 就是那座連接兩棟大樓的「專屬高空天橋」。**

它是 NVIDIA 獨家開發的一種高速、點對點（Point-to-Point）互聯技術。

* **物理與軟體的結合：** 物理上它是一條獨立的高速專線；軟體上它有專屬的驅動協議，支援*記憶體池化（Memory Pooling）*，讓 GPU 1 可以直接把 GPU 2 的記憶體當作自己的來用。
* **核心效益：** 資料傳輸**直接繞過 PCIe 與系統 CPU**，頻寬高達數百 GB/s 到上千 GB/s（取決於世代），徹底釋放多 GPU 協同運算的潛力。

[nvidia | Blog | nvlink-and-nvidia-nvswitch](https://developer.nvidia.com/blog/nvidia-nvlink-and-nvidia-nvswitch-supercharge-large-language-model-inference/)

#### 為什麼需要 NVLink？

> **核心痛點：PCIe 匯流排的「繞遠路」效應**

在傳統的主機板架構中，所有的擴充卡（包含顯示卡 GPU、網卡、音效卡）都必須插在 **PCIe (Peripheral Component Interconnect Express) 插槽**上。

如果 GPU 1 想要把資料傳給 GPU 2，它必須：

1. 搭電梯下樓（離開 GPU 1）。
2. 走進擁擠的大廳（進入 PCIe 匯流排）。
3. 經過大樓管理員（系統 CPU 與主機板晶片組）。
4. 再搭電梯上樓，把資料交給 GPU 2。

這不僅**極度浪費時間（高延遲）**，而且 PCIe 的頻寬是大家共用的，當 8 張頂級 GPU 都在全力訓練 AI 模型時，這條通道會瞬間被塞爆。

#### NVLink 的三種實作型態 (Implementations)

根據應用場景與硬體規模，NVLink 有三種不同的物理表現形式：

1. NVLink 橋接器 (NVLink Bridge)

    * **型態：** 一個小型的實體接頭組件。
    * **場景：** 在消費級遊戲主機或基礎工作站中，將兩張獨立的顯示卡（如兩張 RTX 4090 或 RTX A6000）從頂部直接扣接在一起。

2. 整合型 NVLink (Integrated NVLink)

    * **型態：** 晶片級的內建線路。
    * **場景：** 像我們之前提到的 **Grace Hopper (GH200) 超級晶片**。CPU 與 GPU 直接焊在同一塊板子上，不需要外接橋接器，晶片內部直接以 NVLink-C2C 的線路相連。

3. NVSwitch (NVLink 的終極型態)

    * **型態：** 專門負責路由 NVLink 流量的高速交換晶片。
    * **場景：** 資料中心級別的伺服器（如 DGX A100 / H100）。
    * **為什麼需要 Switch？**
        如果只有 2 張 GPU，牽一條天橋（Bridge）很簡單。但如果一台伺服器裡有 **8 張 GPU**，要讓每一張都能直接跟另外 7 張講話（Fully Connected Mesh），線路會像蜘蛛網一樣複雜且不可行。因此，NVIDIA 設計了 **NVSwitch**。8 張 GPU 全部連到這幾顆 NVSwitch 晶片上，由 Switch 來負責瞬間路由轉發，確保**任何兩張 GPU 之間都能以無損的全速 NVLink 頻寬進行通訊**。

下圖為有無 NVSwitch 架構圖

![gpu-to-gpu-bandwidt](https://developer-blogs.nvidia.com/wp-content/uploads/2024/08/gpu-to-gpu-bandwidth-nvswitch-comparison-b.png)

#### 何時該使用 NVLink/NVSwitch？

| ✅ **極度需要 NVLink 的場景 (Must Have)** | ❌ **不需要 NVLink 的場景 (Skip It)** |
| --- | --- |
| **訓練超大基礎模型 (LLMs)：** 多張 GPU 需要瘋狂同步權重與梯度參數（All-Reduce 操作）。 | **單一 GPU 系統：** 只有一張卡，沒有人可以講話。 |
| **PCIe 頻寬成為瓶頸：** 當 GPU 算力很強，但都在原地「等資料傳輸」時。 | **GPU 之間不需要交談的工作負載：** 例如同時跑 8 個完全獨立的雲端遊戲實例，彼此資料不互通。 |
| **企業級 AI 研究中心與多 GPU 伺服器：** 如部署 DGX 系統。 | **消費級輕度應用與小型邊緣設備。** |

### InfiniBand

#### 什麼是 HPC Fabric？

當單台 DGX 伺服器（8 張 GPU）的算力達到極限時，我們必須將數十甚至數百台伺服器串聯起來（形成叢集或 SuperPOD）。HPC Fabric 就是用來串聯這些節點的超級神經網路。

目標： 確保跨伺服器的通訊（Node-to-Node）能擁有極低的延遲與極高的頻寬，讓多台伺服器運作起來就像「一整台超級電腦」一樣順暢。

#### InfiniBand 的四大硬體組成要件

InfiniBand 不是隨便插條網路線就能運作，它需要一整套專門的生態系：

* 矽晶片 (Silicon)： 網路設備的底層邏輯控制晶片。
* 網路卡/配接器 (Adapters / DPUs)： 安裝在伺服器端（如 BlueField DPU 或 ConnectX 網卡）。
* 高速交換器 (Switches)： 專門路由 InfiniBand 流量的設備（如 NVIDIA Quantum 系列）。
* 專用線纜 (Cables)： 高品質的光纖或銅纜（如 QSFP 接頭），確保訊號傳輸無損。

#### Ethernet

在 NVIDIA 生態系中，**InfiniBand 與 Converged Ethernet (RoCE)** 其實是在**不同的硬體產品線**與**管理邏輯**上平行發展的。

**這不是速度（Speed）的對決，而是延遲（Latency）與管理方式（Management）的不同**。

#### InfiniBand vs. Converged Ethernet

| 比較維度 | 🚄 InfiniBand 生態系 | 🌐 Converged Ethernet (RoCE) 生態系 |
| --- | --- | --- |
| **端點設備 (網卡端)** | **HCA (Host Channel Adapter)**，*例：ConnectX-6 / ConnectX-7 (IB 模式)* | **NIC (Network Interface Card)** / **SuperNIC** *例：ConnectX-6 / ConnectX-7 (Eth 模式), BlueField DPU* |
| **網路交換器 (Switches)** | **NVIDIA Quantum 系列** *專為超低延遲與無損路由打造* | **NVIDIA Spectrum 系列** *專為高頻寬乙太網與多租戶雲端打造* |
| **極限頻寬 (Max Speed)** | 最高可達 **400GB/s ~ 800GB/s** | 最高可達 **400GB/s ~ 800GB/s**  |
| **決策核心考量** | **追求極致的超低延遲 (Ultra-Low Latency)** 與硬體級的無損傳輸 (Lossless)。 | **追求靈活性、較低的部署成本**，以及相容於現有的網路基礎設施。 |
| **網路管理中樞** | 必須使用特規的 **OpenSM (Open Subnet Manager)**。 | 可以沿用現有的 **TCP/IP 管理工具**與標準 Ethernet 交換邏輯（如 BGP/EVPN）。 |

#### 為什麼管理方式差這麼多？

這段內容帶出了一個非常核心的技術差異：**Subnet Manager (OpenSM) vs. 傳統路由**。

1. InfiniBand 的集權式大腦：OpenSM

    * InfiniBand 不是像傳統 Ethernet 那樣透過廣播（Broadcast）或 ARP 來自己摸黑找路的。
    * InfiniBand 網路中必須有一個（或一組高可用）被稱為 **Subnet Manager (SM)** 的軟體大腦存在。在開源與 NVIDIA 環境中，通常使用 **OpenSM**。
    * **運作方式：** 當網路接通時，OpenSM 會掃描整個網路拓撲，計算好每一條不塞車的最佳路徑（Routing Tables），然後把這些路徑發布給所有的交換器和 HCA 網卡。這也是 InfiniBand 能做到超低延遲與防擁塞的原因——因為**路徑是上帝視角預先算好的**。

2. Ethernet 的去中心化路由：TCP/IP 與標準協議

    * 即使跑的是 Converged Ethernet 與 RoCE，它底層依然是乙太網路。
    * 它可以依賴傳統的交換器（Spectrum）、使用標準的網路協議（如 OSPF、BGP）來決定路由。因此，企業**不需要為了導入 AI 網路而完全捨棄原有的網管團隊經驗與監控工具（如 SNMP, NetFlow 等）**。

### DMA and RDMA

這正是為什麼 InfiniBand 和 RoCE 能夠在 AI 資料中心稱霸的最核心底層邏輯。

[nvidia | gpudirect](https://developer.nvidia.com/gpudirect)

#### 基礎 - 什麼是 DMA (Direct Memory Access)？

在理解遠端之前，必須先搞懂本地的 DMA。

* **沒有 DMA 的黑暗時代：** 如果音效卡、網卡或 GPU 想要讀寫主機的 RAM（系統記憶體），所有的資料傳輸都必須由 CPU 這個中間人（Middleman）親自經手搬運。
  * **痛點：** CPU 變成超級搬運工，浪費了寶貴的運算週期（Cycles）；同時，GPU 只能在原地發呆，等待 CPU 把資料餵給它。
* **DMA 的救贖：** 系統透過指派 **DMA 通道與控制器**，為周邊設備開闢了一條直達系統記憶體的專屬快車道。
  * **效益：** CPU 只負責「下達指令（Setup）」與「接收完成通知（Notification）」。搬運資料的粗活交由硬體控制器自己搞定。**這讓資料移動速度提升了 10 到 100 倍！**

#### 什麼是 RDMA (Remote DMA)？

DMA 解決了同一台主機板上的頻寬瓶頸。但是，當我們把幾百台伺服器組成叢集時，我們需要跨網卡的直接記憶體存取。

這就是 **RDMA (Remote Direct Memory Access)** 的價值：**讓主機 A 的 GPU，可以直接越過網路，去讀寫主機 B 的系統記憶體，而且雙方的 CPU 完全不需要介入**

#### RDMA 的運作機制對比

| 傳輸機制 | 傳統 TCP/IP 網路傳輸 (無 RDMA) | RDMA 傳輸 (透過 InfiniBand/RoCE) |
| --- | --- | --- |
| **運作路徑** | 網卡收封包 ➡️ 通知主機 B 的 CPU ➡️ CPU 拆解封包 (TCP stack) ➡️ CPU 將資料搬到系統記憶體。 | 主機 A 的網卡 ➡️ 高速網路 (InfiniBand) ➡️ 主機 B 的網卡 ➡️ **直接寫入主機 B 的記憶體**。 |
| **CPU 參與度** | 兩邊的 CPU 都深度參與，耗費大量算力（高負載）。 | **Zero-Copy (零拷貝) & CPU Bypass**。雙方 CPU 幾乎 0 參與。 |
| **延遲表現** | 較高（10~100 微秒以上），受限於作業系統與 TCP 協定負擔。 | **極低（1~2 微秒）**，硬體直通。 |
| **AI 訓練效益** | GPU 嚴重閒置，等待資料從網路爬過來。 | GPU 不斷獲得海量資料，維持近乎 100% 的高算力輸出。 |

![](https://d29g4g2dyqv443.cloudfront.net/sites/default/files/akamai/GPUDirect/gpudirect-rdma.png)

#### 支援 RDMA 的三大網路實作技術

RDMA 是一種概念/協議，它必須跑在有支援這項特性的底層網路上：

1. **InfiniBand (IB)：**
    * **RDMA 的原生老家。** 從設計之初（2000年）就是為了 RDMA 而生，提供最純粹、最極致的效能與無損網路。


2. **RoCE (RDMA over Converged Ethernet)：**
    * 它將 RDMA 封裝在標準乙太網路封包中，讓較便宜的乙太網也能享受繞過 CPU 的好處。

3. **iWARP (Internet Wide Area RDMA Protocol)：**
    * 將 RDMA 建立在傳統 TCP/IP 基礎上。雖然相容性極高（不強求網路硬體無損），但在現代 AI 資料中心中效能不如 IB 與 RoCE，因此**較少在 NVIDIA 頂級 AI 叢集架構中被採用**。

### GPUDirect RDMA

在標準的 RDMA 中，主機 A 的網卡雖然可以直接將資料寫入主機 B 的系統記憶體 (System RAM)，但別忘了，AI 模型是在 GPU 內部執行的。

資料從網路透過 RDMA 來到主機 B 的系統記憶體。接著，還是得由主機 B 的系統，透過 PCIe 匯流排將資料從「系統記憶體」複製到GPU 自己的記憶體 (VRAM)。*雖然繞過了 CPU，但資料在主機內部還是多搬運了一次*。

NVIDIA 思考的是：既然都要直通，為什麼不直通到底？GPUDirect RDMA 的運作方式，它徹底打破了系統記憶體的限制，讓主機 A 的 GPU 可以透過支援 RDMA 的網卡（如 ConnectX 網卡），透過 InfiniBand 或 RoCE 網路，直接將資料寫入主機 B 的 GPU 顯存 (VRAM) 裡。

#### GPUDirect RDMA 的核心架構對比

| 傳輸步驟 | 傳統網路傳輸 (TCP/IP) | 標準 RDMA 傳輸 | 👑 **GPUDirect RDMA 傳輸** |
| --- | --- | --- | --- |
| **資料來源** | 主機 A GPU ➡️ 系統 RAM ➡️ 網卡 | 主機 A 網卡直接抓系統 RAM | **主機 A 網卡直接抓 GPU VRAM** |
| **跨網路** | 傳統乙太網路 | InfiniBand / RoCE 網路 | InfiniBand / RoCE 網路 |
| **資料接收** | 網卡 ➡️ CPU ➡️ 系統 RAM ➡️ GPU VRAM | 主機 B 網卡直接寫入系統 RAM ➡️ GPU VRAM | **主機 B 網卡直接寫入 GPU VRAM** |
| **記憶體複製次數** | 3 次以上 | 1 次 (從 RAM 到 VRAM) | **0 次 (真正意義的 Zero-Copy)** |
| **CPU 介入程度** | 兩端 CPU 滿載處理封包 | 無介入 | **絕對無介入，連作業系統 (OS) 都被繞過** |

#### 什麼 AI 訓練極度依賴 GPUDirect RDMA？

這項技術的商業與實務價值極高，因為在訓練大型神經網路（例如含有數百億參數的大語言模型）時，必須採用**分散式訓練 (Distributed Training)**：

* 數十台甚至數百台 DGX 伺服器中的 GPU，每一輪計算完梯度 (Gradients) 後，都必須立刻與其他節點的 GPU 分享、同步這些數據。這被稱為 **All-Reduce 操作**。
* **如果沒有 GPUDirect RDMA：** 這龐大的同步資料會在每台伺服器的系統記憶體、CPU 與 PCIe 之間塞車，導致 GPU 大量時間處於閒置狀態（等資料同步）。
* **有了 GPUDirect RDMA：** 節點間的 GPU 就像是共用一塊無限大的記憶體池，資料以微秒級的延遲瞬間同步，讓昂貴的算力維持 100% 榨乾狀態。

> 這項魔法不是隨便拼湊就能實現的。它必須**全部採用 NVIDIA 生態系**：包含 NVIDIA 的 GPU、專屬驅動程式、以及具備 RDMA 能力的 NIC（通常是 Mellanox ConnectX 網卡或 BlueField DPU）。

### GPUDirece Storage

既然我們能讓 GPU 繞過 CPU 去讀其他 GPU 的記憶體，為什麼不乾脆讓 GPU 也繞過 CPU，直接去讀硬碟裡的資料呢？

#### GPUDirect Storage (GDS)

##### 傳統 I/O 儲存讀取的痛點 (Bounce Buffer Problem)

在沒有 GDS 之前，當 AI 模型準備開始訓練，GPU 需要讀取硬碟（NVMe SSD）裡的海量圖片或文字資料集時，路徑是這樣的：

1. 資料從硬碟讀出。
2. 搬到系統記憶體 (System RAM) 的一個暫存區（稱為 Bounce Buffer）。
3. 由 CPU 經由 PCIe 匯流排，再將這些資料複製到 GPU 的記憶體 (VRAM)。

> **痛點：** 這就像是送貨員（硬碟）把包裹先丟在管理室（系統記憶體），然後屋主（GPU）還要親自下樓去把包裹搬回房間。這過程不僅吃 CPU 效能，還受限於系統記憶體的頻寬。

##### GDS 的直接通道

有了 **GPUDirect Storage (GDS)**：

* 硬體（如 PCIe Switch 或高速網卡）與 NVIDIA 驅動程式合作，直接在 **硬碟 (NVMe)** 與 **GPU 顯存 (VRAM)** 之間建立專屬通道。
* **資料流向：** 硬碟 ➡️ (PCIe/網路) ➡️ GPU VRAM。完全不需要進出系統記憶體，也不需要 CPU 介入！

#### 🛠️ GDS 的兩種實務部署場景

GDS 本質上就是將 DMA 技術應用在儲存上。實務上它涵蓋了本地與遠端兩種情境：

1. **本地直連 (Local GDS)：**
    如同所舉的例子，伺服器內部插著極速的 NVMe SSD，GPU 可以透過機殼內的 PCIe 通道直接把資料從 SSD 抽進顯存，減少了本機內的 I/O 瓶頸。
2. **遠端叢集儲存 (GDS over Fabric / RDMA)：** *(這是企業級 AI 中心最真實的用法)*
    當資料集大到幾十 PB，根本塞不進單台伺服器時，資料會放在遠端的儲存叢集（如 NetApp, VAST Data）。這時，遠端的儲存設備會結合 **RDMA 網路 (RoCE/InfiniBand)** 與 **GDS 技術**，將資料從遠端硬碟直接、跨網、無損地射進運算節點的 GPU 顯存裡！

### GPUDirect Comparsion

#### GPUDirect RDMA vs. GPUDirect Storage 決策速查表

| 比較維度 | 🚀 GPUDirect RDMA | 💾 GPUDirect Storage (GDS) |
| --- | --- | --- |
| **通訊範圍 (Scope)** | **跨主機 (Across Hosts)** (GPU -> remote GPU/NIC via RDMA)| **主機內 (Within a Host) 或網路儲存** (GPU -> local) |
| **連線對象 (Entity)** | 本機 GPU ↔️ 遠端 GPU 顯存 (VRAM) | 本機 GPU ↔️ NVMe 硬碟 / 遠端平行儲存系統 |
| **資料路徑 (Data Path)** | **GPU VRAM ↔️ 網卡 (NIC) ↔️ 遠端 GPU** *(完全繞過兩端 CPU 與系統記憶體 OS RAM)* | **GPU VRAM ↔️ 硬碟 (NVMe) 或儲存網路** *(完全繞過 CPU 與系統記憶體 OS RAM)* |
| **核心目標與優勢** | 追求 **極致超低延遲 (Ultra-Low Latency)**，確保跨節點 GPU 同步不卡頓。 | 追求 **極高吞吐量 (High Bandwidth / Throughput)**，確保海量資料集餵飽 GPU。 |
| **主要 AI 應用場景** | **叢集平行計算：** 多節點分散式 AI 模型訓練（如權重梯度更新、All-Reduce 通訊）。 | **資料載入與 I/O 密集任務：** 將龐大的訓練資料集 (Datasets) 或模型快照 (Checkpoints) 快速讀寫。 |
| **硬體與生態要求** | NVIDIA GPU；支援 RDMA 的網卡 (如 Mellanox ConnectX/BlueField)；支援 RDMA 的網路 (InfiniBand/RoCE) | NVIDIA GPU；本地高速 NVMe 或 企業級平行儲存系統 *(如 IBM Spectrum Scale, Weka, DDN 等合作夥伴)* |

## Layer3 - OS、Driver and Virtualization

### vGPU

**GPU 虛擬化 (GPU Virtualization)** 是企業將 AI 導入正式生產環境時，一定會面臨到的成本與架構挑戰。

#### 為什麼我們需要 GPU 虛擬化？

在沒有虛擬化的情況下，一張實體 GPU（裸機）只能分配給一台機器、一個作業系統使用。如果這台機器上的 AI 任務很輕量，這張昂貴的 GPU 就會長時間處於閒置狀態（Idle）。

**導入 GPU 虛擬化的四大核心價值：**

1. **大幅降低成本 (Cost Reduction)：** 讓多個使用者（如資料科學家）或多台 VM 共享同一張實體 GPU，省下採購多張顯示卡的龐大開銷。
2. **極致化資源利用率 (Better Resource Utilization)：** 避免昂貴的算力變成「只耗電不工作」的發熱鐵板，確保 GPU 時刻處於忙碌狀態。
3. **靈活彈性擴充 (Flexible Scaling)：** 可以根據當下的工作負載（如白天開發、晚上跑大型訓練），動態調整分配給各個 VM 的虛擬 GPU 算力大小，無需隨時插拔實體卡。
4. **安全的效能隔離 (Secure Isolation)：** 即使多個使用者共享同一張卡，透過虛擬化隔離機制，也能確保 A 專案的當機或高負載，不會影響到同在一張卡上的 B 專案。

#### 深度對比：CPU 虛擬化 vs. GPU 虛擬化

這絕對是架構設計考試的必考題型，了解兩者的先天差異是關鍵：

| 比較維度 | 💻 CPU 虛擬化 (vCPU) | 🎮 GPU 虛擬化 (vGPU) |
| --- | --- | --- |
| **技術成熟度與標準** | **極度成熟且標準化。** 無論是 VMware, KVM 還是 Hyper-V，底層邏輯皆相通。 | **發展中且高度綁定廠商 (Vendor-Specific)。** NVIDIA、AMD 的實作方式與底層架構截然不同。 |
| **資源切割顆粒度 (Granularity)** | **非常容易。** CPU 可以輕鬆地以「執行緒 (Threads)」或「時間切片 (Time-slicing)」來乾淨俐落的切割。 | **非常困難。** GPU 擁有數千個核心與龐大的顯存，無法輕易地「乾淨切開」。必須依賴特製的硬體機制（如 vGPU 或 MIG）。 |
| **隔離性機制 (Isolation)** | 由 Hypervisor (如 ESXi) 直接在作業系統底層進行強隔離。 | 較為複雜。除了 Hypervisor，往往還需要安裝**特殊的授權驅動程式 (Special Drivers)** 才能實作顯存與算力的中介隔離。 |
| **效能損耗 (Performance Overhead)** | 接近原生裸機效能 (Near-Native)，損耗極低。 | **取決於配置模式。**；**Pass-through (直通模式)：** 效能接近原生。；**共享模式 (Shared)：** 效能會受分割方式影響。 |
| **資源共享模型** | 時間切片 (Time-slicing) 或核心綁定。 | 硬體切割 (如 MIG)、驅動程式中介 (Driver Mediation) 或 API 攔截。 |

#### 實務上的兩種 GPU 分割法

既然 GPU 那麼難切，NVIDIA 到底是用什麼魔法把它切開分給不同 VM 的？這引出了現代 AI 資料中心最核心的兩大 GPU 虛擬化技術：

1. **NVIDIA vGPU (Virtual GPU)：** *(偏向傳統的軟體/時間切片或授權中介)*
    透過軟體與驅動程式層級，讓一張物理卡虛擬出多張 vGPU 給不同 VM，主要用於 VDI (虛擬桌面) 或輕量級 AI 開發。
2. **NVIDIA MIG (Multi-Instance GPU)：** *(硬體級別的終極物理切割)* 
    這是從 Ampere (A100) 架構開始引入的革命性硬體技術，能在物理層面上將一張 GPU「切成多個完全獨立的小 GPU」。

### vGPU vs MIG

#### 🏢 共享辦公室的啟示：隔離深度的差異

1. 軟體邏輯隔離：就像共用大廳的辦公區

    * **情境：** 每間公司有自己的辦公桌區域（算力），但大廳、電梯與餐廳是**共用**的（如 GPU 的快取、記憶體頻寬與排程器）。
    * **風險 (Noisy Neighbor)：** 如果某間公司（某台 VM）突然舉辦大型活動佔滿了電梯與大廳，其他公司的人就會被卡住。這就是軟體隔離常見的「吵鬧的鄰居」效應。

2. 硬體物理隔離：就像完全獨立的隔間套房

    * **情境：** 每一間公司不僅有自己的辦公桌，還有**專屬**的私人電梯、專屬的餐廳與專屬的大廳。
    * **優勢：** 達到真正的物理隔離。無論隔壁公司怎麼胡鬧，都絕對不會影響到您的運作。

#### 兩大 GPU 虛擬化技術核心對比

| 技術名稱 | ☁️ NVIDIA vGPU (軟體級虛擬化) | 🛡️ NVIDIA MIG (硬體多執行個體 GPU) |
| --- | --- | --- |
| **底層運作機制** | **軟體層面隔離 (Hypervisor-based)。** 依賴如 VMware ESXi 或 KVM 等 Hypervisor 搭配 NVIDIA vGPU 授權軟體進行切片。 | **硬體層面物理切割 (Hardware-level)。** 在裸機 (Bare-metal Linux) 加上 `nvidia-smi` 即可直接將 GPU 晶片在物理上切開。 |
| **資源分割方式** | GPU 的核心（算力）透過**時間切片 (Time-Slicing)** 輪流分享。記憶體與內部頻寬通常是共用的。 | **絕對的物理分割。** 不只是算力，連**記憶體頻寬 (Memory Bandwidth) 與 L2 快取 (L2 Cache)** 都被硬體強迫切開，互不干擾。 |
| **最大分割數量** | 切割顆粒度極細，最高可將一張卡切出高達 **64 個 vGPU**。 | 切割受限於硬體架構，最多只能將一張頂級卡（如 A100/H100）切成 **7 個獨立的實體實例 (Instances)**。 |
| **上層應用負載** | **虛擬機 (Virtual Machines, VMs)。** 每台 VM 有自己完整的 Guest OS，應用程式跑在 VM 內。 | **容器化應用 (Containers, 如 Docker/K8s)。** 不需要跑肥大的 VM，直接在底層 Linux 啟動容器並掛載 MIG 實例。 |
| **最佳適用場景** | **VDI (虛擬桌面)、輕量級 3D 繪圖、大量學生的輕度 AI 開發環境**（需要切出極多份，且不在乎輕微的效能干擾）。 | **生產環境的平行 AI 推論 (Parallel Inferences) 與模型微調**（需要保證 100% 可預測的效能 (QoS)，絕不容忍鄰居干擾）。 |

#### 架構圖解從底層到應用程式

在準備架構設計題時，腦中必須浮現這兩種實作的層次堆疊：

##### 【架構 A】vGPU 實作堆疊

1. **硬體層：** 實體伺服器 + 實體 GPU
2. **Hypervisor 層：** ESXi / KVM + **NVIDIA vGPU 軟體驅動** (負責虛擬化 GPU)
3. **VM 層：** 建立多台虛擬機 (包含 Guest OS，如 Windows 或 Ubuntu)
4. **應用層：** 在 VM 內部安裝應用程式或 Docker 執行 AI 任務。

##### 【架構 B】MIG 實作堆疊 (更現代、更雲端原生的做法)

1. **硬體層：** 實體伺服器 + 支援 MIG 的實體 GPU (如 A100/H100)
2. **OS/管理層：** 基礎 Linux OS + **`nvidia-smi` (開啟 MIG 模式並切割實例)**
3. **直接應用層：** 不跑 VM！直接透過 Docker / Kubernetes，將切割好的小塊 MIG 實例直接配發給 Pod 或容器使用。

這是一段非常紮實且充滿實戰感的操作教學！您透過 NVIDIA SMI 的實際畫面，不僅解釋了 **MIG (Multi-Instance GPU)** 的理論架構，還帶出了非常核心的實務考點：**MIG 必須透過 Profile (設定檔) 來嚴格切割，且絕對受到硬體物理限制。**

#### MIG 的核心精神：硬體級別的不重疊切割

MIG 最強大的地方在於，它不只切算力，它還切記憶體與內部頻寬。

* **SM (Streaming Multiprocessors)：** 負責算力的核心單元。
* **L2 Cache & Memory Bandwidth：** 負責資料吞吐的快取與頻寬。

在 MIG 模式下，這兩者會被嚴格綁定並切割。一旦切開，這些硬體資源就**絕對不會重疊 (No Overlapping)**。如果 A 實例滿載，B 實例依然享有自己專屬的快取與頻寬，完全不受影響。

下圖為官方示意圖

![gpu-mig-overvie](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/latest/_images/gpu-mig-overview.jpg)

這張圖想要傳達的終極訊息是，MIG 實作了真正的「物理不重疊（No Overlapping）」隔離。從資料進入的管道（Sys Pipe）、晶片內傳輸（Xbar）、核心運算（SMs）到最後的記憶體存取（L2 / DRAM），7 個 GPU Instance 就像是被物理鐵網隔開的 7 張獨立小網卡。這種硬體級隔離帶來了三大好處：

* QoS 效能保證： 每個使用者的延遲與吞吐量高度可預測，不受鄰居干擾。
* 故障隔離： 假設 USER 3 的程式碼寫壞引發錯誤導致 GPU Instance 3 當機，其餘 6 個 Instance 依然能完好無損地繼續提供 AI 服務。
* 無授權費負擔： 裸機 Linux 搭配 nvidia-smi 就能直接切出 7 個實例給容器（Docker/K8s）使用，不需要額外購買肥大的商業虛擬化軟體（Hypervisor）。

[nvidia | datacenter | mig-user-guide](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/latest/introduction.html)

#### MIG 的切割法則與命名邏輯 (Profile Naming)

在實務操作中，看懂 MIG 的命名規則非常重要。以 `3g.20gb` 為例：

* **前面的數字 (3g)：** 代表分配到的 **GPU 運算單元 (Compute Slices)** 的數量。
* **後面的數字 (20gb)：** 代表分配到的 **專屬記憶體 (VRAM) 大小**。

可參閱官方關於 [Profile](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/latest/concepts.html) 的概念

#### 切割的物理極限 (以 A100 40GB 為例)

1. **最大實例數：** 物理極限就是切出 **7 份** (`1g.5gb`)。
2. **總容量不可超越：** 可以自由組合（例如切兩個 `2g.10gb` 和一個 `3g.20gb`），但**記憶體總和絕對不能超過 40GB，算力單元總和不能超過 7g**。
3. **零碎浪費 (Wastage)：** 如果您切的組合無法完美填滿整塊晶片，剩下的算力與記憶體將會閒置（浪費），因此架構師必須仔細規劃 Profile 的組合。

#### MIG 的啟用與設定流程

1. **檢查支援度：**
    * 輸入 `nvidia-smi`。如果像 Tesla T4 或 A10G 顯示 `N/A`，代表硬體不支援 MIG。
    * MIG 專屬於頂級資料中心卡（如 A100, H100 等 Ampere 架構之後的旗艦卡）。

2. **啟用 MIG 模式 (預設為關閉)：**
    * 指令：`sudo nvidia-smi -i 0 -mig 1` （針對第 0 號 GPU 開啟 MIG 模式）。
    * *注意：開啟或關閉 MIG 模式通常需要重啟系統或重置 GPU。*

3. **查看可用的切割設定檔 (Profiles)：**
    * 系統會列出該張卡支援的切割模式（如 `1g.5gb`, `2g.10gb`, `3g.20gb`, `7g.40gb`）。

4. **建立 MIG 實例：**
    * 根據需求指定 Profile 來切出實體的小 GPU。切出來後，作業系統和 Docker 就會把它們當作「獨立的實體 GPU」來掛載使用。

#### GPU vs. MIG 選型決策表

| 決策維度 | ☁️ NVIDIA vGPU (軟體虛擬化) | 🛡️ NVIDIA MIG (硬體多執行個體) |
| --- | --- | --- |
| **底層環境** | 依賴 Hypervisor (VMware, Citrix)。 | **Bare-metal Linux (裸機)。** 不需 Hypervisor。 |
| **軟體授權** | ⚠️ **需要額外購買 NVIDIA vGPU 授權軟體。** | 免費，只需標準 NVIDIA 驅動程式與 SMI 工具。 |
| **效能可預測性** | 較低（可能有 Noisy Neighbor 效應）。 | **極高（硬體級隔離，QoS 保證）。** |
| **主要工作負載** | 虛擬桌面 (VDI)、VM 架構下的輕量 AI 開發。 | **容器化 (Container/K8s) 的 AI 推論與 HPC。** |
| **硬體支援度** | 廣泛（許多資料中心卡甚至部分工作站卡皆支援）。 | **極為嚴苛（僅限 A30/A100/H100/B200 等頂級旗艦卡）。** |
