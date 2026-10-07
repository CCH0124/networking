# Scalable Subnet Administration (SSA) 


## 簡介（Introduction）

子網路管理代理（Subnet Administration, SA）在 InfiniBand 架構規格書第 1 卷第 15 章（相容 IBA 1.3 或 1.2.1 標準）中進行了定義。SA 包含查詢（query）與事件轉發（event forwarding）子系統。查詢子系統負責回應子網中端點連接埠的各類查詢，其中最顯著的是路徑記錄（Path Records, PR），但也涵蓋許多其他記錄。事件轉發子系統則負責將 SM 收到的陷阱（traps）與通知轉發給已訂閱的相關方。SA 在邏輯上屬於 SM 的一部分，在 OpenSM 實作中通常與 SM 緊密結合。

由於 SA 本質為集中式架構，因此存在**擴充性問題（scalability issues）**。典型的問題在於當所有節點都想與其他所有節點進行通訊時，會對 SA 產生 $O(N^2)$ 的負載量。這正是 MPI 全對全（all-to-all）通訊時所發生的情況；而當節點內的每個 CPU 核心都發起通訊時情況會更為嚴峻。以一個擁有 40,000 個節點的子網為例，在假設單核心 CPU 的前提下，全對全通訊將產生 16 億條路徑記錄（Path Records）。假設 SA 每秒能處理 50,000 筆路徑記錄查詢，這將需要耗費整整 **9 個小時**。

**可擴充子網路管理代理（Scalable SA, SSA）** 將此轉化為分散式架構問題，透過將計算路徑記錄所需的數據分發下去，讓節點能計算前往另一節點的路徑，並將其快取在運算（客戶端）節點本機端。

SSA 由數個使用者空間（user space）的軟體模組組成。

SSA 構成了一個最多具備 4 層的**分發樹（distribution tree）**。分發樹的頂層是「核心層（Core layer）」，它與 OpenSM 共存。分發樹的下一層是「分發層（Distribution layer）」，負責向外扇出（fan out）至「存取層（Access layer）」。終端/運算節點（ACM）位於分發樹的最底層，並連接至存取層節點。分發樹的規模大小取決於運算節點的總數量。

SSA 將 SM 資料庫沿著分發樹向下散佈至存取節點。存取節點為其底下的客戶端（運算）節點計算「半全域 SA 路徑記錄資料庫（SA path record half-world database）」，並填入 ACM 快取中。「半全域（Half-world）」意味著涵蓋從該客戶端（運算）節點出發，前往 IB 子網中所有其他節點的路徑。

SSA 樹狀架構定義如下圖所示：

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnLj&feoid=00N8Z000003jPco&refid=0EM8Z000003DUYM)

* 架構解析：
    * **Management（管理層）**：Core
    * **Database replication（資料庫複本層）**：Distribution 節點
    * **Data Processing（資料處理層）**：Access 節點
    * **Localized caching（本機快取層）**：Client 節點


針對 40,000 個運算節點的分發樹扇出比例配置如下：

    * 每個 Core 節點配置 10 個 Distribution 節點（$M = 10$）
    * 每個 Distribution 節點配置 20 個 Access 節點（$N = 20$）
    * 每個 Access 節點支援 200 個 Consumer（客戶端）節點（$K = 200$）

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnLj&feoid=00N8Z000003jPco&refid=0EM8Z000003DUYR)

* 細部連線圖

    * 頂層 Master SM/SA 與 Standby SM/SA 分別掛載 SSA plugin；
    * 中間層為 Dist 1.1 至 Dist 1.M（約 10 台），再向下連至 Access 1 至 Access N（每組約 20 台，共 200 台 Access 節點）；
    * 各 Access 節點產生約 2.5MB 的 Half-World PR 資料，分發至底層 Server 內執行的 ACM 快取）


在規模較小的配置中，Core 與 Access 層可以合併；Distribution 與 Access 層也可以合併；甚至可以完全省略 Distribution 層。

**近期 SSA 版本（upstream 0.0.9 / MOFED 3.1 版 0.0.9.1）功能包含**：

    * 支援 IP 位址（IP address support）
    * 支援管理工具（Admin support）


*(補充前述功能說明)*：

    * 核心 IP 支援允許由 SSA ACM 預先填入核心內的 IPv4 ARP 及/或 IPv6 鄰居快取（neighbor caches）。
    * 管理支援包含 `ssadmin` 工具與 SSA 節點中的管理支援。`ssadmin` 工具用於監控、除錯與配置 SSA 各層級：Core、Distribution、Access 與 ACM。
    * 0.0.9 版開始支援 ConnectX-4 以及 Connect-IB（這在先前的 0.0.8 版本中是一項限制）。

**前一 SSA 版本（upstream 0.0.8 / MOFED 3.0 版 0.0.8.1）功能包含**：

    * 基於分發樹負載平衡的 SSA 任意順序初始啟動（Initial SSA bring up）
    * OpenSM 故障切換與接管（failover / handover）
    * 基於通訊端保持活躍（socket keepalive）的非核心節點復原彈性
    * 分發樹重新加入/重新連線機制
    * 存取層的多執行緒路徑記錄（PathRecord）計算

### 總結

* **傳統 SA 的瓶頸與危機**：InfiniBand 的集中式 SA 在大型叢集面臨 $O(N^2)$ 的查詢負載爆發。以 4 萬節點叢集進行全對全通訊為例，集中式處理需耗費長達 9 小時，導致系統啟動與初始化嚴重癱瘓。

* **SSA 核心架構（分層分散式處理）**：
    * **Core 層**：與 OpenSM 整合，集中管理整體拓撲資料庫。
    * **Distribution 層**：負責資料庫的向上/向下同步與廣播複本。
    * **Access 層**：負責分擔計算，為各主機預先算好該節點出發的「半全域路徑記錄（Half-World PR）」。
    * **Client / ACM 層**：運算節點本機，直接快取計算好的路徑資料，讓查詢延遲降為近乎零。

* **超大規模支援實例（40K 節點）**：透過 1:10（Core $\to$ Dist）、1:20（Dist $\to$ Access）、1:200（Access $\to$ Client）的分層架構，將原本不可行的百萬級查詢量化整為零。

* **彈性拓撲部署**：針對中小規模叢集，各層級（如 Core/Access 或 Dist/Access）可合併部署以節省節點資源。

* **進階功能與新硬體支援**：新版納入了核心 ARP/鄰居快取預先填充以加速 IP 通訊、提供 `ssadmin` 命令列監控配置工具，並正式支援 ConnectX-4 與 Connect-IB 等新一代網卡硬體。

## 何時使用 SSA（When to use SSA）

SSA 最初是為大型子網路（4 萬個運算節點）所設計，但也可以部署在具有高 SA 查詢率的較小子網路配置中。

每當目前所使用的 SM 無法承受龐大的 SA 負載時，就應當考慮採用 SSA。這可以透過針對路徑記錄（path records）的 SA 查詢是否發生逾時（timeouts）來判斷。在以主機伺服器為基礎的 SM（host-based SM）上，處理上限通常約為每秒 5 萬筆路徑記錄；而在受管交換器內建的 SM（managed switch SM）上，此處理能力則低得多。

以 4 萬個節點的子網路進行 MPI 全對全（all-to-all）通訊的名義範例來說，原本集中式 SA 每秒能處理 5 萬筆路徑記錄，而在引入 SSA 後，每個 ACM（本機快取代理）都能處理至少該數量的查詢，因此整個子網路層級的處理能力可達到 $40\text{K} \times 50\text{K}$，即每秒 20 億筆路徑記錄。


### 總結

* **適用場景與規模**：專為超大規模子網路（如 4 萬個運算節點）打造，亦適用於 SA 查詢頻率極高、容易造成瓶頸的中小型子網路。

* **採用門檻與指標**：當節點向 SA 請求路徑記錄（Path Records）開始頻繁出現「查詢逾時（Timeouts）」時，即代表現有 SM 已達效能瓶頸，應導入 SSA。

* **不同 SM 架構的處理上限**：
    * **主機型 SM（Host-based）**：每秒極限約 5 萬筆路徑記錄查詢。
    * **交換器內建 SM（Switch-embedded）**：受限於硬體 CPU 資源，處理能力遠低於 5 萬筆/秒。

* **吞吐量爆炸性提升（分散式優勢）**：在 4 萬節點的 MPI 全對全通訊環境中，SSA 透過讓各端點 ACM 獨立分擔快取查詢，將全網的 Path Record 處理能力由單點的 5 萬筆/秒，直接拉升至驚人的每秒 20 億筆（2 Billion PR/s）。