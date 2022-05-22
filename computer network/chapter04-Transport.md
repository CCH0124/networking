# 傳輸層
## 概述和傳輸服務
傳輸層協定運行在不同主機上的應用行程之間提供了`邏輯通訊(logic communication)`功能。如下圖

![](https://i.imgur.com/pMXfJu3.png)

應用行程使用傳輸層提供邏輯通訊功能彼此發送 `segment`，無需考慮乘載這些 `segment` 的物理設施。

在網路應用程式中可以使用多種傳輸協定，如：`TCP`、`UDP`

### 傳輸層和網路層關係
網路提供主機之間的邏輯通訊，而傳輸層為運行在不同主機上的行程之間提供了邏輯通訊。

從不同區域家庭中的信件發送，可以類比上述的文字

application messages = letters in envelopes 
processes = cousins 
hosts (also called end systems) = houses 
transport-layer protocol = Ann and Bill 
network-layer protocol = postal service (including mail carriers)

### Internet 傳輸層概述
- UDP
    - 不可靠 
    - 無連接的服務
- TCP
    - 可靠
    - 面相連接的服務

>傳輸層封包稱為**segment**，TCP 也是。UDP 常稱為 **datagram**，這邊都統稱**segment**
>

在 Internet 上有一個網路協定 IP，他為主機之間提供了邏輯通訊。他不做**任何確保**。


將主機間交付擴展到行程間交互被稱為**傳輸層的多路復用(transport-layer multiplexing)** 與 **多路分解(demultiplexing)**。`UDP` 和 `TCP`可以透過 `segment` 中首部的差錯檢查字段而提供完整性檢查。

`UDP` 不能保證一個行程所發送的數據能夠完整的到達目的地。


## 多路復用(transport-layer multiplexing)與多路分解 (demultiplexing)

![](https://i.imgur.com/esgI6X5.png)

在接收主機的運輸層實際上並沒有直接將數據交付給行程，而是將數據交給了一個中間的 `socket`。由於在任何時刻，在接收主機可能有一個以上的 `Socket`，每個 `socket` 都有唯一辨識符，格式取決於 `UDP` 或 `TCP`。

將運輸層 segment 中的數據交付到正確的 socket 的工作稱為**demultiplexing**。
在來源主機從不同 socket 中蒐集數據，並為每個數據封裝上首部訊息（浙江在之後用於分解）從而生成 segment，然後將 segment 傳遞到網路層，所有這些工作稱為**multiplexing**。

multiplexing 要求：
1. socket 有唯一識別符
2. 每個 segment 有特殊字段來指示該 Segment 要交付到的 socket。下圖

![](https://i.imgur.com/n5O7GLL.png)

其中 port 範圍在 0 ~ 65535。0 ~ 1023 是已知端口，保留給像是 HTTP 80 port、FTP 21 port 等。

在主機上的每個 socket 能夠分配一個 port 號，當 segment 到達主機時，傳輸層檢查 segment 中的目的 port，並將其定向到相應 socket。然後 segment 中的數據透過 socket 進入其所連接的 socket。

##### 1. 無連接的多路復用與多路分解
![](https://i.imgur.com/QdZt0at.png)
一個 UDP socket 是由一個二元組全面標識的，包含目的 IP 與 Port。
##### 2. 面向連接的多路復用與多路分解
TCP 是由四元組，來源 IP、Port 和目的 IP、Port 組成。因此，當一個 TCP 從網路到達一台主機時，該主機用此四元組將 segment 定向到相應的 socket。

![](https://i.imgur.com/iZSeXYT.png)

上圖主機 A 和主機 C 不相干，因此可將 26145 分配至 HTTP 連接。服務器 B 會利用不同源 IP 去判斷。

服務器 B 為每個連接生成一個行程，每個連接透過 socket 來接收和回應 HTTP。

當 Client 使用持續 HTTP 時，則連接期間都是由同一個 socket 進行交換 HTTP message；如果使用非持續連接，則會對請求和回應都建立一個新的 TCP 連接並隨後關閉。

## UDP
傳輸層最低限度必須提供 ` multiplexing/demultiplexing `，以便網路層與正確的應用成級行程之間傳輸數據。
