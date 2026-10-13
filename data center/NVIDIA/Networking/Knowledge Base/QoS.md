# Quality of Service
在資料中心與高效能網路環境中，**Quality of Service (QoS，服務品質)** 是用於管理、分類、調度與控制網路流量的核心機制。其主要用意在於當網路發生擁塞或多種不同特性的業務流量共用同一網路通道時，確保關鍵業務（如 AI 訓練之 RoCE 流量、控制平面訊號、即時傳輸資料）獲得預期的頻寬保障、微秒級低延遲與極低的封包遺失率，避免非關鍵流量佔滿硬體緩衝區與傳輸頻寬。

在 Cumulus Linux 中支援多種不同的 QoS 功能和標準，包括：
* COS and DSCP marking and remarking
* Shaping and policing
* Egress traffic scheduling (802.1Qaz, Enhanced Transmission Selection (ETS))
* Flow control with IEEE Link Pause and PFC, and congestion control with ECN
* Lossless and lossy RoCE

## 1. 流量分類與信任機制 (Classification & Trust Mode)

1. **內部 Switch Priority (CoS) 映射**：
   * 當數據影格或封包進入交換器時，系統會將其分類並映射至內部的 **Switch Priority**（範圍為 0 至 7，內部預留 CoS 3 給 CPU 生成的流量）。
   * 值永遠不會寫入幀(frame)或資料包(packet)
2. **信任模式 (Trust Mode)**：
   * **Trust L2 (802.1p / PCP)**：依據 VLAN Tag 中的 802.1p 優先權數值（0–7）映射至內部的 Switch Priority。
   * **Trust L3 (DSCP)**：依據 IP 表頭中的 DiffServ Code Point (DSCP) 數值（0–63）映射至內部的 Switch Priority。
   * **Trust Port**：不論進入封包的 L2/L3 標記為何，一律強制指定為特定的預設 Switch Priority。

If you use NVUE to configure QoS, you define which values are trusted with the `nv set qos mapping <profile> trust l2` command (802.1p) or the `nv set qos mapping <profile> trust l3` command (DSCP) .

### Switch Priority (0 – 7) 的作用

**Switch Priority（內部交換器優先權，亦稱內部 CoS / Class of Service）** 是數據封包進入交換器後，內部晶片管道（ASIC Data Path）用來標示該封包優先等級的 **內部 3-bit 抽象數值（範圍為 0 至 7）**。

#### 核心特性與作用：
1. **絕不寫入外部封包標頭**：
   Switch Priority 僅存在於交換器內部的 ASIC 處理流程中，**永遠不會直接修改或寫入實體封包的外部 L2/L3 標頭**。
2. **作為 QoS 內部的「中樞橋樑」**：
   因為不同網路層級的標記規格不同（L2 只有 8 個等級，L3 有 64 個等級），交換器透過 Switch Priority 建立一個標準化的內部統一視角。
3. **決定後續所有 QoS 處理流程**：
   封包被賦予特定 Switch Priority 後，交換器據此決定：
   * **出口佇列映射 (Egress Queue / Traffic Class)**：預設情況下，Switch Priority $(N)$ 會直接映射至出口的 Traffic Class $(N)$（0–7）。
   * **優先權流量控制 (PFC)**：決定該封包是否屬於無損（Lossless）池，以及是否觸發特定優先權的 PFC Pause 影格（如對 Switch Priority 3 啟用 PFC）。
   * **出口重標記 (Egress Remarking)**：決定封包離開交換器時，是否重新改寫外部的 802.1p 或 DSCP 標記。


## 2. 流量標記與重標記 (Marking & Remarking)

* **目的與用意**：當數據封包經過交換器處理並準備由出口轉發時，將內部的 Switch Priority 重新寫入（Remark）為全新的 L2 802.1p 或 L3 DSCP 數值，以便跨網域或下游網路設備繼續識別並執行相同的 QoS 策略。
* **實作方式**：可透過全域 Profile、Port Group 或基於 ACL (iptables / ebtables) 進行 Policy-based 標記。


---

## 3. 出口調度與佇列管理 (Egress Scheduling & Queues)

1. **出口佇列 (Egress Queues)**：
   * 交換器提供 8 個獨立的出口佇列（Traffic Class 0–7），預設將內部 Switch Priority 一對一映射至相對應的出口佇列。
2. **排程演算法 (Scheduler Modes - IEEE 802.1Qaz / ETS)**：
   * **Strict Priority（嚴格優先權）**：優先度最高的佇列（如 PTP 時間同步或控制訊號）擁有絕對優先傳送權，直到該佇列清空後才處理其他佇列。
   * **DWRR (Deficit Weighted Round Robin，赤字加權輪詢)**：針對一般資料佇列設定頻寬百分比（`bw-percent`），按權重比例平分出口頻寬。

### Egress Queues

#### 1. 什麼是「8 個出口佇列」？
交換器的每個實體網路孔在把封包「發送出去（Egress）」之前，內部都設有 8 條獨立的專用排隊走道（Queue 0 至 Queue 7），類似機場的報到櫃檯：
* **低優先權佇列（如 Queue 0）**：給一般網頁瀏覽、日常檔案傳輸（Best-effort 盡力而為流量）。
* **高優先權佇列（如 Queue 3 或 Queue 4）**：通常專門留給 **AI 訓練的 RoCEv2 流量**或儲存網路，享受無損（Lossless）與優先發送待遇。
* **最高優先權佇列（如 Queue 7）**：保留給網路控制訊號（BGP、LLDP、心跳封包等），確保網路管理永不斷線。

#### 2. 預設 vs. 重新映射（Remapping）

* **預設情況（1:1 映射）**：
  $$\text{Priority 0} \rightarrow \text{Queue 0}$$
  $$\text{Priority 1} \rightarrow \text{Queue 1}$$
  $$\dots$$
  $$\text{Priority 7} \rightarrow \text{Queue 7}$$

* **多對一映射（Many-to-One Mapping）**：
  如果您的網路不需要分得那麼細，可以把多個優先權合併排入同一條走道。例如：
  * 將 Priority 0、1、2 全部導入 **Queue 0**（一般流量集中處理）。
  * 將 Priority 3、4 導入 **Queue 4**（AI / 儲存 RoCE 流量）。
  * 這樣可以簡化佇列排程（Scheduler）與緩衝區（Buffer）的管理。

#### 3. 技術串連

在前面學到的 **PFC** 與 **ECN** 中，交換器都是**「以佇列（Queue）為單位」**來做精準控管的：
* **PFC**：只暫停特定佇列（如 Queue 4 凍結，其他 Queue 照常暢行）。
* **ECN**：監控特定佇列的緩衝區深度（如前一篇指令中的 `traffic-class 4,5,7` 其實就是在設定這些 Queue 的 ECN 閾值）。

### Egress Scheduler

Cumulus Linux 支援 **IEEE 802.1Qaz 標準的「增強型傳輸選擇（ETS，Enhanced Transmission Selection）」**，該標準允許交換器為各個**出口佇列（Egress Queues）**分配保證頻寬，並排程發送各佇列中的流量。802.1Qaz 同時支援**優先權排程（Priority Queuing / Strict Priority）**。

#### 什麼是 802.1Qaz（ETS）？

交換器有 8 個出口佇列（Queue 0 ~ 7）。**ETS 就像是「流量交通警察」**，決定當多個佇列同時有資料要衝出網口時，各佇列能分到多少頻寬比例。

ETS 支援兩種排程模式的混搭：

1. **嚴格優先權（Strict Priority，文中稱為 strict）**：
   * **「老大先走」模式**：只要標註為 Strict 的佇列裡有封包，交換器會**100% 優先處理它**，直到這個佇列完全清空，才會輪到其他佇列。
   * *適用情境*：網路控制協議（BGP、STP）或極度敏感的即時語音/視訊。
2. **加權輪詢分配（Bandwidth Percentage / DWRR）**：
   * **「按比例分餅」模式**：各佇列依分配到的百分比（如 30%、20%）輪流發送封包，確保不會有任何佇列被完全「餓死（Starvation）」。
   * *適用情境*：AI 運算流量（RoCEv2）、儲存備份流量、一般網頁流量。

---

#### 範例的頻寬分配剖析

範例中的配置方式是資料中心非常經典的 QoS 架構：

```text
[總頻寬 100%]
 │
 ├── 👑 Strict 優先權（Queue 0, 1, 5, 7）:
 │     只要有封包就立刻插隊發送（通常給控制協定或高優先權服務）
 │
 └── ⚖️ 剩餘頻寬依比例分配 (總計 100%):
       ├── Queue 2 : 30% ┐ (共 60%，給一般高流量業務)
       ├── Queue 6 : 30% ┘
       ├── Queue 3 : 20% ┐ (共 40%，例如專屬 AI 訓練 / 儲存流量)
       └── Queue 4 : 20% ┘
```
---

## 4. 流量整形與流量監管 (Traffic Shaping & Policing)

流量整形和監管控制交換器在網路上發送或接收流量的速率，以防止擁塞。

1. **Traffic Shaping（流量整形）**：
   * **用意**：將超出設定速率的流量暫存於記憶體緩衝區（Buffer）中，並以平滑的速率發送，避免突發流量（Traffic Bursts）造成下游設備衝擊。
   * **層級**：支援兩層階層式 Shaping（個別 Egress Queue 的 `min-rate` / `max-rate` 以及實體 Port 的 `port-max-rate`，單位可設定為 kbps 或 pps）。
2. **Traffic Policing（流量監管）**：
   * **用意**：限制介面接收或發送的最高傳輸速率，當流量超過設定門檻時直接將超出部分丟棄（Tail Drop）或進行降級標記。支援 Single-rate 與 Dual-rate/Tricolor Policer。


| 比較項目 | 流量整形（Traffic Shaping） | 流量管制（Traffic Policing） |
| :--- | :--- | :--- |
| **處理超額流量的手法** | **「排隊慢走（緩存延遲）」**<br>把突發流量先暫存在 Buffer，依節奏平滑送出。 | **「直接丟棄（毫不留情）」**<br>超過上限的封包直接丟掉（Drop）或改標記降級。 |
| **主要作用方向** | 通常用在**出口（Egress / 出去前）** | 通常用在**入口（Ingress / 剛進來時）**或出口 |
| **封包延遲 / 抖動** | 會**增加延遲**（因為封包在隊列裡排隊） | **不增加延遲**（要嘛過、要嘛丟） |
| **波形視覺感受** | **削峰填谷（Smooth 平滑曲線）** | **直接削平（硬切平頭線）** |
| **常見生活比喻** | 高速公路交流道紅綠燈（車流排隊依序放行） | 地鐵旋轉閘門（超過刷卡人數直接卡死擋在外面） |

#### 關鍵應用場景

1. **何時用 Shaping？**
   * 當本端是 100G 交換器，對端主機網卡只有 10G 或 25G 時，若直接 100G 暴衝過去對方必掉包。此時用 **Shaping** 把流量平滑降速送出。
2. **何時用 Policing？**
   * 雲端多租戶防禦、DDoS 防護或 ISP 頻寬販售。例如客戶只買了 1Gbps 方案，只要進來的流量超過 1Gbps，立刻用 **Policing** 丟掉超出部分，保護資料中心內部網路骨幹不受衝擊。
---

## 5. 流控與壅塞控制 (Flow Control & Congestion Control)

流量控制會影響資料傳輸以管理網路路徑上的擁塞。

1. **Link Pause (IEEE 802.3x)**：
   * 當交換器接收緩衝區達到高水位門檻時，向對端發送 Pause 影格，**暫停整條實體鏈路**的所有數據傳輸。
2. **Priority Flow Control (PFC, IEEE 802.1bb)**：
   * **無損乙太網（Lossless Ethernet）核心**。專門針對特定的 Switch Priority（例如 RoCE 專用的 Priority 3）發送 Pause 影格，僅暫停該優先權佇列，其餘優先權的流量仍可正常傳送。
3. **PFC Watchdog（PFC 看門狗）**：
   * **用意**：監控鏈路是否因異常或環路陷入持續性的 Paused 狀態（PFC Deadlock）。當鎖定時間超過門檻時自動解鎖該佇列並丟棄封包，防止連鎖反應癱瘓整體網路。
4. **Explicit Congestion Notification (ECN, RFC 3168)**：
   * **端到端 L3 壅塞控制**。當交換器出口佇列深度介於 `min-threshold` 與 `max-threshold` 之間時，交換器在 IP 標頭中標記 CE (11) 位元，由接收端主機通知傳送端主機主動降低發送速率，從源頭避免佇列溢位與丟包。

### Flow Control Buffers 的核心概念

**Flow Control Buffers** 指的是在交換器共享記憶體（Shared Buffer）中，**專門分配給無損流量（Lossless Flows）與有損流量（Lossy Flows）的記憶體緩衝池（Buffer Pool Memory）**。

* **預設分配狀態**：在預設情況下，Cumulus Linux 會將交換器 **100% 的緩衝區記憶體** 全部分配給 `default-lossy`（預設有損流量池）。
* **無損傳輸的前提條件**：當要在連接埠上啟用 **Link Pause (802.3x)** 或 **Priority Flow Control (PFC, 802.1bb)** 時，必須先手動調整緩衝區配置，從總記憶體中切出一塊專屬的無損緩衝池（如 `default-lossless` 或 `roce-lossless`）。

---

### Flow Control Buffers 與「流控/壅塞控制」的關聯性

之所以需要先設定 **Flow Control Buffers**，原因如下：

##### 1. 為何 PFC / Link Pause 必須依賴 Flow Control Buffers？
* **吸收信號傳輸與反應延遲 (Headroom / Flight Time Absorption)**：
  當交換器的接收緩衝區達到告警門檻（`XOFF`）時，交換器會向對端發送 Pause / PFC 影格要求暫停發送。但因為**實體纜線傳播延遲（Cable Length）**與**網卡/交換器晶片（PHY/MAC）處理延遲**，對端網卡在收到 Pause 指令前，線路上仍在傳輸的「飛行中數據（Packets in flight）」會持續湧入。
* **防範緩衝區溢位丟包**：
  這段微秒時間內抵達的數據，必須被存放於 Flow Control Buffer 專屬預留的 **Headroom 緩衝區**中。若沒有提前劃分專屬的 Flow Control Buffer，這些突發數據將無處可放而被直接丟棄（Tail Drop），導致「無損（Lossless）」機制失效。

##### 2. 與 ECN 壅塞控制的協同運作
* ECN 是基於出口佇列深度（`min-threshold` 與 `max-threshold`）來進行 CE 標記的 L3 壅塞控制。
* ECN 門檻的計算與發揮作用，正是建立在各 Traffic Class 所綁定的 Flow Control Buffer 結構之上。

---

#### Cumulus Linux 中的 Traffic Pools（緩衝池種類）

在 NVUE 配置中，Flow Control Buffers 主要透過以下 **Traffic Pools** 進行管理：

* **`default-lossy`**：預設一般乙太網路流量緩衝池。
* **`default-lossless`**：一般 Link Pause 或 PFC 無損流量緩衝池。
* **`roce-lossless`**：專為 RoCEv2（如 AI 訓練 Priority 3）最佳化之無損流量緩衝池。
* **`mc-lossy`**：多播（Multicast）流量緩衝池。

---

#### NVUE 標準配置命令範例

在啟用 PFC 或 Link Pause 之前，必須先劃分 Flow Control Buffers（總和不得超過 100%）：

```bash
# 1. 劃分 50% 給無損流量池，50% 給預設有損流量池
cumulus@switch:~$ nv set qos traffic-pool default-lossless memory-percent 50
cumulus@switch:~$ nv set qos traffic-pool default-lossy memory-percent 50
cumulus@switch:~$ nv config apply
```

### 為什麼需要 PFC Watchdog？

在現代 AI 與分散式儲存（RoCEv2）網路中，PFC 是一把雙面刃：

1. 什麼是「背壓（Backpressure）」與「暫停風暴（Pause Storm）」？
* **正常情況**：當 Switch B 的緩衝區快滿時，向上游 Switch A 發送 `PAUSE` 訊框：「先別送！」，等消化完再恢復，做到「零掉包（Lossless）」。
* **災難情境（死鎖 / 風暴）**：如果某台伺服器故障、NIC 驅動當機或網路產生環路（Loop），導致該節點**瘋狂發送 PAUSE 訊框**。Switch B 被暫停後緩衝區立刻被填滿，只好回頭向 Switch A 發 PAUSE，Switch A 又向 Switch C 發……這股**「背壓（Backpressure）」會像骨牌一樣迅速蔓延整座資料中心**，最後導致完全無關的伺服器也跟著斷網癱瘓（PFC Deadlock）。

2. PFC Watchdog 的應對策略：「壯士斷腕」

PFC Watchdog 就像是一個安全保險絲：
```text
[偵測階段]
若某個佇列被 PAUSE 凍結的時間超過閾值（例如 > 100ms）
   ⬇
[判定]：這不是正常的短暫塞車，而是發生了「暫停風暴 / 異常背壓」！
   ⬇
[緩解手段（壯士斷腕）]
1. 不理會 PAUSE：直接忽視對端送來的暫停訊框，強行恢復發送。
2. 啟動丟包（Drop）：把該佇列累積的新封包直接丟棄，清空 Buffer。
   ↳ 代價：該特定連線會掉包。
   ↳ 好處：切斷背壓骨牌效應，拯救整個資料中心的其餘網路不被拖垮！
   ⬇
[恢復階段]
定時輪詢監控，一旦對端不再發送 PAUSE 訊框，立刻自動恢復為正常的 PFC 無損狀態。
```

3. PFC vs. Link Pause（802.3x）的差異

* **PFC（802.1Qbb）**：針對特定優先權（Priority 0~7）暫停，只會凍結高優先權的 RoCE 流量，不影響普通流量。
* **Link Pause（802.3x）**：針對整個實體線路暫停，一旦風暴觸發，整個 Port 的所有流量（所有 Queue）通通停擺。Watchdog 對 Link Pause 的處理也是直接把整個 Port 的所有出口佇列啟動丟包來解套。

#### Cumulus 5.16.8 中新機制

##### 1. 觸發時間的計算公式（Detection Time）
在舊版或傳統架構中：
$$\text{觸發緩解時間} = \text{polling-interval} \times \text{robustness}$$
以範例中的設定為例：$200\text{ ms} \times 5 = 1000\text{ ms}$（1 秒）。這表示交換器會連續檢查 5 次（每次間隔 200ms），如果每次都符合條件，滿 1 秒後就會觸發丟包緩解。

##### 2. 為什麼 Cumulus Linux 5.16.8 的「三條件判定」是重大改進？
在舊版網路中，PFC Watchdog 很容易**「誤殺（False Positive）」**：
* **舊痛點**：在高效能 AI 運算中，突發大流量是很常見的，這時常常收到很多 PAUSE 訊框。如果 Watchdog 太敏感，把正常的「高負載塞車」誤判為「死鎖」而直接把封包丟掉，會導致 AI 訓練直接報錯中斷。
* **新解法**：新版本引入了**「車流到底有沒有在動？」**的判斷邏輯：
  * **壅塞（Congestion）**：雖然路上大塞車（Queue 滿了、收到暫停），但車子還是一台一台慢慢開過去（`tx-frames > threshold`），這時**不應該丟包**！
  * **死鎖（Deadlock）**：路上塞死，且**完全沒有任何一台車開得出去**（`tx-frames <= threshold`），連續幾秒動彈不得，這才需要出動拖吊車（Watchdog 啟動丟包）。

### ECN

顯式壅塞通知（Explicit Congestion Notification，ECN）是一種端到端（End-to-End）的第 3 層（Layer 3）壅塞控制協定。

ECN 是透過中繼交換器在兩個終端主機之間標記封包來運作：

1. 發送端宣告能力：發送端主機將傳出的 IP 標頭中的 ECN 位元設為 01 或 10，表示其支援 ECN。
2. 中繼交換器標記：當中繼交換器的佇列緩衝區深度大於設定的「最小閾值（Min Threshold）」時，交換器會將 ECN 位元改寫標記為 11，代表已遭遇壅塞（Congestion Encountered，CE）。
3. 接收端回傳通知：接收端主機在回傳確認封包（例如 TCP-ACK 或 RoCE CNP）時，將其標記為 CE (11)。
4. 發送端主動降速：最初的發送端主機收到通知後，主動降低其資料傳輸速率。
5. 壅塞解除：當交換器的緩衝區壅塞程度回落至設定的最小閾值以下時，交換器停止改寫 ECN 位元，將其恢復為 01 或 10。
6. 恢復正常速度：接收端主機在下一次的回覆中反映出這個未被標記的狀態，發送端主機便隨之恢復至正常傳輸速度。

#### 1. ECN vs. PFC：為什麼資料中心兩者都要用？
* **PFC（Layer 2 硬踩剎車）**：當 Buffer 快爆時，直接叫上一台設備「**立刻暫停（PAUSE）發送**」。
  * *缺點*：太粗暴，容易引發先前說的「背壓傳播」與「暫停風暴」。
* **ECN（Layer 3 軟性限速）**：交換器不暫停流量，只在封包上「**蓋章蓋上 11 (CE)**」，讓收發兩端的伺服器自己協商**降速**。
  * *黃金組合（RoCE 最佳實踐）*：**「ECN 先通知減速，PFC 當最後防線防掉包」**。

```text
[佇列緩衝區深度]
 100% 滿 ── 🔴 緩衝區爆滿（觸發 PFC PAUSE 或 Tail-Drop 丟包）
         ▲
         │ (這段區間：按機率越來越高地標記 ECN = 11)
Max 門檻 ── 🟡 強制全部封包標記 ECN (11)
         ▲
         │ (這段區間：開始隨機標記 ECN)
Min 門檻 ── 🟢 正常通行（ECN 保持 01/10，不標記）
   0% 空 ──
```

#### 2. ECN 標記的三種區間
* **低於 Min 閾值（< 40KB）**：無壅塞，封包正常放行，ECN 位元不變。
* **介於 Min 與 Max 之間（40KB ~ 200KB）**：開始擁擠，交換器**隨機**對部分封包標記 `11 (CE)`，越靠近 Max 標記機率越高。
* **高於 Max 閾值（> 200KB）**：極度擁擠，**100% 所有封包**全部打上 `11 (CE)` 標記。

#### 3. RED（Random Early Detection）的角色
* 一般預設是 **Tail-drop**：緩衝區滿了之後，最後進來的封包直接被丟掉（容易導致多條 TCP 同步重傳塞車）。
* 啟用 **RED**：在緩衝區快滿時，提早「隨機」丟棄少量封包，讓各個連線錯開降速時機，避免網路流量雪崩。


## 6. 控制平面保護 (Control Plane Policers, CoPP)

* **用意**：保護交換器 CPU 控制平面免受網路風暴或 DoS 攻擊影響。針對轉發給 CPU 處理的特定協定封包（Trap Groups，如 ARP, BGP, LACP, SSH, ICMP, IGMP 等），嚴格限制其承載的承諾資訊速率（CIR，以 packets/sec 計）與承諾突發大小（CBS）。

### 參考來源對照表 (Source Citation Mapping)

| 技術主題 / 功能模組 | 引用來源文件名稱 | 章節位置 | 對應內文位置 |
| :--- | :--- | :--- | :--- |
| **QoS 總覽與支援標準** | `Cumulus Linux 5.16` | **Quality of Service** | Passage 137–138 |
| **流量分類與信任模式 (Trust L2/L3/Port)** | `Cumulus Linux 5.16` | **Quality of Service ── Classification** | Passage 139–141, 145–146, 151 |
| **流量標記與重標記 (Mark and Remark)** | `Cumulus Linux 5.16` | **Quality of Service ── Mark and Remark Traffic** | Passage 153–154, 157, 160 |
| **出口佇列與排程 (Egress Queues & ETS/DWRR)** | `Cumulus Linux 5.16` | **Quality of Service ── Egress Queues / Egress Scheduler** | Passage 181, 184–185 |
| **流量整形 (Hierarchical Traffic Shaping)** | `Cumulus Linux 5.16` | **Quality of Service ── Hierarchical Traffic Shaping** | Passage 188–189 |
| **流量監管 (Single/Dual-rate Policing)** | `Cumulus Linux 5.16` | **Quality of Service ── Policing** | Passage 192–193 |
| **流量控制 (Link Pause & PFC)** | `Cumulus Linux 5.16` | **Quality of Service ── Flow Control / PFC** | Passage 162, 167–169 |
| **PFC Watchdog 防死鎖機制** | `Cumulus Linux 5.16` | **Quality of Service ── PFC Watchdog** | Passage 171, 173 |
| **顯式壅塞通知 (ECN)** | `Cumulus Linux 5.16` | **Quality of Service ── Congestion Control (ECN)** | Passage 174–177 |
| **RoCE 無損與有損網路配置** | `Cumulus Linux 5.16` | **RDMA over Converged Ethernet - RoCE** | Passage 261–265 |
| **控制平面保護 (CoPP)** | `Cumulus Linux 5.16` | **Access Control List Configuration ── Control Plane Policers** | Passage 81, 84, 86 |

## RoCEv2 Cheat Sheet
#### 全域 RoCEv2 無損模式一鍵啟用 (Quick-Start)

NVUE 提供全域預設命令，執行後系統會自動套用 **Priority 3 映射**、**Lossless 緩衝區配置**、**Priority 3 PFC**、**Traffic Class 3 ECN** 以及 **CNP (Priority 6) 嚴格優先權排程**：

```bash
# 1. 啟用全域 RoCE 無損 (Lossless) 模式
cumulus@switch:~$ nv set qos roce
cumulus@switch:~$ nv config apply
```

> ![NOTE]
> `nv set qos roce` 與 `nv set qos roce mode lossless` 等價，預設採用動態記憶體劃分

---

#### PFC (Priority Flow Control) 優先權流量控制詳細配置

若需手動調整 **Priority 3** 之無損記憶體池、纜線長度或 **PFC Watchdog（防死鎖保護）**，可使用以下指令：

##### 1. 配置無損記憶體池與 PFC Profile (Priority 3)
```bash
# 調整保留給無損流量的共享記憶體比例（例：Lossless 50%, Lossy 50%）
cumulus@switch:~$ nv set qos traffic-pool default-lossless memory-percent 50
cumulus@switch:~$ nv set qos traffic-pool default-lossy memory-percent 50

# 針對全域預設 Profile 於 Priority 3 啟用 PFC，並設定光纖/纜線長度 (公尺)
cumulus@switch:~$ nv set qos pfc default-global switch-priority 3
cumulus@switch:~$ nv set qos pfc default-global tx enable
cumulus@switch:~$ nv set qos pfc default-global rx disable
cumulus@switch:~$ nv set qos pfc default-global cable-length 50
cumulus@switch:~$ nv config apply
```

##### 2. 配置 PFC Watchdog（避免死鎖風暴）
```bash
# 在實體介面（如 swp1 至 swp48）啟用 PFC Watchdog 防死鎖保護
cumulus@switch:~$ nv set interface swp1-48 qos pfc-watchdog

# 設定 PFC Watchdog 輪詢間隔 (ms) 與健壯性門檻 (Robustness)
cumulus@switch:~$ nv set qos pfc-watchdog polling-interval 200
cumulus@switch:~$ nv set qos pfc-watchdog robustness 5
cumulus@switch:~$ nv config apply
```

---

#### ECN (Explicit Congestion Notification) 顯式壅塞通知詳細配置

針對 **Traffic Class 3 (對應 Priority 3)** 設定出口佇列之 **RED/ECN 壅塞標記門檻**：

```bash
# 針對 Traffic Class 3 設定最小與最大緩衝區門檻 (Bytes) 並啟用 ECN 與 RED
cumulus@switch:~$ nv set qos congestion-control default-global traffic-class 3 min-threshold 40000
cumulus@switch:~$ nv set qos congestion-control default-global traffic-class 3 max-threshold 200000
cumulus@switch:~$ nv set qos congestion-control default-global traffic-class 3 probability 100
cumulus@switch:~$ nv set qos congestion-control default-global traffic-class 3 red enable
cumulus@switch:~$ nv set qos congestion-control default-global traffic-class 3 ecn enable
cumulus@switch:~$ nv config apply
```

---

#### LLDP / DCBX 宣告配置

讓交換器透過 **LLDP (DCBX)** 協定將 PFC 與 ETS 參數自動通報給連接的網卡（NIC/DPU）：

```bash
# 在實體介面上啟用 DCBX PFC 與 ETS TLV 廣播
cumulus@switch:~$ nv set interface swp1-48 lldp dcbx-pfc-tlv enabled
cumulus@switch:~$ nv set interface swp1-48 lldp dcbx-ets-config-tlv enabled
cumulus@switch:~$ nv set interface swp1-48 lldp dcbx-ets-recomm-tlv enabled
cumulus@switch:~$ nv config apply
```

---

#### 狀態檢查與排錯驗證指令 (Monitoring & Troubleshooting)

| 檢視 / 驗證需求 | NVUE 語法指令 |
| :--- | :--- |
| **檢視全域 RoCE 設定與模式** | `nv show qos roce` |
| **檢視單一介面 RoCE 運作狀態** | `nv show interface swp16 qos roce status` |
| **檢視介面實時/歷史 RoCE 流量與 PFC 統計** | `nv show interface swp16 qos roce counters` |
| **檢視全域 PFC Profile 設定** | `nv show qos pfc default-global` |
| **檢視單一介面 PFC Watchdog 狀態** | `nv show interface swp1 qos pfc-watchdog` |
| **檢視 ECN 門檻與 RED 設定** | `nv show qos congestion-control default-global` |
| **檢視 QoS 介面計數器 (Ingress/Egress)** | `nv show interface swp1 counters qos` |
| **清除 RoCE 統計計數器** | `nv action clear interface swp16 qos roce counters` |
| **清除 PFC Watchdog 死鎖計數** | `nv action clear interface swp1 qos pfc-watchdog deadlock-count` |

## 案例場景

在資料中心網路架構中，**Quality of Service (QoS，服務品質)** 是確保多租戶混合業務（如 AI 訓練、分散式儲存、控制訊號與一般網路流量）共用同一實體 Fabric 時，能依據業務敏感度進行差異化處理的核心機制。

### 一、 流量分類與信任模式 (Classification & Trust Mode)

#### 1. 機制與設計意圖
當數據影格抵達交換器介面時，交換器需決定是否信任封包標頭自帶的優先權標記。若信任，則將 L2 802.1p (PCP) 或 L3 DSCP 數值映射至交換器內部的 **Switch Priority (0–7)**；若不信任，則在 Port 層級強制指定預設值（**Trust Port**），防止未授權的端點搶佔高優先權佇列。

#### 2. 實務應用案例：資料中心接入層（Access/Leaf Ingress）
* **場景**：伺服器接入埠（Server Facing Port）。
* **應用**：伺服器網卡已將 **RoCEv2 數據串流打上記號 DSCP 26**、**CNP 壅塞訊號打上記號 DSCP 48**。交換器接入埠設定為 **Trust L3 (DSCP)**，精準將其映射至內部的 Switch Priority 3 與 6。反之，對外網或未受控的 VM 接入埠設定 **Trust Port (Default SP 0)**，強制所有進站流量降為 Best-Effort。

#### 3. ASCII 架構流程圖
```text
+---------------------+      +-------------------------------------------+      +-----------------------+
|  Ingress Packet     |      |  NVIDIA Spectrum Switch Ingress Port      |      | Internal Pipeline     |
|                     |      |                                           |      |                       |
| [ PCP=3 / DSCP=26 ] | ---> |  Check Trust Policy:                      | ---> | Assigned Internal     |
|  or Untrusted Host  |      |  - Trust L2  -> Map PCP to Switch Prio    |      | Switch Priority (CoS) |
+---------------------+      |  - Trust L3  -> Map DSCP to Switch Prio   |      | e.g., SP 3 / SP 6     |
                             |  - Trust Port-> Overwrite to Default SP   |      +-----------------------+
                             +-------------------------------------------+
```

---

### 二、 流量標記與重標記 (Marking & Remarking)

#### 1. 機制與設計意圖
在數據離開交換器出口（Egress）或跨越網域邊界時，交換器可根據內部的 Switch Priority 重新寫入（Rewrite/Remark）L2 PCP 或 L3 DSCP，或是利用 ACL 進行 Policy-based 標記，使下游設備能維持一致的 QoS 策略。

#### 2. 實務應用案例：邊界交換器與 WAN 出口（Border Leaf / Uplink）
* **場景**：資料中心跨區連線或連接電信業者 WAN 網路。
* **應用**：資料中心內部將 SSH / 網管流量對應至 Switch Priority 6。在邊界交換器出口介面上設定 **Rewrite L3**，將 Switch Priority 6 重新標記為 **DSCP 46 (EF, Expedited Forwarding)**，使電信運營商的邊界路由器能據此給予高優先權調度。

#### 3. ASCII 架構流程圖
```text
+-----------------------+      +-------------------------------------------+      +---------------------+
| Internal Pipeline     |      | NVIDIA Spectrum Switch Egress Port        |      | Outgoing Packet     |
|                       |      |                                           |      |                     |
| Switch Priority (CoS) | ---> | Egress Remarking Engine / ACL SETQOS:     | ---> | Updated Header:     |
| e.g., SP 6            |      | - Rewrite L2 PCP  (e.g., SP 6 -> PCP 6)   |      | [ DSCP 46 (EF) ]    |
+-----------------------+      | - Rewrite L3 DSCP (e.g., SP 6 -> DSCP 46) |      +---------------------+
                               +-------------------------------------------+
```

---

### 三、 出口佇列與排程 (Egress Queues & ETS Scheduler)

#### 1. 機制與設計意圖
交換器出口提供 8 個獨立的出口佇列（Traffic Class 0–7）。結合 **IEEE 802.1Qaz (Enhanced Transmission Selection, ETS)**，可將特定佇列指定為 **Strict Priority (SP，絕對優先)** 或 **DWRR (Deficit Weighted Round Robin，加權輪詢)** 並分配頻寬百分比。

#### 2. 實務應用案例：AI 運算與混合業務共用 Fabric
* **場景**：Spine-Leaf 拓撲中同時承載 AI 訓練、時脈同步與一般業務。
* **應用**：在 NVIDIA Spectrum-X 參考架構中：
  * **TC 6 (CNP 壅塞通知 / PTP 時脈)**：設定為 **Strict Priority**，確保控制訊號零延遲搶佔傳送。
  * **TC 3 (RoCEv2 AI 訓練數據)**：設定為 **DWRR (Weight 50%)**，保證大吞吐管道。
  * **TC 0 (Best-Effort 一般流量)**：設定為 **DWRR (Weight 50%)**，避免低優先權佇列發生飢餓（Starvation）。

#### 3. ASCII 架構流程圖
```text
+---------------------------------------------------------------------------------------------------+
| Egress Port Buffer Queues (Traffic Classes)                                                       |
|                                                                                                   |
| [ TC 6 (CNP / PTP) ] -------> [ Strict Priority Scheduler ] -----------------+                    |
|                                                                              |                    |
| [ TC 3 (RoCE Data) ] -------> [ DWRR Scheduler: Weight 50% ] ----+           v                    |
|                                                                  |    +---------------+           |
| [ TC 0 (Best Effort) ] -----> [ DWRR Scheduler: Weight 50% ] ----+->  | Egress Port   | --------> |
+-----------------------------------------------------------------------| Line Rate     |           |
                                                                        +---------------+           |
+---------------------------------------------------------------------------------------------------+
```

---

### 四、 流控機制與無損緩衝池 (Flow Control Buffers & PFC / PFC Watchdog)

#### 1. 機制與設計意圖
在交換器共享記憶體中劃分 **Traffic Pools**（如 `default-lossy` 與 `roce-lossless`）。當緩衝區堆積至反壓門檻（XOFF）時，透過 **PFC (IEEE 802.1bb)** 按優先權發送 Pause 影格；同時開啟 **PFC Watchdog** 監控，防止因持續 Paused 引發連鎖性死鎖（Deadlock Storm）。

#### 2. 實務應用案例：大規模 GPU 分散式 AI 訓練（Lossless RoCEv2）
* **場景**：GPU-to-GPU 的 All-Reduce 集合通訊網路。
* **應用**：跨節點 GPU 訓練不允許丟包。劃分 `roce-lossless` 專屬緩衝池，並於 Priority 3 啟用 PFC。當接收端緩衝區堆積時，交換器僅暫停 Priority 3 的發送，其餘 Priority 正常傳輸；若對端網卡故障導致連線持續 Paused 逾時，**PFC Watchdog** 自動解鎖並丟棄該佇列封包，保護整體 Fabric 不致癱瘓。

#### 3. ASCII 架構流程圖
```text
[ Sender GPU Node ]                              [ Spectrum Switch Ingress Port ]
        |                                                        |
        | -------- High-Rate RoCE Traffic (Priority 3) --------> | [ Shared Buffer Filling... ]
        |                                                        | Buffer > XOFF Threshold
        | <------- PFC Pause Frame (Priority 3) ---------------- | (Triggers PFC Pause TX)
        |                                                        |
        | [ Cable Propagation & MAC Processing Delay ]           | [ In-Flight Packets Arrive ]
        |                                                        | Stored in Lossless Headroom Buffer
        | [ Stop Priority 3 Transmission ]                       | (Zero Packet Loss Guaranteed)
        v                                                        v
```

---

### 五、 端到端壅塞控制 (Congestion Control - ECN & RED)

#### 1. 機制與設計意圖
當出口佇列深度介於 `min-threshold` 與 `max-threshold` 之間時，交換器在轉發的 IP 標頭中標記 **CE (Congestion Encountered, 11)** 位元；搭配 **RED (Random Early Detection)** 在緩衝區完全溢位前進行隨機標記/丟棄，由端點進行降速，從源頭避免佇列溢位與實體 PFC 反壓。

#### 2. 實務應用案例：NVMe-oF IP 高效能儲存與多對一 Incast 流量
* **場景**：數十台運算節點同時向同一台儲存伺服器發起資料寫入。
* **應用**：多對一流量易造成出口埠瞬間 Incast 壅塞。在 Traffic Class 3 配置 ECN (`min-threshold 40KB`, `max-threshold 200KB`)。當佇列堆積時，交換器主動標記 CE 位元；接收端主機收到後回應 **CNP 封包**，促使傳送端網卡硬體主動調降發送速率，避免觸發實體 PFC Pause 影響全網效能。

#### 3. ASCII 架構流程圖
```text
[ Sender Host ]                  [ Spectrum Switch ]                   [ Receiver Host ]
      |                                   |                                   |
      | === 1. High-Rate RoCE Stream ===> |                                   |
      |                                   | [ Queue Depth > min-threshold ]   |
      |                                   | === 2. Mark IP ECN CE (11) =====> |
      |                                   |                                   | [ Detect CE=11 ]
      | <================= 3. Send Back CNP (Priority 6) ===================== |
      |                                                                       |
      | [ Hardware Rate Limiter Actuated:                                     |
      |   Reduce Sending Rate ]                                               |
```

---

### 六、 流量整形與流量監管 (Traffic Shaping & Policing)

#### 1. 機制與設計意圖
* **Traffic Shaping (流量整形)**：作用於 Egress，將超出速率的突發流量暫存於 Buffer 中，並以平滑的速率發出。
* **Traffic Policing (流量監管)**：作用於 Ingress，使用 Single-rate (`-j POLICE`) 或 Dual-rate/3-Color (`-j TRICOLORPOLICE`)，對超出 SLA 限額的流量執行直接拋棄（Drop）或降級標記。

#### 2. 實務應用案例：雲端多租戶託管（Multi-Tenant SLA Limit）
* **場景**：資料中心出租 100G 實體介面給租戶，合約限制承諾速率 (CIR) 為 10Gbps、峰值速率 (PIR) 為 20Gbps。
* **應用**：在 Ingress 入口套用 **Dual-rate Policer**，合規流量放行，超出 CIR 流量降級標記，超出 PIR 流量直接 Drop。在 Egress 出口套用 **Hierarchical Traffic Shaping**，限制整埠最高輸出速率為 20Gbps (`port-max-rate`)，防止突發流量衝垮對端網路。

#### 3. ASCII 架構流程圖
```text
[ Ingress Burst Traffic ]                                             [ Egress Smooth Output ]
          |                                                                     |
          v                                                                     v
+-----------------------+                                           +-------------------+
| Ingress Policer       |                                           | Egress Shaper     |
| (Dual-Rate 3-Color)   |                                           | (Queue / Port)    |
+-----------------------+                                           +-------------------+
| CIR: Conform -> Pass  |                                           | Buffer Packets    |
| PIR: Exceed  -> Mark  |                                           | & Release at      |
| >PIR: Violate-> Drop  |                                           | Smooth Rate       |
+-----------------------+                                           +-------------------+
```

---

### 七、 控制平面保護 (Control Plane Policers - CoPP)

#### 1. 機制與設計意圖
針對轉發至交換器 CPU 控制平面的特定協定封包（Trap Groups，如 ARP, BGP, BFD, LACP, IGMP 等），在硬體 ASIC 層級嚴格限制其 CIR (pps) 與 CBS (Burst) 速率，保護 CPU 免受網路風暴或 DoS 攻擊影響。

#### 2. 實務應用案例：防範 ARP 廣播風暴與 BGP 對等體保護
* **場景**：資料中心網域發生 L2 環路或遭遇惡意掃描。
* **應用**：當大量的 ARP 廣播或 ICMP 封包湧入時，交換器內建 CoPP 機制將 ARP 流量限制為 800 pps、BGP 限制為 2000 pps。超出門檻的異常封包會在硬體 ASIC 層級直接被丟棄（Violated Packets），確保交換器 CPU 運算資源不受影響，BGP 路由連線保持穩定。

#### 3. ASCII 架構流程圖
```text
[ Incoming Network Traffic ]
        |
        +----------------------------+----------------------------+
        | (Data Plane Transit)       | (To-CPU Control Packets)   |
        v                            v                            v
+---------------+            +------------------+         +------------------+
| Switching     |            | CoPP Trap Group  |         | CoPP Trap Group  |
| ASIC Hardware |            | Policer: ARP     |         | Policer: BGP     |
| Forwarding    |            | (Rate: 800 pps)  |         | (Rate: 2000 pps) |
+---------------+            +------------------+         +------------------+
                                     |                             |
                                     | Violate -> Hardware Drop    | Pass -> To CPU
                                     v                             v
                                [ CPU Safe ]                [ Control Plane ]
```

---

### 八、 先進數據包裁切技術 (Packet Trimming - Spectrum-4 特性)

#### 1. 機制與設計意圖
在 **NVIDIA Spectrum-4 ASIC** 晶片上，當出口緩衝區飽和即將發生 Tail Drop 時，交換器不直接丟棄全包，而是將數據包進行裁切（Trimming，保留標頭 256 Bytes）並繼續轉發，同時重標記 DSCP。接收端網卡收到裁切標頭後，能精準得知壅塞發生點並觸發微秒級快速重傳。

#### 2. 實務應用案例：極低延遲 AI 乙太網路（Lossy Multi-TC Profile）
* **場景**：允許有損（Lossy）傳輸的極低延遲 AI 訓練網路。
* **應用**：當突發流量導致緩衝區溢位時，交換器將封包裁切，並將 downlink 介面出的裁切包 DSCP 改寫為 21、uplink 介面改寫為 11。接收端網卡收到裁切包後，無須等待傳統 TCP/RDMA 逾時（Timeout），立發起 Fast NACK/重傳，將尾部延遲（Tail Latency）降至最低。

#### 3. ASCII 架構流程圖
```text
[ Ingress Packets ] ---> [ Spectrum-4 Egress Buffer Full ]
                                 |
                                 v (Trimming Engine)
                        +-------------------------------------+
                        | Truncate Payload to 256 Bytes       |
                        | Remark DSCP (Host: 21 / Network: 11)|
                        +-------------------------------------+
                                 |
                                 v (Forward Trimmed Header)
                        [ Receiver Host / SuperNIC ]
                                 |
                                 v
                        [ Instant NACK / Fast Retransmit ]
```

## 可以一起設定？（從 ASIC 封包處理流水線看）


當一個數據封包通過交換器時，各個 QoS 機制會在不同的硬體位置**分工合作**：

```text
[ Ingress 進站 ] ──> [ 晶片內部與緩衝區 ] ──> [ Egress 出站 ] ──> [ 控制平面 ]
       │                      │                    │                 │
       ├── Classification     ├── Flow Control     ├── Egress        └── CoPP
       │   (Trust L2/L3)      │   Buffers          │   Scheduler         (Control
       │           │         │   (ETS/DWRR)        Plane
       │                      │                    │          Policer)
       └── Ingress Policing   ├── PFC / PFC        │                
           (3-Color)          │   Watchdog         ├── Egress
                    │         │   Shaping
                              │                    │  
                              └── ECN Congestion   │
                                  Control          └── Egress Remark
                                           
```

* **Ingress (進站階段)**：先透過 **Trust Mode** 進行流量分類（Classification），並可用 **Policing** 阻擋超過 SLA 的異常突發流量。
* **Buffer & Queue (緩衝區管理階段)**：劃分 **Flow Control Buffers**，同時套用 **PFC**（防止硬體溢位）與 **ECN**（通知主機主動降速）。
* **Egress (出站階段)**：透過 **ETS (DWRR/SP)** 進行佇列頻寬分配，以 **Shaping** 平滑輸出速率，並重新 **Remark** 標頭。
* **CPU Protection (控制平面階段)**：同步開啟 **CoPP** 確保 BGP / ARP 等關鍵控制封包不被數據流衝垮。

### RoCEv2

在 NVIDIA Spectrum-X AI 網路架構中，只下達一行一鍵配置命令 `nv set qos roce`，系統就會在底層**同時開啟並聯動以下所有 QoS 功能**：

1. **Classification (信任機制)**：自動開啟 **Trust L2/L3**，將 RoCE 數據 (DSCP 26) 歸為 Priority 3，CNP 訊號 (DSCP 48) 歸為 Priority 6。
2. **Flow Control Buffers (緩衝池)**：自動切割出 `roce-lossless` 專屬無損記憶體池。
3. **PFC & PFC Watchdog (流控與防死鎖)**：在 Priority 3 啟用 PFC，並開啟 PFC Watchdog 防範死鎖風暴。
4. **ECN (壅塞控制)**：在 Traffic Class 3 啟用 ECN 門檻（`min-threshold 40KB`, `max-threshold 200KB`），優先觸發主機降速。
5. **Egress Scheduler (ETS 佇列排程)**：將 CNP 訊號 (TC 6) 設定為 **Strict Priority** 優先發送，RoCE 數據 (TC 3) 設定為 **DWRR 50%** 頻寬保障。
6. **DCBX TLV (自動宣告)**：透過 LLDP 自動將這套 QoS 參數通報給 ConnectX / BlueField 網卡。

## 參考資源

* [Quality-of-Service](https://docs.nvidia.com/networking-ethernet-software/cumulus-linux-516/Layer-1-and-Switch-Ports/Quality-of-Service/)
