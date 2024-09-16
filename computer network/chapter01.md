# 計算機網路和 Internet
## 網路邊緣
### 接入網
1. 家庭接入 (Home Access)

- DSL(Digital Subscrible Line)
    - 住戶通常提供本地電話接入的電信公司獲取此網路

![](https://i.imgur.com/6wOcHIQ.png)

- 電纜 (Cable)
    - 利用有線電視公司現有的有線電視基礎
    - 住戶提供有線電視公司獲得了此網路

![](https://i.imgur.com/ZlnVyRz.png)

- FTTH(Fiber To The Home)
    - 從本地中心直接到家庭提供一條光纖路徑
- 兩種體系結構: AON(Active Optical Network)、PON(Passive Optical Network)

![](https://i.imgur.com/OL3JOdY.png)

- 撥號 (Dial-Up)

- 衛星 (Satellite)

- 5G 固定式無線
    - 高速存取，沒有安裝成本
    - 不需要搭建從電信公司到家庭的布線系統

2. 企業或家庭接入

LAN 的應用
- Ethernet
- WiFi

![](https://i.imgur.com/rsnJRCk.png)

3. 廣域無線接入

移動設備越來越多，並在移動間發送訊息、上傳照片等。這些設備應用了與蜂窩移動電話相同的無限基礎設施。用蜂窩網提供商的基站發送和接收封包。

- 3G
- LTE 4G
- 5G

![](https://i.imgur.com/PkRxz0h.png)

### 物理媒介

1. 雙絞銅線
    - 便宜、常見
2. 同軸電纜
    - 銅導體組成
3. 光纖
4. Terrestrial Radio Channels 
5. 衛星無線電信通到
    - 通訊常使用的衛星
        - 同步衛星(geostationary statellite)
        - 近地軌道(Low-Earth Orbiting)
### 網路核心
#### 封包交換
- 在網路應用中，端系統彼此交換 **message**
    - 一張圖片；一則訊息
- 將原來長度的 **message** 劃分較小的數據，稱為 **packet(封包)**
- 每個 packet 都透過通訊鏈路與封包交換(Packet switching) 傳送
    - router、link-layer switch 
- Packet 以等於該鏈路**最大傳輸速率**的速度傳輸通過通訊的鏈路
    - 某來源端系統或是 Packet switch 經過一條鏈路發送一個  $L$ bit 的 packet，鏈路傳輸速率為 $R\ bit/s$，則傳輸該 packet 的時間為 $L/R$ 秒

1. 儲存轉發傳輸(store-and-foreard transmission)

大多封包交換機在鏈路輸入端使用**儲存轉發傳輸**。其指在交換機開始向輸出鏈路傳輸該封第一個 bit 之前，必須接收到整個封包(Packet)

![](https://i.imgur.com/3EQtPOU.png)

從上圖看出該路由器任務是，將封包從一條輸入鏈路轉移到另一條鏈路。在某一個時間，來源端已經傳輸了封包一部分，封包 1 先抵達路由器。因該路由器有**儲存轉發**機制，因此在當下還不能將接收到的 bit 傳輸，要先緩存該封包的 bit，直到接收完該封包所有 bit，才能向目的端做轉發該封包動作。

路由器再轉發前需要接收、儲存和處理整個封包。

2. 列隊延遲和封包遺失(Queuing Delays and Packet Loss)

- 封包交換機具有**輸出緩存(output buffer)** 或稱**輸出列隊(output queue)**
    - 負責儲存路由器準備轉發往哪條鏈路的封包
    - 會有**儲存轉發延遲**和輸出緩存的**列隊延遲(queuing delay)**
        - 延遲非固定。取決於網路壅塞程度
- 封包遺失
    - 緩存是有限的，一個到達的封包可能發現該緩存被其它等待傳輸的封包佔滿了，**到達的封包**或**已經列隊的封包**之一將被丟棄

![](https://i.imgur.com/gZXiEMO.png)

假設 A 和 B 像主機 E 發送封包。主機 A 和 B 通過 100 Mbps 的乙太網路向第一個路由器發送封包。該路由器將封包轉發至 15 Mbps 的鏈路。在某個時間間格內，如果封包到達路由器的到達率(每秒 bit)超過 15Mbps。這些封包再透過鏈路傳輸之前，將在鏈路輸出緩存中列隊，則路由器出現壅塞。

3. 轉發表和路由協定 (Forwarding Tables and Routing Protocols)
- 每台路由器都會有**Forwarding Tables**
    - 將目的位置映射為輸出鏈路，路由器會利用此表進行轉發
- **路由協定**負責管理**Forwarding Tables**
    - 使用最短路徑配置路由器轉發表


### packet 交換中的時間延遲、丟包和吞吐量
#### packet 交換中的時間延遲概述
在本機與某服務溝通，在到達該服務時沿路會受到不同類型的時間延遲。最為重要的是
- 節點處理延遲（nodal processing delay）
- 排隊延遲（queuing delay）
- 傳輸延遲（transmission delay）
- 傳播延遲（propagation delay）

以上延遲加總起來是節點總延遲。

##### 延遲類型

![](https://i.imgur.com/VO3payv.png)

1. 處理延遲
- 檢查 packet 表頭和決定將 packet 導向何處所需的時間是**處裡延遲**的一部分。

包括檢查從上游節點向路由器 A 傳輸這些  packet 過程發生的 packet 中的 bit-level 錯誤所需的時間。

2. 排隊延遲
- 在隊列中，packet 在等待傳輸到鏈路上時經歷**排隊延遲**
- 該列隊為空，並無其餘 packet 正在傳輸，則該 packet 排隊延遲為 0；相反則該延遲會提升

3. 傳輸延遲
- 僅當所有已經到達的 packet 被傳輸後，才能傳輸剛到達的 packet

用 $L$ 表示該 packet 長度，$R\ b/s$ 表示從路由器 A 到 B 的鏈路傳輸速率。

10 Mbps，速率 $R = 10 Mbps$

- **傳輸延遲**是 $L/R$

4. 傳播延遲
- 從該鏈路的起點到路由器 B 傳播所需要的時間是**傳播延遲**。從上圖一個 bit 被推向鏈路，該 bit 需要向路由器 B 傳播。
- **傳播延遲**是 $d/s$，$d$ 為 A 到 B 距離，$s$ 該鏈路傳播速率
- **傳播延遲**  取決於物理媒介，光纖或雙絞線

5. 傳輸延遲和傳播延遲比較
- 傳輸延遲是路由器推出 packet 所需時間，是 packet 長度和鏈路傳輸速率的函數
- 傳播延遲是一個 bit 從一談路由器到另一台路由器所需要的時間，是兩台路由器之間距離的函數，與 packet 長度和鏈路傳輸速率無關

![](https://i.imgur.com/lzY9Rth.png)

將收費站之間的公路路段當成鏈路，假設汽車以 $100km/h$ 速度在公路上行駛（傳播）。以 10 輛車當作一個車隊，認定一台車為一個 bit，該車隊為一個封包。該收費站假定以每輛車 $12s$ 的速度服務一輛車（傳輸）。該車隊在轉發之前，必須儲存在收費站。
該收費站將整個車隊推送至公路所需時間是 $10輛車/(5輛車/min) = 2 min$，類似於一台路由器**傳輸延遲**。一輛車從一個收費站出口行駛到下一個收費站所需要的時間是 $100km/(100km/h) = 1h$，相似**傳播延遲**。因此，該車隊儲存在收費站前到該車隊儲存至下一個收費站前的時間是傳輸延遲和傳播延遲總和，本例為 $62 min$。

另 $d_{proc}$ 為處裡延遲、$d_{queue}$ 為排隊延遲、$d_{trans}$ 為傳輸延遲、$d_{prop}$ 為傳播延遲，則節點得總延遲為

$d_{nodal}=d_{proc}+d_{queue}+d_{trans}+d_{prop}$

每個場景延遲的成分都不同。

#### 排隊延遲和丟包
- 排隊延遲對不同的封包可能是不同的

因為以最後一個 packet 來說他要等待前 n 個 packet 傳輸

另 $a\ pkt/s$ 表示 packet 到達列隊平均速率

另 $R\ b/s$ 為傳輸速率

另 $L$ bit  組成為所有 packet

則 bit 到達列隊的平均速率為 $La\ bps$

假設該列隊非常大，

ratio $L_a/R$ 稱做 **traffic intensity(流量強度)**

當 $La\ bps > 1$，則到達列隊的平均速率超過該列隊傳輸出去的速率。

:::info
in traffic engineering is: Design your system so that the traffic intensity is no greater than 1.
:::

![](https://i.imgur.com/EuGWYIx.png)

隨著流量強度接近於 1，平均排隊長度越來越長。

##### 丟包
鏈路前的列隊是有限的，隨著流量強度接近 1，到達分組將發現列隊已滿，沒地方儲存因此被路由器 drop 該 packet，則該 packet 會 lost。而丟失可能基於端到端的原則而重傳，確保數據的完整性。

>一個節點的性能常部根據延遲來度量，而根據丟包機率來度量
>

#### 端到端延遲
假設來源主機和目的端主機之間有 $N-1$ 台路由器。並且該網路目前無壅塞情況(可忽略隊列的延遲)。每台路由器和來源主機的處裡延遲是 $d_{proc}$，每台路由器和來源主機的輸出速率是 $R bps$，每條鏈接的傳播延遲是 $d_{prop}$。節點延遲累加，得到端到端延遲

$d_{end-end} = N(d_{proc} + d_{trans} + d_{prop})$

$d_{trans}=L/R$，$L$ 是封包長度。

tracerout 可觀察

### 吞吐量
想像 A 到 B 主機，透過網路傳遞文件。在任何時間瞬間的**瞬時吞吐量(instantaneous throughput)** 是主機 B 接收到該文件的速率(bps 計算)。如果該文件為 $F$ bit，主機 B 接收到所有 $F$ bit 用了 $T$ 秒，則文件傳送的**平均吞吐量(average throughput)** 是 $F/T (bps)$

![](https://i.imgur.com/GCPakft.png)

$R_s$ 為鏈路速率，server 和 route 

$R_c$ 為鏈路速率，route 和 client 之間

如果 $R_s < R_c$，則在給定的吞吐量 $R_s (bps)$ 下，該 server 傳遞的 bit 資料會順暢的通過 route，並以 $R_s (bps)$ 速率抵達 client。

如果 $R_c < R_s$，route 無法像接收速率一樣快的轉發 bit 資料，bit 資料會以 $R_c$ 速率離開 route，這種情況持續的話，該 route 中等待傳輸給 client 的`backlog of bits` 會不斷增加，這是一種糟糕的情況。

對於上述，其吞吐量為 $min\{R_c, R_s\}$，就是所謂的 `bottleneck link` 的傳輸速率。

現在可以評估說從 server 到 client 傳輸一個 $F$ bit 的資料所需要的時間是 $F/min\{R_c, R_s\}$。

舉例來說下載一個 $F=32 \times 10^6$ bit 的 mp3，server 有 $R_s= 2Mbps$ 的傳輸速率，並且自己有一條 $R_c = 1Mbps$ 的接入鏈路。該文件傳輸速率需要 $32$ 秒。但這秒數不包含儲存轉發、處裡延遲和協定等問題。

在上圖的 b，server 和 client 之間有 $N$ 條的鏈路網路，這 $N$ 條傳輸速率分別為 $R_1, R_2, ..., R_N$，同樣對一個 $F$ bit 資料，server 到 client 傳輸吞吐量是 $F/min\{R_1, R_2,..., R_N\}$，也是 `bottleneck link`  問題。

![](https://i.imgur.com/wiQg6H0.png)

對於圖 1.20 的 b，假定 $R_s = 2Mbps$，$R_c = 1Mbps$，$R=5Mbps$(核心網中一條所有 10 個下載通過的鏈路)，共用的鏈路為 10 個下載平等劃分它的傳輸速率。此時瓶頸不再接入網中(route 到 client 之間)，而是在核心網中的共享鏈路，此瓶頸提供了每個下載 $500 kbps$ 的吞吐量，因此每個下載的端到端吞吐量減少至 $500kbps$。


**吞吐量取決於數據流過鏈路的傳輸速率或者干擾流量(多個不同流量都經由同一條核心鏈路傳遞給 client，在大的傳輸速率終究也是會有瓶頸)。**

## 協定層和服務模型

##### 協定分層
![](https://i.imgur.com/ymUZUIA.png)

- Application
    - 此層訊息封包稱**message**
- Transport
    - TCP
    - UDP
    - 此層封包稱**segment**
- Network
    - 此層封包稱**datagram**
- Link
    - 將封包從一姑節點移動至路徑上的下一個節點
    - 此層封包稱**frame**
- PhysicL
    - 將 frame 中的一個個 bit 從一個節點移動至下一個節點

![](https://i.imgur.com/dVdwgOD.png)

上圖說明了 **封裝(encapsulation)**。一個 `Application` 上的 `message` 被傳送給 `Transoprt`，並添加 `segment` 表頭，形成了傳輸層訊息，以此類推。
