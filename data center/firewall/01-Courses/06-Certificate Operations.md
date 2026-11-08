# Certificate Operations

## Introduction to Security Profiles

### Background / Objective（背景與核心目的）

* **核心角色與本質差異**：在 FortiGate 防火牆架構中，**安全策略（Firewall Policy）** 負責控制網路邊界的「存取授權（Access Control）」，決定哪些連線被允cceptCEPT`）或阻enyDENY`）。而 **安全性設定檔（Security Profiles，即 UTM 防護模組）** 則負責對已經放行的流量實施「**應用層內容過濾與威脅掃描（Content-Level Inspection）**」。

* **欲解決之核心問題**：
    1. 避免傳統防火牆僅檢查 L3/L4 標頭（IP、Port）所產生的盲點，深入封包 Payload 辨識病毒（Antivirus）、惡意網址（Web Filter）、入侵攻擊（IPS）及未授權應用（Application Control）。

    2. 確立處理邏輯與資源優化：確立 **「先判定 Policy Action，再執行 Profile 深度掃描」** 的管線機制，避免對已被阻斷的流量進行無效的內容檢驗。

### Methodology & Architecture（處理管線與決策流程圖）

當網路封包通過 FortiGate 時，底層封包處理引擎會歷經兩階段過濾：

```
                    【連入網路封包 (Incoming Packet)】
                                   │
                                   ▼
             [階段 1：Firewall Policy 存取控制比對 (L3/L4)]
                                   │
                                   ▼
                       ＜策略動作 Action 為何？＞
                                   │
                 ┌─────────────────┴─────────────────┐
                 │ DENY                              │ ACCEPT[cite: 61]
                 ▼                                   ▼
         【封包即刻阻斷丟棄】                 【放行封包進入 UTM 管線】
                 │                                   │
       [無須掛載 Security Profile]           [掛載 Security Profiles 檢查模組][cite: 61]
       (已阻斷流量無須額外掃描)[cite: 61]                 │
                                                     ▼
                                      [階段 2：L7 內容層級安全掃描][cite: 61]
                                       ├── 1. Antivirus (病毒/惡意軟體掃描)[cite: 61]
                                       ├── 2. Web Filter (惡意 URL/網頁分類過濾)[cite: 61]
                                       ├── 3. DNS Filter (惡意網域查詢阻斷)
                                       ├── 4. Application Control (應用程式特徵識別)
                                       ├── 5. IPS (漏洞利用/入侵防禦檢測)[cite: 61]
                                       └── 6. File Filter / DLP (機密檔案外洩防護)
                                                     │
                                   ┌─────────────────┴─────────────────┐
                                   ▼                                   ▼
                           【發現威脅 / 違規 Payload】           【內容安全無虞】
                                   │                                   │
                         阻斷連線 (TCP RST / Drop)[cite: 52]        封包改寫轉發至目的地
                         寫入 Threat Log / Security Event[cite: 59, 61]

```

#### 核心處理步驟拆解（6 大防護管線節點）

1. **Packet Allowed by Policy**：封包必須先完整滿足防火牆策略的來源、目的、服務等條件，且動作被判定為 `ACCEPT`。
2. **Security Profile Applied**：防火牆依據策略內勾選的 Profile 物件，將資料流導流至對應的檢測引擎。
3. **Threat Scanning**：執行特徵碼比對，偵測軟體漏洞利用程式（Exploits）、間諜軟體與惡意程式。
4. **Malicious URL Detection**：比對 FortiGuard 雲端資料庫，即時攔截釣魚網站與已知威脅連結。
5. **Suspicious File Analysis**：分析檔案上傳與下載內容，識別未知可疑附檔。
6. **Threat Log Maintenance**：當觸發安全事件時，由系統寫入專屬的 Threat Log 並推送至 Log & Report / FortiAnalyzer。


### Key Findings & 設定體系剖析（模組分類、日誌與檢查模式）

#### 核心 Security Profile 功能分類與適用情境

| 安全設定檔 (Profile) | 檢查層級 | 核心功能與保護標的 | 典型預設範本 (Predefined Templates) |
| --- | --- | --- | --- |
| **Antivirus** | L7 | 阻斷病毒、木馬、蠕蟲、勒索軟體與惡意下載。 | `default`、`wifi-default` |
| **Web Filter** | L7 | 限制存取高風險分類網頁、阻斷惡意 URL、強迫啟用 SafeSearch。 | `default`、`monitor-all` |
| **DNS Filter** | L7 | 攔截惡意網域名稱解析、防止 Command & Control (C2) 殭屍網路回連。 | `default` |
| **Application Control** | L7 | 深入 Payload 識別特定應用程式（如 P2P、遊戲、社群網路、穿牆翻牆工具）。 | `default` |
| **Intrusion Prevention (IPS)** | L4~L7 | 阻斷網路入侵攻擊、防止已知 CVE 軟體漏洞利用（Exploits）。 | `default`、`client`、`server`、`high_security` |
| **File Filter** | L7 | 依據真實檔案類型（Magic Number，非僅看附檔名）限制特定檔案傳輸。 | `default` |

#### 多情境專業設定檔（Set of Profiles）

在大型架構中，針對不同業務流量應套用特定最佳化 Profile 物件以維持效能：

* **Web 伺服器策略（HTTP Server）**：IPS 應選用針對 Web 漏洞優化的 `server` 範本，防範 SQL Injection、XSS 等攻擊。
* **郵件伺服器策略（Email Server）**：IPS 應選用聚焦 SMTP/IMAP/POP3 協定的保護範本，並搭配 Anti-Spam / Email Filter。
* **員工終端上網（Client/Workstation）**：應掛載 `client` 範本，防範惡意下載、瀏覽器 Exploit 與勒索軟體回連。

#### SSL Inspection 與 Inspection Mode 的強烈依賴性

1. **SSL 深度解密必要性（`ssl-ssh-profile`）**：
    * 現今 90% 以上網路流量皆經 HTTPS 加密。若安全策略僅採用預設的 `certificate-inspection`，防火牆只能讀取 SNI/網域名稱，**無法解密 HTTPS 內容**。
    * 若要讓 Antivirus、DLP 或深度 IPS 在 HTTPS 流量中生效，安全策略必須將 SSL Inspection 升級為 **`deep-inspection`（完整 SSL 代理與解密）**。

2. **Inspection Mode（檢查模式）差異約束**：
    * **Flow-based**：提供線速的高吞吐量與低延遲，適用多數辦公室外向流量。
    * **Proxy-based**：提供完整的記憶體緩衝重組能力。若需使用 **Video Filter**、**DLP** 或客製化網頁阻斷警告頁面，該策略必須將檢查模式調整為 `proxy`。

#### 日誌記錄關聯（Log Allowed Traffic）

在安全策略啟用 Security Profile 後，必須正確設定日誌選項：

* **`set logtraffic utm`（Security Events）**：平常建議選項，防火牆僅在觸發 Security Profile 的安全事件時才寫入日誌，有效節省 CPU 與儲存資源。
* **`set logtraffic all`（All Sessions）**：完整記錄所有連線的建立與關閉，並可在 **Log & Report > Security Events** 下依 Antivirus、Web Filter、IPS 分類檢視攻擊詳情。



#### FortiOS 7.4.12 官方 CLI 配置範例

```fortios
# 步驟 1：客製化建立一個 Antivirus Profile
config antivirus profile
    edit "Corp_AV_Profile"
        set comment "Scan HTTP, FTP, and SMB traffic"
        config http
            set options scan
        end
    next
end

# 步驟 2：在 Firewall Policy (Action=ACCEPT) 中掛載多個 Security Profiles
config firewall policy
    edit 10
        set name "LAN_to_WAN_Protected"
        set srcintf "port3"                     # 內部 LAN 介面
        set dstintf "port1"                     # 外部 WAN 介面
        set action accept                       # 必須為 accept 才能啟用 UTM
        set srcaddr "all"
        set dstaddr "all"
        set schedule "always"
        set service "ALL"
        set nat enable
        
        # --- 掛載 Security Profiles (UTM 模組) ---
        set utm-status enable                   # 啟用安全設定檔功能
        set ssl-ssh-profile "certificate-inspection"
        set av-profile "Corp_AV_Profile"        # 掛載自訂防毒 Profile
        set webfilter-profile "default"         # 掛載網頁過濾 Profile
        set ips-sensor "default"                # 掛載入侵防禦 Profile
        set application-list "default"          # 掛載應用程式控管 Profile
        
        # --- 日誌記錄 ---
        set logtraffic utm                      # 僅記錄資安事件 (節省儲存空間)
    next
end

```

### Implications & Practical Engineering Insights（實務意涵與設計要點）

1. **職責解耦：Policy（控制流）vs. Profile（內容流）**：
    * **Firewall Policy** 像門禁警衛，依據證件與目的地（IP、Port、Schedule）決定「能不能進門」。
    * **Security Profile** 像安檢 X 光機，對已經進門的人「檢查行李內是否有危險品」。
    * 模組化設計讓管理員可以「一次定義多種 Profile，並跨多條 Policy 重複引用」，無須在每條策略中重複設定相同的資安參數。

2. **Deny 策略的介面行為驗證**：
    * 當政策動作改為 `DENY` 時，Web GUI 會自動將下方所有 Security Profile 勾選項目隱藏，CLI 也會略過這些屬性。因為連線在階段 1 已被阻斷，底層若再進行 L7 深度掃描只會浪費系統運算資源。

3. **記憶體防護與硬體平台限制（Conserve Mode 注意事項）**：
    * 依據 FortiOS 7.4.12 規範，在記憶體小於等於 2 GB 的小型機型（可透過 `diagnose hardware sysinfo conserve` 確認），部分進階 Proxy-only Profile（如 Video Filter、ICAP、WAF）不再支援，策略應全面採用 Flow-based 模式以防止設備進入系統保留模式（Conserve Mode）。

## Introduction to SSL Inspection

### Background / Objective（背景與核心目的）

* **加密流量盲區**：在現代網路中，超過 90% 的流量（如 HTTPS、TLS、SSL）皆處於加密狀態。若防火牆僅維持透傳，端到端加密通道（End-to-End Tunnel）會使次世代防火牆（NGFW）的 Antivirus、Web Filter、IPS 及 DLP 等安全模組失去作用，使惡意程式與威脅有機可乘。

* **核心目的**：
    1. 藉由 **SSL/TLS 檢測（SSL Inspection / Decryption）** 拆解加密通道，讓安全引擎能深入分析封包內容並還原掃描，確保傳輸無惡意程式後再重新加密轉發。

    2. 區分 **Outbound（出向 / Forward Proxy）** 與 **Inbound（入向 / Reverse Proxy / SSL Offloading）** 兩種截然不同的證書信任體系與架構模式。

### Methodology & Architecture（兩大檢測架構運作流程）

#### 模式一：Outbound HTTPS Inspection（正向代理 / 企業內網出向保護）

保護企業內部用戶在瀏覽外部 Internet 時，防止惡意軟體藉由 HTTPS 下載至內網。FortiGate 在此扮演 **中間人代理（Man-in-the-Middle, MitM）** 角色：

```
[內部客戶端 Client]               [FortiGate (MitM Proxy)]              [外部目標伺服器 Server]
       │                                     │                                    │
       │──(1) Client HELLO (TLS Request)────>│                                    │
       │                                     │──(2) Firewall Client HELLO────────>│
       │                                     │                                    │
       │                                     │<─(3) Server HELLO + Server Cert────│
       │                                     │                                    │
       │                                     │──[4. 驗證證書 (Validation)]        │
       │                                     │  [5. 動態簽發新證書 (Dynamic Cert)]│
       │                                     │                                    │
       │<─(6) Server HELLO + Dynamic Cert────│                                    │
       │                                     │                                    │
  [建立通道 1: Client <-> FGT]                 │       [建立通道 2: FGT <-> Server] │
       │                                     │                                    │
       │<======== 加密資料 (通道 1) ========>│<======== 加密資料 (通道 2) =======>│
                                             │
                                    [明文解密檢測 (Decrypted)]
                                    • Antivirus / IPS / Web Filter
                                    • 重新加密後分別向兩端送出

```

**Outbound 握手流程詳解**：

1. **連線發起**：客戶端發送 `Client HELLO` 發起 TLS 請求。
2. **代理轉發**：FortiGate 攔截該請求，並代表客戶端向外部伺服器發起握手。
3. **驗證遠端**：外部伺服器回傳 `Server HELLO` 與真實伺服器證書（例如 DigiCert / GlobalSign 簽發）。
4. **驗證與動態簽發**：FortiGate 驗證外部證書合法性後，以機內的 **CA 根證書（Root CA / Forward Trust CA）** 動態產生一張主體名稱相同、公私鑰由 FortiGate 自主生成的動態憑證（Dynamic Certificate）。
5. **回應用戶**：FortiGate 將此動態憑證發送給客戶端。
6. **建立雙通道**：形成「Client ↔ FortiGate」與「FortiGate ↔ Server」兩條獨立的 TLS 通道，FortiGate 於中間進行明文解密與深度威脅檢查。


#### 模式二：Inbound HTTPS Inspection（反向代理 / DMZ 伺服器發布防護）

保護企業內部伺服器（如資料中心、DMZ 網站伺服器）免受來自外部網際網路的駭客攻擊。

```
[外部網際網路 Client]                 [FortiGate (Reverse Proxy)]               [內部伺服器 Server]
       │                                     │                                    │
       │──(1) Client HELLO (存取公網 IP)────>│                                    │
       │                                     │                                    │
       │<─(2) Server HELLO + Server Cert.────│                                    │
       │   (使用機內預先匯入的 Server 憑證)    │                                    │
       │                                     │                                    │
  [建立外部通道: Client <-> FGT]              │                                    │
       │                                     │                                    │
       │                                     │──(3) Client HELLO─────────────────>│
       │                                     │                                    │
       │                                     │<─(4) Server HELLO + Server Cert────│
       │                                     │                                    │
       │                                     │    [建立內部通道: FGT <-> Server]  │
       │                                     │                                    │
       │<======== 加密資料 (外部) ==========>│<========= 加密資料 (內部) =========>│
                                             │
                                    [明文解密檢測 (Decrypted)]
                                    • 防禦 SQLi / XSS / WAF 模組

```

**Inbound 流程特點**：

    * **憑證預先載入**：企業必須將伺服器的 **真實 SSL 證書與私鑰（Server Certificate & Private Key）** 匯入到 FortiGate 中。
    * **無須派送 CA 給外部用戶**：外部客戶端瀏覽器連線時，直接取得其信任的公開 CA 簽發證書（如 Let's Encrypt、DigiCert），瀏覽器不會出現任何告警。
    * **後端架構彈性**：FortiGate 對連入流量解密完成安全掃描後，可選擇向後端伺服器建立二次加密通道，或直接以 HTTP 明文轉發（SSL Offloading 負載均衡模式）。


### Key Findings & 憑證信任體系剖析（核心概念與常見問題）

#### 為什麼瀏覽器會跳出「不安全 / 憑證錯誤」？

* **根本原因**：在 Outbound 深度解密時，FortiGate 動態簽發的憑證是由 FortiGate 內部的 **自簽根憑證（如 `Fortinet_CA_SSL`）** 所簽署。


* **解決方案**：
    * 終端使用者的作業系統或瀏覽器（Windows Cert Store、macOS Keychain、Firefox 等）必須事先匯入並信任 FortiGate 的 CA 根憑證。
    * 企業環境實務上透過 **Active Directory 網域群組原則（GPO）**、MDM 工具（Intune、JAMF）將 FortiGate CA 自動派送至所有員工電腦的「受信任的根憑證授權單位（Trusted Root Certification Authorities）」。


#### FortiOS 兩大 SSL 檢測設定檔對照

| 檢測模式 (Profile) | 運作機制 | 深度掃描能力 | 終端需否安裝 CA 憑證？ |
| --- | --- | --- | --- |
| **Certificate Inspection**<br>（預設憑證檢測） | 僅讀取 TLS 握手階段的 **SNI（Server Name Indication）** 與主機名稱，不解密 Payload。 | 僅支援 URL 分類過濾，**無法進行 Antivirus、DLP 與深度 IPS 掃描**。 | ❌ 不需要 |
| **Deep Inspection**<br>（SSL 深度檢測） | 充當中間人（MitM），完整解密 HTTP 請求與回應資料流。 | **完全解密**，支援 Antivirus 惡意檔案分析、DLP 敏感資料過濾、Web 關鍵字偵測。 | **必須安裝並信任 FortiGate CA** |

#### FortiOS 7.4.12 CLI 配置語法

```fortios
# 1. 配置 Outbound SSL Deep-Inspection 設定檔
config firewall ssl-ssh-profile
    edit "custom-deep-inspection"
        config https
            set ports 443
            set status deep-inspection        # 啟用深度解密
        end
        config ftps
            set status deep-inspection
        end
        # 指定用於簽署動態憑證的內部 CA 憑證
        set caname "Fortinet_CA_SSL"
        
        # 豁免免檢測類別 (例如銀行金融、個人隱私網站依資安法規需排除)
        config ssl-exempt
            edit 1
                set fortiguard-category 31    # Finance and Banking 分類
            next
            edit 2
                set fortiguard-category 33    # Health and Medicine 分類
            next
        end
    next
end

# 2. 於安全策略中套用該 Deep-Inspection 設定檔
config firewall policy
    edit 10
        set name "LAN_to_WAN_DeepInspection"
        set srcintf "port3"
        set dstintf "port1"
        set action accept
        set srcaddr "all"
        set dstaddr "all"
        set schedule "always"
        set service "ALL"
        set nat enable
        
        # --- 掛載 SSL 深度解密設定檔與 UTM ---
        set utm-status enable
        set ssl-ssh-profile "custom-deep-inspection"
        set av-profile "default"
        set webfilter-profile "default"
    next
end

```

### Implications & Practical Engineering Insights（實務意涵與維運最佳實務）

1. **隱私與合規豁免原則（SSL Exemptions）**：
    * 進行 Outbound 深度解密時，若解密員工的網銀轉帳、薪資或醫療就診紀錄，將違反個人資料保護法及隱私法規。
    * **實務標準**：必須在 SSL Profile 內針對 **Finance and Banking（金融機構）**、**Health and Medicine（醫療與健保）** 等 FortiGuard 類別設定 **Exempt（略過檢測）**，僅對該類別執行 SNI 驗證而不進行內容解密。

2. **憑證綁定（Certificate Pinning）衝突解決**：
    * 部分應用程式（如 Zoom、Microsoft 365 專用客戶端、Dropbox 等）採用 Certificate Pinning 技術，拒絕任何非官方公鑰簽發的動態憑證，會直接中斷連線。
    * **維運方式**：在 `ssl-ssh-profile` 內將這類特殊應用的 FQDN / Wildcard 網址加入白名單排除解密。

3. **硬體處理能力考量（Hardware Offloading）**：
    * 完整 SSL 深度解密需要密集進行非對稱 RSA / ECC 金鑰協商與對稱 AES 加解密運算，會大幅拉高設備負擔。
    * 規劃大型環境時，應確認 FortiGate 機型具備專用的內容處理器（CP9 / SPU 晶片加速），以確保在啟用大規模 Deep Inspection 時維持線速轉發。

## SSL Inspection Modes

### Background / Objective（背景與核心目的）

* **核心挑戰**：現今網際網路絕大多數流量（如 HTTPS、FTPS、SMTPS 等）皆採用 SSL/TLS 協定加密傳輸。端到端加密雖然保障了資料傳輸隱私，卻也使得惡意軟體、勒索病毒、C2 殭屍網路回連以及資料外洩行為得以隱匿於加密封包中，直接穿透傳統防火牆查機制。


* **欲解決之核心問題**：FortiGate 透過 **SSL Inspection** 機制拆解傳輸層安全性協定，依據資安合規、效能負擔與防護深度需求，提供兩種主要檢測模式：
    1. **Certificate Inspection（憑證檢測模式）**：僅解析憑證中繼資料（Metadata），不解密封包內文。
    2. **Full SSL / Deep Inspection（完整深度檢測模式）**：扮演中間人代理（MitM），完整解密並掃描封包內容（Payload），重建端到端防禦。

### Methodology & Architecture（兩大模式架構與運作機制）

```
========================================================================================
                      FortiGate SSL/TLS Inspection 運作架構對比
========================================================================================

【模式一：Certificate Inspection（僅讀取握手中繼資料，不解密 Payload）】

  [Client] <──────────────── (端到端加密通道，未解密) ────────────────> [Web Server]
      │                                                                      │
      └───────────> [FortiGate 僅截獲 TLS Handshake 封包] <────────────────┘
                                      │
                         [讀取 SNI / 伺服器憑證資訊]
                         • 網域名稱 (CN / SAN)
                         • 簽發單位 (Issuer) 與 效期[cite: 70]
                                      │
                   ┌──────────────────┴──────────────────┐
                   ▼                                     ▼
           【符合 Web Filter 阻斷類別】           【憑證合法且允許連線】
           阻斷連線 (TCP RST / Drop)[cite: 52]        原封包維持加密透傳 (不解密內文)[cite: 70]
           (例如阻斷 facebook.com)                 (無法掃描內含之病毒與木馬)[cite: 70]


----------------------------------------------------------------------------------------

【模式二：Full SSL / Deep Inspection（Man-in-the-Middle 中間人雙通道代理）】

  [Client]                               [FortiGate (MitM Proxy)]                          [Web Server]
      │                                             │                                           │
      │──── (1) Client HELLO ──────────────────────>│                                           │
      │                                             │──── (2) Firewall Client HELLO ───────────>│
      │                                             │                                           │
      │                                             │<─── (3) Server HELLO + 伺服器憑證 ────────│
      │                                             │                                           │
      │                                             │──── [4. 驗證伺服器憑證合法性]            │
      │                                             │──── [5. 機內 CA 動態簽發新憑證][cite: 62, 71]│
      │                                             │                                           │
      │<─── (6) Server HELLO + FortiGate 動態憑證 ──│                                           │
      │                                             │                                           │
  【通道 1: Client <-> FortiGate】                  │                    【通道 2: FortiGate <-> Server】
  (以終端信任之 FortiGate CA 加密)[cite: 71]        │                    (以遠端網站合法憑證加密)
      │                                             │                                           │
      │<========== 加密傳輸資料流 =================>│<========== 加密傳輸資料流 ================>│
                                                    │
                                      【明文還原與深度安全掃描】
                                      • Antivirus (檔案串流/壓縮解密掃描)[cite: 61, 71]
                                      • IPS (深度攻擊特徵碼比對)[cite: 61, 71]
                                      • DLP (機密資料洩漏過濾)[cite: 61, 71]
                                      • Web Filter (完整 URL/路徑/搜尋引擎過濾)[cite: 71]

```


### Key Findings & 機制對比剖析（核心發現與對照表）

#### Certificate Inspection vs. Full SSL Inspection 核心特性矩陣

| 比較特性 | Certificate Inspection（憑證檢測） | Full SSL Inspection（深度檢測） |
| --- | --- | --- |
| **TLS 握手截獲** | **是**（僅讀取 Client/Server Hello 階段） | **是**（完整攔截並分割為雙向代理 Session） |
| **SSL 明文解密** | ❌ **否**（Payload 維持全加密透傳） | **是**（解開 TLS 加密層，還原 HTTP/L7 明文） |
| **內容層級檢查** | ❌ **否**（完全無法掃描檔案 Payload） | **是**（全面支援 AV、IPS、DLP 等模組檢測） |
| **系統資源耗損** | **極低**（僅解析標頭，CPU/記憶體消耗小） | ⚠️ **高**（需大量非對稱金鑰與對稱加解密運算） |
| **終端憑證需求** | ❌ **不需要**（用戶端無感，無憑證告警） | ⚠️ **必須派送並信任 FortiGate CA 根憑證** |
| **SSL Pinning 影響** | **完全無影響**（憑證是由原始網站簽署） | ⚠️ **可能破壞** 綁定公鑰之 App（如銀行、金融客戶端） |
| **隱私法規衝擊** | **極低**（無法窺探使用者帳密與對話內文） | ⚠️ **高**（可還原明文資料，需配置合規豁免） |
| **Web Filter 能力** | **僅限網域名稱**（基於 SNI / CN / SAN 分類） | **完整 URL 路徑檢測**（支援子目錄、特定檔案後綴與關鍵字） |
| **適用場景** | 訪客 Wi-Fi、法規限制不可解密網段、硬體資源受限設備。 | 企業內部員工電腦、高安全防禦出口、資料外洩防護（DLP）要求環境。 |

#### 終端憑證錯誤（Untrusted Certificate Warning）根本原因與排解

當啟用 Full SSL Inspection 後，若用戶瀏覽網頁出現憑證無效或不安全警告：

1. **根本原因**：外部網站的真實憑證已被 FortiGate 攔截，用戶端收到的是由 FortiGate 機內 CA（如 `Fortinet_CA_SSL`）動態自簽的新憑證。因瀏覽器預設信任清單中未包含該 CA，遂判定為潛在的中間人攻擊。

2. **標準排解流程**：
    * 至 **System > Certificates** 下載 FortiGate 簽發用之 CA 憑證（`.crt` 或 `.cer` 檔案）。
    * 將該憑證匯入至用戶端作業系統（Windows / macOS）的「受信任的根憑證授權單位（Trusted Root Certification Authorities）」儲存庫中。
    * 企業網管環境應透過 **Active Directory 網域群組原則（GPO）** 或 MDM（Intune、JAMF）集中推送安裝。

#### FortiOS 7.4.12 CLI 配置範例

```fortios
# 1. 配置 Full SSL Deep-Inspection 設定檔 (含金融與醫療豁免)
config firewall ssl-ssh-profile
    edit "custom-deep-inspection"
        config https
            set ports 443
            set status deep-inspection            # 啟用深度解密
        end
        config ftps
            set status deep-inspection
        end
        # 指定動態簽署憑證的本機 CA
        set caname "Fortinet_CA_SSL"
        
        # 規避法規與隱私風險：設定豁免類別 (Exemptions)
        config ssl-exempt
            edit 1
                set fortiguard-category 31        # Finance and Banking (金融機構豁免)
            next
            edit 2
                set fortiguard-category 33        # Health and Medicine (醫療個人隱私豁免)
            next
        end
    next
end

# 2. 於安全策略中套用設定檔
config firewall policy
    edit 10
        set name "LAN_to_WAN_DeepInspection"
        set srcintf "port3"
        set dstintf "port1"
        set action accept
        set srcaddr "all"
        set dstaddr "all"
        set schedule "always"
        set service "ALL"
        set nat enable
        
        # --- 掛載 SSL 深度解密與防毒/IPS 模組 ---
        set utm-status enable
        set ssl-ssh-profile "custom-deep-inspection"
        set av-profile "default"                  # 流量已解密，AV 能深度掃描惡意下載
        set ips-sensor "default"
        set logtraffic utm
    next
end

```

### Implications & Practical Engineering Insights（實務意涵與維運最佳實務）

1. **資安掃描模組的「解密依賴性」**：
    * 在 `certificate-inspection` 模式下，即便策略中勾選了 Antivirus 或 IPS，若惡意檔案是透過 HTTPS 協定下載，FortiGate 因未解密 Payload，**惡意檔案將直接穿越防火牆而無法被阻斷**。
    * 只有在切換為 `deep-inspection` 後，AV / IPS 引擎才能對解密還原後的資料流執行特徵碼比對，成功攔截威脅並記錄 Threat Log。

2. **網頁分類過濾（Web Filter）的精度差異**：
    * `Certificate Inspection` 僅能讀取憑證主體名稱（如 `facebook.com`），能達到網域層級的直接阻斷；但**無法識別子路徑**（例如允許瀏覽主站，但阻斷特定子網址 `[example.com/malicious/path](https://example.com/malicious/path)`）。
    * `Full SSL Inspection` 可完整還原 HTTP GET 請求路徑與標頭，支援細粒度的路徑過濾、關鍵字屏蔽與搜尋引擎 SafeSearch 強制重寫。

3. **憑證綁定（Certificate Pinning）與應用白名單**：
    * 包含銀行專用 App、行動支付、特定雲端辦公用戶端（如 Dropbox、Microsoft 365 特定服務）因內部寫死伺服器公鑰，遭遇 FortiGate 代理簽發之憑證時會直接拒絕連線。 
    * **實務建議**：在維運大型企業網路時，應善用 `ssl-ssh-profile` 中的 `ssl-exempt`，將已知的特殊 FQDN 或應用特徵加入免解密白名單，兼顧網路正常運作與邊界防護。