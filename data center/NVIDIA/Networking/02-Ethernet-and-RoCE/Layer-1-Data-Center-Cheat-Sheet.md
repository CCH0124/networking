# Layer 1 Data Center Cheat Sheet

## Data Center Terminology

### 資料中心與網路架構術語對照表

| 英文術語 | 繁體中文譯名 | 定義與說明 |
| :--- | :--- | :--- |
| **Clos** | **Clos 架構** | 一種多級網路架構，旨在優化頻寬資源分配。名稱源自其發明者 Charles Clos。 |
| **ToR (Top of Rack)** | **機櫃頂端交換器** | 位於機櫃頂部的交換器，伺服器在此處接入網路。 |
| **Leaf** | **枝葉交換器** | 通常也稱為 ToR 或 **存取交換器 (Access Switch)**。在 Spine-Leaf 或 Clos 拓撲中常用的稱呼。 |
| **Exit-Leaf** | **出口枝葉交換器** | 連接資料中心外部服務的 Leaf 交換器，包含防火牆、負載平衡器和網際網路路由器。 |
| **Spine** | **骨幹交換器** | 也稱為 **匯聚交換器 (Aggregation)**、**列末交換器 (EoR)** 或 **分發交換器 (Distribution)**。在 Spine-Leaf/Clos 拓撲中通稱為 Spine。 |
| **Super-Spine** | **超級骨幹交換器** | 有時稱為骨幹匯聚交換器或 **資料中心核心交換器 (Core Switch)**。通常用於三層式 Clos 架構中。 |
| **MLAG** | **跨機框鏈路聚合** | (Multi-Chassis Link Aggregation) 允許一對交換器以「雙活」(Active-Active) 模式達成備援，並在邏輯上呈現為單一台交換器。 |
| **Peerlink** | **對等鏈路** | 用於連接 MLAG 配對中兩台交換器的實體鏈路或聚合鏈路。 |
| **ECMP** | **等價多路徑路由** | (Equal-Cost Multi-Path) 允許在多條路由路徑之間進行流量負載分擔。 |
| **Layer 3 Fabric** | **三層網路架構** | 有時稱為「路由架構」(Routed Fabric)。Leaf 與 Spine 層之間採用 Layer 3 路由協議，並利用 ECMP 來提升整體頻寬。 |
| **OOB** | **帶外管理** | (Out of Band Management) 獨立於高速業務網路之外的低速管理網路（通常為 1Gbps 或更低），專用於基礎設施管理；亦指交換器上的 1G 管理介面。 |
| **POD** | **網路單元 / POD** | 由網路、儲存與運算資源組成的模組化單元。POD 是一種可重複的設計模式，使資料中心更易於擴展與管理。 |

## 通用資料中心架構

### Two-Tier Clos Architecture (Leaf-Spine)

![Two-Tier Clos Architecture](https://docs.nvidia.com/networking-ethernet-software/images/knowledge-base/L1-Cheat-Sheet/two_tier_clos.png) From nvidia

##### 1. 架構連接特性 (Topology)

* **全連結性**：每一台 Leaf 都必須與每一台 Spine 相連。
* **水平隔離**：Spine 與 Spine 之間沒有實體連線（No inter-spine links）。
* **高效路徑**：流量路徑極簡化，任何 Leaf 間的通訊最多僅需經過一台 Spine。

##### 2. 三層路由優勢 (Layer 3 Routing)

* **排除 MLAG**：Spine 層之間不需執行 MLAG，減少設定複雜度。
* **頻寬優化**：利用 **ECMP (等價多路徑)** 讓流量在所有 Spine 之間平均分擔，最大化頻寬利用率。
* **擴充性**：Spine 層可靈活擴充（通常建議 3 台以上），提升整體架構的耐受度。

##### 3. 技術演進：從 MLAG 轉向 EVPN-MH

* **簡化維運**：透過 **BGP-EVPN** 協議中的 **EVPN-MH (多重歸屬)** 技術，可完全取代傳統的 MLAG。
* **伺服器備援**：在維持伺服器「雙上行」備援（Redundancy）的前提下，解決了 MLAG 在控制平面（Control Plane）同步上的技術複雜難題。

內容強調了資料中心從「二層（L2）傳統環境」轉向「三層（L3）路由環境」的過程。最核心的進步在於利用 **BGP-EVPN** 統一控制平面，讓網路不僅能自動處理負載平衡，還能擺脫傳統 MLAG 容易遇到的專有技術限制與排錯困難。

### Three-Tier Clos Architecture (Leaf-Spine-Super Spine)

![Three-Tier Clos Architecture](https://docs.nvidia.com/networking-ethernet-software/images/knowledge-base/L1-Cheat-Sheet/three_tier_clos.png)

對於規模更大的網路，Leaf 交換器可以採增量方式添加，並在單個 POD（網路單元）內與 Spine 層進行匯聚。若要進一步擴大資料中心規模並建立多個 POD，可以使用另一層被稱為 **Super-Spine（超級骨幹）** 的交換器，來匯聚各個 POD 的 Spine 層。這種架構即稱為**三層式 Clos 網路 (Three-Tier Clos Network)**。

##### 1. POD 內的彈性擴充 (Intra-POD Scaling)

* **增量成長**：在單一 POD 內部，可以根據需求逐步增加 Leaf 交換器的數量。
* **局部匯聚**：這些新增的 Leaf 直接上連至該 POD 內的 Spine 交換器，形成基礎的二層 Clos 拓撲。

##### 2. 跨 POD 的大規模擴展 (Inter-POD Scaling)

* **引進 Super-Spine**：當資料中心需要容納更多 POD 時，會新增第三層設備 Super-Spine。
* **層級匯聚**：Super-Spine 的作用是將不同 POD 的 Spine 層連接起來，實現跨 POD 的流量互通。

##### 3. 三層式 Clos 架構的層級

這類大型架構由下而上分為三層：

1. **Leaf 層**：連接伺服器與終端設備。
2. **Spine 層**：匯聚該 POD 內的 Leaf 流量。
3. **Super-Spine 層**：匯聚所有 POD 的 Spine，作為資料中心的核心骨幹。

##### 為什麼要分 POD？

在大規模資料中心中，分 POD 的設計有助於**故障隔離（Fault Isolation）**。如果某個 POD 的網路出現問題，影響範圍通常會侷限在該單元內，而不會波及整個資料中心。同時，透過 **Super-Spine** 的連結，即使是不同 POD 間的伺服器通訊，也能維持極高的頻寬與低延遲。

## 常見主機到 ToR（葉節點）網路連線類型

### MLAG

![MLAG](https://docs.nvidia.com/networking-ethernet-software/images/knowledge-base/L1-Cheat-Sheet/mlag.png)

**MLAG（跨機框鏈路聚合）**是指兩台獨立的交換器能夠建立一個單一的 LACP 或靜態鏈路聚合（Bond），儘管這些連結是來自兩台物理上獨立的設備。**VRR（虛擬路由器備援）**則能讓一對交換器充當單一閘道（Gateway），以實現高可用性（HA）以及伺服器的雙活（Active-Active）鏈路。

##### 1. MLAG (Multi-Chassis Link Aggregation)

* **跨設備聚合**：傳統的 LACP 只能在單一交換器上進行，MLAG 突破了物理限制，讓伺服器以為自己是接在「同一台」交換器上，但實際上是橫跨兩台設備。
* **優點**：
  * **無環路架構**：不再需要傳統的生成樹（STP）來阻斷路徑，所有鏈路皆可同時傳輸資料。
  * **頻寬翻倍**：兩條上行鏈路皆處於轉發狀態（Active-Active）。

##### 2. VRR (Virtual Router Redundancy)

* **虛擬閘道**：兩台交換器共用一個虛擬 IP（VIP）和虛擬 MAC 位址。
* **高可用性 (HA)**：當其中一台交換器故障時，另一台會立即接管閘道功能，伺服器無需更改配置或重啟連線。
* **Active-Active 轉發**：在 MLAG 環境下，VRR 允許兩台交換器同時處理來自伺服器的路由流量，實現真正的負載平衡。

##### 3. 雙活連結 (Active-Active)

* **消除單點故障**：任何一台交換器或任一條線路損壞，服務都不會中斷。
* **提升效能**：伺服器到網路的路徑可以同時利用兩台交換器的效能，而非一主一備（Active-Standby）。

##### VRR vs. VRRP

在資料中心領域，特別是 Arista 等廠牌常用的 **VRR** 與標準協定 **VRRP** 略有不同。一般的 VRRP 通常只有一台 Master 在轉發流量，而 **VRR** 與 MLAG 配合時，兩台交換器都能同時進行 Layer 3 轉發，這就是文中所強調的 **Active-Active** 特性。

### EVPN Multihoming (EVPN-MH)

![EVPN Multihoming](https://docs.nvidia.com/networking-ethernet-software/images/knowledge-base/L1-Cheat-Sheet/evpn-mh.png)

**EVPN 多重歸屬 (EVPN-MH)** 是資料中心部署中，用來取代各家廠商私有 **MLAG** 協定的標準化方案。它能提供伺服器「全雙活」（All-active）的連線能力，且 **ToR 交換器之間不需要對等鏈路（Peerlinks）**。由於 EVPN-MH 是基於標準的協定，因此能透過單一的 **BGP-EVPN 控制平面** 實現多廠商設備的互通性。此技術讓資料中心部署變得更簡單，維運人員不再需要去理解或使用複雜的私有協定。

##### 1. 標準化與相容性 (Standards-based)

* **擺脫廠商鎖定**：與傳統 MLAG（通常為廠商私有技術，如 Arista MLAG, Cisco vPC）不同，EVPN-MH 是業界標準協定。
* **多廠商互通 (Multi-vendor)**：允許在同一個資料中心內混合使用不同品牌的交換器（只要皆支援 BGP-EVPN），並能保持控制平面統一。

##### 2. 架構簡化 (Architecture Simplification)

* **無需 Peerlinks**：這是與 MLAG 最大的不同之處。ToR 交換器之間不需要實體的對等連線，減少了佈線負擔與故障點。
* **全雙活連線 (All-active)**：伺服器的多條上行鏈路可以同時轉發流量，最大化頻寬利用率。

##### 3. 維運優勢

* **統一控制平面**：僅需維護一套 BGP-EVPN 協定即可同時處理 L2 延伸與多重歸屬備援，大幅降低管理複雜度。
* **降低學習成本**：不需要為了不同品牌的設備去學習各種私有的冗餘技術。

##### 為什麼「無 Peerlink」這麼重要？

在傳統 MLAG 中，**Peerlink** 是最脆弱的一環。如果 Peerlink 發生故障（Split-brain），網路會變得極其複雜且難以排錯。**EVPN-MH** 則是透過 BGP 協定在控制平面（Control Plane）進行狀態同步，這讓網路拓撲變得更乾淨，也更符合現代軟體定義網路（SDN）的設計原則。

### Redistribute Neighbor

![Redistribute Neighbor](https://docs.nvidia.com/networking-ethernet-software/images/knowledge-base/L1-Cheat-Sheet/redis-neigh.png)

**Redistribute neighbor daemon（鄰居重分發守護行程）** 會動態監測 ARP 項目，並將這些 IP 位址重分發（Redistribute）至網路架構（Fabric）中。當 MLAG 或 EVPN 無法作為伺服器連線的可行方案時，Redistribute neighbor 就會是一個非常有用的替代選擇。

##### 1. 運作機制：從 ARP 到路由

* **動態監測**：該守護行程會持續監控交換器上的 ARP 表項。當有伺服器接入並產生 ARP 紀錄時，系統會自動感知。
* **自動宣告**：它會將偵測到的主機 IP 轉換為 **/32 主機路由**，並自動注入到 BGP 或 OSPF 等路由協定中，讓整個網路架構（Fabric）知道該主機的位置。

##### 2. 核心優勢：純三層 (Pure L3) 到主機

* **無需 L2 延伸**：伺服器可以直接與交換器建立 Layer 3 連結，不需要處理生成樹（STP）或複雜的 Layer 2 廣播問題。
* **簡化配置**：在不需要（或無法支援）EVPN 或 MLAG 的環境下，依然能實現伺服器的連線與遷移感應。

##### 3. 適用場景

* **非傳統環境**：當硬體不支援 EVPN，或環境中不適合部署 MLAG 的對等鏈路（Peerlink）時。
* **大規模主機路由**：適用於希望將路由點直接下放至靠近伺服器（Host）端的設計。


通常在這種架構下，你會在伺服器上配置相同的 IP（例如透過 Anycast IP），或者單純讓 Leaf 交換器透過 `rdnbrd` (Redistribute Neighbor Daemon) 自動學習接在後面的所有主機，而不需要手動去設定每一條路由。這對於自動化程度要求高、且想擺脫 Layer 2 複雜性的**平台工程**團隊來說，是一個非常優雅的解決方案。

## Ethernet Optics and Cables

### Transceivers Modulation Scheme

![](https://docs.nvidia.com/networking-ethernet-software/images/knowledge-base/L1-Cheat-Sheet/pam_nrz.png)

1. NVIDIA LinkX 產品線

    * 涵蓋範圍：提供資料中心互連所需的所有物理層組件，包括：
      * DAC (Direct Attach Copper)：銅纜，適用於機櫃內短距離連接。
      * AOC (Active Optical Cable)：主動式光纜，比 DAC 輕量且距離較長。
      * Optical Transceivers：光學收發器（光纖模組）。

2. 調變技術的世代交替 (NRZ vs. PAM4)

    * 100G (含) 以下：採用 NRZ (Non-Return to Zero)
      * 這是傳統的訊號傳輸方式，一個訊號位準（High/Low）只代表 1 個位元（0 或 1）。
    * 200G (含) 以上：採用 PAM4 (Pulse Amplitude Modulation 4-levels)
      * 這是現代高速網路的關鍵技術，透過 4 個不同的電壓位準，讓一個訊號週期內可以攜帶 2 個位元 的資訊。

3. PAM4 的核心優勢

    * 頻寬翻倍：在不增加硬體時鐘頻率（維持 25GHz）的情況下，傳輸效率直接提升 100%。
    * 成本控制：由於不需要大幅提升時鐘頻率，可以繼續沿用相對低成本的連接器與物理組件，解決了高速網路帶來的成本壓力。