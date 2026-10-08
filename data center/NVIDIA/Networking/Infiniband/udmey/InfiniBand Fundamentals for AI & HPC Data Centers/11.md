# Nvidia InfiniBand Stack
## Nvidia InfiniBand Hardware Stack

### NVIDIA InfiniBand 硬體堆疊核心剖析

講師將整個硬體架構由底至頂分為四大層級：

#### 1. 實體層（Physical Interconnect）：LinkX 線材與收發模組
* **定位**：銅纜（DAC）、主動光纜（AOC）與光模組。
* **核心優勢**：經 NVIDIA 官方在 GPU 伺服器與交換機上做過 100% 相容性認證，避免高速傳輸掉包。
* **最新規格**：LinkX XDR 800G。

#### 2. 端點運算層（Endpoints）：ConnectX HCA 網卡 & BlueField DPU
* **ConnectX 系列（HCA / NIC）**：
  * **VPI 技術**：單卡同時支援 InfiniBand 與 Ethernet（切換設定即可）。
  * **硬體卸載**：新世代支援硬體加密（Crypto）與防火牆卸載，解放 CPU。
  * **最新型號**：ConnectX-8 (C8180)、ConnectX-9。
* **BlueField DPU（資料處理器）**：
  * **架構**：整合 ConnectX 網卡晶片 + 多核心 ARM CPU。
  * **軟體生態**：透過 **DOCA SDK**（Data Center Infrastructure-on-a-Chip）進行程式開發；**「DOCA 之於 DPU，就像 CUDA 之於 GPU」**。
  * **最新型號**：BlueField-3、BlueField-4。

#### 3. 交換網路層（Fabric Switching）：從 Legacy 到 Quantum
* **傳統交換機（Legacy，已停產）**：
  * **IS（InfiniScale）**：純 InfiniBand 交換機。
  * **SX（Switch-X）**：具備 VPI 混合協定能力。
* **現代主力：Quantum 系列交換機**：
  * **AI/HPC 基礎設施**：構建大型 Fat-Tree（胖樹）或 Dragonfly+ 拓撲的核心。
  * **In-Network Computing（網內運算）**：不只負責轉發封包，還具備自我修復（Self-heal）與硬體運算卸載（如 SHARP 協定，在交換機內直接完成資料聚合聚合）。
  * **最新型號**：QM9700 / QM9790（Quantum-2 NDR 400G）、Quantum-X800（800G）。

#### 4. 路由、閘道與長途延伸（Scale-out & Long-Haul）
* **InfiniBand Router（Quantum-2）**：
  * 專門用來**跨子網（Cross-Subnet）互連**，支援多租戶（Multi-tenant）與大規模雲端 HPC 部署。
* **InfiniBand-to-Ethernet Gateway**：
  * 扮演 InfiniBand 與乙太網路的**協定轉譯橋樑**，讓 HPC 叢集能低成本存取外部 Ethernet 資料湖（Data Lake）或儲存庫。
* **MetroX 系統（跨地域長途延伸）**：
  * **突破機房限制**：可在長達 **40 公里** 的遠距光纖下，維持**原生 RDMA 吞吐量**。
  * **關鍵應用**：支援跨機房的 VM / 容器熱遷移（Live Job Migration）與跨遠距站點算力聚合，支援硬體線速加密。


#### NVIDIA InfiniBand 硬體全景對照表

| 產品系列 (Product Family) | 類型 | 它是什麼？ (What is it?) | 獨特之處 (What's Unique?) | 最新型號 (Latest Model) | 競品廠商與型號 (Competitors) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **LinkX** | 線材/收發器 | 銅纜與光纖互連配件 | 經 NVIDIA 交換機與 GPU 系統認證相容 | LinkX XDR 800G | Amphenol, Molex, TE Connectivity |
| **ConnectX 系列**<br>*(ConnectX-1 ~ 9)* | HCA / 網卡 | 支援 VPI（單卡支援 IB 與 RoCE 乙太網） | 支援硬體加密與防火牆卸載；DGX 標配 | ConnectX-8 (C8180)<br>ConnectX-9 (已發表) | Intel TrueScale *(已淘汰)* |
| **BlueField DPU**<br>*(BlueField-1 ~ 4)* | DPU 資料處理器 | 整合 ConnectX 與 ARM CPU，卸載網路/儲存/安全 | 專為 AI 工廠設計；具備 **DOCA SDK**（基礎設施的 CUDA） | BlueField-3 (B3240)<br>BlueField-4 (已發表) | AMD Pensando Elba<br>Intel IPU (Mount Evans)<br>Marvell OCTEON 10 |
| **InfiniBand 舊版交換機**<br>*(SX, IS 系列)* | 交換機 (舊款) | 早期 IB 交換平台；SX 支援 VPI，IS 為純 IB | 實現早期大型 HPC 架構；支援混合 IB/Ethernet | SX6036, SX6790<br>IS5022, IS5030 | Intel TrueScale *(已淘汰)*<br>早期 HPE IB 交換機 |
| **Quantum 交換機**<br>*(Quantum, Q-2, Q-X800)* | 交換機 (現代) | 模組化/固定式；構建 Fat-Tree 與 Dragonfly+ 拓撲 | 具備網內運算（Compute）、自我修復，超越單純封包轉發 | QM9700, QM9790<br>Quantum-X800 | 現階段無直接對手<br>*(Voltaire 已被 Mellanox 收購)* |
| **InfiniBand Router** | 路由器 | 連接不同獨立 IB 子網（Subnet） | 實現資料中心級多子網與多租戶部署；雲端 HPC 必備 | Quantum-2<br>Quantum-X800 | Cornelis、HPE Slingshot 皆無直接對等產品 |
| **IB-to-Ethernet Gateway** | 閘道器 | 橋接 IB 與乙太網；進行通訊協定轉換 | 無需替換既有設施，直接對接外部乙太網資料湖或雲儲存 | Quantum-2 NDR<br>Quantum-X800 XDR | HPE Slingshot-to-Ethernet Gateway<br>*(Cornelis 無對等產品)* |
| **MetroX 系統** | 長途延伸系統 | 跨地理距離（最長 40 km）延伸 IB 網路 | **唯一原生支援長距離 RDMA** 的方案；支援跨站點運算聚合與動態遷移 | MetroX-3 XC<br>*(NDR, 40km, 硬體加密)* | 無直接對手<br>*(HPE 與 Cornelis 僅限機房內部)* |

## Nvidia InfiniBand Software Stack

### NVIDIA InfiniBand 軟體堆疊四大核心

講師將軟體層分為四大維度：

#### 1. 驅動與核心層：MLNX_OFED（基礎通訊引擎）
* **定位**：NVIDIA 針對 ConnectX 網卡深度最佳化的驅動程式與核心協定堆疊（Drivers & Kernel Stack）。
* **為什麼不用 OS 預設驅動？**：雖然 Linux/Windows 有內建（Inbox）的開源 RDMA 驅動，但唯有安裝 **MLNX_OFED** 才能解鎖完整的進階功能（如硬體卸載、高階 QoS 設定）。
* **殺手級功能**：**GPUDirect RDMA** 的必要基石（讓遠端主機能直接讀寫本地 GPU 顯存）。
* **最新版本**：OFED 24.x（舊版 4.9 僅支援至 ConnectX-3）。

#### 2. DPU 開發框架：DOCA（基礎設施的 CUDA）
* **定位**：BlueField DPU 的專屬軟體開發套件（SDK）與執行環境。
* **角色比喻**：**「DOCA 之於 DPU，就像 CUDA 之於 GPU」**。
* **核心功能**：
  * 將原本消耗主機 CPU 的網路、儲存、安全（防火牆/加密）邏輯，以程式化方式下放到 DPU 上執行。
  * 支援 **基礎設施即程式碼（Infra-as-Code）**、零信任安全（Zero-Trust）架構與全方位 Telemetry 監控。
* **最新版本**：DOCA 3.x。

#### 3. 網管與監控平台：UFM（Unified Fabric Manager，視覺化中樞）
* **定位**：InfiniBand 交換網路的集中管理 GUI 平台。
* **核心優勢**：提供 **Per-Port（單埠）** 與 **Per-Flow（單一資料流）** 的超高解析度深度監控與壅塞洞察。
* **三大版本（Flavors）**：
  1. **UFM Telemetry**：僅提供即時遙測與網路監控數據串流。
  2. **UFM Enterprise**：監控＋主動配置管理（Provisioning）與路由管理。
  3. **UFM Cyber-AI**：在 Enterprise 基礎上加入 AI 引擎，自動偵測網路異常、鏈路降速預警與資安威脅。
* **最新版本**：UFM 6.13。

#### 4. 分散式 AI 集合通訊庫：NCCL（多 GPU 訓練心臟）
* **定位**：專門為分散式多 GPU、多節點訓練打造的通訊庫。
* **核心優勢**：
  * **拓撲感知（Topology-Aware）**：能自動判斷硬體環境，若在同一台伺服器內優先走 **NVLink**；跨伺服器則自動切換至 **InfiniBand + GPUDirect RDMA**。
  * 主流 AI 框架（PyTorch、TensorFlow）在執行多機多卡訓練時，底層幾乎全靠 NCCL 來進行梯度同步。
* **最新版本**：NCCL 2.20（AMD 競品為 RCCL）。

---

### NVIDIA InfiniBand 軟體堆疊全景表

| 產品系列 (Product Family) | 軟體類型 | 它是什麼？ (What is it?) | 獨特之處 (What's Unique?) | 最新版本 (Latest Version) | 競品／其他方案 (Competing Products) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **MLNX_OFED**<br>*(Mellanox OpenFabrics Enterprise Distribution)* | 驅動與核心堆疊<br>*(Drivers & Kernel Stack)* | • 支援 IB 與 RoCE 的 RDMA 驅動<br>• 內建 Verbs、IPoIB、SR-IOV | • 針對 ConnectX 網卡深度最佳化<br>• **啟用 GPUDirect RDMA 的必備驅動** | • **OFED 24.x**<br>*(舊版: 4.9 僅支援 CX-3)* | • Linux 內建 RDMA (Inbox)<br>• Intel OFED |
| **DOCA**<br>*(Data Center-on-a-Chip Architecture)* | DPU SDK / 框架平台 | • 開發 BlueField DPU 的 SDK<br>• 提供網路、儲存、安全之底層 API | • 將 CPU 負擔完全卸載至 DPU<br>• 實現零信任架構與 DPU 基礎設施即代碼 | • **DOCA 3.x** | • Intel IPU SDK<br>• AMD Pensando SDK |
| **UFM**<br>*(Unified Fabric Manager)* | 網路架構管理<br>*(Fabric Management)* | • IB 網路監控、自動化配置、遙測 (Telemetry) | • 具備單埠、單流的深度可視化<br>• 壅塞控制 (Congestion Insights)<br>• **Cyber-AI** 智慧異常預測 | • **UFM 6.13** | • Intel Fabric Suite *(已淘汰)*<br>• HPE Fabric Manager |
| **NCCL**<br>*(NVIDIA Collective Communication Library)* | GPU 集合通訊庫 | • 多 GPU / 多節點的高效集合通訊演算法 | • **具備拓撲感知**（自動協調 NVLink 與 IB）<br>• 分散式 AI 訓練的核心通訊庫<br>• 整合 GPUDirect RDMA | • **NCCL 2.20** | • **RCCL** (AMD ROCm 方案) |

---

### 總結

硬體（ConnectX 網卡、Quantum 交換機、LinkX 線材）提供了**極致低延遲、高頻寬的物理通道**；而軟體（MLNX_OFED、DOCA、UFM、NCCL）則提供了**零拷貝旁路、智慧監控、硬體卸載與分散式運算演算法**。兩者完美嵌合，構成了當前 AI 工廠（AI Factory）不可或缺的網路基石。

## OpenFabrics Enterprise Distribution (OFED)

### 📌OFED 驅動演進與世代劃分

#### 1. 為什麼不能只用作業系統內建的驅動（Inbox Driver）？
* **OS 內建驅動（Inbox）**：通常只能提供基本連線功能，無法發揮 ConnectX 網卡的極致效能，且缺少許多專屬功能（例如 GPUDirect RDMA、自訂 QoS、硬體加速等）。
* **官方最佳化驅動（OFED）**：徹底解鎖硬體全部功能與最低延遲表現。

#### 2. MLNX_OFED 走向 DOCA_OFED 的演進版圖

```text
[ 網卡世代 ]  CX-3  |  CX-4  |  CX-5  |  CX-6  |  CX-7  |  CX-8
-------------------------------------------------------------------->
MLNX_OFED:   [========= 支援 =========]
                                  ▲ (轉折交會點)
DOCA_OFED:                    [================ 支援未來主力 ========>]

[ DPU 世代 ]              BlueField-2 DPU      |      BlueField-3 DPU
                          (部分支援 DOCA)      |      (全面導入 DOCA)
```

* **MLNX_OFED（Mellanox 時代）**：
  * 適用早期 ConnectX-3、ConnectX-4 到 ConnectX-5。
* **分水嶺：ConnectX-5**：
  * 此世代是過渡期，既有支援 MLNX_OFED，也開始納入 DOCA_OFED。
* **DOCA_OFED（NVIDIA 現代與未來標準）**：
  * 從 **ConnectX-5 之後（CX-6、CX-7、CX-8）**，全面轉向 DOCA_OFED 作為官方預設標準。
  * **專為新一代架構設計**：針對 SmartNIC / DPU、AI/HPC 大型叢集以及 **高度硬體卸載（Offload-heavy）** 設計。
  * **DPU 支援**：BlueField-2 僅部分支援，從 **BlueField-3** 開始完全以 DOCA 為核心。

### 如何檢查系統的驅動狀態？

#### 步驟一：檢查是否載入了 Mellanox 核心模組
```bash
$ sudo lsmod | grep "mlx"
mlx5_fwctl             16384  0
mlx5_ib               561152  0
fwctl                  12288  1 mlx5_fwctl
macsec                 77824  1 mlx5_ib
mlx5_core            3153920  2 mlx5_fwctl,mlx5_ib
mlxdevm               540672  1 mlx5_core
mlxfw                  36864  1 mlx5_core
psample                16384  1 mlx5_core
tls                   155648  2 bonding,mlx5_core
pci_hyperv_intf        12288  1 mlx5_core
ib_uverbs             212992  21 nvidia_peermem,rdma_ucm,mlx5_ib
ib_core               528384  8 rdma_cm,ib_ipoib,iw_cm,ib_umad,rdma_ucm,ib_uverbs,mlx5_ib,ib_cm
mlx_compat             12288  13 rdma_cm,ib_ipoib,mlxdevm,mlx5_fwctl,iw_cm,ib_umad,fwctl,ib_core,rdma_ucm,ib_uverbs,mlx5_ib,ib_cm,mlx5_core
```
* 會列出目前載入的模組，常見如：
  * `mlx4_core` / `mlx4_ib`（ConnectX-3 舊卡）
  * `mlx5_core` / `mlx5_ib`（ConnectX-4 以上現代網卡）

#### 步驟二：檢查驅動是「系統內建」還是「外部 OFED 安裝」（關鍵技巧）
使用 `modinfo` 檢查驅動模組的實體路徑：
```bash
$ sudo modinfo mlx5_core 
filename:       /lib/modules/6.8.0-117-generic/updates/dkms/mlx5_core.ko.zst
alias:          auxiliary:mlx5_core.eth-rep
alias:          auxiliary:mlx5_core.eth
supported:      external
basedon:        Korg 6.18-rc4
version:        26.01-1.0.0
license:        Dual BSD/GPL
description:    Mellanox 5th generation network adapters (ConnectX series) core driver
author:         Eli Cohen <eli@mellanox.com>
srcversion:     DAC01C69511CBB2302830B1
alias:          pci:v000015B3d0000A2DFsv*sd*bc*sc*i*
```
* **情況 A：系統原生內建驅動（未最佳化）**
  * 路徑顯示：`/lib/modules/.../kernel/drivers/net/ethernet/mellanox/...`
* **情況 B：官方安裝的最佳化 OFED 驅動**
  * 路徑顯示：`/lib/modules/.../updates/dkms/...`
  * 看到 `updates/dkms` 即代表是外部透過 DKMS 動態編譯並替換的高效能驅動。

#### 步驟三：使用 `ofed_info` 確認版本
```bash
$ sudo ofed_info -s
OFED-internal-26.01-1.0.0:
```
* **未安裝 OFED**：系統回應 `command not found`。
* **已正確安裝**：回應版本資訊
