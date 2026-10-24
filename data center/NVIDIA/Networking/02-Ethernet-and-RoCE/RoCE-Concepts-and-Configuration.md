# RDMA over Converged Ethernet (RoCE) 核心概念

**RoCE (RDMA over Converged Ethernet)** 是指在標準乙太網路（Ethernet）基礎設施上，執行 **RDMA（Remote Direct Memory Access，遠端直接記憶體存取）** 技術的業界標準協定。

1. 傳統網路 vs. RoCE 的差異
* **傳統 TCP/IP 網路**：資料傳輸需要經過作業系統核心（OS Kernel）、多重記憶體複製（CPU Memory Copy）與 TCP/IP 協定棧解析，會產生顯著的 CPU 開銷與延遲。
* **RoCE 技術**：採用 **Kernel Bypass（核心旁路）** 與 **Zero-Copy（零拷貝）** 機制，網卡（HCA / SuperNIC）能直接將資料寫入遠端伺服器或 GPU 的記憶體，達成微秒 $\mu$ s 等級的極低延遲與高吞吐量。

2. RoCEv2 傳輸層封裝
* **RoCEv2** 將 InfiniBand 傳輸層協定直接封裝於 **UDP/IP** 封包之內（預設目的 UDP Port 為 `4791`）。
* 由於具備標準 L3 IP 標頭，RoCEv2 具備可路由（Routable）特性，能跨越 Spine-Leaf 等三層資料中心 IP Fabric 進行傳輸。

3. 無損乙太網（Lossless Ethernet）兩大支柱
RoCE 依賴交換器與網卡協同運作，防止網路發生丟包與重傳：
* **PFC (Priority Flow Control, IEEE 802.1bb)**：按優先權佇列（如 RoCE 專用的 Priority 3）進行逐跳流量控制。當接收端緩衝區接近滿載時，向對端發送 Pause 影格暫停該佇列發送，其餘流量不受影響。
* **ECN (Explicit Congestion Notification, RFC 3168)**：端到端壅塞控制。中間交換器佇列堆積時於 IP 標頭標記 CE 位元，接收端收到後傳回 **CNP (Congestion Notification Packet，預設 Priority 6)** 封包，通知發送端網卡主動降低傳輸速率。

---

## RoCE 在 Cumulus Linux 中的運作架構圖

```text
[ Sender Host / GPU ]                           [ Cumulus Linux Switch ]                        [ Receiver Host / GPU ]
        |                                                  |                                               |
        | === (1) RoCE Data Stream (UDP:4791, DSCP 26) ==> |                                               |
        |     Classified to Switch Priority 3 / TC 3       | [ Shared Buffer Filling ]                     |
        |                                                  |   Queue Depth > ECN Min Threshold             |
        |                                                  | === (2) Forward Data with Marked ECN CE (11) =>|
        |                                                  |                                               | [ Detect CE=11 ]
        | <================ (3) Return CNP Packet (DSCP 48 / Priority 6, Strict Priority) ================= |
        |                                                  |
        | [ Hardware Rate Limiter Actuated: ]              | [ If Buffer reaches XOFF Threshold ]
        |   Throttles Sending Rate                         | <--- (4) PFC Pause Frame (Priority 3) ------- |
        v                                                  v
```

---

## Cumulus Linux 預設 RoCE 配置行為

在 **Cumulus Linux** 中啟用 RoCE 時，NVUE 會在底層自動套用以下預設的 QoS 與佇列對應策略：

下表顯示了有損模式（Lossy Mode）與無損模式（Lossless Mode）下的預設 RoCE 配置：

| 配置項目（Configuration） | 有損模式（Lossy Mode） | 無損模式（Lossless Mode） |
| :--- | :---: | :---: |
| **連接埠信任模式（Port trust mode）** | **是 (YES)** | **是 (YES)** |
| **連接埠交換器優先權至流量類別映射（Priority to TC Mapping）**<br>Switch priority 3 映射至 Traffic class 3（RoCE 數據）<br>Switch priority 6 映射至 Traffic class 6（CNP 壅塞通知）<br>其餘 Switch priority 映射至 Traffic class 0（一般流量） | **是 (YES)** | **是 (YES)** |
| **連接埠增強型傳輸選擇（Port ETS 排程）**：<br>Traffic class 6 (CNP) — **嚴格優先（Strict Priority）**<br>Traffic class 3 (RoCE) — **DWRR 50% 頻寬**<br>Traffic class 0 (其他流量) — **DWRR 50% 頻寬** | **是 (YES)** | **是 (YES)** |
| **連接埠針對 Traffic class 3 (RoCE) 的 ECN 絕對門檻值**<br>設定為 **1,501,500 位元組（Bytes）** | **是 (YES)** | **是 (YES)** |
| **LLDP 與 Application TLV (RoCE)**<br>(宣告 RoCEv2 使用 UDP 埠號 4791，對應優先權 Priority 3) | **是 (YES)** | **是 (YES)** |
| **在 Switch priority 3 (RoCE) 上啟用 PFC** | **否 (NO)** | **是 (YES)** |
| **將 Switch priority 3 分配給 RoCE 無損緩衝池（Lossless Traffic Pool）** | **否 (NO)** | **是 (YES)** |

---

### 解析

#### 1. 有損（Lossy）vs. 無損（Lossless）的真正差異只有「最底下兩行」
* **共同點**：兩種模式都啟用了 **ECN（顯式壅塞通知）**、相同的佇列排程（ETS）與優先權映射（Priority 3 跑 RoCE、Priority 6 跑 CNP）。
* **唯一差異**：
  * **Lossless Mode（無損模式）**：額外開啟了 **PFC（Priority Flow Control）**，並在交換器晶片內切出專屬的 **`roce-lossless` 緩衝池（Buffer Pool）**，確保在極度壅塞時能發送 PAUSE 訊框做到「絕對不掉包」。
  * **Lossy Mode（有損模式）**：完全依賴 **ECN** 來控制傳輸速度，不發送 PFC PAUSE 訊框（避免發生 PFC 死鎖與暫停風暴風險）。

#### 2. 為什麼 CNP（壅塞通知封包）被分配在 Priority 6 且設為 Strict？
* **CNP（Congestion Notification Packet）** 是接收端在發現 ECN 標記後，緊急回傳給發送端的剎車指令。
* 如果剎車指令跟著一般資料封包一起排隊，發送端就無法及時降速。因此系統將其獨立放在 **Traffic Class 6** 並賦予 **Strict（絕對優先發送）**，確保剎車指令在微秒內送達

#### 3. UDP Port 4791 的意義
* **RoCEv2** 是封裝在 UDP 協定之上的 RDMA 技術，其 IANA 官方標準定義的目的連接埠（Destination Port）就是 **4791**。交換器透過 LLDP TLV 能自動向對端主機宣告與協商此協定與優先權設定。

---

## 四、 如何在 Cumulus Linux (NVUE) 配置 RoCE

#### 1. 一鍵啟用全域 RoCE 無損模式 (Lossless Mode)
NVUE 提供全域預設命令，執行後會自動配置所有的 QoS 佇列、PFC、ECN 與 LLDP DCBX TLV：
```bash
cumulus@switch:~$ nv set qos roce
cumulus@switch:~$ nv config apply
```

> ![NOTE]
> `nv set qos roce` 與 `nv set qos roce mode lossless` 效果相同

#### 2. 切換為 RoCE 有損模式 (Lossy Mode)
若應用情境不需使用 PFC，僅依賴 ECN 進行降速控制：
```bash
cumulus@switch:~$ nv set qos roce mode lossy
cumulus@switch:~$ nv config apply
```

#### 3. 啟用單一共享緩衝池模式 (Lossless Single Shared Buffer Pool)
將 Ingress 的有損與無損流量合併至同一共享記憶體池，提供更高的突發流量吸收能力：
```bash
cumulus@switch:~$ nv set qos roce mode lossless-single-ipool
cumulus@switch:~$ nv config apply
```

#### 4. 調整 RoCE 無損記憶體池比例 (Memory Percent)
若需修改劃分給 `roce-lossless` 的記憶體比例（例：分配 60% 給無損池，40% 給有損池）：
```bash
cumulus@switch:mgmt:~$ nv set qos traffic-pool default-lossy memory-percent 40
cumulus@switch:mgmt:~$ nv set qos traffic-pool roce-lossless memory-percent 60
cumulus@switch:mgmt:~$ nv config apply
```

---

## 五、 驗證與監控指令

* **檢視全域 RoCE 配置與狀態**：
  ```bash
  cumulus@switch:~$ nv show qos roce
  ```
 
* **檢視特定介面（如 `swp16`）之 RoCE 運作狀態**：
  ```bash
  cumulus@switch:~$ nv show interface swp16 qos roce status
  ```
 
* **檢視實時與歷史 RoCE 流量包數、PFC 發送計數與 ECN 標記統計**：
  ```bash
  cumulus@switch:~$ nv show interface swp16 qos roce counters
  ```
 
