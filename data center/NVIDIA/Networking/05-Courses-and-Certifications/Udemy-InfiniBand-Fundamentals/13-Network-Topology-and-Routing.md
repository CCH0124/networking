# Network Topology and Routing
## Network Toploigy and Routing

### 1. 網路拓撲 vs. 路由演算法（地圖與導航的比喻）

| 比較維度 | 網路拓撲 (Network Topology)| 路由演算法 (Routing Algorithm)|
| --- | --- | --- |
| **地圖比喻** | **道路系統與既定街廓**（已經鋪好的實體道路與交叉路口） | **導航選擇的路徑**（從 A 點到 B 點所走的路，避開塞車或道路施工） |
| **本質定義** | 交換器與主機之間的**實體排列與佈線結構**（固定不變） | 封包在這些實體線路與交換器之間**實際傳遞的邏輯路徑** |
| **動態彈性** | 實體結構通常固定，擴充需重新佈線 | **具備動態調整能力**：遇到鏈路故障或壅塞時可切換路徑|

---

### 2. InfiniBand 常見的 4 大網路拓撲

#### 1. 胖樹架構（Fat Tree）

<img width="1404" height="655" alt="image" src="https://github.com/user-attachments/assets/d8eb03ca-7032-40c8-9904-2c7dae0e7c5a" />


* **結構特點**：如同「倒置的大樹」。由下而上分別為運算節點、Leaf 交換器、Spine 交換器，頂層的樹幹（Trunk）由聚合的多條實體纜線組成，擁有最大的聚合頻寬。
* **優勢**：可實現全頻寬無阻塞（Non-blocking）傳輸，如同城市的大幹道，是目前 AI 與 HPC 叢集**最廣泛採用**的經典拓撲。



#### 2. 全網狀架構（Full Mesh）

<img width="398" height="209" alt="image" src="https://github.com/user-attachments/assets/7b366952-a98e-4c91-b198-53fb12e2072b" />

* **結構特點**：每個節點/交換器都與其他所有節點建立直連線路。


* **優缺點**：
* **優點**：任意兩點傳輸皆為直連（1-hop），延遲極低、備援能力極高。


* **缺點**：隨節點數量增加，纜線數量呈爆炸性成長（$O(N^2)$），佈線與維護成本極高，僅適用於超小規模叢集。





#### 3. 龍蠅拓撲增強版（Dragonfly+）

<img width="332" height="213" alt="image" src="https://github.com/user-attachments/assets/a79dc0d2-227c-4b7b-b672-90a421695333" />


* **結構特點**：屬於分層模組化設計。每個群組內部採用 Leaf-Spine 架構，而在各個群組之間則透過 Mesh 方式進行全互聯。


* **優勢**：在保持極大節點規模的同時，大幅減少跨群組的高成本長距光纖數量，兼顧可擴展性與佈線成本。



#### 4. 三維環面架構（Torus 3D）

<img width="334" height="212" alt="image" src="https://github.com/user-attachments/assets/25e0fc81-464c-4a2f-a9a8-128cefe44b7b" />


* **結構特點**：將節點以立體網格（Grid）排列，各軸邊界的節點透過環狀迴路（Wrap-around link）首尾相連，形成環面結構。


* **優勢**：僅需與相鄰節點連線，大幅節省纜線成本，非常適合氣象模擬、流體力學等鄰近通訊（Nearest-neighbor communication）模式密集的科學運算。

## Control Plane and Data Plane

### 1. 控制平面 vs. 資料平面

* **核心分工原則**：Subnet Manager 定義路徑，Switch 依照該路徑轉發封包（Subnet Manager defines paths, Switch forwards packets using those paths）。
* **控制平面（Control Plane）— Subnet Manager (SM)**：網路的中樞大腦，負責整個 Fabric 的啟動、編號、演算法決策與路徑計算。
* **資料平面（Data Plane）— Switches（交換器）**：負責實際封包在實體埠口之間的快速轉發。

### 2. InfiniBand 交換器的分類：內部管理 vs. 外部管理

傳統乙太網路常區分「Managed（有作業系統）」與「Unmanaged（無作業系統）」。在 InfiniBand 領域，即便交換器具備作業系統（如 Mellanox OS / MLNX-OS），其分類核心取決於 **Subnet Manager (SM) 運行的位置**：

| 類型 | 定義與架構 | 特徵與適用情境 |
| --- | --- | --- |
| **Internally Managed Switch**<br><br>（內部管理型交換器） | **Subnet Manager 功能直接內建並運行於交換器硬體內部**。 | 開箱即用，無需額外伺服器運行 SM，適合中小規模或獨立叢集。 |
| **Externally Managed Switch**<br><br>（外部管理型交換器） | 交換器本身不運行 SM，**由 Fabric 上的外部伺服器/節點運行 SM 來集中控制**。 | 交換器成本較低且專注於硬體轉發，適合超大規模 AI 叢集透過專用伺服器集中統一管理。 |

---

### 3. Subnet Manager 工作流程（Control Plane Workflow）

當 InfiniBand Fabric 啟動時，SM 會按順序執行以下 5 大核心任務：

1. **探索拓撲（Discover topology）**：掃描並掌握實體網路中所有主機、交換器與線路的連接關係。
2. **分配 LID（Assign LIDs to all nodes）**：為子網內的所有端節點與交換器指派唯一的 16-bit LID。
3. **選擇路由演算法（Choose routing algorithm）**：依據網路拓撲與業務需求，指定最佳路由演算法（如 ftree、up/down、minhop 等）。
4. **計算全域路徑（Compute paths）**：算出任一來源節點到目標節點之間的最優轉發路徑。
5. **燒錄線性轉發表（Program Linear Forwarding Table in switches）**：將計算好的轉發規則下發並寫入各交換器的晶片記憶體中（LFT）。

---

### 4. Switch 工作流程（Data Plane Workflow）

交換器硬體在轉發實際資料封包時的標準動作：

1. **接收封包（Receive packet）**：從某個實體連接埠收到 InfiniBand 封包。
2. **查詢 LFT（Lookup LFT using destination LID）**：讀取封包 LRH 標頭中的「目標 LID（Destination LID）」，並至內建的線性轉發表（LFT）中進行硬體查表。
3. **選擇輸出埠（Select output port based on routing type）**：找出目標 LID 所對應的輸出實體埠號（例如目標為 LID 2 則走 Port 4）。
4. **轉發至下一跳（Forward packet to next hop）**：將封包從該埠口高速送出。

## Linear Forwarding Table

### 1. 什麼是線性轉發表（LFT）？

* **核心定義**：儲存於每一台 InfiniBand 交換器內部晶片（ASIC）中的硬體轉發表，負責建立 **「目標 LID $\rightarrow$ 輸出實體埠（Output Port）」** 的精確映射關係。
* **由誰建立**：由控制平面的 **Subnet Manager (SM)** 預先計算並燒錄至各 Switch 中。
* **硬體轉發流程**：
    1. 封包抵達交換器。
    2. 交換器硬體 ASIC 讀取標頭中的 **Destination LID**。
    3. 查詢 LFT 表格。
    4. 從指定 Output Port 送出封包。

### 2. 拓撲偵測與 Switch 識別實務指令

在檢視 LFT 之前，需先掌握拓撲與 Switch 的 LID 資訊：

* **`ibhosts`**：列出網路中所有的 Host 節點及其連接埠數量。
* **`ibswitches`**：列出網路中的所有交換器及其基礎資訊：
  * **重要概念**：無論 Switch 擁有多少個實體埠（例如 8 埠、36 埠），**預設情況下整台 Switch 只會獲得 1 個 LID**。
  * **Base Port 0**：代表交換器硬體**自身（Management Port）**，用於管理與接收 SM 控制指令。

* **`ibnodes`**：綜合列出子網內所有的節點（包含 Hosts 與 Switches）。
* **`ibnetdiscover`**：掃描並輸出整個網路的實體拓撲連接結構。



---

### 3. LFT 查看指令：`ibroute <switch_lid>`

要查看指定交換器的 LFT 內容，直接執行 `ibroute <switch_lid>`：

#### 實機輸出範例解析（以 8 埠 Mellanox Switch 為例）

：

```text
root@ubuntu1:~# ibroute 4
Unicast lids [0x0-0x6] of switch Lid 4 guid ... (InfiniScale-IV Mellanox Technologies):
  Lid   Out Port  Destination Info
0x0001    002   : (Channel Adapter portguid ... : 'ubuntu1 HCA-1')
0x0002    004   : (Channel Adapter portguid ... : 'ubuntu2 HCA-1')
0x0003    006   : (Channel Adapter portguid ... : 'ubuntu3 HCA-1')
0x0004    000   : (Switch portguid ... : 'InfiniScale-IV Mellanox Technologies')
4 valid lids dumped

```

* **LID 1 (ubuntu1)**：對應 **Port 2**。
* **LID 2 (ubuntu2)**：對應 **Port 4**。
* **LID 3 (ubuntu3)**：對應 **Port 6**。
* **LID 4 (Switch 本身)**：對應 **Port 000**（代表連往交換器自身管理介面）。



### 4. 實體拓撲對應關係 ASCII 圖

```text
               +--------------------------------------------+
               |        InfiniBand Switch (LID 4)           |
               |                                            |
               |   [ Port 0: Switch Management (Local) ]    |
               +-------+--------------+--------------+------+
                       | Port 2       | Port 4       | Port 6
                       |              |              |
                       v              v              v
               +---------------+ +---------------+ +---------------+
               |   Ubuntu 1    | |   Ubuntu 2    | |   Ubuntu 3    |
               |    (LID 1)    | |    (LID 2)    | |    (LID 3)    |
               +---------------+ +---------------+ +---------------+

```

* 當 Ubuntu 1 (LID 1) 想送資料給 Ubuntu 3 (LID 3) 時，交換器收到封包辨識 Destination 為 `0x0003`，查表確認為 Port 6，直接硬體旁路轉發至 Ubuntu 3。

## Two Switch 

### 1. 網路變更與最新拓撲架構

* **新增設備**：
* 原有交換器：8 埠 Switch（LID 4）。
* 新增交換器：36 埠 Mellanox SwitchX（LID 5）。


* **實體線路調整**：
* **Switch 間互聯（ISL）**：8 埠 Switch 的 **Port 8** 直連至 36 埠 Switch 的 **Port 1**。
* **節點搬移**：Ubuntu 3 從原本的 8 埠 Switch 拔下，改插至 36 埠 Switch 的 **Port 2**。



#### 拓撲結構 ASCII 圖

```text
      +-------------------------------------------------------------+
      |               36-Port SwitchX (LID 5)                       |
      +--------------+-------------------------------+--------------+
                     | Port 1                        | Port 2
                     | (ISL 連接線)                  |
                     v                               v
      +--------------+---------------+       +---------------+
      |    8-Port Switch (LID 4)     |       |   Ubuntu 3    |
      +-------+--------------+-------+       |    (LID 3)    |
              | Port 2       | Port 4        +---------------+
              |              |
              v              v
      +---------------+ +---------------+
      |   Ubuntu 1    | |   Ubuntu 2    |
      |    (LID 1)    | |    (LID 2)    |
      +---------------+ +---------------+

```

---

### 2. 拓撲偵測與分析指令

* **`ibhosts`**：確認 3 台運算主機（Ubuntu 1、2、3）皆正常在線。
* **`ibnodes`**：確認子網內共有 5 個節點（3 台 Host + 2 台 Switch：LID 4 與 LID 5）。
* **`ibnetdiscover`**：
  * 掃描並傾印整個 Fabric 中所有連線與連接埠關係。
  * **實務技巧**：當大型網路節點數量龐大時，手動解讀文字輸出較吃力，可將 `ibnetdiscover` 輸出內容交由文字或視覺化工具自動生成結構拓撲圖。



---

### 3. 路徑追蹤實測：`ibtracert <src_lid> <dst_lid>`

如同傳統乙太網的 Traceroute，`ibtracert` 可驗證資料在交換器晶片轉發表（LFT）中的實際傳遞路徑：

#### 案例一：同交換器內通訊（Ubuntu 1 $\rightarrow$ Ubuntu 2）

* **指令**：`ibtracert 1 2`
* **路徑**：

$$\text{Ubuntu 1 (HCA)} \xrightarrow{\text{進}} \text{Switch LID 4 (Port 2)} \xrightarrow{\text{出}} \text{Switch LID 4 (Port 4)} \xrightarrow{\text{進}} \text{Ubuntu 2 (HCA)}$$


* **特徵**：僅經過單一交換器（1-hop switch），未跨越 ISL 連接線。

#### 案例二：跨交換器通訊（Ubuntu 1 $\rightarrow$ Ubuntu 3）

* **指令**：`ibtracert 1 3`
* **路徑**：

$$\text{Ubuntu 1} \rightarrow \text{Switch LID 4 (Port 2 進 / Port 8 出)} \xrightarrow{\text{ISL}} \text{Switch LID 5 (Port 1 進 / Port 2 出)} \rightarrow \text{Ubuntu 3}$$


* **特徵**：封包穿越了兩台交換器，清楚呈現多層架構下的端到端逐跳轉發路徑。

---

### 4. 常用拓撲診斷指令速查

| 指令 | 核心用途 |
| --- | --- |
| **`ibhosts`** | 列出子網內所有的運算節點 (HCA) |
| **`ibswitches`** | 列出子網內所有的實體交換器 |
| **`ibnodes`** | 綜合列出所有主機與交換器節點及其 LID |
| **`ibnetdiscover`** | 探索整個網路拓撲，輸出實體連接線路清單 |
| **`ibtracert <src> <dst>`** | 根據各交換器 LFT 追蹤兩節點間的端到端轉發路徑 |

## Routing Algorithms

### 1. 什麼是路由演算法？

* **核心定義**：定義資料在主機與交換器之間**如何選擇路徑**的邏輯規則。
* **決策大腦**：由控制平面的 **Subnet Manager (SM / OpenSM)** 負責計算與配置。
* **預設演算法**：若管理者未手動配置任何演算法，OpenSM 預設會採用 **MinHop**。

---

### 2. 核心對比：Topology vs. Routing Algorithm

| 比較維度 (Aspect) | 網路拓撲 (Topology) | 路由演算法 (Routing Algorithm) |
| --- | --- | --- |
| **本質是什麼 (What it is)**<br> | **網路實體結構 (Network structure)**<br> | **路徑選擇邏輯 (Path selection logic)**<br> |
| **關注核心 (Focus)**<br> | **實體連線方式 (Connections)**<br> | **流量傳輸流向 (Traffic flow)**<br> |
| **具體範例 (Example)**<br> | Fat-tree、Rail-optimized、Torus 3D、DragonFly+ | MINHOP、UPDN、Fat-tree、Adaptive Routing |
| **由誰定義 (Who defines it)**<br> | **網路架構設計與佈線 (Network design)**<br> | **子網管理器 (Subnet Manager / SM)**|

> **重要澄清**：**Fat-Tree 既是拓撲名稱，也是路由演算法名稱**。可以在實體的 Fat-Tree 拓撲之上運行專屬的 Fat-Tree 路由演算法，兩者層次不同，切勿混淆。

---

### 3. 常見的 4 大路由演算法概覽

1. **MINHOP（Minimum Hop）**

    * **預設演算法**。
    * 計算並選擇經過交換器跳數（Hop）最少的路徑；若有多條最短路徑，則會嘗試進行簡單的負載分散。


2. **UPDN（Up/Down）**

    * 專為避免死鎖（Deadlock-free）設計的經典演算法。
    * 規則：封包必須「先往上走（Up），再往下走（Down）」，嚴格禁止在往下到達某一階層後又往上折返，從根本上打破環路依賴。


3. **Fat-Tree（專用樹狀路由演算法）**

    * 專門針對對稱且無阻塞的 **K-ary N-tree (Fat-Tree)** 實體拓撲最佳化。
    * 能精確平衡 Leaf 與 Spine 交換器之間的上下行鏈路負載，達成極致的對稱平衡與無死鎖。


4. **Adaptive Routing（動態自適應路由）**

    * **AI / HPC 關鍵技術**：在大規模平行運算與高頻寬無損網路中扮演核心角色。
    * 突破傳統靜態路由只能走單一路徑的限制，交換器能根據即時的**埠口壅塞程度、隊列長度與鏈路負載**，由硬體晶片動態決定最佳轉發路徑，大幅消除網路微暴流（Microburst）與長尾延遲。
  
## MINHOP Routing


### 1. 什麼是 MinHop？

* **核心定義**：MinHop 演算法的核心原則是「永遠選擇交換器跳數（Hop）最少的第一條可用最短路徑」（Always picks least number of hops, first available shortest path）。
* **系統預設值**：在 OpenSM 中，如果管理者沒有手動指定任何路由演算法，系統預設就會直接使用 MinHop。

---

### 2. 圖解選路邏輯分析

<img width="888" height="596" alt="image" src="https://github.com/user-attachments/assets/c2417b03-c6b2-43ed-be1f-ba7208da78d2" />

圖展示了一個典型的 Leaf-Spine 架構，當最左側的 **Source Host** 欲傳輸資料給最右側的 **Destination Host** 時：

* **傳統上行路徑（非 MinHop 最優解）**：
若封包走標準的 Leaf $\rightarrow$ Spine $\rightarrow$ Leaf，中間需要穿越 3 台交換器（跳數 = 3）。


* **MinHop 實際選中的路徑（藍色虛線）**：
由於中間的 Leaf 交換器同時與兩側的主機或鏈路相連，只需經過中間這台交換器即可直接抵達目標主機，整體**僅需穿越 1 台交換器（Minimum Hops = 1）**。


* **選路結果**：MinHop 會無條件選擇中間這台交換器作為唯一轉發路徑。



---

### 3. MinHop 的兩大核心缺點與挑戰

1. **缺乏壅塞感知（No Congestion Awareness）**

  * **易形成單點過載**：演算法完全不關心特定交換器或鏈路上目前的即時流量負載。
  * 當多對主機同時進行大流量傳輸時，如果它們的最短路徑都剛好經過同一台交換器，所有流量會全部強行灌入該節點，導致該交換器瞬間飽和（Saturation Point）、造成嚴重壅塞。


2. **忽略鏈路頻寬與品質差異（Other Paths Ignored Even If Better）**

  * MinHop 只單純計算「跳數」，不考慮鏈路的實際物理頻寬。
  * **舉例**：即使經過 1 跳的鏈路只有 10 Gbps，而經過 2 跳的替代路徑具備 40 Gbps（或更高）的充裕頻寬，MinHop 依然會固執地選擇 10 Gbps 的慢速路徑，白白浪費更好的網路資源。

## UPDN Routing

### 1. 什麼是 UPDN 路由？

* **核心黃金法則**：流量必須**先往上走（UP，朝向頂層 Spine 交換器）**，接著**再往下走（DOWN，朝向目標主機）**。
* **嚴格限制**：一旦封包開始往下走（Down），就**絕對不允許再次往上走（Never go up again）**。徹底禁止 `Up -> Down -> Up` 的鋸齒狀（Zig-zag）路徑。

---

### 2. 圖解選路邏輯與控制機制

對比先前的 MinHop 演算法，在同一個網路拓撲中：

* **嚴格遵循階層（Strictly follows hierarchy）**：
封包從左下角的 **Source Host** 出發後，不會走中間 Leaf 交換器的水平捷徑，而是嚴格按照階層：

$$\text{Source Host} \xrightarrow{\text{UP}} \text{左側 Leaf Switch} \xrightarrow{\text{UP}} \text{頂層 Spine Switch} \xrightarrow{\text{DOWN}} \text{右側 Leaf Switch} \xrightarrow{\text{DOWN}} \text{Destination Host}$$



* **集中計算與寫入**：
當管理員在 **Subnet Manager (SM)** 啟用 UPDN 演算法後，SM 會自動計算符合「先上後下」規則的路徑，並將轉發規則燒錄至每一台交換器的記憶體（LFT）中，所有交換器皆強制遵循此規範。



---

### 3. UPDN 路徑 ASCII 圖解

```text
                       +------------+
                       |  Switch 1  |  (頂層 Spine)
                       +------------+
                         *        *
              [ UP ]   *            *   [ DOWN ]
                     *                *
         +------------+              +------------+
         |  Switch 3  |              |  Switch 5  |  (中間層 Leaf)
         +------------+              +------------+
               *                            *
      [ UP ]  *                              *  [ DOWN ]
             *                                *
         +--------+                      +--------+
         | Host 1 |                      | Host 6 |  (底層 Host)
         +--------+                      +--------+
          (Source)                      (Destination)

   [!] 嚴格禁止：Down 之後再轉向 Up（No zig-zag: Up -> Down -> Up）

```

---

### 4. 核心效益

* **徹底消除路由迴圈與死鎖（Prevent Loops & Deadlocks）**：在無損網路（Lossless Network）中，若封包在交換器間形成環狀等待（Credit Loop），會導致整個網路卡死。禁止「下而復上」在拓撲學上直接切斷了形成環路的可能性。
* **流量流向可預測**：強制跨區流量統一匯聚至上層 Spine 交換器再分發，避免了下層 Leaf 交換器因充當跨區中繼站而意外過載。

## Fat-Tree Routing

### 1. 為什麼需要 Fat-Tree 路由？

* **先前演算法的痛點**：先前介紹的 **MinHop** 與 **UPDN** 雖然能找到路徑，但它們只會選定**單一條固定路徑**並一直走到底，無法有效利用實體網路中的多條備援鏈路，導致頻寬浪費。
* **Fat-Tree 的突破**：能識別出從來源端（Source）到目的端（Destination）之間**所有的等價路徑（Equal-Cost Paths）**，並**同時（Simultaneously）** 使用這些路徑來分流傳輸資料。


---

### 2. Fat-Tree 路由的運作機制

* **多重路徑分流（Traffic Splitting）**：
  * 封包可同時經由 **路徑 1（藍色圓點，經過 Spine 1）** 與 **路徑 2（黃色圓點，經過 Spine 2）** 進行傳輸，將流量分散到兩台頂層 Spine 交換器上。(如下 ASCII)

* **雜湊選路（Hashing）**：
  * 演算法透過雜湊（Hashing）計算，決定哪些流量走哪一條等價路徑。
* **核心效益**：
  * 達成**負載均衡（Load Balancing）** 與 **高吞吐量（High Throughput）**，充分利用多條上行鏈路的聚合頻寬。

---

### 3. Fat-Tree 路由路徑 ASCII 圖解

```text
                    +-------------+               +-------------+
                    |   Spine 1   |               |   Spine 2   |
                    +-------------+               +-------------+
                      *         *                   o         o
            [路徑 1] *           *                 o           o [路徑 2]
            (藍點)  *             *               o             o (黃點)
         +------------+         +-------------------+         +------------+
         |   Leaf 1   |         |      Leaf 2       |         |   Leaf 3   |
         +------------+         +-------------------+         +------------+
               *                 o        *                   o
                *          o o o            * * *            o
                 *   o o o                        * * *     o
              +--------+                             +--------+
              | Host 1 |                             | Host 6 |
              +--------+                             +--------+
               (Source)                             (Destination)

   [*] 路徑 1 (藍)：Source -> Leaf 1 -> Spine 1 -> Leaf 2 -> Destination
   [o] 路徑 2 (黃)：Source -> Leaf 2 -> Spine 2 -> Leaf 3 -> Destination

```

---

### 4. Fat-Tree 路由的局限性（為何需要 Adaptive Routing？）

* **靜態雜湊、缺乏即時壅塞感知（No Real-Time Congestion Awareness）**：
  * Fat-Tree 在傳輸開始時就透過 Hashing 決定好路徑，但**無法感知當前 Fabric 內部的即時流量狀況**。
  * 如果路徑 1 已經因為其他任務而非常忙碌（壅塞），而路徑 2 完全閒置，Fat-Tree 依然會機械式地按照既定比例把封包往忙碌的路徑送，無法動態繞開塞車路段。


* **不適合 AI/HPC 的大象流（Elephant Flows）**：
  * 在 AI 模型訓練與 HPC 負載中，充滿了單一連線資料量極龐大的「大象流（Elephant Flows）」。靜態雜湊極易發生碰撞（Hash Collision），導致多條大象流被分配到同一條鏈路上造成嚴重阻塞。
  * 為了解決這個問題，必須依賴下一個單元將介紹的 **Adaptive Routing（動態自適應路由）**。

## Adaptive Routing

### 1. 什麼是 Adaptive Routing？

* **核心定義**：**根據即時網路壅塞狀況（Congestion in real time）動態選擇最佳轉發路徑**。

* **Google 地圖導航比喻**：
  * 開車導航時若遇到施工、事故或嚴重塞車，地圖軟體會即時重新計算並推薦暢通的替代道路。
  * Adaptive Routing 亦然：當原本通行的鏈路因其他大流量（如大象流）而變忙碌時，它會主動避開壅塞路徑，將後續封包導向閒置鏈路。
---

### 2. 圖解選路邏輯分析

* **壅塞發生（Congestion in path，橘紅色圓點）**：
    原本 Source 與 Destination 間走下層的中繼路徑，但因大量流量湧入導致該路徑飽和。


* **傳輸中動態切換（Path can change mid-flow，藍色圓點）**：
    即便資料傳輸正在進行中（Mid-flow），系統偵測到原路徑壅塞後，能立即將流量重新導向上方的 Spine 交換器，透過高階層的替代路徑抵達目標端。



```text
                           +------------+
                           |  Spine 1   |
                           +------------+
                             *        *
              [ 繞行新路徑 ]  *          *  [ 暢通路徑 ]
                  (藍點)    *            *
               +------------+            +------------+
               |   Leaf 1   |            |   Leaf 3   |
               +------------+            +------------+
                     *                          *
            [ 新路徑 ]*                          * [ 抵達目的地 ]
                     *                          *
                 +--------+                  +--------+
                 | Host 1 |  x x x x x x x > | Host 6 |
                 +--------+                  +--------+
                  (Source)   [ 原路徑壅塞 ]    (Destination)
                             (橘紅點飽和)

```

---

### 3. 硬體門檻與實作需求

* **需智慧型硬體交換器支援**：傳統舊款交換器無法運行 Adaptive Routing，必須搭配具備硬體級即時隊列與鏈路監控能力的現代交換器（例如 **NVIDIA Quantum 系列** InfiniBand 交換器）。
* **協同控制**：交換器硬體監控即時佇列狀態，並與 Subnet Manager 協同維護多路徑轉發資訊，確保交換器能在毫秒甚至微秒級內完成動態繞徑。

## Change Routing Algorithm

在 Linux 環境下變更 InfiniBand 路由演算法，核心是透過修改 **`opensm.conf`** 設定檔中的 **`routing_engine`** 參數，並重啟 OpenSM 服務來強制全網重新計算 LFT。

具體配置與生效步驟如下：

### 1. 產生與確認設定檔位置

若系統中尚未產生預設的 `opensm.conf`，可先透過目前運行的 OpenSM 傾印一份完整的設定檔：

```bash
# 若無現成設定檔，可直接傾印當前配置
sudo opensm -c /etc/opensm/opensm.conf

```

> **常見路徑差異**：
> * **原生 Linux / OFED 獨立安裝**：`/etc/opensm/opensm.conf`
> * **NVIDIA UFM（Unified Fabric Manager）整合環境**：通常位於 `/opt/ufm/files/conf/opensm/opensm.conf`
> * **Mellanox OS (MLNX-OS) 內部管理型交換器**：通常透過 Switch CLI (`config t` $\rightarrow$ `ib sm routing-engine ...`) 配置，不直接編輯檔案。
> 

---

### 2. 修改路由引擎參數（`routing_engine`）

使用文字編輯器開啟設定檔：

```bash
sudo nano /etc/opensm/opensm.conf

```

找到 `routing_engine` 欄位並修改為所需演算法：

```text
# 可設定單一引擎或多引擎回退（以逗號分隔，若前項失敗則依序嘗試）
routing_engine ftree,minhop

```

**常見演算法參數值**：

* `minhop`：最小跳數演算法（預設值）。
* `updn`：防環路 Up/Down 演算法。
* `ftree`：Fat-Tree 胖樹拓撲專用負載均衡演算法。
* `ar_updn`：支援自適應路由的 Up/Down 引擎（Adaptive Routing Up/Down）。
* `dor`：適用於 Torus 拓撲的維度順序路由（Dimension Order Routing）。

---

### 3. 重啟 OpenSM 服務使設定生效

修改完成後重啟服務，Subnet Manager 會立即進行全網拓撲掃描（Sweep）、依新演算法重算路徑，並下發新的 LFT 到各交換器：

```bash
sudo systemctl restart opensm

```

---

### 4. 驗證新路由演算法與 LFT 更新

執行以下步驟確認演算法是否切換成功並正常運作：

1. **檢查 OpenSM 日誌**：
```bash
sudo grep -E "Routing engine|routing engine" /var/log/opensm.log

```


*確認日誌中顯示類似 `Routing engine 'ftree' has been activated` 或相應的引擎啟動成功訊息。*
2. **確認交換器 LFT 已重新燒錄**：
```bash
ibroute <switch_lid>

```


*檢查各 Port 對應目標 LID 的輸出路徑是否已依照新演算法重新分配。*
3. **追蹤端到端路徑變化**：
```bash
ibtracert <src_lid> <dst_lid>
```

## Why Adaptive Routing

### 1. 為何 AI 工作負載需要 Adaptive Routing？（三大核心支柱）

```text
               +--------------------------------------------------------+
               |        Adaptive Routing 在 AI 工作負載的核心優勢       |
               +--------------------------------------------------------+
                               /            |             \
                              /             |              \
                             v              v               v
                +-----------------+ +----------------+ +------------------+
                | 動態分散大象流  | | 避免靜態負載均衡 | | 平衡低熵固定流量 |
                | (Elephant Flows)| | (Static Hashing)| | (Low-Entropy)    |
                +-----------------+ +----------------+ +------------------+

```

1. **動態分散大象流（Spreads Elephant Flows Across Multiple Paths Dynamically）**

2. **避免靜態流負載均衡造成的熱點壅塞（Avoids Static Flow-Based Load Balancing Hotspots）**

3. **利用即時路徑選擇平衡低熵流量（Balances Low-Entropy Traffic Using Real-Time Path Selection）**


---

### 2. 深入剖析三大核心機制

#### 核心一：化解大象流（Elephant Flows）的衝擊

* **什麼是大象流**：資料量龐大（Large）、持續時間長（Long-lived）且消耗巨大頻寬的傳輸流量。


* **AI 中的具體場景**：
  * **分散式訓練中的梯度同步（Gradient Exchange）**：例如 AllReduce 集合通訊。
  * **模型檢查點儲存（Checkpointing）**：將數十至數百 GB 的權重快速寫入存儲。
  * **大規模資料集載入（Large Dataset Transfers）**。


* **痛點**：流量集中在少數但極具主導性的連線上，會迅速填滿交換器的緩衝區（Switch Buffers），並長時間霸佔鏈路。
* **Adaptive Routing 解法**：突破單一路徑限制，在傳輸過程中動態將同一批龐大資料分流到不同的可用鏈路上，防止單一鏈路被徹底鎖死。

---

#### 核心二：避免傳統靜態雜湊（Static Hashing）的「碰撞悲劇」

* **靜態負載均衡的缺陷**：
  * 傳統 ECMP 或 Fat-Tree 路由多依賴靜態雜湊（Hash 來源/目標 IP 或 Port）。


* **盲目性**：一個流在生命週期內只能死守被 Hash 命中的那一條路徑，完全無視該鏈路當前是否塞車。
* **雜湊碰撞（Hash Collision）**：若演算法剛好將兩條龐大的「大象流」Hash 到同一個 Spine 交換器與鏈路，該路徑會瞬間過載癱瘓，而旁邊平行的其他等價路徑卻完全閒置。
* **Adaptive Routing 解法**：實時監控交換器各 Port 的排隊長度與鏈路負載，一旦檢測到壅塞，自動將後續封包轉向最閒置的路徑，保持整網利用率均衡。

---

#### 核心三：破解低熵流量（Low-Entropy Traffic）的傳輸慣性

* **什麼是網路流量的「熵（Entropy）」**：
  * **熵** 代表系統中混亂、隨機的程度。

* 一般網際網路流量屬於**高熵（High-Entropy）**：成千上萬個使用者連往不同伺服器，連線短暫、來源目標隨機，天然適合傳統 Hash 均勻打散。
* AI 訓練流量則是典型的**低熵（Low-Entropy）**：連線非常規律、高度可預測，而且流量死死集中在固定的幾對 GPU 之間反覆通訊（例如特定 Ring 拓撲上的相鄰 GPU）。
* **痛點**：因為沒有隨機性，低熵流量會不斷命中完全相同的 Hash 結果，反覆擠壓同一批交換器與實體線路。
* **Adaptive Routing 解法**：在這種幾乎沒有變化的重複通訊模式下，硬體主動介入，強制將固定節點間的龐大封包流動態平攤到整個 Fabric 的所有實體線路上，徹底消除因通訊模式規律而產生的硬性熱點。

## LMC(LID Mask Control)

### 1. 什麼是 LMC（LID Mask Control）？

* **核心定義**：允許 InfiniBand 網路中的**單一實體連接埠（HCA 或 Switch Port）同時被指派多個 LID**。

* **類比概念**：如同在乙太網中為同一張實體網卡設定多個 Secondary IP 位址。
* **路徑映射機制**：
    在交換器的線性轉發表（LFT）中，**每一個不同的 Destination LID 都可被 Subnet Manager 計算並映射到不同的實體輸出埠**。因此，當發送端針對同一個實體節點的不同 LID 發送封包時，便能實現在底層實體網路上走**完全不同的實體路徑**抵達目的地。



---

### 2. 數值與 LID 數量的數學關係

LMC 是一個指數值，單一連接埠獲得的連續 LID 數量為 $2^{\text{LMC}}$：

$$\text{分配 LID 總數} = 2^{\text{LMC}}$$

| LMC 設定值 | 單埠分配 LID 數量 | 範例（假設 Base LID 為 10） |
| --- | --- | --- |
| **0** (預設) | $2^0 = \mathbf{1}$ 個 LID | LID 10 |
| **1**<br> | $2^1 = \mathbf{2}$ 個 LID | LID 10, LID 11 |
| **2**<br> | $2^2 = \mathbf{4}$ 個 LID | LID 10, LID 11, LID 12, LID 13 |
| **3** | $2^3 = \mathbf{8}$ 個 LID | LID 10 ~ LID 17 |

---

### 3. 為何使用 LMC？（核心優勢）

1. **路徑多樣性（Path Diversity / Multipathing）**：打破單一固定路徑限制，讓同一節點具備多條通往交換器骨幹的備用與併行線路。

2. **提升吞吐與效能（Improved Performance）**：多條路徑同時承載流量，避免所有通訊擠壓在同一條實體鏈路上。

3. **與 Adaptive Routing 形成黃金組合**：Adaptive Routing 搭配 LMC 提供的多重 LID 路徑，能更靈活地在微秒級內將流量避開壅塞路段，在 Fat-Tree 或 Clos 拓撲中發揮最大綜效。



---

### 4. 設定與驗證方式

* **修改設定檔**：
編輯 `/etc/opensm/opensm.conf`，找到 `lmc` 參數：


```text
lmc 1    # 或設定為 2

```


* **重啟生效**：
```bash
sudo systemctl restart opensm

```


* **查詢連接埠 LID 範圍**：

```bash
ibaddr

```


*(若啟用 LMC，輸出會顯示指派給該連接埠的連續 Base LID 與 LID Range)*。



---

### 5. 重要權衡與副作用（Trade-offs）

不可盲目將 LMC 設得過高（例如 5 或 6，單埠佔用 32 或 64 個 LID）：

* **交換器記憶體與 LFT 膨脹**：
    每增加一個 LID，交換器內部的 LFT（線性轉發表）就必須多維護一筆表項。若叢集內有上千台伺服器，過高的 LMC 會導致 LFT 表項暴增數十倍，耗盡交換器晶片（ASIC）的硬體記憶體資源。
* **Subnet Manager 計算開銷過大**：
    SM 在全網重拓撲掃描時，計算成千上萬個虛擬路徑的開銷顯著拉長，降低故障時的網路收斂速度。
* **最佳實踐**：在具備足夠多等價上行鏈路的胖樹拓撲中，**通常將 LMC 設定為 1 或 2 即為最佳平衡點（Sweet Spot）**。

## Network Congestion

### 1. 網路壅塞的本質、成因與症狀

* **核心定義**：網路傳輸量超過實體頻寬承載上限，引發封包延遲、佇列堆積（Queue Buildup）與整體效能劣化的狀態。
* **4 大主要成因**：
    1. **多發一收 / 多點併發（Multi-Send / Incast）**：多個節點同時向單一節點或交換器埠發送大量資料（如集合通訊中的 AllGather 或梯度聚合）。
    2. **熱點效應（Hotspot）**：關鍵資源（如集中式儲存節點）被所有運算節點同時密集存取。
    3. **超額配比過高（Oversubscribed Link）**：非 1:1 的收斂比設計，導致上行頻寬低於下行總頻寬。
    4. **緩衝區極限（Buffer Limit）**：交換器 ASIC 的實體封包緩衝空間有限，無法長期承受突發流量堆積。

* **顯著症狀**：延遲暴增、封包重傳（或因 Credit 耗盡導致鏈路暫停）、吞吐量暴跌，最終導致昂貴的 GPU/CPU 算力處於飢餓空等狀態（GPU Underutilization）。

---

### 2. AI / HPC 場景下的致命影響

在分散式深度學習中，各節點需要頻繁進行權重與梯度同步：

* **掉隊者節點（Straggler Nodes）**：少數通訊路徑因塞車延遲，導致被分派到該路徑的 GPU 落後，迫使整個叢集停下等待同步（障礙同步 Barrier Synchronization）。
* **降低叢集有效算力（MFU 下降）**：網路壅塞直接拉長全域 AllReduce 時間，拖垮整體訓練吞吐與叢集利用效率。



---

### 3. NVIDIA Mellanox 交換器消除壅塞的 4 大技術支柱

InfiniBand 的核心哲學是 **「事前主動預防，而非事後被動反應（Prevents congestion instead of reacting to it）」**：

| 技術機制 | 運作原理與功能 |
| --- | --- |
| **Adaptive Routing (自適應路由)**<br> | 實時監測各埠負載，動態將大流量與封包打散到平行的閒置鏈路，主動繞開塞車熱點。 |
| **Congestion Control (擁塞控制 / ECN)**<br> | 當交換器排隊超過閾值時，標記並向發送源端回傳顯式通告（Explicit Notification），源端網卡硬體自動降速（Rate Reduction），在壅塞惡化前平抑流量。 |
| **QoS & Virtual Lanes (服務品質與虛擬通道)**<br> | 透過 QoS 劃分優先級，並利用實體鏈路上切分的多條邏輯通道（VLs）進行硬體隔離，確保高優先級控制或關鍵同步流不受一般流量阻塞。 |
| **Shared Buffer (動態共享緩衝區)**<br> | 交換器打破傳統固定緩衝區劃分，將全晶片 Buffer 形成共享池，可隨時彈性調配給突發流量（Microburst）的連接埠，吸收突發流量峰值。|

---

### 4. 壅塞問題排查與驗證診斷步驟

若在大規模叢集中懷疑網路出現壅塞或 Credit 暫停，可依循以下順序檢查：

1. **檢查鏈路層 Credit 暫停計數器**：
    執行以下指令檢查是否有交換器或 HCA 正在送出 `Wait` 訊號（導致 Head-of-Line Blocking）：
    ```bash
    perfquery -x <LID> <PORT>
    ```

*重點觀察 `PortXmitWait` 與 `PortRcvCon_BufExceeded` 計數器是否持續遞增。若 `PortXmitWait` 快速上升，代表該埠因下游緩衝區滿載而無法發送封包。*

2. **掃描全網擁塞與錯誤點**：
    執行網管全面性診斷工具：
    ```bash
    sudo ibdiagnet -pc -r

    ```
*檢查產出的 `ibdiagnet2.pm` 與日誌，搜尋標註為 Congestion 或 Buffer Overrun 的交換器實體埠號。*

3. **確認 OpenSM 擁塞控制功能已啟用**：
    檢查 `/etc/opensm/opensm.conf`：
    ```text
    congestion_control TRUE

    ```
## Credit Loops


### 1. 什麼是信用迴圈（Credit Loop）？

* **核心定義**：當多個交換器形成環狀路徑（Cyclic Path），且各交換器**彼此循環等待對方的緩衝區信用額度（Buffer Credit）** 時，導致整個循環路徑上的傳輸徹底卡死，形成網路層級的死鎖（Deadlock）。
* **無損機制（Lossless）的雙面刃**：
  * InfiniBand 採用基於 Credit 的鏈路級流量控制（Credit-Based Flow Control）：發送端網卡或交換器**必須先拿到接收端回傳的 Credit，確認對方有空閒 Buffer，才准許發送封包**。
  * **信用卡比喻**：信用卡有固定的消費額度上限，刷滿後必須等還款（釋放空間）才能繼續使用。當多台交換器的 Buffer 通通塞滿，而釋放 Buffer 的前提又是「下游必須先清空 Buffer 給我 Credit」時，一旦形成閉環，所有設備將陷入永久等待。

---

### 2. 圖解 Credit Loop 的形成過程（雙流交叉閉環）

片中以兩條相反且交叉的流（Flow 1 與 Flow 2）演示了閉環死鎖的產生：

#### 第一條流（Flow 1，粉紅色路徑）

* **路徑**：$\text{Host A} \rightarrow \text{Switch 1} \rightarrow \text{Spine 1} \rightarrow \text{Switch 3} \rightarrow \text{Host F}$

* **等待關係**：
  * Switch 1 等待 Spine 1 釋放 Credit。
  * Spine 1 等待 Switch 3 釋放 Credit。

#### 第二條流（Flow 2，反向交叉流，藍色路徑）

* **路徑**：$\text{Host F} \rightarrow \text{Switch 3} \rightarrow \text{Spine 2} \rightarrow \text{Switch 1} \rightarrow \text{Host A}$

* **等待關係**：
  * Switch 3 等待 Spine 2 釋放 Credit。
  * Spine 2 等待 Switch 1 釋放 Credit。


#### 閉環死鎖依賴圖（Circular Wait Dependency）

將兩條流的等待依賴鏈拼合在一起，就構成了死鎖的典型「$\infty$」字型或環狀閉環依賴：

$$\text{Switch 1} \xrightarrow{\text{等}} \text{Spine 1} \xrightarrow{\text{等}} \text{Switch 3} \xrightarrow{\text{等}} \text{Spine 2} \xrightarrow{\text{等}} \text{Switch 1} \quad (\circlearrowleft \text{死鎖形成})$$

```text
                  [ Spine 1 ] ------------> (等待 Switch 3)
                      ^                            |
                      | (等待 Spine 1)             v
                 [ Switch 1 ]                 [ Switch 3 ]
                      ^                            |
                      | (等待 Switch 1)             v
                  (來自 Spine 2) <------------ [ Spine 2 ]

```

---

### 3. Credit Loop 的三大關鍵認知（Key Takeaways）

1. **觸發條件**：通常發生在網路中存在**兩個以上的循環/交叉流（Circular Flows）** 同時將緩衝區灌滿時。

2. **屬於 Fabric 交換器層級問題，非主機問題**：
    * Credit Loop 的核心是**交換器與交換器之間的 Buffer 相互卡死**（Fabric-level problem），主機端（Host）只是發起端，本身並不直接構成信用迴圈。

3. **影響範圍具備局部精確性（Exact devices in loop）**：
    * 死鎖只會直接凍結**參與該循環閉環的交換器**。
    * 例如叢集內有 100 台交換器，可能只有參與閉環的 4 台交換器完全癱瘓，未涉入該循環路徑的其他交換器與節點仍可運作（直到被 Head-of-Line Blocking 波及）。

## How to avoid Credit Loops

### 避免信用迴圈的 5 大關鍵策略

1. **採用無死鎖路由演算法（Deadlock-Free Routing），避免使用 MINHOP**
    * **UPDN（Up/Down）**：強制執行「先往上走 Spine、再往下走 Destination」的單向規則，嚴格禁止下行後再次折返上行（No Down-to-Up），從根本切斷環狀依賴。
    * **Fat-Tree（ftree）**：針對對稱的樹狀拓撲進行全路徑上下行流量規劃，保證無死鎖。
    * **避免 MINHOP**：MinHop 只盲目尋找跳數最短的路徑，缺乏全域防環邏輯，極易在交叉流量下引發死鎖。


2. **使用自適應路由（Adaptive Routing）平衡壅塞，但不可單獨依賴它防死鎖**
    * **核心定位**：AR 能動態將流量打散至閒置鏈路以減輕熱點，但**無法單獨保證死鎖免疫**。
    * **正確架構**：必須將 AR 運行於無死鎖演算法之上（例如 `ar_updn`），兼具動態分流與邏輯防環。


3. **合理配置虛擬通道（Virtual Lanes, VL）以實現流量隔離**
    * **緩衝區硬體隔離**：在同一條實體鏈路上劃分獨立的緩衝區隊列（如 VL0、VL1、VL2）。
    * **實務效益**：將關鍵運算流量（如 MPI / NCCL）指派至高優先級的 `VL0`，儲存流量（如 NVMe-oF / Lustre）指派至其他 VL。即便儲存流量突發造成緩衝區耗盡，也不會佔用或卡死 `VL0` 的 Buffer Credit。

4. **減少通訊熱點，避免多對一壅塞模式（Reduce Hotspots / Many-to-One）**
    * **避免 Incast 效應**：防止多個節點在同一時間同時向單一節點（如集中式儲存或單一 GPU）發送大量資料。
    * **演算法規劃**：在集合通訊中採用 Ring 或 Tree 等分散式結構，平攤各節點的吞吐壓力。

5. **使用 NVIDIA UFM（Unified Fabric Manager）即時監控 Fabric**
    * **視覺化維運**：透過 UFM 儀表板實時監控全網交換器佇列、鏈路負載、Credit 暫停計數（如 `PortXmitWait`）與異常擁塞事件。
    * **早期預警**：在信用等待演變成全網級別的 Head-of-Line Blocking 或死鎖之前，提早定位並隔離問題埠口。

## Algorithm Coomparson

### 4 大路由演算法綜合對比表

| 評估維度 | MinHop | UpDown (UPDN) | Fat-Tree (ftree) | Adaptive Routing (AR) |
| --- | --- | --- | --- | --- |
| **核心理念** | 尋找跳數最少的最短路徑，忽略壅塞與頻寬。 | 階層式路徑（先上 Spine 再下 Destination），嚴格防環。 | 針對樹狀拓撲，利用靜態雜湊同時使用所有等價路徑。 | 依據即時壅塞與佇列狀態，動態挑選最優路徑。 |
| **路徑選擇** | 單一路徑（Single path）。 | 單一受限路徑（Single constrained path）。 | **多路徑（Multi-path）**，依來源/目的 LID 等進行**靜態雜湊（Hash-based）**。 | **多路徑（Multi-path）**，依即時狀態**動態選路（Dynamic real-time）**。 |
| **路徑可預測性 (Determinism)** | **高度確定**（路徑固定可精確推導）。 | **高度確定**（路徑受限於階層，完全固定）。 | **可預測**（雜湊結果固定，即可推算路徑）。 | **無法預先確定**（隨運行時鏈路負載動態飄移）。 |
| **信用迴圈迴避 (Credit Loop Avoidance)** | ❌ **不保證**（極易受死鎖影響）。 | ✅ **支援保證**（打破循環等待依賴）。 | ✅ **支援保證**（正規樹狀結構天然無死鎖）。 | ⚠️ **需搭配**（通常架構在 UPDN/Tree 邏輯之上）。 |
| **負載均衡能力** | ❌ 無負載均衡。 | ⚠️ 非常有限的負載分散。 | ✅ **靜態負載均衡**（受限於 Hash 分佈）。 | ✅ **動態負載均衡**（實時繞開熱點）。 |
| **壅塞感知 (Congestion Awareness)** | ❌ 無（不採集交換器佇列資訊）。 | ❌ 無。 | ❌ 無。 | ✅ **具備即時壅塞感知**。 |
| **全網利用率 (Fabric Utilization)** | 差（少數鏈路極易飽和，其餘閒置）。 | 普通（受限於階層固定流向）。 | 良好（但 Hash 碰撞時可能失衡）。 | **最佳**（全網鏈路充分且彈性利用）。 |
| **AI / HPC 適用性** | 極差（易引發熱點與死鎖）。 | 普通（適合結構固定的小型叢集）。 | 良好（適用於傳統對稱 HPC 負載）。 | **卓越（AI 大模型訓練必備首選）**。 |
| **最佳流量型態** | 均勻微小流量（Uniform / Low traffic）。 | 穩定預測型流量（Stable traffic）。 | 均勻分佈的多流傳輸（Distributed flows）。 | **大象流（Elephant flows）**與低熵重複流量。 |
| **硬體相容要求** | 零相容要求（全系列交換器通用）。 | 極低（無特殊硬體依賴）。 | 低（拓撲需符合對稱樹狀規範）。 | **高度依賴**（需具備 AR 硬體引擎的現代晶片，如 Quantum 系列）。 |


1. **靜態雜湊 vs. 動態自適應**：Fat-Tree 與 Adaptive Routing 皆支援 Multi-path，但 Fat-Tree 選路後在傳輸期間**完全固定（Static Hash）**；Adaptive Routing 則能**在傳輸中途（Mid-flow）動態改道**。
2. **死鎖免疫首選**：不規則拓撲或通用網狀拓撲選 **UpDown**；正規對稱胖樹拓撲選 **ftree**；絕不可在複雜多交換器網路中單獨依賴 **MinHop**。
3. **AI 叢集首選**：AI 模型訓練中存在極端消耗頻寬的 **大象流（Elephant Flows）**，傳統 Hash 易發生碰撞產生熱點，必須依賴 **Adaptive Routing** 進行微秒級動態避塞。
