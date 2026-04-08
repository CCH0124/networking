## EVPN L2

![l2evpn](https://docs.nvidia.com/networking-ethernet-software/images/guides/VXLAN-EVPN-design-guide/l2evpn.png)

L2 EVPN 部署採用如圖所示的「橋接疊加網路」（Bridged Overlay）。它在 EVPN 網路中提供乙太網路橋接功能，並透過 **VXLAN 隧道** 在 Leaf 設備之間延伸 VLAN。這些 Leaf 對 Leaf 的 VXLAN 隧道對於需要 Leaf 設備間連通性、但不需要跨 VLAN 路由（Inter-VLAN routing）的網路非常有用。因此，**網路的「智慧化」功能集中在 Leaf 層**，而 Spine 層僅提供 Leaf 設備間的連線能力。Leaf 設備會建立 **VTEP** 來連接其他 Leaf 設備，這些隧道讓 Leaf 與資料中心內連接乙太網路的端點系統得以通訊。

關於 STP 的變革

**STP** 是一種 L2 交換協定，透過建立單一重路徑的樹狀結構來確保無環路（Loop-free）拓撲。若發生鏈路故障或網路重新配置，所有網路流量都會暫停，直到生成樹演算法重新計算出允許的路徑。然而，在 EVPN 環境中，由於其內建的**水平分割（Split-horizon）**功能，STP 已不再是必要的。

### 注意事項與限制

* **跨 L3 延伸 L2**：當 L2 網域被 L3 網路架構分割，但需要將其「拉伸」（Stretched）過去時（例如為了舊有的 L2 應用程式或 ESF），此技術非常有用。
* **VTEP 角色**：每一台機櫃頂端交換器（ToR/Leaf）皆作為一個 VTEP，並承載其機櫃內的 VLAN（這些 VLAN 會對應到 VNI）。
* **VNI 配置**：若要延伸 L2 網域，必須在相關的 VTEP 上配置特定的 **VNI**。
* **不支援跨 VLAN 通訊**：此環境**不允許**跨 VLAN 的連通性。若需要不同 VNI 之間的路由，必須採用 L3 部署模型或在網路架構外部使用外部閘道（External Gateway）。

### 適合使用 L2 EVPN 的場景

* **跨機架子網路**：當你的子網路需要橫跨資料中心內的不同機架時。
* **防火牆作為閘道**：當架構定義所有跨 VLAN 流量必須經過防火牆時。由於 L3 閘道功能是由架構外部設計提供的，因此「橋接疊加網路」架構非常契合。
* **現代化轉型過渡期**：當你已有現成的乙太網路資料中心，並想引入 EVPN/VXLAN 時。由於橋接疊加模式非常基礎且簡單，是想要分階段或增量式現代化環境時的理想選擇。

### 為什麼要選 L2 EVPN？

之前研究的 **Spine-Leaf** 架構，雖然傾向將路由下放到 Leaf（L3 Fabric），但現實中常會遇到無法輕易更改 IP 的舊系統。這張圖表告訴我們，L2 EVPN 提供了一種「魚與熊掌兼得」的方法：底層是強大的 L3 路由（ECMP），但對伺服器來說，它們看起來就像接在同一個超大的 L2 交換器上，而且還順便解決了 STP 斷線收斂的夢魘。

## EVPN L3

擺脫 Layer 2 的局限性:

1. 頻寬浪費：傳統 STP 會為了防止環路而阻斷路徑，導致寶貴的頻寬無法被利用。
2. 擴充瓶頸：MLAG 的備援能力有限，且大型機框式設備在高可用性需求下顯得過於笨重且耗電。

### Routing Modeling

你可能需要在 Layer 2 網域之間，或是 VXLAN 隧道與外部世界之間進行通訊，為此你可以在網路中啟用 VXLAN 路由。

VXLAN 路由可以透過以下兩種架構之一來執行：

|比較項目|集中式路由 (Centralized)|分散式路由 (Distributed)|
|---|---|---|
|路由發生位置|邊界枝葉交換器 (Border Leaves)|存取層枝葉交換器 (Leaf Layer)|
|最適合流量|南北向流量（對外通訊）|東西向流量（伺服器對伺服器）|
|優點|配置集中，適合對外閘道設計|流量路徑最短化，減少核心負擔|
|缺點|可能導致東西向流量繞路（Hairpinning）|每一台 Leaf 交換器的硬體規格要求較高|

#### Centralized Routing

![Centralized IRB Example](https://docs.nvidia.com/networking-ethernet-software/images/guides/VXLAN-EVPN-design-guide/centralized.png)

上圖顯示了部署此模型的常見方式。邊界設備（Border Devices）位於資料中心網路架構的邊緣或邊界。這些設備同時充當進出網路架構之南北向流量的 VTEP。源自乙太網路連接終端系統的流量，會透過 Trunk（多 VLAN）或 Access Port（單一 VLAN）轉發至枝葉 VTEP 設備。VTEP 設備隨後將流量轉發至本地終端系統，或遠端 VTEP 設備上的終端系統。邊界設備上的整合路由與橋接 (IRB) 介面則負責在不同的乙太網路虛擬網路之間進行路由。

1. 核心機制：路由點集中化
    * 集中處理：所有的跨 VLAN (Inter-VXLAN) 路由功能都集中在「邊界設備」上，而不是散布在每一台 Leaf 交換器。
    * IRB 介面：邊界設備利用 IRB 技術，在 Layer 2 橋接與 Layer 3 路由之間建立聯繫，負責處理虛擬網路間的流量轉發。

2. 流量路徑特徵
    * 南北向優化：此架構特別適合進出資料中心（外部網路對伺服器）的流量。
    * 東西向繞路（Hairpinning）：若同一資料中心內、不同 VLAN 的兩台伺服器要通訊，流量必須先爬升到邊界設備進行路由後再折返，這就是所謂的「非最佳化路徑」。

3. 優缺點與適用場景
    * 優點：
        * 管理簡單，路由邏輯集中於少數設備。
        * 可降低對 Leaf 交換器硬體規格的要求（Leaf 僅需支援 L2 VXLAN）。

    * 缺點：
        * 邊界設備容易成為頻寬瓶頸（擴充性限制）。
        * 增加內部流量的延遲。

    * 適用場景：
        * 資料中心主要流量為南北向。
        * 現有 Leaf 設備不支援 L3 VXLAN 路由功能。

#### Distributed Routing

這是現代大規模資料中心為了優化伺服器間通訊效率而採用的主流架構。

1. 優化東西向流量 (East-West Optimization)
    * 就近轉發：路由點下放到 Leaf 層，流量不需要繞經遠端的邊界交換器，大幅降低了延遲並提升速度。
    * 效能提升：最適合處理資料中心內部頻繁的伺服器間通訊（如資料庫同步、微服務呼叫）。

2. 簡化骨幹層設計 (Spine Simplification)
    * 純 IP 轉發：Spine 交換器僅需扮演「底層 IP 路由」的角色，不需要理解內部的 VLAN 或橋接細節。
    * 架構乾淨：這種設計讓骨幹層更易於維護，且具備更強的擴展性。

3. IETF 標準模型
    * 根據需求，分散式路由可分為兩大流派：
        * 非對稱式 IRB (Asymmetric IRB)：在進入隧道時完成路由與橋接，但在離開時僅進行橋接。
        * 對稱式 IRB (Symmetric IRB)：在隧道的入口和出口交換器上都執行路由功能，通常被認為是大規模環境中擴展性更好的做法。

##### Symmetric IRB

![Symmetric IRB Example](https://docs.nvidia.com/networking-ethernet-software/images/guides/VXLAN-EVPN-design-guide/symmetric.png)

這是 EVPN 的預設路由模型。對稱式模型在入口 (Ingress) 與出口 (Egress) 枝葉交換器 (Leaf) 上同時執行路由與橋接功能。這使得雙向流量能在相同的 VNI 上傳輸，這也是「對稱」名稱的由來。此模型使用一種特殊的「轉運 VNI」(Transit VNI) 來處理所有路由後的 VXLAN 流量，稱為 L3VNI。所有需路由的流量會先被路由到 L3VNI，透過 L3 基礎設施進行隧道傳輸，最後在出口端路由離開 L3VNI 並橋接至目的地 VLAN。

1. 設計考量與優勢 (Points to consider)
    * 優異的擴展性：Leaf 交換器僅需承載位於其機櫃上的 VLAN/VNI 以及 L3VNI。
    * 簡化入口端負擔：入口 Leaf 不需要知道目的地的 VNI 資訊。
    * 多租戶支援 (Multitenancy)：每個 VRF 需要一個獨立的 L3VNI，所有參與該 VRF 的交換器都必須配置相同的 L3VNI，出口 Leaf 藉此識別該封包應屬於哪個 VRF 路由表。
    * 複雜度：由於需要在網路中配置額外的 VXLAN 隧道與 VLAN，設定上較為複雜。

2. 適用場景 (Scenarios)
    * 大規模 EVPN 部署：特別是 VLAN、子網路或 VNI 分散在資料中心各處的情況。
    * 混合路由環境：當網路架構中包含非 EVPN 路由（如預設路由、靜態路由或動態路由協定）時。
    * 通用性：除了需要集中式閘道的特殊需求外，幾乎適用於所有資料中心 EVPN 架構。

3. 技術效益 (Benefits)
    * L2 網域縮減：將 Layer 2 網域限制在一對 ToR 交換器內，降低廣播風暴風險。
    * 全 L3 匯聚層：匯聚層完全採 L3 設計，提升穩定性。
    * 高可用性 (HA)：提供路由擴展性與靈活的備援機制。
    * 監控容易：Overlay 流量路徑對稱，方便進行流量追蹤與監控。

##### Asymmetric IRB

![Asymmetric IRB Example](https://docs.nvidia.com/networking-ethernet-software/images/guides/VXLAN-EVPN-design-guide/asymmetric.png)

該圖片介紹了 **非對稱式 IRB (Asymmetric IRB)**，這是一種在 EVPN 環境中處理跨子網路路由的模型，主要應用於中小型規模或特定的集中式架構。

**定義與運作機制**

非對稱式模型在 VXLAN 隧道的**入口端 (Ingress)** 執行路由與橋接，但在**出口端 (Egress)** 僅執行橋接。這導致雙向的 VXLAN 流量在經過路由基礎設施時，會在兩個方向上使用不同的 VNI（始終是使用目的地的 VNI）。上圖顯示了一個非對稱配置範例中的橋接與路由流程。

1. 核心特性：非對稱的轉發邏輯
    * **入口端處理**：流量進入隧道前，交換器會先查路由表（L3）決定目的地子網路，再查 MAC 表（L2）進行封裝。
    * **出口端處理**：流量抵達目的端交換器後，僅需解封裝並直接進行二層橋接轉發。
    * **VNI 使用方式**：流量始終封裝在目的地所屬的 VNI 內。因此，去程與回程若分屬不同 VLAN，使用的 VNI 就會不同。


2. 適用場景 (Scenarios)
    * **集中式閘道部署**：這是部署集中式閘道時的首選模型。
    * **舊型硬體相容**：當網路中包含使用舊型專用積體電路 (ASIC) 的交換器，且該硬體不支援 L3 VXLAN 時，必須透過集中式閘道採用此模型。
    * **中小型資料中心**：適用於規模較小的環境。

3. 技術優勢與局限
    * **優點：配置直覺簡單**
        * 所有枝葉交換器（Leaves）都配置相同的 VLAN、子網路與 VNI。
        * 易於設定，且在排錯時不需要處理額外的轉運 VNI (L3VNI)。
    * **缺點：擴展性受限**
        * **必須同步配置**：每一台參與通訊的 Leaf 交換器都必須建立所有的 VLAN 與 VNI，這會消耗大量硬體資源（如 ARP 表與 MAC 表空間），因此不適合大規模環境。


為什麼它叫「非對稱」？

「非對稱」指的是路由發生的位置。在這種模式下，**入口 Leaf 交換器做了全部的工作**（路由+橋接），而出口 Leaf 交換器只是一個被動的橋接器。

這與看到的 **對稱式 IRB** 形成鮮明對比：

* **對稱式**：兩端都做路由，中間用一條「公共走廊」(L3VNI) 連結。
* **非對稱式**：入口端直接把封包送進「對方的房間」(Destination VNI)，所以出口端不需要再路由。

### Multi-tenancy and VRF

VRF 分割是用於在共享網路上將使用者和設備組織成群組，同時分離和隔離不同群組。網路上的路由設備會為每個群組建立並維護**獨立的虛擬路由轉發 (VRF) 表**。您可以在資料中心使用 VRF 來為多租戶環境承載隔離的流量。因為多個路由實例彼此獨立存在，它們的 IP 位址可以重疊而不會發生任何衝突，因此實現了多租戶。

在 EVPN 路由中，假設路由發生在 VRF 的上下文中。無論模型是對稱式還是非對稱式，都是如此。底層路由表 (underlay) 假設在預設或全域路由表中，而覆蓋路由表 (overlay) 則假設在 VRF 特定的路由表中。在不使用 VRF 的情況下，也可以實現非對稱路由，但如果端點必須與外部世界通訊，則 RT-5 通告必須在 VRF 的上下文中發生。此外，L3 VNI 在通告中被訊號傳遞。因此，為了保持路由模型的一致性，**建議在 EVPN 路由中始終使用 VRF**。

如下圖所示，伺服器被分組在一個 VRF 區段中，彼此之間可以通訊，但它們不能與另一個 VRF 區段中的使用者通訊。如果您想在不同 VRF 區段之間發送和接收流量，您必須設定**路由洩漏 (route leaking)** 或依賴外部閘道器。

**使用 VRF 實現多租戶**

![Multi-tenancy using a VRF](https://docs.nvidia.com/networking-ethernet-software/images/guides/VXLAN-EVPN-design-guide/multi-tenancy.png)

圖片顯示 Leaf 交換器上有多個 VRF 表（以不同顏色表示），每個 VRF 隔離一組伺服器。Spine 交換器上也有這些 VRF 表。

EVPN 如何利用 VRF 來實現多租戶（Multi-tenancy）隔離。

1. **什麼是 VRF？ (虛擬路由轉發)**

      * **比喻：** VRF 就像在一台實體路由器上，切分出多台**虛擬路由器**。
      * **功能：** 每台 VRF 都有自己**獨立的路由表**。
      * **目的：** 用於**隔離**不同租戶的 L3 網路。

2. **EVPN 多租戶的核心：VRF + L3 VNI**

      * 在 EVPN 架構中，**一個租戶 (Tenant) = 一個 VRF**。
      * 在**對稱式 IRB (Symmetric IRB)** 模型中（推薦的模型），這個 VRF 會被綁定到一個**專屬的 L3 VNI**。
      * 這意味著不同租戶（不同 VRF）的流量在 VXLAN 隧道中傳輸時，會帶著各自不同的 L3 VNI 標籤，從而在網路層面上被徹底隔離。

3. **隔離與互通**

      * **預設隔離：** 位於不同 VRF（例如 VRF Blue 和 VRF Green）中的伺服器，預設是**完全隔離的**，無法互相通訊，即使它們的 IP 位址重疊（例如都使用 `192.168.1.0/24`）也不會衝突。
      * **受控互通：** 如果需要讓兩個 VRF（租戶）之間通訊，必須明確設定 **「路由洩漏」 (Route Leaking)**，這通常是為了讓租戶能訪問共享服務（如 DNS、DHCP）。

4. **關鍵設定考量（Cumulus Linux）**
      * **Overlay vs. Underlay 分離：** 租戶的 VRF（Overlay 覆蓋網路）**必須**與「預設 VRF」(Default VRF) 分離，預設 VRF 用於運行實體網路（Underlay）。
      * **L3 VNI 限制：** 不能為「預設 VRF」設定 L3 VNI。
      * **VRF Loopback：** VRF 需要一個 Loopback 介面作為其在 L3 網路中的標識（例如用於 VTEP IP）。
      * **名稱限制：** VRF 名稱不能是 `mgmt`。
      * **數量限制：** Spectrum 1 晶片最多支援 255 個 VRF。

**VRF 是 EVPN 實現 L3 多租戶隔離的基石。每個租戶被放入一個獨立的 VRF 中，並與一個 L3 VNI 綁定，從而實現了路由層面的完全隔離。**

### Summarized Route Announcements

EVPN 路由優化，特別是在 MLAG（active-active）環境下。

1. **背景問題：**
    在 EVPN-MLAG 環境中，兩台 Leaf 交換器會共享一個虛擬的 **Anycast IP** 和 **Anycast MAC**（作為伺服器的預設閘道）。如果所有路由（L2 和 L3）都通告這個共享的 Anycast IP 作為下一跳，當其中一台 Leaf 故障時，遠端的 VTEP 可能仍然會將流量發送到這個 Anycast IP，導致流量被轉發到已故障的 Leaf 上而丟失（黑洞）。

2. **解決方案：「Advertise Primary IP address」功能**
    Cumulus Linux 預設啟用此功能，**區別對待** L2 路由 (Type-2) 和 L3 路由 (Type-5) 的通告：

3. **關鍵區別 (對照表)：**

| 路由類型 | 路由用途 | 下一跳 (Next Hop) IP | 路由器 MAC | 目的 |
| :--- | :--- | :--- | :--- | :--- |
| **Type-2** | **主機路由 (MAC/IP)**<br>(同子網路/L2 橋接) | **Anycast IP**<br>(MLAG 共享) | **Anycast MAC**<br>(MLAG 共享) | 處理 L2 流量和同子網路的閘道流量。 |
| **Type-5** | **IP 前綴路由 (IP Prefix)**<br>(跨子網路/L3 路由) | **System IP**<br>(VTEP 唯一的 Loopback IP) | **VTEP 唯一的 MAC** | gi確保 L3 路由流量被精確發送到一個**特定且健康的 VTEP** 上，避免流量在 MLAG 故障時被黑洞。 |

**總結：**

* **Type-2 路由（L2/同子網路）** 使用 **Anycast IP**，因為流量可以在 MLAG 對中的任一台 Leaf 上處理。
* **Type-5 路由（L3/跨子網路）** 則**必須**使用**唯一的 System IP( loopback IP address of the VTEP)**。這等於是告訴其他 VTEP：「如果你有 L3 路由流量要找我，請指名道姓地送到我這個『唯一』的 IP 位址」，這樣就避免了流量被誤送到已故障的 MLAG。

### Prefix-based Routing

EVPN **`type-2`**（MAC 和 IP）通告**不支援**通告匯總路由 (summarized) 或前綴路由 (prefix routes)（例如 /16 或 /24 路由）。這會影響解決方案的可擴展性。

如果部署了帶有邊緣設備 (edge devices) 的網路，邊緣設備通常只會向邊界設備 (border devices) 通告預設路由。在幾乎所有的部署中，Spine 和 Leaf 交換器都不會承載外部世界（例如網際網路）的完整路由表。它們只承載預設路由，將流量導向邊界設備，再由邊界設備轉發到邊緣設備。這個預設路由就是 `0.0.0.0/0`（IPv6 則是 `::/0`），它並非 /32 的主機路由。

為了支援此使用情境，一種新的路由類型 **`type-5` (RT-5)** 被引入。Type-5 路由（或稱前綴路由）主要用於路由到**資料中心 fabric 之外**的目的地。EVPN type-5 路由會攜帶 **L3 VNI** 和路由器的 MAC 位址，並遵循**對稱路由模型 (symmetric routing model)** 來路由到目的前綴。

**考量要點 (Points to consider)：**

* 當連接到 WAN 邊緣路由器以訪問資料中心外的目的地時，請指定**邊界 (border) 或出口 (exit) Leaf 交換器**來產生 `type-5` 路由。
* 在具有 Spectrum ASIC 的交換器上，集中式路由、對稱式路由和基於前綴的路由僅適用於 Spectrum-A1 及更高版本。
* 設定一個**租戶專屬的 VXLAN 介面**，並為該租戶指定 L3 VNI。此 VXLAN 介面是橋接器的一部分，且路由 MAC 位址會從在此介面上安裝的 VTEP 遠端學習。
* 設定一個對應於租戶專屬 VXLAN 介面的 **SVI (L3 介面)**。此 SVI 附加到租戶的 VRF。租戶的遠端前綴會透過此 SVI 學習。
* 指定 L3 VNI 到 VRF 的映射。此設定用於 BGP 控制平面。

**使用基於前綴路由的情境 (Scenarios for using prefix-based routing)：**

* 路由到**資料中心 fabric 之外**的目的地（例如網際網路或 WAN）。
* 將資料中心細分為多個 Pod (pods)，Pod 之間具有完整的主機移動性，但 Pod 之間僅交換前綴路由。
  * 使用 route-map 過濾並通告 EVPN type-5 路由
* 僅交換特定 VNI 的 EVPN 路由。
  * 使用 route-map 僅通告 VNI 1000 的 EVPN 路由
* Cumulus Linux 支援產生 EVPN **預設 `type-5` 路由**。預設 `type-5` 路由從邊界 (出口) Leaf 產生，並通告給 Pod 內的所有其他 Leaf。任何 Leaf 之後都會遵循此預設路由，將流量導向外部網路（或不同的 Pod）。
  * 範例顯示如何設定 `nv set vrf RED router bgp address-family ipv4-unicast route-export to-evpn default-route-origination on`

##### EVPN Type-5 路由 (IP 前綴路由)

EVPN L3 路由的關鍵，它解決了 EVPN Type-2 路由的根本限制。

1. **Type-2 路由的限制 (The Problem)：**
    * `Type-2` 路由（MAC/IP 路由）**只能**通告**主機路由**（Host Route），也就是 `/32` (IPv4) 或 `/128` (IPv6)。
    * **問題點：** 如果要連接外部網路（如網際網路），不可能將網際網路上的所有路由（數十萬條）都當作 `/32` 主機路由一條一條塞進 EVPN。這會**嚴重影響擴展性**。

2. **Type-5 路由的誕生 (The Solution)：**
    * `Type-5` 路由（IP 前綴路由）被專門設計用來通告 **L3 網段 (Prefix)**，例如 `192.168.0.0/16`、`/24` 路由，或最重要的**預設路由 `0.0.0.0/0`**。

3. **核心用途：連接「外部世界」**
    * `Type-5` 路由的主要工作是讓資料中心 (Fabric) 內部的 Leaf 交換器，能夠學習到**外部網路**的路由。
    * **最常見的情境 (預設路由)：**
        1. **邊界 Leaf (Border Leaf)** 連接到外部路由器 (WAN Router)。
        2. 邊界 Leaf 學習到一條 `0.0.0.0/0` 的預設路由。
        3. 邊界 Leaf 將這條 `0.0.0.0/0` 路由打包成 **EVPN Type-5 路由**，並透過 BGP 通告給 Fabric 內的所有其他 Leaf 交換器。
        4. 所有 Leaf 交換器收到後，就知道「任何未知的 IP 流量，都應透過 VXLAN 隧道丟給邊界 Leaf 處理」。

4. **運作模型：基於 L3 VNI 與對稱式 IRB**
    * Type-5 路由是純 L3 路由，它不包含 MAC 位址資訊。
    * 它在通告時會攜帶 **L3 VNI**，用來標識這條路由屬於**哪一個租戶 (VRF)**。
    * 它完全遵循我們之前討論過的**「對稱式 IRB (Symmetric IRB)」**模型來轉發流量。

**總結 Type-2 與 Type-5 的分工：**

* **EVPN Type-2：** 用於 **VNI 內部**的 L2 橋接和 L3 路由（通告 `/32` 主機 MAC/IP）。
* **EVPN Type-5：** 用於**連接 VNI 外部**（通告 `/24`, `0.0.0.0/0` 等 L3 前綴）。

## EVPN for BUM Traffic

EVPN 對於泛洪 (flooded) 封包的術語是 **BUM**，即**廣播 (Broadcast)**、**未知單播 (Unknown Unicast)** 和**未知多播 (Unknown Multicast)**。EVPN 提供了兩種方式來處理 BUM 封包的複製：**Ingress 複製（頭端複製）和多播 (Multicast)**。

Ingress 複製即頭端複製 (head-end replication)，其中 Ingress VTEP (入口 VTEP) 會將同一個封包傳送給每個遠端的 VTEP。在單播複製中，來源 VTEP 將同一個訊框傳送給所有其他遠端 VTEP。而在多播複製中，來源 VTEP 只需發送一次封包，底層網路（例如使用 PIM-SM）會將其交付給遠端的 VTEP 鄰居。這使得多播具有較低的開銷和更快的交付速度，但安全性較低。

#### Ingress 複製 / 頭端複製 (Ingress Replication / Head-end replication)

在 Ingress 複製中，Ingress NVE（入口 NVE）會發送封包的多個副本，虛擬網路中的每個 Egress NVE（出口 NVE）都會收到一個。

**此模型的優點：**

  * **保持底層網路 (underlay) 簡單。** 底層網路只需要提供 IP 單播 (unicast) 路由功能即可。
  * **易於設定。** 不需要額外的設定。複製列表是透過 BGP EVPN（攜帶 VNI 資訊的 `RT-3` 路由）自動建立的，無需進一步干預。
  * **解決方案穩健 (robust)**，因為 VTEP 的變動被顯著減少。

**此模型的缺點：**

  * 底層網路需要提供複製所需的頻寬，特別是在有大量 BUM 封包時。
  * 如果需要複製的 NVE 數量不多，且 BUM 流量很低，此方法運作良好。即使 NVE 數量較多，但 BUM 流量很低，此方法也運作得不錯。

**Cumulus Linux 預設在 EVPN 多重路徑 (multihoming) 中使用頭端複製 (Head End Replication)。**

#### 多播路由 (Multicast Routing)

使用多播，Ingress NVE 不需要為每個 Egress NVE 發送單獨的副本。最常見的模型是 PIM。PIM-SM 用於在 EVPN-MH 網路中進行優化的泛洪。

**此模型的優點：**

  * 能夠高效處理大量的 BUM 封包或眾所周知的大量多播流量。

**此模型的缺點：**

  * 管理上可能變得困難。在此模型中，除了單播路由支援外，底層網路還必須提供多播路由支援。
  * PIM 需要額外的協定（如 SDP）才能可靠部署。
  * 要確保每個虛擬網路只接收其自身的多播群組流量。這會導致需要擴展許多多播群組。您現在必須將所有虛擬網路映射到較小的多播群組中。這導致了複雜的 BUM 封包路由。
  * 將虛擬網路映射到多播群組會增加顯著的複雜性。您必須在**每一個 NVE** 上設定此映射。沒有簡單的方法能確保此設定在所有 NVE 上保持一致。

**下圖是 EVPN-PIM 用於 BUM 流量**
![](https://docs.nvidia.com/networking-ethernet-software/images/guides/VXLAN-EVPN-design-guide/pim.png)

圖片顯示 BUM 封包被封裝後，透過 Spine 交換器上的多播樹狀結構，被複製並分發到多個 Leaf 交換器。

### 重點整理：如何處理 BUM 流量

BUM 指的是**廣播 (Broadcast)**、**未知單播 (Unknown Unicast)** 和**未知多播 (Unknown Multicast)**。在傳統 L2 網路中，這些流量會被無腦泛洪 (flooding)。EVPN 提供了更智慧的處理方式。

EVPN 有三種處理 BUM 流量的模式：

##### 1. Ingress 複製 / 頭端複製 (Head-End Replication) - 預設

  * **運作方式：**
    1.  `Leaf 1` 收到一個 BUM 封包（例如 ARP 廣播）。
    2.  `Leaf 1` 查詢 EVPN BGP (`Type-3` 路由)，找出「還有誰也在此 VNI 中？」
    3.  `Leaf 1` 複製 (Replicate) 該封包，並透過 **IP 單播 (Unicast)** 方式，**一個一個**地發送給所有其他相關的 VTEP（例如 `Leaf 2`, `Leaf 3`, `Leaf 4`...）。
  * **優點：**
      * **架構簡單：** 底層網路 (Underlay) **只需要支援 IP 單播**即可，Spine 交換器非常單純。
      * **設定容易：** 無需額外協定，BGP 會自動處理一切。
  * **缺點：**
      * **效率低、耗資源：** 如果有 100 台 Leaf，`Leaf 1` 就必須自己複製 100 份封包，非常消耗其出口頻寬。
  * **適用情境：** **Cumulus Linux 預設使用此模式**。適用於 BUM 流量不高，或 VTEP 數量不多的絕大多數場景。

##### 2. 多播 (Multicast) 模式 (PIM)

  * **運作方式：**
    1.  `Leaf 1` 收到一個 BUM 封包。
    2.  `Leaf 1` **只發送一份**封包，並將其發送到一個**特定的多播群組 IP**。
    3.  底層網路 (Spine) 必須運行 PIM 等多播協定。Spine 會**在網路中**複製封包，並將其分發給所有加入了該多播群組的 Leaf 交換器。
  * **優點：**
      * **效率極高：** `Leaf 1` 只需發送一份，極大節省了 VTEP 的負擔。適合 BUM 流量巨大的環境（例如影像串流）。
  * **缺點：**
      * **架構極複雜：** 底層網路**必須**運行 PIM、SDP 等複雜的多播協定，管理和除錯非常困難。
      * **設定複雜：** 必須手動將 VNI 映射到多播群組，且**所有 VTEP 上的設定必須一致**。

##### 3. 丟棄 (Drop) BUM 流量 - 零信任模式

  * **運作方式：**
      * 直接停用 EVPN `Type-3`（BUM 路由）的通告和接收。
      * 交換器**不轉發**任何 BUM 流量。
  * **為什麼可行？**
      * EVPN 的設計理念是透過 **EVPN `Type-2` 路由（控制平面）** 來學習所有主機的 MAC 和 IP。
      * 在一個「完美」的 EVPN 網路中，**不應該存在**「未知單播」，因為所有主機資訊都已透過 BGP 得知。
      * ARP 廣播也應被「ARP 抑制」功能所處理。
  * **優點：**
      * **最安全：** 徹底杜絕 BUM 封包（DDoS 攻擊的常見來源）。
  * **適用情境：**
      * **自動化部署 (Orchestrator)：** 在像 OpenStack 這樣的雲平台環境中，所有 VM 的 IP/MAC 都是平台預先配置 (pre-provisioned) 好的，交換器無需透過泛洪來學習。
  * **缺點：**
      * 可能會導致「**靜默伺服器 (Silent Server)**」（即開機後從不主動發送封包，只等待他人連線）的通訊中斷。
