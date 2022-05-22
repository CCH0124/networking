##### What is the difference between a host and an end system? List several different types of end systems. Is a Web server an end system?

- 沒有不同，所有設備都可被稱為端系統(end system)或主機(host)
- 個人電腦、服務器、手機等等
- Web 服務器是端系統

##### The word protocol is often used to describe diplomatic relations. How does Wikipedia describe diplomatic protocol?
- 是指在網路上一種可以彼此溝通的模式，雙方都要依照某些規則進行溝通
- 定義了在兩個或多個通訊實體之間交換的訊息的格式和順序，以及訊息發送和接收一條訊息或其他事件所採取的動作
- [wiki](https://en.wikipedia.org/wiki/Communication_protocol)

##### Why are standards important for protocols?
- 協定控制 internet 中訊息的接收和發送
- 每個人就各個協定及其作用取得一至認識是很重要的，這樣人們就能夠創造協同工作的系統產品

##### List six access technologies. Classify each one as home access, enterprise access, or widearea wireless access.
- home access
    - DSL
    - 電纜
    - FTTH
    - 衛星
    - 撥號接入
    - 乙太網路
    - WIFI...
- enterprise access
    - 乙太網路
    - WiFi...
- widearea wireless access
    - 3G
    - LTE

#####  Is HFC transmission rate dedicated or shared among users? Are collisions possible in a downstream HFC channel? Why or why not?
- DSL 利用電話公司現有的本地電話設施，而**cable Internet access**利用有線電視基礎設施
- HFC（Hybrid Fiber Coax），光纖和同軸電纜的混合
    - 同軸電纜為共享媒體(share medium)
- 用戶之間共享的 HFC 傳輸速率
    - 有分上下行
    - 在下行 HFC 通道中，所有的數據包都是從一個來源發出的，即頭端，因此下由通道沒有碰撞。


##### List the available residential access technologies in your city. For each type of access, provide the advertised downstream rate, upstream rate, and monthly price.
- N/A

#####  What is the transmission rate of Ethernet LANs?
- 10 Mbps, 100 Mbps, 1 Gbps and 10 Gbps

#####  What are some of the physical media that Ethernet can run over?
- 雙絞線
- 光纖
- 粗同軸鏈覽


##### Dial-up modems, HFC, DSL and FTTH are all used for residential access. For each of these access technologies, provide a range of transmission rates and comment on whether the transmission rate is shared or dedicated.

|Home access|傳輸速率|共享或專用|
|---|---|---|
|Dial-up modems|56Kbps|專用|
|HFC|下行：42.8Mbps，上行：30.7Mbps|共享|
|DSL|下行：24Mbps，上行：2.5Mbps|專用|
|FTTH|100Mbps|共享|

##### Describe the most popular wireless Internet access technologies today. Compare and contrast them.

- WiFi
    - 用戶在幾十米的半徑範圍內向/從基站（即無線接入點）發送/接收數據包。 基站通常連接到有線 Internet，因此用於將無線用戶連接到有線網絡
- 3G and 4G
    - 封包是在用於蜂窩電話的相同無線基礎結構上傳輸，基地台由電信提供商管理
        - 這為基站半徑幾十公里內的用戶提供了無線訪問

#####  Suppose there is exactly one packet switch between a sending host and a receiving host. The transmission rates between the sending host and the switch and between the switch and the receiving host are R and R , respectively. Assuming that the switch uses store-and-forward packet switching, what is the total end-to-end delay to send a packet of length L? (Ignore queuing, propagation delay, and processing delay.)
- 某元端系統或封包交換器經一條鏈路封發送一個 $L$ bit的封包，鏈路傳輸速率為 $R$ bit/s，則傳輸該封包的時間為 $L/R$ 秒


在 $t_0$ 時間，發送端開始傳輸，因為忽略傳播延遲，當 $t_1 = L/R_1$，交換器接收到整個封包，並開始傳輸封包到接收端，當 $t_2 = t_1 + L/R_2$，接收端接收到整個封包，因此總端到端延遲為 $L/R_1+L/R_2$。

##### What advantage does a circuit-switched network have over a packet-switched network? What advantages does TDM have over FDM in a circuit-switched network?
- 電路交換(circuit-switched) 可以在通訊會話期間保證一定量的端到端頻寬，當今大多數 packet-switched 無法對頻寬進行任何端到端保證
- 頻分複用（FDM）需要復雜的模擬硬體才能將信號移入適當的頻帶，而時分複用（TDM）不需要
    - FDM 
        - 鏈路頻譜由跨越鏈路創建的所有連接共享
        - 連接期間鏈路為每條連接專用一個頻段

![](https://i.imgur.com/foIu47m.png)

##### Suppose users share a 2 Mbps link. Also suppose each user transmits continuously at 1 Mbps when transmitting, but each user transmits only 20 percent of the time.

- a. When circuit switching is used, how many users can be supported?
    - 兩個用戶，一人占 1 Mbps
- b. For the remainder of this problem, suppose packet switching is used. Why will there be essentially no queuing delay before the link if two or fewer users transmit at the same time? Why will there be a queuing delay if three users transmit at the same time?
    - 由於每個用戶在傳輸時需要1Mbps，因此，如果兩個或更少的用戶同時傳輸，則最多需要2Mbps 因此在鏈接之前不會有排隊延遲
    - 個用戶同時進行傳輸，則所需頻寬將為 3Mbps，比可用頻寬更大，因此鏈接之前會有排隊延遲
- c. Find the probability that a given user is transmitting.
    - 0.2
- d. Suppose now there are three users. Find the probability that at any given time, all three users are transmitting simultaneously. Find the fraction of time during which the queue grows.
    - $\begin{pmatrix} 0  \\ 0 \end{pmatrix} p^3(1-p)^{3-3} = 0.2^3 = 0.008$
    - 隊列增長的時間比例為0.008，等於所有三個用戶同時在傳輸的概率

#####  Why will two ISPs at the same level of the hierarchy often peer with each other? How does an IXP earn money?
- 如果兩個ISP不相互對等，則當它們彼此發送流量時，它們必須通過提供商ISP（中間商）發送流量，而他們必須為攜帶流量付費。 通過直接相互對等，兩個ISP可以減少向其提供商ISP的付款。 Internet交換點（IXP）（通常在具有自己的交換機的獨立建築物中）是多個ISP可以連接和/或對等連接的匯合點。 ISP通過向連接到IXP的每個ISP收取相對較小的費用來賺錢，這可能取決於發送給IXP或從IXP接收的流量。
    - IPX 是匯合點，多個 ISP 在此對等

##### Some content providers have created their own networks. Describe Google’s network. What motivates content providers to create these networks?

Google 的專用網路將其所有大小數據中心連接在一起。Google 數據中心之間的流量透過其專用網路而不是公共 Internet 傳遞。這些數據中心中有許多位於或靠近較低層的 ISP。因此，當 Google 向用戶交付內容時，它通常可以繞過更高級別的 ISP。是什麼促使內容提供商創建這些網路？首先，由於內容提供商只需使用很少的中間 ISP，因此可以更好地控制用戶體驗。 其次，它可以通過向提供商網路發送更少的流量來節省資金。第三，如果 ISP 決定向高利潤的內容提供商收取更多的錢，則內容提供商可以避免這些額外的付款。

##### Consider sending a packet from a source host to a destination host over a fixed route. List the delay components in the end-to-end delay. Which of these delays are constant and which are variable?
- 延遲成份
    - 處理延遲
    - 傳輸延遲
    - 傳播延遲
    - 排隊延遲
    - 將這些延遲相加總就是總節點延遲
- 除了排隊延遲可變之外，所有這些延遲都是固定的
    - 一個特定封包的排隊延遲長度取決於先期到達的整在排隊等待向鏈路傳輸的封包數量

![](https://i.imgur.com/q44iu83.png)

#####  Visit the Transmission Versus Propagation Delay applet at the companion Web site. Among the rates, propagation delay, and packet sizes available, find a combination for which the sender finishes transmitting before the first bit of the packet reaches the receiver. Find another combination for which the first bit of the packet reaches the receiver before the sender finishes transmitting.
- [網站](https://media.pearsoncmg.com/aw/ecs_kurose_compnetwork_7/cw/content/interactiveanimations/transmission-vs-propogation-delay/transmission-propagation-delay-ch1/index.html)

##### How long does it take a packet of length 1,000 bytes to propagate over a link of distance 2,500 km, propagation speed $2.5 \times 10^8 m/s$, and transmission rate 2 Mbps? More generally, how long does it take a packet of length $L$ to propagate over a link of distance $d$, propagation speed $s$, and transmission rate $R$ bps? Does this delay depend on packet length? Does this delay depend on transmission rate?

- 4 ms
- 10 ms
    - 傳播延遲
- no，延遲取決於數據包長度是不正確的；延遲取決於傳輸速率是不正確的


$Transmission delay = L/R = 8 bits/byte * 1,000 bytes / 2,000,000 bps = 4 ms$

$Propagation delay = d/s = 2,500 / 2.5×105 = 10 ms$

$total time = 4ms + 10 ms = 14 ms$

##### Suppose Host A wants to send a large file to Host B. The path from Host A to Host B has three links, of rates R1=500 kbps, R2=2 Mbps, and R3=1 Mbps.

- a. Assuming no other traffic in the network, what is the throughput for the file transfer?
    - $min{R1,R2,R3}$ = 500 kbps
- b. Suppose the file is 4 million bytes. Dividing the file size by the throughput, roughly how long will it take to transfer the file to Host B?
    - 4MB = 32000000 bits；500 Kbps = 500000 bps
    - 32000000/500000 = 64 sec
- c. Repeat (a) and (b), but now with $R_2$ reduced to 100 kbps.
    - 100 kbps 為吞吐量，32000000 bits / 100000 bps = 320 sec

##### Suppose end system A wants to send a large file to end system B. At a very high level, describe how end system A creates packets from the file. When one of these packets arrives to a router, what information in the packet does the router use to determine the link onto which the packet is forwarded? Why is packet switching in the Internet analogous to driving from one city to another and asking directions along the way?

- 將檔案分成數據塊，添加 header 訊息創建封包，該封包中含有目的地
- 使用目的地地址決定鏈路
- 每個封包維護目的地地址，封包顯示出轉發到哪個路徑的出站鏈接


##### Visit the Queuing and Loss applet at the companion Web site. What is the maximum emission rate and the minimum transmission rate? With those rates, what is the traffic intensity? Run the applet with these rates and determine how long it takes for packet loss to occur. Then repeat the experiment a second time and determine again how long it takes for packet loss to occur. Are the values different? Why or why not?
- [網站](https://media.pearsoncmg.com/aw/ecs_kurose_compnetwork_7/cw/content/interactiveanimations/queuing-loss-applet/index.html)

$500/350=1.42$
##### List five tasks that a layer can perform. Is it possible that one (or more) of these tasks could be performed by two (or more) layers?

- Flow control
- Error control
- Segmentation and reassembly
- Multiplexing
- Connection setup

#####  What are the five layers in the Internet protocol stack? What are the principal responsibilities of each of these layers?

1. Application layer
- 用於在多個終端系統上發送數據
2. Transport layer 
- 兩個端點之間傳輸內容
3. Network layer
- 在網路中任何兩個主機之間移動封包
4. Data link layer
- 將上層傳來的封包封裝成幀(frame)，將數據包從一個節點移動到另一個節點
5. Physical layer.
- 在幀中將各個 bit 從一個節點傳輸到下一個節點

##### What is an application-layer message? A transport-layer segment? A network-layer datagram? A link-layer frame?
- application-layer message
    - 應用程式要發送的數據
- transport-layer segment
    - 用於將應用層的數據封裝成 segment，並在兩個端點間傳送內容
- network-layer datagram
    - 在網路中任何兩個主機之間移動封包
- link-layer frame
    - 將封包從一個節點移動到另一個節點

#####  Which layers in the Internet protocol stack does a router process? Which layers does a link-layer switch process? Which layers does a host process?
- router process
    -  Physical layer
    -  Link layer
    -  Network layer
- link-layer switch process
    -  Physical layer
    -  Link layer
- host process 
    - Physical layer
    - Link layer
    - Network layer
    - Transport layer
    - Application layer


##### What is the difference between a virus and a worm?
|Virus|Worm|
|---|---|
|自我複製，透過郵件等傳播|駐留在受感染計算機記憶體中的自我複製|
|通過可執行檔案傳播到不同的系統|使用網路進行自我傳播|
|傳播慢|傳播快|
|往往會破壞損壞或更改目標計算機的檔案|不會修改任何檔案，而是只在破壞資源檔案|
|需要某種形式的人類互動才能傳播|不需要人工干預|

##### Describe how a botnet can be created and how it can be used for a DDoS attack
- create botnet
    - 準備主機系統以查找攻擊者嘗試的漏洞
    - 惡意軟體攻擊或破壞主機系統
    - 並注入一段控制指令，讓目標系統成為受操控地殭屍
- DDoS
    - 主機系統可以掃描環境並從攻擊者那裡控制系統
    - 殭屍網絡的發起者可以遠程控制並向殭屍網路中的所有節點發出命令。因此，攻擊者控制多個源並讓每個源向目標猛烈發送流量，讓受害者癱瘓

#####  Suppose Alice and Bob are sending packets to each other over a computer network. Suppose Trudy positions herself in the network so that she can capture all the packets sent by Alice and send whatever she wants to Bob; she can also capture all the packets sent by Bob and send whatever she wants to Alice. List some of the malicious things Trudy can do from this position.
- 中間人
- 可觀測封包


##### Equation 1.1 gives a formula for the end-to-end delay of sending one packet of length $L$ over $N$ links of transmission rate $R$. Generalize this formula for sending $P$ such packets back-toback over the $N$ links.
最後一個封包只有等前面 $P-1$ 個封包傳輸出去才能傳輸，這等愛時間是$(P-1) \times \frac{L}{R}$，最後一個封包在鏈路中的傳輸延遲是 $N \times \frac{L}{R}$，所以總時間為 $(N + P-1) \times \frac{L}{R}$

##### Consider an application that transmits data at a steady rate (for example, the sender generates an N-bit unit of data every k time units, where k is small and fixed). Also, when such an application starts, it will continue running for a relatively long period of time. Answer the following questions, briefly justifying your answer:
- a. Would a packet-switched network or a circuit-switched network be more appropriate for this application? Why?
    - circuit-switched
        - 解決了固定頻寬和長時間會話的問題
- b. Suppose that a packet-switched network is used and the only traffic in this network comes from such applications as described above. Furthermore, assume that the sum of the application data rates is less than the capacities of each and every link. Is some form of congestion control needed? Why?
    - 原因是已啟用鏈接的足夠頻寬以完成應用程序的任務(傳輸速率總和小於鏈路容量)
        - 不會發生等待問題

#####  Consider the circuit-switched network in Figure 1.13 . Recall that there are 4 circuits on each link. Label the four switches A, B, C, and D, going in the clockwise direction.
- a. What is the maximum number of simultaneous connections that can be in progress at any one time in this network?
    - 16
        - A to B --> 4
        - B to C --> 4
        - C to D --> 4
        - D to A --> 4
- b. Suppose that all connections are between switches A and C. What is the maximum number of simultaneous connections that can be in progress?
    - 8
        - A to B --> 4
        - B to C --> 4
- c. Suppose we want to make four connections between switches A and C, and another four connections between switches B and D. Can we route these calls through the four links to accommodate all eight connections?
    - 可以
        -  對於 A 和 C 之間的連接，我們透過 B 路由兩個連接，也透過 D 路由兩個連接。對於 B 和 D 之間的連接，我們透過 A 路由兩個連接，也通過 C 路由兩個連接，這樣，最多有4個連接穿過任何鏈接。

![](https://i.imgur.com/N9u0OvK.png)

#####  Review the car-caravan analogy in Section 1.4 . Assume a propagation speed of 100 km/hour.
- a. Suppose the caravan travels 150 km, beginning in front of one tollbooth, passing through a second tollbooth, and finishing just after a third tollbooth. What is the end-to-end delay?
    - 傳播速率 100km/hour
    - 收費站將整個車隊推向公路的時間為 10 輛/(5輛/min) = 2 min，
    - 3個收費站到達10輛汽車所需的時間= 2 * 3 = 6 min
    - 延遲時間 = total distance/propagation speed = 150/100 = 1.5 hr
    - 端到端延遲 1.5 hr + 6mun = 1 hr 36 min
- b. Repeat (a), now assuming that there are eight cars in the caravan instead of ten.
    - 8 輛/(5輛/min) = 1.6 min
    - 1.6 * 3 = 4.8 min
    - 1.5+4.8 = 1 hr 34 min 48 sec

##### This elementary problem begins to explore propagation delay and transmission delay, two central concepts in data networking. Consider two hosts, A and B, connected by a single link of rate $R$ bps. Suppose that the two hosts are separated by $m$ meters, and suppose the propagation speed along the link is $s meters/sec$. Host A is to send a packet of size $L$ bits to Host B.
- Express the propagation delay, $d_{prop}$ , in terms of $m$ and $s$
    - $d_{prop} = m/s sec$
- Determine the transmission time of the packet, $d_{trans}$ , in terms of $L$ and $R$
    - $d_{trans} = L/R sec$
- Ignoring processing and queuing delays, obtain an expression for the end-to-end delay.
    - $(L/R+m/s) sec$
- Suppose Host A begins to transmit the packet at time $t=0$. At time $t=d_{trans}$ , where is the last bit of the packet?
    - 剛離開 A Host
- Suppose $d_{prop}$ is greater than $d_{trans}$ . At time $t=d_{trans}$, where is the first bit of the packet?
    - 鏈路上，但未到達目的地
- Suppose $d_{prop}$ is less than $d_{trans}$ . At time $t=d_{trans}$, where is the first bit of the packet?
    - 抵達目的地
- Suppose $s=2.5 \times 108$,$L=120$ bits , and $R=56$ kbps Find the distance $m$ so that $d_{prop}$ equals $d_{trans}$ .
    - $d_{prop}$ = $d_{trans}$ ---> m/s = L/R
    - $m=\frac{L}{R}s = \frac{120}{56 \times 10^3}(2.5 \times 10^8) = 536 km$

##### In this problem, we consider sending real-time voice from Host A to Host B over a packetswitched network (VoIP). Host A converts analog voice to a digital 64 kbps bit stream on the fly. Host A then groups the bits into 56-byte packets. There is one link between Hosts A and B; its transmission rate is 2 Mbps and its propagation delay is 10 msec. As soon as Host A gathers a packet, it sends it to Host B. As soon as Host B receives an entire packet, it converts the packet’s bits to an analog signal. How much time elapses from the time a bit is created (from the original analog signal at Host A) until the bit is decoded (as part of the analog signal at Host B)?
Host A 產生 56 byte 封包所需時間 $\frac{56 \times 8}{64 \times 10^3} = 0.007 sec$
傳輸延遲 = $L/R$ = $\frac{56 \times 8}{2 \times 10^6} = 0.000224 sec$，L 為封包大小

總花費時間 = 產生封包時間 + 傳輸時間 + 傳播延遲 = $0.007+0.000224+0.01 = 0.017224 sec$



#####  Suppose users share a 3 Mbps link. Also suppose each user requires 150 kbps when transmitting, but each user transmits only 10 percent of the time. (See the discussion of packet switching versus circuit switching in Section 1.3 .)
- a. When circuit switching is used, how many users can be supported?
    - $\frac{3*10^3 kbps}{150 kbps} = 20$
- b. For the remainder of this problem, suppose packet switching is used. Find the probability that a given user is transmitting.
    - $1/10=0.1$
- c. Suppose there are 120 users. Find the probability that at any given time, exactly n users are transmitting simultaneously. (Hint: Use the binomial distribution.)
    - $Pr(n) = $\begin{pmatrix} 120  \\ n \end{pmatrix} \times p^n \times (1-p)^{120-n}$
- d. Find the probability that there are 21 or more users transmitting simultaneously.
    - ?

#####  Consider the discussion in Section 1.3 of packet switching versus circuit switching in which an example is provided with a 1 Mbps link. Users are generating data at a rate of 100 kbps when busy, but are busy generating data only with probability $p=0.1$. Suppose that the 1 Mbps link is replaced by a 1 Gbps link.
- a. What is $N$, the maximum number of users that can be supported simultaneously under circuit switching?
    - $\frac{1Gbps}{100kbps} = 10000$
- b. Now consider packet switching and a user population of M users. Give a formula (in terms of p, M, N) for the probability that more than N users are sending data.
    - ?
#####  Consider a packet of length $L$ which begins at end system A and travels over three links to a destination end system. These three links are connected by two packet switches. Let $d_i$, $s_i$, and $R_i$ denote the length, propagation speed, and the transmission rate of link $i$, for $i = 1, 2, 3$. The packet switch delays each packet by $d_{proc}$. Assuming no queuing delays, in terms of $d_i$, $s_i$, $R_i$, ($i = 1,2,3$), and $L$, what is the total end-to-end delay for the packet? Suppose now the packet is 1,500 bytes, the propagation speed on all three links is $2.5 \times 108 m/s$, the transmission rates of all three links are 2 Mbps, the packet switch processing delay is 3 msec, the length of the first link is 5,000 km, the length of the second link is 4,000 km, and the length of the last link is 1,000 km. For these values, what is the end-to-end delay?
處理延遲時間 $d_{proc} = 3 msec$

- First Link
傳輸延遲$L/R_1 = \frac{1500 \times 8}{2 \times 10^6} = 0.006 sec$
傳播延遲$d1/s1 = \frac{5000 \times 10^3}{2.5 \times 10^8} = 0.02 sec$

- Second Link
$L/R_2 = \frac{1500 \times 8}{2 \times 10^6} = 0.006 sec$
$d2/s2 = \frac{4000 \times 10^3}{2.5 \times 10^8} = 0.016 sec$

- Third Link
$L/R_3 = \frac{1500 \times 8}{2 \times 10^6} = 0.006 sec$
$d3/s3 = \frac{1000 \times 10^3}{2.5 \times 10^8} = 0.004 sec$

- total
$0.006+0.006+0.006+0.02+0.016+0.004+0.003+0.003 = 0.064$

#####  In the above problem, suppose R1=R2=R3=R and $d_{proc}=0$. Further suppose the packet switch does not store-and-forward packets but instead immediately transmits each bit it receives before waiting for the entire packet to arrive. What is the end-to-end delay?

packet 1500 byte = 1500 * 8 bit
傳播延遲 $2.5 \times 10^8 m/s$
封包延遲 $d_{proc} = 0$

$0.006+0.02+0.016+0.004 = 0.046$

##### A packet switch receives a packet and determines the outbound link to which the packet should be forwarded. When the packet arrives, one other packet is halfway done being transmitted on this outbound link and four other packets are waiting to be transmitted. Packets are transmitted in order of arrival. Suppose all packets are 1,500 bytes and the link rate is 2 Mbps. What is the queuing delay for the packet? More generally, what is the queuing delay when all packets have length $L$, the transmission rate is $R$, $x$ bits of the currently-being-transmitted packet have been transmitted, and $n$ packets are already in the queue?
Packet Length = $L$
Transmission rate = $R$
Currently trannsmitted packet = $x\ bit$
Waiting quene = $n$ packets
- $L = 1500 bytes$
- $R = 2Mbps = 2 \times 10^6 bps$
- $x = 1500/2 = 750$
- $n = 4$
- $(4 \times 1500) + (1500-750) \times 2 \times 4 = 54000$
- $\frac{54000}{2 \times 10^6} = 0.027 sec$

完整封包延遲為 $\frac{1500 \times 8}{2 Mbps} = 0.6 ms$
4.5 個封包總排隊延遲為 $4.5 \times 0.6 = 2.7 ms$
$\frac{L_n}{R} + \frac{L-x}{R}$
##### 題目為以下
- a. Suppose $N$ packets arrive simultaneously to a link at which no packets are currently being transmitted or queued. Each packet is of length $L$ and the link has transmission rate $R$. What is the average queuing delay for the $N$ packets?
    - 第一個封包無延遲
    - 第二個為 $\frac{L}{R}$、第三個為 $\frac{2L}{R}$
    - 第 $N$ 個封包延遲為 $(N-1)\frac{L}{R}$
    - $\frac{\frac{L}{R}+2\frac{L}{R}+3\frac{L}{R}+...+(N-1)\frac{L}{R}}{N} = (N-1)\frac{L}{2R}$
- b. Now suppose that $N$ such packets arrive to the link every $LN/R$ seconds. What is the average queuing delay of a packet?
    - $(N-1)\frac{L}{2R}$
        - 當下一波 $N$ 個封包抵達時，上一波的已經轉傳完成

#####  Consider the queuing delay in a router buffer. Let I$$ denote traffic intensity; that is, $I=La/R$.Suppose that the queuing delay takes the form $IL/R(1-l)$ for $I<L$.
- a. Provide a formula for the total delay, that is, the queuing delay plus the transmission delay.
    - $queue delay + transmission delay = \frac{IL}{R(1-I)} + \frac{L}{R} = \frac{L}{R(1-I)}$
- b. Plot the total delay as a function of $L/R$.
    - transmission delay $x = \frac{L}{R}$
    - traffic intensity $I = \frac{La}{R} = xa$
    - total delay $\frac{x}{1-xa}$
