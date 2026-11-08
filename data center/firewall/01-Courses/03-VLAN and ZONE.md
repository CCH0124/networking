# VLAN and Zone

## 核心概念解析

參考拓樸

```text
+-----------------------+                    +-----------------------+
|      DMZ-SW           |                    |     FortiGate (FW1)   |
| (Cisco Switch)        |                    |                       |
|                       |   802.1Q Trunk     |  實體介面: port4      |
|  Eth 0/0 [Trunk] =====+====================+==>  (0.0.0.0/0)       |
|                       |  (VLAN 20, 30)     |       |               |
|  Eth 0/1 [Access 20]  |                    |       +-- SRV1 (VLAN20: 10.0.2.254/24)
|  Eth 0/2 [Access 30]  |                    |       +-- SRV2 (VLAN30: 10.0.3.254/24)
+-------+-------+-------+                    +-----------------------+
        |       |
        |       |
   [Access]   [Access]
        |       |
        v       v
     +-----+ +-----+
     |SRV1 | |SRV2 |
     | .1  | | .2  |
     +-----+ +-----+
     VLAN 20 VLAN 30
  (10.0.2.0) (10.0.3.0)
```

### 1. VLAN（虛擬區域網路，Layer 2 / Layer 3 界面）

* **本質**：屬於**網路層/資料鏈結層**技術（IEEE 802.1Q）。

* **FortiGate 中的角色**：
    * FortiGate 將 VLAN 視為綁定在實體介面（如拓撲中的 `port4`）上的**邏輯子介面（Sub-interface）**。
    * 每個 VLAN 介面擁有獨立的 VLAN ID、IP 網段、網關與廣播域（Broadcast Domain）。
    * 拓撲中，`port4` 作為 Trunk 口，承載了 `SRV1`（VLAN 20: `10.0.2.254/24`）與 `SRV2`（VLAN 30: `10.0.3.254/24`）兩個網段。


### 2. Zone（安全區域，Policy Layer / 物件容器）

* **本質**：屬於**安全性與管理層**概念，用來將一個或多個邏輯或實體介面（如實體 port、VLAN 介面）捆綁在一起。


* **FortiGate 中的角色**：
    * **簡化政策管理**：在防火牆策略中，可以直接以「Zone」作為來源或目的介面（如 `DMZ-ZONE`），而不需要為底下每個介面各自寫一條 Policy。


* **預設行為與流量控制**：
    * **Inter-zone traffic**：跨 Zone 流量預設全部阻擋，必須有明確的 Firewall Policy 才能放行。
    * **Intra-zone traffic**：同一個 Zone 內部不同成員介面之間的流量，可透過開關 **`Block intra-zone traffic`** 一鍵設定是否允許互相存取。


## 它們帶來什麼效益？

| 維度 | 單用 VLAN 的情況 | VLAN 結合 Zone 的效益 |
| --- | --- | --- |
| **介面與硬體節省** | 透過單一實體線路（Trunk）切分多個獨立網段，不需為每個伺服器拉一條實體線。 | 同樣享有實體簡化的好處。|
| **策略維護量 (Policy Complexity)** | 每個 VLAN 都需要獨立配置政策。例如：VLAN 20 到 Internet、VLAN 30 到 Internet 需要寫兩條策略。 | **策略數量減半**。只需建立一條 `DMZ-ZONE` $\to$ `WAN` 的策略，所有成員立刻套用相同的安全規則。 |
| **橫向移動防禦 (Lateral Movement)** | 若要禁止不同伺服器互訪，需手動編寫多條拒絕或限制規則。 | 勾選 **`Block intra-zone traffic`**，即可一鍵隔離 Zone 內各 VLAN 介面，防止內網橫向滲透。 |
| **擴展性 (Scalability)** | 日後新增 `VLAN 40 (SRV3)` 時，需重寫一套去往 WAN、LAN 的所有策略。 | 新增 VLAN 介面後，只需將其**加入該 Zone**，該介面即自動繼承所有既有策略，大幅降低維護成本與配置疏失。 |


## 在 DMZ（非軍事區）場景的實際應用

提供的實驗拓撲中，DMZ 區域通常放置對外提供服務的伺服器（如 Web Server、Mail Server），是最容易遭受外部攻擊的區域。

#### 網路實體與邏輯劃分（VLAN 的應用）

* **伺服器職能隔離**：
    * 在 Switch 上將不同用途的伺服器劃分在不同的 Access VLAN（例如：SRV1 屬 VLAN 20，SRV2 屬 VLAN 30）。
    * 經由單條 Trunk 線路接入 FortiGate 的 `port4`。
    * **效果**：即使攻擊者攻破了 `SRV1`（例如利用 Web 漏洞），因為 Layer 2 廣播域已被切開，攻擊者無法直接在同一個廣播域嗅探封包或發動 ARP 欺騙。

#### 安全邊界統一與策略簡化（Zone 的應用）

1. **建立 `DMZ-ZONE**`：
    * 將 `SRV1 (VLAN20)` 與 `SRV2 (VLAN30)` 介面納入 `DMZ-ZONE` 作為成員。

2. **啟用 `Block intra-zone traffic**`：
    * 當此選項開啟時，即便 `SRV1` 與 `SRV2` 都在同一個 `DMZ-ZONE` 內，兩者之間的 Layer 3 路由流量直接被防火牆硬性封鎖，杜絕了 DMZ 伺服器間互相攻擊的可能。

3. **對外/對內統一策略**：
    * **出網/更新需求**：建立一條 `DMZ-ZONE -> WAN-2 (port2)` 策略即可讓所有 DMZ 伺服器連外更新套件或同步時間。
    * **內部管理/進站訪問**：建立 `LAN -> DMZ-ZONE` 或 `WAN -> DMZ-ZONE (VIP)`，集中套用相同的 IPS/AV（入侵防禦/防毒）安全設定檔，大幅降低策略繁雜度。
