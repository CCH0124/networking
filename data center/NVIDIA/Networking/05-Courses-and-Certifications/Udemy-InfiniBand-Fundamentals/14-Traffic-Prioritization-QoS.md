# Traffic Prioritization
## Traffic Prioritization

在 InfiniBand 中，流量優先級的運作可以濃縮為最關鍵的一句口訣：

> **「QoS decides $\rightarrow$ SL labels $\rightarrow$ VL delivers」**（QoS 定策略 $\rightarrow$ SL 貼標籤 $\rightarrow$ VL 走專道）
> 
> 

---

### 概念對比：真實世界比喻 vs. InfiniBand 實作

將複雜的網路機制拆解為 **問題 $\rightarrow$ 政策 $\rightarrow$ 標籤 $\rightarrow$ 通道 $\rightarrow$ 結果** 五個階段：

| 階段 / 維度 | 比喻一：救護車專用道 | 比喻二：機場優先登機 | **InfiniBand 網路實作**|
| --- | --- | --- | --- |
| **面臨問題 (Problem)** | 救護車在一般車流中塞車 | 乘客蜂擁登機門造成混亂混雜 | 多種應用（運算、存儲、管理）搶佔頻寬，網路壅塞且延遲不可預測。 |
| **1. 制定政策 (Policy)** | 市議會定義：緊急車輛享有最高路權 | 航空公司定義：頭等艙、商務艙與老弱婦孺享有優先登機權 | **Subnet Manager (QoS)**：定義哪類流量（控制流量 vs 關鍵運算 vs 大容量傳輸）享有優先權。 |
| **2. 標籤識別 (Tagging)** | 車體標記「Emergency Vehicle」或鳴笛警示 | 登機證上印製「Group 1 / Group 2」分組號碼 | **Service Level (SL)**：每個封包被賦予一個 **0 ~ 15** 的 SL 標記（共 16 個等級）。 |
| **3. 通道分流 (Path)** | 馬路上劃設「緊急車輛專用道」 | 機場劃分「Priority Lane」與「一般登機道」 | **Virtual Lanes (VL)**：實體纜線上切分出的獨立邏輯通道（如 VL0, VL1）。 |
| **最終效益 (Result)** | 緊急車輛不被卡住、快速通行 | 高優先級乘客平順登機 | **高優先級流量暢通無阻**，確保極低延遲與可預測的效能表現。 |

---

### InfiniBand QoS 三大支柱核心解析

```text
+------------------------+      +-------------------------+      +--------------------------+
|  1. 政策決策層 (QoS)    | ---> |    2. 封包標記層 (SL)    | ---> |    3. 實體硬體通道 (VL)    |
|   Subnet Manager 定義   |      |   Service Level (0~15)  |      |   Virtual Lanes (硬體緩衝) |
|  "Who deserves priority?"|     |   "What group are you?" |      |   "Which lane do you take?"|
+------------------------+      +-------------------------+      +--------------------------+

```

1. **QoS (Quality of Service) — 規則制定者**

    * 由控制平面的 **Subnet Manager (SM)** 統一管理。
    * 根據連線的來源/目的節點、特定 P_Key、連線 Port、MPI 通訊型態或租戶，制定哪種流量該給予何種待遇。

2. **SL (Service Level) — 邏輯標籤（Tagging）**

    * 存在於 InfiniBand 封包標頭（Local Route Header）中的 4-bit 欄位，範圍為 **SL 0 至 SL 15**。
    * 它純粹是一個「邏輯身分識別碼」，告訴沿途的交換器：「我屬於哪一個等級的隊列」。

3. **VL (Virtual Lanes) — 實體獨立通道（Delivery）**
    * **硬體層級的獨立緩衝區（Buffer）**：不同於乙太網的 VLAN（純二層廣播域隔離），InfiniBand 的 VL 是在同一條實體纜線上切分出相互獨立的硬體接收/發送佇列。
    * **阻斷連鎖反應**：一般流量在普通 VL 塞滿時，完全不會消耗高優先級 VL 的 Credit 額度，從根本上避免關鍵流量被 Head-of-Line Blocking 波及。

## Quality of Service (QoS)

### 三位一體核心架構：分工與角色

在 InfiniBand 網路中，三者的生命週期與職責如下：

```text
       [ Subnet Manager ] (制定規則)
               |
         +-----+-----+
         | 定義 QoS 策略
         v
     [ HCA 網卡 ]  ----------------------> [ Switch 交換器 ]
 (發送端貼 SL 標籤)                       (依 SL2VL 映射分流至 VL)
 [ 產生封包: SL 0~15 ]                   [ 透過 VL 獨立緩衝區傳輸與仲裁 ]

```

* **QoS (Quality of Service)**：
  * **角色**：規則制定者（Policy Framework）。
  * **三方聯動**：由 **Subnet Manager (SM) 定義**、由端點 **HCA 網卡套用**、由中間 **Switch 交換器強制執行**。
  * **目的**：提供優先權處理、公平頻寬分配，以及高負載下可預測的低延遲表現。


* **SL (Service Level)**：
  * **角色**：封包識別標籤（Packet Label）。
  * **規格**：封包標頭內的 **4-bit 標記**（數值範圍為 **0 至 15**，共 16 個等級）。
  * **目的**：決定封包在經過交換器時該走哪一條虛擬通道（VL），以及如何進行頻寬仲裁（Arbitration）與擁塞處理。


* **VL (Virtual Lane)**：
  * **角色**：實體線路上的邏輯傳輸通道（Logical Data Lane）。
  * **機制**：在單一實體線路上劃分出彼此完全獨立的**硬體緩衝區（Buffer）與信用流控（Flow Control）**。
  * **目的**：實現流量硬體隔離（如 AI 運算 vs. 儲存 vs. 控制訊號），從根本杜絕死鎖並減少壅塞波及。



---

### 虛擬通道（VL）的通道劃分與特權通道 VL15

可將實體纜線比喻為多線道公路：

* **可用資料通道（VL0 ～ VL14）**：
  * 共 **15 條可自訂的資料通道**，各自擁有獨立的 Buffer 與 Credit 計數。
  * 常見劃分規劃：
    * `VL0`：預設/一般通用流量（Default Traffic）。
    * `VL1`：MPI / NCCL 平行集合通訊（AI 訓練流量）。
    * `VL2`：儲存流量（NVMe-oF / Lustre 等）。
    * `VL3`：叢集監控與控制（Management）。




* **保留專用通道（VL15）**：
  * **專屬特權**：嚴格保留給 **Subnet Manager 的管理流量（SMP 封包）**，普通資料封包絕對禁止使用。
  * **通道特性**：如同公路上的緊急專用路肩，不受任何普通資料堵塞影響，甚至**不運行一般的信用流控限制**，保證全網即使在資料死鎖癱瘓時，SM 的管理與拓撲探測封包依然能通行無阻。



---

### QoS、SL 與 VL 橫向綜合對照表

整理的架構對照表精準提煉了三者的實務差異：

| 評估面向 (Aspect) | QoS (Quality of Service) | SL (Service Level) | VL (Virtual Lane) |
| --- | --- | --- | --- |
| **定義本質 (What is it?)** | 定義流量應如何劃分優先權與排程的**策略框架**。 | 賦予封包標記優先等級的 **4-bit 標籤 (0–15)**。 | 實體纜線內部劃分出的**邏輯資料通道**。 |
| **存在目的 (Why is it used?)** | 確保不同業務流量間的公平性、優先處理與效能保證。 | 對流量進行分類，以便沿途設備依優先權差別對待。 | 透過通道分離來強制實體流量隔離，避免壅塞擴散。 |
| **由誰配置 / 指派 (Who assigns?)** | **Subnet Manager** 定義全域 QoS 規則與策略。 | 上層應用（MPI、NCCL、Verbs）或效能工具（如 `ib_write_bw -s`），由 SM 策略引導。 | **Subnet Manager** 在各交換器上配置 **SL $\rightarrow$ VL 映射表**。 |
| **機場登機比喻 (Analogy)** | 航空公司訂立的**優先登機政策**（誰享有特權與原因）。 | 機票上的**登機組別標記**（Group 1, 2, 3...）。 | 登機門前劃設的**實體登機隊列/專用通道**。 |

## QoS Configuration
這段內容與投影片詳細剖析了 InfiniBand QoS 在底層主設定檔 **`opensm.conf`** 中的四大核心參數、**SL2VL 映射陣列語法**，以及 **VL 仲裁器（VL Arbitration）權重演算法**的精確計算。


### `opensm.conf` vs. `qos-policy.conf` 的架構分工

```text
+------------------------------------+      +------------------------------------+
|          opensm.conf               |      |         qos-policy.conf            |
+------------------------------------+      +------------------------------------+
| • 啟用 QoS 與全域底層架構規則      |      | • 租戶感知與流量分類 (Classifier)  |
| • 定義全網 SL2VL 映射表            | ---> | • 根據 GUID、Port Group 分類租戶   |
| • 定義 VL Arbitration 權重與優先級 |      | • 回答「哪位租戶取得哪個 SL 標籤」 |
| • 推送配置至全網交換器 Egress Port |      |                                    |
+------------------------------------+      +------------------------------------+

```

### `opensm.conf` 四大關鍵 QoS 參數詳解

| 參數名稱 | 範例設定值 | 核心意義與功能說明 |
| --- | --- | --- |
| **`qos`** | `TRUE` | **開啟 QoS 功能**。 |
| **`qos_max_vls`** | `4` | **限制硬體使用的最大資料 VL 數量**（此例中僅使用 VL0 ~ VL3，避免硬體開銷過大）。 |
| **`qos_policy_file`** | `/etc/opensm/qos-policy.conf` | **指定租戶原則分類檔案路徑**。 |
| **`qos_sl2vl`** | `0,1,2,3,3,3,3,3,3,3,3,3,3,3,3,15` | **SL 到 VL 的映射陣列**（共 16 個位置，依序對應 SL0 ~ SL15）。 |
| **`qos_vlarb_high`** | `0:100,1:50,2:20,3:10` | **高優先級 VL 仲裁排程權重表**（語法為 `VL:Weight`）。|

### `qos_sl2vl` 陣列語法（16 位對應關係）

這串陣列共有 16 個逗號分隔的數字，**陣列的索引位置（Index 0～15）代表 Service Level (SL)，陣列中的數值代表該 SL 被指派去的 Virtual Lane (VL)**：

```text
SL 標籤 (Index):  [0]  [1]  [2]  [3]  [4]  [5] ... [13] [14]  [15]
                   |    |    |    |    |    |        |    |     |
指派的 VL 數值:    0,   1,   2,   3,   3,   3  ...   3,   3,   15

```

* **SL0 $\rightarrow$ VL0**：指派給 FinCorp 核心業務。
* **SL1 $\rightarrow$ VL1**：指派給 BioGen RDMA 高性能運算。
* **SL2 $\rightarrow$ VL2**：指派給 MediaCo 影音流量。
* **SL3 至 SL14 $\rightarrow$ VL3**：所有未特別標記或備用的常規流量統一導向 VL3。
* **SL15 $\rightarrow$ VL15**：嚴格保留給 Subnet Manager 管理訊號專用通道。

---

### VL 仲裁機制（VL Arbitration）與頻寬權重精算

交換器輸出埠（Egress Port）具備硬體仲裁器（Arbitrator），如同交通管制員。權重（Weight）以封包信用額度為單位（1 Credit $\approx$ 1 個 MTU 大小，如 4096 Bytes）。

#### 核心原則：權重是「相對競爭值」，非固定限制

* **無競爭（No Contention）**：若只有單一租戶發送流量，該租戶可佔用實體線路 **100% 的頻寬（如跑滿 40 Gbps）**。
* **有競爭（Under Contention）**：當所有租戶同時以全速發送時，頻寬依照權重佔比分配。

#### 40 Gbps 實體線路爭搶精算（`qos_vlarb_high 0:100,1:50,2:20,3:10`）

計算總信用權重點數：

$$\text{Total Credits} = 100 + 50 + 20 + 10 = 180$$

| VL | 租戶 / 應用 | 設定 Credits | 十六進位值 (Console) | 頻寬比例計算 (Share) | 40 Gbps 實體頻寬分配 (Approx) |
| --- | --- | --- | --- | --- | --- |
| **VL0**<br> | FinCorp (VIP) | 100 | `0x64`<br> | $100 / 180 \approx \mathbf{55.6\%}$<br> | $\approx \mathbf{22.2\text{ Gbps}}$<br> |
| **VL1**<br> | BioGen (RDMA) | 50 | `0x32`<br> | $50 / 180 \approx \mathbf{27.8\%}$<br> | $\approx \mathbf{11.1\text{ Gbps}}$<br> |
| **VL2**<br> | MediaCo | 20 | `0x14`<br> | $20 / 180 \approx \mathbf{11.1\%}$<br> | $\approx \mathbf{4.4\text{ Gbps}}$<br> |
| **VL3**<br> | Future Use / Spare | 10 | `0x0A`<br> | $10 / 180 \approx \mathbf{5.6\%}$<br> | $\approx \mathbf{2.4\text{ Gbps}}$<br> |
| **VL15**<br> | Subnet Manager (Mgmt) | — | — | **永遠優先服務，繞過仲裁器，不受壅塞影響**。 | — |
| **總計**<br> | — | **180**<br> | — | **100%**<br> | **40 Gbps**<br> |

---

### 維運管理實務技巧：熱重載（SIGHUP）

在大型線上 AI 叢集中，修改 QoS 權重或 SL2VL 映射時**不需要整機重開機或中斷 Subnet Manager 服務**：

* 可向 OpenSM 進程發送 **`SIGHUP` (Hangup Signal)** 訊號：

```bash
sudo pkill -HUP opensm
# 或透過 systemctl
sudo systemctl reload opensm

```


* OpenSM 捕捉到 HUP 訊號後，會直接在記憶體中重新載入設定檔，並在下一次掃描時將新的 LFT 與 VL 仲裁表推送至全網交換器。

### `qos-policy.conf` 三大核心區塊架構

配置檔切分為三個層次遞進的關鍵區塊：

```text
+------------------------------------+
| 1. Who? (port-groups)              | ---> 定義主機成員 (透過 Port GUID 分組)
+------------------------------------+
                  |
                  v
+------------------------------------+
| 2. Which? (qos-levels)             | ---> 定義特權等級 (指定 Service Level: SL 0~15)
+------------------------------------+
                  |
                  v
+------------------------------------+
| 3. Matching Engine (qos-match-rules| ---> 規則媒合 (當 Source/Dest 符合時套用特定 Level)
+------------------------------------+

```


### 三大區塊語法與設定詳解

#### 區塊一：Who? —— `port-groups`（身分與節點分類）

透過節點的實體 **Port GUID**，將不同業務或租戶的伺服器劃分到特定的群組中：

```text
port-groups
    port-group
        name: FinCorp
        port-guid: 0x0002c903004e0790, 0x0002c903004e0791
    end-port-group

    port-group
        name: BioGen
        port-guid: 0x0002c903004e07a0, 0x0002c903004e07a1
    end-port-group

    port-group
        name: all                     # 預設全域群組，作為兜底備用
        use: across                   # 匹配未明確歸類的其餘節點
    end-port-group
end-port-groups

```

#### 區塊二：Which? —— `qos-levels`（服務等級定義）

定義具備具體標籤（SL）的特權等級：

```text
qos-levels
    qos-level
        name: FinCorp-Level
        sl: 0                         # 對應 SL0 (在 opensm.conf 中走 VL0，享 55.6% 頻寬)
    end-qos-level

    qos-level
        name: BioGen-Level
        sl: 1                         # 對應 SL1 (走 VL1，享 27.8% 頻寬)
    end-qos-level

    qos-level
        name: default-level
        sl: 3                         # 兜底等級，導向低優先級的 VL3
    end-qos-level
end-qos-levels

```

#### 區塊三：Matching Engine —— `qos-match-rules`（媒合引擎）

將「來源群組」、「目標群組」與「QoS 等級」串聯成完整規則：

```text
qos-match-rules
    # 規則 1：FinCorp 內部節點互通
    qos-match-rule
        name: FinCorp-rule
        source: FinCorp
        destination: FinCorp
        qos-level-name: FinCorp-Level # 套用 FinCorp-Level (SL0)
    end-qos-match-rule

    # 規則 2：BioGen 內部節點互通
    qos-match-rule
        name: BioGen-rule
        source: BioGen
        destination: BioGen
        qos-level-name: BioGen-Level  # 套用 BioGen-Level (SL1)
    end-qos-match-rule

    # 兜底規則：其餘未匹配流量
    qos-match-rule
        name: default-rule
        source: all
        destination: all
        qos-level-name: default-level # 套用 default-level (SL3)
    end-qos-match-rule
end-qos-match-rules

```

---

### 端到端流程全貌串接

當 `FinCorp Node 1` 欲發送封包至 `FinCorp Node 2` 時，整體流轉邏輯如下：

$$\text{Port GUID 命中 FinCorp 群組} \xrightarrow{\text{qos-match-rule}} \text{套用 FinCorp-Level} \xrightarrow{\text{qos-levels}} \text{打上 SL 0 標籤}$$

$$\xrightarrow{\text{opensm.conf (qos\_sl2vl)}} \text{指派進入 VL 0 通道} \xrightarrow{\text{qos\_vlarb\_high}} \text{在競爭時享有 100 Credits (55.6\% 頻寬)} \xrightarrow{\text{傳出}}$$


### 什麼是 Management Datagram (MAD)？

* **原生通訊格式**：MAD 是 InfiniBand 規範中標準的**原生管理訊息格式**（Native management message format）。
* **通訊對象**：它是控制平面 **Subnet Manager (OpenSM)**、診斷工具（如 `smpquery`、`perfquery`、`ibstat`）以及實體設備（HCA 網卡、Switch 交換器）之間進行狀態查詢、配置下發與拓撲探索的唯一標準通訊語言。
* **獨立通道運作**：MAD 走專屬的管理通道（固定使用保留的 **VL15**），**完全獨立於常規資料流量（Data Traffic）**，不受 P_Key 分區隔離約束，也不受資料面的壅塞影響。



```text
+-------------------------------------------------------------------+
|               Subnet Manager (OpenSM) / 管理工具                  |
+-------------------------------------------------------------------+
         |                             |
         | MAD 封包 (走 VL15 專用道)    | MAD 封包 (走 VL15 專用道)
         v                             v
+------------------+          +------------------+
|   Switch (晶片)   |          |   HCA (網卡端點)  |
| 寫入 LFT / SL2VL  |          | 讀寫暫存器與屬性 |
+------------------+          +------------------+

```

---

### 實務驗證：使用 `smpquery` 檢驗硬體暫存器

管理員在 `opensm.conf` 編輯的參數屬於**軟體設定**，若要確認硬體晶片是否真正生效，必須透過 `smpquery` 發送 MAD 封包讀取設備暫存器：

#### 步驟一：驗證 SL2VL 映射關係

```bash
smpquery sl2vl <LID> <Port>

```

* **輸出解析**：回傳 SL 0～15 對應的實體 VL。確認 SL0 $\rightarrow$ VL0、SL1 $\rightarrow$ VL1、SL2 $\rightarrow$ VL2、SL3～14 $\rightarrow$ VL3、SL15 $\rightarrow$ VL15。



#### 步驟二：驗證 VL Arbitration 權重（Hex 進制對照）

```bash
smpquery vlarb <LID> <Port>

```

硬體回傳的權重值皆為**十六進位（Hex）**，需與設定檔中的十進位 Credit 點數相互對照：

* **`0x64`** $\rightarrow$ 十進位 **100**（對應 VL0，分配最高頻寬權重）
* **`0x32`** $\rightarrow$ 十進位 **50**（對應 VL1）
* **`0x14`** $\rightarrow$ 十進位 **20**（對應 VL2）
* **`0x0A`** $\rightarrow$ 十進位 **10**（對應 VL3）



---

### VL 仲裁機制：High-Priority vs. Low-Priority

交換器輸出端（Egress Port）具備兩級仲裁排程表：

| 仲裁層級 | 適用流量型態 | 頻寬分配原則 |
| --- | --- | --- |
| **High-Priority (VLARB High)** | **延遲敏感型（如 MPI / NCCL 集合通訊）**<br> | 優先傳輸，依設定的 Credit 權重嚴格分配頻寬。 |
| **Low-Priority (VLARB Low)** | **大容量傳輸型（如儲存備份、批次數據）** | 僅在高優先級通道閒置或發送達上限時，瓜分**剩餘頻寬（Remaining Bandwidth）**。 |

---
