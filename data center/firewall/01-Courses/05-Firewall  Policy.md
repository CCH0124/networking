# Firewall  Policy

## Intro to Firewall  Policy

### Background / Objective（背景與核心目的）

* **核心情境與角色**：在 FortiGate 防火牆架構中，**安全政策（Firewall Policy）** 是所有網路流量轉發與安全防護的核心運作中樞（Central Axis）。任何穿越 FortiGate 的網路封包，都必須與特定的安全政策進行比對。

* **欲解決之核心問題**：透過集中且具備邏輯結構的規則清單，解決「誰能連線（Who）」、「前往何處（Where）」、「何時連線（When）」以及「如何處理（How）」的邊界存取控制問題，提供可自訂的雙向通信會話建立基礎。

### Methodology & Architecture（比對管線與評估流程）

FortiGate 防火牆安全政策遵循嚴格的 **由上而下（Top-Down Enforcement）** 與 **首條匹配即停止（First-Match & Stop）** 原則。

```
[連入封包 (Incoming Packet)]
         │
         ▼
[階段 1：屬性解析 (Analyze Packet)]
         │ 提取: Ingress Interface, Egress Interface, 
         │       Source IP/User, Destination IP, Protocol/Port, Time of Day
         ▼
[階段 2：規則庫由上而下逐條檢索 (Evaluate Rules Top-to-Bottom)]
         ├── 比對 Policy ID 1 ──(未命中)──> 往下比對
         ├── 比對 Policy ID 2 ──(命中 Match Found) ──┐
         │                                          │ (停止後續比對 Stop Searching)
         ▼                                          ▼
[若直至末端皆未命中]                    [階段 3：執行政策動作 (Execute Action)]
         │                                          ├── Action = ACCEPT
         ▼                                          │     └── 建立雙向 Session，放行流量
[命中預設 Implicit Deny]                             └── Action = DENY
         │                                                └── 丟棄封包 (Drop)，可選擇記錄 Log
         ▼
    [阻斷封包並丟棄]

```

#### 政策匹配關鍵要素（Match Criteria）

防火牆依據連入封包的多維度特徵進行比對：

1. **介面邊界**：`Incoming Interface`（連入介面）與 `Outgoing Interface`（出向介面）。
2. **來源與目的**：`Source Address`（可結合特定 User / Group 身分認證）與 `Destination Address`（包含 VIP/網段物件）。
3. **服務與時間**：`Service`（基於 L4 TCP/UDP 連接埠）與 `Schedule`（排程，支援單次生效或按星期/時段週期性生效）。

#### 兩大基本動作（Action）與工作階段處理

* **`ACCEPT`（允許）**：通過比對並放行封包，FortiOS 核心正式分配記憶體並建立雙向連線狀態（Session Table），後續雙向回程流量依據 Session 狀態自動穿越。

* **`DENY`（拒絕）**：封包被直接丟棄（Drop），不建立正常通訊 Session。可依稽核需求開啟 `Log Violation Traffic`。

* **`Implicit Deny`（隱含拒絕）**：預置於規則庫最底層的終端規則（`srcintf any`, `dstintf any`, `srcaddr all`, `dstaddr all`, `action deny`），不可被刪除或移動順序。所有未命中自訂規則的流量最終均在此被丟棄。


### Key Findings（核心發現與管理機制）

#### 策略管理維度

安全策略支援高度動態的生命週期操作：

* **調整順序（Reorder）**：GUI 中可直接拖曳，或於 CLI 使用 `move <id> before/after <id>` 調度順序（極度關鍵：寬鬆規則若放在過於靠前位置會遮蔽下方的細部精確規則）。
* **啟用/停用（Enable/Disable）**：維運或排錯時可將規則快速暫停（`set status disable`），無須刪除。
* **複製與複製衍生（Clone / Copy）**：支援快速複製規則（`Clone`）並在上/下方插入修改，提升維運效率。


### Implications & Practical Insights（實務意涵與設計要點）

1. **「由上而下」的遮蔽陷阱（Shadowing Rules）**：
    * 由於具備「首條命中即停止（First-Match）」特性，若將範圍極大的規則（如 Source: `all`, Destination: `all`, Action: `ACCEPT`）置頂，下方所有針對特定主機、服務或拒絕黑名單的政策將**完全失去作用**。
    * **實務原則**：規則編排必須嚴格遵守「**具體特定（Specific）在頂，廣泛寬鬆（General）在底**」。

2. **Deny 規則的實務價值**：
    * 雖然底部已有預設的 Implicit Deny，但主動在特定規則上方建立顯式（Explicit）的 `DENY` 策略，主要目的是為了針對特定惡意 IP、未授權服務進行即時阻斷，並精準抓取該類違規日誌（Violation Log）以利資安告警。


3. **Session 關聯維護**：
    * 安全策略主要檢驗**連線發起端（Initiator）的第一個封包**；一旦策略判定為 `ACCEPT` 並建立 Session，後續連線封包均直接依據 Session 快取查表轉發，無須每個封包重複比對由上而下的 Policy 表，確保高吞吐轉發效能。

## Firewall Policy Parameters

### Background / Objective（背景與核心目的）

* **核心角色與情境**：在 FortiOS 7.4.12 架構中，**防火牆安全策略（Firewall Policy）** 是所有通過 FortiGate 流量的核心判斷樞紐。任何從一個網路介面進入、並試圖從另一個介面離開的連線請求，都必須與安全策略中的各項參數進行匹配比對。

* **欲解決之核心問題**：透過嚴謹的多維度條件組合（L2~L7），精確界定流量的「進入點（Ingress）」、「外出點（Egress）」、「發起者（Source/Identity）」、「目標位置（Destination/Service）」以及「時間與安全檢查維度」，防止非授權連線穿越，並作為後續啟用 NAT、身分認證與 UTM 安全防護設定檔（Security Profiles）的掛載載體。


### Methodology & Architecture（比對管線與參數匹配架構）

FortiGate 防火牆策略遵循 **「由上而下（Top-Down）」** 逐條比對原則，一旦連線的第一個封包命中符合條件的規則即刻停止往下檢索（First-Match & Stop）。

```
[連入封包 (Incoming Packet)]
         │
         ▼
[封包屬性提取與多維度匹配 (Policy Matching Engine)]
   ┌────────────────────── 6 大核心必備匹配條件 ──────────────────────┐
   │ 1. Ingress Interface (連入介面 / 實體埠 / 虛擬 Zone / VPN)       │
   │ 2. Egress Interface  (出向介面 / 實體埠 / 虛擬 Zone / SD-WAN)    │
   │ 3. Source Address    (來源 IP / 網段 / Address Group / 使用者)   │
   │ 4. Destination       (目的 IP / VIP 物件 / ISDB 網際網路服務)    │
   │ 5. Service / Port    (協定與埠號 / TCP / UDP / 自訂服務)         │
   │ 6. Schedule          (排程 / always / 單次或週期性工作時段)      │
   └──────────────────────────────────────────────────────────────────┘
         │
         ├── [6 項條件全數吻合] ──> 命中該 Policy ──> 執行 Action (ACCEPT / DENY)
         │                                              │
         │                                              ├── ACCEPT ──> 建立 Session、執行 NAT / UTM
         │                                              └── DENY   ──> 丟棄封包，記錄 Violation Log
         ▼
   [任一條件不吻合] ──> 往下比對次一條 Policy ──> 直至最底層 Implicit Deny (全部丟棄)

```

---

#3. Key Findings & 核心參數體系剖析（CLI 語法與底層機制）

依據 FortiOS 7.4.12 官方手冊，防火牆策略主要參數可劃分為 **比對條件（Matching Criteria）**、**動作與轉換（Action & NAT）** 及 **深度防護（Security Profiles）** 三大構面：

#### 核心匹配參數（Matching Parameters）

| 參數名稱 (GUI) | CLI 語法名稱 | 屬性類型與值域範圍 | 運作機制與說明 |
| --- | --- | --- | --- |
| **Policy ID** | `edit <id>` | 整數（如 `1`, `10`） | 系統自動指派或手動指定的唯一識別碼。決定規則在 CLI 中的實體編號，可透過 `move` 指令調整優先順序。 |
| **Incoming Interface** | `set srcintf <string>` | 實體介面、VLAN、Zone、VPN | 封包進入 FortiGate 的實體或虛擬介面。可綁定單一介面或群組 Zone。 |
| **Outgoing Interface** | `set dstintf <string>` | 實體介面、VLAN、Zone、SD-WAN | 封包經路由查表後，預計離開 FortiGate 的目標出口介面。 |
| **Source Address** | `set srcaddr <object>` | IP、Subnet、Address Group | 封包的來源 IP 位址範圍。可設為 `all` 或特定內部主機網段。 |
| **Source User / Group** | `set users <name>`<br>`set groups <name>` | LDAP、FSSO、RADIUS、Local | **身分感知訪問控制**。當設定使用者或群組時，未認證流量會被重導向至 Captive Portal 要求身分驗證。 |
| **Destination Address** | `set dstaddr <object>` | IP、Subnet、FQDN、VIP | 封包的目的定位址。在一般出向存取中可設為 `all`；**在 DNAT 情境中，此處必須直接指定 VIP 物件名稱**。 |
| **Internet Service (ISDB)** | `set internet-service enable`<br>`set internet-service-name <name>` | FortiGuard 動態 IP/Port 庫 | 預先定義且由 FortiGuard 動態維護的雲端服務資料庫（如 Office365、AWS、GitHub、Google）。啟用後會直接取代傳統的 Destination Address 與 Service，免除手動維護公有雲動態 IP 的困擾。 |
| **Service** | `set service <object>` | L4 Protocol、Port（如 HTTP、ALL） | 匹配 L4 協定與連接埠（如 TCP 80/443、UDP 53 等）。未在清單內的 Port 請求將無法匹配該條策略。 |
| **Schedule** | `set schedule <object>` | `always`、one-time、recurring | 策略生效的時間視窗。支援一次性有效期限（One-time）或按星期循環的排程（如週一至週五上班時段）。 |

#### 動作、位址轉換與狀態控制（Actions & NAT）

* **Action (`set action accept | deny`)**：
    * `accept`：放行封包，允許進入後續處理管線並建立雙向連線狀態（Session Table）。
    * `deny`：直接丟棄封包（Drop）。

* **NAT 相關參數**：
    * `set nat enable | disable`：啟用或停用出向來源位址轉換（SNAT）。
    * `set ippool enable` 搭配 `set poolname <name>`：指定動態 IP Pool 物件（支援 Overload、One-to-One、Fixed Port Range、Port Block Allocation）。

* **Session 日誌控制**：
    * `set logtraffic all`：記錄該策略匹配的所有完整連線。
    * `set logtraffic utm`：僅在觸發資安事件時記錄。



#### 安全設定檔整合（Security Profiles / UTM）

在 `set action accept` 的前提下，可掛載 Layer 7 深度檢查模組：

* **`set utm-status enable`**
* **`set av-profile <name>`**：防毒檢查（Antivirus）。
* **`set webfilter-profile <name>`**：網頁分類過濾（Web Filter）。
* **`set ips-sensor <name>`**：入侵防禦系統（IPS）。
* **`set application-list <name>`**：應用程式特徵識別與控管（Application Control）。
* **`set ssl-ssh-profile <name>`**：SSL 憑證檢驗或 Deep-Inspection 深度解密。



#### FortiOS 7.4.12 典型 CLI 配置範例

```fortios
config firewall policy
    edit 10
        set name "Corp_Users_To_Internet"
        set srcintf "port3"                     # 內部連入介面
        set dstintf "port1"                     # 外部出向介面
        set action accept
        set srcaddr "10.0.1.0/24"               # 來源位址物件
        set dstaddr "all"                       # 目的端物件
        set schedule "always"                   # 生效排程
        set service "HTTP" "HTTPS" "DNS"        # 限制服務埠號
        
        # --- NAT 與身分認證 ---
        set nat enable                          # 啟用 SNAT (預設使用 Outgoing Interface)
        set groups "Finance_AD_Group"           # 整合身分識別
        
        # --- UTM 深度防禦 ---
        set utm-status enable
        set ssl-ssh-profile "certificate-inspection"
        set av-profile "default"
        set webfilter-profile "default"
        set logtraffic all
        set status enable                       # 啟用策略狀態
    next
end

```

---

### Implications & Practical Engineering Insights（實務意涵與設計要點）

1. **六大要素全匹配原則（All-Condition Matching）**：
    * 封包必須**同時滿足** `Incoming Interface`、`Outgoing Interface`、`Source`、`Destination`、`Service` 與 `Schedule` 六大要素，該規則才算命中。任一條件不符（如工作時段外連線、非允許的 Port、或介面路由走向不同），封包即跳至下一條政策比對。


2. **通訊方向性（Traffic Directionality & Statefulness）**：
    * 安全策略主要規範**連線發起端（Initiator）的起始方向**。
    * 例如用戶端上網瀏覽網頁，雖然回程有大量 HTTP/HTTPS 封包由外網伺服器流向內部，但因 FortiGate 是狀態檢驗防火牆（Stateful Firewall），一旦初始請求經 `port3 -> port1` 策略核准並在記憶體建立 Session，回程封包即自動關聯放行，**絕對不需要反向設定一條由 `port1 -> port3` 的安全策略**。只有內部有獨立伺服器需對外提供主動連線時，才需針對該入向流量單獨設定政策。

3. **ISDB 取代傳統 FQDN/IP 的效能優勢**：
    * 面對 Office365、Zoom 或 AWS 等頻繁變更公網 IP 的大型 SaaS 服務，傳統使用 FQDN 或手動建立 Address Group 容易因 DNS TTL 逾時或 IP 漏列而引發業務中斷。
    * 採用 **Internet Service (ISDB)** 作為策略目的端，由 FortiGuard 雲端特徵庫動態向 FortiGate 核心核心即時推送更新，大幅降低網管人員手動維護 ACL 的成本與失誤風險。

## Inspection Mode

### Background / Objective（背景與核心目的）

* **核心角色與情境**：次世代防火牆（NGFW）在處理 Layer 7 應用層安全防護時，面臨傳輸延遲與深度解析的權衡取捨。FortiOS 支援在每一條 Firewall Policy 中獨立切換 **Flow-based（串流檢測模式）** 或 **Proxy-based（代理檢測模式）**，而非全域綁死單一架構。

* **欲解決之核心問題**：
    1. 針對高頻寬、低延遲需求的流量（如影音串流、大型檔案傳輸、一般 Web 瀏覽），提供近乎線速（Wire-speed）且不大幅消耗 CPU 記憶體的安全防禦。
    2. 針對高資安風險情境（如公司郵件伺服器、機密資料外洩防護 DLP、嚴格網頁重寫與安全認證），提供完整組裝還原的深度安全防護。


### Methodology & Architecture（架構機制與封包流向流程圖）

#### 核心架構處理機制流程圖

```
========================================================================================
                          FortiOS 雙檢測模式封包流向架構對比
========================================================================================

【情境一：Flow-based Mode（逐封包即時串流掃描，預設模式）】

  [連入封包 Flow] ──> [硬體加速 (CP9/SPU)] ──> [IPS 引擎特徵碼比對 (Pattern Matching)]
                                                        │
                      ┌─────────────────────────────────┴─────────────────────────────────┐
                      ▼                                                                   ▼
              【正常無威脅封包】                                                  【偵測到威脅 Payload】
                      │                                                                   │
    逐封包即時轉發 (Zero-Buffering)，僅暫扣最後一個封包                 FortiGate 阻斷連線並向接收端發送 TCP RST
                      │                                                                   │
                      ▼                                                                   ▼
       [直通目的地 (低延遲 / 高吞吐)]                                      [連線中斷 (Terminated / Dropped)]


----------------------------------------------------------------------------------------

【情境二：Proxy-based Mode（完整緩衝組裝與雙向代理模式）】

  [用戶端 Client]                                [FortiGate 代理引擎]                         [目標伺服器 Server]
         │                                                │                                            │
         │─────── 建立連線 Session 1 (TCP Handshake) ────>│                                            │
         │                                                │─────── 建立連線 Session 2 (TCP Handshake) ─>│
         │                                                │                                            │
         │─────── 傳送資料 Payload 1, 2, 3 ... ──────────>│ [記憶體暫存緩衝 (Full Buffering)]          │
         │                                                │       │                                    │
         │                                                │       ▼                                    │
         │                                                │ [內容重組還原 (Reconstruct Content)]       │
         │                                                │       │                                    │
         │                                                │       ├── Antivirus (完整解壓縮掃描)        │
         │                                                │       ├── Web Filter (網頁替換警告頁)       │
         │                                                │       └── DLP (檔案特徵與洩漏檢查)         │
         │                                                │       │                                    │
         │                                                │       ▼                                    │
         │                                                │ [確認安全無虞]                             │
         │                                                │─────── 轉發完整組裝內容 ──────────────────>│
         │<────── 回傳伺服器回應 ────────────────────────-─│<────── 回應資料 ───────────────────────────│

```



### 3. Key Findings & 特性對照剖析（核心發現與參數比對）

#### 兩大檢測模式核心行為與功能矩陣對比

| 比較項目 | Flow-Based Mode（串流模式） | Proxy-Based Mode（代理模式） |
| --- | --- | --- |
| **預設狀態** | **FortiOS 7.4.12 策略預設值** | 需手動切換啟用 |
| **緩衝行為 (Buffering)** | **無記憶體完整緩衝（Zero Buffering）**：封包隨到隨檢並立即轉發，僅保留最後一個封包以待掃描判定。 | **完整記憶體組裝（Full Buffering）**：接收完整內容並重組還原（Reconstruct）後才開始檢查。 |
| **硬體加速與效能** | 支援 SPU / CP9 晶片加速，**極高吞吐量、超低延遲**。 | 仰賴 CPU 密集運算與 RAM 緩衝，延遲較高、吞吐量受限。 |
| **阻斷機制 (Drop/Reset)** | 命中特徵碼時，對雙方發送 **TCP RST 封包** 強制中斷 Session。 | 直接由代理終止連線，並可回傳 **自訂 HTML 阻斷/警告頁面** 給用戶端。 |
| **支援的安全功能** | • Antivirus（串流快篩）<br> Web Filter（分類查詢）<br> IPS、DNS Filter、應用程式控制 | Antivirus（支援深層壓縮檔拆解掃描）<br>DLP（資料外洩防護）<br> Email Filter / Video Filter<br> Web 認證/警告重定向頁面 |
| **適用典型場景** | 辦公室上網外向流量、影音傳輸、資料中心 East-West 高速流量。 | 內部郵件伺服器（DMZ）、高機密研發資料防洩漏（DLP）、合規審計流量。 |

#### FortiOS 7.4.12 CLI 配置語法

在安全策略中直接宣告 inspection-mode：

```bash
# 1. 配置 Flow-based 策略 (追求轉發效能)
config firewall policy
    edit 1
        set name "LAN_to_WAN_Flow"
        set srcintf "port3"
        set dstintf "port1"
        set action accept
        set srcaddr "all"
        set dstaddr "all"
        set schedule "always"
        set service "ALL"
        
        # --- 核心檢查模式 ---
        set inspection-mode flow               # 啟用 Flow-based 檢測
        set utm-status enable
        set av-profile "default"               # 套用 Flow-based AV
        set ips-sensor "default"
    next
end

# 2. 配置 Proxy-based 策略 (追求完整深度檢測)
config firewall policy
    edit 2
        set name "WAN_to_DMZ_Proxy"
        set srcintf "port1"
        set dstintf "port2"
        set action accept
        set srcaddr "all"
        set dstaddr "VIP_MailServer"
        set schedule "always"
        set service "ALL"
        
        # --- 核心檢查模式 ---
        set inspection-mode proxy              # 啟用 Proxy-based 檢測
        set utm-status enable
        set av-profile "proxy-av"
        set dlp-sensor "default"               # 支援 DLP 等代理型進階功能
    next
end
```


### Implications & Practical Insights（實務意涵與架構選型）

1. **Security Profiles（安全設定檔）相依性約束**：
    * 當 Firewall Policy 設為 `flow` 時，若關聯的 Security Profile（例如 Antivirus 或 Web Filter）內含有僅限 Proxy 支援的進階選項，系統將限制該功能生效或要求同步匹配。
    * 若需使用 **DLP（資料外洩防護）**、**自訂 HTTP 攔截頁面（Custom Replacement Messages）** 或 **安全網頁重寫（Web Profile Override）**，該條政策**必須明確指定為 `proxy` 模式**。


2. **AIDC 與高效能運算場景建議**：
    * 在高密度資料交換、AIDC 節點對外拉取資料庫或分散式叢集通訊中，強烈維持 **`flow` 模式**，避免因記憶體緩衝重組導致的 TCP 延遲放大與逾時問題。

3. **分流混合部署最佳實務（Per-Policy Hybrid）**：
    * 傳統分公司出口可 90% 以上採 Flow 模式維持網路流暢度；僅針對特定內部郵件伺服器（SMTP/IMAP）或財務機密專用連線單獨拆分出一條 Proxy 模式安全策略，達到效能與深層防禦的最佳平衡。

## Multiple Interface and Any Policies

### 1. Background / Objective（背景與核心目的）

* **核心情境與痛點**：在預設環境下，若有多個內部介面（例如 `LAN (port3)`、`DMZ (port2)`、`WiFi`）需要連線至外部多個出口（例如 `WAN-1` 與 `WAN-2`），網管人員往往必須排列組合建立多條重複的安全策略，導致策略清單膨脹且維護成本大幅提升。
* **欲解決之核心問題**：透過啟用 **Multiple Interface Policies**，解除介面一對一選取的限制：
    1. 允許在單一條 Policy 中以清單方式選取多個來源與目的介面（如 `set srcintf "port3" "port2"`）。
    2. 開放使用 **`any`** 通配介面（匹配 FortiGate 上的任意連入或離開介面）。
    3. 大幅收斂規則數量，並在特定架構（如 Virtual Wire Pair、跨多介面通用放行規則）中提供靈活的配置彈性。


### Methodology & Architecture（設定流程與實作方式）

#### GUI 圖形介面操作步驟

1. **啟用功能可見性（Feature Visibility）**：
    * 前往 **System > Feature Visibility**。
    * 滾動至 **Additional Features**（附加功能）區塊。
    * 找到 **Multiple Interface Policies** 並將開關切換為 **Enable**（開啟）。
    * 點選右下角 **Apply** 套用變更。


2. **在 Firewall Policy 中使用多介面或 any**：
    * 前往 **Policy & Objects > Firewall Policy**，點選 **Create New** 或編輯既有策略。
    * 觀察介面欄位：
        * `Incoming Interface` 與 `Outgoing Interface` 右側現在會出現 **`+`（新增更多介面）** 圖示。
        * 點開選單即可同時勾選兩個以上的介面，或是直接選取 **`any`**。
        * 完成其餘參數（Source, Destination, Service 等）後點選 **OK** 儲存。



#### CLI 命令列設定方式

```fortios
# 步驟 1：全域啟用多介面策略支援
config system settings
    set gui-multiple-interface-policy enable
end

# 步驟 2：在防火牆策略中指定多個介面或 any
config firewall policy
    edit 1
        set name "Allow_Multi_LAN_to_WAN"
        # 同時指定多個來源介面 (port3 與 port2)
        set srcintf "port3" "port2"
        # 同時指定多個目標介面 (WAN-1 與 WAN-2)，或設為 "any"
        set dstintf "port1" "port4"
        set action accept
        set srcaddr "all"
        set dstaddr "all"
        set schedule "always"
        set service "ALL"
        set nat enable
    next
end

```

> **CLI 特性補充**：在 FortiOS CLI 中，即使 GUI 尚未切換開關，部分底層規則（如 Virtual Wire Pair 策略）亦原生支援以空格隔開多個介面（例如 `set srcintf "port3" "port4"`）；但在 `system settings` 開啟 `gui-multiple-interface-policy` 後，才能完整解鎖 Web GUI 的多選與 `any` 顯示支援。

---

### 架構流程圖（單一策略整合多介面示意）

```
                     【多來源連入介面 (Incoming)】
               ┌───────────────────┬───────────────────┐
               ▼                   ▼                   ▼
          [LAN (port3)]       [DMZ (port2)]      [WiFi (port5)]
               │                   │                   │
               └───────────────────┼───────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────┐
          │     單一整合型 Firewall Policy (ID: 1)           │
          │  • Incoming Interface: [port3, port2, port5]    │
          │  • Outgoing Interface: [port1, port4] (或 any)   │
          │  • Action: ACCEPT                               │
          │  • NAT: Enabled                                 │
          └────────────────────────┬────────────────────────┘
                                   │
               ┌───────────────────┴───────────────────┐
               ▼                                       ▼
        [WAN-1 (port1)]                         [WAN-2 (port4)]
               │                                       │
               └───────────────────┬───────────────────┘
                                   ▼
                     【外部網際網路 (Internet / Any)】

```

---

### Key Findings & Practical Insights（核心考量與實務建議）

1. **多介面策略 vs. Security Zones（安全性區域）的架構取捨**：
    * **Multiple Interface Policy**：適合臨時維運、少數跨介面規則收斂，或是直接使用 `any` 介面簡化測試。
    * **Security Zone（官方推薦最佳實務）**：若這些介面（如多個 LAN 實體埠）本質上具有相同信任等級與安全需求，在企業架構中建議優先建立 **Zone**（例如將 `port3`、`port4` 納入 `LAN-ZONE`），將 Zone 指定為 Policy 介面；這樣日後新增/移除實體網卡時，只需調整 Zone 成員，完全不需改動安全策略。

2. **`any` 介面的維運隱患與遮蔽風險**：
    * 當將 `Incoming Interface` 或 `Outgoing Interface` 設為 `any`，且搭配 Source: `all`、Destination: `all` 時，該條規則會涵蓋防火牆所有的穿越路徑（包含 LAN 到 WAN、WAN 到 LAN、DMZ 到 LAN 等）。
    * **實務原則**：若因方便而將帶有 `any` 介面的寬鬆規則放置在頂部，將會直接造成「**規則遮蔽（Shadowing Rules）**」，導致下方所有針對特定介面的精確限制與拒絕策略完全失效，設定時應格外謹慎。

## Policy Table

### Background / Objective（背景與核心目的）

* **核心角色與情境**：FortiGate 採用由上而下（Top-Down）的規則匹配機制，策略清單的先後順序、啟閉狀態與命中指標直接決定了網路安全姿態與轉發結果。

* **欲解決之核心問題**：
    1. 提供單一全景介面，清晰檢視跨介面（From/To）、使用者身分、排程、NAT 與安全性設定檔（UTM）的綁定狀態。
    2. 解決規則膨脹時「不易排查連線走哪條規則」與「難以識別無效/過時規則」的維運痛點，藉由整合流量統計（Bytes）與計數器（Hit Count）提供量化依據。


### Methodology & Architecture（介面操作與欄位客製化方法）

#### 自訂策略表欄位（Configure Table）

若介面預設未顯示特定監控欄位（如 ID、Status、Hit Count、Bytes 等），可透過下列步驟開啟：

    1. 前往 **Policy & Objects > Firewall Policy**。
    2. 將滑鼠游標懸停於任一欄位標題（Header）上方，按右鍵或點擊齒輪圖示，選擇 **Configure Table**（配置表格）。
    3. 勾選欲顯示的欄位（如 `ID`、`Status`、`Hit Count`、`Bytes`、`Active Sessions` 等），亦可點選 **Reset Table** 重設或 **Best Fit Columns** 自動適應欄寬。
    4. 點選 **Apply** 儲存個人化視圖。



#### 規則排序與檢視模式切換（Interface Pair vs. Sequence）

FortiOS 7.4.12 支援兩種主要的策略表排列檢視視圖：

* **Interface Pair View（介面配對模式）**：將相同「連入 ➔ 連出」介面的政策分組折疊顯示，有助於依據實體/虛擬區域掌握邊界防護範圍。
* **By Sequence View（全域序號模式）**：跨介面直接展示由上而下的絕對執行序號（Sequence Number），精確反映底層引擎的真實匹配優先順序。可在此模式下透過拖曳或 CLI `move` 指令調度規則。

### Key Findings & 核心欄位體系剖析（欄位特徵與行為定義）

依據官方規格與操作指南，Policy Table 包含的代表性特徵欄位如下：

| 欄位名稱 (Column) | 特徵屬性 (Characteristic) | 運作機制與定義說明 |
| --- | --- | --- |
| **ID** | `Unique Identifier` | 系統於建立政策時自動分派的唯一數字 ID（`0` 預設保留給最底層的 Implicit Deny）。ID 一旦產生即固定，不隨策略在表格中上下移動而改變。 |
| **Name** | `Policy Name` | 規則的自訂文字名稱，便於專案或業務識別（如 `Allow_LAN_to_WAN`）。 |
| **From** | `Source Interface(s)` | 來源/連入介面（Incoming Interface），可為單一實體埠、VLAN、Zone 或多介面組合。 |
| **To** | `Destination Interface(s)` | 目的/出向介面（Outgoing Interface），指示封包路由離開的介面或 SD-WAN。 |
| **Source** | `Source Address & Identity` | 發起連線的主機位址、Subnet、Address Group、特定國家（GeoIP）或 AD/LDAP 使用者與群組。 |
| **Destination** | `Destination Address / VIP` | 目的地位址物件、FQDN、VIP 虛擬 IP 或 ISDB 雲端服務庫。 |
| **Schedule** | `Policy Schedule` | 生效時間區間，預設為 `always`，亦可設定定期工作時段或單次到期排程。 |
| **Service** | `Policy Services` | 允許通過的 L4 協定與埠號（如 `HTTP`、`DNS`、`ALL`）。|
| **Action** | `Accept / Deny` | 基礎放行動作：`ACCEPT`（建立 Session 並允許後續檢測）或 `DENY`（直接阻斷）。 |
| **NAT** | `NAT Status` | 出向來源位址轉換狀態（`Enabled` 或 `Disabled`）。若啟用，可進一步配置 Interface Overload 或 Dynamic IP Pool。 |
| **Security Profiles** | `UTM Profiles Applied` | 掛載的 Layer 7 深度安全設定檔。**重要特性**：僅當 Action 為 `ACCEPT` 時方能生效並顯示；若為 `DENY` 則自動隱藏。包含 Antivirus、IPS、Web Filter、Application Control 等。 |
| **Log** | `Traffic Logging Status` | 工作階段日誌記錄等級，如 `All Sessions`（所有連線）、`Security Events`（僅資安事件）或 `Disabled`。 |
| **Bytes** | `Traffic Volume` | 該條策略已累計處理的流量傳輸總量（以 Bytes、KB、MB 或 GB 顯示）。 |
| **Hit Count** | `Traffic Counter` | 封包匹配該策略的累積次數。點擊或懸停可查看近期的連線頻率，支援手動重置計數。 |
| **Status** | `Enabled / Disabled` | 規則的實體運作狀態。可直接雙擊或右鍵將策略切換為暫停狀態（`Disabled`）而無需刪除規則條目。 |

### Implications & Practical Insights（實務意涵與設計要點）

1. **規則精簡與垃圾策略清理（Policy Pruning）**：
    * 藉由開啟 **`Hit Count`** 與 **`Bytes`** 欄位，資安團隊能快速辨識哪些是「長期零命中（Zero-Hit）」的殭屍規則。
    * 在經過業務確認與停用觀察後，可予以刪除，減少策略資料庫負擔並消除非必要的潛在穿透風險。

2. **Policy ID 與日誌追蹤關聯**：
    * 防火牆日誌（Log & Report > Forward Traffic）與 Syslog 輸出中，每筆記錄皆帶有 `policyid=<ID>` 屬性。
    * 透過 Policy Table 顯示 `ID` 欄位，網管人員可在接獲資安告警或連線異常時，第一時間依據 ID 精準定位到對應的安全規則進行修正。


3. **隱含拒絕（Implicit Deny / ID 0）的監控**：
    * 表格最底部的 `Implicit Deny`（ID 0）預設丟棄所有未匹配流量。
    * 透過編輯 ID 0 開啟 `Log Violation Traffic`，能在 Policy Table 或 Log 中即時掌握未被現有規則放行的非法探測或設定遺漏。

## Policy Match

### Background / Objective（背景與核心目的）

* **核心痛點**：FortiGate 嚴格遵循由上而下（Top-down）與首條命中即停止（First-match）的比對原則。在包含數十至數百條政策的複雜網路中，常因規則順序倒置（Shadowing Rules）、未預期的 Address/Service 範圍重疊，導致流量未走預期策略而發生連線異常。


* **核心目的**：
    1. 提供離線/模擬的五元組封包查表工具，輸入流量特徵即可精準預測轉發決策。
    2. 驗證新建立策略（如 DNAT VIP、特定使用者群組存取）的優先順序是否正確生效。
    3. 快速跳轉至目標規則進行編輯除錯，大幅縮短維運排錯時間。

### Methodology & Architecture（比對流程與操作步驟）

Policy Match 模擬比對遵循 FortiOS 核心轉發管線邏輯：**先比對路由與連入介面，再由上而下檢索安全性策略清單**。

```
[輸入模擬流量特徵 (Traffic Parameters)]
  • Ingress Interface: WAN-1 (port1)
  • Protocol: HTTP (TCP)
  • Source IP: 172.29.129.38 / Source Port: (Optional)
  • Destination IP: 192.168.1.200 (VIP) / Destination Port: 80
                 │
                 ▼
[底層查表運算 (Policy Lookup Engine)]
  ├── 1. 路由有效性查核 (Routing Table Check): 確保目的路徑存在可用路由
  └── 2. 策略規則逐條比對 (Top-Down Sequence Evaluation):
           ├── Policy ID 1 ──(未命中 Ingress/IP)
           ├── Policy ID 2 ──(未命中)
           ├── Policy ID 3 ──(未命中)
           └── Policy ID 4 ──【命中 Match Found!】
                 │
                 ▼
[診斷成果輸出 (Diagnostics Output)]
  • 命中策略: Allow-DMZ-SRV-from-WAN1 (Policy ID: 4)
  • 執行動作: ACCEPT
  • 快速操作: [Show in list (清單高亮)] 或 [Edit (直接編輯)]

```

#### GUI 執行步驟：

1. **開啟診斷工具**：前往 **Policy & Objects > Firewall Policy**，點選上方工具列的 **Policy match** 按鈕。

2. **輸入模擬參數**：
    * **Incoming interface**：指定流量進入的介面（例如 `WAN-1 (port1)`）。
    * **Protocol**：挑選協定類型（如 `HTTP`、`TCP`、`UDP`、`ICMP`）。
    * **Source**：輸入發起端來源 IP（例如 `172.29.129.38`）。
    * **Source port**：來源連接埠（選填，若無特定限制可留空）。
    * **User**：身分群組（若有配置 Captive Portal / FSSO，可指定特定 User / Group）。
    * **Destination address**：目的地位址（例如發布的公網 VIP `192.168.1.200`）。
    * **Destination port**：目的服務連接埠（例如 `80`）。

3. **執行匹配**：點選 **Find matching policy**。


4. **檢視與連動**：
    * 系統即時顯示命中的策略名稱（例如 `Allow-DMZ-SRV-from-WAN1 (4)`）與預期動作（`Accept` 或 `Deny`）。
    * 點選 **Show in list**：頁面會自動在策略總表中將該條規則以醒目顏色高亮選取。
    * 點選 **Edit**：直接彈出該策略的編輯設定視窗，方便立即調校參數。

### Key Findings & 核心參數體系剖析

根據 FortiOS 7.4 規範與實驗觀察，Policy Match 工具的底層細節包含以下特性：

#### 關鍵參數與比對依據

* **前置路由依賴（Routing Prerequisite）**：Policy Match 在比對前會先確認路由表（FIB）中是否存在到達該 Destination 的有效路徑。若路由表中無對應路徑，即使策略條件符合，系統也可能提示無匹配策略或轉發失敗。
* **歷史搜尋紀錄（Recent Matches）**：工具具備快取功能，會保留近期的查詢條件與歷史紀錄，更換參數時可快速載入重試。
* **DNAT / VIP 預轉換感知**：當目的 IP 輸入的是外部 VIP（如 `192.168.1.200`）時，Policy Match 能準確識別對應的 DNAT 關聯，並比對出底層放行該 VIP 物件的安全策略。

#### CLI 對等指令（CLI Policy Trace）

若在純終端機（CLI/SSH）環境下進行排錯，FortiOS 提供了功能相同的 CLI 追蹤指令：

```fortios
# 使用 diagnose 指令進行離線策略比對
diagnose firewall iprope lookup <src_ip> <src_port> <dst_ip> <dst_port> <protocol_num> <ingress_interface>

# 範例：查詢由 port1 進入、訪向 192.168.1.200:80 的 HTTP (TCP=6) 流量
diagnose firewall iprope lookup 172.29.129.38 54321 192.168.1.200 80 6 port1

```

*輸出解析*：系統會直接返回命中的 `policy_index` 與對應的 `rule_id`，達成與 GUI 相同的反查效果。


### Implications & Practical Engineering Insights（實務意涵與設計要點）

1. **上線前變更驗證（Pre-Deployment Validation）**：
    * 在企業主幹防火牆新增特定放行或阻斷政策後，應第一時間利用 Policy Match 進行正向（應該通過）與反向（應該阻斷）的模擬測試，確認新規則未被上方的寬鬆規則攔截遮蔽。

2. **與動態除錯指令（Debug Flow）的互補關係**：
    * **Policy Match**：屬於靜態/離線模型，適合*靜態檢查既有策略規則語法與優先級*。
    * **`diagnose debug flow`**：屬於動態/即時抓包，能追蹤真實封包的 NAT 改寫、CPU/NP 硬體卸載狀態與 UTM 丟棄原因。兩者搭配可涵蓋 100% 的防火牆轉發排錯需求。

3. **隱含拒絕（Implicit Deny）的兜底確認**：
    * 若 Policy Match 回傳結果為最底層的 `Implicit Deny (0)`，代表現有安全策略庫中沒有任何一條規則同時滿足六大匹配條件，必須逐一檢查介面綁定、排程有效性或位址物件設定。

## Plicy View

### 核心概念與切換方式

在 FortiGate 的 **Policy & Objects > Firewall Policy** 頁面右上角，可透過下拉選單在不同 organizational 格式間切換，主要包含 **Interface Pair View**、**By Sequence** 以及 **Sequence Grouping View** 三種模式。

### 三大檢視模式對比與重點

#### 1. Interface Pair View（介面配對檢視模式）

* **分類邏輯**：依據 **Incoming Interface（連入介面）與 Outgoing Interface（連出介面）的組合** 進行分組（例如：`LAN -> WAN-1`、`DMZ -> WAN-2`）。
* **預設狀態**：FortiGate（NGFW）的**預設顯示模式**。
* **折疊管理**：每個介面組合各自獨立成一個區塊，支援自由展開與折疊，便於聚焦特定網路區域的流量規則。
* **使用限制（灰色反灰）**：
    * 若策略中使用了 **`any` 介面** 或啟用了 **Multiple Interfaces（多介面策略）**，此檢視模式將**反灰無法使用**（強制切換至 By Sequence）。

#### 2. By Sequence（循序檢視模式）

* **分類邏輯**：**不進行任何介面分組**，純粹依據防火牆底層引擎由上而下（Top-Down）實際比對的「絕對先後順序」一條條完整列出。
* **自動切換機制**：一旦任何安全策略中包含 `any` 或多個來源/目的介面，FortiGate 會**自動強制將畫面切換為 By Sequence**。
* **順序調整功能**：在此模式下，可直接透過拖曳或右鍵指定 Policy ID，將規則移動（Move）至另一條規則的前方或後方，精確控制比對優先權。

#### 3. Sequence Grouping View（循序分組檢視模式）

* **分類邏輯**：維持由上而下的全域執行順序（Sequence），但允許管理員自訂邏輯群組標籤（Custom Groups），兼顧順序嚴謹性與分類閱讀的便利性。

### 關鍵維運與排錯重點

1. **排查 Shadowing（規則遮蔽）**：若懷疑上位規則遮蔽了下方的精細規則，應切換至 **By Sequence** 檢視全域真正的先後執行順序。
2. **切換選單失效排查**：若發現右上角的 **Interface Pair View 反灰** 無法點選，代表規則庫中至少有一條策略使用了 `any` 介面或綁定了多個介面。

## Firewall Policy Logging

### Background / Objective（背景與核心目的）

* **核心情境**：在企業與資料中心高頻寬環境中，每一秒通過 FortiGate 的連線可能數以萬計。若毫無節制地為所有允許連線產生日誌，會快速耗盡本機儲存空間（Disk/Flash）、造成 CPU 與記憶體負擔，並灌爆遠端 Syslog 或 FortiAnalyzer。

* **欲解決之核心問題**：
    1. 提供彈性的記錄粒度控制，讓管理員可依業務敏感度選擇 **Security Events（僅資安事件）** 或 **All Sessions（所有工作階段）**。
    2. 提供 **Generate logs when session starts（連線開始時產生日誌）** 機制，滿足即時監控（Real-time Monitoring）與排查異常中斷連線的需求。


### Methodology & Architecture（日誌記錄選項與觸發機制）

```
                     【通過防火牆的網路連線 (Allowed Traffic)】
                                        │
                                        ▼
                   ┌─────────────────────────────────────────┐
                   │    Firewall Policy: Log Allowed Traffic │[cite: 59]
                   └────────────────────┬────────────────────┘
                                        │
             ┌──────────────────────────┴──────────────────────────┐
             ▼                                                     ▼
【Security Events（預設模式）】[cite: 59]               【All Sessions（全工作階段模式）】[cite: 59]
  • 僅在觸發 UTM 安全防護模組時記錄[cite: 59]           • 記錄該政策允許的每一筆網路連線[cite: 59]
  • (Antivirus / IPS / Web Filter / App Control)[cite: 59] • 預設在連線正常結束 (Session End) 時寫入
  • 儲存與 CPU 消耗極低[cite: 59]                       • 產生完整傳輸數據 (Sent/Rcvd Bytes)
                                                           • 儲存空間與資源消耗大[cite: 59]
                                                                   │
                                            ┌──────────────────────┴──────────────────────┐
                                            ▼                                             ▼
                             [預設：連線關閉時記錄]                  [啟用：Generate logs when session starts][cite: 59]
                             • 僅在 Session 終止時寫入一筆 Log      • Session 一建立 (TCP SYN-ACK) 即刻寫入[cite: 59]
                             • 包含連線總時長與總流量量體          • 適用於即時追蹤、排查長連線中斷與資安回應[cite: 59]

```

---

### Key Findings & 核心參數體系剖析（CLI/GUI 對照與行為特徵）

#### 兩大核心記錄模式對比

| 比較項目 | Security Events（安全性事件） | All Sessions（所有工作階段） |
| --- | --- | --- |
| **預設狀態** | **FortiGate 新增政策時的預設值** | 需手動切換選取 |
| **記錄內容** | **僅記錄觸發 UTM 特徵碼的事件**（例如偵測到病毒封包、攔截惡意網址、IPS 入侵阻斷）。一般正常傳輸的連線不產生日誌。 | **記錄策略放行的所有連線**。包含連線起訖時間、來源/目的 IP、Port、NAT 改寫位址及雙向流量大小。 |
| **系統負擔** | 產生之 Log 數量少，**大幅節省儲存空間與 CPU/記憶體開銷**。 | 產生海量 Log，**儲存與系統資源消耗顯著增加**。 |
| **檢視位置** | **Log & Report > Security Events**（或各對應的 AntiVirus / Web Filter 等分類日誌）。 | **Log & Report > Forward Traffic**（轉發流量日誌）及 **FortiView**。 |
| **適用場景** | 日常辦公上網、一般信任網段轉發、內部高頻寬儲存/運算流量。 | 關鍵伺服器發布（DMZ/VIP）、外部邊界進出、法規稽核對帳、網路連線除錯排錯。 |

#### 進階選項：Generate logs when session starts（連線開始時產生日誌）

* **運作機制**：FortiOS 預設是在連線**結束（Session Close/Teardown）** 時才產生日誌，以統計完整的傳輸量（Sent/Rcvd Bytes）與持續時間（Duration）。
* **啟用效果**：一旦開啟此選項，FortiGate 會在 **TCP 三方交握成功（或 UDP 首個封包轉發）的當下立即寫入一筆起始日誌**，連線結束時再寫入第二筆日誌。
    * **適用場景**：
        1. **即時威脅應變（Incident Response）**：資安團隊需要第一時間感知惡意或異常連線發起，不能等待長連線結束後才收到 Log。
        2. **排查連線中斷（Troubleshooting Disconnects）**：若連線遭遇非正常中斷、防火牆突然當機或網路路徑黑洞，可能永遠收不到 Session Close 日誌；開啟此選項可確保起始紀錄已被成功保留。
        3. **超長連線監控**：如資料庫長連線（Database Connection Pools）或 SSH Session，連線可能維持數天甚至數週，開啟後可在發起時立即確認政策命中狀況。

#### FortiOS 7.4.12 CLI 配置語法

在 `firewall policy` 層級中，透過 `logtraffic` 與 `logtraffic-start` 參數控制：

```fortios
config firewall policy
    edit 1
        set name "Corporate_LAN_Access"
        set srcintf "port3"
        set dstintf "port1"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        
        # --- 核心日誌配置參數 ---
        # 模式選取：all (All Sessions) 或 utm (Security Events) 或 disable
        set logtraffic all                             # 等同 GUI 勾選 [All sessions][cite: 59]
        
        # 進階起始日誌：enable 或 disable
        set logtraffic-start enable                    # 等同 GUI 勾選 [Generate logs when session starts][cite: 59]
    next
end

```

> **CLI 對照速查**：
> * `set logtraffic utm`：對應 GUI 的 **Security events**。
> 
> 
> * `set logtraffic all`：對應 GUI 的 **All sessions**。
> 
> 
> * `set logtraffic disable`：完全關閉該策略的允許流量日誌。
> * `set logtraffic-start enable`：對應 GUI 的 **Generate logs when session starts**。
> 

### Implications & Practical Engineering Insights（實務意涵與維運最佳實務）

1. **儲存空間與 Log Rate 崩潰預防**：
    * 在大規模網路或 AIDC 環境中，**切忌對所有出向政策無差別啟用 `logtraffic all` 搭配 `logtraffic-start enable**`。這會讓單一連線產生兩筆日誌，Log 吞吐量瞬間翻倍，可能導致本機磁碟進入保留空間保護模式（Log Disk Full）甚至拖垮 FortiAnalyzer 寫入效能。

2. **Deny 策略的違規日誌（Violation Traffic）**：
    * 當政策的動作為 `action deny` 時，日誌選項會收斂為單一的 `Log Violation Traffic`（CLI 為 `set logtraffic-start enable`）。對於顯式的阻斷黑名單規則，強烈建議開啟此項，以利捕捉未授權掃描與異常探測行為。

3. **除錯排錯黃金組合**：
    * 平時將一般非核心政策設為 `Security events` 保持高效運行；當特定系統遭遇連線異常（如連線卡住、回程中斷或特定應用無法連網）時，臨時將該政策切換為 `All sessions` 並勾選 `Generate logs when session starts`，即可在 **Log & Report > Forward Traffic** 頁面即時確認發起與終止狀態。除錯完畢後務必切回以釋放系統資源。