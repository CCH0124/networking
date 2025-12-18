## **理解 (Understanding):**

1.  **分割區 (Partitions)** 有兩種類型的成員資格：**完整成員資格 (Full membership)** 和 **限制成員資格 (Limited membership)**。

      * **完整 (Full) [預設值]**：擁有完整成員資格的成員，可以與該網路/分割區內的所有主機 (成員) 進行通訊。
      * **限制/部分 (Limited/partial)**：擁有限制成員資格的成員，**無法**與其他同樣擁有限制成員資格的成員通訊。
      * **成員資格類型取決於最高有效位元 (Most-significant bit)**：然而，不同類型的成員之間可以進行通訊（例如：完整 + 限制）。

2.  成員資格類型被加入到 **P\_Key** 數值的最高有效位元 (MSB) 中。例如，預設的 PKey `7fff`，其數值將會是 `0x7FFF` (限制) 或 `0xFFFF` (完整)。


## 技術重點整理

這份文件對於網路工程師來說，最重要的觀念總結如下：

1.  **P\_Key 的結構與計算：**

      * P\_Key 是 16-bit 的數值。
      * **最高位元 (Bit 15)** 決定權限：`1` = Full (完整)，`0` = Limited (限制)。
      * 因此，同一個 Partition ID (例如 `7FFF`) 會有兩個 Hex 值：`0x7FFF` (Limited) 和 `0xFFFF` (Full)。

2.  **通訊規則 (存取控制)：**

      * **不同 P\_Key ID：** 絕對隔離，完全無法通訊 (例如 `0x6FFF` 不能連 `0x7FFF`)。
      * **同 P\_Key ID 內的權限：**
          * Full \<--\> Full : ✅ 可通訊
          * Full \<--\> Limited : ✅ 可通訊 (常見於 Server 連接 Storage 或 SM)
          * Limited \<--\> Limited : ❌ **不可通訊** (此機制常用於多租戶隔離，防止 Client 端互連)。

3.  **設定生效機制：**

      * 修改 `partitions.conf` 後，OpenSM 不會立即得知。
      * 必須觸發 **Heavy Sweep** (網路拓樸重掃描) 才會生效。
      * 指令：`pkill -HUP opensm` (發送 HUP 訊號給 OpenSM 行程)。

## Example

### 範例 1

下面展示了 InfiniBand 分割區 (Partition) 設定中**「白名單 (Whitelist)」**的控制方式，也就是**「只允許特定裝置加入這個網路」**，而非開放給所有人。

這行指令位於 OpenSM 的設定檔 (`partitions.conf`) 中。讓我們拆解每一個部分的含義：

`Part2=0x8020,ipoib, defmember=full : SELF, 0x0002c90300ea67d1, 0x0002C9030073D2A8;`

我將它拆解為三個區塊來解釋：**[定義] : [成員清單] ;**

#### 1. 網路定義區 (冒號之前)

* **`Part2`**
    * 這是**分割區名稱 (Partition Name)**。這只是給人看的標籤，方便管理員識別這是哪個網路（例如可以改名為 `Storage_Net`）。

* **`0x8020`**
    * 這是** P_Key (Partition Key)**。
    * **`0x0020`** 是 Partition ID。
    * **`0x8000`** 是 Full Member 的標記 (最高位元為 1)。
    * 加起來就是 `0x8020`，代表這個分割區的成員預設擁有完整通訊權限。

* **`ipoib`**
    * 這是**功能旗標**。代表這個分割區支援 **IP over InfiniBand**。
    * 加上這個，作業系統才能在這個 P_Key 上建立網路介面（例如 `ib0.8020`），你才能設定 IP 位址（如 `20.20.2.x`）。沒有這個，它就只能跑原生的 RDMA 協定，無法設定 IP。

* **`defmember=full`**
    * 這是**預設成員資格**。
    * 意思是：列在後面清單中的成員，如果沒有特別註明，一律給予 **Full (完整)** 權限。

#### 2. 成員清單區 (冒號之後)

這部分是與先前範例 (`ALL=full`) 最大的不同處。這裡使用的是**指定 GUID (硬體位址)** 的方式。

* **`SELF`**
    * 這代表 **Subnet Manager (SM) 自己**。
    * **重要觀念：** SM 必須是所有 Partition 的成員，否則它無法管理這個網路。所以設定白名單時，永遠要記得加上 `SELF`。

* **`0x0002c90300ea67d1`**
    * 這是特定裝置的 **Port GUID**。
    * 這可能對應到架構圖中的 **Server 2 (Storage)**。只有擁有這個 GUID 的網卡才能連接此網路。

* **`0x0002C9030073D2A8`**
    * 這是另一個特定裝置的 **Port GUID**。
    * 這可能對應到 **Switch (Gateway)** 或是 **Server 3 (Compute)** 的埠口。

#### 3. 結尾符號

* **`;` (分號)**
    * 代表這一行設定結束。語法上不可省略。

#### 為什麼要這樣寫？ (技術意涵)

這是一種**安全性強化 (Security Hardening)** 的寫法。

1.  **先前範例 (`ALL=full`)：** 像是「開放式公園」，只要插上 InfiniBand 線的機器，預設都會被加入這個 Partition。這在實驗室很方便，但在企業環境不安全。
2.  **此範例 (指定 GUID)：** 像是「私人俱樂部」，門口有保全拿著名單核對。
    * 只有 **GUID 符合**清單的裝置，SM 才會發送 P_Key 給它。
    * 如果有人偷接一台未經授權的伺服器進來，即便他手動設定了 IP，因為他的 GUID 不在名單上，SM 根本不會讓他加入這個 P_Key 網路，底層連線會直接被拒絕。

#### 總結

建立一個名為 **Part2** 的分割區，P_Key 為 **0x8020**，啟用 **IPoIB** 功能。此分割區採白名單制，成員預設擁有 **Full** 權限。允許加入的成員只有：**SM 自己 (SELF)**、**GUID 為 ...d1 的裝置** 以及 **GUID 為 ...A8 的裝置**。

### 範例 2

`MyPartition=0x8001, ipoib : 0x0002c9030009db3f=full, 0x0002c90200262841=full;`

1.  **`MyPartition`**: 這是分割區的名稱 (可自訂)。
2.  **`0x8001`**: 這是 P\_Key 數值。
      * **0x0001**: Partition ID。
      * **0x8000**: 代表 Full Membership bit (最高位元為 1)。
3.  **`ipoib`**: 啟用 IPoIB 支援，讓這些節點可以在此 Partition 上設定 IP 位址。
4.  **`:` (冒號)**: 分隔設定與成員清單。
5.  **`0x0002c9030009db3f=full`**:
      * 這是第一台端點節點的 **Port GUID**。
      * **`=full`** 指定它擁有完整通訊權限。
6.  **`0x0002c90200262841=full`**:
      * 這是第二台端點節點的 **Port GUID**。
7.  **`;` (分號)**: 每一行設定結束必須加上分號。

這行指令建立了一種 繫結 (Binding) 關係：

**將硬體 GUID 為 0x0002c9030009db3f 和 0x0002c90200262841 的這兩個端口，加入到 P_Key 為 1 (設定值為 0x8001) 的分區中，並賦予它們 Full (完全通訊) 的權限。**

這確保了這兩個節點可以在這個特定的邏輯網路 (0x8001) 中互相傳輸資料，同時與 Fabric 上的其他非成員節點隔離。


[nvidia | Understanding-and-Setting-Up-InfiniBand-Partitions](https://enterprise-support.nvidia.com/s/article/Understanding-and-Setting-Up-InfiniBand-Partitions)
[nvidia | howto-configure-ipoib-networks-with-gateway-and-multiple-pkeys](https://enterprise-support.nvidia.com/s/article/howto-configure-ipoib-networks-with-gateway-and-multiple-pkeys)
[nvidia | in-between-ethernet-vlans-and-infiniband-pkeys](https://enterprise-support.nvidia.com/s/article/in-between-ethernet-vlans-and-infiniband-pkeys)
[nvidia | howto-use-infiniband-pkey-membership-types-in-virtualization-environment--connectx-3--connectx-3-pro-x](https://enterprise-support.nvidia.com/s/article/howto-use-infiniband-pkey-membership-types-in-virtualization-environment--connectx-3--connectx-3-pro-x)
