# Network Template Rendering System

## 概述 (Overview)

此範本渲染系統為生成網路裝置組態提供了一種彈性且基於繼承（inheritance-based）的方法。它向 Nautobot（網路單一真理源）查詢結構化資料，並使用具有自訂篩選器（filters）的 Jinja2 範本渲染生成裝置組態。

### 關鍵特色 (Key Features)

* **多平台支援**：支援 Cumulus Linux、Arista EOS、Mellanox MLNX-OS 與 NVIDIA NV-OS 的範本。
* **基於角色的範本**：為不同的裝置角色（Leaf、Spine、Core 等）提供自訂組態。
* **版本管理**：支援每個平台/角色有多個韌體版本。
* **範本繼承**：遵循 DRY（Don't Repeat Yourself，不要重複自己）原則，具備多層級範本繼承。
* **自訂篩選器**：強大的 Jinja2 篩選器，用以提取並轉換 Nautobot 資料。
* **型別安全 (Type Safety)**：使用 Python 資料類別（dataclasses）提供結構化且經過驗證的資料物件。

## 系統架構 (System Architecture)

### 高階流程 (High-Level Flow)

```text
Nautobot (單一真理源)
    ↓ (GraphQL 查詢)
裝置資料 Device Data + 位置資料 Location Data
    ↓ (傳遞給渲染器 Pass to Renderer)
Jinja2 範本引擎
    ↓ (套用篩選器並進行渲染 Apply Filters & Render)
裝置組態檔案
```

### 架構組件

1. **Renderer (渲染器)**：主編排類別（orchestration class），負責：
   * 透過 GraphQL 查詢 Nautobot。
   * 載入並設定 Jinja2 環境。
   * 動態註冊自訂篩選器。
   * 使用裝置與位置資料渲染範本。

2. **Filters (篩選器)**：在範本內轉換資料的 Python 函式：
   * 位於 `filters/` 模組中（包含 bgp, device, ip, isis, location, vault）。
   * 自動載入並註冊為 Jinja2 篩選器。
   * 在所有模組中必須擁有唯一的名稱。

3. **Templates (範本)**：依平台、角色與版本組織的 Jinja2 範本：
   * **進入點範本 (Entrypoint templates)**：用於生成最終組態的最頂層範本。
   * **基礎範本 (Base templates)**：使用具名區塊（named blocks）定義組態結構。
   * **包含範本 (Include templates)**：實作特定的組態區段。

4. **Dataclasses (資料類別)**：用於型別安全資料處理的結構化 Python 物件：
   * `Interface`：網路介面表示。
   * `BGPPeer`：BGP 對等體（peering）資訊。
   * `VRF`：虛擬路由與轉發實例。
   * `ConnectedDevice`：已連線鄰近裝置的詳細資訊。

## 範本結構 (Template Structure)

範本組織於階層式的目錄結構中：

```text maxLines=0
templates/
├── {platform}/                      # 例如 "cumulus-linux", "arista-eos"
│   ├── role_common/                 # 此平台的所有角色共用
│   │   ├── base/                    # 基礎範本
│   │   │   └── startup.yaml.j2
│   │   └── include/                 # 通用包含範本
│   │       ├── interface.j2
│   │       ├── service.j2
│   │       └── system.j2
│   └── {role}/                      # 例如 "tan-leaf", "smn-spine", "wan"
│       ├── base/                    # 角色特定的基礎範本
│       │   └── startup.yaml.j2
│       ├── include/                 # 角色特定的包含檔案
│       │   ├── interface.j2
│       │   ├── router.j2
│       │   └── qos.j2
│       └── {version}/               # 例如 "5.6.0", "4.29.3M"
│           └── entrypoint/          # 版本特定的進入點
│               ├── startup.yaml.j2
│               └── boot-script.j2
```

### 範本檢索 (Template Lookup)

渲染器根據裝置屬性決定要使用哪些進入點（entrypoint）範本：

1. **Platform (平台)**：從裝置的平台欄位提取（例如，"Cumulus Linux" ➡️ `cumulus-linux`）。
2. **Role (角色)**：從裝置的角色欄位提取（例如，"TAN-Leaf" ➡️ `tan-leaf`）。
3. **Version (版本)**：從裝置的組態上下文 `intended-firmware.version` 提取。

**路徑範例**：`cumulus-linux/tan-leaf/5.6.0/entrypoint/startup.yaml.j2`

## template-cli

`template-cli` 是一個本地端範本開發指令，並非由執行中的 Config Manager 部署或目標主機上的安裝程式所提供的指令。它會安裝在任何安裝了 `nv-config-manager-templates` 套件的 Python 環境中；在 Config Manager 原始碼樹中，可在 `components/network-templates` 目錄下使用 `uv run template-cli` 來執行。

在將內建範本或外部範本外掛程式封裝提供給渲染服務之前，可使用 `template-cli` 進行疊代開發。部署的環境則會透過 Config Manager UI、渲染 API、事件消費者和暫存的範本外掛程式內容，來使用同一個渲染引擎。

常見的指令：

| 指令 | 用途 |
| :--- | :--- |
| `cache-query` | 僅提取一次裝置與位置的 GraphQL 負載（payloads），並寫入 JSON 測試基底（fixtures）以利快速疊代與 pytest。若外掛程式新增了查詢，則支援使用 `--output-plugin-file`。 |
| `list-entrypoints` | 顯示與裝置相配的進入點範本（可以是即時的 Nautobot、快取的 JSON 或測試基底）。 |
| `render` | 渲染指定的 `--entrypoint` 名稱或完整的 `--template` 路徑。接受 `--cached-data`、`--cached-location-data`、`--cached-plugin-data`，以及選填的 `--output-file`，並可搭配 `--vault` 進行真實的 Vault 密鑰查詢，而非使用虛擬的預留密鑰。 |

在不使用 `--vault` 的情況下，CLI 輸出中的加密欄位會以佔位符顯示。在將渲染的組態複製到實驗室硬體之前，請使用 `--vault`。對於渲染迴歸測試，請在 `tests/resources/expected_config/` 下新增預期檔案，並在 `tests/resources/nautobot/` 下新增相符的 Nautobot JSON，然後執行 `uv run pytest`（請參閱 `nv-config-manager-templates` 的 README 說明）。

## 範本繼承 (Template Inheritance)

系統使用 Jinja2 的範本繼承機制，以實現程式碼重複使用與可維護性。

### 三層式繼承模型 (Three-Tier Inheritance Model)

```text
第一層：平台通用 (role_common)
    ↓ 被繼承 (extends)
第二層：角色特定基礎 (Role-Specific Base)
    ↓ 被繼承 (extends)
第三層：版本特定進入點 (Version-Specific Entrypoint)
```

### 範例：Cumulus Linux TAN-Leaf

**第一層：`cumulus-linux/role_common/base/startup.yaml.j2`**

```jinja
{% block header %}
- set:
{% endblock header %}

{% block acl %}{% endblock acl %}
{% block bridge %}{% endblock bridge %}
{% block evpn %}{% endblock evpn %}
{% block interfaces required %}{% endblock interfaces %}
{% block nve %}{% endblock nve %}
{% block qos required %}{% endblock qos %}
{% block router required %}{% endblock router %}

{% block service %}
{% include "cumulus-linux/role_common/include/service.j2" %}
{% endblock service %}

{% block system %}
{% include "cumulus-linux/role_common/include/system.j2" %}
{% endblock system %}

{% block vrf required %}{% endblock vrf %}
```

這使用具名區塊定義了整體結構。`required` 關鍵字確保子範本必須實作這些區塊。

**第二層：`cumulus-linux/tan-leaf/base/startup.yaml.j2`**

```jinja
{% extends "cumulus-linux/role_common/base/startup.yaml.j2" %}

{% block bridge %}
{% include "cumulus-linux/tan-leaf/include/bridge.j2" %}
{% endblock bridge %}

{% block interfaces %}
{% include "cumulus-linux/tan-leaf/include/interface.j2" %}
{% endblock interfaces %}

{% block qos %}
{% include "cumulus-linux/tan-leaf/include/qos.j2" %}
{% endblock qos %}

{% block router %}
{% include "cumulus-linux/tan-leaf/include/router.j2" %}
{% endblock router %}

{% block vrf %}
{% include "cumulus-linux/tan-leaf/include/vrf.j2" %}
{% endblock vrf %}
```

這透過包含角色特定的範本，實作了角色特定的區塊。

**第三層：`cumulus-linux/tan-leaf/5.6.0/entrypoint/startup.yaml.j2`**

```jinja
{% extends "cumulus-linux/tan-leaf/base/startup.yaml.j2" %}
```

這單純地擴充了角色的基礎範本。如果版本 5.6.0 需要特定的變更，可以在此處覆寫區塊。

### 包含範本繼承 (Include Template Inheritance)

包含（Include）範本之間也可以相互繼承：

**通用介面範本：`cumulus-linux/role_common/include/interface.j2`**

```jinja
    interface:
{% block management %}
{% set intf = device_data|interface_by_name("eth0") %}
      eth0:
        description: {{intf.description}}
        ip:
          address:
            {{ intf.primary_ipv4 }}: {}
          gateway:
            {{ intf.primary_ipv4|gateway }}: {}
        type: eth
{% endblock management %}

{% block loopback %}
{% set intf = device_data|interface_by_name("lo") %}
      lo:
        ip:
          address:
            {{ intf.primary_ipv4 }}: {}
        type: loopback
{% endblock loopback %}

{% block swp required %}{% endblock swp %}
{% block vlan %}...{% endblock vlan %}
```

**角色特定介面範本：`cumulus-linux/tan-leaf/include/interface.j2`**

```jinja
{% extends "cumulus-linux/role_common/include/interface.j2" %}

{% block swp %}
{% for intf in device_data|interfaces(prefix="swp") %}
      {{ intf.name }}:
        description: {{intf.description}}
        qos:
          congestion-control:
            profile: tan-ecn-profile
        type: swp
{% endfor %}
{% endblock swp %}
```

這繼承了通用的管理和 lo (loopback) 區塊，僅實作了特定 swp 連接埠的邏輯。

## Jinja2 篩選器 (Jinja2 Filters)

篩選器是在範本中提取與轉換 Nautobot 資料的主要機制。所有的篩選器都是純 Python 函式，接收資料輸入並傳回處理後的輸出。

### 篩選器組織 (Filter Organization)

篩選器依功能劃分為不同的模組：

* **device.py**：裝置層級屬性與介面操作。
* **bgp.py**：BGP 特定的資料轉換。
* **ip.py**：IP 位址與網路運算。
* **isis.py**：IS-IS 協定輔助。
* **location.py**：站點/位置層級的資料（彙整網段、ASN、對等體）。
* **vault.py**：密鑰管理與加密。

### 裝置篩選器 (Device Filters)

從 Nautobot GraphQL 資料中提取裝置屬性。

#### 基礎裝置資訊

| 篩選器 | 輸入 | 輸出 | 說明 | Nautobot 欄位 |
| :--- | :--- | :--- | :--- | :--- |
| `hostname` | device_data | string | 裝置主機名稱 | `device.name` |
| `site_name` | device_data | string | 站點名稱（處理巢狀位置） | `device.location` 階層關係 |
| `platform` | device_data | string | 平台名稱 | `device.platform.name` |
| `role` | device_data | string | 裝置角色 | `device.role.name` |
| `model` | device_data | string | 裝置型號 | `device.device_type.model` |
| `uuid` | device_data | string | Nautobot UUID | `device.id` |
| `device_tags` | device_data | list[str] | 裝置標籤清單 | `device.tags[].name` |
| `has_tag` | device_data, tag | bool | 檢查裝置是否具有特定標籤 | `device.tags[].name` |
| `desired_firmware`| device_data | string | 目標韌體版本 | `device.config_context['intended-firmware']['version']` |

**範例用法：**

```jinja
hostname {{ device_data|hostname }}
! Running {{ device_data|platform }} {{ device_data|desired_firmware }}
! Role: {{ device_data|role }}
```

#### 路由與 BGP

| 篩選器 | 輸入 | 輸出 | 說明 | Nautobot 欄位 |
| :--- | :--- | :--- | :--- | :--- |
| `router_id` | device_data | string | 路由器 ID（不含子網路遮罩的 IPv4） | Loopback 介面 IP |
| `asn` | device_data, vrf="default" | string | 裝置/VRF 的 BGP ASN | `device.bgp_routing_instances[].autonomous_system.asn` 或組態上下文 |
| `local_asn` | device_data | string | Azure 裝置的本地端 ASN | `device.config_context['bgp']['local-asn']` |
| `bgp_peers` | device_data, vrf="default" | list[BGPPeer] | BGP 對等體清單 | `device.bgp_routing_instances[].endpoints` |

**範例用法：**

```jinja
router bgp {{ device_data|asn }}
  router-id {{ device_data|router_id }}
  {% for peer in device_data|bgp_peers %}
  neighbor {{ peer.peer_ipv4 }} remote-as {{ peer.asn }}
  {% endfor %}
```

#### 介面操作

| 篩選器 | 輸入 | 輸出 | 說明 | Nautobot 欄位 |
| :--- | :--- | :--- | :--- | :--- |
| `interfaces` | device_data, prefix=None, role=None, tags=None | list[Interface] | 依前綴/角色/標籤篩選介面 | `device.interfaces[]` |
| `interface_by_name`| device_data, name, fail_if_missing=True | Interface or None | 取得特定介面；設定 `fail_if_missing=False` 可避免在缺失時拋出異常 | `device.interfaces[]` 且 `name` 符合 |
| `breakout_count` | device_data, interface_name | int | 分口（breakout）連接埠數量 | 衍生自子介面 |
| `loopback_prefix` | device_data | string | Loopback 介面的父前綴 (parent prefix) | `interfaces[name='lo'].ip_addresses[0].parent.parent.prefix` |

**Interface 物件屬性：**

```python
Interface(
    name: str                           # 介面名稱 (例如 "swp1", "Ethernet1")
    primary_ipv4: str | None            # 帶有前綴的 IPv4 位址
    primary_ipv6: str | None            # 帶有前綴的 IPv6 位址
    enabled: bool                       # 介面啟用狀態
    mtu: int                            # MTU 大小
    tags: list[str]                     # 介面標籤
    untagged_vlan: int | None           # 未標記的 VLAN ID (Access VLAN)
    tagged_vlans: list[int]             # 標記的 VLAN ID 清單 (Trunk VLANs)
    vrf: str                            # VRF 名稱
    description: str                    # 介面描述
    role: str                           # 介面角色
    connected_interface: ConnectedInterface  # 對端已連線之介面資訊
)
```

**範例用法：**

```jinja
{% for intf in device_data|interfaces(prefix="swp", role="Uplink") %}
interface {{ intf.name }}
  description {{ intf.description }}
  mtu {{ intf.mtu }}
  {% if intf.primary_ipv4 %}
  ip address {{ intf.primary_ipv4 }}
  {% endif %}
{% endfor %}
```

#### 特殊篩選器

| 篩選器 | 輸入 | 輸出 | 說明 |
| :--- | :--- | :--- | :--- |
| `spx_subnets` | device_data, ip_version=4 | list[dict] | 具有 rail 前綴的 Spectrum-X 下行（downlink）/31 子網。 |
| `tenant_vrfs` | device_data | list[VRF] | 裝置上設定的租戶 VRF。 |
| `console_server_ports`| device_data | list[ConsoleServerPort] | 主控台（console）連線。 |
| `helper_addresses_by_vlan`| device_data, location_data | dict | 依 VLAN ID 索引的 DHCP 轉發位址（helper addresses）。 |
| `helper_addresses_by_vrf`| device_data, location_data | dict | 依 VRF 分組的轉發（helper）設定。 |
| `users` | device_data | list[dict] | 用於範本化之本地端或 AAA 使用者的使用者名稱、選填角色與密碼對應鍵。 |

### BGP 篩選器 (BGP Filters)

轉換 BGP ASN 格式。

| 篩選器 | 輸入 | 輸出 | 說明 |
| :--- | :--- | :--- | :--- |
| `asplain` | asdot_string | int | 將 ASDOT 標記法轉換為 ASPLAIN（例如，"1.1" ➡️ 65537）。 |

**範例：**

```jinja
router bgp {{ "1.100"|asplain }}  {# 產生結果: router bgp 65636 #}
```

### IP 篩選器 (IP Filters)

網路運算與 IP 位址處理。

| 篩選器 | 輸入 | 輸出 | 說明 |
| :--- | :--- | :--- | :--- |
| `gateway` | cidr | string | 子網中第一個可用的 IP。 |
| `subnet` | cidr, prefix_len | list[str] | 將網路細分為更小的子網路。 |
| `supernet` | cidr, prefix_len | string | 取得父級超網（parent supernet）。 |
| `ips` | cidr | list[str] | 列出網段中的所有 IP。 |
| `netmask_notation` | cidr | tuple[str, str] | 將 CIDR 轉換為 (位址, 子網路遮罩)。 |
| `get_peer_ip` | cidr | string | 取得 /31 點對點連結中的對端 IP。 |
| `network_address` | cidr | string | 從主機 IP 中提取網路位址。 |
| `host_range` | cidr | tuple[str, str] | 取得 DHCP 範圍的 (第一個主機, 最後一個主機)。 |
| `rfc3442_classless_static_route` | cidr, next_hop | string | 為 DHCP 格式化 RFC3442 無類別靜態路由。 |

**範例用法：**

```jinja
{# 閘道計算 #}
ip route 0.0.0.0/0 {{ intf.primary_ipv4|gateway }}

{# 子網細分 #}
{% for subnet in "10.0.0.0/16"|subnet(24) %}
ip prefix-list SUBNETS permit {{ subnet }}
{% endfor %}

{# 取得 /31 連結的對端 IP #}
{% set peer_ip = intf.primary_ipv4|get_peer_ip %}
neighbor {{ peer_ip }} remote-as {{ peer_asn }}

{# DHCP 主機範圍 #}
{% set first, last = subnet|host_range %}
range {{ first }} {{ last }};
```

### ISIS 篩選器 (ISIS Filters)

IS-IS 協定輔助程式。

| 篩選器 | 輸入 | 輸出 | 說明 |
| :--- | :--- | :--- | :--- |
| `isis_system_id` | loopback_ip | string | 從 loopback 產生 IS-IS 系統 ID（例如，"1.2.3.4" ➡️ "49.0039.8037.0001.0002.0003.0004.00"）。 |

**範例：**

```jinja
router isis CORE
  net {{ device_data|router_id|isis_system_id }}
```

### 位置篩選器 (Location Filters)

提取站點/位置層級的資料（操作於 `location_data` 上，而非 `device_data`）。

| 篩選器 | 輸入 | 輸出 | 說明 | Nautobot 欄位 |
| :--- | :--- | :--- | :--- | :--- |
| `site_aggregates` | location_data, role_name, tags=None, exclude_tags=None | list[str] | 具有特定角色的前綴；選填標籤包含/排除清單。 | `location.prefixes[]` 且依角色篩選 |
| `site_asn` | location_data | string | 站點層級的 BGP ASN | `location.config_contexts[0].data.site_asn` |
| `route_server_peers`| location_data | list[BGPPeer] | 站點的 BGP 路由伺服器對等體 | `location.route_servers[]` |
| `wan_loopbacks` | location_data | list[tuple] | WAN 路由器名稱與 loopback 位址 | `location.wan_devices[].interfaces[]` |
| `uc_jumphost_prefixes`| location_data | list[str] | UC 跳板主機前綴 | `location.uc_jumphost_prefixes[]` |

**範例用法：**

```jinja
{# 取得用以宣告的站點彙整網段 #}
{% for aggregate in location_data|site_aggregates("Aggregate", tags=["bgp-advertise"]) %}
network {{ aggregate }}
{% endfor %}

{# 與路由伺服器建立對等關係 #}
{% for rs in location_data|route_server_peers %}
neighbor {{ rs.peer_ipv4 }} remote-as {{ rs.asn }}
neighbor {{ rs.peer_ipv4 }} peer-group {{ rs.peer_group }}
{% endfor %}
```

### Vault 篩選器 (Vault Filters)

金鑰管理與加密（用於密碼、金鑰等）。

| 篩選器 | 輸入 | 輸出 | 說明 |
| :--- | :--- | :--- | :--- |
| `load_secret` | key, region=None, site=None | string | 從 Hashicorp Vault 載入金鑰。 |
| `encrypt` | plaintext, algo, site=None | string | 使用 "sha512"、"md5" 或 "ciscot7" 進行加密；選填 `site` 可用以查詢鹽值（salt）。 |
| `get_password_key` | device_data, username | string | 從組態上下文中獲取使用者的密碼金鑰。 |

**金鑰載入模式 (Secret Loading Modes)**：

1. **Production (生產環境)**：直接查詢 Hashicorp Vault。
2. **Kubernetes (容器環境)**：自注入的密鑰檔案中讀取。
3. **Development (開發環境)**：當 `NV_CONFIG_MANAGER_SKIP_VAULT=1` 時，傳回模擬值（格式為 `{path}:{key}`）。

**範例用法：**

```jinja
{# 載入並加密密碼 #}
{% set admin_key = device_data|get_password_key("admin") %}
{% set admin_password = admin_key|load_secret(site=device_data|site_name) %}
username admin secret {{ admin_password|encrypt("sha512") }}

{# 載入 TACACS 金鑰 #}
{% set tacacs_key = "tacacs_shared_key"|load_secret(region="US-WEST") %}
tacacs-server key {{ tacacs_key|encrypt("ciscot7") }}
```

## Nautobot 資料模型 (Nautobot Data Model)

系統使用 GraphQL 查詢 Nautobot，以檢索完整的裝置與位置資料。

### 裝置查詢結構 (Device Query Structure)

裝置查詢（`query_config_data_by_device_id_v2.graphql`）會檢索：

```text maxLines=0
device (裝置)
├── 基礎屬性 (Basic Attributes): id, name, serial, role, platform, device_type, tenant
├── tags[]: 裝置標籤清單
├── location: 站點/位置階層關係
├── config_context: 自訂 JSON 資料（包含目標韌體、BGP 設定等）
├── interfaces[] (介面)
│   ├── 基礎: name, type, mtu, enabled, description, mgmt_only
│   ├── role: 介面角色
│   ├── tags[]: 介面標籤
│   ├── vrf: 帶有 RD 和路由目標的 VRF 指派
│   ├── ip_addresses[]: 帶有父前綴階層關係的 IPv4/IPv6 位址
│   ├── member_interfaces[]: LAG 成員
│   ├── parent_interface: 子介面的父介面
│   ├── untagged_vlan: 存取 VLAN (Access VLAN)
│   ├── tagged_vlans[]: 幹線 VLAN (Trunk VLANs)
│   └── connected_interface (已連線介面)
│       ├── name, ip_addresses[]
│       └── device: 已連線裝置細節 (name, role, tenant, tags, config_context)
├── bgp_routing_instances[] (BGP 路由實例)
│   ├── status, autonomous_system (ASN)
│   ├── router_id (包含介面與 VRF)
│   └── endpoints[] (BGP 對等體)
│       ├── peer_group (對等體群組)
│       ├── source_interface
│       └── peer: 遠端裝置路由實例
├── console_server_ports[] (主控台伺服器連接埠)
│   └── connected_console_port
│       └── device: 已連線裝置
└── nvlink_domain: NVLink 拓撲資料
```

### 位置查詢結構 (Location Query Structure)

位置查詢（`query_location_data.graphql`）會檢索站點層級資料：

```text maxLines=0
location (位置)
├── name, location_type
├── config_contexts[]: 站點層級設定 (ASN 等)
├── prefixes[]: 此站點的 IP 前綴
│   ├── prefix, role
│   └── tags[]
├── route_servers[]: BGP 路由伺服器
│   ├── name, config_context
│   └── interfaces[].ip_addresses[]
├── wan_devices[]: WAN 路由器
│   ├── name
│   └── interfaces[] (用於 loopback IP)
└── uc_jumphost_prefixes[]: 跳板主機前綴
```

### 組態上下文 (Config Context)

`config_context` 欄位包含定義於 Nautobot 中的自訂 JSON 資料：

```json
{
  "intended-firmware": {
    "version": "5.6.0",
    "image": "cumulus-linux-5.6.0.bin"
  },
  "bgp": {
    "asn": 65100,
    "local-asn": 65200
  },
  "password_mappings": {
    "default": {
      "admin": {
        "password": "admin_password",
        "rotation": "v1",
        "role": "admin"
      }
    }
  }
}
```

允許的密碼對應角色（password-mapping roles）為 `admin`、`ro` 與 `rw`。

## 建立範本 (Creating Templates)

### 確定範本放置位置

根據您的裝置，識別以下項目：

1. **Platform (平台)**：`cumulus-linux`、`arista-eos`、`mlnx-os`、`nv-os`。
2. **Role (角色)**：`tan-leaf`、`smn-spine`、`wan`、`oob-switch` 等。
3. **Version (版本)**：韌體版本，例如 `5.6.0`、`4.29.3M`。

### 建立或擴充基礎範本 (Create or Extend Base Template)

若要建立新的角色，請從基礎範本開始：

**檔案路徑**：`{platform}/{role}/base/{config-file}.j2`

```jinja
{% extends "{platform}/role_common/base/{config-file}.j2" %}

{% block interfaces %}
{% include "{platform}/{role}/include/interface.j2" %}
{% endblock interfaces %}

{% block router %}
{% include "{platform}/{role}/include/router.j2" %}
{% endblock router %}

{# 依需求覆寫其他區塊 #}
```

### 建立包含範本 (Create Include Templates)

實作特定的設定區段：

**檔案路徑**：`{platform}/{role}/include/interface.j2`

```jinja
{# 可依需求繼承通用範本 #}
{% extends "{platform}/role_common/include/interface.j2" %}

{% block swp %}
{% for intf in device_data|interfaces(prefix="swp") %}
interface {{ intf.name }}
  description {{ intf.description }}
  {% if intf.primary_ipv4 %}
  ip address {{ intf.primary_ipv4 }}
  {% endif %}
  {% if not intf.enabled %}
  shutdown
  {% endif %}
{% endfor %}
{% endblock swp %}
```

### 建立進入點範本 (Create Entrypoint Template)

**檔案路徑**：`{platform}/{role}/{version}/entrypoint/{config-file}.j2`

```jinja
{% extends "{platform}/{role}/base/{config-file}.j2" %}

{# 若需要版本特定的變更，請覆寫對應區塊 #}
{% block new_feature %}
{% if device_data|has_tag("enable-new-feature") %}
! 新版本 {{ device_data|desired_firmware }} 的新功能設定
new-feature enable
{% endif %}
{% endblock new_feature %}
```

### 設定 Nautobot (Configure Nautobot)

確保 Nautobot 中的裝置具有：

1. 正確設定的 **Platform (平台)**。
2. 正確設定的 **Role (角色)**。
3. **Config Context (組態上下文)** 中的 `intended-firmware.version` 必須與您的範本路徑相符。
4. 填入必要的介面、IP 與 BGP 資料。

### 測試您的範本 (Test your template)

1. 快取裝置資料：

   ```bash
   uv run template-cli cache-query --hostname my-device \
     --output-file tests/resources/nautobot/my-device.json \
     --output-location-file tests/resources/nautobot/MY-SITE.json
   ```

2. 在本地端渲染：

   ```bash
   uv run template-cli render \
     --cached-data tests/resources/nautobot/my-device.json \
     --cached-location-data tests/resources/nautobot/MY-SITE.json \
     --entrypoint startup.yaml.j2
   ```

3. 新增預期輸出：將渲染的輸出儲存至 `tests/resources/expected_config/my-device_startup.yaml`（命名慣例為 `{hostname}_{entrypoint}`）。
4. 執行測試：`uv run pytest tests/nv_config_manager_templates/test_render.py`。

## 最佳實踐 (Best Practices)

### 範本設計 (Template Design)

1. **使用繼承**：避免重複的組態程式碼。擴充基礎範本並僅覆寫相異之處。
2. **保持包含範本專注**：每個 include 範本應僅處理一個邏輯區段（如介面、路由、QoS 等）。
3. **明確失敗**：使用 `fail_if_missing=True`（預設值）的篩選器，以便及早發現資料異常。
4. **處理選填資料**：在使用選填欄位前，請先檢查是否為 None。
5. **在篩選器中處理邏輯**：將複雜的邏輯移至 Python 篩選器中，而非寫在 Jinja2 範本內。
6. **空白字元管理**：已啟用 Jinja2 `trim_blocks=True`。可使用 `{%-` 與 `-%}` 進行更精確的控制。

### 篩選器開發 (Filter Development)

1. **單一職責**：每個篩選器應專注於做一件事。
2. **型別提示**：使用型別提示（type hints）以提高程式碼清晰度。
3. **錯誤處理**：在發生錯誤時拋出 `FilterException` 並附帶清晰的說明訊息。
4. **測試覆蓋率**：每個篩選器都必須編寫單元測試。
5. **不可變資料**：使用 `frozen=True` 的資料類別（dataclasses）以防止意外的資料變更。

### Nautobot 資料管理 (Nautobot Data Management)

1. **一致的命名**：為裝置、介面、VLAN 等遵循一致的命名慣例。
2. **組態上下文 (Config Context)**：使用組態上下文管理預期韌體、BGP、密碼對應等。
3. **介面角色 (Interface Roles)**：一致地定義與使用介面角色（例如 Uplink, Downlink, Management）。
4. **標籤 (Tags)**：使用標籤進行功能啟用（`enable-feature-x`）、裝置分組與介面分類。
5. **IP 階層結構**：維持正確的父子前綴關係（Rail aggregates ➡️ 裝置前綴 ➡️ /31 點對點連結）。

### 版本管理 (Version Management)

1. **僅針對版本特定變更**：僅在絕對必要時才建立特定韌體版本的範本。
2. **功能偵測**：盡量使用標籤（tags）而非版本號檢查來判斷功能支援。
3. **防退化與遷移 (Deprecation Path)**：在棄用舊版本時，保留對應範本以供平滑遷移。

## 實用範例 (Examples)

### 簡單的介面設定 (Simple Interface Configuration)

**範本**：`my-platform/my-role/include/interface.j2`

```jinja
{% for intf in device_data|interfaces(prefix="Ethernet") %}
interface {{ intf.name }}
  description {{ intf.description }}
  mtu {{ intf.mtu }}
  {% if intf.primary_ipv4 %}
  ip address {{ intf.primary_ipv4 }}
  {% endif %}
  {% if intf.enabled %}
  no shutdown
  {% else %}
  shutdown
  {% endif %}
{% endfor %}
```

### 帶有對等體群組的 BGP 設定 (BGP Configuration with Peer Groups)

**範本**：`my-platform/my-role/include/bgp.j2`

```jinja
router bgp {{ device_data|asn }}
  router-id {{ device_data|router_id }}

  {# 定義對等體群組 #}
  neighbor SPINE peer-group
  neighbor SPINE remote-as {{ location_data|site_asn }}
  neighbor SPINE send-community extended

  {# 設定個別對等體 #}
  {% for peer in device_data|bgp_peers %}
  {% if peer.peer_group == "SPINE" %}
  neighbor {{ peer.peer_ipv4 }} peer-group SPINE
  neighbor {{ peer.peer_ipv4 }} description {{ peer.description }}
  {% endif %}
  {% endfor %}

  {# 位址族群 #}
  address-family ipv4 unicast
    {% for aggregate in location_data|site_aggregates("Aggregate") %}
    network {{ aggregate }}
    {% endfor %}
  exit-address-family
```

### 基於標籤的條件設定 (Conditional Configuration Based on Tags)

**範本**：`my-platform/my-role/include/features.j2`

```jinja
{# 僅在標有該標籤的裝置上啟用 LLDP #}
{% if device_data|has_tag("enable-lldp") %}
lldp run
{% for intf in device_data|interfaces(prefix="Ethernet") %}
interface {{ intf.name }}
  lldp transmit
  lldp receive
{% endfor %}
{% endif %}

{# 在標有 qos-enabled 標籤的介面上設定 QoS #}
{% for intf in device_data|interfaces(tags=["qos-enabled"]) %}
interface {{ intf.name }}
  qos trust dscp
  qos cos {{ intf.tags|select("match", "^cos-\\d+$")|first|replace("cos-", "") }}
{% endfor %}
```

### DHCP 伺服器設定 (DHCP Server Configuration)

**範本**：`cumulus-linux/cin-leaf/base/dhcpd.conf.j2`

```jinja
default-lease-time 600;
max-lease-time 7200;
ddns-update-style none;
authoritative;

{% for intf in device_data|interfaces(role="Tenant") %}
{% if intf.primary_ipv4 %}
subnet {{ intf.primary_ipv4|network_address|netmask_notation|first }}
       netmask {{ intf.primary_ipv4|network_address|netmask_notation|last }} {
  {% set first_host, last_host = intf.primary_ipv4|network_address|host_range %}
  range {{ first_host }} {{ last_host }};
  option routers {{ intf.primary_ipv4|gateway }};
  option domain-name-servers 8.8.8.8, 8.8.4.4;

  {# 透過 RFC3442 進行靜態路由 #}
  {% set routes = [] %}
  {% for aggregate in location_data|site_aggregates("Aggregate") %}
  {% set _ = routes.append(aggregate|rfc3442_classless_static_route(intf.primary_ipv4|gateway)) %}
  {% endfor %}
  option rfc3442-classless-static-routes {{ routes|join(', ') }};
}
{% endif %}
{% endfor %}
```

### 多 VRF BGP 設定 (Multi-VRF BGP Configuration)

**範本**：`my-platform/my-role/include/bgp-vrf.j2`

```jinja
{% for vrf in device_data|tenant_vrfs %}
router bgp {{ device_data|asn("default") }}
  vrf {{ vrf.name }}
    router-id {{ device_data|router_id }}

    {# VRF 特定對等體 #}
    {% for peer in device_data|bgp_peers(vrf=vrf.name) %}
    neighbor {{ peer.peer_ipv4 }} remote-as {{ peer.asn }}
    neighbor {{ peer.peer_ipv4 }} description {{ peer.description }}
    {% endfor %}

    {# 用於 EVPN 的 L3 VNI #}
    address-family ipv4 unicast
      redistribute connected
      redistribute static
    exit-address-family

    address-family l2vpn evpn
      advertise ipv4 unicast
    exit-address-family
  exit-vrf
{% endfor %}
```

### 密鑰管理 (Secret Management)

**範本**：`my-platform/my-role/include/management.j2`

```jinja
{# 載入站點特定的密鑰 #}
{% set site = device_data|site_name %}

{# 帶有加密密碼的 admin 使用者 #}
{% set admin_key = device_data|get_password_key("admin") %}
{% set admin_password = admin_key|load_secret(site=site) %}
username admin privilege 15 secret {{ admin_password|encrypt("sha512") }}

{# 載入 TACACS 金鑰 #}
{% set tacacs_key = "tacacs_shared_key"|load_secret(site=site) %}
tacacs-server host 10.0.0.10 key {{ tacacs_key|encrypt("ciscot7") }}
tacacs-server host 10.0.0.11 key {{ tacacs_key|encrypt("ciscot7") }}

{# SNMP 社群字串 #}
{% set snmp_community = "snmp_ro_community"|load_secret(site=site) %}
snmp-server community {{ snmp_community }} ro
```

### 帶有已連線裝置上下文的介面設定 (Interface with Connected Device Context)

**範本**：`my-platform/my-role/include/interface-advanced.j2`

```jinja
{% for intf in device_data|interfaces(prefix="Ethernet") %}
interface {{ intf.name }}
  description {{ intf.description }}

  {% if intf.connected_interface %}
  {# 我們已知對端連線的裝置資訊 #}
  {% set peer = intf.connected_interface.device %}

  {# 依據對端角色進行設定 #}
  {% if peer.role == "Spine" %}
  {# 連接至 spine 的 Uplink #}
  no switchport
  ip address {{ intf.primary_ipv4 }}

  {% elif peer.role == "GPU" %}
  {# 連接至 GPU 伺服器的 Downlink #}
  switchport mode access
  switchport access vlan {{ intf.untagged_vlan }}
  spanning-tree portfast

  {% elif peer.role in ["Storage-Server", "Control-Server"] %}
  {# 連接至伺服器的 LAG 連結 #}
  channel-group {{ intf.name|regex_replace('Ethernet(\\d+)', '\\1') }} mode active

  {% endif %}
  {% endif %}
{% endfor %}
```

## 結論 (Conclusion)

此範本渲染系統為網路組態管理提供了一種強大且易於維護的方式。藉由結合：

* **Jinja2 繼承**：實現程式碼的重複使用。
* **自訂篩選器**：提供靈活的資料轉換。
* **Nautobot 作為單一真理源**：確保資料的結構化與一致性。
* **Python 資料類別 (Dataclasses)**：確保型別安全。

您可以建構高擴展性的組態範本，以適應多元的網路環境，同時保持組態的一致性與可靠性。

若對範本開發有任何支援需求或疑問，請聯絡 CFA 團隊或參閱 `nv-config-manager-templates` 的 README。

* [篩選器快速參考](https://docs.nvidia.com/switch-infrastructure/config-manager/services/render/filter-quick-reference)
* [範本展開導覽](https://docs.nvidia.com/switch-infrastructure/config-manager/services/render/template-expansion)
* [Render 服務](https://docs.nvidia.com/switch-infrastructure/config-manager/services/render/config-manager-render-service)
* [API 參考資料](api:render-api)
