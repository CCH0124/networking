## 核心重點整理

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
        * **Leaf (葉交換器)：** 每個 Leaf 交換器都使用**唯一 (Unique) 的 AS 號碼**。
        * **Spine (骨幹交換器)：** 同一個資料中心 (Pod) 內的所有 Spine 交換器使用**共同 (Common) 的 AS 號碼**。
    * **理由：** 這種設計能實現最佳的 ECMP (Equal-cost multi-path) 負載平衡和快速收斂。

* **Route Distinguishers (RDs) - 路由辨識碼：**
    * **用途：** 在多租戶環境下（例如多個 VRF），確保不同租戶的相同 IP 路由（例如兩個客戶都用 192.168.1.0/24）在 BGP 中是**唯一**的。
    * **規劃：** RD 必須在**每個 VTEP 的每個 VRF 上都是唯一的**。通常會自動產生（例如使用 `[VTEP_IP]:[VNI]` 的格式）。

* **Route Targets (RTs) - 路由目標：**
    * **用途：** **這是 EVPN 的策略核心**。RT 決定了路由資訊的「匯入」和「匯出」策略。
    * **運作：**
        * 一個 VRF 在「匯出 (Export)」路由時會標記上 RT。
        * 另一個 VRF 只有在設定了「匯入 (Import)」相同 RT 時，才會接收（學習）這些路由。
    * **應用：** RTs 控制了哪些 VLANs/VRFs 可以跨資料中心互通。

* **Ethernet Segment Identifiers (ESIs) - 乙太網段辨識碼：**
    * **用途：** 專門用於 **Multi-homing**，即一台伺服器同時連接到**兩台不同的 Leaf 交換器**以實現備援。
    * **規劃：** 這兩台 Leaf 交換器必須針對該伺服器的連接埠設定**完全相同的 ESI**。這能讓 EVPN 知道這兩台交換器「共同」服務於同一個網段，從而實現流量負載平衡和故障時的快速切換。


沒有手動設定 RD 和 RT，Cumulus Linux 會自動產生它們：
- RD (路由辨識碼) 格式： `<vxlan-local-tunnelip>:<VNI>`
- RT (路由目標) 格式： `<AS>:<VNI>`

- RD (路由辨識碼) 格式： <vxlan-local-tunnelip>:<VNI>
- RT (路由目標) 格式： <AS>:<VNI>
