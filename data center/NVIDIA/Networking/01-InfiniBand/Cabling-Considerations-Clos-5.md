# Cabling Considerations for Clos-5 Networks
## 繁體中文翻譯

### 概述 (Overview)

在為 InfiniBand（IB）交換器佈線時，始終建議在配置中保持**一致性（Consistency）與對稱性（Symmetry）**；然而，針對在 Clos-5 或更高階網路架構中使用導引交換器（Director Switches）的場景，**連接埠層級的佈線細節（Port-level cabling details）至關重要**。Clos-5（即 3 層 Fat-Tree）通常是以上層的 Director 交換器作為核心交換器（Core Switches），並搭配下層的 1U 交換器作為 L1（邊緣/Edge）交換器來建置。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnRt&feoid=00N8Z000003jPco&refid=0EM8Z000003DRrB)

(上方為兩台大型 Director Chassis 交換器，下方連接多台 1U L1 交換器，L1 往下再連接終端節點)

在 Clos-5 架構中，基本模型是位於 Director 下方的**每台 IB L1 交換器，都會向每台 Director 交換器發送相同數量的上行鏈路（Uplinks）**。從單一 L1 交換器連至單一 Director 的確切上行鏈路數量，取決於所需的阻塞比（Blocking Level）以及 Director 交換器的總數量。例如，在採用 36 埠交換器 ASIC 技術的無阻塞（Non-blocking）架構中，每台 L1 交換器總共有 18 條上行鏈路，這些鏈路將根據架構規模，平均分配給 1、2、3、6、9 或 18 台 Director。**切勿將 Director 交換器視為每個連接埠都完全相同的「黑盒子（Black Box）」，這一點至關重要**。這項建議與許多光纖通道（Fibre Channel）或乙太網路交換器並無不同，例如在那些網路中，單一乙太網線卡模組內部雖然是無阻塞的，但交換器背板（Backplane）可能具備阻塞性。

一台 IB Director 交換器本質上是一個「箱中 2 層 Fat-Tree（Clos-3 in a box）」**網路，內部由 Spine 模組（Spine Modules）與 Leaf 模組（Leaf Modules）組成，且**這套內部拓撲對子網管理器（Subnet Manager, SM）而言是直接且完全可見的。一個 Leaf 模組包含一個或多個交換器 ASIC。這些 ASIC 各自對外提供若干外部連接埠（例如透過 QSFP 接頭），同時也透過 Director 機箱內部的專屬埠連接至內部的 Spine ASIC。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnRt&feoid=00N8Z000003jPco&refid=0EM8Z000003DRrG)

*(Modular Director Switch 內部結構圖，展示上層 Spine/Fabric Modules、內部 IB 鏈路、下層 Leaf Modules 以及對外的 External Ports)*

舉例來說：

    * 在 Mellanox **FDR Director** 中，一個 Leaf 模組包含 1 個交換器 ASIC，並提供 **18 個外部連接埠**（半寬/Half-Width 模組）。
    * 在 **EDR Director** 中，一個 Leaf 模組則包含雙 ASIC，共提供 **36 個外部連接埠**（每個 ASIC 提供 18 埠，全寬/Full-Width 模組）。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnRt&feoid=00N8Z000003jPco&refid=0EM8Z000003DRrQ)

*(實體機箱外觀對比，標示 FDR Director 的半寬模組單 ASIC 18 埠，與 EDR Director 的全寬模組雙 ASIC 2x18 埠)*

對於從 Director 下方的 L1 交換器拉上來的每條上行鏈路，**必須慎重選擇連接到 Leaf 模組內部的哪一個交換器 ASIC**。這對於實現**頻寬最大化、延遲最小化以及降低擁塞**而言極為重要。

核心問題在於：**對於從特定 L1 交換器連至特定 Director 的 N 條線纜，究竟該將它們連接到哪裡？**


接下來的章節將介紹一套解決方案及其數種變化型，該方法具備以下特點：

* **經過實務驗證（Field-proven）**。
* **便於分析與排錯（Easy to analyze）**。
* **避免意外產生難以除錯的阻塞情況（Avoids inadvertent blocking）**。
* **將流量降至最低，進而減少 Director Spine ASIC 上的動態壅塞**。

### 結論

* **Clos-5 與 Director 的本質**：
    * 大型 3 層（Clos-5）IB 網路常以 Director 大型機箱作為 L2/L3 核心層，搭配 1U 交換器作為 L1 Leaf 層。
    * **Director 絕非「黑盒子」**：Director 內部本身就是一個獨立的 2 層 Fat-Tree（Clos-3），內含 Spine 模組與 Leaf 模組，OpenSM 能看清並直接管理裡面的每一顆 ASIC。

* **ASIC 規格與埠位差異**：
    * **FDR Director**：Leaf 模組為半寬，每模組內含 **1 顆 ASIC**，對外提供 18 個外部連接埠。
    * **EDR Director**：Leaf 模組為全寬，每模組內含 **2 顆 ASIC**，對外提供 36 個外部連接埠（每顆 ASIC 分配 18 埠）。

* **精細佈線（Port-Level Cabling）的關鍵性**：
    * 下層 L1 交換器連往 Director 的上行線路，不能隨便「看到空孔就插」。
    * 必須精準規劃線路插在 Director Leaf 模組的**哪一顆具體 ASIC 上**，否則會因流量無法在 Leaf ASIC 局部轉發，而頻繁湧入 Director 背板的 Spine ASIC，進而引發內部阻塞、增加延遲並導致動態壅塞。

## 鄰近組 (Neighborhood Groups)

### 劃分為相同分組 (Identical Division to Groups)

基本概念是**將 L1 交換器劃分為多個分組（稱為低延遲鄰近組 / Low-Latency Neighborhoods）**，每個分組包含 $N$ 台交換器，並將它們連接起來，使**鄰近組內部的流量能夠保留在同一個 Leaf 模組 ASIC 內**（在 Director 內部僅引入 1 次交換器跳數）。*不同鄰近組*之間的流量則需穿越 Director 的 Spine ASIC（在 Director 內部共包含 3 次跳數）。

下圖展示了一個高度簡化的架構範例，包含兩台小型 Director，並將 L1 交換器劃分為三個鄰近組，每個分組各包含兩台 L1 交換器：

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnRt&feoid=00N8Z000003jPco&refid=0EM8Z000003DRrV)

*(展示 Director 1 與 Director 2 內部結構，下方分為 Neighborhood 1、2、3，同組內的 L1 連往 Director 相同的 Leaf ASIC。總共 6 台 L1，分 3 組，每組 2 台)*

作為更貼近實際的範例，假設一個包含 3 台 Director 的無阻塞（Non-blocking）架構，每個 Director Leaf ASIC 通常具備 18 個外部連接埠。每台 L1 交換器可向每台 Director 發送 6 條上行鏈路（Uplinks）。一個鄰近組規模的自然選擇是 **18 台 L1 交換器**。

為了替第一個鄰近組佈線，我們在每台 Director 上配置一組共 **6 個 Leaf ASIC**，並將每個 Leaf ASIC 分別連線至這 18 台 L1 交換器中的每一台。在每台 Director 上，這個由 18 台 L1 交換器組成的鄰近組共佔用 6 個 Leaf ASIC，總計相當於 108 個外部連接埠（$18 \times 6 = 108$）。下圖展示了針對標記為 E1 到 E18 的 L1（Edge）交換器實現此目標的一種佈線方式：

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnRt&feoid=00N8Z000003jPco&refid=0EM8Z000003DRra)

*(展示 6 個 Leaf ASIC 的 18 個連接埠映射，每個 ASIC 上整齊接入 E1 至 E18 的線路)*

我們可以透過挑選另外 18 台 L1 交換器，並在兩台（或各台）Director 上配置另外 6 個 Leaf ASIC，依此類推繼續增加鄰近組。由於剩餘的 L1 交換器可能不足 18 台，最後一個鄰近組可能會不完整，但佈線方式完全相同。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnRt&feoid=00N8Z000003jPco&refid=0EM8Z000003DRrk)

*(實體機箱的模組分配示意圖，標記不同色塊代表 Neighborhood 1 到 Neighborhood 6 所分配的區域)*

> **注意：**
> * 在特定 Leaf ASIC 內部選擇使用哪些連接埠並不重要，但**在各鄰近組內部與跨鄰近組之間保持一致性**，能讓日後的故障排除與容量擴充更加容易。
> * 針對特定鄰近組選擇具體哪 6 個 Leaf ASIC 並不重要，但**讓它們彼此相鄰**（或具備某種明顯的規律）將有助於後續維護管理。
> 

### 總結

* **核心目標：打造「低延遲鄰近組（Neighborhood）」**
    * **組內通訊（1-Hop 極低延遲）**：同一個鄰近組內的 L1 交換器，其上行線路全數接進 Director 的**同一個 Leaf ASIC**。組內節點互傳時，封包在 Director 底層 Leaf 模組就直接掉頭轉發，**完全不經過 Director 內部的 Spine 背板**（僅 1 跳），延遲最低。
    * **跨組通訊（3-Hop 骨幹轉發）**：只有跨越不同鄰近組的流量，才會向上送進 Director 的 Spine ASIC 進行核心交換（共 3 跳：Leaf $\to$ Spine $\to$ Leaf）。

* **精準佈線計算範例（以 3 台 Director、每 ASIC 18 埠為例）**：
    * **每組大小**：最適規模為 **18 台 L1 交換器**（E1 ~ E18）。
    * **上行分配**：每台 L1 上行總頻寬平均分配至 3 台 Director，因此每台 L1 會拉 6 條線到每台 Director（$18 \div 3 = 6$）。
    * **Director 模組配置**：每台 Director 拿出 **6 顆 Leaf ASIC** 專門對接此分組，每顆 ASIC 提供 18 個外部埠，恰好各插一條線連往 E1 至 E18（$6 \text{ ASIC} \times 18 \text{ 埠} = 108 \text{ 條線}$），形成完美對稱的無阻塞連接。

* **現場工程維護準則**：
    * **佈線一致性（Consistency）**：強烈建議保持埠位對應規格化（例如 ASIC 上的第 1 埠永遠接 E1、第 2 埠永遠接 E2），這能大幅降低維護、查線排錯與未來擴充的複雜度。
    * **實體相鄰擺放**：同一鄰近組所屬的 6 顆 Leaf ASIC 應盡量選擇實體槽位連續相鄰的模組，便於視覺化識別與管理。

## 雙 Director 架構下的最後一個鄰近組範例 (The Last Neighborhood Example with two Directors)

前述方案的一個含義是：Leaf ASIC 的數量應該要是 6 的倍數。如果最後一個鄰近組僅包含例如 **3 台 L1 交換器**，這 3 台交換器朝向 Leaf 端共有 18 個連接埠。在此範例中，我們假設有 **2 台 Director**，每台 Director 應處理來自每台 L1 的 18 條線纜的一半：$3 \text{ 台 L1 交換器} \times 9 \text{ 埠} = \mathbf{27 \text{ 個連接埠}}$。按照前一節範例的相同邏輯，針對 2 台 Director，一個鄰近組的標準 Leaf ASIC 選擇數量本應為 9 顆。然而，配置 9 顆 Leaf ASIC 會產生許多閒置的空連接埠，進而增加硬體成本。本節將探討一些讓最後一個鄰近組使用較少 Leaf ASIC 的方案。

假設在組建完多個完整的 18 台交換器鄰近組後，剩餘了 **3 台 L1 交換器**。來自這 3 台交換器的上行鏈路在每台 Director 端需要 27 個連接埠，因此在每台 Director 上只增購 2 顆額外的 Leaf ASIC（共 36 個連接埠），而非直接增加一整組（9 顆或更多）ASIC。此時，您可以依據以下規則分配來自這 3 台 L1 交換器的上行線路：

* **每顆 Leaf ASIC 必須連接來自每台 L1 交換器相同數量的線纜。**


遵循此規則可確保在任何 Leaf ASIC 上都不會產生鄰近組內部的阻塞（Intra-neighborhood blocking）。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnRt&feoid=00N8Z000003jPco&refid=0EM8Z000003DRrp)

*(圖示：展示 A、B、C、D 四種佈線接孔範例)*

* **A) 獨立的 1:1 鄰近組 (Separate 1:1 Neighborhoods: E1/E2, E3)**

* **B) 5:4 鄰近組 (5:4 Neighborhood)**

* **C) 1:1 鄰近組 (1:1 Neighborhood)**

* **D) 1:1 鄰近組 (1:1 Neighborhood)**


---

#### 佈線範例 A (Wiring Example A)

可以將 18 條線纜全部連接在單一 ASIC 上，這會為其中 2 台 Leaf 交換器建立一個鄰近組。這種接法可以運作，但其影響是：E1 與 E2 之間的通訊，和 E3 與其他所有人之間的通訊，會存在**不一致的延遲（Inconsistent latency）**。範例 A 的第二個問題是**失去了冗餘度（Redundancy）**，該 Leaf 插卡成為了 E3 的單一故障點（SPOF）。

#### 佈線範例 B (Wiring Example B)

在 InfiniBand 中進行非對稱佈線（Wiring asymmetrically）會產生極難診斷的問題。表面上看，您可能認為每台 L1 的 9 個連接埠是均勻分佈在 2 顆 ASIC 上。然而，非對稱性會在 2 顆 Leaf 之間的 Fabric 中引入熱點（Hot spots）。上方的 Leaf ASIC 接了 $\text{E1}=5$ 條線、$\text{E2}=4$ 條線、$\text{E3}=5$ 條線；下方的 Leaf ASIC 則接了 $\text{E1}=4$ 條線、$\text{E2}=5$ 條線、$\text{E3}=4$ 條線。這會在 E1-E2 以及 E2-E3 之間產生 **5:4 的比例失衡**。這 5 條線的連接會允許比 4 條輸出線所能乘載更多的流量湧入 ASIC，進而造成瓶頸。

#### 佈線範例 C (Wiring Example C)

雖然範例 C 的接線看起來並不美觀，但它**完全符合所有要求**。它在每顆 ASIC 內部皆維持了對稱性，同時也提供了冗餘性。然而，剩餘的 9 個連接埠若不重新引入非對稱性，將無法被額外利用。

#### 佈線範例 D (Wiring Example D)

範例 D 的接線同樣**完全符合所有要求**。它在每顆 ASIC 內部維持了對稱性，且提供了冗餘性；然而，剩下的 9 個連接埠若不引入非對稱性，一樣無法被使用。

---

### 解決方案 (Solution)

與其發揮不必要的創意，不如**遵循平衡的佈線模式（Balanced cabling patterns）**。稍微調整前述範例的規模：您可以採用 **3 顆額外的 Leaf ASIC（共 54 埠）** 來對接 **3 台 L1 交換器**（如下方圖示）。

下方圖示展示的設計提供了一個更加輕鬆的解決方案：您只需**將每台 L1 連至每顆 Leaf ASIC 的線纜數量固定為 3 條**（$3 \text{ 台 L1} \times 3 \text{ 條線} = 9 \text{ 埠/ASIC}$）。這種方式若未來要擴充至 6 台 L1 交換器同樣非常簡單（直接將剩餘的 9 埠補滿）。若超出此規模，擴充時才需要進行重新佈線。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnRt&feoid=00N8Z000003jPco&refid=0EM8Z000003DRru)

*(展示 3 顆 ASIC，每顆 ASIC 上平均分配 E1、E2、E3 各 3 條線，留有整齊且對稱的擴充空位)*


### 結論

* **問題背景：邊際餘數的配置難題**
    * 在 2 台 Director 架構下，標準鄰近組需要極多的 Leaf ASIC。當剩餘最後 3 台 L1 交換器時（每台需送 9 條線至單一 Director，總需求 27 埠），若購買標準組數會造成巨額成本浪費與大量閒置連接埠。
    * 若僅採用 2 顆 ASIC（提供 36 埠），則必須在 27 條線與 2 顆晶片之間求取平衡。

* **黃金佈線準則：各 ASIC 對各 L1 必須絕對對稱**
    * **準則**：每顆 Leaf ASIC 連接到各台 L1 交換器的線路數量必須完全一致，才能避免組內局部阻塞。
    * **錯誤示範 A（單晶片集中）**：把部分交換器集中單一晶片，會產生延遲不一致，且讓該模組成為單點故障（SPOF）。
    * **錯誤示範 B（非對稱分配）**：由於 9 無法被 2 整除，若採用 5 條與 4 條的跳線組合（5:4 比例），會導致上行輸入頻寬大於下行輸出頻寬，在晶片內部形成微突發壅塞（Hot spots），且此類問題極難透過網管軟體除錯。
    * **可行替代方案 C / D**：在每顆晶片上為每台 L1 嚴格配置對稱的線路（如 3:3:3），滿足無阻塞與冗餘，但缺點是剩餘的空埠無法被輕易零散利用。

* **官方推薦的最佳實踐 (Best Solution)**
    * **3 顆 ASIC 對稱分配**：額外配置 3 顆 Leaf ASIC，每顆 ASIC 連接來自 E1、E2、E3 各 **3 條線**（每顆 ASIC 用掉 9 埠，共 27 埠）。
    * **效益**：
        1. 完美保持 1:1:1 內部無阻塞與對稱性。
        2. 兼具高可用冗餘架構。
        3. 預留的空間未來可無縫平滑擴充至 6 台 L1 交換器，期間完全不需要拔線重拉。

這張圖片為完整架構圖版本的「專用節點與共享資源（Specialized Nodes and Shared Resources）」，以下為完整的繁體中文翻譯與重點整理：

---

## 專用節點與共享資源（Specialized Nodes and Shared Resources）

先前的討論將所有 L1 交換器視為可互換的。顯而易見地，每個「鄰域」（neighborhood）都可以進行量身規劃，使其包含彼此靠近能獲得最大效益的終端節點。例如，一個鄰域可能包含運算節點與 GPU 節點，或是運算節點與儲存節點。雖然一般而言將鄰域配置得越大越好，但有時採用較小的鄰域方案會更理想，因為這能最大程度減少對「感知網路拓撲的工作排程」（topology-aware job scheduling）之需求。

Clos-5 網路架構（Clos-5 fabric）通常包含會被多個鄰域同時存取的節點，例如納入儲存節點與儲存閘道器時（SwitchX 閘道器即為一個特例）。
下圖是先前展示的高度簡化鄰域圖之變體。圖中現在加入了一個用於「**共享資源**」（例如儲存設備）的「特殊」鄰域。此鄰域在每個 Director 交換器上都擁有**自己的 Leaf ASIC**；在實際部署中，它甚至可以在每個 Director 上佔用多個 Leaf ASIC。連接到這些 ASIC 的 L1 交換器也可能不止一台。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnRt&feoid=00N8Z000003jPco&refid=0EM8Z000003DRm7)

*架構圖解析：*

* 頂層為 Director 1 與 Director 2，內部皆由 Spine ASIC 連接至下層 Leaf ASIC；
* 最右側的 Leaf ASIC 透過纜線束 W 與 X 連接至「SharedResources」（共享資源鄰域）的 L1 交換器；
* 「Neighborhood 1」與「Neighborhood 2」各透過獨立的 L1 交換器連接終端節點（如 A、B 與 C、D），共享資源鄰域則連接儲存節點 S）

### 總結

* **鄰域客製組合**：鄰域能依運算與通訊需求量身打造，將需要緊密低延遲通訊的節點群組化（如運算 + GPU、運算 + 儲存）。
* **鄰域大小的權衡考量**：雖然大鄰域有利於規模效應，但縮小鄰域規模能顯著降低工作排程系統對網路拓撲感知（topology-aware scheduling）的複雜度。
* **多鄰域共享架構設計**：在 Clos-5 架構下，供多個運算群組共同存取的服務（如儲存節點、閘道器），會被抽離並規劃為獨立的「共享資源鄰域」。
* **獨立專屬的交換硬體配置**：共享資源在每台 Director 交換器內部都有專屬的 Leaf ASIC（可視需要配置多顆），並透過專用纜線束（如圖中的 W 與 X）連接專屬的 L1 交換器，確保多個運算鄰域跨區存取時具備充足頻寬。


## 共享資源節點特性（Shared Resource Node Properties）

* 所有其他鄰域皆可透過 Director 交換器的 Spine ASIC 存取它。
* 每個 Director 都能為往返此特殊鄰域的流量提供大量的 Spine 頻寬，該流量只會與其他跨鄰域流量競爭。
* 往返共享資源節點的流量通常受限於共享節點本身，而非受限於 Director 交換器。在示意圖中，此頻寬由纜線（線束）W 和 X 以及節點本身（S）的處理能力來表示。
* 此特殊鄰域的規模通常比其他傳統鄰域來得小。

下圖顯示了一台 Director 交換器的接頭面板，其連接了四個運算鄰域（Compute Neighborhoods）以及一個小型「I/O 鄰域」：

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnRt&feoid=00N8Z000003jPco&refid=0EM8Z000003DRs4)

*(圖中標示：Neighborhood 1、Neighborhood 2、Neighborhood 3、Neighborhood 4、I/O Neighborhood、Empty Slots)*

所有其他鄰域對儲存設備的存取都必須經過 Director 的 Spine 層。從各運算鄰域發起的存取是均勻一致的，且各運算鄰域與儲存設備之間的頻寬也是對等的。

**補充說明（Additional notes）**

* 如果 L1 交換器「下方」的總計儲存頻寬較低（例如：使用傳統旋轉式硬碟/磁碟媒體，或是受限於前端效能限制），那麼原本預設數量的 Director 上行鏈路（Uplinks）可能就顯得過度配置（overkill）。相較於我們先前無阻塞（Non-blocking）架構範例中每台 L1 配置 18 條上行鏈路，改為每台 L1 配置 9 條上行鏈路，可能就足以為儲存節點提供足夠的頻寬與備援韌性。雖然連接至每個 Director 的上行鏈路數量仍須保持一致，但這樣可以減少佔用 Director 交換器的連接埠數量。

* 與運算節點不同，資源節點彼此之間所需的內部頻寬通常相對較低。在此類情況下，對於特殊鄰域內部「阻塞（blocking）」的顧慮可以適度放寬。

### 總結

1. **統一跨鄰域存取與頻寬公平性**：所有運算鄰域皆透過 Director 交換器的 Spine ASIC 存取儲存與 I/O 共享資源，享有均勻對等的頻寬與連線路徑。
2. **效能瓶頸在節點本身**：Director 骨幹所提供的 Spine 頻寬充足，通訊瓶頸通常落在共享節點本身（硬體處理能力或實體纜線）而非交換器架構。
3. **超額配比與節省連接埠（Oversubscription）**：若底層儲存媒介速度較慢（如旋轉硬碟），可將每台 L1 交換器的上行鏈路數量減半（例如 18 條降至 9 條），在維持各 Director 連接對稱性的同時，節省昂貴的 Director 連接埠。
4. **放寬內部無阻塞需求**：共享資源節點之間較少發生大規模的「內部節點互傳」，因此該鄰域內部不一定需要嚴格的無阻塞架構，設計彈性較大。

## 降低共享資源的延遲（Lowering Latency to Shared Resources）

先前的圖表展示了一種為共享資源提供通用存取的穩健架構，但共享資源與其客戶端之間需要跨越五個交換器躍點（switch hops）。對於固態硬碟（SSD）或 NVMe 儲存等低延遲資源而言，減少兩個交換器躍點可能帶來顯著的效益。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnRt&feoid=00N8Z000003jPco&refid=0EM8Z000003DRs9)

上圖展示了三個鄰域：

* 最右側的鄰域是如前文所述的「共享資源鄰域」（SharedResources neighborhood）。
* 「鄰域 1」（Neighborhood 1）是傳統的運算鄰域，它如前文所述透過 Director 交換器的 Spine 層來存取共享資源。
* 「鄰域 2」（Neighborhood 2）雖然也是運算鄰域，但它的 Leaf ASIC 同時透過線路 Y 和 Z 連接至共享資源的 L1 交換器。

現在，鄰域 2 到共享節點之間擁有了更短的路徑——從 S 節點到客戶端節點（例如 C 和 D）僅需三個交換器躍點。

**架構限制（Limitations）**

* 從鄰域 2 到 S 節點的頻寬完全由「直連」纜線 Y 和 Z 的數量決定。由於 InfiniBand 路由永遠優先選擇最短路徑，因此從客戶端 C 和 D 通往 S 的其他潛在路徑將永遠不會被使用（因為那些路徑需要五個躍點）。
* 鄰域 1 中的節點也可能會使用這條「直連」路徑，因為這條經過五個躍點的路徑與經過 Director Spine 的路徑長度完全相同。這種資源共享可能並非原先所預期的，但可以透過儲存遮罩（storage masking）來避免：
    * 第一種方案是將 S 節點拆分到不同的 L1 交換器上（例如將部分放入鄰域 1）。
    * 第二種方案是將鄰域 1 的節點直接連接到連向共享資源鄰域的 L1 交換器（最右側的交換器）。
* 為了替纜線 Y 和 Z 提供 Leaf ASIC 連接埠，鄰域 2 中「運算用」L1 交換器的數量必須縮減。例如，鄰域 2 可能只能包含 17 台運算 L1 交換器（及其掛載的運算節點），而非原先的 18 台。



連接共享資源還有其他巧妙（以及不那麼巧妙）的做法，在此不一一贅述。在分析其他替代方案時，請牢記以下幾點：

* IB（InfiniBand）路由永遠選擇最短路徑。
* Clos-5 架構必須採用 Up/Down 路由或 Fat Tree 路由以避免信用循環（credit loops）。這會禁止節點之間許多潛在的最短路徑。詳情請參閱《Understanding Up/Down InfiniBand Routing Algorithm》。

### 結論

* **降低延遲的核心手法**：將特定運算鄰域（鄰域 2）的 Director Leaf ASIC 直接以跳線（Y、Z）連至共享資源的 L1 交換器，讓躍點數從原本的 5 hops 降低至 3 hops，大幅降低存取 NVMe/SSD 等儲存設備的延遲。

* **路徑鎖定與頻寬瓶頸**：因為 InfiniBand 永遠只走最短路徑，鄰域 2 的流量只會走直連通道（3 hops），而不會動用原先走 Spine 的 5 hops 路徑；這意味著直連纜線（Y 與 Z）的數量將成為頻寬的唯一上限。

* **鄰域 1 流量旁路爭奪風險**：鄰域 1 經由 Spine 存取 S 也是 5 hops，因此可能也會被路由演算法引導至鄰域 2 的直連路徑造成搶佔，需藉由儲存遮罩（Storage Masking）或拓撲重組來隔離。

* **硬體連接埠的犧牲代價**：將 Leaf ASIC 的連接埠撥給直連纜線（Y、Z）後，鄰域 2 能接取的運算 L1 交換器數量將會減少（例如 18 台減為 17 台），犧牲了部分運算擴充密度。

* **拓撲設計限制**：在 Clos-5 架構中必須遵循 Up/Down 或 Fat Tree 路由機制以防止 Credit Loops（信用循環/死結），在自行設計非常規直連拓撲時，並非所有幾何上的最短路徑都能被合規啟用。