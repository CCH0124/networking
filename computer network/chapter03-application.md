# Application
### HTTP
由 client 和 server 端程式實現。HTTP 定義了兩端的 message 結構和交換方式。

![](https://i.imgur.com/YraUPzq.png)

上圖示 client 和 server 交互過程。使用者請求一個頁面時，瀏覽器向 server 發出對該頁面所包含對象的 HTTP 請求 message，server 接收到請求並用包含這些對象的 HTTP 回應 message 進行回應。

因為 HTTP server 並不儲存關於 client 端的訊息，所以是一個**無狀態協定(stateless protovol)**。

##### 非持續連接和持續連接
- 非持續連接(non-persistent connection)
    - 每個請求和回應是經過一個單獨的 TCP 連接發送
- 持續連接(persistent connection)
    - 請求和回應經過相同的 TCP 連接發送

##### 非持續連接 HTTP
file and 10 JPEG images, and that all 11 of these objects reside on the same server. Further suppose the URLfor the base HTMLfile is

http://www.someSchool.edu/someDepartment/home.index

1. HTTP client 在 80 port 上發起一個到 www.someSchool.edu 的 TCP 連接。在 server 和 client 分別有 socket 該連接相關聯。
2. HTTP client 經由 socket 向 server 發送 HTTP message 請求，包含請求路徑、主機等資訊
3. HTTP server 經由 socket 接收該請求，從儲存裝置(RAM 或 Disk) 中檢所出請求對象，在一個 HTTP 回應 message 中封裝對象，並透過 socket 向 client 回應 message
4. HTTP server 的 process 通知 TCP 斷開與 client 的連接。(必須直到 client 完整接收到該回應訊息)
5. HTTP client 接收到回應訊息，TCP 連接關閉。該 message 封裝的是一個 HTML 檔案，並得到對 10 個 JPEG 圖檔的引用
6. 對每個引用的 JPEG 圖型對象，重複 1 ~ 4 步驟

從上面可知需要 11 個 TCP 請求，因為使用**非持續連接**。但在現代，大部分瀏覽器都可開啟 5 ~ 10 個並行 TCP 連接，縮短回應時間。

從上面步驟，可估算出 client 請求 HTML 到收到整個檔案所花費時間。這邊給出**往返時間(Round-Trip Time, RTT)** 的定義，RTT 包含封包傳播延遲、封包在中間路由和交換器上的隊列延遲和封包處裡延遲。
![](https://i.imgur.com/iP0VjTF.png)

##### 持續連接 HTTP

