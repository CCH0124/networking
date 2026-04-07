
通道埠 (Port Channel)，在 Cisco 環境中常被稱為 EtherChannel，是數據中心網路架構中的基礎且關鍵的技術。將從技術定義、操作模式、負載平衡機制，以及其在高可用性設計中的延伸應用——虛擬通道埠 (vPC) 進行全面且深入的重點整理。

## 一、 通道埠的基礎概念與核心優勢

通道埠是將多個實體介面聚合為一個邏輯介面的技術。這種聚合提供了幾個對於數據中心至關重要的優勢：

1. **冗餘性 (Redundancy)**：如果通道埠中的某個成員埠故障，流量會自動轉移到剩餘的成員埠上，從而確保服務的連續性。
2. **頻寬擴展 (Bandwidth)**：流量在通道埠的各個鏈路上進行負載平衡，有效地增加了總聚合頻寬。通道埠可以聚合最多 8 個或 16 個實體埠，具體取決於硬體或 NX-OS 軟體。
3. **生成樹協議 (Spanning Tree Protocol, STP) 簡化**：對於 STP 而言，通道埠被視為**單一交換器埠**，因此所有實體介面都保持在轉發狀態 (forwarding state)，消除了 STP 阻塞冗餘鏈路的需求。

**兼容性要求 (Compatibility)**
通道埠內的所有實體埠必須具備兼容性，包括使用相同的速度 (speed) 和全雙工模式 (full-duplex mode)。此外，NX-OS 在允許介面加入通道埠之前，會執行兼容性檢查，涵蓋網路層、鏈路速度、雙工配置、埠模式以及 VLAN 列表等操作屬性。一旦介面加入通道埠，其部分參數（如頻寬、MAC 位址和 STP 參數）將被通道埠的配置取代。

## 二、 通道埠的實施協議與模式

通道埠的建立可以透過靜態配置或動態協議進行：

### 1. 鏈路聚合控制協議 (LACP)

LACP (Link Aggregation Control Protocol) 定義於 **IEEE 802.3ad** 標準中。LACP 透過交換協議封包來進行埠捆綁的協商，這比靜態配置更有效率，並降低了配置錯誤的可能性。

* **NX-OS 支援模式**：Cisco NX-OS 支援靜態模式或 LACP 模式。
  * **Active (主動)**：埠處於主動協商狀態，會主動發送 LACP 封包並與其他埠協商。
  * **Passive (被動)**：埠處於被動協商狀態，只回應接收到的 LACP 封包，但不主動發起協商。
  * **On (靜態)**：所有靜態通道埠都保持在此模式，不運行 LACP 協議。

| PortA 模式 | PortB 模式 | 埠狀態 (Port Status) | 協商說明 |
| :--- | :--- | :--- | :--- |
| Active | Active | UP | 成功協商 |
| Active | Passive | UP | 成功協商 |
| ON | ON | UP | LACP 禁用 |
| Passive | ON | Down | 不會協商成功 |

* **NX-OS 限制**：Cisco NX-OS **不支持** 埠聚合協議 (PAgP)。LACP 也不支援半雙工模式 (half-duplex mode)；在 LACP 通道埠中，半雙工埠將被置於懸掛狀態 (suspended state)。
* **優先級**：LACP 埠優先級 (Port Priority) 與埠號一起構成埠識別符 (Port Identifier)。**數值越高，優先級越低**。當硬體限制無法聚合所有兼容埠時，埠優先級用於決定哪些埠應置於備用 (standby) 模式。預設 LACP 系統優先級為 32768。

相容性檢查包括以下操作屬性：

* Network layer
* (Link) speed capability
* Speed configuration
* Duplex capability
* Duplex configuration
* Port mode
* Access VLAN
* Trunk native VLAN
* Tagged or untagged
* Allowed VLAN list

### 2. SAN 通道埠 (SAN Port Channels)

通道埠的概念也應用於儲存網路 (SAN)。SAN 通道埠將多個實體介面聚合成一個邏輯介面，用於提供更高的聚合頻寬、負載平衡和冗餘。

* **SAN 埠類型組合**：通道埠可以在以下埠類型之間形成：
  * E 埠 (E ports) 和 TE 埠 (TE ports)。
  * F 埠 (F ports) 和 NP 埠 (NP ports)。
  * TF 埠 (TF ports) 和 TNP 埠 (TNP ports)。
  * *注意*：E 埠和 F 埠不能形成通道埠，因為 E 埠用於連接其他交換器，而 F 埠用於連接周邊設備 (主機或磁碟)。

## 三、 通道埠的負載平衡機制 (Load Balancing)

Cisco NX-OS 透過**流量雜湊 (hashing)** 機制，將流量均勻分配到通道埠內所有可操作的介面上。負載平衡的精確性取決於流量標頭和選定的雜湊準則。

| 配置選項 | Layer 2 準則 | Layer 3 準則 | Layer 4 準則 |
| :--- | :--- | :--- | :--- |
| 僅目的地 MAC (Destination MAC) | 目的地 MAC | - | - |
| 來源 MAC (Source MAC) | 來源 MAC | - | - |
| 來源與目的地 MAC (Source and destination MAC) | 來源與目的地 MAC | - | - |
| 來源與目的地 IP (Source and destination IP) | 來源與目的地 MAC | 來源與目的地 IP | - |
| 來源與目的地 TCP/UDP Port | 來源與目的地 MAC | 來源與目的地 IP | 來源與目的地 Port |

* **預設值**：對於 Layer 3 介面，預設的負載平衡方法是**來源與目的地 IP 位址**；對於非 IP 流量，預設是**來源與目的地 MAC 位址**。
* **優化**：如果流量只流向單一 MAC 位址，僅使用目的地 MAC 地址進行負載平衡將導致所有流量選擇同一條鏈路；改用來源/目的地 MAC 位址則可能獲得更好的分佈。

![alt text](images/Port%20Channel%20Load%20Balance.png)

## 四、 虛擬通道埠 (Virtual Port Channel, vPC)

vPC 是 Cisco Nexus 交換器上的一項技術，允許單一終端設備（例如交換器、伺服器或支援 IEEE 802.3ad 的網路設備）跨兩個上游交換器建立通道埠。在下游設備看來，這對 vPC 交換器就像單一設備。

### 1. vPC 與 VSS 的比較

| 特性 | vPC (Virtual Port Channel) | VSS (Virtual Switching System) |
| :--- | :--- | :--- |
| **控制平面** | 每個 Nexus 交換器獨立管理和配置 (Dual Control Plane)。 | 創建單一邏輯交換器，具有單一控制平面。 |
| **功能** | 允許 Layer 2 通道埠跨越兩個交換器。 | - |

vPC 能夠**消除 STP 阻塞埠**，使下游設備能夠使用所有可用的上行頻寬，並在鏈路或設備故障時提供快速收斂。

### 2. vPC 的核心組件

一個 vPC 系統包含以下關鍵元件：

* **vPC Domain (vPC 域)**：包含 vPC 對等體、Keepalive 鏈路和使用 vPC 技術的通道埠。
* **vPC Peer Switch (vPC 對等交換器)**：vPC 域內的另一個交換器。其中一個被選為 Primary (主) 角色，另一個為 Secondary (次) 角色。這些角色是**非搶佔式 (nonpreemptive)** 的。
* **vPC Peer Link (對等鏈路)**：vPC 系統中最關鍵的連接元素。它用於**同步 MAC 地址和 IGMP 條目**，並為多播流量和孤立埠 (orphaned ports) 提供必要的傳輸。對等鏈路上的通道埠會自動配置 **Bridge Assurance**。
  * 在 vPC 設備同時也是第 3 層交換器的情況下，peer link 也承載熱備份路由協定（HSRP）幀。
  * 要使 vPC 轉發 VLAN，該 VLAN 必須存在於 peer link 上以及兩個 vPC 對等交換機上，並且必須出現在 vPC 本身的交換機埠幹道允許清單中
* **vPC Peer Keepalive Link (Keepalive 鏈路)  or fault-tolerant link**：一條路由 (routed) **鏈路** (更準確地說是一個路徑)，用於在對等鏈路斷開時解決雙主動 (dual-active) 情境。Keepalive 流量通常通過管理網路或專用的 VRF 實例傳輸。
* **vPC member port** 分配給 vPC 通道組的埠。形成虛擬埠通道的埠在 vPC 對等設備之間分配，並被稱為 vPC 成員埠。
* **Non-vPC port** 在非 vPC 模式下連接設備到 vPC 拓撲的端口被稱為孤立端口。設備以常規生成樹配置連接到 Cisco Nexus 交換機，因此，一個鏈路是轉發狀態，另一個鏈路是阻塞狀態。這些鏈路通過孤立端口連接到 Cisco Nexus 交換機。

![vPC Topologies](images/vPC%20Topologies.png) vPC Topologies


![vPC Components](images/vPC%20Components.png) vPC Components

### 3. vPC Traffic Flows

確保通過具備 vPC 功能的系統的流量是對稱的。例如在下圖中，左側的流量（從 Core1 到 Acc1）從核心到達 Cisco Nexus 交換機（圖中的 Agg1）時，會被轉發到接入層交換機（圖中的 Acc1），而不會通過對等的 Cisco Nexus 交換機設備（Agg2）。同樣，來自伺服器並指向核心的流量會到達 Cisco Nexus 交換機（Agg1），接收的 Cisco Nexus 交換機會將此流量直接路由到核心，而無需將其不必要地傳送到對等的 Cisco Nexus 設備。無論哪個 Cisco Nexus 設備是特定 VLAN 的主要 HSRP 設備，此過程都會發生。

![alt text](images/Traffic%20Flows%20with%20vPC.png)

### 4. vPC 關鍵機制

* **雙重控制平面 (Dual-Control Plane)**：vPC 確保鄰近設備將 vPC 對等體視為單一的 STP 和 LACP 實體。為了實現這一點，vPC 主交換器預設只會在其 vPC 成員埠上轉發 BPDUs。
* **重複幀預防 (Duplicate Frames Prevention)**：這是 vPC 的核心轉發規則。**任何從 vPC 對等鏈路進入 vPC 對等交換器的幀，都不能從 vPC 成員埠離開**。這確保了下游設備不會收到重複的幀，即使在 vPC 雙活動故障期間，Layer 2 環路也不會發生。

* **vPC 對等閘道 (vPC Peer Gateway)**：
  * 當終端設備將 Layer 3 流量發送到 vPC 交換器的 **burned-in MAC address (BIA)**，而不是 HSRP 虛擬 MAC 地址時，可能會發生錯誤的流量雜湊。流量可能被導向到不擁有該 BIA 的對等體，然後透過 Peer Link 傳輸。
  * 若此時該流量被路由到 vPC 成員埠，則會觸發**重複幀預防規則**而被丟棄。
  * 啟用 `peer-gateway` 功能後，vPC 對等體會交換 BIA MAC 地址信息，允許它們在本地處理該流量並進行路由，從而避免流量繞經 Peer Link。

* **配置一致性 (Configuration Consistency)**：vPC 依賴於對等體之間配置的高度一致性。不一致的配置會被分為兩類：
  * **Type-1 (類型 1)**：嚴重不一致，會導致**整個通道埠暫停 (suspend)**，例如 System MTU 或 STP 模式不匹配。
  * **Type-2 (類型 2)**：較輕微不一致，只發出警告，或阻止單個 VLAN 處於活躍狀態。

* **ARP 同步 (ARP Synchronization)**：Layer 3 vPC 對等體會同步各自的 ARP 表，確保 vPC 交換器在故障後重新連接時，能加快融合速度。

### 5. 配置一致性檢查 (Configuration Consistency Checks)

vPC 受到嚴格的一致性檢查。不匹配的配置會根據其嚴重性分為兩類：

* **Type-1 (類型 1)**：**會暫停整個通道埠 (suspend the port channel)**。例如：System MTU 不匹配、STP 模式不匹配。
* **Type-2 (類型 2)**：**僅發出警告**，或阻止單個 VLAN 或一組 VLAN 在通道埠上處於活躍狀態。例如：QoS 配置不匹配 (在較新版本中是 Type-2)。

**限制/建議**：

* vPC 對等交換器必須是**相同類型**的 Cisco Nexus 交換器（例如，不能在 Nexus 5000 和 7000 組合上部署 vPC）。
* 不建議在 vPC 埠上配置 Port Security。
* vPC Peer Link 必須由 **10 Gbps 或更高速度**的乙太網路埠組成。

## 五、 配置與驗證命令摘要 (NX-OS)

以下是配置和驗證通道埠和 vPC 的關鍵命令，適用於 Cisco Nexus NX-OS 環境：

| 類別 | 命令 (Command) | 目的 (Purpose) |
| :--- | :--- | :--- |
| **功能啟用** | `feature lacp` | 啟用 LACP 功能。|
| | `feature vpc` | 啟用 vPC 功能。|
| **通道埠配置** | `interface port-channel channel-number` | 進入通道埠介面配置模式。|
| | `channel-group channel-number [mode {on | active | passive}]` | 將實體埠加入通道組並設定模式。|
| | `port-channel load-balance method {method}` | 指定設備的負載平衡演算法。|
| **vPC 域配置** | `vpc domain domain-id` | 創建 vPC 域並進入 vpc-domain 配置模式。|
| | `peer-keepalive destination X.X.X.X source Y.Y.Y.Y vrf NAME` | 配置 Keepalive 目的和來源地址。|
| | `vpc peer-link` | 將指定的 Port Channel 配置為 vPC 對等鏈路。|
| | `peer-gateway` | 啟用 Peer Gateway 功能。|
| | `peer-switch` | 啟用 vPC 對等交換器看起來像單一 STP 根的功能。|
| | `ip arp synchronize` | 啟用 vPC 對等體之間的 ARP 同步。|
| **驗證命令** | `show vpc brief` | 顯示 vPC 狀態摘要 (包括 Peer Status, Consistency Status)。|
| | `show port-channel summary` | 顯示通道埠介面的摘要。|
| | `show vpc consistency-parameters` | 顯示必須在所有 vPC 介面上保持一致的參數狀態。|
| | `show port-channel load-balance` | 顯示正在使用的負載平衡類型。|
| | `show lacp neighbor` | 顯示 LACP 鄰居資訊。|

## configure a virtual port channel

![alt text](images/Port%20Channel%20Network%20Topology.png) Port Channel Network Topology

## 比較

### 1. vPC 與 Port Channel 的根本差異

vPC 的核心差異在於其**控制平面**架構：

| 特性 | Port Channel (單機箱) | Virtual Port Channel (vPC) |
| :--- | :--- | :--- |
| **跨越設備** | 僅限於單一實體交換器。 | 跨越兩個獨立的 Cisco Nexus 交換器。 |
| **控制平面** | **單一控制平面** (Single Control Plane)。 | **雙控制平面** (Dual Control Plane)，兩台 vPC 對等交換器獨立配置和管理。 |
| **下游視角** | 單一 LACP/STP 實體。 | 透過 LACP/STP 協定，對下游設備而言視為單一實體。 |

> **比較 VSS**：Cisco VSS (Virtual Switching System) 雖然也是多機箱聚合，但它創建的是**單一邏輯交換器**，共享單一控制平面；而 vPC 則是兩個獨立交換器，各自擁有獨立控制平面。

### 2. vPC 的三大關鍵元件

vPC 系統 (vPC Domain) 的運作依賴於三個關鍵的連線元件：

1. **vPC 對等交換器 (vPC Peer Switch)**：vPC 域中的兩台 Nexus 交換器。它們被指定為 **Primary (主)** 或 **Secondary (次)** 角色。這些角色基於配置的優先級，並且是**非搶佔式 (nonpreemptive)** 的，以避免不必要的業務中斷。
2. **vPC 對等鏈路 (vPC Peer Link)**：vPC 系統中**最重要**的連接。
    * 作用：用於同步 MAC 地址和 IGMP 條目。
    * 作用：用於傳輸多播流量 (multicast traffic) 和孤立埠 (orphaned ports) 的數據流量。
    * 配置：必須由 **10 Gbps 或更高速度**的乙太網路埠組成。
    * 協定：當通道埠被定義為 vPC 對等鏈路時，**Bridge Assurance** 會自動配置。
3. **vPC Keepalive 鏈路 (vPC Peer-Keepalive Link)**：
    * 作用：這是一條**路由 (routed) 路徑**，用於在對等鏈路 (Peer Link) 斷開時，解決**雙主動 (dual-active) 衝突**。
    * 配置：Keepalive 流量通常透過管理網路或專用的 VRF 實例傳輸。
    * **限制**：Keepalive 鏈路**不應**運行在 vPC 對等鏈路上。

## 三、 總結與應用場景

| 特性 | Port Channel | Virtual Port Channel (vPC) |
| :--- | :--- | :--- |
| **技術層面** | L2/L3 鏈路聚合 (單一交換器)。 | L2 跨機箱鏈路聚合 (兩個 Nexus 交換器)。 |
| **控制平面** | 單控制平面。 | 雙控制平面，但對下游設備呈現單一實體。 |
| **主要用途** | 增加單設備連接的頻寬和鏈路冗餘。 | 消除數據中心接入層的 STP 阻塞，實現 **Active-Active** L2 轉發。 |
| **關鍵元件** | 僅有聚合鏈路本身。 | 包含 Peer Link, Peer Keepalive Link, Primary/Secondary 角色。 |
| **防環機制** | STP 根橋選擇、LACP 協商。 | LACP/STP 協同，以及 **Duplicate Frame Prevention 規則**。 |

### 應用場景

1. **Port Channel 應用**：
    * 傳統網路中兩台交換器之間的高頻寬骨幹連接 (ISL)。
    * 單台伺服器或儲存設備連接到單台交換器時，需要更高的頻寬和鏈路冗餘。

2. **Virtual Port Channel (vPC) 應用**：
    * **數據中心接入層**：這是 vPC 的主要應用。通過將伺服器、防火牆或邊緣交換器同時連接到兩台 Nexus 核心或聚合交換器，實現 Layer 2 的 **Active-Active** 連接，從而避免任何鏈路被 STP 阻塞。
    * **VXLAN 高可用性**：vPC 交換器對可以作為邏輯 VTEP 設備，共享同一個 **Anycast VTEP 地址**，實現 VXLAN 網路的高可用性。
    * **Layer 2 鏈路冗餘**：vPC 可以作為 Layer 2 鏈路，在兩個外部路由器之間建立路由鄰接關係，提供高冗餘的連線基礎。
    * **HSRP 閘道優化**：透過啟用 Peer Gateway，vPC 能確保 Layer 3 流量的路徑優化，即使流量目的地是另一個 vPC 對等體的 BIA MAC 地址，也能在本地進行路由轉發。
