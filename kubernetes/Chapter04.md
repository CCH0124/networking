Kubernetes 網路只在解決以下網路問題：
- 高度耦合的容器到容器通訊
- POD 到 POD 通訊
- POD 到 service 通訊
- 外部到服務的通訊

## The Kubernetes Networking Model
Kubernetes 網路模式原生支援多主機集群網路，因此預設下，POD 可以相互通訊，無論它們部署在哪個主機上。
Kubernetes 依賴 CNI 來滿足以下需求：
- 所有容器必須在沒有 NAT 的情況下相互通訊
- 節點可以在沒有 NAT 的情況下與容器通訊
- 容器的 IP 地址與容器外部的 IP 地址相同

Kubernetes 工作單元是 POD。一個 POD 中會有一到多個容器被執行，並且不斷被調度至節點上一起運行。

POD 在 Kubernetes 中如下被定義

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: go-web
  namespace: default
spec:
  containers:
  - name: go-web
    image: go-web:v0.0.1
    ports:
    - containerPort: 8080
      protocol: TCP
```

但通常會用更高層級元件去管理 POD，像是 `deployment`、`ReplicaSet`、`StatefulSet`。

![image](https://user-images.githubusercontent.com/17800738/197341478-10dc731d-d987-42c1-b31e-a66dfa9f4091.png)

POD 本身是短暫的，隨時會被刪除並替換新版本，當中本地硬碟狀態、節點調度和 IP 都將在 POD 的生命週期中定期更換。然而，POD 本身有一個唯一的 IP，它在 POD 中的所有容器共享，*主要動機是為了消除 Port 號限制*。

一些案例可能無法正常運行在其客製 port，那可能需要 iptable 的 DNAT 協助。Kubernetes 選擇 IP per POD 模式是為了讓開發人員更容易採用並更容易運行第三方工作負載。不幸的是，為每個 POD 分配和路由一個 IP 會大大增加 Kubernetes 集群的複雜性。

`StatefulSet` 是一種內置的資源，適用於數據庫等有狀態的工作負載，它*維護一個 POD 身份概念，並為新的 POD 提供與其替換的 POD 相同的名稱和 IP*。

每個 Kubernetes 節點都運行一個 Kubelet 組件，該組件管理節點上的 POD。*Kubelet 中的網路功能來自與節點上的 CNI 插件的 API 交互*，其用於管理 POD IP 和單個容器網路配置，也維護著 POD 之間的路由。

> Kubernetes 預設沒有 CNI 插件，因此 POD 預設下無法使用網路

### Node and Pod Network Layout

集群必須能夠控管 IP，才能將 IP 分配給 POD，透過該 L3 連接性，表示有 IP 的封包可以被路由。相較於 L4 概念，能被轉發更為重要。通常，POD 沒有 MAC 地址。因此，L2 連接到 POD 是不可能的，但 CNI 會確定這一點。


>Kubernetes 對與外界的 L3 連接沒有任何要求


構建集群網路的大致三種方法:
- isolated
- flat
- island

#### Isolated Networks

在此模式的集群網路中，節點可以在更廣泛的網路上路由，也就是不屬於集群的主機可以訪問集群中的節點，但 POD 不是。因為集群無法從更廣泛的網路路由，多個集群的網路設計可以使用相同的 IP 位置空間。

![image](https://user-images.githubusercontent.com/17800738/198882729-321c2845-b871-4f61-b2d3-350ff524c0a4.png)

如果集群需要訪問或被外部系統訪問，負載均衡器和代理可用於突破此障礙並允許互聯網流量進出隔離集群。

#### Flat Networks
在此模式網路中，*所有 POD 都有一個可從外部的網路路由的 IP 地址*。除非防火牆規則阻擋，網路上的任何主機都可以路由到集群內部或外部的任何 POD。這種配置在網路簡單性和性能方面有很多好處，畢竟 POD 可以直接連接到網路中的任意主機。

下圖，兩個集群之間沒有兩個節點的 POD CIDR 重疊，因此不會有兩個 POD 分配相同的 IP 地址。這邊網路可以將每個 POD IP 地址路由到該 POD 的節點，因此網路上的任何主機都可以與任何 POD 進行存取。

![image](https://user-images.githubusercontent.com/17800738/201510574-2ce34414-684e-4717-b182-cb6d647a8e64.png)

對於集群外部的負載均衡器可以對 POD 進行負載均衡，例如路由到另一個集群中的 gRPC。

外部 POD 流量，當連接的目標是特定的 POD IP 時具有*低延遲*和*低開銷*。對於任何形式的代理或封包重寫都會產生延遲和處理成本，這雖然很小但並不重要，但在涉及許多後端服務的應用程式架構中，每個延遲都會累加。

缺點是，此模式需要為每個*集群提供一個大的、連續的 IP 地址空間，該範圍內的每個 IP 地址都在控制之下）*。在 Kubernetes 中會要求單個 CIDR 用於 POD IP 地址。該模式可通過私有子網 10.0.0.0/8 或 172.16.0.0/12 實現，但使用公共 IP 地址要困難得多，成本也高。管理員將需要使用 NAT 將在私有 IP 地址空間中運行的集群連接到網際網路。

私有子網上的扁平網路(Flat Network)在雲環境中很容易實現。絕大多數雲提供商網路將提供大型私有子網，並具有用於 IP 地址分配和路由管理的 API。

#### Island Networks

此模式是在高層次上是 isolate 和 flat 網路的結合。

下圖，*節點與外部的網路具有 L3 連接，但 POD 沒有*，要進出 POD 的流量必須透過某種形式的代理。大多數情況下，這是*透過對離開節點的 POD 封包進行 iptables 來源 NAT 來實現的*，該過程可以稱做*masquerading*，使用 SNAT 將封包源(source)從 POD 的 IP 地址重寫為節點的 IP 地址，封包就來自節點，而非 POD。

![image](https://user-images.githubusercontent.com/17800738/201515395-638ac6ce-0139-4a92-9fa7-89cc365df527.png)

在使用 NAT 的同時共享 IP 地址會隱藏各個 POD IP 地址。這種基於 IP 地址的防火牆並識別跨集群邊界變得困難，但這有時是必須的。

我們可藉由 `kube-controller-manager` 配置這些網路組態。控制平面是指確定使用哪個路徑來發送封包或幀(frame)的所有功能和過程。數據平面是指基於控制平面邏輯將封包或幀從一個接口轉發到另一個接口的所有功能和過程。

>共享 IP 是指分配給網站或主機帳戶的 Internet 協定 (IP) 地址在多個域或網站之間共享。相反，專用 IP 是僅分配給一個域的 IP 地址。

#### kube-controller-manager Configuration



