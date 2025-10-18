# Border Gateway Protocol

Border Gateway Protocol (BGP) 作為網際網路的核心路由協議，對於數據中心與外部網路的連接至關重要。

## 一、 BGP 協議基礎與核心機制 (BGP Fundamentals and Core Mechanisms)

BGP 是一種**路徑向量路由演算法** (path-vector routing algorithm)，主要用於在不同的自治系統 (Autonomous Systems, AS) 之間交換路由資訊，其設計目標是確定到達特定目的地的最佳路徑，同時確保網路中不會出現路由迴圈。

> 不像鏈路狀態路由協議那樣包含網路的完整拓撲
> AS_Path 在 BGP 中用作迴路防止機制。
> AS_Path A BGP attribute used to track the autonomous systems a network has been advertised through as a loop prevention mechanism.

### 1. 自治系統 (Autonomous System, AS)

AS 是由單一管理實體控制的網路集合，擁有獨立的路由策略。

* BGP 支援 16 位元和 32 位元 AS 編號。
* **BGP 路由資訊**：交換的路由資訊包含目的地的路由前綴 (route prefix)、到達該目的地的自治系統路徑 (**AS path**)，以及多種額外的路徑屬性 (path attributes, PAs)。

> ASN 64,512 到 65,534 是 16 位元 ASN 範圍內的私有 ASN，而 4,200,000,000 到 4,294,967,294 是擴展 32 位元範圍內的私有 ASN。

### 2. BGP 傳輸層與會話建立

BGP 使用 **TCP 協議 (Port 179)** 作為可靠的傳輸協議，在 BGP 路由器（或稱為 BGP speakers）之間建立 TCP 連線會話。

* **無自動發現機制**：BGP 鄰居關係必須透過手動配置來定義。
* **路由交換**：當 TCP 連線建立後，BGP 對等體會先交換完整的 BGP 路由表；之後只傳送**增量更新** (incremental updates)。
* **Keepalive 與 Hold Time**：在沒有路由更新時，BGP 對等體會交換 Keepalive 訊息以維持會話活躍。
  * **Hold Time** 是接收連續 BGP 更新或 Keepalive 訊息之間允許經過的最大時間限制。在 Cisco NX-OS 環境中，預設 Hold Timer 為 180 秒，Keepalive 間隔為 60 秒。
* **router id** 要在對等端之間建立 BGP 會話，BGP 必須具有路由器 ID，該 ID 會在建立 BGP 會話時通過 OPEN 消息發送給 BGP 對等端。
  * 如果 BGP 沒有路由器 ID，它無法與任何 BGP 鄰居建立對等連線

> BGP session 是兩個 BGP 路由器之間建立的鄰接關係

### 3. BGP 鄰居狀態機 (Finite-State Machine, FSM)

BGP 使用 FSM 來維護與所有 BGP 對等體的操作狀態。一個典型的 BGP 會話會經歷以下幾個關鍵狀態：

1. **Idle**：初始狀態，嘗試啟動 TCP 連線。
2. **Connect/Active**：嘗試建立 TCP 連線。
3. **OpenSent/OpenConfirm**：交換 OPEN 訊息並協商能力，例如 BGP 版本、AS 編號和保持時間。
4. **Established**：BGP 會話完全建立，開始透過 **UPDATE 訊息**交換路由資訊。

## 二、 BGP 會話(BGP session)類型與路由傳播規則

BGP 會話根據對等體是否位於同一自治系統內部分為兩類，並且各自擁有不同的路由傳播規則。

### 1. eBGP (External BGP)

* **定義**：用於在**不同** AS 之間交換路由資訊。
* **行為特點**：
  * 預設情況下，eBGP 數據包的 **TTL 設置為 1**，這要求對等體通常是直接連接的（單跳）。如果需要建立多跳 eBGP，則需要額外配置 `ebgp-multihop`。
  * 通告路由時，**eBGP 鄰居會修改下一跳地址** (Next Hop) 為發送路由的路由器介面 IP 地址。
  * eBGP 學習到的路由，其管理距離 (Administrative Distance, AD) 預設為 **20**。

### 2. iBGP (Internal BGP)

* **定義**：用於在**相同** AS 內部的 BGP 路由器之間交換路由資訊。
* **行為特點**：
  * iBGP 數據包的 **TTL 預設為 255**，這允許對等體之間可以非直連（多跳連線）。
  * iBGP 學習到的路由，其管理距離 (AD) 預設為 **200**。
  * iBGP 通常使用 **Loopback 介面**建立會話，以增加冗餘，因為 Loopback 介面的可達性依賴於底層的 IGP（如 OSPF 或 EIGRP）。

### 3. iBGP Split-Horizon 規則 (iBGP Split-Horizon Rule)

這是 BGP 設計中處理環路預防的關鍵機制：

* **規則內容**：BGP 路由器從一個 iBGP 對等體收到的路由，**不會再通告給任何其他的 iBGP 對等體**。
* **設計含義**：為確保 AS 內部所有路由器都能學習到外部路由，AS 內部所有 iBGP 路由器之間必須建立**全網狀 (full mesh) 連線**。

## 三、 BGP 路由資訊庫與路徑選擇機制 (BGP Best Path Selection)

BGP 最佳路徑選擇是該協議最複雜也最具控制力的部分。路由器會維護多個路由表格，並依賴一套嚴格的屬性順序來選擇唯一的最佳路徑。

### 1. BGP 三個核心路由表

BGP 路由器使用三個主要表格來處理路由資訊：

1. **Adj-RIB-in**：存放從鄰居收到的、未經入向策略修改的原始路由。
2. **Loc-RIB (BGP Table)**：包含了所有本地產生或從鄰居接收到的有效路由。最佳路徑計算在此進行。
3. **Adj-RIB-out**：存放經過出向策略處理後，準備通告給特定鄰居的路由。

### 2. BGP 路徑屬性分類 (Path Attribute Classifications)

BGP 路由的選取取決於附帶的各種路徑屬性 (PAs)。PAs 主要有四種分類，影響了它們能否跨越 AS 傳播：

| 屬性類別 | 識別性 (Required by all implementations) | 傳遞性 (Advertised Between ASs) | 範例 |
| :--- | :--- | :--- | :--- |
| Well-known Mandatory | 必須識別 | 是 | Next-Hop, AS-Path, Origin |
| Well-known Discretionary | 必須識別 | 否 | Local Preference |
| Optional Transitive | 不必須識別 | 是 (如識別則傳播) | Community, Atomic Aggregate |
| Optional Non-transitive | 不必須識別 | 否 | MED, Originator ID, Cluster List |

### 3. BGP 最佳路徑選擇順序 (Best Path Algorithm)

當一個目的地有多條路徑時，BGP 遵循以下嚴格順序進行比較，直到找到唯一最佳路徑：

1. **最高 Weight (權重)**：本地配置，僅在本地路由器有效。**最高**值優先。
2. **最高 Local Preference (本地偏好)**：在整個 AS 內傳播。**最高**值優先，通常用於影響流量流出 AS 的路徑。
3. **本地產生 (Locally Originated)**：本地路由器通過 `network` 命令或聚合產生的路由優先。
4. **最短 AS Path (AS 路徑長度)**：AS 數量最少者優先，用於防止環路和選擇最短路徑。
5. **最低 Origin Type (起源類型)**：起源代碼最低者優先 (IGP/i < EGP/e < Incomplete/?)。
6. **最低 Multi-Exit Discriminator (MED)**：用於影響流量進入 AS 的路徑選擇。**最低**值優先。
7. **eBGP 優於 iBGP**：外部路徑 (eBGP) 優先於內部路徑 (iBGP)。
8. **最低 IGP Metric**：到達 BGP Next-Hop 地址的內部網關協議 (IGP) 成本最低者優先。
9. **最舊 eBGP 會話**：如果兩條路徑都是 eBGP 學習，則較早建立的會話所學習的路徑優先（有助於網路穩定性）。
10. **最低 BGP Router ID (RID)**：發布路由的路由器 ID 最低者優先（如果通過 Route Reflector，則比較 Originator ID）。
11. **最低 Neighbor IP Address**：用於打破最後的平局。

### 4. ECMP 和 Next-Hop

* **Equal-Cost Multipathing (ECMP)**：BGP 支援 ECMP，允許在多條 metric 相同、被選為最佳路徑的路徑之間進行負載平衡。
* **Next-Hop 可達性**：所有 BGP 路由必須通過下一跳可達性檢查 (Next-Hop reachability check) 才能被視為有效 (Valid) 路徑，並進入最佳路徑選擇過程。若下一跳不可達，該路由雖然保留在 BGP 表中，但會標記為無效。在 iBGP 環境中，通常需要使用 `next-hop-self` 命令或將下一跳地址通告到 IGP 中，以確保其可達。

## 四、 BGP 可擴展性與多協議擴展 (Scalability and MP-BGP)

由於 iBGP 的全網狀要求和路由表爆炸問題，BGP 引入了擴展性機制。

### 1. 路由反射器 (Route Reflector, RR)

Route Reflector 是最常用的 iBGP 擴展方案，用於減少 iBGP 的全網狀連線負擔。

* **運作原理**：將 AS 內的路由器分為 **Route Reflector (RR)** 和 **Client**。Client 之間不需要直接連線，只需與 RR 建立 iBGP 會話。
* **環路預防**：RR 使用兩個非傳遞屬性來防止環路：
  * **Originator ID**：標識將前綴注入 AS 的路由器 ID。
  * **Cluster List**：包含所有反射該路由的 RR 的 Cluster ID 列表。

### 2. 聯盟 (Confederations)

聯盟是一種替代全網狀的方案，將單一 AS 分割為多個子 AS (Member ASs)。

* **外部視角**：外部 AS 看不到內部的子 AS 結構，只看到單一的聯盟 AS 標識符。
* **AS Path 處理**：AS Path 中包含特殊的 `AS_CONFED_SEQUENCE` 字段來記錄內部子 AS 號，但這個序列在計算最短 AS Path 時會被忽略。

### 3. 多協議 BGP (Multiprotocol BGP, MP-BGP)

Cisco NX-OS 支援 BGP Version 4 並包含多協議擴展。

* **地址族 (Address Family, AF)**：MP-BGP 透過 AFI (Address Family Identifier) 擴展，允許 BGP 承載不同 L3 協議（如 IPv4 Unicast、IPv6 Unicast、VPNv4 等）的路由資訊。
* **數據庫隔離**：每個配置的地址族都會維護一個獨立的路由資料庫 (Loc-RIB) 和配置。

> 需要使用路由器的 address-family 和 neighbor address-family 配置模式來支持多協議 BGP 配置

## 五、 Cisco NX-OS/IOS XE 環境下的配置與驗證

在實際數據中心環境中，掌握 BGP 的配置和驗證命令是資深架構師的必備技能。

### 1. 關鍵配置步驟 (Configuration Highlights)

| 目的 (Purpose) | 命令 (Command) | 說明 (Source) |
| :--- | :--- | :--- |
| 啟用 BGP 功能 | `feature bgp` (NX-OS) | 啟用 BGP 協議。 |
| 啟用 BGP 實例 | `router bgp autonomous-system-number` | 啟用 BGP 進程並分配本地 AS 編號。 |
| 配置 Router ID | `router-id ip-address` | 配置唯一的 BGP 路由器 ID。建議配置以避免會話抖動。 |
| 配置鄰居 | `neighbor ip-address remote-as as-number` | 配置遠端對等體地址和 AS 編號。 |
| 路由注入 | `network ip-prefix mask subnet-mask` | 必須精確匹配本地 RIB 中的路由，才會注入 BGP 表。 |
| 啟用 Next-Hop-Self | `neighbor ip-address next-hop-self` | 通常在 iBGP 鄰居上配置，確保下一跳可達。 |
| eBGP 多跳連線 | `neighbor ip-address ebgp-multihop hops` | 當 eBGP 鄰居非直連時使用。 |
| 啟用地址族 | `address-family {ipv4 | ipv6} unicast` | 進入地址族模式，進行路由宣告和鄰居激活。 |

### 2. 核心驗證命令 (Verification Commands)

| 目的 (Purpose) | 命令 (Command) | 說明 (Source) |
| :--- | :--- | :--- |
| 狀態摘要 | `show bgp {ipv4 | ipv6} unicast summary` | 顯示 BGP 狀態（如 Established, Idle）和從每個鄰居接收到的前綴數量 (PfxRcd)。 |
| BGP 路由表 | `show bgp {ipv4 | ipv6} unicast [network]` | 顯示 BGP 路由表 (Loc-RIB)，包括所有路徑、下一跳、屬性 (MED, LocPrf, AS Path, Origin) 和最佳路徑 (`>`)。 |
| 鄰居詳細資訊 | `show bgp {ipv4 | ipv6} unicast neighbors [ip-address]` | 顯示詳細協商設置、定時器、AD 和交換的前綴計數。 |
| 鄰居通告路由 | `show bgp ipv4 unicast neighbors ip-address advertised-routes` | 顯示通告給特定鄰居的路由 (Adj-RIB-Out)。 |
| 路由表中的 BGP 路由 | `show {ip | ipv6} route bgp` | 顯示已安裝到 IP 路由表 (RIB) 中的 BGP 路由。 |

### 3. 故障排除要點 (Troubleshooting Focus)

在故障排除 BGP 時，資深架構師會關注幾個常見問題：

* **鄰居連線失敗 (Neighbor Failure)**：檢查 TCP Port 179 是否被 ACL 阻擋；eBGP 是否使用 `ebgp-multihop`；兩個鄰居之間是否有路由可達性（不能僅依賴預設路由）；以及 `remote-as` 配置是否正確。
* **路由遺失 (Missing Routes)**：
    1. 檢查是否違反 **iBGP Split-Horizon 規則**。
    2. 檢查 **Next-Hop 是否可達** (Next-Hop Unreachable)。
    3. 檢查是否有路由過濾器（如 Prefix List, Route Map）阻止了路由通告或接收。
    4. 確認 `network` 命令是否**精確匹配** RIB 中的現有路由。
    5. 確認是否有更優的路由源（例如，IGP 路由的 AD 低於 BGP 路由的 AD 200）導致 **RIB 故障** (`r RIB-failure`)。