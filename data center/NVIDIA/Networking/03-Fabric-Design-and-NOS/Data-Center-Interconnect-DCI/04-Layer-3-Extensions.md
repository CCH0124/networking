Layer 3 擴展使用 EVPN 作為控制平面 (control plane)，並且類似於帶有 VXLAN 隧道的 Layer 3 VPN。Leaf 交換器 (leaf switches) 在 POD（效能優化資料中心）內部和跨 POD 之間建立全網狀 (full mesh) 的 VXLAN 隧道，而 POD 之間的路由交換 (routing exchange) 則是透過 **EVPN type-5 路由** 來進行。

在 POD 內部，有
* 用於 EVPN 多宿主 (multihoming) 的 type-1 和 type-4 路由
* 用於 MAC 位址、IP 位址和 MAC 路由的 type-2 路由
* 用於 BUM HER (廣播、未知單播、多播的頭端複製) 的 type-3 路由

**設定 (Configuration)**

![網路圖示顯示 DC-1 和 DC-2 兩個資料中心互連](https://docs.nvidia.com/networking-ethernet-software/images/guides/dci-reference-topology.png)

表格顯示 DC1 和 DC2 的 VRF、Layer 2 VNI 和 Layer 3 VNI 對應關係

<img width="512" height="402" alt="image" src="https://github.com/user-attachments/assets/b962f8d9-db80-4db6-a662-30eee9adb8ef" />


以下設定範例使用「下游 VNI (downstream VNI)」和「對稱路由 (symmetrical routing)」，將 DC1 中的 VRF RED 與 DC2 中的 VRF RED 連接起來。`route-target` 匯入陳述式將兩個 RED VRF **在 Layer 3 層級連接起來（用於交換前綴 (prefix)）**。

此設定提供了 RED VRF 內 server01 和 server03 之間，以及 GREEN VRF 內 server02 和 server04 之間的 **IP 連線能力 (IP connectivity)**，但 RED 和 GREEN VRF 彼此無法通訊。

**所有伺服器都位於不同的 IP 子網路 (IP subnets)；它們之間沒有 Layer 2 鄰接關係 (no layer 2 adjacency)。** 一台伺服器是透過其**預設閘道 (default gateway)** 與另一個 DC 中的對應伺服器通訊，這個閘道在 ARP 快取中是本地的 VRR (虛擬路由器備援) MAC 位址。

此範例展示了一個 Layer 3 互連設定，其中邊界 Leaf (border leafs) 會過濾 EVPN 前綴（**type-5 除外**）以分發到 DCI (資料中心互連) 鏈路。此設定確保 DCI **僅交換 type-5 前綴**，且遠端的 DC 不會接收和處理不需要的前綴類型。ESI (乙太網段識別碼) 和 MAC 位址對於每個本地 POD 是可見的，但**不會跨 POD 傳遞**。

### 內容重點整理

這份文件介紹了 Layer 3 擴展，這與上一份的 Layer 2 擴展是**完全不同的概念**，也是現代資料中心互連 (DCI) 的**首選方法**。

**1. 核心概念：在「路由層級」互連 (L3 VPN)**
* L3 擴展**不是**將 L2 廣播網域延伸，而是像 L3 VPN 一樣，只在資料中心之間交換 **IP 路由資訊**（IP prefixes）。
* 伺服器之間的通訊是透過**路由 (routing)** 進行的，而不是 L2 轉發。

**2. 與 L2 擴展的關鍵區別**
* **L2 擴展：**
    * Server01 (DC1) 和 Server03 (DC2) 在**同一個** IP 子網路 / 廣播網域。
    * 彼此是 L2 鄰居（可透過 ARP 直接找到對方 MAC）。
    * **風險：** DC1 的廣播風暴會**淹沒** DC2。
* **L3 擴展 (本文)：**
    * Server01 (DC1) 和 Server03 (DC2) 在**不同**的 IP 子網路。
    * 彼此**沒有** L2 鄰接關係。
    * 一台伺服器必須將流量傳送至其**預設閘道 (Gateway)**，由閘道負責將流量路由到另一個資料中心。
    * **優勢：** **L2 故障域被完全隔離**。DC1 的廣播風暴**不會**影響 DC2。

**3. 實現的關鍵技術 (EVPN)**
* **EVPN Type-5 路由：** 這是 L3 擴展的核心。它被用來在資料中心（POD 之間）**通告 IP 前綴 (路由)**。
* **邊界過濾 (Border Filtering)：** 邊界 Leaf 交換器被設定為**只允許 Type-5 路由**通過 DCI 鏈路。
* **資訊本地化：** L2 相關資訊（如主機 MAC 位址、ESI 等）**不會**被傳送到遠端的資料中心。這大幅減少了網路的複雜性和需要同步的狀態資訊。

**4. 架構總結**
* 表格顯示 DC1 和 DC2 的 L2 VNI 是**不同**的（例如 RED VRF 中，DC1 是 10，DC2 是 1010），證實了 L2 網域是各自獨立的。
* L3 VNI 則是用於在 VXLAN 隧道中承載 L3 路由流量。
* 這是一種更健壯 (robust)、更具擴展性且更安全的資料中心互連方式，它避免了 L2 擴展的所有缺點。
\對比了 L2 擴展（不推薦，高風險）和 L3 擴展（推薦，現代作法）的架構。

您還有其他文件需要我協助翻譯或整理嗎？
