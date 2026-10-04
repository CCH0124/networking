# Understanding Up/Down InfiniBand Routing Algorithm

## 概述 (Overview)

網路中可設定多種 InfiniBand 路由引擎，例如 Min-Hop、Up/Down、Down/Up、Fat Tree 等（詳見 [OpenSM](http://linux.die.net/man/8/opensm) 文件）。其中，**Up/Down（UpDn）** 與 **Fat Tree** 是 Clos/Fat-Tree 網路中最常使用的 InfiniBand 路由演算法。

> **注意：** 這包含由導引交換器（Director Switches）與 1U 交換器所建構的樹狀網路——這兩層實體交換器外殼實際上代表了 3 層交換器 ASIC，因為每個 Director 交換器內部皆包含 2 層 ASIC。
> 
> 

如同多數 IB 路由演算法，UpDn 會使用任兩個終端節點之間可用的最短路徑。它可以為任意由 IB 連接的交換器與 HCA 所組成的集合進行路由。最重要的是，與 Min-Hop 不同，**UpDn 保證網路架構中不會產生信用循環（Credit-loop free）**。

UpDn 會先從構成架構「根（Root）」或頂層的交換器 ASIC 清單開始運作。此清單是透過子網管理器（SM）的旗標 `--root_guid_file` 進行設定，它是一個純文字檔，每行記錄一個 Root ASIC 的全域唯一 ID（GUID）。雖然 UpDn 具備自動探索 Root ASIC 的選項，但**強烈建議手動提供 Root GUID 清單**。若更換了 Root 交換器 ASIC 或擴充了網路拓撲，則必須更新該清單，且每個 SM 都必須擁有完全一致的 GUID 清單副本。

為全網開始計算路由時，UpDn 演算法會先從 Root 交換器 ASIC 開始，將其定義為 **Distance 0（距離 0）**。演算法接著找出所有距離 Root 僅有一跳（One hop / 1 條鏈路）的交換器 ASIC，將其視為 **Distance 1**。接著再找出距離 Root 交換器兩跳的所有交換器 ASIC，視為 **Distance 2**。此程序持續進行，直到全網每個交換器 ASIC 都被賦予一個與 Root 相對的距離為止。下圖展示了一個指派完距離的 3 層架構範例。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnPV&feoid=00N8Z000003jPco&refid=0EM8Z000003DSEe)

*(3 層拓撲，最頂層為 Root ASIC / Distance 0，往下依次為 Distance 1 與 Distance 2)*

此程序會產生一棵**廣度優先生成樹（Breadth-First Spanning Tree, BFST）**，類似於乙太網路使用的生成樹協定（STP）。但不同於 STP，UpDn 允許**多個 Root**，並致力於在每對終端節點之間提供盡可能多的路徑。

UpDn 演算法隨後會找出終端節點之間所有可能的最短路徑。接著，**UpDn 會捨棄任何包含「從 Distance N 跳至 Distance N+1，隨後又跳回 Distance N」的路徑**。也就是說，它會丟棄任何「先往下（Away from the roots），然後又往上（Toward the roots）」的路徑。

**合法路徑可以：**

    * 向上（Up）
    * 向下（Down）
    * 先向上再向下（Up and then Down）
    * 停留在同一層級（Stay at the same level）
    * **絕不允許：先向下再向上（Never Down and then Up）**


透過捨棄這些不合規路徑、且不在交換器中配置它們，UpDn 保證不會產生邏輯環路，亦不會產生可能導致流量停滯的信用循環。

下圖展示了允許（Allowed）與禁止（Disallowed）的路徑範例：

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnPV&feoid=00N8Z000003jPco&refid=0EM8Z000003DSEj)

*(展示節點 E 與 F 之間的路徑，其中一條走合法 Up-Down，另一條因包含 Down-to-Up 區段而被禁止)*

> **注意：** 節點 E 與 F 之間的兩條潛在路徑長度完全相同（跳數相同），但只有一條遵守 UpDn 規則。被禁止的那條路徑包含了一個 Down-to-Up 區段。
> 

UpDn（以及 Fat Tree）路由拓撲的無信用循環特性，對於網路的可靠運作至關重要。然而，由於部分潛在路徑被捨棄，在某些情況下可能會導致一對終端節點彼此斷連、無法互相通訊。

當 OpenSM 設定檔中的 `calculate_missing_routes` 選項設定為 **TRUE**（此為預設值）時，可保證在 UpDn 與 Fat Tree 路由下，以**無信用循環的方式確保網路中所有端點之間的連通性**。

舉例來說，考慮一個不同的架構，其節點連接在 Leaf 交換器之上（例如節點 G、H 和 J）。連接在 L1 交換器上的節點（A、B、C 等）擁有通往節點 G、H、J 的合法 UpDn 路徑；節點 G 與 H 之間也存在合法的 UpDn 路徑。然而，**節點 G 與 J 之間卻不存在合法的 UpDn 路徑**，這兩台節點將無法互相通訊。此時將 `calculate_missing_routes` 設為 TRUE，即可在所有端點之間提供無信用循環的路由。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnPV&feoid=00N8Z000003jPco&refid=0EM8Z000003DSEo)

*(展示非底層節點 G 與 J 之間因 UpDn 規則出現無法通訊的死角，標記 Disallowed Missing Path)*

某些情況下節點之間確實不需要通訊（例如儲存節點之間不需要互傳），但這種情況很少見。**對於 Clos-5 3 層架構而言，最佳實踐原則是切勿將節點連接至 L2 交換器**。

> **注意：** 上述圖示同樣適用於兩種情況：由 3 層 1U 交換器建構的架構，以及上方使用兩台 Director 交換器、下方搭配 1U 交換器的架構。在後者情況下，節點 E、F、G 代表連接至 Director 交換器內部 Leaf 模組的節點。
> 


### 分散連接埠 (Scatter-Ports)

在將邏輯路徑指派給實體鏈路時，UpDn 演算法會嘗試為每條鏈路映射相同數量的路徑，以達到可用頻寬的最大化利用。這種平衡是靜態完成的，演算法並不知道實際的工作負載與流量模式。由於路徑平衡決策是在每台交換器局部（Locally）進行的，並未對實體拓撲進行整體性假設，因此所得出的路徑分配對於典型的 Clos/Fat-Tree 工作負載而言可能並非最佳。

Min-Hop 與 UpDn 路由引擎提供了一個名為 **`scatter-ports`** 的路由選項。它會指示路由演算法**隨機化（Randomize）路徑到實體鏈路的局部指派**，這通常能帶來更好的鏈路利用率。`scatter-ports` 選項需要一個整數參數作為亂數產生器的種子（Seed），建議使用質數作為種子；設定為 0 則會關閉隨機化功能。

> **注意：** `scatter-ports` 設定僅適用於在主機（Host）或 UFM 上執行的 Subnet Manager，若 SM 是直接運行在交換器本體上（Embedded SM），則不支援此功能。
> 


### 總結

* **Up/Down 的核心數學邏輯（BFST 生成樹與階層化）**：
    * 以手動指定的 Root 交換器群為基準點（Distance 0），採用廣度優先搜尋為全網每台交換器標記距離層級（Distance 1, Distance 2...）。
    * 支援多個 Root，比傳統乙太網路的單根 STP 更具擴充性與路徑多樣性。

* **絕對轉發法則（無死結保證）**：
    * **合法**：純上行（Up）、純下行（Down）、先上後下（Up-then-Down）、同層轉發。
    * **嚴格禁止**：**先下後上（Down-then-Up）**。即便兩條路徑跳數完全相同，只要踩到 Down-to-Up 就直接剔除，徹底消滅邏輯環路與信用循環。

* **斷連風險與解法（`calculate_missing_routes`）**：
    * **風險**：若有節點未接在最底層（如接在較高層交換器），部分端點之間可能找不到符合 UpDn 規則的合法路徑（如圖中的 G 到 J）。
    * **解法**：保持 OpenSM 預設參數 `calculate_missing_routes TRUE`，強制在無信用循環的前提下補齊連通性。


* **最佳防範實踐**：**嚴禁將運算伺服器插在 L2 層交換器上**，所有主機務必統一接在最底層 Leaf 交換器。




* **流量負載平衡優化（`scatter-ports`）**：
* **本質限制**：UpDn 的鏈路分配是交換器各自進行的「靜態局部平衡」，非全域最佳化。


* **優化方式**：在主機端或 UFM 的 OpenSM 啟用 `scatter-ports <質數種子>`，隨機打散路徑分配，可有效改善鏈路頻寬利用率、防止局部熱點。