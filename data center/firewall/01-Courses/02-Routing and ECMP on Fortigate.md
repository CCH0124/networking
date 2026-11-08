# Routing and ECMP on Fortigate
## Routing and Routed Protocols

### 背景與核心目的（Background & Objective）

* **背景**：網路常因「Routing Protocol」與「Routed Protocol」拼寫與發音高度相似而產生概念混淆，無法清楚區分「尋找路徑的控制面」與「承載資訊的資料面」。

* **核心目的**：透過生活化比喻（如 Google 地圖與行駛車輛）解析 Routed Protocol 與 Routing Protocol 的本質差異，並建構動態路由協定（IGP/EGP、Distance Vector/Link State/Path Vector）的完整分類樹狀模型。


### 架構設計與本質對比（Methodology / Conceptual Comparison）

兩者在網路架構中扮演互補但完全不同的角色：

| 比較維度 | 被路由協定（Routed Protocol） | 路由協定（Routing Protocol） |
| --- | --- | --- |
| **生活化比喻** | 載著乘客與貨物前往目的地的**「汽車與乘客」**。 | 規劃最佳路徑與導航指引的**「Google Maps」**。 |
| **核心職責** | 封裝並傳輸使用者的實際資料（User Data）跨網段移動。 | 路由器間交換網段路由資訊，計算前往目的地的最佳路徑。 |
| **定址與依賴** | 必須依賴邏輯定址系統（如 IP 位址）確認發送與接收端。 | 依賴演算法（距離、鏈路狀態或路徑向量）維護路由表（Routing Table）。 |
| **傳輸資料型態** | 使用者應用層流量（如 Email、網頁瀏覽、檔案傳輸）。 | 路由器之間的控制與路由更新封包（Routing Updates）。 |
| **常見協定代表** | **IPv4、IPv6**（Internet Protocol 家族）。 | **RIPv1/v2、OSPF、BGP、EIGRP**。 |

### 路由分類階層體系（Key Findings & Classification Hierarchy）

路由方式在架構上可分為三大類別，其中動態路由進一步依據自治系統（AS）範圍與演算法細分：

* **靜態路由（Static Routing）**：由管理員手動指定各目標網段的下一跳（Next-hop）。
* **預設路由（Default Routing）**：通常歸類為靜態路由特例（`0.0.0.0/0`），用於將所有未匹配路徑導向特定出口網關。
* **動態路由（Dynamic Routing）**：透過路由演算法自動探索網路拓撲並適應線路變更：

1. **內部網關協定（IGP, Interior Gateway Protocol）**：用於單一自治系統（AS）內部。
    * **距離向量協定（Distance Vector）**：以跳數（Hop Count）等距離評估路徑，例：**RIP**（Routing Information Protocol）。
    * **鏈路狀態協定（Link State）**：維護完整拓撲地圖並透過 SPF 演算法計算最短路徑，例：**OSPF**（Open Shortest Path First）。

2. **外部網關協定（EGP, Exterior Gateway Protocol）**：用於不同自治系統（AS）之間的路徑交換與原則路由。
    * **路徑向量協定（Path Vector）**：記錄穿越的 AS 路徑清單以防範環路，代表協定為 **BGP**（Border Gateway Protocol）。

### 實務意涵與網路運作邏輯（Implications）

* **初始狀態與收斂機制**：路由器剛開機時僅知悉實體介面直連（Directly Connected）的網段；必須藉由 Routed Protocol 提供資料的定址格式，並由 Routing Protocol 在背景自動學習遠端網段與更新路徑，整體網路才能具備端到端傳輸能力。

* **分層解耦價值**：將「路徑計算（Control Plane / Routing）」與「資料轉發（Data Plane / Routed）」解耦，使網路工程師在調整骨幹路由協定（如從 RIP 遷移至 OSPF）時，無需變更終端使用者的 IP 定址與應用層封包結構。

## Understanding Static Routing

### 背景與核心目的（Background & Objective）

* **背景**：大型網路環境多依賴動態路由協定，但在小型、拓撲單純或資源受限的環境中，動態路由會消耗額外的 CPU、記憶體與頻寬來傳遞協定更新封包。
* **核心目的**：探討靜態路由的運作原理與優缺點，解析其在 FortiGate 防火牆中的預設屬性（如管理距離與優先權），並說明特化靜態路由——預設路由（Default Route / Gateway of Last Resort）在邊界設備上的關鍵分流角色。

### 架構設計與比較（Methodology / Comparative Analysis）

#### 靜態路由與動態路由特徵對比


| 評估維度 | 靜態路由（Static Routing） | 動態路由（Dynamic Routing） |
| --- | --- | --- |
| **路徑建立方式** | 管理員手動逐條輸入至路由表。 | 路由器間透過演算法動態探索與學習。 |
| **系統負載與頻寬** | **極低負載**（無背景交換封包、低 CPU/RAM 消耗）。 | 較高（需計算演算法狀態與定期發布更新）。 |
| **拓撲適應性** | **無自適應能力**（線路中斷需人工手動介入修改）。 | **自動自適應**（可動態收斂並切換備援路徑）。 |
| **適用場景** | 拓撲固定的小型網路、末梢節點、指向特定 ISP 閘道。 | 大型、多站點或拓撲頻繁變動的企業骨幹網。 |

#### 預設路由（Default Route）

* **定義**：一種特殊的靜態路由，在路由表內又被稱為「最後防線網關（Gateway of Last Resort）」。
* **運作機制**：當封包的目的地 IP 未能精準匹配路由表中的任何特定網段（No more specific route exists）時，一律將該未知的 IP 資料包（IP Datagram）轉發給指定的單一出口設備（如邊界防火牆或上一層路由器）。

### 關鍵機制與 FortiGate 參數（Key Findings & Parameters）

* **FortiGate 預設路由屬性**：
    * **匹配原則**：FortiGate 採取最長匹配與第一符合規則（Pick the first matching route）。
    * **Administrative Distance (AD, 管理距離)**：FortiGate 靜態路由的預設 AD 值為 **`10`**（代表信任度高於多數動態路由協定，如 OSPF 預設為 110、RIP 為 120）。
    * **Priority（優先權）**：FortiGate 靜態路由預設優先權為 **`1`**（當有多條 AD 相同的靜態路由時，優先權數值越小越優先）。
* **配置要素**：在 FortiGate 介面建立靜態路由時，必須手動定義：
    1. `Destination`（目標網段，如 `0.0.0.0/0` 或特定子網）
    2. `Gateway`（下一跳 IP，如 `254`）
    3. `Interface`（出接口，如 WAN 介面）
    4. `Administrative Distance` 與 `Priority`（可自訂覆蓋預設值）

    TODO 實際配置


### 實務意涵與網路維運權衡（Implications）

* **優勢（Pros）**：具備完整的路由控制權（Full Control）、高安全性（無法透過偽造路由更新進行毒化）、無通訊協定額外開銷（Low Overhead & Low Traffic）。
* **劣勢（Cons）**：缺乏自動容錯能力（No Adaptation），在冗餘線路架構下，若缺乏鏈路健康監測機制（如 Link Monitor / BFD），容易因實體鏈路故障而引發黑洞路由。

## Administrative Distance

### 背景與核心目的（Background & Objective）

* **背景**：當路由器或防火牆同時從不同的來源（如多個動態路由協定、DHCP 或靜態設定）獲取到達同一個目標網段的重複路由（Duplicate Routes）時，需要一套客觀標準來決定何者優先寫入轉發資料庫。

* **核心目的**：解析 FortiGate 防火牆中 **Administrative Distance（AD，管理距離）** 作為「第一優先決策條件（First Tiebreaker）」的判斷機制，探討數值信任度評估準則，並透過實作驗證路由表（RIB）的動態安裝與剔除行為。

---

### 核心機制與評估準則（Methodology / Evaluation Criteria）

* **數值意義與可靠性**：
    * AD 數值範圍介於 **`0` 至 `255**`（數值越低代表來源越可靠、信任度越高）。

* **本地有效性（Local Significance）**：AD 僅於設備本機進行選路判斷，不會在路由更新封包中發布（Advertised）給其他鄰居路由器。
* **不可信任特例（AD = 255）**：若一條路由的 AD 被設定為 `255`，設備將判定該路由來源完全不可信（Disbelieve entirely），並將其完全排除於選路程序外，不會寫入路由表（RIB）。


* **FortiGate 預設路由管理距離表**：

| 路由類型 / 來源 | 預設 AD 值 | 信任程度與說明 |
| --- | --- | --- |
| **Direct Connected（直連網段）** | **`0`** | 最高信任度，硬體實體介面直連。 |
| **Static SD-WAN Zone** | **`1`** | SD-WAN 區域靜態路由。 |
| **Static DHCP** | **`5`** | 介面經由 DHCP 自動取得的預設網關。 |
| **Static Manual（手動靜態路由）** | **`10`** | 手動建立的靜態路由預設值。 |
| **EBGP（外部 BGP）** | **`20`** | 跨自治系統外部 BGP 路由。 |
| **OSPF** | **`110`** | 內部鏈路狀態協定。 |
| **ISIS** | **`115`** | 內部鏈路狀態協定。 |
| **RIP** | **`120`** | 內部距離向量協定。 |
| **IBGP（內部 BGP）** | **`200`** | 自治系統內部 BGP 路由。 |

---

### 實驗驗證與動態選路行為（Key Findings & Empirical Verification）

透過在 FortiGate 上建立兩條指向相同網段的靜態路由進行 AD 調校實驗：

1. **雙路由對等情況**：當兩條路由之 AD 與 Priority 皆相同時，兩者均會被安裝進路由表，形成 ECMP（等價多路徑轉發）。
2. **AD 差異化實驗**：
    * 將其中一條的 AD 調整為 `20`，保留另一條為 `10`：路由表立即**剔除 AD = 20** 的路徑，僅保留 AD 較低的線路。
    * 將次要線路的 AD 調降為 `5`：由於 `5 < 10`，路由表隨即動態切換，改由 AD = 5 的路徑安裝生效，原線路退出轉發狀態。


### 實務意涵與設計建議（Implications）

* **浮動靜態路由（Floating Static Route）部署**：利用 AD 作為第一 Tiebreaker 的特性，網路工程師可將備援線路的 AD 手動設大（如主要線路 AD = 10，備援 AD = 20），在不啟用複雜動態路由的情況下達成主備線路容錯切換。

* **DHCP 優先權覆蓋問題**：從 DHCP 取得的靜態路由預設 AD 為 `5`，信任度高於手動配置的靜態路由（AD = 10），若於同一介面混用手動路由與 DHCP，需手動調整 AD 避免預期外的路由被覆蓋。

## Router Priority in Fortigate Routing

### 背景與核心目的（Background & Objective）

* **背景**：在 FortiGate 路由架構中，若多條到達相同目的地的靜態路由具備相同的管理距離（AD），所有路由都會同時寫入路由表（RIB/FIB）並進行等價負載平衡（ECMP）。若管理者欲在維持備援路由同時常態指定單一路徑優先轉發，需引入第二決策條件。
* **核心目的**：解析 **Priority（優先權）** 作為「同 AD 靜態路由之決勝指標（Tiebreaker）」的判定機制，並透過修改 Priority 實測 `execute traceroute` 封包轉發路徑的即時切換行為。


### 架構設計與決策條件判定（Methodology / Decision Criteria）

* **數值規格與屬性規則**：
    * **數值範圍**：Priority 數值範圍為 **`0` 至 `4294967295**`（32-bit 整數）。
    * **預設值**：靜態路由預設 Priority 為 **`1`**（直接連線 Connected 路由預設不可變動）。
    * **決策原則**：**數值越小，優先權越高（Lower value = Higher preference）**。 

* **AD 與 Priority 雙層決策流程**：
    1. **第一階決策（AD，寫入路由表）**：比較 Administrative Distance。只有 AD 最小的路徑會被寫入路由表；若 AD 相同，則所有路徑**皆會寫入路由表**。
    2. **第二階決策（Priority，實際轉發選路）**：當多條路徑皆已寫入路由表時，系統比對 Priority。**僅選取 Priority 數值最小的那條路徑轉發流量**；其餘路徑留在路由表中作為即時備援。


### 實驗驗證與矩陣分析（Key Findings & Empirical Verification）

##### 實驗情境驗證

* **初始狀態（ECMP）**：WAN 1 與 WAN 2 的 AD 均為 `10`、Priority 均為 `1`，兩者皆寫入路由表並標記選取，流量分散傳輸。

* **調整 WAN 1 Priority = 10，WAN 2 Priority = 1**：
    * 兩條路由仍**同時保留在路由表內**（因為 AD 仍同為 10）。
    * 執行 `execute traceroute 8.8.8.8`，下一跳閘道選擇 `192.168.2.254`（WAN 2 出口），證明 Priority 數值較小者勝出。
    * **反轉 WAN 1 Priority = 1，WAN 2 Priority = 20**：
    * 路由表維持兩條，但 `execute traceroute` 即時改走 `192.168.1.254`（WAN 1 出口）。

配置範例：


1. 建立 WAN-1 靜態預設路由 (Default Route to WAN-1)

    * **選單路徑 (Navigation Path)**：
        點擊左側選單的 **`Network`** > **`Static Routes`**。
    * **介面操作**：
        點擊上方的 **`+ Create new`** 按鈕。
    * **欄位填寫與設定 (Edit / New Static Route 視窗)**：
        * **Destination**：選擇 **`Subnet`**，輸入 `0.0.0.0/0.0.0.0`。
        * **Gateway Address**：輸入 `192.168.1.254`。
        * **Interface**：下拉選取 **`WAN-1 (port1)`**。
        * **Administrative Distance**：輸入 `10`。
        * **Status**：點選 **`Enabled`**。
        * **展開 Advanced Options**：
            * **Priority**：輸入 `1`。
        * 點擊最下方的 **`OK`** 完成儲存。


2. 路由狀態驗證點擊步驟 (Verification)

    * **GUI 驗證方式**：
        1. 點擊左側選單的 **`Dashboard`** > **`Network`**。
        2. 點擊畫面中的 **`Static & Dynamic Routing`**（或點進 Routing 狀態卡片）。
        3. 進入 **`Routing`** 檢視清單，確認路由表中已包含兩條目的地為 `0.0.0.0/0` 且 Distance 為 `10` 的靜態路由。

    * **CLI 指令驗證**：

        ```bash
        get router info routing-table static
        ```

##### 路由決策矩陣（Route Selection Matrix）

針對四種典型組合（AD 與 Priority 數值大小）的最終勝出順位分析：

| 路徑標籤 | 數值特徵（AD 與 Priority 數值） | 決策結果與說明 |
| --- | --- | --- |
| **Route B** | **Low AD**, **Low Priority value**（數值小代表優勢高） | **第 1 順位（最優）**：AD 低先保證進入路由表，Priority 數值小優先轉發。 |
| **Route C** | **Low AD**, **High Priority value**（數值大代表優勢低） | **第 2 順位（次優）**：AD 低同樣進入路由表，但 Priority 較差，作為備援。 |
| **Route A / D** | **High AD** | **直接淘汰**：第一關比對 AD 時即落敗，**根本不會進入路由表**。 |

### 實務意涵與應用比較（Implications）

* **與 Floating Static Route（改 AD）的實務差異**：
    * **改 AD 作法**：次要線路不會出現在主路由表中，當主要線路中斷時，路由器需重新計算並將備援路由寫入轉發資料庫，切換延遲較長。
    * **改 Priority 作法**：主備路由**同時常駐於轉發層**，主要線路失效時可達成近乎**零延遲的無縫容錯切換（Seamless Failover）**。

## Route Metric and Its Significance

### 背景與核心目的（Background & Objective）

* **背景脈絡**：當單一路由協定在探索拓撲時發現多條通往相同目標網段的路徑，協定內部必須仰賴一套量化計算標準，以評估何者為最有效率的路徑。
* **核心目的**：解析 **Metric（度量值 / 權值）** 的運作原理，釐清其與 **Administrative Distance（AD，管理距離）** 在選路範疇上的本質差異，並橫向歸納主流路由協定（RIP、OSPF、EIGRP、BGP）所採用的不同度量計算維度。

### 架構設計與比較機制（Methodology / Conceptual Comparison）

#### 1. Metric vs. Administrative Distance（AD）作用層級對比


| 比較維度 | 路由度量值（Route Metric） | 管理距離（Administrative Distance, AD） |
| --- | --- | --- |
| **運作範疇** | **單一協定內部（Within a single routing protocol）**。 | **跨多種協定之間（Across multiple routing rotocols）*。 |
| **核心職責** | 在同一個動態路由協定中，評估多條路徑的最佳勝出者。 | 評估不同協定來源（如 OSPF vs. RIP vs. 靜態）的總體信任度。 |
| **選路先後順序** | 先由各協定依據 Metric 選出該協定的最佳路徑。 | 路由表再比對不同協定所選出路徑的 AD，AD 最小者進入路由表。 |
| **數值偏好** | 在 FortiGate 與標準網路設備中，**Metric 數值越低越優先（Lower is preferred）**。 | **AD 數值越低越優先**。 |

#### 2. 主流路由協定採用的 Metric 計算維度

* **Static Routing（靜態路由）**：**無預設動態 Metric**；路徑完全由網管人員手動決定（Administrator decides the route）。
* **RIP（Routing Information Protocol）**：以 **Hop Count（跳數）** 為度量基準。計算封包沿途穿越的路由器數量，路徑上路由器數量越少（跳數越小）者勝出。
* **OSPF（Open Shortest Path First）**：以 **Cost（開銷 / 成本）** 為度量基準。公式通常反比於介面頻寬（Bandwidth），頻寬愈大、Cost 愈低、鏈路愈優。
* **EIGRP（Enhanced Interior Gateway Routing Protocol）**：複合度量值，預設主要依據 **Bandwidth（頻寬）** 與 **Delay（延遲）** 計算最優路徑。
* **BGP（Border Gateway Protocol）**：以路徑屬性為導向，此處簡化為 **Path Count（AS-Path 長度）** 作為度量標準，穿越的自治系統（AS）越少越優先。



### 關鍵機制與運作範例（Key Findings & Path Selection Logic）

* **跳數選路陷阱（RIP 範例）**：
    * 若到達同一目標有兩條路徑：路徑 A 穿越 3 台路由器（3 hops），路徑 B 穿越 5 台路由器（5 hops）。
    * RIP 僅依據跳數大小判定，強制選擇 3 hops 的路徑 A，即使路徑 B 的實體頻寬高於路徑 A。
* **FortiGate 介面整合**：
    * 在 FortiGate 網路防火牆中，靜態或動態協定皆允許管理者手動指定或宣告 Route Metric。當相同協定中存在多條候選等價路徑時，FortiOS 優先採用 Metric 數值較小的路徑進行流量轉發。

TODO Static Route

### 實務意涵與設計建議（Implications）

* **選路階層的邏輯先後**：網路工程師除錯時需建立嚴謹的階層觀念——先在協定內部檢視 **Metric**（決定協定內部推薦誰），再於系統全域檢視 **AD**（決定哪種協定能寫入路由表），最後在同 AD 的靜態路由中以 **Priority** 決勝負。
* **跨協定重分配（Redistribution）之必要性**：由於各協定的 Metric 計算公式完全不相容（如 RIP 的跳數無法直接對比 OSPF 的 Cost），在做跨協定路由重分配時，必須由管理員手動指定「種子度量值（Seed Metric）」，否則外部路由將因無法識別度量單位而被丟棄。

## Primary and Backup Path Overview

### 背景與核心目的（Background & Objective）

* **背景脈絡**：企業通常具備多條網際網路或 WAN 線路（如雙 ISP：WAN 1 與 WAN 2）。在非雙線同時負載平衡（ECMP）的情境下，需要確保平時僅利用主要線路轉發，並在主要鏈路中斷時自動平滑切換至備用線路（Failover）。

* **核心目的**：探討在 FortiGate 上實作主備路徑（Primary & Backup Path）的兩種核心機制——**調整管理距離（AD）** 與 **調整優先權（Priority）** 的運作差異，並說明配合 **鏈路健康檢查（Link Health Monitor）** 達成無縫自動切換的整體流程。

### 架構設計與實作機制對比（Methodology / Comparative Analysis）

在 FortiGate 靜態路由中，主要有兩種方式來建構主備關係：

| 評估維度 | 機制一：修改管理距離（AD） | 機制二：修改優先權（Priority） |
| --- | --- | --- |
| **運作原理** | 主要線路設較低 AD（如 10），備援線路設較高 AD（如 20）。 | 兩條線路維持相同 AD（如 10），但備援線路設較高 Priority 數值（如 20，主線設 1）。 |
| **路由表狀態** | **僅主要路由寫入路由表（RIB/FIB）**；備援路由平時被隱藏排除。 | **主備兩條路由皆常駐於路由表**。|
| **轉發決策** | 僅依據 AD 最小者轉發流量。 | 依據 Priority 數值最小者優先轉發流量。 |
| **切換特性** | 浮動靜態路由（Floating Static Route）；主線失效時需重新向路由表注入備用路徑。 | 即時切換；由於備援路由已常駐於轉發層，收斂速度更快、負擔更低。 |

### 關鍵機制與切換流程（Key Findings & Failover Workflow）

標準的主備容錯切換由五大生命週期階段構成：

1. **設定預設路由（Configure Default Routes）**：針對雙 WAN 介面建立兩條指向各自主管閘道的預設靜態路由（`0.0.0.0/0`），並賦予不同的 AD 或 Priority。
2. **優選低值路徑（Prefer Lower Priority / AD Route）**：FortiOS 核心路由引擎自動選擇數值較小的線路作為 Active（Primary）通道傳輸封包。
3. **鏈路健康監測（Monitor Route Health）**：啟用 **Link Health Monitor**（如透過 Ping/DNS probe 檢測外部目標主機），主動監控實體線路與下一跳閘道的存活狀態。
4. **偵測路由不可達（Detect Route Unavailability）**：當主要鏈路發生中斷、封包遺失率超標或閘道無回應時，監控機制立即宣告該偏好路由失效。
5. **切換至備援路由（Switch to Backup Route）**：系統自動撤銷主路徑並啟動備用路徑接管所有流量，實現自動容錯轉移（Smooth Failover）。

### 實務意涵與架構演進（Implications）

* **黑洞路由防範**：單靠靜態路由的介面狀態（Link-Up）無法偵測到遠端 ISP 骨幹中斷，因此必須搭配 **Link Health Monitor**，才能確保主要線路失效時備援路由能被強制啟用。

* **多路徑演化路徑**：單純主備架構會造成備援線路頻寬閒置；實務上可根據業務需求，進一步演進為 **ECMP（多路徑等價負載平衡）** 或部署 **FortiGate SD-WAN**，依據應用程式品質（延遲、抖動、丟包）動態智慧調配兩條線路的流量。

## Understanding Equal Cost Multi-Path

### 背景與核心目的（Background & Objective）

* **背景**：企業部署多條對外 ISP 線路（如雙 WAN）時，若僅採用傳統主備模式，備援線路頻寬將長期閒置；若欲在相同目的地間實施並行多路徑負載平衡，需要嚴謹的比對條件與健全的雜湊排程機制。


* **核心目的**：解析 FortiGate **Equal Cost Multi-Path (ECMP)** 的觸發條件（同目的地、同協定、同 AD 與同 Priority）、四種演算法負載平衡模式，以及結合 Policy Route 優先級與多介面防火牆政策（Multiple Interface Policies）的轉發決策流程。



### 架構設計與演算法配置（Methodology / Algorithm Design）

##### 1. ECMP 觸發之充要條件

一組候選路徑若要被 FortiOS 視為 ECMP 組合並同時啟用負載平衡，必須滿足以下所有條件：

1. **相同目的地（Same Destination）**：如皆指向預設路由 `0.0.0.0/0`。
2. **相同路由協定來源（Same Protocol）**：支援 Static Routing、OSPF、BGP（不可跨協定混合）。
3. **相同管理距離（Equal Administrative Distance）**：手動靜態路由預設皆為 `10`。
4. **相同優先權（Equal Priority）**：靜態路由預設皆為 `1`。
5. **實體介面狀態正常（Interface Status UP）**。



##### 2. 四大負載平衡模式（ECMP Algorithms）

管理者可透過 CLI 切換 ECMP 演算法模式：

| 負載平衡模式 | 運作機制與排程邏輯 | 典型應用場景 |
| --- | --- | --- |
| **`source-ip-based`**<br>*(預設模式)* | 透過來源 IP 計算 Hash，將流量平均分散至各介面。**來自相同來源 IP 的所有連線 Session 恆走同一條路徑**。 | 預設網路環境，避免單一使用者的連線封包因走不同線路導致連線中斷。 |
| **`weight-based`** | 管理者手動為各介面指派權重（Weight）。系統依據連線 Session 總數的比例分配負載。 | 雙線路頻寬規格不對等的情境（如 300M 對比 100M）。 |
| **`usage-based`**<br>*(Spillover)* | 設定介面的 Ingress/Egress 頻寬閾值。流量未滿前固定走首選介面，**一旦超出閾值，溢出的流量才被導向下一成員介面**。 | 主線為吃到飽固定頻寬、副線為按流量計費的備援線路。 |
| **`source-dest-ip-based`** | 同時依據來源 IP 與目標 IP 進行雜湊。相同來源造訪相同目標走原路徑，造訪不同目標則可分散至另一線路。 | 內部終端設備較少但存取目標多元的環境，使單一 Client 也能有效利用雙線頻寬。 |


配置方式：


1. 來源 IP 模式 (Source IP Based)

    根據來源 IP 位址計算 Hash 值決定路由出口。同一台設備（相同來源 IP）即使連往不同目的地，都會走同一個介面。
    配置指令:


    ```bash
    FW1 # config system settings
    FW1 (settings) # set v4-ecmp-mode source-ip-based
    FW1 (settings) # end

    ```

2. 權重模式 (Weight Based)

    依照靜態路由設定的權重（Weight）比例來分配連線流量。

    配置指令:


    ```bash
    FW1 # config system settings
    FW1 (settings) # set v4-ecmp-mode weight-based
    FW1 (settings) # end

    ```

    **設定各靜態路由的 Weight（例如 WAN-1 設 10，WAN-2 設 5）**：
    ```bash
    FW1 # config router static
    FW1 (static) # edit 1
    FW1 (1) # set weight 10
    FW1 (1) # end

    FW1 # config router static
    FW1 (static) # edit 2
    FW1 (2) # set weight 5
    FW1 (2) # end

    ```

3. 使用量 / 溢出模式 (Usage Based / Spillover)

    流量優先走預設線路，當介面流量達到設定的閾值（Spillover Threshold）後，後續連線會溢出導向另一條介面。

    * 配置指令:

        **啟用 Usage-based 模式**：
        ```bash
        FW1 # config system settings
        FW1 (settings) # set v4-ecmp-mode usage-based
        FW1 (settings) # end
        ```
        **設定介面溢出閾值 (Spillover Threshold)**：
        ```bash
        FW1 # config system interface
        FW1 (interface) # edit port1
        FW1 (port1) # set spillover-threshold 5
        FW1 (port1) # end
        FW1 # config system interface
        FW1 (interface) # edit port2
        FW1 (port2) # set spillover-threshold 10
        FW1 (port2) # end
        ```

    * 驗證方式

        * **CLI 指令驗證**：

        ```bash
        FW1 # diagnose netlink dstmac list port1
        FW1 # diagnose netlink dstmac list port2
        FW1 # diagnose netlink dstmac list
        FW1 # get system session list
        ```


        * **GUI 檢視**：前往 **`Log & Report`** > **`Forward Traffic`**，確認當流量滿載溢出後，流量開始轉往 `WAN-2 (port2)` 傳輸。


4. 來源與目的 IP 模式 (Source-Destination IP Based)

    根據來源 IP 與目的 IP 兩者共同計算 Hash。即使同一台來源設備，只要連往不同的目標 IP，就會分流至不同的 WAN 出口。

    配置指令：

    ```bash
    FW1 # config system settings
    FW1 (settings) # set v4-ecmp-mode source-dest-ip-based
    FW1 (settings) # end
    ```

    * 驗證方式

        * **清除舊連線與封包監聽**：
        ```bash
        FW1 # diagnose sys session clear
        FW1 # diagnose sniffer packet any icmp 4
        ```

### 關鍵機制與決策流程（Key Findings & Forwarding Flow）

1. **路由優先權順序（Precedence）**：
    * **Policy Route（策略路由）擁有絕對最高優先權**。當流量匹配特定策略路由時，直接強制指定出口，繞過常規路由表與 ECMP 邏輯。
    * 只有在未匹配策略路由時，系統才進入路由表評估 ECMP。

2. **路徑容量與邊界值**：
    * FortiGate 預設支援最多 **`255` 條** ECMP 路徑。
    * 若將最大 ECMP 路徑數設為 **`1`**，則等同於完全**停用 ECMP 功能**。

3. **容錯與監控整合（Failover）**：
    * 單純 ECMP 僅負責負載分配；若要達成故障自動切除，必須配置 **Link Health Monitor**。當某條鏈路探測失敗時，系統自動將其從路由表中摘除，流量無縫轉由存活鏈路承載。

4. **防火牆安全政策配置要求（Firewall Policy）**：
    * 封包被 ECMP 分流後仍須通過安全策略檢查。
    * 管理者可選擇：
        * 針對各出口介面（WAN 1、WAN 2）分別撰寫獨立的 Firewall Policy；或
        * 於 `Feature Visibility` 中啟用 **Multiple Interface Policies**，將多個出接口合併於同一條策略內，簡化維運規則。

### 實務意涵與設計建議（Implications）

* **Session 黏滯性（Session Stickiness）權衡**：預設的 `source-ip-based` 保證了銀行或高安全性網站的登入 Session 不會因來源 IP 飄移而失效；但若內部網段僅有少數高負載伺服器對外傳輸，易發生負載傾斜，此時應改用 `source-dest-ip-based` 或引入 SD-WAN。

* **架構演進**：ECMP 僅能基於靜態規則（IP 雜湊或靜態閾值）轉發；若需即時偵測線路 SLA（延遲 Latency、抖動 Jitter、丟包率 Packet Loss）並依應用程式類型精細導流，應提升至 Fortinet SD-WAN 架構。

## Link Health Monitor 

### 背景與核心目的（Background & Objective）

* **背景**：在企業雙 WAN 或冗餘網際網路架構中，常見的故障並非本機端防火牆實體連接埠斷開（Port Link-Down），而是**上一層 ISP 閘道或骨幹網路失聯**。此時若僅依賴實體介面狀態，靜態路由將持續常駐於路由表中，導致流量被導向黑洞。


* **核心目的**：探討 FortiGate **Link Health Monitor（介面狀態偵測機制）** 如何主動探測對外鏈路品質，並在偵測到故障時動態將失效靜態路由自路由表剔除，驅動流量平滑容錯轉移（Failover）至備援介面（如 WAN 2）。

---

### 架構設計與檢測機制（Methodology / Detection Design）

* **探測原理**：
    * Link Health Monitor 定期（Regular intervals）透過特定 WAN 介面發送主動探測封包（通常為 ICMP Ping）至指定目標（如 ISP 下一跳 Gateway 或網際網路公共伺服器）。

* **判定參數**：
    * 管理者需定義探測間隔與失敗次數閾值（Fail threshold / Defined number of tests）。
    * 連續未收到回應達設定次數後，系統判定該線路處於不可用狀態（Line unavailable）。

* **狀態機流程（State Flow）**：

$$\text{持續監控 WAN 介面} \longrightarrow \text{判定主鏈路是否失效？} \begin{cases} \text{否} \to \text{繼續循環監控} \\ \text{是} \to \text{切換至備援介面 (Failover)} \end{cases}$$

#### 配置流程

1. Link Monitor CLI 配置

    ```bash
    config system link-monitor
        edit "WAN1"
            set srcintf "port1"             # 發送探測封包的出口介面。
            set server "8.8.8.8"            # 探測目標 IP 位址。   
            set protocol ping               # 監控協定（ICMP Ping）。
            set gateway-ip 192.168.1.254    # 探測封包使用的預設閘道
            set source-ip 0.0.0.0           # 自動依據介面 IP 決定來源 IP。
            set interval 500                # 探測間隔時間（單位為毫秒，500 ms 即 0.5 秒）
            set failtime 5                  # 連續探測失敗次數門檻，達到即判定線路中斷（Link Down）
            set recoverytime 5              # 連續探測成功次數門檻，達到即判定線路恢復（Link Up）
            set ha-priority 1               # 在HA環境中，優先順序用於故障轉移決策。
            set update-cascade-interface enable # 探測失敗時將該介面標記為 Down。
            set update-static-route enable      # 核心關鍵：當線路中斷時，自動自路由表移除相關靜態路由。
            set update-policy-route enable      # 當線路中斷時，自動失效相關策略路由（Policy Route）。
            set status enable                   # 啟用該 Link Monitor 設定。
        next
    end
    ```

    ```bash
    config system link-monitor
        edit "WAN2"
            set srcintf "port2"
            set server "8.8.8.8"
            set protocol ping
            set gateway-ip 192.168.2.254
            set source-ip 0.0.0.0
            set interval 500
            set failtime 5
            set recoverytime 5
            set ha-priority 1
            set update-cascade-interface enable
            set update-static-route enable
            set update-policy-route enable
            set status enable
        next
    end
    ```
2. 驗證
    * 檢查 Link Monitor 狀態：
        ```bash
        diagnose sys link-monitor status
        ```
        觀察輸出，確認 WAN1 狀態是否標記為 Status: dead、state: dead 且封包丟失率顯示為 100%。
    * 檢查靜態路由表：
        ```bash
        get router info routing-table static
        ```
        WAN-1 預設路由已被自動抽離，路由表中僅保留經由 port2 (192.168.2.254) 的預設路由。

### 關鍵機制與路由聯動（Key Findings & Routing Table Interaction）

下方生命週期展示了系統與路由表的動態交互過程：

| 階段步驟 | 系統行為與路由表連動 |
| --- | --- |
| **1. Monitor WAN Interfaces** | 主動向 WAN 介面發送探測請求。 |
| **2. Check Gateway Availability** | 驗證遠端閘道或網際網路目標的連通性。 |
| **3. Detect Interface Failure** | 連續逾時超過設定閾值，標記該主要鏈路失效。 |
| **4. Consider Line Unavailable** | 宣告該實體通道處於離線狀態。 |
| **5. Remove Static Route** | **將指向該失效介面的靜態路由直接從路由表（RIB/FIB）中移除**。 |
| **6. Failover to Backup** | 系統自動套用次佳路徑（如備用靜態路由或 ECMP 存活成員），完成容錯轉移。|
| **7. Return Record（鏈路復原）** | 當主線探測恢復正常後，**自動將原本的靜態路由重新寫回（Re-install）路由表**，流量無縫切回主路徑。 |


### 實務意涵與應用價值（Implications）

* **解決「靜態路由無感知」痛點**：Link Health Monitor 將被動的靜態路由賦予了類似動態路由的感知與收斂能力，且不會增加動態協定交互的頻寬負擔。

* **支援多架構容錯**：
    * **主備模式（Primary/Backup）**：強制拔除高優先權路由，讓備援路由接手。
    * **等價多路徑模式（ECMP）**：在某成員線路故障時將其自多路徑群組中剔除，避免部分雜湊連線持續丟包。

* **SD-WAN 的演進基礎**：此機制即為 Fortinet SD-WAN 中 Performance SLA（品質探測與自動選路）的底層技術雛形。

## Policy Routing

### 背景與核心目的（Background & Objective）

* **背景**：傳統常規路由（Regular Routing）僅依賴封包的「目的地 IP（Destination IP）」進行路徑查找，無法因應來源網段分流、特定通訊協定專線傳輸或多 ISP 差異化路由需求。

* **核心目的**：解析 FortiGate **Policy Routing（策略路由）** 的多維度匹配條件與流量重導向（Traffic Redirection）機制，並確立其在整體防火牆路由查找架構（Routing Table Lookup Sequence）中凌駕於常規路由表之上的最高優先順位。

### 架構設計與比較機制（Methodology / Comparative Analysis）

#### 1. 策略路由 vs. 常規路由（Regular Routing）對比


| 特性維度 | 策略路由（Policy Routing） | 常規路由（Regular Routing） |
| --- | --- | --- |
| **流量重導向（Redirection）** | **支援（Yes）**：可強制覆蓋路由表的最優選路。 | **不支援（No）**：嚴格遵循路由表計算結果。 |
| **匹配條件（Matching Criteria）** | **多維度組合**：來源/目的 IP、傳入介面、通訊協定（TCP/UDP/ICMP）、來源/目的通訊埠。 | **單一維度**：僅比對目的地 IP 位址（Destination IP）。 |
| **必備配置資訊** | 需明確指定下一跳閘道（Next-hop IP）與 FortiGate 出接口（Outgoing Interface）。 | 僅需目標網段、閘道與介面。 |
| **查找邏輯** | 自頂向下（Top-to-Bottom）循序比對，首條匹配即執行。 | 依循最長前綴匹配（Longest Prefix Match）、AD 與 Metric/Priority。 |

#### 2. 策略路由的動作選項（Action）

當流量命中策略路由時，可採取兩種處理動作：

* **Forward Traffic（轉發流量）**：將封包強制自指定的 Gateway 與 Interface 轉發出去。
* **Stop Policy Routing（停止策略路由）**：命中該規則後立即跳出策略路由判斷，讓該流量直接下放至後續的 SD-WAN 規則或路由表進行常規處理。


### 關鍵機制與完整路由查詢生命週期（Key Findings & Lookup Pipeline）

當封包自 Ingress 介面進入 FortiGate 後，系統依序執行的 5 階路由查找流程如下：

```
[Ingress 封包進入]
       │
       ▼
 1. Regular Policy Routes (常規策略路由) ──Match──> [執行 Action: Forward 或 Stop]
       │ (No Match 或 Action 為 Stop)
       ▼
 2. ISDB Routes (網際網路服務資料庫路由) ──Match──> [Forward 轉發]
       │ (No Match)
       ▼
 3. SD-WAN Rules (軟體定義廣域網規則) ────Match──> [Forward 轉發]
       │ (No Match)
       ▼
 4. Route Cache (路由快取記憶體) ────────Match──> [Forward 轉發]
       │ (No Match)
       ▼
 5. FIB / Routing Table (直連/靜態/動態) ──Match──> [Forward 轉發]
       │ (No Match)
       ▼
  [ Drop Packet 丟棄封包 ]

```

* **CLI 驗證與排錯指令對應**：
    * 檢視策略路由列表：`diagnose firewall proute list`
    * 檢視路由快取狀態：`diagnose ip rtcache list`
    * 查詢全域路由表：`get router info routing-table all`
    * 查詢底層核心轉發庫（FIB）：`get router info kernel`


### 實務意涵與應用場景（Implications）

* **多線路分流控制**：即便 WAN 1 在路由表具有較優優先權（Priority = 1），管理者仍可藉由策略路由將特定內部主機（如 PC1）或特定服務（如 SSH/Telnet）強制綁定至 WAN 2 出口。

* **黑洞與死路防範**：若策略路由指定的下一跳 Gateway 處於不可達狀態，封包可能會被強制送往無效路徑，實務上應設定 Gateway 探測或搭配健全的下一跳驗證機制。
* **架構排程優先性**：策略路由優先權高於 SD-WAN Rules；若設定了全覆蓋型策略路由，將導致後續配置的 SD-WAN 智慧選路功能完全失效。

## Named Addresses in Static Routes

在 FortiOS 的靜態路由（Static Routes）配置中，**具名位址（Named Address）** 是一種將預先定義好的**防火牆位址物件（Address Object）** 或 **位址群組物件（Address Group Object）** 作為靜態路由目的地（Destination）的配置概念，用以替代傳統手動輸入 IP 子網位址與遮罩（Subnet）的做法。

### 背景與核心目的（Background & Objective）

* **背景**：傳統靜態路由在配置目的地時，通常需手動輸入純數值 IP 網段（如 `192.168.50.0/24`）。在面對大型網路或經常需要動態對應網域名稱（FQDN）的環境中，重複輸入 IP 易導致設定繁瑣、可讀性差且難以維護。

* **核心目的**：探討 FortiGate（FortiOS）如何利用 **Named Address Object（命名位址物件）** 作為靜態路由的目的地，提升路由配置的可讀性與管理彈性，並釐清在 Web GUI 中啟用此功能的前置依賴條件。

### 架構設計與前置條件（Methodology / Implementation Prerequisites）

#### 1. 物件支援類型

靜態路由支援以下兩種類型的防火牆位址物件作為目的地：

* **Subnet**：將特定 IPv4 網段（如 `192.168.50.0/24`）定義為直觀名稱（如 `OfficeNetwork`）。
* **FQDN（完全合格網域名稱）**：針對特定網域名稱（如 `facebook.com`）動態解析 IP 並進行路徑導流。

#### 2. 關鍵前置條件（Prerequisite）

* **預設隱藏機制**：在全新或出廠預設狀態下，靜態路由新增介面僅會顯示 `Subnet` 與 `Internet Service` 兩個選項，**「Named Address」選項預設處於隱藏狀態**。

* **觸發顯示門檻**：必須在 **Policy & Objects > Addresses** 中建立至少一個位址物件，且**必須勾選啟用「Routing configuration（靜態路由配置）」** 開關。

* **動態依賴關係**：一旦系統中存在至少一個啟用該功能的物件，靜態路由頁面才會即時渲染出 `Named Address` 選項；若將符合條件的物件全數刪除，該選項會再次自動隱藏。

#### 3. 使用條件與限制

1. **必須啟用靜態路由配置選項**：
   只有在防火牆位址物件中啟用了「靜態路由配置（Static Route Configuration）」選項（在 CLI 中對應為 `set allow-routing enable`）的位址物件，才會顯示在 Named Address 的下拉式可選清單中。
2. **不支援地理位置類型物件**：
   地理位置類型（Geography type）的位址物件不支援此功能，無法作為靜態路由的目的地。


### 關鍵機制與配置生命週期（Key Findings & Configuration Workflow）

五大落實步驟如下：

| 階段步驟 | 操作說明 | 實例示範 |
| --- | --- | --- |
| **1. Identify Network Address** | 識別並確認欲引導流量的目標網段或網域名稱。 | `192.168.50.0/24` 或 `facebook.com` |
| **2. Create Named Address** | 定義易讀且具業務意義的物件名稱（快捷別名）。 | `OfficeNetwork` 或 `Facebook` |
| **3. Configure Firewall Address** | 在防火牆位址清單中建立物件，選擇類型為 Subnet 或 FQDN。 | Type: `FQDN`，FQDN: `facebook.com` |
| **4. Enable Routing Configuration** | **關鍵步驟**：在該物件設定中啟用路由配置開關。 | 勾選 `Static Route Configuration` |
| **5. Use in Static Routes** | 至 **Network > Static Routes**，切換為 `Named Address` 並指定出接口與閘道。 | Destination: `Facebook`，Interface: `WAN 1` |


### 實務意涵與應用價值（Implications）

* **提升架構維護性（Maintainability）**：當遠端分支機構網段發生變更時，管理者僅需至位址物件中更新一次 IP 定址，所有引用該物件的靜態路由與安全策略（Firewall Policy）均會同步生效，避免逐條路由手動修改的人為疏失。

* **支援動態 FQDN 路由**：傳統靜態路由無法直接處理浮動 IP 服務；透過 FQDN 物件結合 DNS 快取解析，防火牆能在底層依據解析結果自動維護靜態路由轉發標的。

## Internet Services Routing

### 背景與核心目的（Background & Objective）

* **背景**：現代企業廣泛採用雲端 SaaS 服務（如 Microsoft 365、AWS、Google 等）。這些服務背後擁有龐大且頻繁動態變更的公網 IP 網段清單（例如單一服務即涉及數千組 IP）；傳統網管若手動維護 Address Group，維運成本極高且易因 IP 變更導致連線中斷。
* **核心目的**：解析 FortiGate 如何運用內建並由 FortiGuard 自動定期更新的 **Internet Service Database（ISDB，網際網路服務資料庫）** 進行智慧型路由，使管理者能直接以服務名稱（Service Name）作為導流標的，並釐清其底層在轉發決策中「作為策略路由（Policy Route）」的本質特性。

### 架構設計與運作本質（Methodology / Architectural Design）

##### 1. ISDB 核心機制

* **內建資料庫**：位於 **Policy & Objects > Internet Service Database**，內建逾千種知名網路服務與應用程式（如 Adobe、Amazon、Apple、Cisco、Microsoft 365 等）。

* **動態維護**：由 FortiGuard 威脅情報團隊在雲端持續追蹤各廠商的公網 IP 範圍、連接埠與通訊協定，自動推播更新至防火牆，無需人工手動調整 IP 物件清單。



##### 2. 靜態路由介面配置與底層本質

* **GUI 配置路徑**：前往 **Network > Static Routes > Create New**，將 Destination 切換為 **`Internet Service`**，直接下拉選取特定服務（如 `Microsoft-Office365`）並指定出接口與閘道。

* **轉發層級本質（重大特性）**：
    * **不在常規路由表（RIB）內生成條目**：在 CLI 執行 `get router info routing-table all` 時，**無法**查看到該條 ISDB 靜態路由。
    * **底層以策略路由（Policy Route）形式實作**：ISDB 靜態路由在 FortiOS 核心引擎中實際上遵循策略路由的匹配規則，屬於核心路由查找第 2 階（介於常規 Policy Route 與 SD-WAN 規則之間）。


### 關鍵機制與驗證流程（Key Findings & Verification Workflow）

##### 1. 流量分流案例（以 Microsoft 365 為例）

* **情境**：企業擁有 WAN-1（普通線路）與 WAN-2（高速穩定線路）。

* **實作**：
    1. 建立 ISDB 路由：選取 `Microsoft 365`，導向 `WAN-2 (port2)`（閘道 `192.168.2.254`）。
    2. 預設靜態路由：所有其餘網際網路流量（`0.0.0.0/0`）維持走 `WAN-1 (port1)`。

* **效益**：7,000 多組 Microsoft 相關 IP 流量自動精確走高品質專線，其餘常規流量走一般線路。


##### 2. CLI 驗證指令

由於 ISDB 路由不寫入標準 RIB，必須使用策略路由專屬診斷指令進行檢視與確認：

```text
FW1 # diagnose firewall proute list
```

* **輸出結果**：可查看到由 ISDB 產生的策略路由條目，標記對應的 Internet Service ID、出接口（`port2`）與閘道 IP，並能即時觀察 `hit_count` 累積情形。

##### 3. 應用場景

1. **SaaS / 雲端應用精準分流 (Application Steering)**：
   * **消除傳統維運痛點**：像 Office 365 或 AWS 等雲端服務的 IP 位址極其龐大且頻繁變動，若使用傳統靜態路由手動維護，極易因 IP 變更而導致連線中斷。透過 ISDB 路由，設備會自動由 FortiGuard 取得最新 IP 清單並動態更新路由表。

2. **SD-WAN 本地網際網路切出 (Direct Internet Access, DIA / Local Breakout)**：
   * 在企業 SD-WAN 或分公司與總部連線架構中，管理者可設定將關鍵企業內部流量經由 VPN Overlay 送回總部，同時利用 **ISDB 路由** 將特定雲端服務（例如 Microsoft 365 或 Teams 視訊會議）直接從本地 WAN 介面（DIA）分流發送出去，以降低 VPN 隧道負載與傳輸延遲。

3. **結合 SD-WAN 與策略路由的動態選路 (SLA & Multi-WAN Steering)**：
   * 可結合 SD-WAN 服務規則（Service Rules），針對特定的 ISDB 服務設定品質策略（例如：最少成本策略 Lowest Cost 或最佳品質策略 Best Quality）。當主要 WAN 線路延遲或丟包率過高時，自動將該 ISDB 服務流量切換至備援線路。

4. **路由評估優先順序 (Order of Precedence)**：
   * 當封包進行路由比對時，FortiOS 的策略與分流評估優先順序為：
     $$\text{Policy-based routes} > \text{ISDB routes} > \text{SD-WAN routes}$$
     經由 ISDB 路由匹配的流量會優先於一般 SD-WAN 規則與標準路由表 (FIB/ECMP) 進行轉發。

### 實務意涵與設計建議（Implications）

* **簡化維運負擔**：將「追蹤 IP 變更」的責任完全轉移給 FortiGuard 雲端訂閱服務，消除因雲端供應商擴展 IP 導致防火牆連線中斷的風險。

* **路由查找優先順位意識**：
    * 雖然在 Web GUI 上它被歸類在「Static Routes」頁籤中，但工程師必須明瞭它在底層是 **ISDB 策略路由**，其優先權**高於**常規路由表（FIB）與 SD-WAN Rules，但**低於**管理者在 Policy Routes 頁籤手動配置的常規策略路由（Regular Policy Routes）。

## Understanding RIB and FIB in Fortigate


### 背景與核心目的（Background & Objective）

* **背景脈絡**：網路設備在處理封包轉發時，若直接由控制面（Control Plane）複雜龐大的全域路由表對每個封包進行決策，將造成 CPU 高度負載並拖慢轉發線速。


* **核心目的**：解析 FortiGate 防火牆將路由資料解耦為 **RIB（Routing Information Base）** 與 **FIB（Forwarding Information Base）** 的分層轉發機制，說明兩者在控制面與核心轉發面（Kernel/Data Plane）的分工，並掌握 CLI 查詢指令與各欄位代碼解讀方法。


### 架構設計與分層對比（Methodology / Plane Separation）

FortiGate 的路由體系劃分為控制面與核心轉發面，兩者協同運作：

| 評估維度 | 路由資訊庫（RIB / Routing Table） | 轉發資訊庫（FIB / Kernel Routes） |
| --- | --- | --- |
| **所屬層級** | **控制面（Control Plane）**。 | **資料/轉發核心面（Data Plane / Linux Kernel）**。 |
| **資料來源** | 彙整直連（Connected）、靜態（Static）及各動態協定（OSPF、BGP、RIP 等）學習到的**所有候選路由**。 | 由路由守護程序（Routing Daemon）計算後，**僅從 RIB 挑選最優路徑注入核心**。 |
| **主要功能** | 全域路徑資料庫，進行 AD、Metric 與 Priority 的選路計算。 | 針對每個進入設備的實際封包執行高速線速轉發決策。 |
| **快取加速機制** | — | 搭配 **Route Cache（路由快取）** 暫存近期的轉發決策以加速比對。 |
| **管理介面支援** | 支援 Web GUI 視覺化顯示與 CLI 檢視。 | **無 Web GUI**，僅能透過底層 CLI 檢視。 |
| **CLI 查詢指令** | `get router info routing-table all` | `get router info kernel` |

---

### 關鍵機制與資料結構解析（Key Findings & Field Structures）

##### 1. RIB 條目語法解讀

以 `S* 0.0.0.0/0 [5/0] via 192.168.2.254, port2, [1/0]` 為例

* **來源前綴代碼**：`C`（Connected 直連）、`S`（Static 靜態）、`*`（Candidate Default 預設路由）、`O`（OSPF）、`B`（BGP）、`R`（RIP）。
* **`0.0.0.0/0`**：目的地網路與子網路遮罩。
* **`[5/0]`**：`[Administrative Distance / Metric]`，前項為管理距離（此處為 5），後項為度量值（靜態路由為 0）。
* **`via 192.168.2.254`**：下一跳閘道 IP（Next-hop IP）。
* **`port2`**：出接口（Outgoing Interface）。
* **`[1/0]`**：`[Priority / Weight]`，前項為靜態路由優先權，後項為權重。


##### 2. FIB / Kernel 核心條目語法解讀

以 `tab=254 vf=0 type=1 proto=2 prio=0 ...` 為例

* **`tab`（Table Number）**：表格編號；`254` 代表單播（Unicast），`255` 代表多播/本機保留（Multicast/Local）。
* **`vf`（VDOM Index）**：虛擬防火牆編號，未啟用 VDOM 時預設為 `0`。
* **`type`（連線類型）**：`0` 未指定、`1` 單播（Unicast）、`2` 本機（Local）、`3` 廣播（Broadcast）、`4` 任播（Anycast）、`5` 多播（Multicast）、`6` 黑洞（Blackhole）、`7` 不可達（Unreachable）、`8` 禁止存取（Prohibited）。
* **`proto`（安裝來源協定）**：表示路由來源；`2` 代表 Kernel 本機產生、`11` 代表 ZebOS 路由模組（動態路由）、`14` 代表 FortiOS 靜態/直連。
* **`prio`**：核心路由優先權（數值愈低愈優先）。
* **`-> IP/Mask` 與 `gwy / dev**`：目標網路遮罩、下一跳閘道與對應的內部出接口索引編號（如 `dev=3(port1)`）。

### 實務意涵與除錯建議（Implications）

* **除錯盲點突破**：當策略或靜態路由配置看似正常但流量仍無法轉發時，問題常出在 **RIB 與 FIB 同步失效** 或介面狀態異常；工程師必須先檢視 RIB 確認路由是否被選出，再下達 `get router info kernel` 驗證該路徑是否成功注入底層核心轉發層（FIB）。

* **快取時效與狀態**：FortiGate 的 Route Cache 可加速已知流程的轉發，但當網路發生即時切換時，舊連線可能因快取或 Session 未清空而暫時未改走新路徑，除錯時可搭配清理快取以利驗證。
