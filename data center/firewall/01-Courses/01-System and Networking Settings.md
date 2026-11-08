## Factory Default Settings

Default Access Setting:
* Web GUI: enable(http/https)
* SSH: enable
* Telnet: disable
* SNMP: disable
* DHCP Server: disable

Routing and Firewall Policy:
* No default static routes
* No Firewall policies (有預設的隱式)

Security Services
* All UTM features (disable by default)
  * antivirus
  * IPS
  * Web filtering 

## Method of Access FortiGate Firewall

介紹管理與存取 **FortiGate 次世代防火牆（NGFW）** 的 4 種主要方式及其適用場景：

| 存取方式 | 連線/運作途徑 | 主要優勢與適用場景 |
| --- | --- | --- |
| **1. GUI（圖形化介面 / Web UI）** | 瀏覽器直接登入 | 最廣泛使用、操作直觀友善。適合日常設定、導覽與**檢視報表/圖表**。 |
| **2. CLI（命令列介面）** | SSH、Telnet、實體 Console 線，或直接在 GUI 內開啟 CLI 主控台 | 適合**進階設定、除錯（Debugging）與故障排除**。支援腳本批次作業（例如一次建立上千筆位址物件，直接貼上腳本秒級完成，省去手動逐筆點選的時間）。 |
| **3. API（應用程式介面）** | REST API / HTTP 請求 | 用於與第三方工具整合及**自動化維運**。可程式化抓取系統狀態（如版本、設備名稱）或路由表等資訊。 |
| **4. FortiManager** | Fortinet 專用集中管理平台 | 多設備集中管理解決方案。企業若部署多台 FortiGate，可透過單一管理介面統一派送策略、監控與控制。 |

**核心結論**：日常單機維運以 **GUI** 和 **CLI** 最常見（GUI 利於看報表，CLI 強於除錯與大量批次設定）；大規模企業環境偏好 **FortiManager** 集中控管；跨系統協同則透過 **API** 實現自動化。

## Firewall Monitor

### 核心 FortiView 監視器（Core FortiView Monitors）

在樹狀選單（Tree menu）中提供以下預設監視器：

| 儀表板名稱（Dashboard） | 用途說明（Usage） |
| --- | --- |
| FortiView 來源<br>*(FortiView Sources)* | 依**流量大小**顯示排名最高的來源（Top Sources），並可針對特定來源進行向下鑽研（Drilldown）分析。 |
| FortiView 目的地<br>*(FortiView Destinations)* | 依**流量大小**顯示排名最高的目的地（Top Destinations），並可針對特定目的地進行向下鑽研分析。 |
| FortiView 應用程式<br>(FortiView Applications)* | 依**流量大小**顯示排名最高的應用程式（Top Applications），並可針對特定應用程式進行向下鑽研分析。 |
| FortiView 網站<br>*(FortiView Web Sites)* | 依**連線階段數量（Session count）**顯示排名最高的網站，並可針對特定網域（Domain）進行向下鑽研分析。 |
| FortiView 策略<br>*(FortiView Policies)* | 依**流量大小**顯示排名最高的防火牆策略（Top Policies），並可依策略編號（Policy number）進行向下鑽研分析。 |
| FortiView 連線階段<br>*(FortiView Sessions)* | 依**流量來源**顯示排行最高的連線階段（Top Sessions），並可用於手動強制中斷/結束特定連線。 |

## Command Line Interface

### 背景與核心目的（Background & Objective）

* **背景**：FortiGate 防火牆雖提供圖形化介面（GUI），但在自動化腳本編寫、進階故障排除（Advanced Troubleshooting）以及存取部分 GUI 未開放的底層設定時，具備高度限制。
* **目的**：解析 FortiGate CLI 的樹狀階層語法架構（Tree Structure），使網路與安全管理者掌握其配置邏輯、導覽方式與各層級語法元件的精確定義。


### 架構設計與操作方法（Methodology / Structural Design）

FortiGate CLI 採用階層式樹狀架構（Tree-like Structure），各指令元件由頂層向底層逐步展開：

| 階層元件 | 角色定義 | 實際範例 |
| --- | --- | --- |
| **Command（主指令）** | 觸發動作的最高層級指令，決定防火牆要執行的操作類型。 | `config`, `show`, `get`, `diagnose`, `execute`, `exit` |
| **Object（物件）** | 欲建立或編輯的可配置實體（Configurable Item）。 | `system interface` |
| **Sub-command（子指令）** | 主指令之下的特定操作動作，進入後可遞迴進入更深層級。 | `edit`, `set`, `delete`, `purge`, `get` |
| **Table（表格/群組項目）** | 同類型物件的清單或命名實體（如介面名、策略編號）。 | `port1`, `<port_name>` |
| **Field（欄位）** | 物件內部具體的設定項名稱；若缺少必要欄位系統會報錯。 | `ip`, `status`, `hostname`  |
| **Option（選項）** | 欄位允許選取的特定預設值或關鍵字集合（可單選或以空格分隔多選）。 | `up`, `down` |
| **Value（數值）** | 賦予特定欄位的自訂輸入值（如字串、IP、數值）。 | `192.168.1.1/24`, `<interface_ipv4mask>` |

---

### 關鍵機制與流程範例（Key Findings & Implementation）

* **配置流程**：

    1. **進入物件**：輸入主指令與物件名稱進入特定模式（如 `config system interface`）。
    2. **選取特定實體**：透過子指令鎖定 Table 條目（如 `edit port1`）。
    3. **定義屬性**：
        * 選項型配置：`set status up`（`status` 為 Field，`up` 為 Option）。
        * 數值型配置：`set ip 192.168.1.1/24`（`ip` 為 Field，IP 位址為 Value）。
    4. **階層跳轉與儲存**：完成單一項目設定後輸入 `next` 移動至下一條目，或輸入 `end` / `exit` 儲存並跳出目前階層回到上層。

* **頂層指令分工**：
    * `config`：物件參數配置。
    * `get`：查詢動態資訊與系統運作狀態。
    * `show`：檢視已生效的組態檔內容。
    * `diagnose`：底層除錯與診斷工具調用。
    * `execute`：執行靜態系統層級命令（如 ping、重啟等）。

### 實務意涵與應用總結

* **運維自動化與排錯價值**：掌握 `Field` 與 `Option/Value` 的分離邏輯，有助於撰寫精準的自動化配置腳本（Scripting），並能大幅降低在非 GUI 支援環境下的故障排除門檻。
* **操作規範與限制**：該 CLI 樹狀架構強制要求自頂向下的依序進入機制，若於巢狀結構中省略必要 Field，設備將拋出錯誤並略過該項配置，管理人員需依賴階層提示（如輸入 `?`）確保配置語法正確性。

## Firewall System Configuration

> ![NOTE]
> 以下配置都應當依照場景需求調整

### 背景與核心目的（Background & Objective）

* **背景脈絡**：完成 FortiGate 設備的初始化後，必須建立穩定的基礎系統環境，否則將導致排錯日誌時間戳記不一致、網域名稱解析失效，或因預設管理閒置逾時頻繁斷線。
* **核心目的**：透過 GUI 與 CLI 兩種途徑，為 Firewall 1（FW1）部署基礎系統層級配置，涵蓋自訂 DNS、時區與本地 NTP 伺服器校時同步，以及延長 Web GUI 管理連線閒置時間（Idle Timeout）。


### 2. 架構設計與操作方法（Methodology / Implementation Design）

##### 1. 網路與 DNS 模組（Network > DNS）

* **DNS 伺服器**：取消 FortiGuard 預設伺服器，改為指定（Specify）公共 DNS：Primary 設定為 `8.8.8.8`、Secondary 設定為 `1.1.1.1`。
* **協定設定**：停用 DNS-over-TLS（TCP/853），採用標準 UDP/53。

> 這依照需求進行設定


##### 2. 系統時間與自訂 NTP 模組（System > Settings）

* **時區（Time Zone）**：配置為 Taipei。
* **NTP 伺服器**：由於 GUI 初始狀態下無法直接指定外部內部自訂 NTP，需透過 CLI 切換為 Custom 模式，指向 NTP Server。
* **監聽介面與同步間隔**：配置透過 Management 埠（port5）進行同步，間隔設為 60 分鐘。


> port5 原因是 port5 可連線至 NTP Server。也是依照場域進行調整



##### 3. 管理介面環境設定（System > Settings > Administration Settings）

* **閒置逾時（Idle Timeout）**：由預設 5 分鐘延長至上限 `480` 分鐘（避免 Lab 測試時網頁頻繁登出）。
* **多管理員存取**：啟用 *Allow concurrent sessions* 允許多個管理員並行登入。


---

### 關鍵機制與驗證指令（Key Findings & CLI Verification）

#### DNS

1. CLI

    ```
    FW1 # config system dns 
    FW1 (dns) # set primary 8.8.8.8 
    FW1 (dns) # set secondary 1.1.1.1 
    FW1 (dns) # end 
    FW1 # get system dns 
    ```

    > GUI: Navigate to Network>DNS click on Specify Type the Primary DNS server and Secondary DNS server change DNS Protocols to DNS(UDP/53), disable TLS(TCP/853) click Apply. 

2. 驗證

    ```
    get system dns
    ```

#### NTP

1. CLI

    ```
    FW1 # config system ntp  
    FW1 (ntp) # set ntpsync enable  
    FW1 (ntp) # set type custom  
    FW1 (ntp) # config ntpserver  
    FW1 (ntpserver) # edit 1 
    FW1 (1) # set server 192.168.100.230 
    FW1 (1) # next  
    FW1 (ntpserver) # end 
    FW1 (ntp) # end 
    ```
    > GUI:  System>Settings change the Time Zone, Set Time, Sync interval and Listen on Interface setting click Apply. 

2. 驗證

    ```
    FW1 # show system ntp 
    FW1 # diagnose sys ntp status 
    FW1 # get system status 
    ```
#### 其它(連線逾時)

1. CLI

```
FW1 # config system global 
FW1 (global) # set admintimeout 480 
FW1 (global) # end 
```

> GUI: System>Settings>Administration Settings Idle timeout

2. 驗證

```
get system status
```

#### 實務意涵與限制（Implications & Limitations）

* **GUI 侷限性與 CLI 互補**：FortiGate 的部分功能（如設定非 FortiGuard 的 Custom NTP 伺服器實體）在舊版或初始 Web GUI 下缺少新增按鈕，必須透過 CLI 指令進入 `config system ntp` 底層才能解鎖 GUI 上的 Custom 選項。

* **網路拓撲相依性**：NTP 同步必須指定正確的出接口（如 MGMT / port5）才能存取內部 AD/NTP 伺服器（`192.168.100.230`），否則封包會因路由或防火牆策略阻擋導致校時失敗。


## Interface Roles and Alias

### 背景與核心目的（Background & Objective）

* **背景脈絡**：在多介面、大型或多站點（Multi-site）的複雜網路環境中，僅以硬體編號（如 `port1`、`port2`）進行管理容易造成維運混淆與策略配置錯誤。

* **核心目的**：解析 FortiGate 介面的兩大關鍵邏輯屬性——**角色（Role）** 與 **別名（Alias）** 的運作機制，說明其如何簡化管理、改善日誌視覺化，以及如何動態影響 Web GUI 呈現的配置項目。



---

### 架構設計與屬性定義（Methodology / Attribute Design）

#### Interface Role（介面角色）


* **定義**：定義介面的安全態勢（Security Posture）與預設行為，做為邏輯分組標籤，影響 FortiView、日誌與 Dashboard 的分類顯示。

* **本質特性**：**Role 本身不具備安全強制力（Does not enforce security）**。設定為 LAN 不代表具備較高防禦等級，WAN 亦不會自動套用阻擋規則，所有流量存取仍完全取決於防火牆策略（Firewall Policy）。


* **四種角色類型**：

    * **LAN**：內部受信任網路（如使用者端電腦、內部伺服器）。
    * **WAN**：外部非受信任網路（如 ISP 網際網路線路）。
    * **DMZ**：半受信任網路（提供對外公開服務的 Web/Email 伺服器）。
    * **Undefined**：尚未決定或不指定預設信任等級與行為。





#### Interface Alias（介面別名）

* **定義**：管理者自訂的描述性文字標籤（User-defined label），代表介面的功能、實體位置或對接設備。
* **應用場景**：在配置防火牆策略（Policy）、路由或故障排除時，能直接選取具業務意義的名稱（如 `ISP 1`、`DMZ - Web Server`），免去記憶實體埠號的負擔。

### 關鍵機制與 GUI 行為比對（Key Findings & GUI Impact）

介面 Role 會動態過濾並改變 Web GUI 上顯示的可用功能區塊（但未顯示的選項仍可透過 CLI 強制啟用）：

| 介面角色（Role） | DHCP Server 選項 | 設備偵測（Device Detection） | 流量整形（Traffic Shaping） |
| --- | --- | --- | --- |
| **LAN** | **顯示**（手動指定 IP 後可啟用） | **顯示**並預設啟用 | **顯示** |
| **WAN** | **隱藏**（GUI 移除，需透過 CLI 啟用） | **隱藏** | **顯示** |
| **DMZ** | **隱藏**（部分版本或設定下） | **顯示** | **顯示** |
| **Undefined** | **顯示** | **顯示** | **顯示** |

---

### 實務意涵與建議（Implications）

* **運維與除錯價值**：Alias 顯著降低跨團隊維運與新進人員培訓（Documentation & Training）的溝通成本，避免誤更動非目標介面。
* **GUI 視圖限制意識**：切換為 WAN 角色會使 GUI 自動隱藏 DHCP Server 與 Device Detection，工程師若需在 WAN 端執行特殊部署（如對接上層數據機取 IP 或特殊派發），應意識到這是 GUI 視圖過濾機制，可透過底層 CLI（`config system interface`）進行進階配置。


### Interface configuration 

TODO

## Administrative Access

### 研究背景與核心目的（Background & Objective）

* **背景脈絡**：若防火牆所有介面均預設開放管理存取，將導致對外（WAN）或非信任網段暴露於未授權連線與暴力破解風險中。
* **核心目的**：探討 FortiGate 依介面（Per-interface）控制管理存取權限的機制，評估各管理協定的安全等級，並透過實際啟閉 PING、SSH 與 Telnet 驗證存取控制對設備安全防護的實務效果。


### 架構設計與協定功能矩陣（Methodology / Protocol Matrix）

管理存取可在各介面的 `Administrative Access` 區塊中個別指定 IPv4/IPv6 允許的協定。主要支援協定與安全性分級如下：

| 協定名稱 | 傳輸特徵與主要用途 | 安全建議 | GUI / CLI 支援度 |
| --- | --- | --- | --- |
| **HTTPS** | 加密 Web GUI 管理介面。 | **推薦使用**（管理網段） | GUI / CLI |
| **SSH** | 加密 CLI 命令列存取。 | **推薦使用**（管理網段） | GUI / CLI |
| **PING** | 允許 ICMP 請求，用於連線可用性測試。 | 依需求開放（如 WAN 端檢測） | GUI / CLI |
| **HTTP** | 明文 Web 管理。 | **不建議啟用**（明文傳輸風險） | GUI / CLI |
| **Telnet** | 明文 CLI 管理。 | **極度不建議**（不安全協定） | **僅限 CLI 啟用**（啟用後 GUI 才會顯示） |
| **FMG-Access (fgfm)** | FortiManager 集中管理存取通道。 | 集中管理環境啟用 | GUI / CLI |
| **SNMP** | 網路設備狀態監控。 | 依監控系統需求啟用 | GUI / CLI |
| **Security Fabric (fabric)** | 連接 Fortinet Security Fabric 安全防禦架構。 | 協同防禦環境啟用 | GUI / CLI |
| **FTM** | 支援 FortiToken Mobile Push 雙重認證請求。 | 啟用 2FA 驗證時使用 | GUI / CLI |
| **SCIM** | 跨網域身分管理與身分佈建（如整合 Azure AD / Entra ID）。 | 身分整合時啟用 | GUI / CLI |
| **RADIUS Accounting (radius-acct)** | 追蹤使用者網路活動與登入日誌。 | 帳號計費/日誌審計啟用 | GUI / CLI |
| **Speed Test (speed-test)** | 測量該介面的即時頻寬。 | 頻寬測試時暫時啟用 | GUI / CLI |
| **CAPWAP** | FortiAP 無線基地台集中控制與通訊。 | AP 連接介面啟用 | GUI / CLI |

---

### 關鍵機制與驗證成果（Key Findings & CLI Verification）


* **隱藏不安全協定（CLI 強制機制）**：
    * 為避免管理員誤勾選非安全協定，FortiGate 原生 Web GUI 預設隱藏 `Telnet` 選項。
    * 若因相容性必須啟用，需透過底層 CLI 指定覆蓋：
    ```text
    config system interface
        edit port5
        set allowaccess https http telnet ssh ping
    end

    ```



---

### 實務意涵與安全最佳實踐（Implications）

* **最小權限原則（Principle of Least Privilege）**：
    * **WAN 端介面（WAN 1 / WAN 2）**：嚴格禁止啟用 HTTPS、SSH、HTTP、Telnet 等管理通道，至多僅開放 `PING` 供外網線路健康度檢測。
    * **管理介面（MGMT）**：限定僅開放安全加密協定（`HTTPS` 與 `SSH`）。

* **同步指派黃金法則**：強烈建議在「為連接埠配置 IP 位址」的當下，即同步定義好 `allowaccess`，避免將處於全開放或未定義狀態的介面連入網路環境。
