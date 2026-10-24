# NVIDIA & Data Center Networking 知識庫

本目錄彙整 NVIDIA 現代資料中心（Modern Data Center）與 AI 叢集高效能網路技術筆記，涵蓋 **InfiniBand Fabric**、**Spectrum-X / Lossless Ethernet**、**Cumulus Linux NOS / EVPN-VXLAN**、**AI 集合通訊加速 (NCCL / SuperNIC)** 以及 **系統化培訓與認證**。

---

## 🗺️ 架構導航總覽 (Knowledge Map)

```text
Networking/
├── 01-InfiniBand/                     # InfiniBand 高效能網路架構、拓撲與路由演算法
├── 02-Ethernet-and-RoCE/              # 乙太無損網路、Spectrum-X、RoCEv2 與 QoS
├── 03-Fabric-Design-and-NOS/          # Cumulus Linux (NVUE)、EVPN-VXLAN 與 DCI 互聯
├── 04-AI-Workload-Acceleration/       # NCCL 分散式集合通訊、Magnum IO 與 I/O 加速
└── 05-Courses-and-Certifications/     # Udemy InfiniBand 核心課程與 NCA-AIIO 原廠認證
```

---

## 01. 🚀 InfiniBand 架構與路由 ([01-InfiniBand](./01-InfiniBand/README.md))

專為極致低延遲、高吞吐量之 HPC 與 AI 訓練叢集打造的網路架構技術：

| 專題文件 | 核心內容說明 |
| :--- | :--- |
| **[Topologies.md](./01-InfiniBand/Topologies.md)** | Fat Tree、Dragonfly+ 與 Torus 拓撲架構比較，Non-blocking 設計原則 |
| **[Cabling-Considerations-Clos-5.md](./01-InfiniBand/Cabling-Considerations-Clos-5.md)** | 五層 Clos (Clos-5) 網路佈線考量與 Neighborhood Groups 規劃 |
| **[Routing-Algorithm-UpDown.md](./01-InfiniBand/Routing-Algorithm-UpDown.md)** | Up/Down 階層式無死鎖（Deadlock-Free）路由演算法機制 |
| **[Prevent-Credit-Loops.md](./01-InfiniBand/Prevent-Credit-Loops.md)** | 基於 Credit 的流量控制機制與防範 Credit Loop 迴圈策略 |
| **[Designing-HPC-Cluster-Mellanox.md](./01-InfiniBand/Designing-HPC-Cluster-Mellanox.md)** | HPC 叢集頻寬運算、超額配比與 Mellanox 方案設計指南 |
| **[IB-Router-Architecture-and-Functionality.md](./01-InfiniBand/IB-Router-Architecture-and-Functionality.md)** | InfiniBand 路由器架構、跨子網路由與 LID 擴充性隔離 |
| **[Scalable-Subnet-Administration-SSA.md](./01-InfiniBand/Scalable-Subnet-Administration-SSA.md)** | 可擴充子網管理 (SSA) 快取架構與 SA 查詢加速 |
| **[Partitions.md](./01-InfiniBand/Partitions.md)** | InfiniBand 安全分區機制、Full 與 Limited Membership 權限規則 |
| **[Ethernet-VLANs-and-InfiniBand-PKEYs.md](./01-InfiniBand/Ethernet-VLANs-and-InfiniBand-PKEYs.md)** | 乙太網 VLAN 與 InfiniBand P_Key 之概念對照與連通設計 |
| **[Virtualization-VXLAN-ConnectX-3-Pro.md](./01-InfiniBand/Virtualization-VXLAN-ConnectX-3-Pro.md)** | 虛擬化環境下的 VXLAN 硬體卸載考量 |

---

## 02. ⚡ Lossless Ethernet、RoCE 與 Spectrum-X ([02-Ethernet-and-RoCE](./02-Ethernet-and-RoCE/))

基於乙太網路生態系實現無損、微秒級延遲的 AI 專用乙太網技術：

| 專題文件 | 核心內容說明 |
| :--- | :--- |
| **[Spectrum-X-Platform-Architecture.md](./02-Ethernet-and-RoCE/Spectrum-X-Platform-Architecture.md)** | NVIDIA Spectrum-X 乙太網平台架構、Spectrum-4 交換器與端到端創新 |
| **[RoCE-Concepts-and-Configuration.md](./02-Ethernet-and-RoCE/RoCE-Concepts-and-Configuration.md)** | RoCEv2 封裝架構、Lossless vs Lossy 模式、PFC/ECN/CNP 原理與 Cumulus NVUE 設定 |
| **[QoS-Quality-of-Service.md](./02-Ethernet-and-RoCE/QoS-Quality-of-Service.md)** | Cumulus Linux QoS 完整指南（DSCP/COS 映射、ETS 排程、Buffer Pool 劃分） |
| **[SuperNIC.md](./02-Ethernet-and-RoCE/SuperNIC.md)** | BlueField-3 架構 SuperNIC、Packet Reordering、硬體遙測與擁塞控制 |
| **[Layer-1-Data-Center-Cheat-Sheet.md](./02-Ethernet-and-RoCE/Layer-1-Data-Center-Cheat-Sheet.md)** | 實體層線材（DAC/AOC/光纖）、PAM4/NRZ 編碼、Leaf-Spine 佈線速查表 |

---

## 03. 🌐 Fabric 設計與網路作業系統 ([03-Fabric-Design-and-NOS](./03-Fabric-Design-and-NOS/))

基於 Linux 的現代雲原生與資料中心 Fabric 架構：

### Cumulus Linux VXLAN & EVPN
* **[01-Introduction.md](./03-Fabric-Design-and-NOS/Cumulus-Linux-VXLAN-EVPN/01-Introduction.md)**: 現代資料中心網路架構演進與基礎
* **[02-Data-Center-Networking-Concepts.md](./03-Fabric-Design-and-NOS/Cumulus-Linux-VXLAN-EVPN/02-Data-Center-Networking-Concepts.md)**: VXLAN 封裝、BGP EVPN 控制平面、MLAG 與 EVPN Multihoming
* **[03-EVPN-Deployment-Scenarios.md](./03-Fabric-Design-and-NOS/Cumulus-Linux-VXLAN-EVPN/03-EVPN-Deployment-Scenarios.md)**: L2 EVPN、Symmetric IRB、Asymmetric IRB 與多租戶 VRF 實戰

### 資料中心互聯 (Data Center Interconnect, DCI)
* **[01-DCI-Topologies.md](./03-Fabric-Design-and-NOS/Data-Center-Interconnect-DCI/01-DCI-Topologies.md)**: 跨資料中心互連拓撲架構
* **[02-Extending-EVPN-VXLAN-with-DCI.md](./03-Fabric-Design-and-NOS/Data-Center-Interconnect-DCI/02-Extending-EVPN-VXLAN-with-DCI.md)**: 利用 DCI 擴展 EVPN-VXLAN Fabric
* **[03-Layer-2-Extensions.md](./03-Fabric-Design-and-NOS/Data-Center-Interconnect-DCI/03-Layer-2-Extensions.md)**: 跨站點 Layer 2 延伸技術
* **[04-Layer-3-Extensions.md](./03-Fabric-Design-and-NOS/Data-Center-Interconnect-DCI/04-Layer-3-Extensions.md)**: 跨站點 Layer 3 延伸與路由交換

### 通用路由與架構
* **[Anycast-Design-Guide.md](./03-Fabric-Design-and-NOS/Anycast-Design-Guide.md)**: 資料中心 Anycast 路由架構、BGP 負載均衡與維護切換

---

## 04. 🧠 AI 工作負載加速技術 ([04-AI-Workload-Acceleration](./04-AI-Workload-Acceleration/))

大模型分散式訓練不可或缺的通訊庫與 I/O 軟體加速棧：

| 專題文件 | 核心內容說明 |
| :--- | :--- |
| **[NCCL-Performance-All2All.md](./04-AI-Workload-Acceleration/NCCL-Performance-All2All.md)** | NVIDIA NCCL 集合通訊庫原理、All-to-All 效能調優與通訊原語 |
| **[Accelerating-IO-Magnum-IO.md](./04-AI-Workload-Acceleration/Accelerating-IO-Magnum-IO.md)** | NVIDIA Magnum IO 架構：從計算中心轉向資料中心，突破 I/O 瓶頸 |

---

## 05. 🎓 培訓課程與認證筆記 ([05-Courses-and-Certifications](./05-Courses-and-Certifications/))

### Udemy: InfiniBand Fundamentals for AI & HPC Data Centers
16 個單元的系統化全套課程精華筆記：

1. **[01-Why-InfiniBand.md](./05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/01-Why-InfiniBand.md)**: 為什麼 AI/HPC 需要 InfiniBand？傳統 Ethernet vs. RDMA
2. **[02-InfiniBand-Connections.md](./05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/02-InfiniBand-Connections.md)**: 線材、連接埠、訊號速率（SDR 到 NDR/XDR）
3. **[03-Subnet-Manager-SM.md](./05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/03-Subnet-Manager-SM.md)**: 子網管理器 (OpenSM) 核心角色與主備切換
4. **[04-InfiniBand-Addressing.md](./05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/04-InfiniBand-Addressing.md)**: GUID、LID、GID 定址機制
5. **[05-InfiniBand-Utilities.md](./05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/05-InfiniBand-Utilities.md)**: `ibstat`, `ibnetdiscover`, `ibdiagnet`, `ibping` 常用指令詳解
6. **[06-Ethernet-TCPIP-vs-InfiniBand.md](./05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/06-Ethernet-TCPIP-vs-InfiniBand.md)**: 協定棧逐層對比（L2~L4 運作差異）
7. **[07-Remote-Direct-Memory-Access-RDMA.md](./05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/07-Remote-Direct-Memory-Access-RDMA.md)**: RDMA Read/Write、Send/Receive 核心原語
8. **[08-Key-InfiniBand-Features-QP-and-Keys.md](./05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/08-Key-InfiniBand-Features-QP-and-Keys.md)**: Queue Pair (QP)、Memory Registration (L_Key / R_Key)
9. **[09-How-NVIDIA-Uses-RDMA.md](./05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/09-How-NVIDIA-Uses-RDMA.md)**: GPUDirect RDMA、GPUDirect Storage (GDS)
10. **[10-Subnet-and-SM-Workflow.md](./05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/10-Subnet-and-SM-Workflow.md)**: SM 掃描與拓撲發現流程
11. **[11-NVIDIA-InfiniBand-Stack.md](./05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/11-NVIDIA-InfiniBand-Stack.md)**: OFED (MLNX_OFED) 軟體棧架構
12. **[12-Traffic-Isolation-and-PKEYs.md](./05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/12-Traffic-Isolation-and-PKEYs.md)**: Partition Key (PKey) 流量隔離實務
13. **[13-Network-Topology-and-Routing.md](./05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/13-Network-Topology-and-Routing.md)**: 拓撲架構與路由配置實戰
14. **[14-Traffic-Prioritization-QoS.md](./05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/14-Traffic-Prioritization-QoS.md)**: 服務品質 (SL / VL) 與流量優先級
15. **[15-Unified-Fabric-Manager-UFM.md](./05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/15-Unified-Fabric-Manager-UFM.md)**: NVIDIA UFM 視覺化管理與遙測監控
16. **[16-Troubleshooting-InfiniBand.md](./05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/16-Troubleshooting-InfiniBand.md)**: 故障排除標準流程與符號錯誤（Symbol Errors）分析

### NVIDIA 原廠認證筆記
* **[NCA-AIIO - Bootcamp – AI Infra & Ops Associate](./05-Courses-and-Certifications/NCA-AIIO-Bootcamp/README.md)**: AI 數據中心基礎設施與維運（Inside an AI centric Data Center、運算/儲存/網路全景）
