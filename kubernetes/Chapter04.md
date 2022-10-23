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





