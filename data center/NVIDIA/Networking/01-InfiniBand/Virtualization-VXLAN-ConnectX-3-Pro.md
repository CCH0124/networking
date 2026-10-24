# VXLAN Considerations for ConnectX-3 Pro
## What is VXLAN?

虛擬可延伸區域網路（Virtual Extensible LAN, VXLAN）是一種網路虛擬化技術，旨在改善與大型雲端運算部署相關的可擴充性問題。它將乙太網路訊框（Ethernet frames）封裝於「Ethernet + IP + UDP」訊框中進行通道傳輸（tunneling）。

它能夠在傳統 IP 網路上建立數百萬個虛擬 Layer 2 網路：

    * 可用於在雲端服務供應商的基礎架構中為租戶提供服務

它可以跨越區域網路（LAN）或廣域網路（WAN）：

    * 可在雲端服務商／站點之間遷移整個網路，亦可用於災難復原情境
    * 可建立跨越多個地理位置的邏輯 L2 網路（類似於 VPN 的概念）

它可以跨越路由器（Routers）：

    * 充分善用 Layer 3 網路的可擴充性與路由協定（如 OSPF、BGP、ECMP）

## VXLAN packet encapsulation structure

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnU2&feoid=00N8Z000003jPco&refid=0EM8Z000003DQ2q)

### VXLAN overlay performance challenge

Hypervisor（虛擬機器監視器）的 IP 協定堆疊與標準網卡（NICs）無法感知客戶端虛擬機（Client）的 TCP/IP 流量。
常見的硬體卸載技術，例如：

    * TCP 分段與重組（TCP segmentation/re-assembly，如 TSO/LRO）
    * 接收／發送端總和檢查碼卸載（RX/TX checksum offload）
    * CPU 核心擴展機制（如 RSS/TSS）

皆無法直接作用於虛擬機內部的 TCP/IP 封包（即內部酬載 inner payload），這會導致顯著的 CPU 負擔與大幅降低傳輸效能。
Mellanox ConnectX-3 Pro 網路介面卡能將這些處理任務卸載至硬體層級執行，從而大幅減少 CPU 資源消耗並帶來更卓越的效能表現。

### Typical Architecture and Deployment

下圖展示了以紅、藍、綠三種顏色標示的三個租戶（tenants）之架構配置。

![](https://enterprise-support.nvidia.com/servlet/rtaImage?eid=ka0Vv000000AnU2&feoid=00N8Z000003jPco&refid=0EM8Z000003DQ2v)

    * 共有三個節點，右側兩個節點作為 Hypervisor（虛擬機器監視器），左側節點則作為閘道器（網路）節點。
    * 運行於 Hypervisor 上的每台虛擬機（VM）皆可連接至一個或多個網路。
    * 部分網路可透過路由器或網路節點具備對外連接介面（external interface）。
    * 網路管理可透過 OpenStack Neutron、OpenDaylight (OpenDL)、VMware NSX 或類似工具來達成。

#### 重點整理

* **多租戶隔離架構**：以紅、藍、綠三色標示不同租戶，呈現典型雲端運算環境中網路相互隔離的多租戶（Multi-tenancy）模型。
* **節點角色劃分**：
    * **右側兩節點**：負責運算與虛擬化（Hypervisor 節點），承載各租戶的 VM。
    * **左側節點**：負責網路轉發與外部路由（Gateway / Network 節點）。

* **多網路彈性連線**：每台虛擬機可視需求跨接單一或多個虛擬網路，並依策略經由 Gateway/Router 建立向外連線（External Interface）。
* **SDN 控制與編排工具**：支援業界標準的軟體定義網路（SDN）控制器與雲端管理平台，如 OpenStack Neutron、OpenDaylight、VMware NSX 等進行集中化網路配置與生命週期管理。

### Hypervisor 節點上虛擬機（VM）與主機網路協定堆疊之間的半虛擬化（Para-Virtualized, PV）連線架構

* 虛擬機（VM）運行前端 PV 乙太網路驅動程式（例如 KVM 的 virtio-net），而後端驅動程式（例如 KVM 的 vhost）則運行在 Hypervisor 核心中。
* 後端驅動程式與為此 VM 提供服務的 tap 裝置實例進行通訊。
* 該 tap 實例被接入（plugged into）OVS 核心資料路徑（Datapath, DP）中，並作為一個虛擬連接埠（virtual port）。
* 負責執行 VXLAN 封裝與解封裝（encapsulation/decapsulation）的 OVS 連接埠被加入到該資料路徑中。
* 使用者空間的 OVS 常駐程式（daemon）編寫 DP 流量轉發規則（flow-rules），使 VM 的流量能夠轉發進入或轉發自該 VXLAN 連接埠。
* OVS VXLAN 連接埠將封裝後的封包向下傳送至 UDP/IP 協定堆疊，該堆疊再進一步將封包傳送至實體網卡驅動程式（反向傳輸流程亦然）。
* 實體網卡（NIC）針對 VXLAN 流量套用 TCP 無狀態卸載技術（如 RX/TX checksum、Large-Send、RSS 等）。
* 更多範例與配置選項，請參閱《HowTo Configure VXLAN for ConnectX-3 Pro (Linux OVS)》。

---

#### 重點整理

* **半虛擬化前後端架構**：VM 內部運行前端驅動（如 `virtio-net`），主機核心運行後端驅動（如 `vhost`），兩者透過 Hypervisor 內部的 Tap 裝置交換資料。
* **OVS 核心轉發機制**：Tap 裝置作為虛擬連接埠掛載至 Open vSwitch（OVS）的核心 Datapath；OVS 使用者空間常駐程式負責下發流表規則（Flow-rules），指引流量進出 VXLAN 虛擬埠。
* **封裝與協定堆疊流程**：VM 流量經由 OVS 虛擬埠完成 VXLAN 封裝/解封裝，再透過主機的標準 UDP/IP 堆疊向下傳輸至實體網卡。
* **硬體卸載加速**：搭配如 ConnectX-3 Pro 網卡時，底層硬體能直接辨識 VXLAN 封裝並支援 Checksum、TSO/LSO 及 RSS 等無狀態硬體卸載，大幅減輕主機 CPU 負擔。

### 閘道器（網路）節點上的傳統連線方案（Legacy connectivity scheme on gateway node）

* 如同 Hypervisor 的配置情境，建立一個 OVS Datapath 實例並加入 VXLAN 連接埠。
* 建立一對 `veth`（虛擬乙太網路）網卡，這對網卡將在網路節點內部作為通道，負責將封包從路由器模組（router module）傳遞至 OVS DP 實例，反之亦然。
* 將其中一個 `veth` 裝置作為虛擬連接埠加入至 OVS Datapath。
* 另一個 `veth` 裝置則交由路由器應用程式使用。
* 實體網卡（NIC）針對 VXLAN 流量套用 TCP 無狀態卸載技術（RX/TX checksum、Large-Send/Receive、RSS 等）。

### 閘道器（網路）節點上的 DPDK 連線方案（DPDK connectivity scheme on gateway node）

* 使用者空間的 DPDK 應用程式攔截（hook）所有網卡接收到的封包。
* 實體網卡硬體針對 VXLAN 流量套用 TCP 無狀態卸載技術（RX/TX checksum、Large-Send/Receive、RSS 等）。
* 應用程式執行解封裝（decapsulation），並將封包發送至外部網路。
* 在反向傳輸時，應用程式執行封裝（encapsulation），並透過 DPDK 將封包傳送至內部網路。

### 基於使用者空間 DPDK 卸載 OVS Datapath 的虛擬機與 Hypervisor 間半虛擬化（PV）連線方案

* 虛擬機（VM）運行前端 PV 乙太網路驅動程式（例如 KVM 的 `virtio-net`）。
* 後端 PV 驅動程式（例如 KVM 的 `vhost`）運行於 Hypervisor 的使用者空間程序中。
* 後端驅動程式與實作於 DPDK 之上的 OVS 使用者空間資料路徑（User-space Datapath）進行通訊。
* 負責執行 VXLAN 封裝/解封裝的 OVS 連接埠被加入至該資料路徑中。
* 使用者空間的 OVS 常駐程式編寫 DP 流量規則（flow-rules），引導 VM 流量轉發進出該 VXLAN 連接埠。
* OVS VXLAN 連接埠透過 DPDK API 與 Mellanox 輪詢模式驅動程式（Poll-Mode-Driver, PMD）傳送封裝後的封包。
* 實體網卡硬體針對 VXLAN 流量套用 TCP 無狀態卸載技術（RX/TX checksum、Large-Send、RSS 等）。
* 此配置包含目前開源社群仍在開發中的元件（使用者空間 `vhost` 與 OVS datapath）。

### Legacy connectivity scheme on gateway (network) node