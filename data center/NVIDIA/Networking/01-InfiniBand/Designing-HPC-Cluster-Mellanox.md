# Designing an HPC Cluster with Mellanox InfiniBand Solutions
高效能運算（High-performance computing, HPC）涵蓋透過平行處理進行的高階運算，能加速執行高度運算密集型的任務，例如氣候研究、分子建模、物理模擬、密碼分析、地球物理建模、汽車與航太設計、金融建模、資料探勘等。高效能模擬需要極高效率的運算平台。特定模擬任務的執行時間取決於諸多因素，例如 CPU/GPU 核心數量與其使用率，以及互連架構（interconnect）的效能、效率與可擴充性。高效率的 HPC 系統需要數千個多處理器節點之間的高頻寬、低延遲連線，以及高速儲存系統。

本參考設計說明了如何使用 Mellanox InfiniBand 互連解決方案來設計 HPC 叢集。

## Network Topologies

InfiniBand 網路架構有幾種常見的拓撲結構（topologies）。以下列出其中幾種：

* Fat tree（胖樹）：一種多根樹狀結構（multi-root tree），這是最廣泛使用的拓撲。
* 2D mesh（二維網格）：每個節點連接到其他四個節點，分別位於 X 軸與 Y 軸的正向與負向。
* 3D mesh（三維網格）：每個節點連接到其他六個節點，分別位於 X 軸、Y 軸與 Z 軸的正向與負向。
* 2D/3D torus（二維/三維環狀拓撲）：將 2D 或 3D 網格的 X、Y、Z 軸邊界端點「環繞閉合（wrapped around）」並連接回第一個節點。

以及其他拓撲結構。

## 胖樹拓撲（Fat Tree Topology）

HPC 叢集中最廣泛使用的拓撲是胖樹拓撲（fat-tree topology）。當配置為無阻塞網路（non-blocking network）時，此拓撲通常能夠在大規模部署下發揮最佳效能。在可以容忍網路超額配比（over-subscription）的情況下，叢集也可以配置為有阻塞架構（blocking configuration）。胖樹叢集通常在所有鏈路上使用相同的頻寬，且多數情況下所有交換器皆採用相同數量的連接埠。

以下為使用 36 埠交換器、由 324 個節點組成的胖樹拓撲範例。

請注意下列幾點：

* Spine 交換器層由 9 台標記為 L2（Layer 2）的交換器組成，下層則有 18 台標記為 L1（Layer 1）的交換器，總計為 27 台交換器。
* 每台 L1 交換器可引出 18 條鏈路連接至主機，這使得系統能以無阻塞方式連接 324（18 × 18）個潛在節點。
* 「無阻塞配比」意味著一半的連接埠連接到主機，而另一半的連接埠則連接到 Spine 交換器，在此範例中即為 18 個連接埠。
* 每台 L1 交換器將使用 2 個連接埠連接至每台 L2 交換器（9 × 2 = 18）。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnNu&feoid=00N8Z000003jPco&refid=0EM8Z000003DSWY)

* 圖中
    * 頂層：9 台 36 埠交換器 L2-1 至 L2-9；
    * 下層：18 台 36 埠交換器 L1-1 至 L1-18；
    * 每台 L1 下方皆有 18 條鏈路連接至運算節點（Compute Nodes）；
    * 粗黑線代表 2 條 4X 上行鏈路（2 x 4X Uplinks），細藍線代表 1 條 4X 上行鏈路（1 x 4X Uplinks））

### 總結

* **主流優勢與無阻塞特性**：Fat Tree 是 HPC 的主流架構；採 1:1（無阻塞）配置時可確保任意節點對傳皆達全頻寬，亦可依成本彈性調整為有阻塞（超額配比）配置。

* **兩層式架構規模（以 36 埠交換器為例）**：
    * **交換器總數**：27 台（18 台 L1 + 9 台 L2/Spine）。
    * **支援節點數**：最多可支援 324 個運算節點（18 台 L1 × 每台 18 個下行埠）。
* **埠位對稱分配原則（1:1 Non-blocking）**：每台 36 埠的 L1 交換器將 18 埠留給下行節點，其餘 18 埠做為上行鏈路（Uplinks）。
* **均勻網狀連接**：每台 L1 交換器向上平均分散連接至 9 台 L2 交換器，各分配 2 條鏈路（18 條上行埠 ÷ 9 台 L2 = 2 條鏈路/台），確保負載平衡與多路徑備援。

## 胖樹叢集設計規則（Rules for Designing the Fat-Tree Cluster）

建置胖樹叢集時，必須遵守以下規則：

* **無阻塞叢集必須保持平衡（Balanced）**。每一台 Layer-2（L2）交換器連接到每一台 Layer-1（L1）交換器的鏈路數量必須相同。是否能夠採用超額配比（over-subscription），取決於 HPC 應用程式本身的特性與網路需求。
* **若 L2 交換器為 Director 交換器**（即內部具備 Leaf 與 Spine 板卡的機箱型交換器），所有連向該 L2 交換器的 L1 鏈路必須**均勻分佈（evenly distributed）在各張 Leaf 卡之間**。例如，若 L1 與 L2 交換器之間有 6 條連線，則分配到 Leaf 卡的比例可以配置為 1:1:1:1:1:1、2:2:2、3:3 或 6。絕對不能採用混合分配，例如 4:2 或 5:1。
* **切勿建立必須「往上傳輸、折返回下、再往上傳輸」的路由路徑**。這會產生所謂的**信用循環（credit loops）**，並可能在叢集中導致流量死結（traffic deadlocks）。一般而言，在實體架構上無法完全消除循環；任何由多台 Director 搭配邊緣交換器組成的胖樹架構都存在實體環路，必須藉由使用如 **Up/Down（上/下）路由演算法**來避免信用循環。
* **盡量維持在 L1 使用 36 埠交換器、在 L2 使用 Director 等級的交換器**。若無法維持此一規格架構，請諮詢 Mellanox 技術代表，以確保所設計的叢集不會產生信用循環。


如需在設計胖樹叢集時取得協助，[Mellanox InfiniBand Cluster Configurator](http://www.mellanox.com/clusterconfig) 是一套線上叢集配置工具，提供彈性的叢集規模與配置選項。

以下為平衡型胖樹拓撲（Balanced Fat-Tree topology）的範例：

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnNu&feoid=00N8Z000003jPco&refid=0EM8Z000003DSWi)

* 圖中：
    * 頂層：2 台 L2 交換器（L2-1 與 L2-2）；
    * 下層：4 台 L1 交換器（L1-1、L1-2、L1-3、L1-4）；
    * 每台 L1 交換器皆以對稱數量的上行鏈路均勻連接至 L2-1 與 L2-2，下方各自接出多條鏈路連接至運算節點（To Compute Nodes）

### 總結

* **對稱平衡原則**：無阻塞胖樹必須確保每台 L2 與每台 L1 交換器之間的連線數完全一致，以防止局部頻寬瓶頸。
* **機箱板卡均勻分配**：當 L2 採用機箱型 Director 時，通往 L2 的鏈路必須對稱平分到各 Leaf 板卡（如 1:1:1:1:1:1 或 2:2:2），嚴禁非對稱配置（如 4:2）。
* **嚴禁 Up-Down-Up 路由以防死結**：網路路徑若出現先向上、向下又往上的折返走法，會引發 Credit Loops（信用循環）進而造成網路死結；必須透過 Up/Down 等路由演算法強制路徑方向性。
* **標準化硬體配置建議**：建議架構保持 L1 採用 36 埠盒式交換器、L2 採用 Director 機箱型交換器，若有特殊拓撲變化需經過官方驗證以確保無死結風險。

## 小型叢集的阻塞架構情境（Blocking Scenarios for Small Scale Clusters）

在某些情況下，叢集的規模所要求的終端連接埠數量，可能剛好些微超過「分層」胖樹（"tiered" fat-tree）所能提供的最大無阻塞連接埠上限。

舉例來說，若叢集僅需要 36 個連接埠，使用單台 36 埠交換器作為基本單元即可實現。一旦需求超過 36 埠，就必須建置雙層（2-level / tier）的胖樹架構。例如，如果需要 72 個連接埠，若要實現完全無阻塞（full non-blocking）的拓撲，總共需要 6 台 36 埠交換器。在這種配置下，網路成本並不會隨著連接埠數量線性增長，而是會顯著飆升。同樣的問題在雙層完全無阻塞網路突破 648 個連接埠的臨界值時也會出現。設計大型叢集需要審慎的網路規劃。然而，對於小型或中型系統，可以考慮採用有阻塞網路（blocking network），甚至是簡單的網格結構（meshes）。

以 48 個連接埠的基本案例為例。這個叢集可以用兩台 36 埠交換器來建置，其阻塞比（blocking ratio）為 1:2。這意味著在某些來源與目的地的通訊配對下，一條交換器對交換器（switch-switch）的鏈路需要同時承載來自兩個通訊節點配對的流量。但相對地，此叢集現在僅需使用兩台交換器即可完成建置，而不需添購更多設備。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnNu&feoid=00N8Z000003jPco&refid=0EM8Z000003DSWn)

* 圖中
    * 兩台 36 埠交換器之間以 12 條鏈路（12x links）相互連接；
    * 每台交換器各自向下接出 24 個連接埠（24-ports）供節點使用）

#### Example

要實現一個 **72 埠的 2 層完全無阻塞（Full Non-Blocking, 1:1 配比）胖樹拓撲**，這 6 台 36 埠交換器的計算邏輯與架構如下：

1. 無阻塞（Non-Blocking）的基本原則

    在 Fat-Tree 架構中，要達到 1:1 完全無阻塞：

    * 每台 **Leaf（L1）交換器** 的連接埠必須**對半平分**：
    * **一半的連接埠（Downlinks / 下行）**：連接運算主機（Compute Nodes）。
    * **一半的連接埠（Uplinks / 上行）**：連接上層的 Spine（L2）交換器。

    因為使用的是 **36 埠交換器**：

    * 每台 L1 交換器有：
        * $36 \div 2 = \mathbf{18\text{ 埠}}$ 連接主機（下行）。
        * $36 \div 2 = \mathbf{18\text{ 埠}}$ 連接上層 Spine（上行）。

2. 計算所需的 L1（Leaf）交換器數量

    目標是提供 **72 個主機連接埠**：

    * 每一台 L1 只能提供 18 個主機埠。
    * 所需的 L1 交換器數量：

    $$\text{L1 數量} = \frac{72}{18} = \mathbf{4\text{ 台}}$$

    這 4 台 L1 交換器（L1-1, L1-2, L1-3, L1-4）總共提供了 $4 \times 18 = 72$ 個終端主機連接埠。

3. 計算所需的 L2（Spine）交換器數量

    這 4 台 L1 交換器總共會向上產生：

    $$\text{總上行鏈路數} = 4\text{ 台} \times 18\text{ 條/台} = \mathbf{72\text{ 條上行鏈路}}$$

    這些上行鏈路必須全部連接到 L2（Spine）交換器：

    * 每台 L2 交換器也是 **36 埠**，且 L2 交換器不需要再往上連，所有 36 個連接埠全部用來往下連接 L1。
    * 為了容納這 72 條來自 L1 的上行鏈路，所需 L2 交換器數量為：

    $$\text{L2 數量} = \frac{72\text{ 條鏈路}}{36\text{ 埠/台}} = \mathbf{2\text{ 台}}$$

4. 總交換器數量與連線驗證

    * **L1 交換器**：4 台
    * **L2 交換器**：2 台
    * **總共交換器數量**：$4 + 2 = \mathbf{6\text{ 台}}$

**連線對稱性驗證：**

* 總共有 2 台 L2（Spine 1, Spine 2）。
* 每台 L1 交換器有 18 條上行鏈路，平均分給 2 台 L2：

$$18 \div 2 = 9\text{ 條連線}$$
    * 每台 L1 連接 9 條線到 Spine 1。
    * 每台 L1 連接 9 條線到 Spine 2。

* 每台 L2（36 埠）剛好接滿 4 台 L1 的連線：$4\text{ 台 L1} \times 9\text{ 條} = 36\text{ 埠}$。
* 全網完全對稱、無任何單點頻寬瓶頸，且符合 1:1 無阻塞原則。

### 總結

* **臨界規模下的成本激增**：單台 36 埠交換器一旦無法滿足需求（如需要 72 埠），為了維持 1:1 完全無阻塞胖樹架構，交換器數量會激增至 6 台，導致網路建置成本大幅非線性上升。
* **小中型規模的替代彈性**：對於中小規模叢集，不一定要硬性追求完全無阻塞架構，可退而求其次採用「有阻塞配置（Blocking）」或「Mesh 架構」以大幅節省硬體預算。

* **48 埠折衷配置範例（1:2 阻塞比）**：
    * **硬體成本**：僅需 2 台 36 埠交換器即可滿足 48 節點需求。
    * **連接埠分配**：每台交換器提供 24 埠給終端節點（24 × 2 = 48 埠），兩台交換器之間則以剩餘的 12 條鏈路互連（12x links）。
    * **效能影響**：內部上行對下行比例為 12:24（即 1:2），當所有跨機流量同時發生時，平均每條互連鏈路需承擔 2 對節點的資料傳輸。

## 環狀拓撲與信用循環（Ring Topology and Credit Loops）


請注意，超過三台交換器的「環狀（ring）」網路是無效的配置，這會產生信用循環（credit-loops），進而導致網路死結（network deadlock）。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnNu&feoid=00N8Z000003jPco&refid=0EM8Z000003DSWs)

上方圖示說明：三台交換器組成的三角環狀結構

    * 每台交換器各引出 18 個連接埠（18-ports）連接終端節點。
    * 任兩台交換器之間以 9 條鏈路（9x links）互連（$18 + 9 + 9 = 36$ 埠，剛好用滿單台 36 埠交換器）。


![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnNu&feoid=00N8Z000003jPco&refid=0EM8Z000003DSWx)

上方圖示說明：四台交換器組成的矩形環狀結構，標有禁止符號

    * 4 台交換器圍成一個環，任相鄰兩台交換器之間以 9 條鏈路（9x links）互連。
    * 每台交換器各向下/向上接出 18 個連接埠（18-ports）供節點使用。

### 總結

* **交換器數量上限規則**：在 InfiniBand 架構中，環狀（Ring）拓撲**不可超過 3 台交換器**。

* **死結風險（Credit Loops）**：一旦環狀結構包含 4 台或以上的交換器，網路內部就會形成信用循環（Credit Loops），最終導致整個網路流量發生死結（Deadlock）癱瘓。

* **合法 3 交換器配置規格**：
    * 每台 36 埠交換器接出 18 埠給終端主機，其餘 18 埠分別分給另外兩台交換器各 9 條鏈路互連（共可支援 $18 \times 3 = 54$ 個節點）。

* **架構禁忌**：切勿為了擴充節點數而將 4 台或更多交換器直接串接成閉合環形（如圖中 4 台 18-port 外接的方環）。

## Topology Examples

### CLOS-3 Topology (Non-Blocking)

#### 72 Node Fat-Tree

使用1U SX6036交換器。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnNu&feoid=00N8Z000003jPco&refid=0EM8Z000003DSX2)

9 x 4X Uplinks: 使用 9 條標準的 4 通道（4-lane）InfiniBand 纜線作為上行鏈路，用來連接底層的 L1 交換器與頂層的 L2 交換器，合計佔用兩端各 9 個連接埠。

**雙層平衡型胖樹拓撲架構（72 埠無阻塞範例）**

    * **上層（Layer 2 / Spine 交換器）**：
        * 包含 2 台 36 埠交換器（標示為 **L2-1** 與 **L2-2**）。
    * **下層（Layer 1 / Leaf 交換器）**：
        * 包含 4 台 36 埠交換器（標示為 **L1-1**、**L1-2**、**L1-3**、**L1-4**）。
    * **圖例與線路說明（Legend）**：
        * **黑色粗實線**：代表 **9 條 4X 上行鏈路（9 x 4X Uplinks）**。
        * **藍色雙箭頭線**：代表 **1 條 4X 鏈路（1 x 4X Uplinks）**。
        * **下行連接**：每台 L1 交換器各自向下引出 **18 條鏈路連接至運算節點（18 Links To Compute Nodes）**。

* **節點容量與交換器配比**：
    * 4 台 L1 交換器各提供 18 條連線給運算節點，總共支援 **72 個主機節點**（$4 \times 18 = 72$）。
    * 總共使用 **6 台 36 埠交換器**（4 台 L1 + 2 台 L2）。


* **1:1 完全無阻塞（Non-Blocking）實體配置**：
    * **L1 交換器連接埠配置**（每台 36 埠）：
        * 18 埠作為下行（Downlink）接主機。
        * 18 埠作為上行（Uplink）接 Spine。
    * **Spine 上行鏈路分配**：
        * 每台 L1 交換器的 18 條上行鏈路均勻對拆：**9 條連往 L2-1**，**9 條連往 L2-2**（黑色線條標示為 9 x 4X Uplinks）。

* **Spine（L2）交換器埠位完全對稱**：
    * 每台 L2 交換器接收來自 4 台 L1 交換器的連線，每台 L1 接入 9 條鏈路。
    * 單台 L2 剛好用滿 36 埠（$4 \times 9 = 36$），全網維持高度對稱與負載平衡，沒有任何單點壅塞。

#### 324 Node Fat-Tree

使用1U SX6036交換器或Director交換器（SX6518）。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnNu&feoid=00N8Z000003jPco&refid=0EM8Z000003DSX7)

這張架構圖展示了「使用 27 台盒式交換器（SX6036）構建的雙層無阻塞胖樹架構」**與**「單台機箱型 Director 交換器（SX6518）」之間的等價關係：

* **左側架構：分散式胖樹（Discrete Fat-Tree）**
    * **上層（L2 / Spine）**：共 9 台 Mellanox SX6036 交換器（L2-1 至 L2-9，每台 36 埠）。
    * **下層（L1 / Leaf）**：共 18 台 Mellanox SX6036 交換器（L1-1 至 L1-18，每台 36 埠）。
    * **連線與下行**：每台 L1 各向下接出 18 條鏈路連接運算節點（總計 324 個節點），向上則分別與 9 台 L2 各以 2 條鏈路連接（$2 \times 4\text{X Uplinks}$），合計 18 條上行鏈路（$9 \times 2 = 18$）。

* **右側設備：整合式機箱交換器（Director Switch）**
    * **等價等同（`=`）**：Mellanox SX6518 機箱型 Director 交換器。

* **324 埠無阻塞架構的等價性**：左側由 27 台 36 埠盒式交換器（SX6036：18 台 L1 + 9 台 L2）手動跳線組成的 1:1 完全無阻塞架構，在功能、連接埠總數（324 埠）以及無阻塞無衝突效能上，完全等同於右側的一台 **Mellanox SX6518 機箱型交換器**。

* **Spine 與 Leaf 鏈路配比**：
    * 每台 L1 交換器有 18 埠下行連接運算節點（$18 \times 18 = 324$ 節點）。
    * 剩餘 18 埠作為上行，平均分散連往 9 台 L2，因此每台 L1 到每台 L2 之間鋪設 **2 條 4X 鏈路**（黑色實線：$2 \times 4\text{X Uplinks}$）。

* **外接盒式 vs 機箱型的權衡（Trade-off）**：
    * **27 台獨立交換器（SX6036）**：需自行在機櫃間拉設龐大的跨交換器纜線（Spine-Leaf 間共需 $18 \times 18 = 324$ 條互連線），管理與維護線路複雜度高。
    * **機箱型 Director（SX6518）**：內部背板直接整合了相當於 9 台 Spine 與 18 台 Leaf 的 ASIC 交換模組，將所有複雜的互連線路收容在機箱內部背板中，外部只需直接插上 324 條運算節點線路即可，大幅簡化佈線與管理。

#### 648 Node Fat-Tree using

使用1U SX6036交換器或Director交換器（SX6536）。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnNu&feoid=00N8Z000003jPco&refid=0EM8Z000003DSXC)


這張架構圖展示了「使用 54 台盒式交換器（SX6036）構建的雙層無阻塞胖樹架構」**與更大型的**「單台機箱型 Director 交換器（SX6536）」之間的等價關係：

* **左側架構：大型分散式胖樹（Discrete Fat-Tree）**

    * **上層（L2 / Spine）**：共 18 台 Mellanox SX6036 交換器（L2-1 至 L2-18，每台 36 埠）。
    * **下層（L1 / Leaf）**：共 36 台 Mellanox SX6036 交換器（L1-1 至 L1-36，每台 36 埠）。
    * **連線與下行**：每台 L1 交換器各自向下接出 18 條鏈路連接運算節點（總計支援 $36 \times 18 = 648$ 個節點）。向上則分別與 18 台 L2 各以 **1 條 4X 鏈路** 連接（$1 \times 4\text{X Uplinks}$），合計 18 條上行鏈路（$18 \times 1 = 18$）。

* **右側設備：高密度機箱交換器（Director Switch）**

* **等價等同（`=`）**：Mellanox SX6536 機箱型 Director 交換器。

* **648 埠無阻塞架構的等價性**：左側由 54 台 36 埠盒式交換器（SX6036：36 台 L1 + 18 台 L2）組成的 1:1 完全無阻塞雙層胖樹架構，在整體容量、連接埠總數（648 埠）及無阻塞傳輸效能上，完全等同於右側的一台 **Mellanox SX6536 機箱型交換器**。


* **Spine 與 Leaf 鏈路配比（全網單鏈路互連）**：
    * 每台 L1 交換器有 18 埠下行連接運算節點（$36 \times 18 = 648$ 節點）。
    * 剩餘 18 埠作為上行，平均分散連往 18 台 L2，因此每台 L1 到每台 L2 之間鋪設 **1 條 4X 鏈路**（黑色實線：$1 \times 4\text{X Uplinks}$）。
    * 每台 L2（36 埠）剛好接滿來自 36 台 L1 的連線（$36 \times 1 = 36$ 埠），達到雙層胖樹架構在 36 埠交換器下的最大理論極限（648 埠無阻塞）。


* **外接盒式 vs 機箱型的權衡（Trade-off）**：
    * **54 台獨立交換器（SX6036）**：Spine 與 Leaf 之間需手動拉設高達 648 條跨機櫃光纖/銅纜（$36 \times 18 = 648$ 條互連線），佈線、故障排查與機房空間管理負擔極大。
    * **機箱型 Director（SX6536）**：機箱內部背板已將相當於 18 台 Spine 與 36 台 Leaf 的交換模組完全整合，將 648 條互連線路全部內建在背板中，外部只需直接接入 648 台運算節點，大幅降低實體佈線的複雜度與維護成本。

## 效能計算（Performance Calculations）

計算節點每秒浮點運算次數（FLOPS）的公式如下：

$$\text{節點效能 (FLOPS)} = (\text{CPU 時脈 Hz}) \times (\text{CPU 核心數}) \times (\text{CPU 每週期指令數}) \times (\text{每節點 CPU 顆數})$$

以搭載 Intel E5-2690（2.9GHz、8 核心）CPU 的 Intel 雙路（Dual-CPU）伺服器為例：


$$2.9 \times 8 \times 8 \times 2 = 371.2\text{ GFLOPS（每台伺服器）}$$

> **註**：E5-2600 系列 CPU 的每週期指令數（IPC / instruction per cycle）為 8。
> 
> 

要計算叢集效能，將上述計算出的單節點數值乘以 HPC 系統中的節點總數，即可得出理論峰值效能。

* 一個 **72 節點**的胖樹叢集（使用 6 台交換器）具備：



$$371.2\text{ GFLOPS} \times 72\text{ (節點)} = 26,726\text{ GFLOPS} \approx 27\text{ TFLOPS}$$



* 一個 **648 節點**的胖樹叢集（使用 54 台交換器）具備：



$$371.2\text{ GFLOPS} \times 648\text{ (節點)} = 240,537\text{ GFLOPS} \approx 241\text{ TFLOPS}$$


對於規模超過 648 節點的胖樹架構，HPC 叢集必須具備至少 3 層階層架構（3 levels of hierarchy）。如需包含 GPU 加速的進階計算，請參考指定連結[how-to-calculate-flops-of-gpu](http://optimisationcpugpu-hpc.blogspot.com/2012/10/how-to-calculate-flops-of-gpu.html)。

叢集所發揮的**實際效能**取決於叢集的互連網路（cluster interconnect）。平均而言，使用 **1 GbE 乙太網路**連線會使叢集效能衰退 50%；使用 **10 GbE** 時，預期效能衰退約 30%；然而，**InfiniBand 互連架構**則能達到 **90% 的系統效率**（即僅有 10% 的效能損失）。更多資訊可參考 [www.top500.org](http://www.top500.org/)。

| 叢集規模 (Cluster Size) | 理論效能 (Theoretical 100%) | 1 GbE 網路 (50%) | 10 GbE 網路 (70%) | FDR InfiniBand 網路 (90%) | 單位 (Units) |
| --- | --- | --- | --- | --- | --- |
| **72 節點叢集** | 27 | 13.5 | 19 | 24.3 | TFLOPS|
| **324 節點叢集** | 120 | 60 | 84 | 108 | TFLOPS|
| **648 節點叢集** | 241 | 120.5 | 169 | 217 | TFLOPS|
| **1296 節點叢集** | 481 | 240 | 337 | 433 | TFLOPS|
| **1944 節點叢集** | 722 | 361 | 505 | 650 | TFLOPS|
| **3888 節點叢集** | 1444 | 722 | 1011 | 1300 | TFLOPS|

> **註**：InfiniBand 是 HPC 市場中最主要的互連技術。InfiniBand 擁有許多特性使其成為 HPC 的理想選擇，包括：

> * 低延遲與高吞吐量
> * 遠端直接記憶體存取（RDMA）
> * 可擴展至數千個端點的扁平 Layer 2 架構（Flat Layer 2）
> * 集中式管理（Centralized management）
> * 多路徑支援（Multi-pathing）
> * 支援多種拓撲結構（Support for multiple topologies）

### 總結

* **算力計算公式**：單節點 FLOPS = 時脈 × 核心數 × 每週期指令數 (IPC) × CPU 顆數。全叢集理論峰值算力即為單節點算力乘上總節點數。
* **雙層胖樹規模臨界點**：基於 36 埠交換器的 2 層無阻塞胖樹最大支援至 648 節點（需 54 台交換器）；若叢集規模超過 648 節點，網路層級必須擴展至 3 層（3-tier）架構。

* **互連網路決定算力發揮率（系統效率）**：
    * **1 GbE 乙太網路**：效率僅 50%（效能折損高達一半）。
    * **10 GbE 乙太網路**：效率約 70%（效能折損 30%）。
    * **FDR InfiniBand**：系統效率高達 90%（效能折損僅 10%），能最大化榨出昂貴伺服器的運算效能。

* **InfiniBand 核心優勢**：具備高頻寬、極低延遲、硬體級 RDMA（零拷貝、繞過作業系統）、集中管理與靈活的拓撲支援，是支撐大規模 HPC 與平行運算的關鍵基礎。

## 使用 HPC-X 軟體工具套件極大化效能（Maximizing Performance with HPC-X Software Toolkit）

Mellanox HPC-X Toolkit 是一套專為高效能運算環境打造的完整 MPI、SHMEM 與 UPC 軟體套件。HPC-X 同時包含多種加速模組，以提升基於這些函式庫運作的應用程式之效能與可擴充性，其中包括用於加速底層發送/接收（send/receive，或稱 put/get）訊息的 MXM（Mellanox Messaging），以及用於加速 MPI/PGAS 語言底層集合通訊操作（collective operations）的 FCA（Fabric Collectives Accelerations）。這款功能完整、經過嚴格測試與打包的 HPC 軟體套件，藉由改善記憶體與延遲相關的效率，讓 MPI、SHMEM 和 PGAS 程式語言得以擴展至極大規模的叢集，並確保通訊函式庫能針對 Mellanox 互連架構解決方案進行充分的最佳化。

HPC-X 的主要特色包括：

* 完整的 MPI、SHMEM、UPC 套件，內建 Mellanox MXM 與 FCA 加速引擎
* 將集合通訊（collectives communication）由 MPI 程序卸載（offload）至 Mellanox 互連硬體上執行
* 藉由底層硬體架構將應用程式效能發揮至極致
* 針對 Mellanox InfiniBand 與 VPI 互連解決方案進行深度最佳化
* 提高應用程式的可擴充性（scalability）與資源利用效率
* 支援多種傳輸模式，包括 RC（可靠連接）、DC（動態連接）與 UD（不可靠數據報）
* 節點內部共享記憶體通訊（Intra-node shared memory communication）
* 接收端標籤比對（Receive side tag matching）
* 原生支援 MPI-3 標準


### 總結

* **核心定位與通訊庫整合**：專為 HPC 設計的通訊軟體堆疊，全面整合支援 MPI、SHMEM 與 UPC/PGAS 平行運算程式庫。
* **硬體級通訊加速與卸載**：
    * **MXM 模組**：加速點對點（P2P）訊息傳輸（Send/Receive、Put/Get）。
    * **FCA 模組**：將複雜的集合通訊（如 Allreduce、Broadcast 等）由 CPU 軟體計算卸載至交換器與網卡硬體直接處理。

* **大規模擴充與傳輸協定支援**：原生支援 RC、UD 以及專為超大規模節點設計的 **DC（Dynamically Connected Transport）** 傳輸協定，大幅縮減連線記憶體佔用。
* **節點內外全方位最佳化**：除了跨節點的 InfiniBand 最佳化，亦包含節點內的共享記憶體加速、接收端硬體標籤比對，並原生相容 MPI-3 規範。


## HPC-X 中的通訊函式庫支援（Communication Library Support in HPC-X）

為了讓使用者能及早且透明無縫地採用 Mellanox 互連硬體所提供的各項功能，Mellanox 開發並支援了兩套核心函式庫：

* **Mellanox Messaging (MXM)**
* **Fabric Collective Accelerator (FCA)**

這些通訊函式庫為上層協定（ULP，例如 MPI）以及 PGAS 函式庫（例如 OpenSHMEM 和 UPC）提供完整支援。MXM 與 FCA 亦作為具備明確定義介面的獨立函式庫提供，並被多套商業與開源 ULP 廣泛採用，以提供經過最佳化的點對點（point-to-point）與集合（collective）通訊函式庫，充分榨取底層互連硬體的極致效能。下圖展示了這些函式庫的架構與其核心功能：

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnNu&feoid=00N8Z000003jPco&refid=0EM8Z000003DSXb)

* 圖架構解析

    * **上層程式模型與記憶體架構**：
        * **MPI**：各程序（P1、P2、P3）擁有獨立的私有記憶體（Memory），透過訊息傳遞進行交互。
        * **SHMEM**：各程序存取單一連續的邏輯共享記憶體（Logical Shared Memory）。
        * **PGAS**：將實體上分散於各程序的記憶體，映射並抽象為統一的邏輯共享記憶體空間。

* **中介加速函式庫層**：
    * **MXM**：
        * 針對 Mellanox HCA 最佳化的可靠訊息傳遞（Reliable Messaging Optimized for Mellanox HCA）
        * 混合傳輸機制（Hybrid Transport Mechanism）
        * 高效記憶體註冊（Efficient Memory Registration）
        * 接收端標籤比對（Receive Side Tag Matching）
    * **FCA**：
        * 感知網路拓撲的集合通訊最佳化（Topology Aware Collective Optimization）
        * 硬體多播（Hardware Multicast）
        * 專用於集合通訊的獨立虛擬網路架構（Separate Virtual Fabric for Collectives）
        * CORE-Direct 硬體卸載技術（CORE-Direct Hardware Offload）
    * **底層介面**：
        * **InfiniBand Verbs API**（最底層的硬體存取與控制介面）

### 總結

* **承上啟下的軟體中介層**：MXM 與 FCA 介於頂層平行程式模型（MPI、SHMEM、PGAS）與最底層的 InfiniBand Verbs API 之間，將複雜的硬體特性封裝，讓上層應用無痛享受硬體加速。

* **獨立運作與跨平台彈性**：兩者皆具備標準 API 介面，除了整合於 HPC-X 內，也可作為獨立函式庫供開源與商業 ULP 軟體單獨調用。


* **MXM 核心任務（點對點與記憶體加速）**：
    * 專注於加速節點間一對一訊息傳遞。
    * 支援混合傳輸與接收端硬體標籤比對，並優化記憶體註冊（Memory Registration）機制以減少開銷。

* **FCA 核心任務（群體通訊與硬體卸載）**：
    * 專注於優化一對多、多對多的集合通訊（如廣播、規約）。
    * 結合網路拓撲感知、硬體多播（Hardware Multicast）及 CORE-Direct 硬體卸載，直接由網路交換層級執行群體通訊運算，釋放主機 CPU 負擔。

## 網路集合通訊加速器（Fabric Collective Accelerator, FCA）

網路集合通訊加速器（FCA）函式庫為 MPI 與 PGAS 的集合通訊操作提供支援。FCA 採用模組化元件架構設計，能藉由元件外掛程式（component plugins）快速部署新演算法與新網路拓撲。FCA 能充分善用當前與新興 HPC 系統中日益分層的記憶體與網路階層架構。可擴充性（scalability）與擴展彈性（extensibility）是 FCA 的兩大核心設計目標。因此，FCA 的拓撲外掛程式支援基於 InfiniBand 交換器佈局與共享記憶體階層的架構——同時支援共用 Socket 以及採用 NUMA 共享架構。FCA 以插件為基礎的實作方式，最大程度減少了支援新型拓撲結構與新硬體功能所需的時間。

在核心技術上，FCA 是一套能實現硬體輔助無阻塞集合通訊（hardware assisted non-blocking collectives）的引擎。具體而言，FCA 釋放了 CORE-Direct 的硬體能力。藉由 CORE-Direct，HCA 網卡能夠以非同步方式管理並推進集合通訊操作，完全無需 CPU 介入。FCA 內建支援完全非同步、無阻塞集合通訊操作的 CORE-Direct 外掛模組，其能力已完整實作為 MPI-3 非阻塞集合通訊常式的底層機制。除了全面支援非同步無阻塞集合通訊外，FCA 還向上層協定（ULP）提供了利用 HCA 執行浮點數與整數規約（reduction）運算的能力。

由於集合通訊的效能與可擴充性往往在許多 HPC 科學應用的擴展性與整體效能中扮演關鍵角色，Mellanox 推出了 CORE-Direct 技術作為應對這些挑戰的機制。這種硬體卸載能力可藉由「重疊通訊與運算（overlapping of communication with computation）」來顯著提升應用程式的整體效能。隨著系統規模持續擴大，通訊與運算重疊執行的能力對於提升全系統資源利用率、縮短問題求解時間（time to solution）以及降低能源消耗變得日益重要。這項技術對於減輕「系統雜訊（system noise）」帶來的負面影響也至關重要。透過由 HCA 網卡負責管理與推展集合通訊，因核心層級中斷（kernel-level interrupts）所導致的程序偏差（process skew），及其在超大規模環境下放大延遲的傾向，皆能被降至最低。

### 總結

* **模組化與外掛架構**：FCA 具備高擴充性，能透過外掛模組快速支援新拓撲與新演算法，並針對 InfiniBand 交換器架構、跨 Socket 及 NUMA 共享記憶體進行感知與深度最佳化。
* **CORE-Direct 零 CPU 介入卸載**：核心集合通訊任務由 HCA 網卡在硬體層級非同步排程與執行，徹底解放主機 CPU 負擔，並支援由 HCA 處理浮點數與整數的規約計算（Reduction）。
* **全面落實 MPI-3 非阻塞通訊**：實現通訊與運算的高度重疊（Communication/Computation Overlap），大幅降低大規模模擬計算的總耗時與能源消耗。
* **消除系統雜訊與擴大規模**：將通訊進展交由硬體網卡推進，避免作業系統核心中斷造成的程序失步與延遲放大（Process Skew），確保叢集擴展至超大規模時仍維持極高效率。

## Mellanox 訊息傳遞函式庫（Mellanox Messaging, MXM）

Mellanox 訊息傳遞（MXM）函式庫提供點對點（point-to-point）通訊服務，包括發送/接收（send/receive）、RDMA、不可分割操作（atomic operations）以及主動訊息傳遞（active messaging）。除了這些核心服務外，MXM 還支援多項重要功能，例如定義單向通訊（one-sided communication）操作的上層協定（ULP，如 MPI、SHMEM 和 UPC）所需的單向通訊完成機制。MXM 透過一層輕量且與傳輸協定無關的介面（transport agnostic interface），支援多種 InfiniBand+ 傳輸模式。支援的傳輸模式包括：具備高擴充性的動態連接傳輸（Dynamically Connected Transport, DC）、可靠連接傳輸（Reliably Connected Transport, RC）、不可靠數據報（Unreliable Datagram, UD）、乙太網路 RoCE，以及專為最佳化主機內部低延遲敏感通訊所設計的共享記憶體傳輸（Shared Memory transport）。MXM 為 Mellanox 提供了一項關鍵機制，能夠迅速導入對新硬體特性的支援，為終端使用者提供高效能、具擴充性且具容錯能力的通訊服務。

MXM 善用通訊硬體卸載能力以實現真正的非同步通訊推進，進而釋放 CPU 專注於運算。這項多軌（multi-rail）、執行緒安全（thread-safe）的支援同時涵蓋了非同步發送/接收以及 RDMA 兩種通訊模式。此外，它還支援運用 HCA 網卡的延伸功能，直接處理前述兩種通訊模式中的非連續性資料傳輸（non-contiguous data transfers）。

MXM 採用了多種方法來提供具備擴充性的資源佔用配置（scalable resource foot-print）。這些方法包括支援 DCT、接收端流量控制（flow-control）、長訊息會合協定（Rendezvous protocol），以及所謂的零拷貝發送/接收協定（zero-copy send/receive protocol）。此外，它也支援有限數量的 RC 連線，這可用於持久性通訊通道比動態建立通道更適用的情境。

當 MPI 等上層協定（ULP）定義其容錯支援架構時，MXM 將完全支援這些功能特性。

如前所述，MXM 為 MPI 以及包含 OpenSHMEM 和 UPC 在內的多種 PGAS 協定提供全面支援。MXM 同時為發送/接收、RDMA、不可分割操作（atomic）以及同步操作提供了硬體卸載支援。

請造訪 Mellanox HPC-X Software Toolkit 網站頁面以下載最新版本、版本資訊及使用手冊，以利快速上手部署。

---

### 總結

* **核心通訊與協議相容**：MXM 專注於高效能點對點通訊（Send/Receive、RDMA、Atomic、Active Messaging），並為 MPI、OpenSHMEM 及 UPC 等上層協定提供底層加速。
* **多元傳輸協定支援**：透過抽象傳輸介面支援 RC、UD、RoCE、本機共享記憶體，以及專為超大規模設計以大幅降低記憶體開銷的 **DC（動態連接）**。
* **硬體卸載與非同步運作**：具備 Multi-rail 與 Thread-safe 特性，能將非同步傳輸與非連續性記憶體搬移（Non-contiguous Transfers）直接交由 HCA 處理，完全卸載主機 CPU 負擔。
* **輕量記憶體與連線管理**：採用零拷貝（Zero-copy）、長訊息 Rendezvous 協定以及動態 DCT 機制，有效控制超大規模運算時的通訊連線與快取資源佔用。

## 服務品質（Quality of Service, QoS）

服務品質（QoS）的需求源自於在 InfiniBand 網路上實現 I/O 整合（I/O consolidation）。當多個應用程式共用同一個網路架構時，需要一種手段來管控它們對網路資源的使用。

最基本的需求是區分提供給不同流量的服務等級（service levels），以便執行管理策略，並控制各流量對網路架構資源的使用率。

InfiniBand 架構規範（InfiniBand Architecture Specification）定義了數項用於支援 QoS 的硬體功能與管理介面：

    * 最多可使用 **15 個虛擬通道（Virtual Lanes, VL）** 以無阻塞方式傳輸流量。
    * 不同 VL 流量之間的仲裁是由一個**雙優先權等級的加權輪詢仲裁器（two-priority-level weighted round robin arbiter）** 執行。該仲裁器可透過一組「(VL, 權重)」配對序列進行程式化設定，並可指定在服務低優先權之前所能處理的高優先權信用額度（credits）最大上限。
    * 封包在其標頭的 **SL（Service Level）欄位**中攜帶範圍為 **0 到 15** 的服務等級標記。
    * 每台交換器可依據可程式化對應表 `VL = SL-to-VL-MAP(in-port, out-port, SL)`，將傳入封包根據其 SL 對應到特定的輸出 VL。
    * 子網管系統（Subnet Administrator, SA）透過回應路徑記錄（Path Record, PR）或多路徑記錄（MultiPathRecord, MPR）的查詢請求，來控制每個通訊流的參數設定。

### 總結

* **核心目的與背景**：因應多個應用程式在同一個 InfiniBand 網路上整合 I/O，必須透過 QoS 機制對不同流量進行分級管理，避免資源搶佔。

* **SL（服務等級）標記**：封包標頭具備 SL 欄位，支援 0～15（共 16 種）等級的流量分類標記。
* **VL（虛擬通道）隔離**：硬體支援最多 15 個獨立的 VL，提供無阻塞的實體緩衝區隔離傳輸。
* **靈活的 SL 到 VL 對應機制**：交換器具備可程式化對應表，能根據封包的輸入埠、輸出埠及 SL 數值，彈性將封包分流映射至對應的輸出 VL。
* **雙層 WRR 排程仲裁**：採用具備高低兩級優先權的加權輪詢（Weighted Round Robin）硬體仲裁器，透過配置權重與信用額度上限，兼顧高優先流量的即時性與低優先流量的傳輸保證。
* **集中式參數管控（SA）**：由 Subnet Administrator 統一在節點查詢路徑（Path Record / MultiPathRecord）時下發對應 QoS 通訊參數，實現全網集中化管理。

## 子網路管理器（Subnet Manager, SM）

InfiniBand 使用名為子網路管理器（Subnet Manager, SM）的集中式資源來處理網路架構的管理工作。SM 負責探索接入網路架構的新端點、使用相關網路資訊來設定端點與交換器，並在交換器中建立用於所有封包轉發操作的轉發對應表（forwarding tables）。

選擇放置 SM 最佳位置的三種方案如下：

* **在其中一台受管交換器上啟用 SM**。這是一種非常方便且快速的操作方式，只需一行指令即可啟動 SM。這有助於實現 InfiniBand 的「隨插即用（plug & play）」，減少一項需要安裝與設定的組件。在刀鋒交換器（blade switch）環境中，由於以下優勢而十分常見：

    * 將昂貴的刀鋒伺服器單獨配置為 SM 伺服器通常不符合成本效益；以及
    * 額外加入非刀鋒架構（獨立機架式）伺服器，會稀釋刀鋒系統的原有價值（如易於升級、簡化佈線等）。


* **以伺服器為基礎的 SM（Server-based SM）非常適合大型叢集**，以便擁有足夠的 CPU 運算能力來因應重大網路拓撲變更等狀況。運算效能較弱的 CPU 雖然也能處理大型網路架構，但在伺服器恢復連線時可能需要耗費極長時間。此外，在某些情況下，SM 的處理速度可能會過慢而永遠趕不上網路變化。因此，若節點規模達到 **648 個節點或以上**，建議將 SM 運行於獨立伺服器上。

* **使用 Unified Fabric Management（UFM）Appliance 專用伺服器**。UFM 提供遠多於一般 SM 的功能。UFM 需要比現有交換器更強大的運算能力，但並不需要過於昂貴的伺服器。不過，這確實會因為添購專用伺服器而產生額外成本。

### 總結

* **核心定位與職責**：SM 是 InfiniBand 網路的集中式大腦，負責拓撲探索、節點與交換器組態配置，以及全網轉發路由表（Forwarding Tables）的計算與派發。


* **方案一：交換器內建（Switch-embedded SM）**

    * **適用場景**：中小規模網路或刀鋒伺服器環境。
    * **優點**：單鍵啟用、免裝軟體、即插即用，且避免為了 SM 浪費昂貴刀鋒伺服器或破壞機房統一佈線。


* **方案二：獨立伺服器架構（Server-based SM）**

    * **適用場景**：**648 節點或以上**的大型叢集。
    * **關鍵原因**：大型網路變更時計算負擔龐大；若使用交換器弱效能 CPU，容易導致全網收斂極慢甚至無法即時反應拓撲變化，需仰賴伺服器等級 CPU 加速計算。


* **方案三：專用 UFM Appliance 伺服器**

    * **適用場景**：需要進階網路監控、分析與進階架構管理的高階企業/HPC 環境。
    * **權衡考量**：具備最全面的監控管理功能，需配置一般伺服器運算力，會增加專用硬體採購成本。