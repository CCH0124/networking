# NVIDIA InfiniBand 架構與技術專題

本目錄收錄 NVIDIA / Mellanox InfiniBand 網路架構、路由演算法、拓撲佈線、虛擬化與高可用性機制的技術專題文件。

---

## 📑 核心專題導覽

| 文件名稱 | 主題重點 | 核心概念與技術 |
| :--- | :--- | :--- |
| **[Topologies.md](./Topologies.md)** | 網路拓撲架構 | Fat Tree、Dragonfly+、Torus、Non-blocking 傳輸 |
| **[Cabling-Considerations-Clos-5.md](./Cabling-Considerations-Clos-5.md)** | Clos-5 五層拓撲佈線 | Neighborhood Groups、Leaf-Spine-Core 佈線規劃 |
| **[Routing-Algorithm-UpDown.md](./Routing-Algorithm-UpDown.md)** | Up/Down 路由演算法 | 無死鎖路由（Deadlock-free）、階層式路徑計算 |
| **[Prevent-Credit-Loops.md](./Prevent-Credit-Loops.md)** | 防範 Credit Loops 迴圈 | 信用機制（Credit-based Flow Control）、迴圈預防策略 |
| **[Designing-HPC-Cluster-Mellanox.md](./Designing-HPC-Cluster-Mellanox.md)** | HPC 叢集設計實務 | 頻寬運算、超額配比（Oversubscription）、節點互連規劃 |
| **[IB-Router-Architecture-and-Functionality.md](./IB-Router-Architecture-and-Functionality.md)** | InfiniBand 路由器架構 | 跨子網（Subnet）路由、LID 隔離、擴充性規劃 |
| **[Scalable-Subnet-Administration-SSA.md](./Scalable-Subnet-Administration-SSA.md)** | 可擴充子網管理 (SSA) | 集中快取、減輕 OpenSM 負載、超大型叢集 SA 查詢加速 |
| **[Partitions.md](./Partitions.md)** | P_Key 與安全分區 | Full Membership、Limited Membership、分區隔離規則 |
| **[Ethernet-VLANs-and-InfiniBand-PKEYs.md](./Ethernet-VLANs-and-InfiniBand-PKEYs.md)** | 跨協議對應 | Ethernet VLAN 與 IB Partition Key (P_Key) 概念對比與映射 |
| **[Virtualization-VXLAN-ConnectX-3-Pro.md](./Virtualization-VXLAN-ConnectX-3-Pro.md)** | 虛擬化與重疊網路 | ConnectX 硬體卸載、VXLAN 於虛擬化環境之考量 |

---

> [!TIP]
> 初學者若欲由淺入深學習 InfiniBand 基礎架構，可優先參考 `05-Courses-and-Certifications/Udemy-InfiniBand-Fundamentals/` 的系列課程筆記。
