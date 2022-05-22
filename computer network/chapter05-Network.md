# 網路層：數據平面
## 網路層概述
![](https://i.imgur.com/Mshu90D.png)

H1 和 H2 有兩台主機，在這兩個端點之間有許多的路由器。如果 H1 要發送給 H2 訊息，這之間的路由器會使用網路層的功能。H1 中的網路層取得來自 H1 傳輸層的 `Message segment`，並將其封裝成一個數據 `datagrams`，接著向相鄰路由器 R1 發送該 `datagrams`，接收端 H2 則以反過來的方式去解析。

每台路由器的**數據平面**的主要功能是從其輸入鏈路向其輸出鏈路轉發 `datagrams`；**控制平面**地者要功能是協調這些本地的每個路由器轉發動作，讓 `datagrams` 沿著來源和目的地主機之間的路由器路徑最終進行端到端傳送。

### 轉發和路由：數據平面和控制平面
從上述可以感覺出網路層是將封包從發送端送達到目的端。但要有這種模式需要使用兩種重要的網路層功能

- Forwarding（轉發）
    - 當一個封包底達到某路由器的一條輸入鏈路時，該路由器必須將該封包移動到適當的輸出鏈路。
    - 是數據平面唯一實現的功能
- Routing（路由）
    - 當封包從發送端流向接收方時，網路層必須決定這些封包所採用的路由或路徑。
    - 計算這些路徑的演算法被稱為**routing algorithms**

每台路由器會有個 **forwarding table**。路由器會檢查到達封包表頭，並對應其儲存在轉發表項中的值，接著指出該封包將被路由器的哪個輸出鏈路接口做轉發。如下圖

![](https://i.imgur.com/d182DsA.png)


##### 1. 控制平面
轉發表顯示了路由和轉發之間的重要關係。從上圖可以知道，路由演算法運行在每台路由器中，每台都包含轉發和路由兩種功能。要配置該轉發表，可以由人去做操作，但靈活性不高。

##### 2. 控制平面 SDN 方法

![](https://i.imgur.com/BZN5ekj.png)

上圖顯示從路由器物理上分離的另一種方法，遠端的控制器計算和分發轉發表以供每台路由器使用。控制平面路由與實體的路由器是分離的，該路由器僅執行轉發，而遠端控制器計算並分發轉發表。

該圖的控制平面方法是軟體定義網路（software-defined networking, SDN）的本質，因計算轉發表並與路由器交互的控制器是用軟體實現。

### 網路服務模型

網路服務模型（network service model）定義了封包在發送與接收端系統之間的端到端運輸特性。這些服務可能包含以下：
- 確保交付
    - 確保封包將最終到達目的
- 具有延遲上限的確保交付
    - 不僅確保封包的交付，而且在特定的主機到主機時間上限內（100ms）交付
- 有序封包交付
    - 確保封包以它們發送的順序到達目的地
- 確保最小頻寬
    - 模仿發送和接受主機之間一條特定的 bit 率（例如 1Mbps）的傳輸鏈行為。
    - 只要發送主機以低於特定 bit 率的速率傳輸 bit（作為封包的組成部分），則所有封包最終會交付到目的主機。
- 安全性
    - 網路層能夠在源加密所有 `datagrams` 並在目的地解密這些封包，從而對所有運輸層 `segments` 提供機密性。

這以上只是部分列表，還有無數種可能的服務變種。

Internet 的網路層提供了**盡力而為服務（best-effort service）**。傳送的封包不能保證以它們的發送順序被接收，也不能保證最終交付；也不能保證端到端延遲，甚至是最小的頻寬。

## 路由器工作原理
![](https://i.imgur.com/acthibm.png)

- input port
    - 在路由器中執行終結入物理鏈路的實體層功能。
    - 還要與位於入鏈路遠端的數據鏈路層交互來執行數據鏈路層功能，顯示在中間方塊中
    - 輸入端口還要執行查找功能，最右側方框
        - 透過查詢轉發表決定路由器的輸出端口
    - 控制封包從輸入端口轉發道路由選擇處理器
- Switching fabric
    - 將路由器的輸入端口連接到它的輸出端口
    - 包含在路由器中
- Output ports
    - 儲存從 `Switching fabric` 接收的封包
    - 透過執行必要的鏈路層和實體層功能在輸出的鏈路上傳輸這些封包
- Routing processor
    - 執行控制平面功能
    - 執行 `routing protocols`
    - 維護路由表與關聯鏈路狀態訊息，並未該路由器計算轉發表
    - 在 SDN 中負責與遠端控制器通訊，目的是接收控制器計算的轉發表項，並在路由器的輸入端口安裝這些表項
    - 網路管理功能[5.7]

當數據平面以奈秒時間的尺度運行時，路由器的控制功能以毫秒或秒時間尺度運行，這些控制功能包括執行路由選擇協定、對上線或下線的連接鏈路進行響應、與遠端控制器通訊（SDN）和執行管理功能。因而這些 `Control plane` 的功能通常用軟體實現並在路由選擇處理器（通常為傳統 CPU）上執行。

虛線部分表示 `Routing processor` 到輸入線路卡，轉發決策能在每個輸入端口本地做出，避免集中式的處裡瓶頸。

### Input Port Processing and Destination-Based Forwarding
![](https://i.imgur.com/mmU7yT7.png)

- 在輸入端口中執行的查找對於路由器運行是至關重要的
    - 路由器使用*轉發表*來查找輸出端口，使到達的封包能經過 `switching fabric` 轉發到該輸出端口
    - 轉發表是 `routing processor` 計算和更新的（透過 `routing protocol` 與其他路由交互 ），或者接收來自遠端 SDN 控制器的內容

![](https://i.imgur.com/bN3q2K3.png)

- 路由器使用封包目的地址的**prefix**與該表中的項目進行匹配，如果存在，則路由器與該匹配相關連的鏈路轉發封包
    - 多個匹配時，使用 `longest prefix matching rule`[4.3]
    - 但查找這些表一定是要奈秒等級，DRAM、SRAM、TCAM 等來實踐
- 一旦確定了封包的輸出端口，該封包就能轉發進入 `switching fabric`
    - 但這有可能會有阻塞問題，當出現時，被阻塞的封包需要在輸入端口處排隊，並等候調度
- 透過上述查找目的 IP 加上送封包至`switching fabric`（動作），是一種**匹配加動作**抽象的特定情況
    - 此抽象不僅在路由器中，也存在於這些 ` link-layer switches `、`firewall`、`NAT` 

### Switching

![](https://i.imgur.com/RazCnSf.png)
![](https://i.imgur.com/VCVCb6n.png)

`switching fabric` 位於一台路由器的核心，因為正是透過這種 `switching fabric`，封包才能實現的從一個輸入端口轉發到一個輸出端口。上圖為許多交換的實現方式。

- Switching via memory.
    - 在輸入端口與輸出端口之間的交換是在 CPU（`routing processor`）的直接控制下完成的
        - 像傳統作業系統 I/O 設備一樣
    - 如過記憶體頻寬為每秒可寫進記憶體或從記憶體讀出最多$B$封包，則總的轉發吞吐量（封包從輸入端口傳送到輸出端口的總速率）必然小於$B/2$
- Switching via a bus. 
    - 輸入端口經一根共享總線將封包直接傳送到輸出端口，不須 `routing processor` 干預
    - 輸入端口位封包提供一個交換機內部標籤（header），指示本地輸出端口，使封包在總線上傳送到輸出端口
        - 但所有輸出端口會接收到封包，唯有匹配該標籤端口才會包存該封包
    - 因為只有一個總線，每次只能只有一個封包跨越，當多個封包同時到達路由器，除了一個封包外，其餘都要等待
        - 速率受限制
- Switching via an interconnection network.
    - 如圖 Crossbar 所示，交叉點透過`switching fabric`能夠隨時開啟和閉合
        - 當封包到達 A 端口時，需要轉發到端口 Y 時，交換機閉合總線 A 和 Y 交叉點，接著 A 在其總線上發送該封包，該封包僅由 Y 接收，此時 B 端口也能夠轉發到 X
    - 與前面兩者交換方式不同，此方式能夠**並行轉發**多個封包，是**nonblocking**
        - 但不同輸出端口要轉發到同端口時，則有一方必須再輸入端等待

More sophisticated interconnection networks use multiple stages of switching elements to allow packets from different input ports to proceed towards the same output port at the same time through the **multi-stage switching fabric**. See [Tobagi 1990] for a survey of switch architectures. The Cisco CRS employs a **three-stage non-blocking switching strategy**. A router’s switching capacity can also be scaled by running multiple switching fabrics in parallel. In this approach, input ports and output ports are connected to N switching fabrics that operate in parallel. An input port breaks a packet into K smaller chunks, and sends (“sprays”) the chunks through K of these N switching fabrics to the selected output port, which reassembles the K chunks back into the original packet.

### Output Port Processing

![](https://i.imgur.com/klhZn4Z.png)

如上圖所示，輸出端口處裡取出以存放在輸出端口記憶體中的封包並將其發送到輸出鏈路上。

### Where Does Queuing Occur?
- 上面 switching 的技術，可以知道說在輸入端和輸出端口處都可以形成封包隊列。排隊位置和程度將取決於*流量負載*、*交換結構*的*相對速率*和*線路速率*。
- 隨著隊列增長，路由器的緩存將會耗盡，當記憶體不夠時可用於儲存到達的封包時將會出現**丟包(packet loss)**

##### Input Queueing

![](https://i.imgur.com/4YBd8pX.png)

在輸入隊列前端的兩個封包(深色)要轉發同一個右上角輸出端口。假設當 switch fabric 決定發送左上角隊列的封包，則左下角隊列的封包必須等待，其中該淺色封包也需要等待，即時右中側輸出端口*無競爭*。

上述所發生現象叫做輸入排隊交換機中的**head-of-the-line (HOL) blocking(線路前部阻塞)**，即在一個輸入隊列中排隊的封包必須等待透過 switch fabric 轉發（即時為空閒），因為它被位於線路前部的另一個封包所阻塞。

##### Output Queueing
當每有足夠的記憶體來緩存一個封包時需要作決定：
- drop-tail
    - 要麼刪除一個或多個已排隊的封包為新來的封包騰出空間
- 在某些情況下，仔緩存填滿之前便丟棄一個封包為最有利，這可隊發送方提供一個*壅塞訊號*
- active queue management (AQM) 
- Random Early Detection (RED)

![](https://i.imgur.com/AanWTsI.png)

在時刻$t$，每個輸入端口都到達了一個封包，每個封包都要往最上側的輸出端口。一個時間單位後，所有三個初始封包都被傳誦到輸出端口，並排隊等待傳輸。在下一個時間單位，有兩個封包已到達交換機的輸入端，有一個封包要轉發至最上策的輸出端口。

上面描述的狀況後，輸出端口的**封包調度(packet scheduler)**，在這些隊列封包中選擇一個封包傳輸。

假設要使用緩存方式來吸收流量負載的波動，想必緩存的量要多少?
- 緩存數量應當等於平均往返時間(RTT)乘以鏈路的容量
    - 基於相對少量的 TCP 流的排隊動態特性分析取得
    - RFC3439
- Fraleigh 2003
    - 緩存數量 $B=RTT \times C/\sqrt{N}$
        - B 緩存數量
        - C 鏈路的容量 
        - N TCP流流過一條鏈路時

### 封包調度(packet scheduler)

##### First-in-First-Out (FIFO)

![](https://i.imgur.com/GiHUROK.png)

調度規則按照封包到達輸出鏈路隊列的相同次序來選擇封包在鏈路上傳輸。

![](https://i.imgur.com/UvJpPHW.png)

上圖，封包的到達由尚不時間線上帶編號的箭頭來指示，用編號指示了封包到達的次序。各個封包的離開表示在下部時間線的下面，封包在服務中花費時間是透過這兩個時間線之間的陰影矩形來指示的。

##### Priority Queuing
![](https://i.imgur.com/hiIzCw0.png)

在同一優先權類的封包之間的選擇通常以 FIFO 方式完成。

![](https://i.imgur.com/wVLwfYx.png)

上圖封包1、3和4屬於高優先權，封包2和5是低優先權。其中在封包1、3後傳輸低優先權2是因為該時間高優先權隊列為空。

##### Round Robin and Weighted Fair Queuing (WFQ)
Priority Queuing 的類之間部存在嚴格的服務優先權，循環調度器在這些類之間輪流提供服務，類別1封包被傳送，接著是類別2被傳送以這樣的方式不斷傳送。

一個所謂**保持工作隊列( work-conserving queuing)** 規則在有封包排隊等待傳輸時，部允許鏈路保持空閒。當尋找給定類的封包但是沒也找到時，保持工作的循環規則將立即檢查循環序列中的下一個類。

![](https://i.imgur.com/X1KEaE4.png)

上圖中封包 1、2和4屬於第一類，封包3和5屬於第二類。

而加權公平排隊(Weighted Fair Queuing)，廣泛實現在路由器中。下圖為該模式進行描述。其中，到達的封包被分類並在合適的每個類的等待區域排隊。與 Round Robin 方式一樣。

![](https://i.imgur.com/Gb50gyu.png)

而不同之處在於，每個類在任何時間間格內可能收到不同數量的服務。每個類別 $i$ 被分配一個權重 $w_i$，在最壞情況，即所有的類都也封包排隊，第 $i$ 類扔然保證分配到頻寬的$w_i /(\sum w_j)$ 部分。因此對於一條傳輸速率為 $R$ 的鏈路，第 $i$ 類總能獲得至少為 $R \centerdot w_i /(\sum w_j)$ 的吞吐量。這是理想化情況，沒有考慮這樣的事實，封包是離散單元，並且不能打斷一個封包的傳輸來開始傳輸另一個封包。

# IPv4 封包格式

![](https://i.imgur.com/OYDM5lF.png)

- Version
    - IP 協定版本，透過版本號，路由器能夠確定如何解釋 IP 數據包的剩餘部分
- Header Length
    - 一個 IPv4 數據包可包含一些可變量的選項，故需要用這 4 bits 來確定 IP 數據包中載荷實際開始的地方，但大多數不包含選項，所以一般的 IP 數據包具有 20 byte 的首部
- Type of service
    - 讓不同類型的 IP 數據包能相互區別
        - 低延遲
        - 高吞吐
    - 提供特定等級的服務是對路由器確定和配置的策略問題
- Datagram length
    - IP 數據包總長度(首部加上數據)，以 bytes 計算
    - 為 16 bit，理論最大為 65535 bytes
        - 數據包很少有超過 1500 bytes，該長度能夠容納`Ethernet frame` 載荷字段的最大長度
- Identifier, flags, fragmentation offset
    - 與 IP 分片(IP fragmentation)有關
    - IPv6 部允許路由器上對封包分片
- Time-to-live
    - 確保數據包不會永遠在網路中循環
    - 每當一台路由器處理數據包時，該字段值會減 1，當減到為 0，則該數據包將丟棄
- Protocol
    - 通常僅當一個 IP 數據包到達其最終目的地時才會使用
    - 該值表示 IP 數據包的數據部分應交給哪個運輸層的協定
        - 6 表示 TCP
        - 17 表示 UDP
        - [IANA](https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml)
    - 相似於運輸層中 port 號的作用
- Header checksum
    - 用於幫助路由器檢測收到的 IP 數據包中的 bit 錯誤
    - 其計算是首部 2 bytes 當作一個數，用反碼算數對這些數求和
        - 當錯誤時會丟棄
    - 為什麼 TCP/IP 在第四層與第三層都執行錯誤檢測 ?
        - 第三層只針對 IP 首部計算，而第四層是針對 TCP/UDP 區段(segment)計算
        - TCP/UDP 和 IP 這兩層不一定要相同協議棧上，ATM 上可運行 TCP/UDP 而 IP 不定要傳遞給 TCP/UDP
- Source and destination IP addresses
    - 當來源生成數據包時，它在 Source IP 插入它的地址，而 destination IP 則是最終目的的地址
    - 來源主機通常會以 DNS 決定目的地址
- Options
    - 允許字段首部(IP header)被擴展
    - 這會導致一台路由器處理一個 IP 數據包所需的時間變化很大
    - IPv6 以去掉 IP 選項
- Data (payload)
    - 數據包存在的首要理由
    - IP 數據包中的數據字段包含要交付給目的地的傳輸層區段(segment)，當然不限於該層 TCP 或 UDP

## IPv4 數據包分片
- 並不是所有鏈路層協定都能承載相同長度的網路層封包
    - 乙太網路不能超過 1500 bytes
    - 某些廣域網路可乘載不超過 576 bytes 的數據
- 一個鏈路層能承載的最大數據量稱作**maximum transmission unit (MTU)**
    - 嚴格限制 IP 數據包的長度
    - 然而發送方到目的地每段鏈路都有不同的鏈路層協定，有不同 MTU
        - 透過數據分片多個較小的數據包傳送，可稱為**片(fragment)**
- 而片到達目的地傳輸層以前需要*重新組裝*
    - 而如果組裝被應用在路由器上，會相當複雜且會帶來效能影響，因此最後放到端系統，而非路由器
    - 為了讓端能夠重組因此將 Identifier, flags, fragmentation offset 放在 IP 數據包 header 中
        - 為了讓目的地主機絕對相信他已收到數據包的最後一個片，最後的片將被標示為 flag 0，其它則為 1
        - 為了讓目的地主機確定是否遺失片，使用 offset 字段指定該片應放在初始 IP 數據包位置

![](https://i.imgur.com/Xl3tx6B.png)

上圖為 IP 分片與重新組裝

## IPv4 編址
- 一個 IP 地址與一個接口相關聯，而非與包括該接口的主機或路由器相關聯
    - 主機與物理鏈路之間的邊界稱作**接口(interface)**
- IP 地址長度為 32 bits(4 bytes)


![](https://i.imgur.com/nVZd9QZ.png)

上圖的路由器有三個接口，互聯 7 台主機。用 IP 術語來說，互聯三個主機接口與 1 個路由器形成一個**子網(subnet)**，IP 編址為三個接口分配 `223.1.1.0/24`，其 `/24` 稱為**網路遮罩(network mask)**，定義子網地址，`223.1.1.0/24` 由三個主機接口和一個路由器接口(`223.1.1.4/24`) 組成。


![](https://i.imgur.com/CInf74S.png)

但子網並不侷限於多台主機到路由器接口的網段，上圖中以三台路由器透過點對點方式互聯，上圖共有 6 個子網。其中直接將路由器連接到一對主機的是**廣播鏈路**。

地址分配策略被稱為**無類別域間路由選擇(Classless Interdomain Routing, CIDR)**，因此 32 bits 的 IP 地址被劃分兩部分 `a.b.c.d/x`，`x` 指示了第一部份的 bit 數，通常被稱為*前綴*。

一個地址剩餘 $32-x$ bit 可以認為是分配給組織內的設備，其這些設備都包含了共同的網路前綴，當內部路由器進行轉發時，會考慮這些 bit。

### 獲取地址
- ICANN
### 分配地址
- 手動
- DHCP(Dynamic Host Configuration)
    - 分配臨時 IP
    - 還會給予其它資訊
        - net-mask
        - DNS
        - Gateway
        - ...
 
