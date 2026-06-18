# Network Prerequisites (網路前提條件)

本頁面涵蓋了在部署 NICo 之前必須建置妥當的網路基礎設施，包括 IP 分配、BGP 組態設定、EVPN 疊加網路（Overlay）設定以及實體佈線。

![網路拓撲簡化圖](https://files.buildwithfern.com/nvidia-ncx-infra-controller.docs.buildwithfern.com/infra-controller/4ce930faf714a92fc485535bbd07c3b80f802bdbaa8b4d410276c8888cf6c2a9/_dot_dot_/docs/static/ncp_overview.png)

在高層級上，以下是網路需求：

*   **VNI**：依據預期的 VPC 數量分配在資料中心內唯一的 VNI。
*   **ASN**：依據預期的 DPU 數量分配全域唯一的 32 位元 ASN。
*   **IPv4 前綴**：一個全域唯一的 IPv4 前綴，其總 IP 分配大小依據以下公式計算：`(預期的伺服器數量 + 預期的 DPU 數量) * 2 + 2`。另需一個或多個額外的全域唯一 IPv4 前綴，其總 IP 分配為：`預期的 DPU 數量 * 2`。個別前綴的最小大小為 `/31`。
*   **路由**：提供租戶 EVPN 疊加網路的路由傳播機制與預設路由。

---

## IP 位址池 (IP Address Pools)

NICo 需要數個 IP 位址池。站點擁有者需提供自己的子網路和 VLAN —— 請勿使用預設的 NICo 子網路。

### 控制平面管理網路 (Control Plane Management Network)

| 項目 | 詳細資訊 |
|---|---|
| 每個節點的 IP 數（配備 DPU） | 3（主機 BMC + DPU ARM OS + DPU BMC） |
| 每個節點的 IP 數（無 DPU） | 1（主機 BMC） |
| 管理方式 | 由上層資料中心透過 DHCP 進行管理 |

### 控制平面網路 (Control-Plane Network)

每個站點控制器節點在主機 OS 與 DPU PF 表徵器（Representor）（若有 DPU）之間使用一個 `/31` 點對點子網路。IP 位址是在 OS 安裝時以靜態方式配置。如果不使用 DPU，每個節點則需要一個 IP。

### 控制平面服務 IP 池 (Control Plane Service IP Pool)

通常會使用一個 `/27` 的位址池，供運行在控制平面叢集上的服務使用。

### 受控主機的管理網路 (Management Network for Managed Hosts)

| 項目 | 詳細資訊 |
|---|---|
| 每台主機的 IP 數 | 1（主機 BMC） + 每個 DPU 2 個（DPU ARM OS + DPU BMC） |
| 管理方式 | 由 NICo 管理（可以分割至多個 IP 池） |

<Warning>頻外（OOB）交換器必須有指向 NICo DHCP 服務的 DHCP 中繼（DHCP relay）（詳情請參閱 [BMC and Out-of-Band Setup](https://docs.nvidia.com/infra-controller/documentation/getting-started/prerequisites/bmc-and-out-of-band-setup) 頁面）。</Warning>

### DPU 環回位址池 (DPU Loopback Pool)

在 DPU 網路運作期間，每個 DPU 使用一個 IP 作為 DPU 環回（Loopback）位址。

### 管理網路 (Admin Network)

在未分配租戶時，每個受控伺服器會使用一個 IP 作為其主機 IP。該位址池的容量應足夠為每台受控伺服器提供一個可用 IP，並加上子網路所需的任何網路與廣播位址。

### 租戶網路 (Tenant Networks)

當受控主機被分配給租戶時，它會加入租戶網路。可以有多個租戶網路。IP 配置由 NICo 管理。

每個租戶網路上，每台受控主機有兩個主機 IP（PF + VF）被建置為每個介面一個 `/31`。例如，一台配備 1 個 DPU 並使用該 PF 與一個 VF 的主機，在每個租戶網路上會消耗兩個 `/31` 子網路（每個介面一個 `/31`）。若有多個租戶網路，請提供獨立的位址池，每個位址池的大小均需滿足所有伺服器的需求。

---

## 自治系統編號 (Autonomous System Numbers - ASNs)

*   每個 DPU 都會從分配給 NICo 的編號池中指派一個唯一的 ASN。在多 DPU 的主機中，每個 DPU 都擁有各自的 ASN。
*   需要使用 32 位元的 ASN，以確保有足夠的唯一編號。
*   請遵循 [RFC 7938](https://datatracker.ietf.org/doc/html/rfc7938) 資料中心路由指引，以防止路徑搜尋（Path Hunting）和迴圈。
*   如果使用路由伺服器，則需要為 BGP 路由伺服器群組指定特定的 ASN（通常由備援的路由伺服器群組共享）。

---

## VNI 分配 (VNI Allocations)

*   **L3VNI**：站點中每個預期的 VPC 使用一個 VNI。每個 VPC 都需要一個唯一的 L3VNI 來識別其 VRF。
*   **L2VNI**：站點中的管理網路（Admin Network）使用一個唯一的 L2VNI。

<Note>VNI 必須在整個資料中心內是唯一的。</Note>

---

## Underlay 與 BGP 組態設定 (Underlay and BGP Configuration)

*   **啟用 eBGP 無編號（eBGP unnumbered）**：在所有面向 DPU 的葉端交換器（Leaf Switch）上啟用（RFC 5549）。
*   **指派 ASN**：根據該站點預期的 DPU 數量，分配一個唯一 AS 編號的池。
*   **宣告環回位址**：DPU 會宣告 `/32` 環回位址，作為 VXLAN 隧道端點（VTEP）。
*   **VTEP 到 VTEP 的連線性**：DPU 必須接收所有其他 DPU 的 `/32` 路由、包含這些路由的彙整路由（Aggregate Route），或是預設路由。
*   **路由篩選**：篩選 DPU 的宣告，僅保留環回位址；在葉端/Pod 層級彙整路由；在面向 DPU 的葉端交換器連接埠上設定最大前綴（max-prefix）限制。

---

## Overlay 與 EVPN 組態設定 (Overlay and EVPN Configuration)

以下是 EVPN 疊加網路（Overlay）對等互連的兩個選項：

**選項 1：與 TOR 進行雙堆疊（Dual-stack）IPv4/EVPN 工作階段**
*   TOR 除了接收現有的 IPv4 工作階段外，也接收與 DPU 的 EVPN 工作階段。
*   脊端交換器（Spine）（理想情況下包括所有層級）皆設定為與 TOR 進行 EVPN 工作階段。

**選項 2：路由伺服器 (Route-servers)**
*   部署至少兩個備援的 BGP 路由伺服器（例如在站點控制器上），以進行 EVPN 疊加網路對等互連。
*   在 DPU 與路由伺服器之間建立多躍點（Multi-hop）eBGP 工作階段（僅限 EVPN 位址家族）。
*   在疊加網路工作階段上停用 IPv4 單播（Unicast）。

NICo 不會部署或管理路由伺服器 —— 它們是你必須單獨建置的外部基礎設施。當 siteConfig 中啟用路由伺服器（`enable_route_servers = true`）時，NICo DPU 代理程式會設定每個 DPU 上的 FRR/NVUE，以與你提供的路由伺服器 IP（`route_servers = [...]`）進行對等互連。DPU 會建立一個名為 `routeserver` 的 BGP 對等群組（Peer-group），其多躍點 TTL 為 255、使用外部 AS，且僅限 L2VPN-EVPN 位址家族。

以下是更詳細的比較和理解內容

##### 選項 1：直接與 TOR 交換器進行雙堆疊會話
*   **對接對象**：DPU 直接與它接線的實體 **TOR（櫃頂交換器）** 建立連接。
*   **運作方式**：
    *   在同一個 BGP 連線中，同時傳送 Underlay（底層 IPv4 路由）與 Overlay（租戶 EVPN 路由）。這就是「雙堆疊（Dual-stack）」的意思。
    *   TOR 交換器必須支援 EVPN，且所有實體交換器（包括 TOR、Spine 等）都必須設定並參與 EVPN 路由的傳遞。
*   **優點**：架構直接，不需要額外準備伺服器來跑 BGP 路由服務。
*   **缺點**：實體交換器（TOR/Spine）的負擔較重，因為它們必須處理所有租戶的 EVPN 路由與連線，且交換器端的組態設定較複雜。

---

##### 選項 2：透過外部的「路由伺服器 (Route-servers)」
*   **對接對象**：DPU 不與 TOR 交換器建立 EVPN 連線，而是與**獨立的 BGP 路由伺服器**（通常部署在 NICo 站點控制器上）建立連線。
*   **運作方式**：
    *   實體交換器（TOR/Spine）只負責底層（Underlay）最基礎的 IPv4 封包路由，**不需要參與也完全不知道 EVPN 疊加網路的內容**。
    *   DPU 透過多躍點（Multi-hop，即透過實體網路繞路）直接與路由伺服器連線，且該連線**只用來傳遞 EVPN 路由**（停用一般的 IPv4 單播）。
    *   路由伺服器就像一個「路由中央交換局」，負責收集所有 DPU 的租戶路由，再分發給其他需要的 DPU。
*   **優點**：大幅簡化實體網路交換器的設定。交換器只需要做最簡單的 Underlay BGP 路由，完全不需要管 EVPN 疊加網路，這對大規模或多租戶環境非常有利。
*   **缺點**：需要額外架設並管理至少兩台備援的 BGP 路由伺服器（NICo 本身不負責安裝與營運路由伺服器，需手動建置）。

---

##### 快速對照表

| 比較項目 | 選項 1：與 TOR 對接 | 選項 2：透過 Route-servers |
| :--- | :--- | :--- |
| **DPU 的 BGP 對手** | 實體 TOR 交換器 | 獨立的路由伺服器（多為站點控制器） |
| **BGP 連線跳數** | 單躍點（直接接線，Single-hop） | 多躍點（透過網路轉發，Multi-hop） |
| **實體交換器要求** | 必須支援且啟用 EVPN | 僅需支援基礎 IPv4 路由（Underlay）即可 |
| **網路設定難易度** | 交換器設定較複雜 | 交換器設定極簡，但需多管路由伺服器 |
| **適用場景** | 交換器效能強大、節點規模較小 | 大規模資料中心，希望簡化實體交換器負擔 |

### 預設路由 (Default Route)

必須為疊加網路（Overlay）提供一條預設路由。選項包括：
*   允許與葉端 TOR 建立額外的 L2VPN-EVPN 工作階段，並在網路的每個層級設定相同的工作階段。
*   *設定專屬的租戶閘道（Tenant Gateways）與隔離的租戶 VRF，將其與核心路由器進行對等互連，並套用路由洩漏（Route-leaking）將預設路由注入租戶 VRF 中。*

---

## 路由目標 (Route-Targets)

標準化的通用路由目標：

| 路由目標 (Route-Target) | 用途 |
|---|---|
| `:50100` | 控制平面 / 服務 VIP —— 由站點控制器 DPU 匯出 |
| `:50200` | 內部租戶路由 |
| `:50300` | 維護網路路由 |
| `:50400` | 管理網路路由 |
| `:50500` | 外部租戶路由 |

這些是預設值，且可以進行修改，只要所有組件對這些數值達成一致即可。例如，如果你選擇 45001 作為內部通用路由目標，而不是 50200，請確保更新 NICo 組態設定以及網路設定。

**匯入/匯出原則（Import/export policies）**：

*   租戶/管理網路（`:50200` 到 `:50500`）必須匯入 `:50100` 才能連線至控制平面 VIP。
*   匯出 `:50100` 的站點控制器必須匯入 `:50200` 到 `:50500`，才能連線至所有受控端點。

<Note>雖然許多部署為了管理上的簡便而將路由目標（Route Target）編號與 VNI 對齊，但路由策略嚴格受路由目標的匯入/匯出（Import/Export）組態控制，而非 VNI 本身。</Note>

---

## 交換器組態設定 (Switch Configuration)

以下是最低的交換器組態設定要求：

*   將連接至站點控制器（或其 DPU）的 TOR 連接埠設定為 BGP 無編號（BGP unnumbered）工作階段。
*   啟用 LACP 的傳送和接收模式。
*   設定 BGP 路由對照表（Route Maps）以接受委派路由（Delegated routes）。
*   啟用 EVPN 位址家族。
*   接受來自站點控制器的雙堆疊（IPv4 + EVPN）工作階段。
*   設定站點控制器匯出服務 VIP，並附帶專屬的 EVPN 路由目標，使所有受控主機的 DPU 進行匯入。
*   設定站點控制器匯入所有內部租戶網路、外部租戶網路，以及任何服務連線所需的額外路由目標之 EVPN 路由目標。

---

## 站點控制器網路拓撲 (Site Controller Networking Topology)

以下是連接站點控制器節點到網路主幹（Network Fabric）的兩個常見選項：單一上行鏈路（Single Uplink）與雙主機上行鏈路（Dual-homed Uplink）。

### 選項 1：單一上行鏈路，邏輯隔離

使用一張實體網卡（NIC），承載以下內容：

*   **管理 VLAN（Mgmt VLAN）**：主機/SSH/apt/軟體包存取
*   **K8s 節點流量**：API 伺服器、Kubelet
*   **Pod/服務流量**：疊加網路（Overlay）或經由路由

### 選項 2：雙主機上行鏈路（參考設計）

此設計要求站點控制器上的 DPU 處於 DPU 模式（DPU mode）。

*   站點控制器通常使用配備兩個上行鏈路的單一 DPU/網卡，每個鏈路分別接線到參與 BGP 無編號的不同 ToR 交換器。
*   兩條鏈路皆承載管理與 Kubernetes 流量；隔離是透過 VLAN/VRF 和策略來完成，而不是透過將一張網卡專門用於管理、另一張專門用於資料平面。

---

## 實體佈線 (Physical Cabling)

*   將 DPU 連接至 ToR/EoR 交換器（為求備援，建議採用雙主機/Dual-homed 連線）。
*   確保為 DPU BMC 提供獨立的頻外（OOB）管理連線。

---

## 一般指南 (General Guidance)

| 設定項目 | 建議 |
|---|---|
| MTU | 疊加網路（VXLAN/Geneve）使用 1500；僅在底層網路（Underlay）支援端到端巨型訊框時才使用 9000 |
| DNS | 企業級解析程式（Resolvers）；可選擇使用 NodeLocal DNS 快取 |
| 閘道/路由 | 依站點標準採用靜態或路由（BGP）——不依賴 NICo 路由 |
| 網路綁定 (Bonding)/LACP | 選用，以進行網卡備援；否則採用單純的主動/被動（Active/Standby）模式 |
| 防火牆 | 依選用的 CNI 允許 K8s 控制平面與節點連接埠，並允許來自安全管理網路的 SSH 連線。預設阻擋所有其他連線。 |

---

## 重點整理 (Key Takeaways)

1. **網路資源分配標準**：
   * **VNI**：每個 VPC 需要獨立唯一的 L3VNI。
   * **ASN**：為了避免路由迴圈與滿足架構需要，必須使用 32 位元 ASN，每個 DPU 指派唯一 ASN。
   * **IP 池規劃**：必須由站點自行提供子網路和 VLAN，禁止使用預設的 NICo 子網路。IP 位址公式考量了主機/DPU 的雙向介面需要。

2. **Underlay 與 BGP 原則**：
   * 在面向 DPU 的 TOR 交換器上全面啟用 BGP 無編號（eBGP unnumbered - RFC 5549）。
   * DPU 僅宣告 `/32` 環回位址，用於建立 VXLAN 隧道端點（VTEP），並限制最大前綴（max-prefix）。

3. **Overlay 與 EVPN 對等互連選項**：
   * **選項 1**：與 ToR 交換器建立雙堆疊 IPv4/EVPN 會話。
   * **選項 2**：透過獨立的外部路由伺服器（Route-servers）進行多躍點（multi-hop）eBGP 對等互連，且會話僅限 EVPN 家族。

4. **路由目標（Route-Target）規範**：
   * 使用預設的 RT 段（`:50100` 用於控制平面，`:50200` 至 `:50500` 分別用於內部租戶、維護、管理與外部租戶網路）。
   * 租戶與管理網路必須 Import 控制平面 RT (`:50100`)，站點控制器則需 Import 所有其他網路 RT，以維持雙向連通性。
