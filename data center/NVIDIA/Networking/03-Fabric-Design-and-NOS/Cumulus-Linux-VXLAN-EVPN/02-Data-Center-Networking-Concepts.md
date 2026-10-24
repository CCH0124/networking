## 資料中心網路概念 (Data Center Networking Concepts)

### 覆蓋網路 (Overlay)、底層網路 (Underlay) 與隧道 (Tunneling)

#### 使用覆蓋網路的好處 (Benefits of Using Overlay)

虛擬網路覆蓋相比非覆蓋網路的一些好處包括：

* **可擴展性 (Scalability)：** 虛擬網路覆蓋的擴展性要好得多。因為核心網路不需要儲存虛擬網路的轉發表狀態，它可以用較少的狀態運行。因此，單一實體網路可以支援更大數量的虛擬網路。
* **快速配置 (Rapid provisioning)：** 虛擬網路覆蓋允許快速配置虛擬網路。因為只需要配置受影響的邊緣，而不是整個網路，所以配置可以很迅速。
* **重用現有設備 (Reuse of existing equipment)：** 只有參與虛擬網路的邊緣節點才需要支援虛擬網路的語意。這使得覆蓋網路極具成本效益。如果想在不更新實體網路軟體的情況下嘗試更新虛擬網路軟體，只需要接觸邊緣節點，網路的其餘部分就可以正常運行。
* **不受地理位置限制 (Independence from geographical location)：** 只要端到端的 MTU 允許，覆蓋網路就可以跨網域傳輸端點流量，就像它們是直接連接在同一個網域一樣。這使得災難恢復和資料複製變得非常容易。由於大多數現代覆蓋技術都是純 IP 基礎的，並且整個網際網路都支援 IP，因此覆蓋網路允許在共享環境中互連不同的網域。

### 重點整理

以上解釋 Overlay (覆蓋網路) 和 Underlay (底層網路) 的核心概念，它們是網路虛擬化的基礎。

1.  **核心比喻：Overlay vs. Underlay**
    * **Underlay (底層網路)：** 就像是實體的**「公路系統」**（L3 網路，如 IP 網路）。它的唯一工作是確保從 A 點到 B 點的路是通的。它不關心路上跑的是什麼車。
    * **Overlay (覆蓋網路)：** 就像是建立在公路系統上的**「物流服務」**（L2 虛擬網路）。它使用 Underlay 的公路來運送自己的貨物（封包）。
    * **Tunneling (隧道)：** 就像是物流服務用的**「貨車」**（例如 VXLAN、GRE）。物流公司 (NVE) 把客戶的貨物（原始 L2 封包）裝進貨車（封裝隧道標頭），貨車在公路上行駛，到達目的地後，再把貨物卸下（解封裝標頭）。

2.  **關鍵角色：NVE (網路虛擬化邊緣)**
    * NVE 是隧道的**起點 (Ingress)** 和**終點 (Egress)**。
    * 它負責**封裝**（加上隧道標頭）和**解封裝**（移除隧道標頭）的工作。
    * 在 Leaf-Spine 架構中，**Leaf 交換器**通常就是 NVE。

3.  **使用 Overlay 的四大好處：**
    * **大規模擴展 (Scalability)：** 核心網路（Underlay）非常單純，不需要知道海量的虛擬網路狀態（例如 MAC 位址），因此可以支援極大規模的虛擬網路。
    * **快速部署 (Rapid provisioning)：** 當需要新增或修改虛擬網路時，**只需要在相關的邊緣 (NVE) 上設定**即可，不需要更動整個核心網路。
    * **節省成本 (Reuse of existing equipment)：** 可以在現有的 L3 實體網路上直接部署 Overlay，不需更換硬體設備。
    * **打破地理限制 (Independence from geographical location)：** 只要 IP 可達（例如透過網際網路），就可以將分散在不同地理位置的資料中心「拉」進同一個 L2 網路，非常適合災難備援 (DR)。
  
## 虛擬可擴展 LAN (Virtual Extensible LAN)

VXLAN 廣泛部署在許多 L3 資料中心，為特定應用的主機之間提供 L2 連接性。這是在 L3 框架內封裝 L2 訊框來完成的。VXLAN 是一種覆蓋網路 (overlay) 技術，可讓將 L2 連接延伸到底層的 L3 網路之上，方法是將乙太網路訊框封裝在 IP-UDP 封包中傳輸。
當主機發送屬於某個 **VNI** (VXLAN 網路識別碼) 的流量時（如下圖所示），該流量會被封裝在 UDP 和 IP 標頭中。然後，這個封包會被傳送到**底層網路 (underlay network)**，就像正常的 IP 流量一樣。當封包到達目的交換器時，封包會被**解封裝 (decapsulated)** 並傳送到目的伺服器。

**VXLAN 通訊**

![](https://docs.nvidia.com/networking-ethernet-software/images/guides/VXLAN-EVPN-design-guide/vxlan-communication.png)

上圖片顯示一個原始的乙太網路訊框，被依序加上 VXLAN 標頭、UDP 標頭、IP 標頭、外部乙太網路標頭，變成一個 VXLAN 封包，以便在 Spine 網路中傳輸

在 2 層式 Leaf-Spine 拓撲中，Leaf 交換器處理所有 VXLAN 功能，包括建立虛擬網路以及將 VLAN 映射到 VNI。Spine 交換器僅負責傳遞流量，並不知道 VNI 的存在。使用 VXLAN，擴展 L2 網路不會影響底層網路，反之亦然。

### 虛擬隧道端點 (Virtual Tunnel Endpoints)

如上圖 2 所示，VTEP 是 VXLAN 網路上的邊緣設備。它既可以是 VXLAN 隧道的起點（在此處封裝使用者資料訊框），也可以是 VXLAN 隧道的終點（在此處解封裝資料訊框）。

VTEP 可以是機架頂端 (top-of-rack) 交換器（用於裸機端點）或是伺服器虛擬交換器 (hypervisor)（用於虛擬化工作負載）。VTEP 需要一個 IP 位址（通常是 loopback 介面）作為來源/目的隧道 IP 位址。此 VTEP IP 位址必須在路由網域中被宣告，以便 VXLAN 隧道端點之間可以相互連線。可以在單一 VTEP 上擁有多個 VNI。VXLAN 為每個 VTEP 使用一個 IP 位址，這使得交換器能夠擁有一個支援 VXLAN 的晶片組。VXLAN 是一種**點對多點 (point-to-multipoint)** 隧道。多播 (Multicast) 或廣播 (Broadcast) 封包可以從單一 VTEP 發送到網路中的多個 VTEP。

**圖 3 - 資料中心內的 VXLAN 隧道與 VTEP**

![](https://docs.nvidia.com/networking-ethernet-software/images/guides/VXLAN-EVPN-design-guide/vxlan-tunnel.png)

圖片顯示 Leaf 交換器作為 VTEP，各自擁有 VTEP IP。它們之間透過 Spine 交換器建立 VXLAN 隧道來傳輸特定 VNI 的流量

### 使用 VXLAN 的好處 (Benefits of Using VXLAN)

VXLAN 是一種覆蓋網路技術，它使用封裝技術將 L2 覆蓋 VLAN 延伸到 L3 網路。L2 網路本身存在一些固有缺點：

* 因為 L2 依賴 STP (Spanning Tree Protocol)，其可擴展性、冗餘性（備援）和多路徑能力受到 STP 功能的限制。
* 使用 STP 會降低 L2 網路的規模和半徑，因為 L2 網段的特性和 STP 本身的限制。
* 由於這些特性，L2 廣播網域也定義了廣播風暴的**爆炸半徑 (blast radius)**。較大的 L2 網域（無論是否使用 STP）在廣播風暴後網路**收斂 (convergence)** 的速度也非常慢。
* 冗餘（備援）通常僅限於兩台設備（例如使用 MLAG）。

VXLAN 克服了這些缺陷，並允許網路營運商在 L3 路由架構上優化 L2。L2 覆蓋網路仍然可以實現，但需要控制平面（例如 EVPN）來實現收斂，EVPN 負責宣告 MAC 資訊，並利用 BGP 的可靠性來減少廣播和泛洪 (flooding)。
此外。這說明了 VXLAN (虛擬可擴展 LAN) 的核心概念，以及它為何能解決傳統 L2 網路的問題。

### 重點整理

1.  **什麼是 VXLAN？**
    * **定義：** 它是一種**覆蓋網路 (Overlay)** 技術。
    * **目的：** 讓 L2 網路（的VLAN）可以**跨越 L3 網路**（如 IP 網路）來延伸。
    * **比喻：** 就像在現有的 L3 公路系統（Underlay）上，蓋了一條虛擬的 L2 隧道（Overlay）。

2.  **VXLAN 如何運作？（封裝技術）**
    * 它將**「原始的 L2 乙太網路訊框」** 整個打包（封裝）成一個 IP 封包來傳送。
    * **封裝順序（由內到外）：**
        1.  **原始 L2 訊框** (Payload)
        2.  `+` **VXLAN 標頭** (包含 24-bit 的 **VNI** 識別碼)
        3.  `+` **UDP 標頭**
        4.  `+` **外部 IP 標頭** (來源/目的 IP = VTEP 的 IP)
        5.  `+` **外部 L2 標頭** (用於在 L3 網路中進行下一跳傳輸)

3.  **關鍵元件 (Key Components)：**
    * **VTEP (虛擬隧道端點)：**
        * **角色：** 隧道的**起點**與**終點**，負責**封裝** (Encapsulation) 和**解封裝** (Decapsulation)。
        * **實體：** 通常是 **Leaf 交換器** (用於裸機) 或伺服器上的**虛擬交換器** (用於 VM)。
        * **需求：** 每個 VTEP 都有一個 IP 位址（通常是 Loopback 介面），且 VTEP 之間必須在 L3 底層網路（Underlay）上 IP 可達。
    * **VNI (VXLAN 網路識別碼)：**
        * **作用：** 類似於 VLAN ID，用於**區分不同的 L2 虛擬網路**。
        * **巨大優勢：** VNI 是 **24 位元**，可提供高達 **1600 萬**個虛擬網路，遠超過 VLAN 4094 個的限制。

4.  **為什麼要用 VXLAN？（解決傳統 L2 的痛點）**
    * **痛點一 (STP 限制)：** 傳統 L2 網路依賴 **STP (Spanning Tree)**，STP 會**阻擋備援路徑**，導致頻寬浪費、網路擴展性差、收斂速度慢。
    * **VXLAN 解法：** VXLAN 運行在 L3 底層網路上。L3 網路使用路由協定 (如 OSPF, BGP)，可以**同時使用所有路徑 (ECMP)**，沒有路徑被阻擋，擴展性極佳。
    * **痛點二 (VLAN 數量限制)：** 傳統 VLAN ID 只有 12 位元 (4094 個)，在大型雲端或多租戶環境中完全不夠用。
    * **VXLAN 解法：** 24 位元的 VNI (1600 萬個) 提供了近乎無限的 L2 網段。
    * **痛點三 (廣播風暴)：** 傳統 L2 網域越大，廣播風暴的「爆炸半徑」就越大，影響範圍廣且難以收斂。
    * **VXLAN 解法：** VXLAN 本身不解決廣播問題，但它需要搭配一個**控制平面 (Control Plane)**，例如 **EVPN**，來智慧地學習 MAC 位址並抑制不必要的廣播和泛洪。

## 邊界閘道協定 (Border Gateway Protocol)

- BGP (邊界閘道協定) 是運行網際網路的協定。它管理封包如何在網路之間路由，以交換路由和可達性資訊。
- BGP 在**自治系統 (AS)** 之間直接傳遞封包，AS 是一組由單一管理員控制的路由器集合。每個 AS 都被分配一個唯一的自治系統編號 (**ASN**)。
- 當 BGP 在網路中通告路由時，它會包含 ASN。路由通告會攜帶路由所經過的 AS 列表，這稱為 AS 路徑 (AS path)。當路由器收到 BGP 路由時，會將此 AS 路徑儲存起來並轉發給下一個 BGP 鄰居。此列表用於避免路由迴圈 (loop)。

當在 Leaf 和 Spine 交換器之間使用 BGP 時，有兩種選擇：

1.  **iBGP (內部 BGP)：** 將所有交換器設定在同一個 ASN 中。
2.  **eBGP (外部 BGP)：** 每個 Leaf 交換器使用自己的 ASN。Spine 交換器可以使用一個共同的 ASN，或每個 Spine 都有自己的 ASN。

> 官方建議使用 eBGP，因為它允許在 Leaf 交換器上使用 32-bit ASN，在 Spine 交換器上使用 16-bit ASN。

### 自動 BGP (Auto BGP)

官方建議使用 Auto BGP，這樣就不必考慮要設定哪些 ASN。Auto BGP 可協助在資料中心建立最佳的 ASN 設定，以滿足的子網路和可擴展性需求。Auto BGP 使行為和設定標準化。

Auto BGP Leaf 和 Spine 關鍵字僅用於設定 ASN。設定檔和 `show` 指令仍會顯示實際的 ASN。

### BGP Unnumbered (無編號 BGP)

- BGP unnumbered 是一種規範，用於建立 BGP 鄰居關係，而無需在 L3 連線的介面上設定 IP 位址。這需要 IPv4 和 IPv6 位址配置來連接路由器，這會消耗大量 IPv4 和 IPv6 位址。在大型資料中心，設定所有介面的 IP 位址可能很耗時、容易出錯且浪費資源。
- BGP unnumbered 標準在 RFC 5549 中定義，*不需要在介面上預先配置 IPv4 位址*。相反地，它使用 `IPv6 link-local` 位址作為下一跳 (next hop) 來通告 IPv4 路由。BGP unnumbered 節省了在每個介面上設定 IPv4 位址的時間。

以下範例顯示了 leaf01 和 spine01 兩個交換器之間的基本 BGP unnumbered 設定，它們都是同一個 ASN (65100) 的一部分。leaf01 和 spine01 之間唯一的區別是 BGP unnumbered 設定在介面上，而路由過濾器 (route map) 是相同的。

**leaf01 設定：**

```
no set router bgp autonomous-system 65101
set router bgp router-id 10.10.10.1
set router bgp neighbor swp1 interface remote-as external
set vrf default router bgp address-family ipv4-unicast network 10.10.10.1/32
set vrf default router bgp address-family ipv4-unicast network 10.1.0.0/24
no config apply
```

**spine01 設定：**

```
no set router bgp autonomous-system 65100
set router bgp router-id 10.10.10.11
set router bgp neighbor swp51 interface remote-as external
set vrf default router bgp address-family ipv4-unicast network 10.10.10.101/32
no config apply
```

### 設計考量 (Design Considerations)

1.  在新的部署中使用 Auto BGP，以避免 AS 編號衝突。
2.  在新的部署中使用 2-byte ASN，因為 4-byte ASN 旨在用於資料中心部署。

### 路由區別碼 (Route Distinguisher - RD) 和 路由目標 (Route Target - RT)

##### Route Distinguisher
- 虛擬網路允許在另一個網路的位址空間內重複使用位址。換句話說，一個位址在虛擬網路中是唯一的，但在網路內可能不唯一。一個常見的例子是多個租戶都使用 192.168.0.0/24 子網路。這在 L3 網路中很常見，但在 L2 網路中也同樣如此。這就是為什麼需要 EVPN，它將乙太網路 VPN 的構建模塊從服務提供商擴展到資料中心。
- 當交換 EVPN 網路資訊時，BGP 會在每個位址前附加一個 8-byte 的 **RD (路由區別碼)**。RD 加上 IP 位址使得網路中原本可能重複的位址變成了全域唯一的路由。RD 的格式通常是 `x:x:x:x:x:x:y`。*這使得 EVPN 網域內可以跨越重疊的 IP 空間*。在 EVPN 網域中使用的 RD 必須是唯一的。

##### Route Target

**RT (路由目標)** 是 BGP 擴展社群 (extended community) 屬性，它攜帶有關路由的資訊。它們附加到 BGP 更新訊息中，以通告關於一個前綴的資訊，無論該資訊是通告還是作為編碼位元接收。路徑屬性攜帶資訊，例如前綴的下一跳 IP 位址、通告該前綴的來源，或用於決定將哪些路由安裝到本地虛擬網路路由表的資訊。

RT 用於提供有關路由來源以及希望使用此 RT 決定將哪些路由匯入本地虛擬網路路由表的資訊。**Export RT (匯出 RT)** 會附加到路由通告中。**Import RT (匯入 RT)** 會被檢查，以決定是否將路由安裝到本地 VRF。在典型的 VNI 設定中，必須同時設定 import 和 export RT。

### RD、RT 和 BGP 處理

RD 和 RT 共同識別一個封包到達時應放入哪個虛擬路由表。每個 BGP 實作都維護著兩種路由：

1.  BGP 路由表，用於通告給 BGP 鄰居。
2.  一個虛擬路由表 (VRF)，用於安裝路由到本地虛擬網路。

BGP 首先使用 RT `import` 選擇要安裝到虛擬網路路由表的特定候選路由。然後，BGP 使用 RD 將這些路由安裝到虛擬網路路由表中。當相同的位址(IP)通告給同一 VTEP 時，RD 會使該位址在 VRF 的上下文中變得唯一。

### 自動 RD 和 RT (Auto RD and RT)

RD 和 RT 會在 VLAN/VXLAN 和 VRF 上自動產生。當啟用 Free Range Routing (FRR) 時，交換器會為每個本地定義的 L2 VNI 自動產生一個 RD 和 RT，並且沒有明確的設定將其與 VNI 關聯。對於 L3 VNI（VRF），交換器會衍生 RD，並為此 VNI 匯入和匯出 RT。

### 重點整理
上述描述現代 L3 Leaf-Spine 架構中，如何使用 BGP 及其相關功能 (Auto BGP, BGP Unnumbered)，以及 EVPN 中最重要的兩個元件：RD 和 RT。

1.  **BGP (邊界閘道協定) 的角色：**

      * **用途：** 在現代資料中心，BGP 被用作**底層網路 (Underlay)** 的路由協定，取代了傳統的 OSPF 或 IS-IS。
      * **架構：** 在 Leaf-Spine 架構中，推薦使用 **eBGP**（外部 BGP），即每台交換器（或每層）都在不同的 ASN（自治系統編號）中。

2.  **簡化 BGP 設定的利器：**

      * **Auto BGP (自動 BGP)：**
          * **解決問題：** 省去手動規劃和設定每個交換器 ASN 的麻煩。
          * **功能：** 系統會自動產生 32-bit 的 ASN，簡化部署並避免 ASN 衝突。
      * **BGP Unnumbered (無編號 BGP)：**
          * **解決問題：** 傳統上，L3 網路中每對連接的介面都需要一對 IP 位址（例如 /30 或 /31），在大型網路中，這會消耗大量 IP 並使設定變得極為繁瑣。
          * **功能：** 依賴 **IPv6 Link-Local 位址**（自動在介面上產生）來建立 BGP 鄰居關係 (peering)。
          * **好處：** **完全不需要在 Leaf 和 Spine 之間的介面上設定任何 IP 位址**，大幅簡化 L3 底層網路的設定。

3.  **EVPN 的核心元件：RD 和 RT**
    這兩者是 EVPN (Overlay 控制平面) 的基石，用於在多租戶環境中管理路由。

      * **Route Distinguisher (RD - 路由區別碼)：**

          * **目的：** 讓路由**唯一**。
          * **解決問題：** 在多租戶環境中，兩個不同的客戶（租戶）可能都使用相同的 IP 網段（例如 `192.168.1.0/24`）。
          * **運作：** RD 是一個 8-byte 的值，會被**附加在 IP 路由前面**。
          * **範例：**
              * 租戶 A 的路由變成：`RD_A:192.168.1.1`
              * 租戶 B 的路由變成：`RD_B:192.168.1.1`
          * **結果：** 即使 IP 相同，這兩條路由在 BGP 網路中也會被視為**兩條完全不同的、全域唯一的路由**。

      * **Route Target (RT - 路由目標)：**

          * **目的：** 控制路由的**進出口策略(Policy)**。
          * **解決問題：** RD 只保證路由唯一，但它不管這條路由該被誰接收。RT 決定了哪些路由可以被哪些 VRF（虛擬 L3 網路）或 VNI（虛擬 L2 網路）所**接收**或**發送**。
          * **運作：** RT 是一種 BGP 擴展社群屬性（像是一個標籤）。
          * **類型：**
              * **Export RT (匯出)：** 當一個 VTEP (Leaf) 要通告一條路由時（例如 租戶 A 的路由），它會在這條路由上貼上 `Export RT_A` 的標籤。
              * **Import RT (匯入)：** 其他 VTEP 收到這條路由時，會檢查其 VRF/VNI 是否設定了要匯入 (Import) `RT_A` 這個標籤。如果匹配，BGP 就會將這條路由安裝到該租戶的路由表中。

      * **經典比喻：**
          * **RD (路由區別碼)** 就像是**「護照號碼」**。它確保即使兩個人同名（IP 位址相同），也能被唯一識別。
          * **RT (路由目標)** 就像是**「簽證」**。它決定了你（路由）可以進入（Import）哪些國家（VRF/VNI）。

4.  **自動化 (Auto RD and RT)：**
      * 為了進一步簡化 EVPN 設定，系統可以為 L2 VNI (VLAN) 和 L3 VNI (VRF) **自動產生**唯一的 RD 和 RT 值，無需手動設定。

## 乙太網路虛擬私人網路 (Ethernet Virtual Private Network - EVPN)

- EVPN 是 BGP 的一項功能，可為 MAC 和 IP 位址提供可擴展、可互通的端到端控制平面，以實現現代資料中心的網路虛擬化。EVPN 是一種基於標準的協定，可同時通告 L2 MAC 位址和 L3 IP 位址，從而實現最佳的路由和交換決策。此控制平面利用 **MP-BGP (多協定 BGP)** 來實現，並最大限度地減少了網路泛洪 (flooding)。
- EVPN 支援備援、負載分擔和多租戶。它透過 IP 或 IP/MPLS 骨幹網路提供多點橋接連接。EVPN 還提供了主機或虛擬機器 (VM) 移動時所需的快速收斂性。
- VXLAN 的出現，EVPN 被採用於資料中心的網路虛擬化。Cumulus Linux 在典型的 2 層 Clos（Leaf-Spine）拓撲中支援 EVPN 搭配 VXLAN 運行。
  - Leaf 交換器即為 VTEP
  - Leaf 和 Spine 之間使用 BGP 鄰居關係
  - Spine 交換器充當 BGP 路由轉發器，不保留 VTEP 狀態。
  - Leaf 交換器作為 VTEP 會交換 EVPN 資訊。
  - 當交換器接收到路由時，它們會根據 BGP 協定安裝轉發狀態，作為 BGP 下一跳。

如下圖所示，典型的資料中心家族使用 eBGP（外部 BGP）鄰居關係。

![](https://docs.nvidia.com/networking-ethernet-software/images/guides/VXLAN-EVPN-design-guide/eBGP.png)

* 為每個設備組（例如 Leaf 或 Spine）分配一個唯一的 ASN（自治系統編號）。
* 為每個 Leaf 分配一個 AS 編號。
* 為一組 Spine（連接到同一組 Leaf）分配一個共同的 AS 編號。
* （可選)為每個 Spine 分配一個唯一的 AS 編號。
* 在 Spine 和 Leaf 之間建立 BGP 鄰居關係。
* 使用 Loopback 介面進行 BGP 鄰居建立。
* 添加路由策略以禁止 Leaf 交換器之間的流量轉送。
* 啟用 load balance。

圖片顯示 Leaf 層和 Spine 層，Leaf 交換器有自己的 ASN (例如 65101, 65102...)，而 Spine 交換器有另一組 ASN (例如 65191, 65192...)。Leaf 和 Spine 之間建立 eBGP 關係，並透過 VXLAN 隧道傳輸流量。eBGP 承載了 Underlay 和 Overlay 的路由。

### 部署 EVPN 的好處

EVPN 是一個標準化的控制平面協定，提供的功能遠超過無控制器 (controller-less) 的 VXLAN。它具備規模、備援、快速收斂，並能減少跨資料中心的 BUM（廣播、未知單播、多播）流量。EVPN 部署可同時支援 L2 和 L3 服務。

* **簡易性 (Simplicity)：** EVPN 使用 BGP 路由協定。BGP 已經是資料中心事實上的標準路由協定。單一協定即可用於 L3 底層網路和 L2/L3 覆蓋網路。
* **無控制器的 VXLAN 隧道 (Controller-less VXLAN tunnels)：** 無需控制器。VTEP 透過 MP-BGP 進行對等點發現 (peer discovery)，並可選用 BGP 驗證機制。這避免了基於控制器或多播 (multicast) 進行擴展和管理的相關問題。
* **ARP 抑制 (ARP suppression)：** Cumulus Linux 透過允許本地 Leaf 交換器回應主機的 ARP 請求，來減少資料中心內的廣播流量。Cumulus Linux 預設啟用 ARP 抑制。
* **路由與主機移動性 (Route and host mobility)：** Cumulus 支援 BGP 路由過濾，這為網際網路和資料中心的路由策略提供了精細的控制。它支援新的 MAC 和 IP 以及移動性，為主機和 VM 的移動提供快速收斂。
* **快速收斂與主機移動性（主動-主動模式） (Fast convergence and host mobility (active-active mode))：** Cumulus EVPN 與 MLAG 和多重路徑 (multihoming) 整合，支援主動-主動 (active-active) 模式，提供雙重備援。
* **多租戶 (Multi-tenancy)：** EVPN 使用 RD (路由區別碼) 和 RT (路由目標) 在網路中隔離租戶。
* **VXLAN 路由 (VXLAN Routing)：** Cumulus 支援 VXLAN VNI（覆蓋網路）之間的 IP 路由，並在 Spectrum 硬體上支援。
* **供應商互通性 (Interoperability between vendors)：** MP-BGP 是 EVPN 控制平面的標準化協定。只要供應商遵循標準實作，就能確保 VXLAN 和 EVPN 的互通性。

### EVPN 路由類型 (Route Types - RTs)

下表顯示了不同的 EVPN 路由類型 (RTs)。要確保 EVPN 網路正常運行，所需的**最低要求是 RT-2、RT-3 和 RT-5**。其餘類型是可選的，取決於在網路中需要的功能。

| 路由類型 | 承載內容 | 主要用途 |
| :--- | :--- | :--- |
| **Type 1** | Ethernet Segment Auto Discovery | 用於多重路徑 (multihomed) 端點的資料中心。 |
| **Type 2** | MAC, VNI IP | 通告特定 MAC 位址和/或 IP 位址的可達性。 |
| **Type 3** | Inclusive Multicast Route | Required for Broadcast, Unknown Unicast and Multicast (BUM) traffic delivery across EVPN networks - provides information about P-tunnels that should be used to send the traffic.|
| **Type 4** | Ethernet Segment Route | 用於 BUM 流量的 Designated Forwarder (指定轉發器) 選舉。 |
| **Type 5** | IP Prefix, L3 VNI | 在 L3 虛擬網路中通告 IP 前綴路由（例如 /24）。 |
| **Type 6** | Multicast group membership info | 通告多播組成員資訊。 |
| **Type 7** | Multicast Membership Report Synch Route | IGMP 同步機制，允許 PE 設備為 ES 服務以同步其 IGMP 狀態 - 此路由用於協調 IGMP 成員報告。 |
| **Type 8** | Multicast Leave Synch Route | IGMP 同步機制，允許 PE 設備為 ES 服務以同步其 IGMP 狀態 - 此路由用於協調 IGMP 離開群組。 |
| **Type 9** | Per-region I-PMSI Auto Discovery | Auto-Discovery routes used to announce the tunnels that instantiate an Inclusive PMSI - to all PEs in the same VPN. |
| **Type 10** | S-PMSI Auto Discovery | Auto-Discovery routes used to announce the tunnels that instantiate a Selective PMSI - to some of the PEs in the same VPN. |
| **Type 11** | Leaf Auto Discovery | Used for explicit leaf tracking purposes. Triggered by I/S-PMSI A-D routes and targeted at triggering route’s (re-)advertiser. |

### 重點整理

上述解釋了 **EVPN (乙太網路虛擬私人網路)**，它是現代資料中心網路（特別是 VXLAN）的**控制平面 (Control Plane)**。

1.  **EVPN 的核心定位：VXLAN 的大腦**
    * **問題：** VXLAN 本身只定義了如何**封裝**流量（資料平面），但它**沒有**定義 VTEP (Leaf) 之間如何交換彼此的資訊（例如：VM 2 在哪台 Leaf 後面？）。
    * **EVPN 的解答：** EVPN 使用 **MP-BGP (多協定 BGP)** 作為控制平面，讓 VTEP 之間可以互相「通告」L2 和 L3 的可達性資訊（例如 MAC 和 IP 位址）。

2.  **為什麼用 BGP？ -> 簡單化**
    * 在 Leaf-Spine 架構中，**Underlay (底層網路)** 已經在使用 BGP (eBGP) 來交換 VTEP (Leaf) 的 IP 位址。
    * EVPN 只是**「擴展」**了 BGP 的功能，讓 BGP **同時**也能攜帶 **Overlay (覆蓋網路)** 的資訊（例如 VM 的 MAC 位址）。
    * **最終好處：** 只需維護 **BGP 這一種協定**，即可同時管理 L3 實體網路和 L2/L3 虛擬網路，極大簡化了網路架構。

3.  **EVPN 的關鍵好處 (Benefits)：**
    * **取代傳統控制平面：** 它取代了傳統 L2 網路的「動態 MAC 學習」和「廣播泛洪」，改用 BGP 精準通告。
    * **無控制器 (Controller-less)：** VTEP (Leaf) 之間透過 BGP **自動發現**彼此，不需要依賴中央控制器或複雜的多播設定。
    * **抑制 ARP/BUM 流量：** EVPN 最大的優點之一。
        * **ARP 抑制：** Leaf 會代理回應 ARP 請求，不需將 ARP 廣播到整個網路。
        * **BUM 減少：** 由於所有 MAC 和 IP 都透過 BGP 預先學習，未知單播 (Unknown Unicast) 流量會大幅減少。
    * **原生支援多租戶：** 利用 BGP 的 RD 和 RT 屬性來完美隔離不同租戶的 L2/L3 網路。
    * **主機移動性：** 當 VM 從一台 Leaf 遷移到另一台時，新的 Leaf 只需發送一條 BGP 更新，所有 VTEP 就能立即知道 VM 的新位置，收斂速度極快。
    * **高可用性 (Active-Active)：** 能與 MLAG 等技術結合，實現真正的雙活 (Active-Active) 備援。
    * **標準化：** EVPN 是 IETF 標準，可實現不同供應商設備之間的互通。

4.  **EVPN 的核心運作：路由類型 (Route Types)**
    EVPN 透過 BGP 定義了多種「路由類型」來通告不同資訊。其中最關鍵的是：
    * **Type 2 (MAC/IP 路由)：**
        * **用途：** 這是最核心的路由，用於**通告主機 (VM/伺服器) 的 MAC 和 IP 位址**。
        * **內容：** 「VNI 10000 中的 `MAC-A` 和 `IP-A`，位於 VTEP `1.1.1.1` 後面」。
        * **取代：** 它取代了傳統 L2 交換器的動態 MAC 學習。
    * **Type 5 (IP 前綴路由)：**
        * **用途：** 用於**通告 L3 路由 (IP 網段)**，實現 VNI 之間的路由（稱為 **VXLAN 路由**）。
        * **內容：** 「VNI 50000 (VRF Red) 中的 `192.168.10.0/24` 網段，位於 VTEP `1.1.1.1` 後面」。
        * **取代：** 它取代了傳統的 VRF-Lite + L3 介面。
    * **Type 3 (Inclusive Multicast 路由)：**
        * **用途：** 用於**處理 BUM (廣播/未知單播/多播) 流量**。
        * **內容：** 「VTEP `1.1.1.1` 也加入了 VNI 10000。如果你有該 VNI 的 BUM 流量，請複製一份給我」。
        * **取代：** 它取代了傳統的 L2 泛洪 (flooding)。


## 多機箱鏈路聚合 (Multi-Chassis Link Aggregation - MLAG)

MLAG 允許一對交換器在架構上表現為主動-主動 (active-active) 模式，*並被視為單一的邏輯設備*，以便進行下行鏈路（連接伺服器）的鏈路聚合。這對交換器中的兩台交換器透過一對鏈路或一組綁定鏈路（稱為 peer link）進行通訊。在一對 MLAG 交換器中，每台交換器都可以獨立轉發流量。MLAG 對中的交換器共享控制平面資訊，例如 MAC 位址表和 ARP 表。

**下圖是基本 MLAG 設定**

![](https://docs.nvidia.com/networking-ethernet-software/images/guides/VXLAN-EVPN-design-guide/mlag.png)

圖片顯示兩台 Leaf 交換器 (leaf01, leaf02) 透過 peer link 互連。一台伺服器 (server01) 透過 bond (鏈路聚合) 同時連接到 leaf01 和 leaf02。這兩台 Leaf 交換器在邏輯上被伺服器視為單一交換器。

VRR (虛擬路由器備援) 
  - 一對交換器能夠充當 BGP 和 Active-Active 伺服器鏈路的單一閘道
  - 主機能夠與備援交換器通訊。交換器以相同的方式回應來自伺服器的 ARP 請求。如果一台交換器故障，另一台會接管。

連接到 MLAG 設備的設備相信在其鏈路的另一端只有單一設備，並且只會轉發一份流量副本。VRR 和 VRRP 都允許在主動或待命 (standby) 設定中擁有多個網路設備。

### EVPN 多重路徑 (EVPN Multihoming - EVPN-MH)

EVPN-MH 是資料中心部署中 MLAG 協定的理想替代方案。
  - 它為伺服器提供了全主動 (all-active) 的 L2 連接性，而不需要 Leaf 交換器之間有 peer link。
  - EVPN-MH 使用標準協定取代了傳統的專有協定，實現了多供應商的互通性
  - 此協定簡化了資料中心部署，無需理解和使用專有協定。

EVPN-MH 使用 BGP-EVPN 的 **Type-1**、**Type-2** 和 **Type-4** 路由來發現乙太網路區段 (Ethernet Segments - ES) 並轉發流量。MAC 和鄰居資料庫透過這些路由在 ES 對等體之間進行同步。

> ES 是一組連接到多台 Leaf 交換器的交換器鏈路。EVPN-MH 消除了機架交換器之間對 peer link 或 inter-switch link 的需求。

**下圖是基本 EVPN-MH 設定**

![](https://docs.nvidia.com/networking-ethernet-software/images/guides/VXLAN-EVPN-design-guide/multihoming.png)

圖片顯示兩台 Leaf 交換器 (leaf01, leaf02) **沒有** peer link。一台伺服器 (server01) 透過 bond 同時連接到 leaf01 和 leaf02。

### 設計考量 (Design Considerations)

在 VXLAN 環境中，有時仍需要 MLAG 來實現備援主機連接。EVPN-MH 是一個機會，可以擺脫對 MLAG 的依賴。*MLAG 僅限於雙核心交換器，因為在超過兩台設備之間維持一致狀態非常困難*。相較之下，EVPN-MH 超越了 MLAG 的限制，消除了對 MLAG 所需的背對背 (back-to-back) leaf-to-spine 交換器連接的需求。

EVPN-MH 使用 EVPN 訊息來傳遞主機連接性，並動態建立到連接伺服器的主機的 L2 鄰接性。*MLAG 和 EVPN-MH 都使用 LACP 來通告邏輯上屬於同一條鏈路的介面，這稱為乙太網路區段 (ES)*。此外，多重路徑 (multihoming) 改善了網路供應商的鎖定 (lock-in) 問題，因為它依賴於標準協定。任何實現多重路徑 RFC 規範的供應商都可以成為乙太網路區段的一部分。

交換器會為每個乙太網路區段選出一個**指定轉發器 (Designated Forwarder - DF)**。
  - DF 轉發 BUM (廣播、未知單播、多播) 流量
  - DF 的選舉是基於 VLAN 和 VNI 進行的
  - 為了防止重複封包，只有 DF 會轉發 BUM 流量
  - 當使用全主動 (all-active) 模式時，具有最高 DF 優先權的 VTEP 將成為 DF。
  - EVPN VTEP 使 BGP 同時為 BGP 和 Active-Active 模式選擇 DF（兩者使用相同的 RT）。

**MLAG 的缺點：**

  * 更複雜（更多運作中的部件）
  * 供應商之間的互通性較差
  * 備援僅限於 2 台 Leaf 交換器
  * MLAG 不能與 EVPN-MH 一起設定

**EVPN-MH 的優點：**

  * 可以在任何地方使用 BGP。
  * 可以在多供應商環境中使用的標準化實作。
  * 它可以與超過 2 台 Leaf 交換器形成，並能為 Active-Active 連接建立超過兩個的多重路徑 server-to-leaf 連接，以實現備援和彈性。

### 重點整理

上述比較了兩種實現伺服器「Active-Active/all-active」連線到 Leaf 交換器的高可用性技術：**MLAG** (傳統) 和 **EVPN Multihoming** (現代)。

1.  **核心目標：**
    兩者的目標相同：允許一台伺服器使用 **LACP (鏈路聚合)**，將其網路卡**同時**連接到**兩台（或多台）不同的 Leaf 交換器**，並實現**全主動 (Active-Active)** 的備援和負載分擔。

2.  **MLAG (多機箱鏈路聚合) - 傳統方式**
      * **運作方式：**
          * 兩台 Leaf 交換器透過一條專用的 **Peer Link (對等鏈路)** 互連。
          * 它們透過 Peer Link **同步控制平面**（如 MAC 表、ARP 表）。
          * 這兩台交換器「欺騙」伺服器，讓伺服器以為自己只連接到**一台**邏輯交換器。
      * **缺點：**
          * **專有協定：** 互通性差，通常需要兩台 Leaf 來自**同一供應商**。
          * **複雜性高：** 需要 Peer Link，且控制平面同步複雜。
          * **擴展性差：** MLAG 標準**僅限於 2 台**交換器。
          * **不相容：** 不能與 EVPN-MH 同時使用。

3.  **EVPN Multihoming (EVPN 多重路徑) - 現代方式**

      * **運作方式：**
          * 這是一種**基於標準 (EVPN BGP)** 的方法，是 EVPN 的原生功能。
          * **不需要 Peer Link** 兩台 Leaf 交換器之間**無需**任何專用連線。
          * **控制平面：** 兩台 Leaf 交換器都連接到 Spine。它們透過 **BGP (EVPN Type-1、Type-2 和 Type-4 路由)** 來通告彼此連接了同一個**乙太網路區段 (ES)**。
          * **流量處理：**
              * **DF (指定轉發器)：** 會為每個 ES 選出一個 DF。只有 DF 負責轉發 BUM（廣播/未知）流量，以防止重複。
              * **已知流量：** 對於已知的單播流量，伺服器可以同時向**所有**連接的 Leaf 交換器發送和接收流量，實現真正的 Active-Active。
      * **優點：**
          * **標準化：** 使用 BGP (RFC 標準)，可實現**多供應商互通**。
          * **架構簡潔：** **移除了 Peer Link**，簡化了物理佈線和邏輯設定。
          * **擴展性強：** **不限於 2 台**交換器，理論上可以實現多台（例如 3 台或 4 台）Leaf 交換器的多重路徑。

**總結：EVPN Multihoming 是 MLAG 的現代、標準化、更具擴展性的替代方案。它利用 BGP 控制平面取代了傳統專有的 Peer Link 技術。**
