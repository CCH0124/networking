# Authentication

## Auentication 

### Background / Objective（背景與核心目的）

* **核心情境與動機**：傳統網路防火牆政策主要依賴 Layer 3 與 Layer 4 資訊（來源/目的 IP 位址、傳輸埠與協定）進行存取控制。然而，現代企業網路普遍面臨動態主機配置（DHCP）、NAT 轉譯、遠端 VPN 接入與自攜設備（BYOD）的普及，單純依賴 IP 位址已無法準確代表實際存取者的真實身分，容易導致安全政策被輕易繞過或溯源困難。
* **欲解決之核心問題 / 技術缺口**：
    * **身分驗證與授權之本質界定**：身分驗證（Authentication）僅在於「確認主體是否如其所聲稱的身分（Confirming Identity）」，本身不決定存取權限；權限劃分則交由防火牆 Policy 授權（Authorization）判定。
    * **從 IP-Based 到 User-ID 的演進**：下一代防火牆（NGFW）引進使用者識別（User-ID）機制，解決傳統防火牆無法跨越 IP 辨識應用程式使用者的盲區，構建以「應用程式（Applications）、使用者（Users）、內容（Content）」為核心的三大安全防禦支柱。

### Methodology / Architecture（方法與架構設計）

在 FortiOS 7.4.12 架構中，防火牆身分驗證可分為主動式驗證（Active Authentication）**與**被動式驗證（Passive Authentication）兩大路徑，並透過安全策略（Firewall Policy）綁定使用者與群組進行動態連線授權：

```text
               [ 終端使用者 / 設備連線請求 ]
                            │
                            ▼
     +─────────────────────────────────────────────+
     │       FortiGate 識別與驗證機制 (Identity)      │
     +──────────────────────┬──────────────────────+
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
    【主動式驗證 (Active)】          【被動式驗證 (Passive)】
    • 網頁強制轉向 (Captive Portal) • 網域登入監聽 (FSSO / AD Event)
    • 憑證輸入 (Form / Basic / NTLM)• 802.1X / RADIUS Accounting
    • 傳輸加密 (HTTPS Redirect)     • 無感知透明繫結 (IP <-> User)
            │                               │
            └───────────────┬───────────────┘
                            ▼
    +──────────────────────────────────────────────+
    │     User-ID 會話狀態表 (WAD / Auth Engine)    │
    │     • 映射表項: IP <-> User Name <-> User Group │
    │     • 計時器: 閒置逾時 (Idle Timeout, 預設 5 分鐘)│
    +──────────────────────┬───────────────────────+
                            │
                            ▼
    +──────────────────────────────────────────────+
    │     次世代防火牆政策比對 (NGFW Policy Match)   │
    │     • 來源條件: Source IP + [User / Group]   │
    │     • 內容檢測: App Control + IPS + Web Filter│
    +──────────────────────┬───────────────────────+
                            ▼
               [ 放行並記錄詳細稽核日誌 (Logs) ]

```

#### 核心驗證與逾時機制

* **認證生命週期管理**：使用者通過驗證後，FortiGate 會在認證引擎（如 WAD/Auth Table）中建立暫存的「IP 與使用者/群組」對應表記錄。
* **閒置逾時（Idle Timeout）**：當連線保持閒置無任何流量傳輸達 **5 分鐘（預設值）**，該使用者的認證會話即自動失效過期，後續流量須重新觸發認證或更新狀態，防止終端離線後 IP 遭他人冒用。
* **資料庫整合（User Repositories）**：原生支援本地使用者資料庫（Local User DB）、遠端 LDAP、Active Directory、RADIUS 以及 SAML 2.0 識別提供者（IdP）整合。


### Key Findings / System Hierarchy（核心體系與階層）

User-ID 在次世代防火牆中實現了 7 大核心體系維度，大幅強化安全縱深：

```text
                   ┌── [1. User Identification] ──── 跨越 IP 限制，精準辨識背後人員
                   ├── [2. Application Recognition] 識別各使用者正在執行的特定應用
                   ├── [3. Precise Policies] ─────── 依據 User/Group 與 App 制定精細策略
【User-ID 核心維度】├── [4. Threat Monitoring] ───── 鎖定具體帳號的潛在安全威脅與異常
                   ├── [5. User Activity Tracking] ─ 全網追蹤單一使用者的行為軌跡
                   ├── [6. Detailed Reporting] ───── 產出以人員/群組為維度的鑑識報告
                   └── [7. User Repositories] ────── 無縫介接各類企業身分庫 (AD/LDAP)

```

| 核心維度 (Core Pillar) | 技術特性與功能描述 |
| --- | --- |
| 1. User Identification<br>（使用者身分識別） | 超越純 IP 限制，將網路流量與帳號名稱、角色明確綁定，消除共用 IP 或動態 IP 帶來的模糊盲點。 |
| 2. Application Recognition<br>（應用程式關聯識別） | 結合 DPI 與 L7 簽章，明確解析特定使用者正在存取哪些應用程式（例如識別是誰在存取雲端儲存或影音服務）。 |
| 3. Precise Policies<br>（精細化存取策略） | 策略規則得以「來源 IP + 使用者群組 + 應用程式」同時作為比對條件，落實部門級最小權限控管。 |
| 4. Threat Monitoring<br>（威脅行為監控） | 當 IPS 或防毒引擎觸發告警時，可直接精確定位遭感染或發動攻擊的具體帳號，加速事件應變。 |
| 5. User Activity Tracking<br>（跨網活動軌跡追蹤） | 即時追蹤並關聯使用者在內部網路、跨網段至網際網路的完整存取時序與軌跡。 |
| 6. Detailed Reporting<br>（鑑識與合規報表） | 提供以使用者及群組為單位的流量分析報告，支援資安法規稽核與內部資安事故鑑識。 |
| 7. User Repositories<br>（外部身分庫整合） | 彈性銜接 Active Directory、LDAP、RADIUS 等集中管理庫，維運人員無需在防火牆重複建立帳號。 |

### Implications / Practical Insights（結論與實務意涵）

* **安全策略維運的最佳實踐（Zero Trust 演進）**：
    * **擺脫 IP 僵化配置**：在大量使用 DHCP 或動態無線網路的環境中，嚴禁僅以 IP 位址作為權限劃分基準。應全面於防火牆 Policy 的 `Source` 欄位加入 `User` 或 `User Group`，實現跟隨人員身分移動的安全邊界。

* **驗證模式架構選擇（Active vs. Passive）**：
    * **內網辦公區推薦 FSSO（被動驗證）**：透過監聽 Windows AD 網域登入事件或安裝 FSSO Agent，使用者登入電腦即可自動完成防火牆身分繫結，無須跳出 Captive Portal 認證頁面，兼顧安全性與使用者體驗。
    * **訪客與非網域主機採 Captive Portal（主動驗證）**：對未加入網域的設備，強制透過 HTTPS 重導向進行網頁身分驗證，並確保連線配置深層檢測與安全憑證。

* **逾時參數與效能權衡（Timeout Tuning）**：
    * 預設的 5 分鐘閒置逾時（Idle Timeout）適合一般終端存取；若過長可能導致公用電腦被下一位使用者沿用權限，若過短則可能頻繁中斷長連線應用。在生產環境中應依據辦公型態（如專屬主機或共享終端）進行彈性調優。