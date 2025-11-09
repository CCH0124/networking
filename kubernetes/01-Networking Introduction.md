# Networking Introduction

## OSI Model

OSI 模型是描述兩個系統如何透過網路通訊的概念性框架，將發送數據的職責分解為七個層次。

![](https://www.cloudflare.com/img/learning/ddos/what-is-a-ddos-attack/osi-model-7-layers.svg) from [cloudflare](https://www.cloudflare.com/en-ca/learning/ddos/glossary/open-systems-interconnection-model-osi/)

|Layer number |Layer name | Protocol data unit| Function overview |
|---|---|---|---|
|7|Application|Data|HTTP、SMTP、DNS、SSH ...|
|6|Presentation|Data|編解碼、資料壓縮、加解密|
|5|Session|Data|節點之間的數據交換：發送多少數據，何時發送更多|
|4|Transport|Segment；datagram|網路端點之間的數據分段(data segments)傳輸，分段、確認和復用(multiplexing)|
|3|Network|Packet|網路上的所有端點構建和管理尋址、路由和流量控制|
|2|Data Link|Frame|物理層連接的兩個節點之間傳輸數據幀(Frame)|
|1|Physical|Bit|透過介質發送和接收 bit 資料|

### Application

唯一一個直接與來自使用者的資料進行交互的層。該層不是實際應用程式所在的位置，也就是用戶端軟體應用程式不是此層的一部分，但它為使用它的應用程式負責通訊協定和資料操作，軟體依靠這樣來呈現資料。例如 HTTP、SMTP 或 Office 365。

![](https://cf-assets.www.cloudflare.com/slt3lc6tev37/koKt5UKczRq47xJsexfBV/c1e1b2ab237063354915d16072157bac/7-application-layer.svg) 
from [cloudflare](https://www.cloudflare.com/en-ca/learning/ddos/glossary/open-systems-interconnection-model-osi/)

### Presentation

在應用程式和網路格式之間進行轉換，負責準備資料以供應用程式層使用也就是此層可使資料呈現給需要使用的應用程式。該層允許兩個系統對數據使用不同的編碼，並在它們之間傳遞數據，傳入資料轉譯至接收裝置的應用程式層能夠理解的語法。

同時也負責壓縮其從應用程式層接收到的資料，然後將其傳送至第 5 層(Session Layer)，使傳輸的資料量降到最低，改善通訊速度和效率。

![](https://cf-assets.www.cloudflare.com/slt3lc6tev37/60dPoRIz0Es5TjDDncEp2M/7ad742131addcbe5dc6baa16a93bf189/6-presentation-layer.svg) 
from [cloudflare](https://www.cloudflare.com/en-ca/learning/ddos/glossary/open-systems-interconnection-model-osi/)

### Session

處理開啟和關閉兩個裝置之間的通訊，負責連接的雙工(是否同時發送和接收數據)。它還建立了執行*檢查點*、*暫停*、*重新啟動*和*終止會話*的流程。它建立、管理和終止本地和遠程應用程式之間的連接。

檢查點同步資料傳輸。例如，若正在傳輸 100 MB 檔案，此層可以每 5 MB 設定一個檢查點。若在傳輸 52 MB 後中斷連線或毀損，工作階段可從上一個檢查點繼續進行，亦即只剩下 50 MB 的資料需要傳輸。若沒有檢查點，整個傳輸就必須再次從頭開始。

![](https://cf-assets.www.cloudflare.com/slt3lc6tev37/6jFRnaZSuIMoUzSotZXYbG/cc7a47d2b3f8d3e77b9ffbdb8b8d5280/5-session-layer.svg)
from [cloudflare](https://www.cloudflare.com/en-ca/learning/ddos/glossary/open-systems-interconnection-model-osi/)

### Transport

在應用程式之間傳輸數據，為上層提供可靠的數據傳輸服務，**責處理兩個裝置之間的端對端通訊**。傳輸層藉由*流量控制*(判定最佳傳輸速度)、*分段*和*解分段*(desegmentation)以及*錯誤控制*來控制給定連接的可靠性(確保接收的資料是完整的)。一些協定是面向狀態和連接的，該層追蹤分段並重新傳輸那些失敗的分段、數據傳輸成功的確認，如果沒有發生錯誤則發送下一個數據。 

流層大致會從 Session 層取用資料，並在傳送至第 Network 層之前分解為分段(segments)的區塊，對於接收裝置上的傳輸層負責將分段重組為 Session 層可以取用的資料。

![](https://cf-assets.www.cloudflare.com/slt3lc6tev37/1MGbIKcfXgTjXgW0KE93xK/64b5aa0b8ebfb14d5f5124867be92f94/4-transport-layer.svg)
from [cloudflare](https://www.cloudflare.com/en-ca/learning/ddos/glossary/open-systems-interconnection-model-osi/)

### Network

此層實現了兩個不同網路之間的資料傳輸，同時保持服務質量。網此層執行**路由功能**(為資料尋找抵達目的地的最佳實體路徑)，在接收錯誤時執行*分段*和*重組*。路由器在這一層運行，藉由相鄰網路發送數據。此層在**傳送者的裝置上將來自傳輸層的分段分為較小的單位，稱為封包**，然後接收裝置上重組這些封包，

這些協定屬於此層，包括路由協定、多播組管理、網路層訊息、錯誤處理和網路層地址分配。

![](https://cf-assets.www.cloudflare.com/slt3lc6tev37/76JgEjycZl12c90UByKfJA/d6578bcd7b151c489e61f42227a45713/3-network-layer.svg)
from [cloudflare](https://www.cloudflare.com/en-ca/learning/ddos/glossary/open-systems-interconnection-model-osi/)

### Data Link

**負責同一網路上的主機到主機傳輸，不會跨越本地網路的邊界**，定義了建立和終止兩個設備之間連接的協定。此層在裝置之間傳輸數據，並提供檢測和可能糾正來自物理層(Physical Layer)的錯誤的方法。

此層獲取來自網路層(Network Layer)的封包，並分為較小的物件，稱為**Frame**。類似網路層，此層也負責處理網路內通訊的流量控制和錯誤控制，不同於傳輸層(Transport Layer)，傳輸層僅處理網路間通訊的流量控制和錯誤控制)。

![](https://cf-assets.www.cloudflare.com/slt3lc6tev37/3MR4mPOwaos80t1annw7BG/8ea1c59ccfa1baf6e9738773daa30450/2-data-link-layer.svg)
from [cloudflare](https://www.cloudflare.com/en-ca/learning/ddos/glossary/open-systems-interconnection-model-osi/)

### Physical

由插入交換機的以太網線直觀地表示。該層將數字位形式的數據轉換為電、無線電或光信號。將此層視為物理設備，如電纜、交換機和無線接入點。有線協議也在這一層定義。將資料轉換為位元(bit)的一層，亦即 1 和 0 的字串，兩個裝置之間的實體層也必須同意訊號約定，以便在兩個裝置上辨別 1 和 0。

![](https://cf-assets.www.cloudflare.com/slt3lc6tev37/3m1ZkcaaBYHoodrEO3brv2/2819c4db294631b5753cd55de0c01bd9/1-physical-layer.svg)
from [cloudflare](https://www.cloudflare.com/en-ca/learning/ddos/glossary/open-systems-interconnection-model-osi/)

## TCP/IP

![比較圖](http://fiberbit.com.tw/wp-content/uploads/2013/12/TCP-IP-model-vs-OSI-model.png) 
from [fiberbit](http://fiberbit.com.tw)

### Application

此層包括用於跨 IP 網路的**行程到行程通訊的協定**。應用層賴底層傳輸層(Transport Layer)協定來建立**主機到主機的數據傳輸**，傳輸層管理了網路通訊中的數據交換。

### Transport

`TCP` 和 `UDP` 是傳輸層的主要協定，**為應用程式提供主機到主機的通訊服務**。傳輸協議負責面向連接的*通訊*、*可靠性*、*流控制*和*多路復用*。

在 TCP 中，窗口大小(window size)管理流量控制，而 UDP 不管理擁塞流量，被認為是不可靠的。**每個端口標識負責處理來自網路通訊訊息的主機行程**，服務器上的每個端口都標識其流量，*發送方在本地生成一個隨機端口來標識自己*。

下圖為 TCP 狀態圖
![](https://upload.wikimedia.org/wikipedia/commons/f/f6/Tcp_state_diagram_fixed_new.svg) from [wikipedia](https://zh.wikipedia.org/zh-hk/File:Tcp_state_diagram_fixed_new.svg)

* **TCP 特性與標頭**：TCP 是面向連接 (stateful) 的可靠協定，透過序號 (Sequence Number) 和確認號 (Acknowledgment Number) 管理數據排序與重組，並使用視窗大小 (Window size) 進行流控制。埠號（16 位元）用於標識主機上的特定處理程序（如 HTTP 80/443）。
* **TCP 三向握手**：連接建立透過 SYN, SYN-ACK, ACK 三個步驟完成。連接一旦建立，便由一個 **Socket**（邏輯端點）在本地和遠端主機上追蹤狀態。
* **TCP 狀態轉換**：TCP 是一種複雜的狀態協定，涉及 LISTEN, ESTABLISHED, FIN-WAIT, CLOSED 等多種狀態，用於追蹤連接的生命週期。
* **tcpdump 偵錯**：`tcpdump` 工具可用於在網路介面上過濾和顯示封包內容，常被用於網路和叢集管理員進行故障排除，驗證 TCP 握手和數據傳輸細節。
* **TLS (Transport Layer Security)**：在 TCP 上增加了加密層，確保流量安全。它使用自己的握手過程（ClientHello, ServerHello, Key Generation）來交換密鑰和建立加密能力。
* **UDP 特性**：UDP 提供了 TCP 的替代方案，它無狀態、不可靠、開銷極小，適用於可承受封包丟失的應用（如語音、DNS、SNMP）。UDP 報文頭僅有四個字段。

### Internet

負責在網路之間傳輸數據。對於傳出的封包，它選擇下一跳主機並將其傳輸到該主機，方法是將其傳遞給適當的鏈路層(link-layer)。一旦封包被目的地接收到，網路層將把封包的有效載荷(payload)向上傳遞給適當的傳輸層(Transport Layer)協定。

IP 提供基於最大傳輸單元 (maximum transmission unit,MTU) 的封包分段或碎片整理，這定義 IP 封包的最大大小。*IP 不保證數據包的正確到達目的地*，由於跨不同網路的封包傳輸本質上是*不可靠*且容易發生問題的，因此這種負擔在於通訊路徑的端點，非網路。**提供服務可靠性的功能在傳輸層**，校驗和確保接收到的封包中的訊息是準確的，但該層不驗證數據完整性，IP 地址標識網路上的封包。

所有 TCP 和 UDP 數據都作為 IP 封包在網路層傳輸，負責網路間的數據傳輸。

* **IP 封包結構**：IPv4 標頭包含版本、標識 (Identification)、TTL (防止封包無限循環)、協定 (L4 協定編號)、Checksum，以及源和目的 IP 地址。
* **IP 尋址**：IPv4 使用 32 位元地址（點分十進制），後演進為 **CIDR (Classless Inter-Domain Routing)** 來緩解 IP 地址耗盡問題。**IPv6** 採用 128 位元地址（十六進制），極大地擴展了地址空間。
* **路由協定 (BGP)**：網際網路依賴 **BGP (Border Gateway Protocol)** 進行動態路由，透過 **ASNs (Autonomous System Numbers)** 管理邊緣路由器的封包路徑。部分 Kubernetes 網路實作（如 Calico）使用 BGP 進行節點間路由。
* **ICMP**：**ICMP (Internet Control Message Protocol)** 用於測試主機間連通性（如 `ping` 命令）並提供路由、診斷和錯誤功能。

### Link

此層包括僅在主機連接到的本地網路上運行的網路協定，封包不路由到非本地網路，這是 Internet 層的作用。以太網(Ethernet)是這一層的主要協定，**主機由鏈路層地址或通常在其網路卡上的媒體訪問控制地址( Media Access Control addresses)標識**。一旦主機使用 Address Resolution Protocol (ARP) 確定，從本地網路發送的數據將由 Internet 層處理，該層還包括用於在兩個 Internet 層主機之間移動封包的協定。

鏈路層負責本地網路內的主機到主機傳輸。

* **乙太網 (Ethernet)**：IEEE 802.3 標準定義了乙太網，將 IP 封包封裝成 **Frame**（幀）。
* **MAC 地址**：鏈路層使用 **MAC 地址** (Media Access Control address) 識別主機，MAC 地址在網路介面卡製造時分配。
* **ARP (Address Resolution Protocol)**：用於將 IP 地址（L3）解析為 MAC 地址（L2），以便在本地網路中傳輸數據。
* **VXLAN (Virtual Extensible LAN)**：透過將 L2 幀封裝到 L4 UDP 封包中，在 L3 網路上提供 L2 鄰接性，支援多達 1,600 萬個邏輯網路。這項技術被 Kubernetes 用於建立疊加網路 (overlay networks)。

### Physical layer

定義用於網路的硬體組件。例如，實體網路層規定了通訊介質的物理特性；TCP/IP 的物理層詳細說明了硬體標準，例如 `IEEE 802.3`，即以太網網路介質的規範。

下圖為 TCP/IP 數據流程

![image](https://user-images.githubusercontent.com/17800738/170858512-b23c3eef-85ce-4c26-b807-2578f7bf8b8f.png)
