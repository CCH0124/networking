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

`kube-controller-manager` 存在 Kubernetes 的邏輯。Kubernetes 中的控制器是*監視資源並採取行動以同步或強制執行特定狀態（所需狀態或將當前狀態反映為狀態）的軟體*。Kubernetes 有很多控制器，它們通常擁有特定的對像類型或特定的操作，像是網路堆棧，設定 CIDR。因此其運行了大量的控制器，同時也有大量的參數。

下表為對網路的配置，版本 1.24
|Flag|Default|Description| 
|---|---|---|
|--allocate-node-cidrs|true|設置是否應在雲商上分配和設置 Pod 的 CIDR|
|--cidr-allocator-type|RangeAllocator|要使用的 CIDR 分配器的類型|
|--cluster-CIDR| |從中分配 pod IP 地址的 CIDR 範圍。需搭配 --allocate-node-cidrs 且為 true|
|--configure-cloud-routes|true|設置 CIDR 是否由 `allocate-node-cidrs` 分配並在雲商上配置|
|--node-cidr-mask-size|24(IPv4)、64(IPv6)|集群中節點 CIDR 的遮罩大小。Kubernetes 會為每個節點分配 `2^(node-CIDR-mask-size)` 個 IP 地址。|
|--node-cidr-mask-size-ipv4|24| |
|--node-cidr-mask-size-ipv6|64| |
|--service-cluster-ip-range| |集群中服務的 CIDR 範圍，用於分配服務 ClusterIP。需要 `--allocate-node-cidrs` 為 true。如果 `kube-controller-manager` 啟用了 `IPv6DualStack`，`--service-cluster-ip-range` 接受以逗號分隔的 IPv4 和 IPv6 CIDR。|

>更多配置可參考 [document v1.24](https://v1-24.docs.kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/)

## Kubelet
`Kubelet` 在 Kubernetes 集群中會被分配到每個工作節點上。*`Kubelet` 負責管理任何調度到節點的 POD，並為節點和節點上的 POD 提供狀態更新*。但，*Kubelet 主要充當節點上其他軟體的協調器*，管理容器網路透過 `CNI` 和容器運行時透過 `CRI`。

>工作節點定義為可以運行 POD 的 Kubernetes 節點。

當控制器或使用者在 Kubernetes API 中創建 POD 時，它最初僅作為 POD API 物件存在。Kubernetes 調度監視該 POD，並嘗試選擇一個有效的節點將 POD 調度到那。該調度有幾個限制，我們的 POD 及其 CPU/Memory 請求不得超過節點上剩餘的未請求 CPU/Memory。調度方式有許多選擇可用，例如 `affinity`、`anti-affinity`、`taints` 等。

假設調度找到一個滿足所有 POD 約束的節點，調度應用程式將該節點的名稱寫入我們 POD 的 `nodeName` 字段。

```yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: "2022-08-06T03:13:27Z"
  labels:
    run: mycurlpod
  name: mycurlpod
  namespace: default
  resourceVersion: "122811"
  uid: aebb8e2f-f43c-431e-8481-6f518f0f5fe3
spec:
  containers:
  - args:
    - sh
    image: curlimages/curl
    imagePullPolicy: Always
    name: mycurlpod
    ....
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: kube-api-access-8kh95
      readOnly: true
  dnsPolicy: ClusterFirst
  enableServiceLinks: true
  nodeName: skaffold-node1
  preemptionPolicy: PreemptLowerPriority
  priority: 0
  restartPolicy: Always
...
```

而 Kubelet 監控所有調度給他的 POD。等效的 `kubectl get pods -w --field-selector spec.nodeName=skaffold-node1`。當 Kubelet 觀察到我們的 POD 存在但不存在於節點上時，它會創建它。會觸發 CRI 細節和容器本身的創建。一旦容器存在，Kubelet 就會對 CNI 進行 ADD 調用，這會告訴 CNI 插件創建 POD 網路。

可以簡易得知建立 POD 流程 `Kubelet -> CRI -> CNI -> POD`。

## Pod Readiness and Probes
POD `readiness` 是 POD 是否準備好為流量提供服務，該情況決定了 POD IP 是否顯示在來自外部源的 `Endpoints` 物件中。Deployment 是管理 POD 的資源，當在做滾動更新時會同時考慮 `readiness` 狀態。

探測影響 POD 的 `.Status.Phase` 字段。下面列出該字段的值和描述

*Pending*

POD 已被集群接受，但一個或多個容器尚未準備好運行。這包括 POD 等待調度所花費的時間以及透過網路下載容器 Image 所花費的時間。

*Running*

POD 已經被調度到一個節點上，並且所有的容器都已經創建好了。至少有一個容器仍在運行或正在啟動或重新啟動，但某些容器可能處於失敗狀態，例如處於 `CrashLoopBackoff` 狀態。

*Succeeded*

POD 中的所有容器都已成功終止，不會重新啟動

*Failed*

POD 中的所有容器都已終止，且至少有一個容器因故障而終止。也就是說，容器要嘛非零狀態退出，要嘛被系統終止。

*Unknown*

由於某種原因，無法確定 POD 的狀態。此*階段通常是由於與運行 POD 的 Kubelet 通訊時出現錯誤而發生的*。

`Kubelet` 對 `POD` 中的各個容器執行多種類型的健康檢查：
- liveness probes (livenessProbe)
- readiness probes (readinessProbe)
- startup probes (startupProbe)
- 
*Kubelet 以及節點本身必須能夠連接到該節點上運行的所有容器*，以便執行任何 HTTP 健康檢查。

每個探測具有以下三個結果之一
*Success*

容器通過診斷

*Failure*

容器未通過診斷

*Unknown*

診斷失敗，所以不應採取任何措施

探測可以是 `exec`探測，它嘗試 TCP 或 HTTP 探測並在容器中執行二進製文件。假設探測失敗次數超過 `failureThreshold` 次數，Kubernetes 將認為失敗。

當容器的就緒探測(readiness prob)失敗時，Kubelet 不會終止它。相反，Kubelet 將故障寫入 POD 的狀態；如果活性探測(liveness prob)失敗，Kubelet 將終止容器，該探針通常會讓 kubelet 知道容器何時重啟。

Kubernetes 具有容器重啟回退 (CrashLoopBackoff)，這會增加重啟失敗容器的延遲，此時後可能會遺失快取的內容風險。

當 pod 使用它們時，它們只依賴於它們正在測試的容器，沒有其他依賴性。

啟動探測(startup probe)可以在活性探測(liveness prob)生效之前提供一個寬限期，在啟動探測成功之前，活性探測不會終止容器。

下面是 spring boot 範例
```yaml
....
  spec:
      containers:
       ...
          livenessProbe:
            httpGet:
              path: /actuator/health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 30
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /actuator/health
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 30
            failureThreshold: 3
```

`Endpoints/EndpointsSlice` 資源也會對失敗的就緒探測(readiness probes)做出反應。*如果 POD 的就緒探測失敗，則 POD 的 IP 地址將不在端點對像中，服務也不會將流量路由到它*。

*`startupProbe` 探針會通知 Kubelet 容器內的應用程式是否啟動*，預設不設定是 `success` 狀態，該探針也優先於其它探針。一旦 `startupProbe` 成功，Kubelet 將開始運行其他探針。但*如果 `startupProbe` 失敗，Kubelet 會殺死容器，容器會執行其重啟策略*。

探針可配置選項:

*initialDelaySeconds*

容器啟動後到啟動 liveness 或 readiness 探針之前的秒數。默認0；最小 0。

*periodSeconds*

執行探針的頻率。默認 10；最少 1 秒。

*timeoutSeconds*

探針超時後等待秒數。默認 1；最少 1 秒。

*successThreshold*

失敗後探針成功的最小連續成功數。默認 1；對於 liveness 和 startup 探測必須為 1；最少 1 次。

*failureThreshold*

當探針失敗時，Kubernetes 會在放棄之前嘗試多次。在 liveness 探針的情況下放棄表示著容器將重新啟動。對於 readiness 探測，POD 將被標記為未就緒。默認 3；最少 1 次。


Kubelet 必須能夠連接到 Kubernetes API 服務。在下圖中，我們可以看到集群中所有組件建立的所有連接：
- CNI
  - Kubelet 中的網路插件，使網路能夠獲取 PODd 和 service 的 IP
- gRPC
  - 從 API 服務到 etcd 通訊的 API
- Kubelet
  -  所有 Kubernetes 節點都有一個 Kubelet，可確保分配給它的任何 POD 都在運行並以所需狀態配置
-  CRI
  - 允許 Kubelet 使用 gRPC API 與容器運行(container runtime)對話。容器運行供應商必須整合 CRI API，以允許 Kubelet 使用 OCI 標準 (runC) 與容器對話。 

#### The CNI Specification
根據規範，CNI 插件必須支援四種操作

*ADD*

將容器添加到網路

*DEL*

從網路中刪除容器位置

*CHECK*

如果容器的網路出現問題，返回錯誤

*VERSION*

報告有關插件的版本資訊

> 更多 CNI 規範可參考該[鏈結](https://github.com/containernetworking/cni/blob/main/SPEC.md)


Kubernetes 將 JSON 格式的命令任何配置提供給標準輸入，並透過標準輸出以 JSON 格式接收命令的輸出。CNI 插件充當 Kubernetes 調用的包裝器，而二進製檔案對後端進行 HTTP 或 RPC API 調用。

![image](https://user-images.githubusercontent.com/17800738/205480315-3139fbc1-607b-4c85-85c6-c1f1636d960d.png)


*Kubernetes 一次只使用一個 CNI 插件*，儘管 CNI 規範允許多插件設置，為一個容器分配多個 IP 地址。而，Multus 是一個 CNI 插件，它充當多個 CNI 插件的出口出來解決 Kubernetes 中的這個限制。

## CNI Plugins

CNI 插件有兩個責任，為 POD 分配唯一的 IP 地址，並確保 Kubernetes 中存在到每個 pod IP 地址的路由。這些職責表示著集群所在的總體網路決定了 CNI 插件的行為。

要使用 CNI，須*將 `--network-plugin=cni` 添加到 Kubelet 的啟動參數中*。預設，*Kubelet 從目錄 `/etc/cni/net.d/` 中讀取 CNI 配置，並期望在 `/opt/cni/bin/` 中找到 CNI 執行檔*。管理員可以使用 `--cni-config-dir=<directory>` 覆蓋配置位置，使用 `-cni-bin-dir=<directory>` 覆蓋 CNI 執行檔目錄。

[network-plugins](https://kubernetes.io/zh-cn/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)

>在 Kubernetes 1.24 之前，CNI 插件也可以由 kubelet 使用命令行參數 cni-bin-dir 和 network-plugin 管理。 Kubernetes 1.24 移除了這些命令行參數， CNI 的管理不再是 kubelet 的工作。

CNI 網路模型有兩大類：平面網路(flat networks)和覆蓋網路(overlay networks)。在平面網路中，CNI 驅動程式使用來自集群網路的 IP 地址，這通常需要許多 IP 地址才能用於集群。在覆蓋網路中，CNI 驅動程式在 Kubernetes 中創建一個次要網路，它使用集群的網路（underlay network）發送封包。覆蓋網路在集群內創建一個虛擬網路，在其中，CNI 插件封裝封包。

CNI 還負責調用 IPAM 進行 IP 分配。

### The IPAM Interface
CNI 規範有第二個，即 IP Address Management (IPAM) 接口，以減少 CNI 插件中 IP 分配的重複。IPAM 必須確定並IP 地址、網關和路由，如下所示。IPAM 類似於 CNI，一個二進製檔案，帶有 JSON 輸入(stdin) 和 JSON 輸出(stdout)

[可參考](https://github.com/containernetworking/cni/blob/main/SPEC.md#section-4-plugin-delegation)

##  CNI Plugins
### Cilium

##### Agent

運行在每個節點上，此 cilium-agent 透過 Kubernetes API 接受這些需求，有網路、服務負載均衡、網路政政策(NetworkPolicy)以及可見性和監控。

##### Client

是一個 CLI 工具，會與 cilium-agent 再一起。且與同一節點上的 REST API 交互，檢測當前 cilium-agent 狀態或是存取 eBPF 映射以直接驗證其狀態。

##### Operator

負責管理集群

##### CNI Plugin

CNI 插件 (cilium-cni) 與節點的 Cilium API 交互以觸發配置以提供網路、負載均衡和網路政策(NetworkPolicy)。


### kube-proxy
kube-proxy 是 Kubernetes 中基於節點的守護進程。在集群中提供附載均衡功能，它實現服務(Service)並依賴於 `Endpoints/EndpointSlices`。
- Service 為一組 pod 定義負載均衡
- Endpoint 和 EndpointSlice 列出了就緒的 POD IP。它們是從 Service 自動創建，使用與 Service 相同的 pod。

大多數類型服務(Service)都有一個 IP 地址，稱為 `cluster IP`，它在集群外是不可被路由的。`kube-proxy` 負責將對服務集群 IP 地址的請求路由到健康的 POD。

kube-proxy 有四種模式，它們改變了它的運行時模式
- userspace
- iptables
- ipvs
- kernelspace

`--proxy-mode <mode>` 可以指定，但*所有模式都在一定程度上依賴於 iptables*。

#### userspace Mode
最舊的模式，kube-proxy 運行一個 Web 服務器，並使用 iptables 將所有服務 IP 地址路由到 Web 服務器。Web 服務器終止連接並將請求代理到服務端點中的 POD。此模式不建議使用。

#### iptables Mode
iptables 模式是扇出(fan-out)，而不是真正的負載均衡。iptables 模式會將連線路由到 POD，並且該連線發出的所有請求都將轉到同一個 POD，直到連線終止。假設有兩個 POD 提供服務，是 X 和 Y，且在正常滾動更新期間將 X 替換為 Z。較舊的 Y 仍然有所有現有連線，加上 X 關閉時需要重新建立的一半連線，導致 Y 要提供更多流量，這也出現了不平衡的流量決策。


