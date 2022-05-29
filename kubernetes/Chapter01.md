## OSI Model

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


##### Application

唯一一個直接與來自使用者的資料進行交互的層。該層不是實際應用程式所在的位置，也就是用戶端軟體應用程式不是此層的一部分，但它為使用它的應用程式負責通訊協定和資料操作，軟體依靠這樣來呈現資料。例如 HTTP、SMTP 或 Office 365。

![](https://cf-assets.www.cloudflare.com/slt3lc6tev37/koKt5UKczRq47xJsexfBV/c1e1b2ab237063354915d16072157bac/7-application-layer.svg) 
from [cloudflare](https://www.cloudflare.com/en-ca/learning/ddos/glossary/open-systems-interconnection-model-osi/)

##### Presentation

在應用程式和網路格式之間進行轉換，負責準備資料以供應用程式層使用也就是此層可使資料呈現給需要使用的應用程式。該層允許兩個系統對數據使用不同的編碼，並在它們之間傳遞數據，傳入資料轉譯至接收裝置的應用程式層能夠理解的語法。

同時也負責壓縮其從應用程式層接收到的資料，然後將其傳送至第 5 層(Session Layer)，使傳輸的資料量降到最低，改善通訊速度和效率。

![](https://cf-assets.www.cloudflare.com/slt3lc6tev37/60dPoRIz0Es5TjDDncEp2M/7ad742131addcbe5dc6baa16a93bf189/6-presentation-layer.svg) 
from [cloudflare](https://www.cloudflare.com/en-ca/learning/ddos/glossary/open-systems-interconnection-model-osi/)

##### Session

處理開啟和關閉兩個裝置之間的通訊，負責連接的雙工(是否同時發送和接收數據)。它還建立了執行*檢查點*、*暫停*、*重新啟動*和*終止會話*的流程。它建立、管理和終止本地和遠程應用程式之間的連接。

檢查點同步資料傳輸。例如，若正在傳輸 100 MB 檔案，此層可以每 5 MB 設定一個檢查點。若在傳輸 52 MB 後中斷連線或毀損，工作階段可從上一個檢查點繼續進行，亦即只剩下 50 MB 的資料需要傳輸。若沒有檢查點，整個傳輸就必須再次從頭開始。

![](https://cf-assets.www.cloudflare.com/slt3lc6tev37/6jFRnaZSuIMoUzSotZXYbG/cc7a47d2b3f8d3e77b9ffbdb8b8d5280/5-session-layer.svg)
from [cloudflare](https://www.cloudflare.com/en-ca/learning/ddos/glossary/open-systems-interconnection-model-osi/)

##### Transport

在應用程式之間傳輸數據，為上層提供可靠的數據傳輸服務，**責處理兩個裝置之間的端對端通訊**。傳輸層藉由*流量控制*(判定最佳傳輸速度)、*分段*和*解分段*(desegmentation)以及*錯誤控制*來控制給定連接的可靠性(確保接收的資料是完整的)。一些協定是面向狀態和連接的，該層追蹤分段並重新傳輸那些失敗的分段、數據傳輸成功的確認，如果沒有發生錯誤則發送下一個數據。 

流層大致會從 Session 層取用資料，並在傳送至第 Network 層之前分解為分段(segments)的區塊，對於接收裝置上的傳輸層負責將分段重組為 Session 層可以取用的資料。

![](https://cf-assets.www.cloudflare.com/slt3lc6tev37/1MGbIKcfXgTjXgW0KE93xK/64b5aa0b8ebfb14d5f5124867be92f94/4-transport-layer.svg)
from [cloudflare](https://www.cloudflare.com/en-ca/learning/ddos/glossary/open-systems-interconnection-model-osi/)

##### Network

此層實現了兩個不同網路之間的資料傳輸，同時保持服務質量。網此層執行**路由功能**(為資料尋找抵達目的地的最佳實體路徑)，在接收錯誤時執行*分段*和*重組*。路由器在這一層運行，藉由相鄰網路發送數據。此層在**傳送者的裝置上將來自傳輸層的分段分為較小的單位，稱為封包**，然後接收裝置上重組這些封包，

這些協定屬於此層，包括路由協定、多播組管理、網路層訊息、錯誤處理和網路層地址分配。

![](https://cf-assets.www.cloudflare.com/slt3lc6tev37/76JgEjycZl12c90UByKfJA/d6578bcd7b151c489e61f42227a45713/3-network-layer.svg)
from [cloudflare](https://www.cloudflare.com/en-ca/learning/ddos/glossary/open-systems-interconnection-model-osi/)

##### Data Link

**負責同一網路上的主機到主機傳輸，不會跨越本地網路的邊界**，定義了建立和終止兩個設備之間連接的協定。此層在裝置之間傳輸數據，並提供檢測和可能糾正來自物理層(Physical Layer)的錯誤的方法。

此層獲取來自網路層(Network Layer)的封包，並分為較小的物件，稱為**Frame**。類似網路層，此層也負責處理網路內通訊的流量控制和錯誤控制，不同於傳輸層(Transport Layer)，傳輸層僅處理網路間通訊的流量控制和錯誤控制)。

![](https://cf-assets.www.cloudflare.com/slt3lc6tev37/3MR4mPOwaos80t1annw7BG/8ea1c59ccfa1baf6e9738773daa30450/2-data-link-layer.svg)
from [cloudflare](https://www.cloudflare.com/en-ca/learning/ddos/glossary/open-systems-interconnection-model-osi/)

##### Physical

由插入交換機的以太網線直觀地表示。該層將數字位形式的數據轉換為電、無線電或光信號。將此層視為物理設備，如電纜、交換機和無線接入點。有線協議也在這一層定義。將資料轉換為位元(bit)的一層，亦即 1 和 0 的字串，兩個裝置之間的實體層也必須同意訊號約定，以便在兩個裝置上辨別 1 和 0。\

![](https://cf-assets.www.cloudflare.com/slt3lc6tev37/3m1ZkcaaBYHoodrEO3brv2/2819c4db294631b5753cd55de0c01bd9/1-physical-layer.svg)
from [cloudflare](https://www.cloudflare.com/en-ca/learning/ddos/glossary/open-systems-interconnection-model-osi/)
