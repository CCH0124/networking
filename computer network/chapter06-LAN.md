# 區域網路
## Link-Layer Addressing and ARP
##### MAC 地址
- 並非主機或路由器有鏈路層地只，而是它們的適配器(網路接口)具有鏈路層地址
- 鏈路層交換器並不具有它們的接口相關聯的鏈路層地址
    - 鏈路層交換器任務是在主機和路由器之間
- 適配器的 MAC 是扁平結構，不論適配器到哪都不會變化
- 適配器收到 frame 會檢查其 MAC 地址，不匹配將會丟棄
- MAC 廣播地址為 FF-FF-FF-FF-FF，讓區網的適配器接收並處理它打算要發送的 fram
![](https://i.imgur.com/dZ4JehG.png)

上圖的 MAC 地只被表示為一對 16 進制數
##### Address Resolution Protocol (ARP)
- 將一個 IP 地址解析為一個 MAC 地址
- 而每台主機或路由器在記憶體中會有一個 ARP 表
    - AP 與 MAC 的對照
    - 其也包含 TTL 值，指示從表中刪除每個映射的時間
![](https://i.imgur.com/gtstv6F.png)

![](https://i.imgur.com/zNPpOs3.png)

##### Sending a Datagram off the Subnet

![](https://i.imgur.com/95rmicl.png)

上圖是跨越子網的問題，需透過路由器

##  Ethernet
![](https://i.imgur.com/YZus2Xn.png)
上圖為乙太網路結構

- Data field (46 to 1,500 bytes)
    - 承載 IP 封包
    - 最大傳輸單元(MTU) 是 1500 bytes
        - 超過則分片
    - 最小字段為 46 bytes
        - 小於則填充
- Destination address (6 bytes)、Source address (6 bytes)
    - 適配器 MAC 位置
- Type field (2 bytes)
    - 允許乙太網路付用多種網路層協定
    - 該類型字段和網路層封包中的協定字段、傳輸層 segment 字段的端口號相似
        - 所有這些字段都是為了把一層中的某協定與上一層的某協定結合
- Cyclic redundancy check (CRC) (4 bytes)
    - 使得接收適配器檢測 frame 是否引入了差錯
- Preamble (8 bytes)
    - 前 7 個字段用於喚醒接收適配器
    - 前同步碼第 8 個字節的最後兩個 bit，警告適配器，重要的內容要來了

當丟棄了乙太網路的 frame 而產生間隙，另一端主機的應用會看見此間隙嗎 ?該應用為 UDP，則另一端主機會看到數據中間隙，如果是 TCP 則另一端不會確認包含在丟棄 frame 的數據，從而引起源主機的 TCP 重傳。當 TCP 重傳時，數據最終將回到曾經丟棄它的適配器。

## 鏈路層交換機
### 交換機轉發和過濾
- filtering
    - 決定一個 frame 應該轉發到某個接口還是應當將其丟棄的交換器功能
- forwarding
    - 決定一個 frame 該被導向哪個接口，並把該 frame 移動到那些接口的交換器功能
- 而 filtering 和 forwarding 借助於 `switch table` 完成

![](https://i.imgur.com/uDF50A0.png)

上圖為 switch table 的內容，有 MAC 地址、通向該 MAC 地址的交換器接口和表項放置表的時間


### 自學習
- 交換機中的表是自動、動態和自治建立，然而交換機是即插即用設備，不需管理員的干預
- 交換機為全雙工，能同時接發送

### 性質
- 相較於集線器或星狀拓譜，它**消除碰撞**
    - 交換器最大聚合頻寬為所有接口速率之和
- 異質鏈路
    - 交換器鏈路彼此隔離，因此區網中不同鏈路能夠以不同的速率運行且能夠在不同媒介上
- 管理
    - 安全性
        -  switch poisoning
            -  偽造 MAC
### 交換器與路由器比較
- 路由器
    - 網路地址轉發封包
- 交換器
    - MAC 地址轉發

![](https://i.imgur.com/uJQuzKv.png)


## Virtual Local Area Networks (VLANs)

![](https://i.imgur.com/oMgATSX.png)

從上圖可發現三個缺點
- 缺乏流量隔離
    - 廣播流量必須跨越整個機構網路，限制該流量能改善效能，同時也可以有隱私和安全的目的
- 交換器的無效使用
    - 單一台的的交換器不能提供流量隔離
- 管理用戶
    - 當一個員工在不同組別移動，需改變配線，當有跨多組別的員工會使問題更加困難


然而上述問題可透過 VLAN 的交換器解決，其將單一的區網定義多個虛擬區網。

VLAN 透過端口劃分多個組別，而每一個組別形成該組的廣播域。下圖顯示 2-8 端口為一個 VLAN，9-15 端口為另一個 VLAN。而未表明的端口屬於一個默認的 VLAN。其交換機也會維護著這張 VLAN 的映射表，交換器的軟體僅能夠讓在同一 VLAN 下的端口相互交換訊息。

![](https://i.imgur.com/Pxr22IM.png)

下圖為連接兩個 VLAN 的方式，但此方式無擴展性，都需要按照 VLAN 個數使用該個數個端口進行互聯下圖 a。更具有擴展性的方式是使用 **VLAN trunking**，如下圖 b，它可以乘載所有 VLAN 的訊息。
![](https://i.imgur.com/HpHvCBZ.png)

但如何知道它屬於哪個 VLAN 呢 ? IEEE 定義了 *802.1Q* 的協定，如下圖，從標準乙太網路中加進 4 byte *VLAN tag* 的標識組成該協定封包格式，該標識乘載該 frame 屬於的 *VLAN tag*。

VLAN tag 將會從原端的 VLAN trunking 加進 frame，解析後再由接端的 VLAN trunking 進行刪除

![](https://i.imgur.com/ihIyOeu.png)

