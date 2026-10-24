# [Doubling all2all Performance with NVIDIA Collective Communication Library 2.12](https://developer.nvidia.com/blog/doubling-all2all-performance-with-nvidia-collective-communication-library-2-12/)

* 分散式 AI 訓練的核心瓶頸：集體通訊（Collective communications）是推薦系統、自然語言處理等現代分散式 AI 訓練中影響效能的關鍵環節。
* NCCL 的核心架構與功能：NVIDIA NCCL 專為 GPU 加速集體運算（如 All-Gather、All-Reduce、點對點收發等）所打造，具備拓撲感知（topology-aware）能力，能在 PCIe、NVLink、InfiniBand 等互連架構及主流公有雲（GCP、AWS）中發揮高頻寬與低延遲特性。

## Combining NVLink and network communication

**結合 NVLink 與網路通訊**

NCCL 2.12 引進的新功能稱為 PXN（即 PCI × NVLink），它能讓 GPU 先透過 NVLink、再透過 PCIe 與同節點上的網路卡（NIC）進行通訊。這取代了過往必須使用 QPI 或其他跨 CPU 協定經由 CPU 轉發的方式（舊方式無法提供完整的傳輸頻寬）。透過這種方式，即使每個 GPU 仍會盡可能優先使用自身的本地 NIC，但在需要時也能直接存取其他 NIC。

GPU 不必在本地記憶體準備緩衝區供本地 NIC 發送，而是透過 NVLink 寫入資料到中介 GPU 的緩衝區上。接著，它會通知管理該目標 NIC 的 CPU 代理程式（CPU proxy）資料已就緒，而非通知自己的 CPU 代理程式。雖然 GPU 與 CPU 之間的同步可能會因為需要跨越 CPU 插槽（Sockets）而稍微變慢，但資料本身僅透過 NVLink 與 PCIe 交換器傳輸，從而保證了最大頻寬。

<img width="1652" height="783" alt="image" src="https://github.com/user-attachments/assets/b1d7d086-7fec-4607-b448-bf3dd4ca9835" />

*（圖 1：導軌最佳化拓撲）*

在圖 1 的拓撲架構中，每台 DGX 系統的 NIC-0 都連接到相同的葉層交換器（L0），NIC-1 連接到相同的葉層交換器（L1），依此類推。這種設計通常被稱為「導軌最佳化（Rail-Optimized）」。導軌最佳化網路拓撲有助於最大化 All-Reduce 的效能，同時將資料流之間的網路干擾降到最低。此外，透過減少導軌之間的連線數量，也能降低網路建置成本。

PXN 運用節點內 GPU 之間的 NVIDIA NVSwitch 連線能力，先將資料搬移到與目的地處於同一導軌上的 GPU，接著直接發送到目的地而無需跨越導軌。這實現了訊息聚合（Message Aggregation）並達成了網路流量的最佳化。

<img width="1704" height="953" alt="image" src="https://github.com/user-attachments/assets/ade640b2-d3b5-4f64-b14f-d953862a842a" />

*（圖 2：從 DGX-A 的 GPU0 傳送訊息至 DGX-B 的 GPU3 之路徑範例）*

在 NCCL 2.12 之前，圖中的訊息需要經過三層網路交換器跳躍（L0、S1 與 L3），這可能會引發網路資源競爭並被其他流量拖慢。而在同對 NIC 之間傳遞的訊息會進行聚合，以最大化有效訊息傳輸率與網路頻寬。


### 重點整理

* **PXN (PCI × NVLink) 核心機制**：NCCL 2.12 推出的 PXN 技術允許 GPU 透過節點內的 NVLink 先將資料寫入中介 GPU，再經由 PCIe 存取其他 NIC 發送，避開 CPU 間（如 QPI 等協定）的頻寬瓶頸。
* **導軌最佳化拓撲（Rail-Optimized Topology）**：不同伺服器（DGX）上相同編號的網卡連接至同一台葉層交換器（Leaf Switch）。PXN 利用節點內的 NVSwitch 將資料先搬移至目標「同軌（Same Rail）」的 GPU 上，直接進行同軌網路傳輸。
* **減少交換器跳躍（Hops）與網路壅塞**：在引入 PXN 之前，跨軌傳輸需在葉層與脊層交換器間跳轉多達 3 次（如 L0 → S1 → L3），容易造成網路競爭；PXN 避免了跨軌（Crossing Rails）傳輸，顯著降低延遲並提升有效頻寬。

## Message aggregation

在採用 PXN 後，給定節點上的所有 GPU 都會將傳往同一個目的地的資料集中搬移到單一 GPU 上。這使得網路層能夠透過實作全新的多重接收（multireceive）函式來聚合訊息。該函式能讓遠端的 CPU 代理程式在所有訊息均準備就緒時，立即將其合併為單一訊息進行傳送。

舉例來說，若某個節點上的一顆 GPU 正在執行 All-to-All（all2all）運算，且預計接收來自遠端節點全部八顆 GPU 的資料，NCCL 就會呼叫帶有八組緩衝區與大小參數的 multireceive。在發送端，網路層便可等待全部八個發送任務皆準備就緒後，一次性發送全部八筆訊息，這對訊息傳輸率（message rate）具有顯著的提升效果。

訊息聚合的另一個面向，在於針對特定目的地，同一個節點內的所有 GPU 現在可以共享連線。這意味著需要建立的連線數量減少了。不過，如果網路繞送演算法原先仰賴大量不同的連線來獲取良好的熵（entropy），這也可能會影響到繞送效率。



### 重點整理

* **多重接收（Multireceive）機制實現訊息聚合**：PXN 讓同節點的多顆 GPU 將前往同一目標的資料集中至單一 GPU，並透過新增的 `multireceive` 函式，讓遠端 CPU 代理在確認資料全數就緒後「一次性合併發送」，大幅提升訊息傳輸率（Message Rate）。
* **連線共享與路由權衡（Trade-off）**：同一節點內的所有 GPU 對於特定目的地會共享連線，有效減少需建立的連線數量；然而，若網路繞送演算法仰賴大量多樣連線來維持良好熵值（Entropy），此機制可能會對繞送效率產生連帶影響。
* **整體通訊優勢**：PXN 不僅顯著縮短了 All-to-All 集體運算的完成時間，也為 All-Reduce 運算在挑選參與 GPU 時帶來更高的配置彈性。

## PXN improves all2all performance

圖 4 顯示 All-to-All 涉及了從每個進程到其餘所有進程的通訊。換句話說，在包含 $N$ 個 GPU 的叢集中，作為 All-to-All 操作一部分所交換的訊息數量為 $\mathcal{O}(N^2)$。

<img width="827" height="337" alt="image" src="https://github.com/user-attachments/assets/a0a61e58-7f46-48e7-94a2-a7cf641aa670" />

*（圖 4：橫跨四個參與進程的 All-to-All 集體通訊操作）*

GPU 之間互相交換的訊息彼此各異，無法使用例如[樹狀（Tree）或環狀（Ring）等最佳化演算法](https://developer.nvidia.com/blog/massively-scale-deep-learning-training-nccl-2-4/)（此類演算法常用於 All-Reduce）。當在數百個 GPU 上運行數十億參數等級的模型時，大量的訊息傳輸可能會觸發網路壅塞、產生網路熱點，並對效能造成不利影響。

如前文所述，PXN 結合了 NVLink 與 PCIe 通訊，減少流經第二層脊層交換器（Spine Switches）的流量，進而最佳化網路傳輸。同時，它透過將最多八筆訊息聚合成一筆的方式提高訊息傳輸率。這兩項改進皆顯著提升了 All-to-All 的運算效能。


###  重點整理

* **All-to-All 的通訊複雜度**：All-to-All（all2all）代表每個進程皆須與其餘所有進程通訊，在包含 $N$ 個 GPU 的叢集中，訊息交換量高達 $\mathcal{O}(N^2)$。
* **無法採用常規聚合演算法**：不同於 All-Reduce 可利用 Tree 或 Ring 演算法進行規約最佳化，All-to-All 中各 GPU 間交換的資料片段互不相同，在數百張 GPU 運行數十億參數模型時，極易引發網路壅塞與熱點（Hotspots）。
* **PXN 帶來的雙重最佳化**：PXN 結合 NVLink 與 PCIe 傳輸，不僅減少了經過第二層脊層交換器（Spine Switches）的流量，更將最多八筆訊息聚合成單一訊息傳送，大幅提升訊息傳輸率並改善 All-to-All 效能。

## all-reduce on 1:1 GPU:NIC topologies

PXN 所解決的另一個問題，是每張網卡（NIC）附近僅配置單一 GPU 的拓撲架構。環狀演算法（Ring algorithm）需要有兩顆 GPU 同時鄰近同一張 NIC。資料必須從網路進入第一顆 GPU，接著透過 NVLink 繞行所有的 GPU，最後再從最後一顆 GPU 離開回到網路中。因此，第一顆與最後一顆 GPU 都必須非常靠近該 NIC：第一顆 GPU 必須能有效率地從網路接收資料，而最後一顆 GPU 則必須能高效率地將資料發送到網路。如果給定的 NIC 附近只有一顆 GPU，就無法順利閉合環路（close the ring），必須改道經由 CPU 傳輸資料，這將嚴重影響效能。

有了 PXN 之後，只要最後一顆 GPU 能夠透過 NVLink 連接到第一顆 GPU，它就可以將資料移動到第一顆 GPU 上。資料隨後從該處發送到 NIC，將所有傳輸完整保留在本地 PCIe 交換器（PCIe switches）之內。

這種情況不僅適用於「每個 PCIe 交換器配置一顆 GPU 與一張 NIC」的 PCI 拓撲，當 NCCL 通訊群組（Communicator）僅包含一部分 GPU 子集時，其他拓撲也會遇到類似情形。以配備 8 顆 GPU 並透過 NVLink 超立方體網格（Hypercube mesh）互連的節點為例（如圖 5）。

<img width="899" height="813" alt="image" src="https://github.com/user-attachments/assets/ea148c35-5c15-48e7-9cf9-e441aa4c04ba" />

*（圖 5：NVIDIA DGX-1 系統中的網路拓撲）*

圖 6 展示了當通訊群組包含系統中所有 8 顆 GPU 時，利用拓撲中可用的高頻寬 NVLink 連線所構建出的一個環狀路徑。之所以可行，是因為 GPU0 和 GPU1 共同擁有存取同一個本地 NIC 的權限。

<img width="964" height="787" alt="image" src="https://github.com/user-attachments/assets/8bbf37a6-abae-49b2-8995-51739a5046ee" />

*（圖 6：NCCL 所採用的環狀路徑範例）*

然而，通訊群組可能僅包含部分 GPU 子集。舉例來說，它可能只包含 GPU 0、2、4 和 6。在此情況下，若不進行跨軌（crossing rails）傳輸，構建環路是完全不可能的：進入該節點且由 GPU 0 接收的環路，必須從 GPU 2、4 或 6 離開，但這些 GPU 並沒有直接存取 GPU 0 本地 NIC（NIC 0 和 1）的權限。

另一方面，PXN 讓構建環路變得可行，因為 GPU 2 可以在透過 NIC 0/1 發送之前，先將資料搬移回 GPU 0。

這種情況在模型平行（Model Parallelism）中十分普遍，取決於模型是如何切分的。例如，若一個模型切分在 GPU 0–3 之間，另一個模型運行在 GPU 4–7 之間，這意味著 GPU 0 和 GPU 4 負責處理模型的相同部分，且系統會建立一個包含所有節點上 GPU 0 和 4 的 NCCL 通訊群組，以便為對應的層執行 All-Reduce 運算。若是沒有 PXN，這類通訊群組便無法有效率地執行 All-Reduce。

在此之前，若想要維持高效率的模型平行，唯一的辦法是將模型切分為 GPU 0、2、4、6 以及 1、3、5、7，這樣 NCCL 子通訊群組才會包含 GPU [0,1]、[2,3]、[4,5] 和 [6,7]，而不是 [0,4]、[1,5]、[2,6] 和 [3,7]。全新的 PXN 功能賦予了您更大的彈性，並簡化了模型平行的應用。


### 重點整理

* **1:1 GPU:NIC 架構下的環狀演算法挑戰**：Ring All-Reduce 演算法需要首尾兩顆 GPU 皆鄰近同一張網卡（NIC），以便資料從網路進入首顆 GPU、經 NVLink 繞行節點內各 GPU 後，再由末端 GPU 離開進入網路。若每個 PCIe 交換器僅有一顆 GPU 連接該 NIC，環狀路徑便無法閉合，過去被迫借道 CPU 轉發而重創效能。
* **PXN 解決局部通訊限制**：在 PXN 的輔助下，末端 GPU 可透過 NVLink 將資料傳回首顆 GPU，再由首顆 GPU 經由本地 PCIe 交換器傳送至 NIC，使所有資料轉發完全保持在 PCIe Switch 內部。
* **子集通訊（Subset Communicator）與模型平行化的解放**：當 NCCL 通訊群組僅包含部分 GPU（例如模型平行化切分成 GPU 0–3 與 4–7，導致通訊子集包含跨節點的 GPU 0 與 4）時，過往無法在不跨軌的情況下閉合環路。PXN 讓 GPU 間可彈性轉移資料以閉合環路，打破了過去為配合通訊效率而必須硬性交錯切分 GPU（如 [0, 2, 4, 6] 與 [1, 3, 5, 7]）的限制，大幅提升模型平行配置的彈性。




