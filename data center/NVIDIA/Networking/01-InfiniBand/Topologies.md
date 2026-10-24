## Network Topologies
這段文字描述了高效能運算（HPC）中幾種常見的 InfiniBand 網路拓撲結構。為了讓你更直觀地理解這些技術名詞，以下是詳細的解釋：

### 1. 胖樹拓撲 (Fat Tree Topology)

這是目前 HPC 中心**最受歡迎且最常用**的架構。

* **概念：** 傳統的樹狀結構在向上層連接時頻寬會變窄（產生瓶頸），而「胖樹」則透過增加上層交換機與鏈路數量，確保越往樹根的方向，「樹幹」就越粗（頻寬越高）。
* **優點：** 提供**無阻塞（Non-blocking）**的通訊，這意味著任何一對節點都能以全速進行通訊，而不會影響其他節點。
* **應用：** 非常適合通訊模式較為密集的運算任務。

### 2. Dragonfly+ 拓撲 (Dragonfly+ Topology)

這是 NVIDIA 針對標準 Dragonfly 拓撲所提出的改良版本。

* **核心結構：** 它是由多個「群組（Groups）」組成的。
* **群組內：** 每個群組內部採用 2 層或 3 層的**胖樹（Fat Tree）**架構。
* **群組間：** 群組與群組之間採用**全連接（Full Graph）**，也就是說，每一對群組之間都有直接的鏈路相連。


* **優點：** 這種設計能以更少的纜線連接大量的節點，降低整體佈線成本，同時在大型系統中保持極高的擴充性。
### 3. 其他提到的拓撲結構

除了上述主流架構，文中還提到了幾種較為進階或特定用途的結構：

* **超立方體 (Hypercube)：** 一種多維度的立方體結構，每個節點與  個鄰居相連，路徑極短，但擴充到超大型規模時佈線非常複雜。
* **環面體 (3D/4D Tori)：** 將節點排列成網格，並將邊緣首尾相接形成環狀。適合具有地理鄰近性通訊特徵的科學模擬（如氣象模擬）。
* **Slim Fly：** 一種新興的拓撲，旨在以最低的網路層數（低延遲）與最少的交換機數量連接最多的節點。

### 總結對比

| 拓撲類型 | 核心特點 | 適合場景 |
| --- | --- | --- |
| **Fat Tree** | 層次化設計，頻寬充足 | 通用型 HPC，追求性能穩定 |
| **Dragonfly+** | 群組全連接，節省長距離纜線 | 超大規模超算中心，平衡成本與性能 |
| **Torus** | 鄰近節點連接 | 特定物理或氣象模擬任務 |

### Fat Tree Topology Examples

#### 胖樹拓撲 (Fat Tree Topology) 核心重點

* **地位與性能**：胖樹是 HPC 中應用最廣泛的拓撲結構。當配置為 **無阻塞 (Non-blocking)** 網路時，它能在規模擴大時提供最佳性能。
* **無阻塞定義**：指的是網路中沒有頻寬瓶頸，且沒有超量預訂 (Oversubscription) 的情況。
* **配置特性**：
* 通常在所有鏈路 (Links) 上使用相同的頻寬。
* 大多數情況下，所有的交換機 (Switches) 使用相同數量的連接埠 (Ports)。
* **連接比例**：為了達到無阻塞，交換機一半的連接埠會連向主機 (Compute Nodes)，另一半則連向上層的脊端交換機 (Spine Switches)。

##### 範例一：400 節點配置 (使用 40 埠交換機)

* **硬體**：使用 NVIDIA Quantum 200Gb/s 交換機，每台有 **40 個連接埠**。
* **交換機總數**：30 台（10 台 L2 層，20 台 L1 層）。
* **連接邏輯**：
* 每台 L1 交換機提供 **20 埠**連接主機，共可連接  個節點。
* 其餘 **20 埠**連向上層 L2，每台 L1 會以 2 條鏈路連接到每一台 L2。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv0000001MZZ&feoid=00N8Z000003jPco&refid=0EM8Z000003Euts)

##### 範例二：1024 節點配置 (使用 64 埠交換機)

* **硬體**：使用 NVIDIA Quantum-2 400Gb/s 交換機，每台有 **64 個連接埠**。
* **交換機總數**：48 台（16 台 L2 層，32 台 L1 層）。
* **連接邏輯**：
* 每台 L1 交換機提供 **32 埠**連接主機，共可連接  個節點。
* 其餘 **32 埠**連向上層 L2，每台 L1 會以 2 條鏈路連接到每一台 L2 ()。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv0000001MZZ&feoid=00N8Z000003jPco&refid=0EM8Z000003Euuq)


### Rules for Designing a Fat-Tree Cluster

* **平衡性與無阻塞 (Balance & Non-blocking)**：
* 無阻塞叢集必須保持平衡：每一台第二層（L2）交換機連接到每一台第一層（L1）交換機的鏈路數量必須完全相同。
* 設計時需在應用程式性能需求與網路硬體成本之間進行權衡。


* **避免信貸循環與死結 (Avoiding Credit Loops & Deadlocks)**：
* 正確建置的胖樹不應產生「先上、後下、再向上」的路由路徑。
* 如果出現此類路徑，會產生「信貸循環（Credit Loops）」，進而導致叢集內的流量死結。
* 在具備 L2 交換機的模組化交換機（如 NVIDIA CS8500）中，必須特別注意 L1 交換機的連接方式，因為這類設備內部本身就是一個胖樹結構。


### 2. 「鄰里 (Neighborhoods)」概念與限制

為了避免在大型三層結構中產生非法路由，必須將 L1 交換機劃分為不同的「鄰里（分組）」：

* **連接規則**：同一組（Neighborhood）內的所有 L1 交換機必須連接到相同的 L2 交換機，且禁止連接到其他組的 L2 交換機。
* **分組大小限制**：
* **400Gb/s (NDR InfiniBand)**：每 32 台 L1 交換機組成一個鄰里，連接至 32 台 L2 交換機。
* **200Gb/s (HDR InfiniBand)**：每 20 台 L1 交換機組成一個鄰里，連接至 20 台 L2 交換機。


#### **圖一：模組化交換機與信貸循環示例**

* **結構描述**：展示了一個包含 L1、L2、L3 三層的結構，頂端是一個「模組化交換機（Modular Switch）」。
* **錯誤路徑說明**：圖中標示了 X、Y、Z 三組 L1 交換機。
  * **正確路徑**：流量應遵循「向上至最高層再向下」的原則，例如 $X ->  up -> U -> L3 -> down -> V -> down -> Z$。
  * **錯誤路徑（紅色箭頭）**：展示了 $X -> up -> U -> down -> Y -> up -> V -> down -> Z$ 的路徑，這違反了「不能在下坡後再上坡」的規則，會直接導致**信貸循環（Credit Loop）**並引發死結。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv0000001MZZ&feoid=00N8Z000003jPco&refid=0EM8Z000003EuvK)

#### **圖二：HDR 拓撲的鄰里實作範例**

* **結構描述**：此圖演示了 HDR (200Gb/s) 環境下的分組實作。
* **細節描述**：
  * 底部 L1 交換機被劃分為 **Neighborhood 1 至 4**。
  * 每個鄰里包含 **20 台 L1 交換機**。
  * 各鄰里的 L1 僅連接到其對應的 L2 交換機群組（例如 Modular Switch 1 或 2），確保流量路徑清晰且符合「最短路徑」規則，避免產生「非上下（Not up down）」的非法路由。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv0000001MZZ&feoid=00N8Z000003jPco&refid=0EM8Z000003EuvU)

[mellanox | cabling-considerations-for-clos-5-networks#jive_content_id_Neighborhood_Groups](https://support.mellanox.com/s/article/cabling-considerations-for-clos-5-networks#jive_content_id_Neighborhood_Groups)

#### **圖三：平衡的胖樹拓撲 (Balanced Fat-Tree)**

* **結構描述**：展示了一個最基礎且健康的兩層胖樹。
* **細節描述**：
  * L2 層（頂部）與 L1 層（底部）之間呈現**全對稱連接**。
  * 每一台 L1 交換機（L1-1 到 L1-4）都以相同的鏈路數連接到 L2-1 與 L2-2。
  * 底部鏈路直接連向計算節點（Compute Nodes），確保頻寬均勻分布。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv0000001MZZ&feoid=00N8Z000003jPco&refid=0EM8Z000003EuwD)

## Dragonfly+ Topology

Dragonfly+ 是另一種高效能拓撲，強調群組間的高速互連。

### 1. 結構特點

* **群組互連**：每個脊端交換機 (Spine) 都必須連接到其他所有群組的對應脊端交換機。
* **群組內部**：每個群組內部本身就是一個 2 層或 3 層的胖樹結構。
* **等量鏈路**：任意兩個群組之間的鏈路數量必須完全相同。

### 2. 路由與死結預防

* 為了避免信貸循環，不同群組間的節點通訊僅允許兩種路由選項：
1. **1 跳 (1-hop)**：local routing within a group, global routing between groups, local routing within a group
2. **2 跳 (2-hop)**：local routing within a group, global routing between groups, global routing between groups, local routing within a group


* **虛擬通路 (VL)**：當封包進行第二跳路由時，必須使用獨立的 VL 以消除依賴關係並預防死結。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv0000001MZZ&feoid=00N8Z000003jPco&refid=0EM8Z000003EuwS)

* 展示了一個包含 **5 個群組** 的 DF+ 拓撲，採用基數 8 (radix 8) 的設計。
* 圖中顯示了群組間錯綜複雜但具備對稱性的全連接線路，每個群組內包含 L1 到 L4 的邊緣交換機與 S1, S2 的脊端交換機。

## Best Design Practices

### **1. 交換機組間的交錯連接 (Interleaved Connections)**

又稱為「鄰居連接 (Neighborhood connection)」。

* **原則：** 當連接一組交換機到另一組交換機時，最好讓 A 組的每一台交換機盡可能連接到 B 組中 **越多台不同的** 交換機越好。即使 B 組交換機連接到更上層的交換機，此原則依然適用。
* **原因：** 這種交錯方式可以減少拓撲的「平均直徑」（即任意兩台主機之間的平均距離/跳數），從而提升效能。
* **圖示說明：** 圖片顯示了從「非交錯」到「交錯」連接的轉變，讓連接線路更分散。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv0000001MZZ&feoid=00N8Z000003jPco&refid=0EM8Z000003Euwc)

### **關於 Dragonfly+ (DF+) 拓撲的說明**

* **架構：** DF+ 將交換機分組。組內採用 Fat-Tree（胖樹）拓撲連接，組與組之間則為稀疏連接 (Sparse connection)。
* **效能：** 除了特定流量模式（如組對組）外，DF+ 的效能接近類似參數下的無阻塞 (Non-blocking) Fat-Tree。但相比 Fat-Tree，DF+ 的組間連接距離較長。
* **路由算法：** 為了獲得最佳效能，DF+ 路由算法允許「非直連路由（Indirect routing / non-minimal path）」，這可能會產生 Credit Loop（信用循環）。解決方案是將每個虛擬通道 (VL) 映射到兩個 VL 來避免此問題。
* **三種規模：**
  * **小型：** 每個 L2 交換機都與其他每個群組相連（多條鏈路）。
  * **中型：** 每個 L2 交換機與其他每個群組以單條鏈路相連。
  * **大型：** 並非每個 L2 交換機都連接到每個群組。

#### **3層 Fat-Tree (FT) 的優化建議**

* **建議做法 (Quasi Fat-Tree)：** 建議每個 Leaf (葉) 交換機連接到 **4 台** Spine (脊) 交換機（每台 1 條鏈路）。
* **不建議做法：** 連接到 **2 台** Spine 交換機（每台 2 條鏈路）。
* **目的：** 這種優化的交叉連接 Fat-Tree 被稱為「準胖樹 (Quasi Fat-Tree)」。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv0000001MZZ&feoid=00N8Z000003jPco&refid=0EM8Z000003EuxB)

#### **特殊情況：用途分離 (Separation of Usage)**

* **原則：** 如果網路端口已知有不同的用途（例如：一部分用於運算 Compute，另一部分用於儲存 Storage），則上述的交錯原則可能不適用。
* **做法：** 應將互通的端口保持在同一組，不同用途的群組 **不應** 進行交錯連接。
* **圖示說明：** 圖中顯示 Storage（虛線）與 Compute（實線）的線路是分開處理的。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv0000001MZZ&feoid=00N8Z000003jPco&refid=0EM8Z000003EuxG)

### **2. 線纜排序 (Cable Ordering)**

* **原則：** 連接網絡中的交換機時，建議在整個網絡中保持 **相同的連接順序**。
* **好處：** 遵循此規則可以建立一個更容易理解、除錯 (Debug) 且能避免連接錯誤的網絡。
* 如果同一個單元在網絡中出現多次，其內部連接在所有實例中應保持一致。
* 當連接兩層交換機時，下層的第 n 個交換機應連接到上層每台交換機的同一個端口。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv0000001MZZ&feoid=00N8Z000003jPco&refid=0EM8Z000003EuxQ)


### **3. 連接分佈均勻 (Evenly Distributed Connections)**

* **原則：** 從 L1 交換機到 L2 交換機的連接必須在 Leaf 卡 (Leaf cards) 之間均勻分佈。
* **範例：**
  * **正確：** 1:1:1:1:1:1、2:2:2、3:3 或 6（完全均勻）
  * **錯誤：** 4:2、5:1（切勿混合不均勻的比例）。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv0000001MZZ&feoid=00N8Z000003jPco&refid=0EM8Z000003EuxV)

### **4. 有意義的命名 (Meaningful Naming)**

* **原則：** 每個節點都應分配有意義的名稱，名稱需能代表該交換機的 **層級 (Layer)** 及其在 Fabric 中的 **位置**。

### **5. 線纜長度 (Cable Length)**

* **原則：** InfiniBand 是一種依賴 Credits 機制的無損 (Lossless) 架構，因此線纜長度會影響效能。
* **建議：** L0 交換機（Top of Rack 或 End of Row）應盡可能靠近主機。

### **6. Rail 優化 (Rail - Optimization)**

* **情境：** 當使用內部具有交換機的主機（例如 NVIDIA DGX 100 等多端口伺服器）時建議使用。
* **原則：** 多端口節點上的每個端口應連接到 **不同的** 交換機。
* **好處：**
1. 最大化每個交換機跳數 (Switch hop) 可觸及的伺服器數量（即用更少的跳數到達更多伺服器）。
2. 透過啟用較少 Rails 的路徑來減少故障時的「爆炸半徑 (Blast Radius/影響範圍)」。


* **範例：** NVIDIA DGX SuperPOD 拓撲中即實作了 Rail 優化。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv0000001MZZ&feoid=00N8Z000003jPco&refid=0EM8Z000003EvNZ)

### 重點整理 (Key Takeaways)

這份文件是針對構建高效能、低延遲網路（特別是 InfiniBand 和 Dragonfly+ 架構）的工程指南，核心重點如下：

1. **最大化交錯連接 (Interleaving)：**
在一般設計中，盡量讓交換機連接到「越多不同的」上層交換機越好，以降低網路直徑和延遲。但若有特定用途區分（如儲存與運算分離），則需例外處理，保持物理隔離。
2. **Fat-Tree 的「準胖樹」優化：**
在 3 層架構中，傾向於「分散連接」（連 4 台 Spine 各 1 條線），優於「集中連接」（連 2 台 Spine 各 2 條線）。
3. **一致性與標準化 (Consistency)：**
* **排序：** 整個網路的接線順序要統一，方便維護除錯。
* **分佈：** 上下層交換機的連接必須「絕對均勻」（如 2:2:2），不可大小眼（如 4:2）。
* **命名：** 設備命名需反映其層級與位置。

4. **物理層考量：**
* **線長：** InfiniBand 對線長敏感，L0 交換機要貼近主機。
* **Rail 優化：** 針對高階 AI 伺服器（如 DGX），每個端口要分別連到不同交換機，以提升備援能力並縮小故障影響範圍。
