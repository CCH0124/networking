# In Between Ethernet VLANs and InfiniBand PKEYs

## 什麼是 PKey？（What exactly is PKEY?）

PKEY 代表分割區金鑰（Partition Key）。它是位於 InfiniBand 標頭「BTH（基本傳輸標頭，Base Transport Header）」中的一個 **16 位元（16-bit）欄位**。

在端節點的 PKey 表中擁有相同 PKey 的節點集合，稱為該分割區的成員。

P_Key 表可以指定兩種分割區成員資格（membership）類型之一：

    * **受限（Limited，MSB=0）**
    * **完整（Full，MSB=1）**


分割區金鑰的最高有效位元（MSB，High-order bit）用來記錄分割區表中的成員類型：**0 代表 Limited，1 代表 Full**。

* **Limited 成員無法接收來自其他 Limited 成員的資訊**，但其他每種成員類型的組合之間均允許正常通訊。
* `0xFFFF` 欄位（PKEY 數值為 `0x7FFF`）代表**預設分割區金鑰（Default Partition Key）**。預設分割區金鑰在預設分割區中提供 Full 成員資格。

## 什麼是 VLAN 標籤？（What exactly is VLAN tag?）

VLAN 標籤（VLAN tag）是乙太網路訊框（Ethernet frame）中的選用性 16 位元欄位，它分為三個欄位：

* **VLAN ID**：12 位元（12 bits）
* **CFI**：1 位元（1 bit）
* **Priority（優先權）**：3 位元（3 bits）

VLAN 標籤允許在邏輯上（或虛擬地）將乙太區域網路切分為多個虛擬區域網路（Virtual LANs）。此外，VLAN 標籤也攜帶訊框的優先權資訊。

## InfiniBand PKEY 與 Ethernet VLAN 有何不同？（What is the difference between InfiniBand PKEY and Ethernet VLAN?）

1. **位元長度**：VLAN 標籤與 PKEY 皆為 16 位元欄位。

2. **優先權攜帶機制**：VLAN 標籤直接攜帶優先權資訊，而 PKEY 欄位則不具備優先權。InfiniBand 的優先權是透過 LRH（本地路由標頭，Local Route Header）內的 **SL（Service Level，4 位元）欄位**來攜帶（相較之下 VLAN 標籤內的優先權欄位為 3 位元）。

3. **成員類型（Membership Type）**：Full 或 Limited 的成員資格類型僅存在於 PKEY 機制中。

4. **計數器（Counters）**：經過 Linux 核心的 VLAN 流量計數器可透過 `/proc/net/vlan/<ethX.vlan>` 檔案查看；但各 PKEY 介面並沒有對應的 InfiniBand 計數器可供檢視。

*系統輸出範例：*

```text
# cat /proc/net/vlan/eth1.100
eth1.100 VID: 100 REORDER_HDR: 1 dev->priv_flags: 1
total frames received 28373
total bytes received 1191666
Broadcast/Multicast Rcvd 0 total frames transmitted 1870
total bytes transmitted 78756
Device: eth1
INGRESS priority mappings: 0:0 1:0 2:0 3:0 4:0 5:0 6:0 7:0
EGRESS priority mappings: 0:0 1:1 2:2 3:3 4:4 5:5 6:6 7:7

```

*以上展示了乙太網 VLAN 介面可查詢詳細封包與流量計數器*

## 如何在 InfiniBand 網路架構中配置分割區？（How Do I configure partitions in InfiniBand fabric?）

假設你希望在網路架構中新增分割區 `0x8001`，並讓兩個端節點成為該分割區的成員：

1. 必須在子網路管理器（SM）的 `partitions.conf` 檔案中定義該分割區。

*（`partitions.conf` 檔案的預設路徑為 `/etc/opensm/partitions.conf`）*
* 若在網路中運行 UFM，可透過 UFM 進行設定。
* 若 SM 運行在 InfiniBand 交換器上，則需透過交換器 CLI 進行配置（詳見 MLNX-OS 使用手冊）。

* 其他情況則需要手動修改 `partitions.conf` 檔案。



以下為包含兩個 Full 成員的 `partitions.conf` 範例：

```text
Default=0xffff, ipoib: ALL, SELF=full;
MyPartition=0x8001, ipoib: 0x0002c9030009eb3f=full, 0x0002c902000262841=full;

```

2. 在多數情況下，可能需要為每個節點定義帶有該 PKey 的 IPoIB 介面。
例如，在兩台主機上定義 `ib0.8001` 作為介面，並在同一個子網內為各自指派 IP 位址：

```text
# ifconfig ib0.8001 ib0.8001 Link encap:InfiniBand HWaddr A0:00:02:00:FE:80:00:00:00:00:00:00:00:00:00:00 inet addr:172.16.0.1
Bcast:172.16.255.255 Mask:255.255.0.0 UP BROADCAST RUNNING MULTICAST MTU:4092 Metric:1 RX packets:0 errors:0 dropped:0
overruns:0 frame:0 TX packets:0 errors:0 dropped:0 overruns:0 carrier:0 collisions:0 txqueuelen:1024 RX bytes:0 (0 B) TX bytes:0 (0 B)

```

3. 若要檢視透過 OpenSM 配置的 PKEY 清單，可執行以下指令：

```text
# smpquery PKeyTable -D 0 0: 0xffff 0x8001 0x0000 0x0000 0x0000 0x0000 0x0000 0x0000 8: 0x0000 0x0000 0x0000 0x0000
0x0000 0x0000 0x0000 0x0000 16: 0x0000 0x0000 0x0000 0x0000 0x0000 0x0000 0x0000 0x0000 24: 0x0000 0x0000 0x0000
0x0000 0x0000 0x0000 0x0000 0x0000

```


從查詢結果中即可看到 `PKEY 1` 已經啟用（數值為 `=8001`）。

---

### 總結

* **PKey 定位與成員安全機制**：
    * PKey 位於 BTH 標頭，為 16 位元長度。
    * 最高位元（MSB）決定權限：**Full（MSB=1）** 與 **Limited（MSB=0）**。
    * 通訊隔離規則：**Limited 與 Limited 之間禁止直接通訊**，僅能與 Full 成員連線（類似客端隔離機制）。

* **PKey vs. Ethernet VLAN 的主要差異**：
    * **優先權機制不同**：VLAN 標籤內建 3-bit Priority；PKey 欄位不帶優先權，InfiniBand 是將優先權放在 LRH 的 4-bit SL（Service Level）欄位。

* **成員型態區分**：PKey 具備 Full/Limited 成員類型劃分，VLAN 無此機制。
* **計數器支援**：Linux 對 VLAN 介面有提供 `/proc/net/vlan` 流量計數器，但 InfiniBand PKey 介面無此原生計數器。

* **PKey 部署三步驟**：
    1. **SM 端定義**：在 `/etc/opensm/partitions.conf`、UFM 或交換器 CLI 中建立分割區名稱、PKey 數值（如 `0x8001`）及綁定節點 GUID/權限。
    2. **節點端配置**：在主機建立子介面（如 `ib0.8001`）並配置同網段 IP（IPoIB）。
    3. **驗證狀態**：透過 `smpquery PKeyTable` 指令確認交換器端點已正確載入該 PKey。