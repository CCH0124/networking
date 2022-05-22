# 控制平面
控制平面作為一種網路範圍的邏輯，不僅控制沿著從源主機到目的地主機的端到端路徑間的路由器如何*轉發數據包*，且控制網路層組件含服務如何*配置*和*管理*。

### Per-router control

![](https://i.imgur.com/DckONjK.png)

上圖說明了在每台路由器上運行一種路由演算法的情境，每台路由器都有*轉發*和*路由選擇*功能。
### Logically centralized control

![](https://i.imgur.com/7RNQ7Ox.png)

上圖顯示邏輯集中式控制器計算並分發轉發表以提供給每台路由器使用，並使用*匹配加動作*的抽象允許執行傳統的轉發和其它功能(NAT、Firewall等)。

該控制器使用某種協定與每台路由器的一種 control agent (CA)進行交互，以配置和管理該路由器的轉發表。與 Per-router control 的路由演算法不同，CA 不能直接交互，也不能主動參與計算轉發表，這是之間的差異。

### 路由演算法
路由演算法目的是從發送方到接收方的過程中確定一條透過路由器網路的好的(低開銷路徑)路由。

然而不論是 `Per-router control` 或 `Logically centralized control`，必定總是存在一條定義良好的一連串路由。

!["路由演算法"](https://i.imgur.com/iW0e5Gn.png "路由演算法")圖3

上圖的每條邊上都顯示一個開銷的值。我們可用圖來描述路由選擇問題，圖$G=<N,E>$ 是一個 $N$ 節點和 $E$ 條邊的集合，其每條邊又取至 $N$ 的一對節點。

一般而言，路由選擇演算法的一種分類方式是根據演算法式集中式還是分散式來劃分。

- centralized routing algorithm
    - 用完整的、全局性的網路知識計算出從源到目的地之間的最低開銷路徑
    - 此演算法需要所有節點之間的連通性和所有鏈路的開銷為輸入
        - 集中式演算法具有較完整訊息
    - 全局狀態訊息的演算法被稱作為**鏈路狀態(Link State, LS)演算法**
- decentralized routing algorithm
    - 路由器以迭代、分散式的方式計算出最低開銷路徑
    - 無節點擁有關於網路鏈路的完整資訊
        - 表示每個節點僅有與其直連的鏈路的開銷知識即可工作
    - **距離向量(Distance Vector, DV)演算法**的分散式路由演算法
        - 透過相鄰路由器之間的交互式訊息交換

### 路由演算法第二種分類方式
- static routing algorithms
    - 人工調整
- Dynamic routing algorithms 
    - 隨著網路流量負載或拓樸發生變化而改變路由選擇路徑
    - 易受到  routing loop 或  route oscillation 影響

### 路由演算法第三種分類方式
根據附載是敏感還是遲鈍做分類。
- load-sensitive algorithm
    - 鏈路開銷會動態變化已反映出底層鏈路的當前壅塞水平
        - 當開銷高，則以繞過該鏈路進行路由
        - ARPNet 屬於敏感式
    - 當今 OSPF、RIP、BGP 都是*負載遲鈍(load-insensitive)*
        - 因為某條鏈路的開銷不明確的反應其當前壅塞的水平

###  The Link-State (LS) Routing Algorithm

在實踐中這是透過讓每個節點向網路中所有其它節點廣播鏈路狀態封包來完成，其每個鏈路狀態封包包含他所有連接的鏈路的標示和成本。這動作經常使用**鏈路狀態廣播(link state broadcast)** 演算法完成。

而鏈路狀態路由演算法叫做**Dijkstra**演算法，另一個密切相關演算法是**Prim**。

Dijkstra 的性質是經過演算法迭代 $k$ 次後，可知道到 $k$ 個目的節點的最低開銷路徑，再到所有目的節點的最低成本路徑之中，這 $k$ 條路徑具有 $k$ 個最低成本。

- $D(v)$
    - 到演算的本此迭代，從源節點到目的地的節點 $v$ 的最低成本路徑的成本
- $p(v)$
    - 從源到 $v$ 沿著當前最低開銷路徑的前一節點($v$ 的鄰居)
- $N'$
    - 節點子集
    - 如果從源到 $v$ 的最低成本路徑已確知，$v$ 在 $N'$ 中

```java=
Initialization:
N’ = {u}
for all nodes v 
    if v is a neighbor of u 
        then D(v) = c(u, v)
    else D(v) = ∞ 
Loop 
find w not in N’ such that D(w) is a minimum
add w to N’
update D(v) for each neighbor v of w and not in N’:
    D(v) = min(D(v), D(w)+ c(w, v) ) 
/* new cost to v is either old cost to v or known 14    least path cost to w plus cost from w to v */ 15 until N’= N

```


從圖三，該演算法計算過程以下表總結。

![](https://i.imgur.com/hOf1UQe.png)

![](https://i.imgur.com/fUZBot0.png)

上圖顯示對圖 3中的網路產生的最低開銷路徑和 $u$ 中的轉發表。而該演算法最差情況複雜性為$O(n^2)$，而演算法第 9 行使用較堆的資料結構，能用對數時間而非線性時間找到最小值。

![](https://i.imgur.com/aGFQDls.png)

上圖呈現擁塞敏感的路由選擇的震盪，在每次做 LS 演算法時，都回不斷的來回變換路徑。有人發現說在 internet 上的路由器能在它們之間進行自同步。也就是說，即使它們初始以同一週期但在不同時刻執行演算法，演算法執行最終會在路由器上變為同步並保持，要避免則讓每台路由器發送鏈路通告的時間隨機化。

###  The Distance-Vector (DV) Routing Algorithm
是以迭代、異步和分散式的演算法，分散式是因為每個節點都要從一個或多個直接相連鄰居接收某些訊息執行計算，並將結過轉發給鄰居。而迭代是因為要依值持續到鄰居之間交換無更多訊息為止。而異步是因為不要求所有節點相互之間步伐一致的操作。 

```java=
Initialization:
    for all destinations y in N:
        D (y)= c(x, y)/* if y is not a neighbor then c(x, y)= ∞ */ 
    for each neighbor w
        D (y) = ? for all destinations y in N
    for each neighbor w 
        send distance vector  D = [D (y): y in N] to w
loop
    wait  (until I see a link cost change to some neighbor w or until I receive a distance vector from some neighbor w) 
    for each y in N:
        D (y) = min {c(x, v) + D (y)}
if Dx(y) changed for any destination y
    send distance vector D  = [D (y): y in N] to all neighbors 
forever 
```


DV 演算法路由協定
- RIP
- BGP
- ISO IDRP
- Novell IPX
- ARPNet 等

![](https://i.imgur.com/MKGHaSr.png)

上圖為 DV 演算法的運行，因為是分布式，因此是以同步方式顯示，其所有節點同時從鄰居接收訊息，計算其新距離向量，如過距離向量發生變化則通知鄰居。

最左邊一行顯示三個節點的初始路由表(routing table)。每個節點的路由表包括了他的距離向量和他的每個鄰居的距離向量。在節點 $x$ 的初始路由表中的第一行是 $D_x = [D_x(x), D_x(y), D_x(z)] = [0, 2, 7]$，也因為初始節點 $x$ 還沒有從此節點 $y$ 和 $z$ 收到任何東西，所以該列都為無窮大。

節點 $x$ 向 $y$、$z$ 節點發送了他的距離向量 $D_x$。在接收到更新後，每個節點重新計算它自己的距離向量，如節點 $x$ 計算

$D_x(x)=0$
$D_x(y) = min\{c(x, y)+D_y(y), c(x, z) + D_z(z)\} = min\{2+0, 7+1\} =2$
$D_x(z) = min\{c(x, y)+D_y(z), c(x, z) + D_z(z)\} = min\{2+1, 7+0\} = 3$

而因為無更新訊息發送，將不會進行路由表計算，直到一條路徑成本發生變化，如下列出

##### Distance-Vector Algorithm: Link-Cost Changes and Link Failure

- routing loop

##### Distance-Vector Algorithm: Adding Poisoned Reverse

上述的路由迴圈可以用 `Poisoned Reverse` 解決，但在 3 個或更多節點，此方式將無法偵測到。

### LS vs DV
- 訊息複雜性
- 收斂速度
    - DV 較慢，有機會遇到路由迴圈或無窮計數
- 健壯性
    - 在 LS 中，路由器能夠向其連接的鏈路廣播不正確的開銷，一個節點也可損壞或丟棄它收到的任何 LS 廣播
        - 但一個 LS 演算法，僅計算自己的轉發表，其它也是如此。在某種程度上算是分離的，因次較為穩定
    - DV 上則是會將錯誤訊息影響所有節點

