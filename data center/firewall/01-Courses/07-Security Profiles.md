# Security Profiles

### Background / Objective（背景與核心目的）

* **核心情境與動機**：傳統狀態檢視防火牆（Stateful Firewall）主要依據 L3/L4 屬性（來源與目的 IP、通訊協定、傳輸埠號）進行存取放行或阻擋。但在現代網路威脅中，惡意程式、勒索軟體與資料外洩多半混雜於合法的 80端口或 443 端口流量中，傳統安全規則無法解析封包承載的實質內容。
* **欲解決之核心問題 / 技術缺口**：旨在解決「被放行流量（Allowed Traffic）缺乏內容檢測」的盲區。FortiGate 安全設定檔（Security Profiles）透過深度檢查模組，針對通過防火牆 Policy 允許的流量進行 Layer 7（應用層）內容分析，抵禦惡意軟體、惡意網址、協定濫用與未授權應用程式行為。


### Methodology / Architecture（架構設計與機制）

* **架構定位與觸發順序**：安全設定檔必須掛載於動作為 `ACCEPT` 的防火牆 Policy 之下；若流量已被 Policy 阻擋（`DENY`），系統將直接丟棄，不會耗費運算資源進入安全設定檔引擎。安全設定檔涵蓋 Antivirus、Web Filter、Application Control、IPS、File Filter 等模組。

* **核心檢驗架構與分析機制**：
    * **檢驗模式（Inspection Modes）**：
        * *串流式架構（Flow-based）*：利用 FortiGate 專屬網路/內容處理器（NP/CP）進行即時串流掃描，無需緩存完整檔案，具備高吞吐量與低延遲特性，為 FortiOS 7.4.x 的預設運作模式。
        * *代理架構（Proxy-based）*：封包於記憶體中重組成完整連線與檔案後進行深度剖析，支援 HTTP 標頭抽換、完整 URL 檢視、進階 Quota 配額等功能，檢驗細緻但消耗較多系統記憶體與運算資源。
    * **深度封包檢驗（DPI & SSL/TLS Inspection）**：加密流量（HTTPS/SMTPS）必須搭配 SSL 檢測設定檔（憑證檢查或 Full Deep-Inspection 完整解密），以使 L7 安全設定檔能夠檢視內部明文酬載。
    * **IPS 引擎核心協作**：FortiOS 中的 Application Control 與 IPS 模組共用底層 IPS 引擎，透過特徵碼比對（Signatures）與啟發式/行為分析（Behavioral Analysis）識別應用層協定與攻擊向量。

### Key Findings / System Hierarchy（核心體系與階層）

四大核心安全設定檔的技術特性、管控階層與動作選項整理如下：

| 安全設定檔模組 | 核心保護目標 | 檢測範圍與協定 | 運作模式與進階技術 | 執行動作（Actions） |
| --- | --- | --- | --- | --- |
| **Antivirus (AV)** | 病毒、木馬、蠕蟲、間諜軟體、零日漏洞惡意檔案 | HTTP/HTTPS、FTP、POP3、IMAP、SMTP、SMB/CIFS 等 | 支援 Flow / Proxy 雙模式；整合 FortiGuard 病毒爆發防護（VOS）、FortiSandbox 雲端/在地沙箱分析 |Block（丟棄惡意檔案）<br> Quarantine（隔離送驗）<br> Monitor（放行並產生記錄） |
| **Web Filter** | 限制不當網站存取、避免連線惡意網址與釣魚站點 | 網站類別、靜態 URL、頁面關鍵字、MIME 檔案類型 | FortiGuard 雲端資料庫分類檢測<br>靜態 URL 與 Regex 黑白名單<br>關鍵字與 MIME 類型過濾<br>強制 Google/Bing/YouTube 安全搜尋（SafeSearch） | Allow（允許）<br> Monitor（放行並記錄）<br> Block（攔截警告）<br> Warning（警示後放行）<br> Authenticate（認證覆寫） |
| **Application Control** | 跨越 Port/Protocol 限制，識別並管控網路應用與雲端服務 | 遊戲、P2P（如 BitTorrent）、即時通訊、影音串流、遠端存取等類別 | 依賴 IPS 引擎進行深層封包檢測與行為分析<br> 支援細粒度子功能控制（如允許 Skype 聊天但阻擋傳檔、允許 YouTube 播放但禁止上傳） | Allow（允許）<br>Monitor（放行並記錄）<br>Block（封鎖）<br>Quarantine（隔離主機）<br>頻寬限流（Traffic Shaping） |
| **Intrusion Prevention (IPS)** | 阻斷網路入侵、系統漏洞攻擊與溢位攻擊 | 涵蓋 SQL Injection、緩衝區溢位（Buffer Overflow）、RCE、OS 與服務已知漏洞 | FortiGuard 定期更新之數千組預定義特徵碼<br>支援自訂特徵碼（Custom Signatures）<br>部署模式：Inline 實體阻斷或 Sniffer 側錄模式 |Drop / Reset（丟棄/重置連線）<br>Pass（放行）<br>Alert / Monitor（警示記錄） |


### Implications / Practical Insights（結論與實務意涵）

* **安全與效能之權衡（Engineering Trade-offs）**：
    * 在硬體資源有限的邊界設備上，建議優先採用 **Flow-based 檢驗模式**，透過 SOC/CP 硬體加速晶片卸載運算負載，確保大流量轉發時維持低延遲。
    * 若需要強制執行細部 HTTP Header 檢查、替換網頁警告訊息或實施精確的 Web Quota 配額控制，則必須切換至 **Proxy-based 模式**，並預留足夠的記憶體餘裕。
* **SSL 解密架構之相依性**：
    * 大多數惡意載荷與應用特徵皆包覆於 TLS/SSL 之中。若僅啟用 Certificate Inspection，Web Filter 僅能依據 SNI 與 IP 判斷，無法執行完整 URL 路徑檢驗、關鍵字過濾或深層防毒。
    * 欲全面發揮 Antivirus、Web Content Filter 與 Application Control 子功能（如禁止檔案上傳）之效能，必須在終端部署 FortiGate CA 根憑證並啟用 **Full Deep-Inspection**。

* **維運與策略落地建議**：
    * **初期部署採 Monitor 階段**：新建安全設定檔時，建議將動作設為 `Monitor` 運行 1 至 2 週，評估日誌與告警，避免特徵碼誤判（False Positives）導致關鍵業務中斷。
    * **縱深防禦搭配**：除上述四大核心模組外，亦可依情境結合 DNS Filter（先期網域名稱解析阻截）與 File Filter（阻斷特定副檔名），構建多層次的邊界安全防禦。

## Web Profile and Rating Override

### Background / Objective（背景與核心目的）

* **核心情境與動機**：在企業邊界安全架構中，Web Filter（網頁過濾）通常依據 FortiGuard 全域雲端分類資料庫或統一安全基準（如全面阻擋社交網路、頻寬消耗或高風險站點）進行控管。然而，靜態且一刀切的過濾規則無法完全滿足動態業務需求與複雜的網站屬性判定。
* **欲解決之核心問題 / 技術缺口**：
    1. *臨時業務存取例外（Temporary Business Exception）*：特定使用者或部門（例如 HR 招募人員）因業務需求需臨時存取被策略阻擋的類別（如社交媒體），若直接放寬防火牆 Policy 或修改預設 Profile，會導致安全防線破口且難以自動回收權限。
    2. *雲端分類誤判與自訂政策偏離（Misclassification & Custom Policy）*：FortiGuard 雲端資料庫可能將部分合法站點標記為未分類（Unrated）或誤判為惡意/賭博類別，亦或企業內部資安標準需要將特定常用站點（如搜尋引擎）強制重定義為高風險類別以加強管控。

### Methodology / Architecture（方法與架構設計）

FortiOS 提供了兩項功能維度互補的 Web Filter 進階客製化模組：

```
[Web Filter Security Profile 進階控制機制]
  │
  ├── Web Profile Override (主體與時效導向)
  │     └─► 來源: User / User Group / Source IP
  │     └─► 機制: 暫時替換套用的 Web Filter Profile（跳過阻擋頁與告警）
  │     └─► 生命週期: 具時限性 (Default: 15 mins，到期自動失效)
  │
  └── Web Rating Override (客體與分類導向)
        └─► 對象: 特定 FQDN / URL (如 example.com)
        └─► 機制: 本地優先覆寫 FortiGuard 雲端類別 (Local Classification)
        └─► 生命週期: 常駐生效 (直至管理員手動調整)

```

#### Web Profile Override（設定檔覆寫）

* **運作機制**：允許管理員在保留預設嚴格安全設定檔的同時，針對特定「來源主體」（使用者、使用者群組或來源 IP）授予限時的存取豁免權。
* **檢驗流程**：當符合條件的主體發起連線時，FortiGate 自動將其流量導向權限較為寬鬆的指定目標設定檔，不再顯示阻擋頁面（Block / Replacement Message），亦無需端點重複發起身分驗證。
* **身分驗證相依性**：若欲指定 User 或 User Group 作為覆寫作用域，所屬的 Firewall Policy 來源（Source）必須已綁定該 User Group；若底層 Policy 僅配置 IP/Subnet，則覆寫作用域僅能選擇 Source IP。



#### Web Rating Override（網站評級覆寫）

* **運作機制**：在 FortiGate 本地建立網址分類覆寫對照表，其優先級高於遠端 FortiGuard 雲端分類伺服器查詢結果。
* **本質特性**：作用範圍嚴格限制於「指定網址」，不變更原始類別中其他網站的定義與過濾動作，確保精確控管與最小衝擊。

### Key Findings / System Hierarchy（核心體系與階層）

兩項機制的本質差異、管控階層與參數規格比較如下：

| 評比維度 | Web Profile Override（設定檔覆寫） | Web Rating Override（網站評級覆寫） |
| --- | --- | --- |
| **管控本質** | **主體導向（Who / Where）**：改變特定對象所套用的安全規則集 | **客體導向（What / Destination）**：改變特定網站於系統中的安全分類標籤 |
| **作用範圍** | 特定 User、User Group 或 Source IP | 特定 FQDN、主機名稱或 URL 路徑 |
| **生命週期** | **具時效性**：支援天、小時、分鐘倒數（預設 15 分鐘，可指定到期時間 | **常駐性**：持續生效，除非管理員手動刪除或更新本機設定 |
| **使用者體驗** | 命中覆寫後直接放行，不顯示 Replacement Message，無感知繞過阻擋 | 依據該網站被重新劃分的「新類別」執行對應動作（Allow/Block/Warning） |
| **前置依賴條件** |防火牆 Policy 必須啟用身分驗證與對應 User Group<br>需預先定義目標替代 Profile|依賴 FortiGuard 評級機制架構<br>本地 FortiGate 具有本機資料庫解析權限 |
| **典型應用情境** | 臨時開放行銷/招募部門存取社交平台；工程師臨時維運存取遠端工具 | 修正企業求職網被誤判為賭博類別；將內部指定系統強制劃入自訂白名單 |

### Implications / Practical Insights（結論與實務意涵）

* **安全策略最小權限與生命週期管理**：
    * 面對臨時例外存取申請時，應嚴格禁止直接編輯正式 Firewall Policy 或修改既有 Production Profile。採用 **Web Profile Override** 可設定明確的 Expiry Time（如 15–60 分鐘），避免「暫時放行變成永久後門」的權限蔓延問題。
    * **誤判修正的最佳途徑**：
        * 當發現網站被錯誤分類（如商業網站標註為 Gambling 或 Unrated）時，採用 **Web Rating Override** 重新指定為正確類別（如 Education），是影響最小的做法，因為這不會影響該分類下其他數百萬個真正站點的判定邏輯。

* **分散式架構與維運限制**：
    * *本地生效邊界*：Web Rating Override 屬於設備本機（Local）設定，若企業具備多台 FortiGate 設備，需透過 FortiManager 集中推送或各節點同步建立，否則會出現跨分支機構過濾行為不一致的情況。
    * *身分識別策略連動*：在設計 AD/FSSO 整合架構時，若預期使用 Profile Override 進行精細化權限指派，須確保各網段的安全 Policy 皆具備完整的 User Group 綁定，避免後續僅剩 IP 覆寫可用而喪失人員溯源能力。

## Custom IPS Filters Lab

### Background / Objective（背景與核心目的）

* **核心情境與動機**：在企業邊界安全防禦體系中，FortiGate 的入侵防禦系統（IPS）包含數萬筆定期更新的攻擊特徵碼。若僅依賴手動挑選特定單一特徵碼（IPS Signatures），不僅難以因應日新月異的漏洞利用（Exploits），且在維運上極具管理負擔。
* **欲解決之核心問題 / 技術缺口**：探討如何利用「動態篩選器（IPS Filter）」架構，依據嚴重性（Severity）、目標類型（Target）、通訊協定（Protocol）或作業系統（OS）等維度動態彙整特徵碼並統一套用阻斷防禦，同時利用 Kali Linux 進行主動式滲透與掃描測試（如 nmap 探測），實證 IPS 引擎對異常流量的即時偵測、阻斷與日誌審計機制。


### Methodology / Architecture（方法與架構設計）

```
+-----------------------------------------------------------------------+
|                       內部網路 (Internal LAN Subnet)                   |
|   [Kali Linux 滲透主機] (IP: 10.0.1.4/24)                              |
|     - 執行工具: nmap -A, 漏洞掃描腳本                                 |
+-----------------------------------+-----------------------------------+
                                    | LAN (port2: 10.0.1.254/24)
                                    v
+-----------------------------------------------------------------------+
|                    FortiGate 防火牆 (FW-1: 192.168.100.200)           |
|                                                                       |
|  [Firewall Policy: LAN -> WAN] (Action: ACCEPT)                       |
|    ├── SSL/SSH Inspection: Custom Full Deep-Inspection                |
|    └── Security Profile: Intrusion Prevention (Profile: default)      |
|          └── Custom Filter (優先級: 頂層 Top-1, Action: Block)         |
+-----------------------------------+-----------------------------------+
                                    | WAN-1 (port1: 192.168.1.200/24)
                                    v
+-----------------------------------------------------------------------+
|                        外部網路 (WAN / Internet)                      |
|   [外部受測目標主機] (IP: 192.168.1.254/24)                           |
+-----------------------------------------------------------------------+
```

* **網路拓撲與驗證環境**：
    * **攻擊端主機**：位於內部 LAN 的 Kali Linux（IP: `10.0.1.4`）。
    * **受保護邊界與受測標的**：FortiGate Firewall 1（IP: `192.168.100.200`）配置安全防護策略，外連目標為 WAN 端網段主機（IP: `192.168.1.254`）。
    * **檢測相依性**：流量通過的防火牆 Policy 必須啟用 IPS Profile，並搭配客製化 SSL/TLS 深度檢測（Full Deep-Inspection），以確保加密連線內部之惡意酬載亦能被 IPS 引擎解析。


* **IPS Filter 配置流程與比對架構**：
    * **Filter 建立機制**：進入 `Security Profiles > Intrusion Prevention`，在預設或自訂 Profile 內新增項目，類型指定為 `Filter`（取代單筆 Signature 模式），動作設為 `Block`，並啟用封包日誌記錄（Packet Logging）。
    * **特徵過濾準則**：於 Filter 內部勾選嚴重性等級（Severity Levels，實驗設定為涵蓋全部等級），動態匹配符合該條件之所有已知攻擊特徵碼。
    * **優先權排序（Rule Ordering）**：IPS 規則係採由上而下（Top-Down）循序匹配。配置完成後將該 Filter 拖曳至規則清單最頂端，確保其優先於下方其他預設規則被命中執行。

```
[ 傳入連線請求 (Ingress Packet) ] (來源: 10.0.1.4 -> 目的: 192.168.1.254)
                │
                ▼
+-----------------------------------------------------------------------+
| 1. L3 / L4 狀態檢驗 (Stateful Firewall Policy Match)                  |
|    - 檢查 5-Tuple (Src IP, Dst IP, Protocol, Src Port, Dst Port)      |
|    - 命中規則 (Action = ACCEPT) ──(若為 DENY 則直接丟棄，不進入 UTM)   |
+-----------------------------------+-----------------------------------+
                                    │
                                    ▼
+-----------------------------------------------------------------------+
| 2. SSL / TLS 深度解密 (Full Deep-Inspection)                          |
|    - 拆解並解密加密傳輸 Payload，還原為明文酬載供 L7 安全引擎剖析     |
+-----------------------------------+-----------------------------------+
                                    │
                                    ▼
+-----------------------------------------------------------------------+
| 3. IPS 檢驗引擎 (IPS Engine / CP 晶片加速)                            |
|    - 採由上而下 (Top-Down) 循序比對規則階層:                          |
|                                                                       |
|    [ 頂層: Custom IPS Filter ] ◄────────────── [ 符合條件，優先命中！] |
|      ├── 條件定義: Severity = All (涵蓋 Scan、Nmap、DOS、High/Crit)  |
|      ├── 執行動作: Block (中斷 Session 並丟棄封包)                    |
|      └── 封包記錄: Packet Logging = Enabled (側錄觸發封包 Payload)    |
|                                                                       |
|    [ 底層: Default Predefined Signatures ]                            |
|      └── (封包已於頂層被攔截丟棄，不再向下進行比對)                   |
+-----------------------------------+-----------------------------------+
                                    │
                                    ▼
+-----------------------------------------------------------------------+
| 4. 決策執行與稽核日誌產生 (Action & Audit Logging)                    |
|    ├── 阻斷連線: Session 強制終止，連線重置 (TCP Reset / Drop)         |
|    ├── 安全事件: Log & Report > Security Events > IPS (記為 dropped)  |
|    └── 轉發日誌: Log & Report > Forward Traffic (記為 UTM Blocked)    |
+-----------------------------------------------------------------------+
```


* **驗證方式**：
    * 自 Kali Linux 終端以 Root 權限發動積極探測指令（`nmap -A 192.168.1.254`）及掃描腳本，模擬通訊埠掃描與應用程式弱點試探。

### Key Findings / System Hierarchy（核心體系與階層）

#### IPS 規則型態對比體系

| 比較維度 | IPS Signature（特徵碼指派） | IPS Filter（條件式篩選器） |
| --- | --- | --- |
| **定義維度** | 靜態、單一特定 CVE 或攻擊名稱（如特定 Apache 漏洞、EICAR 測試檔）| 動態屬性維度集合（Severity、Protocol、OS、Target、Application） |
| **維護彈性** | 低；FortiGuard 更新特徵時需手動審查並加入新特徵碼 | 高；當 FortiGuard 資料庫更新時，符合該 Filter 屬性的新特徵自動生效納管 |
| **適用場景** | 針對特定核心系統的關鍵漏洞防護，或作為 Filter 的例外放行/阻斷覆寫 | 建立全域基礎防禦基準（如封鎖所有 Critical/High 等級的伺服器端漏洞） |

#### 攻擊模擬與日誌驗證分析

經由 Kali Linux 發起掃描後，FortiGate 在兩層日誌架構中呈現完整防護軌跡：

* **安全事件日誌（Security Events > Intrusion Prevention）**：
    * 系統精準記錄攻擊來源為 `10.0.1.4`，攻擊名稱標識出 `nmap script scanner`、`Port Scanning` 及相關 HTTP 未授權存取特徵。
    * 執行動作顯示為 `dropped`，驗證封包在抵達目標伺服器前已被 IPS 引擎於底層丟棄。


* **轉發流量日誌（Forward Traffic Logs）**：
    * 原始連線會話之結果欄位顯示為 `Deny`，狀態明記為 `Deny: UTM Blocked`。
    * 展開詳細資訊可確認該 Session 係由 IPS 模組判讀為威脅而強制中斷，並附帶匹配的特徵名稱。


### Implications / Practical Insights（結論與實務意涵）

* **嚴重性等級設定與誤判權衡（Trade-offs）**：
    * 本次實驗為驗證完整攔截效果將 Severity 設為全選（All），此舉會包含大量 Information 與 Low 等級的偵測行為（如正常網管探測、掃描工具簽章）。
    * **生產環境部署準則**：企業現網環境應優先將 Filter 鎖定在 `Critical` 與 `High` 等級且動作設為 `Block`；對於 `Medium` 與 `Low` 則建議先設為 `Monitor` 或 `Default`，避免因誤判（False Positives）導致合法應用程式或弱點掃描工具中斷業務。

* **階層式規則排序（Top-Down Precedence）重要性**：
    * 若網路中存在特定的合法維運掃描器或內部測試需求，應在全域 Filter **上方**建立精確的單一 Signature 或針對特定 IP 豁免（Exempt IPs），動作指定為 `Pass` 或 `Monitor`，否則流量將直接被頂層的廣義 Filter 攔截。

* **資源負載與封包記錄監控**：
    * 啟用 `Packet Logging` 會消耗額外的記憶體與 CPU 運算資源以保留封包 Payload。在現網環境中，僅建議對高風險伺服器或特定調查期間啟用封包側錄，非必要時應關閉以維持硬體轉發效能。