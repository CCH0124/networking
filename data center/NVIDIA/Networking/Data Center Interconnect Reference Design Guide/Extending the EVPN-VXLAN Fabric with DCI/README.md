## 核心重點整理
這份文件的主要目的是說明如何將 EVPN/VXLAN Fabric 從單一資料中心擴展到多個資料中心 (PODs)，並使用 EVPN/VXLAN 來互連它們。

由於 EVPN/VXLAN 依賴控制平面的 MAC 學習，因此擴展的關鍵在於**必須將 EVPN 信令（控制平面）的網域跨資料中心進行延伸**，或是將多個控制平面網域互連起來。

### 主要應用場景 (Use Cases)

本指南展示了多種最佳實踐配置，包括：

1.  **Layer 2 (L2) 延伸**：使用 EVPN Type-1、Type-2 和 Type-4 路由來實現跨資料中心的 L2 網路延伸。
2.  **Layer 3 (L3) 延伸**：使用 EVPN Type-5 路由來實現 L3 路由的延伸。
3.  **Inter-VLAN 路由**：採用 EVPN 對稱路由 (Symmetric Routing) 模型，在 Fabric 中實現分散式路由。
4.  **VRF 路由洩漏 (Route Leaking)**：提供 POD 之間通訊的路由洩漏範例。

### 關鍵技術與模型

1.  **對稱路由模型 (Symmetric Routing Model)**：
    * 在此模型中，每個 VTEP（VXLAN Tunnel Endpoint）同時執行橋接（L2）和路由（L3）功能。
    * 流量會先在 L2 VNI（VLAN）中橋接，然後路由到一個特殊的「L3 VNI」（也稱為 Transit VNI）。
    * 流量透過 L3 VNI 隧道傳輸到目標 VTEP，然後再從 L3 VNI 路由到目標 VLAN，最後橋接到目的地主機。
    * **優點**：Leaf 交換器只需要託管本地機架上的 VLAN 和 L3 VNI 即可，提高了效率。在多租戶環境中，每個 VRF 需要一個專屬的 L3 VNI。

2.  **EVPN Multihoming (EVPN-MH)**：
    * 這是基於標準的技術，用來取代傳統的 MLAG。
    * 它在 ToR (Top-of-Rack) 交換器層級為伺服器提供 L2 備援。

3.  **BUM 流量 (廣播、未知單播、多播) 處理**：
    * **Head-end-replication (HER)**：這是**推薦且預設**的 DCI 選項。它使用 Type-3 (IMET) 路由來自動發現遠端 PE，並透過 VXLAN 建立 BUM 流量通道。
    * **PIM-SM (Multicast)**：雖然也可以使用，但在 DCI 環境中（特別是跨越暗光纖或 DWDM 時），PIM 的設計非常複雜，且大多數第三方服務供應商不支援多播。因此**不推薦**。


本文件的核心在於**規劃 EVPN-VXLAN 的運作方式**。它強調了幾個在建構 DCI 時必須先決定的關鍵技術點：

#### 1. Underlay (底層網路) 與 Overlay (覆蓋網路) 的考量
* **概念：** EVPN-VXLAN 的最大優勢是將「Overlay 虛擬網路」與「Underlay 實體網路」解耦。
    * **Underlay：** 實體交換器和路由器組成的 IP 網路，只負責傳輸 IP 封包（即 VXLAN 隧道封包）。
    * **Overlay：** 虛擬網路（VLANs, VRFs），它們被封裝在 VXLAN 隧道中，對實體網路「透明」。
* **Underlay 路由協定：**
    * 需要一個路由協定來讓所有交換器（VTEPs）的 IP 相互連通。
    * **OSPF：** 適用於企業環境，較為單純。
    * **BGP (eBGP)：** **NVIDIA 推薦**用於大規模、可擴展的資料中心。它提供了更強的路由控制和策略靈活性，是大型網路的首選。

#### 2. BUM 流量的處理
* **BUM (Broadcast, Unknown Unicast, Multicast)：** 廣播、未知單播和多播流量，是 L2 網路（VLAN）的必然產物。在 VXLAN 中必須有方法處理它們。
* **主要方案：Ingress Replication (入口複製)**
    * **運作：** 當一台交換器（VTEP）收到 BUM 封包時，它會查詢 EVPN，找出所有對這個 VLAN 有興趣的其他 VTEP。然後，它會**透過 Unicast（單播）**，將 BUM 封包**複製並發送**給所有相關的 VTEP。
    * **優勢：** **極度推薦用於 DCI**。因為它不依賴 Underlay 實體網路支援 Multicast（多播），而**大多數第三方 DCI 服務商（電信商）根本不支援 Multicast 流量**。
    * **替代方案 (PIM)：** 使用 PIM (Protocol-Independent Multicast) 在 Underlay 建立多播樹。雖然效能更高，但設計極其複雜，且相容性差。

#### 3. EVPN-VXLAN 架構規劃 (最重要的部分)
在啟用 EVPN 之前，必須統一規劃以下幾個關鍵參數：

* **AS 編號 (Autonomous System Number) 規劃：**
    * 由於 EVPN 依賴 BGP 運作，AS 編號的分配至關重要。
    * **NVIDIA 推薦模型：**
      * **Leaf**：每個 Leaf 交換器應有**唯一**的 AS Number。
      * **Spine**：同一個 POD 內的所有 Spine 交換器應共用一個 AS Number（但每個 POD 的 Spine AS Number 必須不同）。
      * **Border Leaf**：同一個 POD 內的一對 (或多個) Border Leaf 應**共用**一個 AS Number（同樣，每個 POD 的 Border Leaf AS Number 必須不同）。
      * **注意**：在 Border Leaf 上使用共用的 AS Number 可以防止路由環路，但這也帶來一個限制：**這些 Border Leaf 將無法為使用 EVPN-MH 的主機提供服務**（因為 EVPN-MH 要求參與的 Leaf 具有不同的 AS Number）。
    * **理由：** 這種設計能實現最佳的 ECMP (Equal-cost multi-path) 負載平衡和快速收斂。

* **Route Distinguishers (RDs) - 路由辨識碼：**
    * **用途：** 在多租戶環境下（例如多個 VRF），確保不同租戶的相同 IP 路由（例如兩個客戶都用 192.168.1.0/24）在 BGP 中是**唯一**的。
    * **自動生成**：如果不安裝，Cumulus Linux 會自動產生 RD (格式：`<vxlan-local-tunnelip>:<VNI>`) 和 RT (格式：`<AS>:<VNI>`)。

* **Route Targets (RTs) - 路由目標：**
    * **用途：** **這是 EVPN 的策略核心**。RT 決定了路由資訊的「匯入」和「匯出」策略。
    * **運作：**
        * 一個 VRF 在「匯出 (Export)」路由時會標記上 RT。
        * 另一個 VRF 只有在設定了「匯入 (Import)」相同 RT 時，才會接收（學習）這些路由。
    * **應用：** RTs 控制了哪些 VLANs/VRFs 可以跨資料中心互通。
    * **設計建議**：**建議手動定義 Route Target (RT)**，並使用 `auto import/export` 功能。手動定義 RT 才能精確控制哪些 VPN 前綴（路由）可以被哪些 VRF 匯入或匯出，這對於 VPN 成員資格的管理至關重要。

* **Ethernet Segment Identifiers (ESIs) - 乙太網段辨識碼：**
    * **用途：** 專門用於 **Multi-homing**，即一台伺服器同時連接到**兩台不同的 Leaf 交換器**以實現備援。
    * **唯一性**：由於 ESI 相關的 EVPN Type-1 和 Type-4 路由會透過 DCI 在資料中心之間交換，因此 ESI **必須在整個 Fabric 中（跨所有資料中心）保持唯一**。
    * **配置**：ESI 可以自動產生，也可以手動配置。如果手動配置，ESI 必須以 `00` 開頭。
    * **重要性**：即使在純 L3 延伸的場景下，保持 ESI 在 Fabric 中的一致性和唯一性也是最佳實踐。
    * **規劃：** 這兩台 Leaf 交換器必須針對該伺服器的連接埠設定**完全相同的 ESI**。這能讓 EVPN 知道這兩台交換器「共同」服務於同一個網段，從而實現流量負載平衡和故障時的快速切換。


沒有手動設定 RD 和 RT，Cumulus Linux 會自動產生它們：
- RD (路由辨識碼) 格式： `<vxlan-local-tunnelip>:<VNI>`
- RT (路由目標) 格式： `<AS>:<VNI>`
