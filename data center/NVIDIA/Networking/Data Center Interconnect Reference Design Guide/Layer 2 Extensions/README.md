將 Layer 2 (第二層) 從一個資料中心擴展到另一個資料中心，通常是為了支援那些需要 Layer 2 鄰接 (adjacency) 的應用程式或系統。一些傳統應用程式需要 Layer 2 鄰接才能運作，儘管這類系統越來越少，但在企業環境中仍然存在。

在現代雲端運算時代，跨長距離擴展 Layer 2 網域已不再是典型的使用情境；請將此選項視為**最後的手段 (last resort)**，僅在沒有其他方法可以解決組織和技術問題，而只能跨地理上分離的資料中心擴展 Layer 2 時才考慮。

Layer 2 擴展是不受歡迎的 (undesirable)，原因如下：

* 它們會增加產生拓撲不對稱 (topological asymmetries) 的機會。
* 廣播和多播風暴 (Broadcast and multicast storms) 的風險會從一個資料中心擴展到另一個。
* 它們會增加 **MTTR** (平均修復時間)。
* 與 Layer 3 擴展相比，它們難以進行故障排除，因為 Layer 2 和 Layer 3 之間沒有明確的界限。
* 它們需要在所有 ToR (機櫃頂) 和 Leaf (葉) 交換器上部署 Layer 2 迴圈偵測系統 (loop detection system)。

透過限制 Layer 2 網路的範圍，可以減少問題發生時的潛在影響。如果無法避免 Layer 2 擴展，至關重要的是將擴展的 Layer 2 廣播網域保持在最小範圍，以限制 MAC 位址的通告 (advertisement) 和撤回 (withdrawals)。擴展 Layer 2 網域等同於合併多個廣播網域；它會建立一個地理上分離的大型廣播網域，該網域透過一個跨越長距離的複雜網路互連。

將 Layer 2 區段從一個資料中心擴展到另一個，涉及擴展用於個別 MAC 位址的 **EVPN type-2 (MAC 和 IP 位址) 路由**，以及用於 **BUM** (廣播、未知單播、多播) 流量的 **type-3 (Inclusive Multicast) 路由**。在具有多宿主 (multihoming) 的現代 EVPN 和 VXLAN 環境中，擴展 **type-1 (Ethernet Auto-Discovery) 路由**和 **type-4 (Ethernet Segment) 路由**也同樣重要。

**設定 (Configuration)**

![網路圖示顯示 DC-1 和 DC-2 兩個資料中心互連](https://docs.nvidia.com/networking-ethernet-software/images/guides/dci-reference-topology.png)

此範例設定使用 EVPN 和 VXLAN Layer 2 延伸技術，將 DC1 中的 VLAN ID 10 與 DC2 中的 VLAN ID 10 互連。路由目標 (route target) 匯入陳述式將兩個 RED VRF 互相連接，並在 RED VRF 內的 server01 和 server03 之間，以及 GREEN VRF 內的 server02 和 server04 之間提供連線能力。RED 和 GREEN VRF 之間無法互相通訊。server01 和 server03 與 server02 和 server04 位於同一個廣播網域中。從 Layer 2 的角度來看，它們是相鄰的主機。這些伺服器會將彼此的 MAC 位址包含在各自的 ARP 快取中。

### 內容重點整理

這份文件主要在說明 Layer 2 擴展（L2 Extension）的用途、重大缺點，以及在現代網路架構（如 EVPN/VXLAN）中如何實現它。

**1. 核心警告：L2 擴展應是「最後的手段」**
* **用途：** 主要是為了支援那些必須在 L2 層級相鄰（L2 adjacency）的**傳統應用程式**。
* **現代觀點：** 在雲端運算時代，這**不應是標準作法**。應優先考慮 Layer 3 網路設計。

**2. 為什麼 L2 擴展不受歡迎（主要缺點）**
* **擴大故障範圍：** 它將兩個獨立資料中心的廣播網域（Broadcast Domain）合併成一個。這意味著一個資料中心的廣播風暴會**直接衝擊到另一個資料中心**。
* **維運困難：**
    * **高 MTTR：** 故障排除變得更複雜，導致平均修復時間 (MTTR) 增加。
    * **界線模糊：** L2 和 L3 之間的界線不清，難以釐清問題根源。
* **架構風險：** 容易產生網路拓撲不對稱，且**必須**在所有 ToR/Leaf 交換器上啟用 L2 迴圈偵測（Loop Detection）。

**3. 如何降低風險**
* 如果非用不可，必須**盡可能縮小 L2 擴展的範圍**（例如，只讓特定 VLAN 延伸），以限制 MAC 位址通告的數量和潛在的衝擊。

**4. 現代技術實現 (EVPN/VXLAN)**
* 在 EVPN/VXLAN 環境中，L2 擴展是透過擴展特定的 EVPN 路由類型來達成的：
    * **Type-2 路由：** 用於傳遞主機的 MAC 和 IP 位址。
    * **Type-3 路由：** 用於處理 BUM（廣播、未知單播、多播）流量，這是 L2 廣播網域的關鍵。
    * **Type-1 / Type-4 路由：** 在有「多宿主」（multihoming，即一台伺服器連到多台交換器）的環境中，這兩者也必須擴展。

**5. 範例架構總結**

![網路圖示顯示 DC-1 和 DC-2 兩個資料中心互連](https://docs.nvidia.com/networking-ethernet-software/images/guides/dci-reference-topology.png)

* 上圖範例展示了如何使用 EVPN/VXLAN 將 DC1 的 `VLAN 10` 和 DC2 的 `VLAN 10` 連接起來。
* `RED VRF` 和 `GREEN VRF` 兩個虛擬網路是**各自獨立**的（例如 server01 和 server02 無法互通）。
* 但是，在同一個 VRF 內部（例如 `RED VRF`），跨資料中心的 server01 (DC1) 和 server03 (DC2) **位於同一個 L2 廣播網域**，它們會認為彼此是 L2 鄰居，並在 ARP 快取中持有對方的 MAC 位址。

