# Subnet
## InfiniBand Subnet

**InfiniBand 單一子網（Single Subnet）架構的運作方式、面臨的擴展性瓶頸，以及為何需要跨子網的解決方案（InfiniBand Router）**。

1. 單一 InfiniBand 子網的典型架構

* **實體拓撲**：通常採用多機架連接至 **Leaf Switches（葉交換器）**，再向上彙整至 **Spine Switches（脊交換器）**（即 Fat-Tree 架構）。
* **子網管理器（Subnet Manager, SM）**：
  * InfiniBand 網路的中樞大腦，負責拓撲發現、路徑計算、LID 分配與轉發表記錄。
  * 實務上會部署 **Active SM（主用）** 與 **Standby SM（備用）** 以保證高可用性（HA）。
 
  ![https://www.fibermall.com/blog/whats-special-about-infiniband.htm?srsltid=AU7gw4WFE6b1l3S_iOXlAiMdyW2orESFHSc2m-HSHSzLiu6TXm8sU4ZJ](https://www.fibermall.com/blog/wp-content/uploads/2023/12/InfiniBands-efficient-and-simple-networking-768x319.png)


2. LID 定址機制與容量極限

* **LID（Local Identifier）角色**：子網內每個節點皆由 SM 分配一個 LID，**子網內部路由完全依賴 LID 進行轉發**。
* **定址空間**：
  * LID 格式為 **16-bit**，理論尋址上限為 $2^{16} = 65,536$ 個（範圍 0 到 65535）。
  * 扣除保留地址後，規格上單子網極限約可容納 **48,000 個節點**。


* **真實世界的規模上限**：
  * 理論值與實務完全不同。在實際生產環境中，單一子網建議規模僅約 **2,000 到 10,000 個節點**，超出此規模就會遭遇嚴重的管理與效能天花板。

3. 單一龐大子網面臨的 5 大核心挑戰

  * **LID 空間與硬體資源受限（LID Constraints）**：交換器內部的轉發表（Linear Forwarding Table, LFT）空間有限，節點過多會耗盡硬體表項。
  * **SM 集中式算力瓶頸（Subnet Manager Bottleneck）**：節點數暴增時，SM 在拓撲掃描、動態路徑計算（Routing Algorithm）的計算耗時呈指數級上升。
  * **故障爆炸半徑過大（Massive Fault Domain）**：所有節點共享同一廣播與管理域。若發生鏈路中斷、線路震盪（Flapping）或 SM 故障，整個龐大叢集都會受到重新路徑計算（Re-routing）的連鎖波及。 
  * **網路擁塞（Network Congestion）**：萬卡規模集中在同一子網，跨機架突發流量極易造成緩衝區反壓與擁塞擴散。
  * **異質拓撲整合困難（Heterogeneous Topologies）**：企業內部不同業務叢集可能採用不同的拓撲結構（如 **Fat-Tree、Dragonfly+、3D-Torus**），無法直接硬塞在同一個單一子網內統一路由。

4. 解決之道：InfiniBand Router（跨子網路由器）

為了解決單子網的擴展瓶頸與異質拓撲連接問題，架構必須進行**子網隔離與模組化分割**。下一階段的核心解決方案即為 **InfiniBand Router（IB Router）**，藉由跨子網路由（基於 GID / 全域標識符）在隔離故障域的同時，實現超大規模叢集的互聯。


## InfiniBand Router

1. 什麼是 InfiniBand Router？

  * **核心定義**：連接多個獨立 InfiniBand 子網的**中央連接樞紐**。
  * **主要任務**：在維持各子網獨立隔離性與擴展性的前提下，實現跨子網（Inter-subnet）的資料通訊，並可將不同拓撲（如 Fat-Tree、DragonFly+、Full Mesh）的網路橋接在一起。

2. 實務

* **業界實務現實（Real-World Advice）**：
  * **以 Switch 擴展為主**：在絕大多數中小型甚至大型環境中，擴展網路主要靠堆疊 **InfiniBand Switches** 即可滿足需求。
  * **Router 極少部署**：IB Router 在實務中並不常見，僅出現在極少數超大規模或進階多子網設計中。若純粹為了流量隔離，通常有其他更輕量的替代方案（如 Partitioning/P_Key）。


3. InfiniBand Router 的 4 大核心優勢

    1. **跨子網互聯（Inter-Subnet Connectivity）**
       * 有效橋接多個各自獨立的 InfiniBand 網路，打破單一子網邊界。


    2. **流量與安全隔離（Traffic Isolation & Access Control）**
       * 控制誰能與誰通訊（ACL 存取控制），避免非必要的廣播或跨域流量互相干擾。


    3. **無上限的水平擴展（Scalability）**
       * 新增節點或擴展某一子網時，其拓撲變化不會衝擊到其他子網。


    4. **解耦 Subnet Manager（獨立 SM 管理）**
       * 消除單一 SM 算力瓶頸。每個子網擁有自己獨立的 Subnet Manager，各司其職，避免單一 SM 負載過重造成整個大叢集癱瘓。

4. 關鍵名詞辨析：Subnet vs. Fabric

在技術文檔中常被混淆，兩者有著嚴格的層次劃分：

| 術語 | 定義與範圍 | 路由與管理特徵 |
| --- | --- | --- |
| **Subnet（子網）** | Fabric 內部的**局部路由域**（Routing Domain） | 由單一（組）**Subnet Manager** 統一管理、內部採用 **LID（16-bit）** 進行路由 |
| **Fabric（全域網路）** | 整個 InfiniBand 網路的**完整集合** | 可由**單一子網**構成，也可由**多個子網經由 IB Router 互聯**組合而成 |


![Fabric（全域網路](https://statics.mylandingpages.co/static/aaapycm22qmuab44/image/6b89cfa4ed144a379e034c49b234510f.webp)

## Infinband Packet

1. InfiniBand 封包核心結構

InfiniBand 封包由不同層級的標頭（Headers）、酬載（Payload）以及校驗碼（CRC）組成：

| 欄位名稱 | 全名 | 核心功能與解析 |
| --- | --- | --- |
| **LRH** | **Local Route Header** | **子網內路由標頭**。包含 Source LID 與 Destination LID，負責同一子網內的轉發。 |
| **GRH** | **Global Route Header** | **跨子網全域路由標頭**。包含 128-bit 的 Source GID 與 Destination GID，僅在跨子網路由時存在；子網內傳輸通常不包含 GRH。 |
| **BTH** | **Base Transport Header** | **基礎傳輸標頭**。定義傳輸操作類型（如 RDMA Read/Write、Send）、目標 Queue Pair (QPN)、Partition Key (P_Key) 等。 |
| **DETH** | **Datagram Extended Transport Header** | **資料報擴展傳輸標頭**。主要用於不可靠資料報（UD）或特定管理封包，記錄來源 QPN、傳輸金鑰等。 |
| **Payload** | **資料酬載** | 實際傳遞的資料本體（例如 RDMA 寫入的記憶體內容或 Ping 測試負載）。 |
| **ICRC** | **Invariant CRC** | **不變校驗碼**。在端到端（End-to-End）傳輸過程中保持不變，用於驗證整個封包從發送端到接收端的完整性。 |
| **VCRC** | **Variant CRC** | **可變校驗碼**。在逐跳（Hop-by-Hop）傳輸過程中，每經過一臺 Switch/設備就會重新計算並更新，用於單一鏈路層的錯誤偵測。 |

---

2. ibdump


1. **環境準備**：
  * 伺服器 A（LID 2，同時兼任 Subnet Manager）：執行 `sudo ibping -S` 作為 Server 端等待連線。
  * 伺服器 B（LID 3）：執行 `sudo ibping -s 2` 發起 Ping 請求。


2. **封包擷取（ibdump）**：
  * 使用 Mellanox/NVIDIA 專用工具 `ibdump` 監聽指定 HCA 介面：
  ```bash
  sudo ibdump -d mlx4_0 -p 1 -w IBCapture.pcap
  ```

## Global ID - GID

1. 什麼是 GID（Global Identifier）？

  * **核心定位**：用於在**多個 InfiniBand 子網之間**跨網路由時，唯一標識一個設備介面（HCA Port）的 128 位元位址。
  * **與 LID 的本質區別**：
    * **LID（Local ID，16-bit）**：僅在「單一子網內部」有效，由該子網的 Subnet Manager 分配。
    * **GID（Global ID，128-bit）**：跨子網（Inter-subnet）透過 InfiniBand Router 路由時的必要標識。

2. 比喻

  * **護照比喻（Passport）**：
    * **LID $\rightarrow$ 國內身分證**：在單一國家（子網）內部移動時，只需身分證/門牌即可被識別與導航。
    * **GID $\rightarrow$ 國際護照**：當要跨出國境（跨子網到另一個網路）時，必須持有國際認可的護照才能通關與路由。


  * **完整住址比喻**：
    * **LID**：相當於同一個城市裡的「巷弄門牌號碼」。
    * **GID**：相當於包含「國家名稱 + 城市名稱 + 門牌號碼」的完整跨國通訊地址。

3. GID 的位址結構（128-bit，似 IPv6 格式）

    GID 在格式與表示法上與 **IPv6** 高度相似，由前後兩個 64-bit 欄位組成：

    $$\text{GID (128-bit)} = \underbrace{\text{Subnet Prefix (64-bit)}}_{\text{子網前綴（代表所屬子網）}} + \underbrace{\text{Interface ID / GUID (64-bit)}}_{\text{介面識別碼（代表特定 HCA 連接埠）}}$$

      * **前 64-bit（Subnet Prefix）**：標識設備位於哪一個子網（例如本機範例常見的 `fe80:0000:0000:0000`）。
      * **後 64-bit（GUID / Interface ID）**：通常衍生自 HCA 連接埠的 EUI-64 硬體位址，確保全球唯一性。

4. 終端機常用查詢指令

    三種在 Linux 環境下檢查 GID 與連接埠狀態的指令：

    1. **`ibv_devinfo -v`**：
      * 顯示 HCA 詳細資訊（Verbose 模式），可清楚查看各 Port 的狀態（Active/Down）、MTU 以及完整的 128-bit GID 列表。


    2. **`rdma link show`**：
      * 現代 Linux `iproute2` 提供的 RDMA 管理指令，可查看 RDMA 鏈路狀態與子網資訊。


    3. **`ibaddr`**：
      * 快速回傳目前節點對應連接埠的 GID 與 LID 簡要對照資訊。
  
## GUID vs LID vs GID


### InfiniBand 協定棧與定址對照表

| 協定分層 (Layer) | 層級核心功能 | 定址機制 (Addressing) | 位址大小 (Size) | 指派來源 (Assigned By) | 使用範圍 (Where Used) | 核心目的 (Purpose) | 重要備註 (Key Note) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Upper Layer**（應用層） | 運行應用程式與工作負載 (Runs workloads and applications) | **None**| — | — | — | 運行工作負載 (Runs workloads) | 無 InfiniBand 定址（透過 API/Verbs 操作） |
| **Transport Layer**（傳輸層） | 高效且端到端地搬移資料 (Moves data end-to-end efficiently) | **None (QP)**<br> | — | Application / Verbs API | 端到端通訊 (End-to-end communication) | 識別通訊上下文 (Identifies communication context) | 使用 Queue Pair (QP)，而非位址 |
| **Network Layer** 網路層） | 在網路中選擇路徑 (Chooses path within network) | **GID**<br> | **128 bits**<br> | Subnet Manager + Device | 跨子網 (Across subnets) | 全域路由 (Global routing) | 類似 IPv6 格式，封裝於 GRH |
| **Link Layer**（鏈路層） | 確保節點間可靠的逐跳傳輸 (Ensures reliable hop-to-hop transfer) | **LID** | **16 bits** | Subnet Manager (SM)| 子網內部 (Within subnet) | 局部路由 (Local routing) | 動態指派（隨網路重新設定可能變更），封裝於 LRH |
| **Physical Layer**（實體層）| 透過實體線路傳送位元 (Sends bits over physical wire) | **GUID** | **64 bits** | Manufacturer (出廠硬體燒錄) | 設備 / HCA 連接埠 (Device / HCA port) | 唯一硬體識別碼 (Unique hardware identity) | 永久固定（不可變更）|

### 總結

* **GUID（實體層，64-bit）**：晶片出廠時由製造商燒錄的硬體永久身分證，代表設備或連接埠本身，類似乙太網路的 MAC 位址。
* **LID（鏈路層，16-bit）**：由子網管理器（SM）動態分配，用於**子網內部**的交換與局部路由，記錄在 **LRH (Local Routing Header)** 中。
* **GID（網路層，128-bit）**：結合了子網前綴（64-bit）與設備識別碼（64-bit），格式似 IPv6，用於**跨子網**透過路由器進行全域轉發，記錄在 **GRH (Global Routing Header)** 中。
* **QP（傳輸層）**：傳輸層不使用傳統 IP 位址，而是使用成對的 Queue Pair（發送/接收隊列）作為端到端通訊上下文端點。
