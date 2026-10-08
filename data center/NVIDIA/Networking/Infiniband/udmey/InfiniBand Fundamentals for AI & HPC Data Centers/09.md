# How Nvidia is using RDMA 
## GPUDirect RDMA

1. 技術演進路徑：從 DMA 到 GPUDirect RDMA

* **階段一：本地 DMA（Direct Memory Access）**
  * 本地設備（如 GPU、網卡）在獲得授權後，可**直接存取本地系統記憶體（Host RAM）**，無需 CPU 每次親自搬移資料。


* **階段二：傳統 RDMA（Remote DMA）**
  * 跨主機節點時，透過 InfiniBand、RoCE 或 iWARP 網路，節點 A 可直接讀寫節點 B 的**系統記憶體（Host RAM）**。
  * **痛點與瓶頸**：傳統 RDMA 只能直接存取**主機系統記憶體（Host RAM）**，無法直接存取 **GPU 顯示記憶體（VRAM / HBM）**。若 GPU A 想取得 GPU B 的資料，必須經過以下冗長路徑：

$$\text{GPU A 顯存} \rightarrow \text{主機 A RAM} \rightarrow \text{網路傳輸 (RDMA)} \rightarrow \text{主機 B RAM} \rightarrow \text{GPU B 顯存}$$

```text
+---------------------------------------+             RoCE / InfiniBand             +---------------------------------------+
|                Host 1                 |<=========================================>|                Host 2                 |
|                                       |                                           |                                       |
|  +---------------------------------+  |                                           |  +---------------------------------+  |
|  | RDMA Capable Network Interface  |  |                                           |  | RDMA Capable Network Interface  |  |
|  +---------------------------------+  |                                           |  +---------------------------------+  |
|                                       |                                           |                                       |
|            +------ DMA ------+        |                   RDMA                    |            +------ DMA ------+        |
|            |                 |        |<==========================================+========+==>|                 |        |
|            v                 v        |                                           |        v                 v        |
|     +-------------+    +-----------+  |                                           |  +-------------+   +-----------+  |
|     |   System    |    |   [GPU]   |  |                                           |  |   System    |   |   [GPU]   |  |
|     |   Memory    |    |  Memory   |  |                                           |  |   Memory    |   |  Memory   |  |
|     +-------------+    +-----+-----+  |                                           |  +-------------+   +-----+-----+  |
|                              |        |                                           |                      ^        |
|            [CPU]             |        |                                           |            [CPU]     |        |
|                              |        |              GPUDirect RDMA               |                      |        |
|                              +========+===========================================+======================+        |
+---------------------------------------+                                           +---------------------------------------+
```



這中間依然需要 CPU 介入排程與多次記憶體複製，嚴重拖慢分散式機器學習（ML）模型訓練的擴展性。


* **階段三：NVIDIA GPUDirect RDMA（核心突破）**
  * NVIDIA 對傳統 RDMA 進行擴展，打破了 GPU 顯存與網卡之間的屏障。
  * 實現**跨節點「GPU 顯存 $\longleftrightarrow$ 遠端 GPU 顯存」的點對點直接讀寫**（Peer-to-Peer over Fabric）。
  * 徹底繞過本機與遠端的主機作業系統（OS）、CPU 以及主機記憶體（Host RAM）。


 2. 運作路徑直觀對比

| 比較維度 | 傳統 RDMA 處理 GPU 資料 | NVIDIA GPUDirect RDMA |
| --- | --- | --- |
| **資料搬移路徑** | GPU 顯存 $\rightarrow$ Host RAM $\rightarrow$ NIC $\rightarrow$ 網路 $\rightarrow$ NIC $\rightarrow$ Host RAM $\rightarrow$ GPU 顯存 | **GPU 顯存 $\rightarrow$ NIC $\rightarrow$ 網路 $\rightarrow$ NIC $\rightarrow$ GPU 顯存** |
| **CPU 與 OS 參與** | 需 CPU 與 OS 介入在 Host RAM 與 GPU 間搬移 | **完全繞過（Bypassed）** |
| **資料複製次數** | 多次記憶體中介複製（記憶體頻寬開銷大） | **真正的端到端零拷貝（Zero-copy）** |
| **通訊延遲** | 較高，且受 PCIe 總線與 CPU 抖動影響 | 極低延遲、高頻寬，滿足大規模平行運算 |

3. GPUDirect RDMA 的部署先決條件

這是一項硬體與驅動層級高度整合的技術，運行需具備以下三要素：

1. **NVIDIA GPU**（硬體需支援 P2P / GPUDirect 功能）。
2. **NVIDIA 專用驅動程式與軟體支援**（如 NVIDIA PeerDirect 驅動、CUDA-aware MPI、NCCL 等）。
3. **支援 RDMA 的網卡（NIC/HCA）**（支援 InfiniBand 或 RoCE 網路協議）。


## GPUDirect Storage

NVIDIA 另一項運用 DMA 原理的關鍵技術：**GPUDirect Storage (GDS)**，主要用來解決本機儲存與 GPU 之間的 I/O 效能瓶頸。

1. 核心問題：傳統本機儲存讀取的 I/O 瓶頸

* **傳統讀取路徑**：

$$\text{本地 NVMe SSD} \xrightarrow{\text{讀取}} \text{CPU / 系統核心} \xrightarrow{\text{複製}} \text{主機記憶體 (Host RAM / Page Cache)} \xrightarrow{\text{複製}} \text{CPU 介入} \xrightarrow{\text{寫入}} \text{GPU 顯存 (VRAM)}$$


* **面臨的痛點**：
  * 在 AI 模型訓練時，需要從硬碟讀取海量的訓練資料（Dataset）。
  * 資料反覆進出 CPU 與 Host RAM，造成多次中介複製（Bounce Buffer Overhead）與極大的 CPU 負載。
  * CPU 與記憶體頻寬成為整個訓練管線（Pipeline）的 I/O 瓶頸，導致強大的 GPU 常常需要「閒置等待資料」。


2. 解決方案：什麼是 GPUDirect Storage (GDS)？

* **核心定義**：NVIDIA 開發的技術，可實現**本地 NVMe 硬碟與 GPU 顯存之間的直接 DMA 傳輸**（Direct Data Path）。
  * **極簡路徑**：

$$\text{本地 NVMe 儲存} \xrightarrow{\text{直接 DMA (經由 PCIe 總線)}} \text{GPU 顯存 (VRAM)}$$


* **三大關鍵效益**：
  1. **完全繞過 CPU 與主機記憶體**：消除作業系統核心頁面快取（Page Cache）的中介搬移與 Context Switch。
  2. **消除複製開銷（Zero-copy）**：直接透過 PCIe 總線端到端寫入顯存，釋放 CPU 運算資源與系統記憶體頻寬。
  3. **大幅降低 I/O 延遲、提升讀取吞吐量**：確保 GPU 能夠全速消化海量資料，極大化模型訓練效能。


3. NVIDIA GPUDirect 家族三大技術定位整理

| 技術名稱 | 作用範圍 | 解決的核心通道 | 繞過對象 |
| --- | --- | --- | --- |
| **GPUDirect P2P** | 單機內部 | $\text{GPU A 顯存} \longleftrightarrow \text{GPU B 顯存}$ | 繞過 Host RAM 與 CPU 轉發 |
| **GPUDirect RDMA** | 跨節點網路 | $\text{主機 A 的 GPU 顯存} \longleftrightarrow \text{主機 B 的 GPU 顯存}$ | 繞過雙方的 OS、CPU 與 Host RAM |
| **GPUDirect Storage (GDS)** | 單機 / 儲存端 | $\text{本地 NVMe SSD} \longleftrightarrow \text{GPU 顯存}$ | 繞過 CPU 核心與 Host Page Cache |


## GPUDirect RDMA vs. GPUDirect Storage 


| 比較維度 | GPUDirect RDMA | GPUDirect Storage (GDS) |
| --- | --- | --- |
| **技術定位一句話總結** | **跨伺服器的 GPU 網路通訊管道** | **供 GPU 存取儲存設備的高速 I/O 管線** |
| **運作範圍（Scope）** | **跨主機節點（Across Hosts）**、GPU $\longleftrightarrow$ 遠端 GPU / RDMA 網卡 | **本機內部或網路儲存（Within Host / Networked Storage）**、GPU $\longleftrightarrow$ 本地 NVMe / 平行儲存設備 |
| **資料流動路徑** | **GPU 顯存 $\longleftrightarrow$ RDMA 網卡**、完全繞過本機與遠端 OS、CPU、系統記憶體 | **儲存設備 $\longleftrightarrow$ GPU 顯存**、直接路徑，繞過作業系統核心、CPU、系統記憶體（Page Cache） |
| **核心主要用途** | **HPC / AI 訓練中多 GPU 間的低延遲同步**（例如：梯度同步、AllReduce 通訊） | **大規模資料集的高吞吐量載入**（例如：將大量訓練資料快速餵給 GPU） |
| **核心優勢效益** | **極致超低延遲（Ultra-low Latency）**，消除跨節點通訊瓶頸 | **極高 I/O 頻寬（High Bandwidth I/O）**，消除資料讀取的 I/O 阻塞 |
| **硬體與環境需求** | • NVIDIA GPU + RDMA 網卡（如 Mellanox ConnectX）和 InfiniBand 或 RoCE 網路 | NVIDIA GPU、 支援的 NVMe SSD、RAID 或相容的平行分散式儲存（如 IBM Spectrum Scale、WekaFS） |


* **GPUDirect RDMA 是「算力節點之間的互聯」**：負責讓不同機器上的 GPU 彼此交換記憶體數據，解決分散式訓練時節點間同步延遲高的問題。
* **GPUDirect Storage 是「算力與資料庫/硬碟的互聯」**：負責把海量訓練資料從硬碟直接灌給 GPU 消化，解決 GPU 等待硬碟 I/O 餵資料的飢渴問題。
