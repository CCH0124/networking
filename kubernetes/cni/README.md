## CNI 是什麼 ?

**容器網路介面 (CNI)** 是一個由 CNCF（雲原生運算基金會）制定的**規範或框架 (interaction framework)**。

它的主要作用是**定義**了「容器執行階段 (CRI)」和「CNI 外掛 (plugin)」這兩者之間的關係：

1.  **容器執行階段 (CRI):** 負責建立容器（例如 `containerd`）。
2.  **CNI 外掛:** 負責在容器啟動時，設定容器內部的網路介面。

簡單來說，**CNI 本身只是一個「標準」**。真正執行網路設定（如分配 IP、設定路由等）的是**「CNI 外掛」**。不過，大家通常會把 CNI 外掛也簡稱為 CNI。

## 容器中的網路

##### **容器 (Container) 依賴主機的核心 (Kernel)**

*  容器沒有自己的作業系統核心；相反，它們依賴其運行的主機系統的核心。這種設計讓容器比虛擬機 (VM) 更輕量，但隔離性也較差。

##### **使用「命名空間 (Namespaces)」來隔離**

* 為了提供一定程度的隔離，容器使用了一種稱為**「命名空間 (namespaces)」**的 Linux 核心功能。這些命名空間會分配系統資源（例如網路介面）。（**請注意：** 這裡指的是 Linux 命名空間，與 Kubernetes 的命名空間無直接關係。）

**網路命名空間 (Network Namespace) 的作用**

  * 每個容器通常都有自己獨立的網路命名空間。這種隔離確保了容器看不到外部的網路介面，並且**不同的容器可以綁定(bind)到相同的連接埠（例如 80 埠）而不會產生衝突**。

##### **使用 `veth` pair 進行連接**
  
* 為了實現網路通訊，容器使用一種稱為 **`veth`（虛擬乙太網路設備）** 的特殊裝置。`veth` 裝置總是**成對**建立，就像一條虛擬網路線，確保封包從一端進入，就會從另一端出來。

##### **如何連接容器與主機**
* 為了讓容器和主機系統之間能夠通訊，**`veth` pair 的一端會被放進容器的網路命名空間中，而另一端則留在主機的網路命名空間中**。
  * 這種配置實現了容器與主機之間的無縫通訊。因此，在同一台節點（主機）上的容器，就能夠透過主機系統互相進行通訊。

![](https://cdn.sanity.io/images/xinsvxfu/production/40dc4f8658370b5ca8de07c9f9059b94a5c407ef-1524x1525.webp?auto=format&q=80&fit=clip&w=1152) From isovalent

## CNI 如何運作？

從 Pod 建立到 CNI 介入的完整流程：

1.  使用者向 **kube-apiserver** 提交建立 Pod 的請求。
2.  排程器 (Scheduler) 決定 Pod 該部署到哪個節點 (Node) 上。
3.  kube-apiserver 接著會聯繫該節點上的 **Kubelet**。
4.  Kubelet 不會自己直接建立容器，而是將這個任務委派給 **CRI**（容器執行階段介面，例如 `containerd`）。
5.  CRI 的職責包含建立容器，以及設定一個**網路命名空間 (Network Namespace)**。
6.  一旦設定完成，CRI 就會呼叫 **CNI 外掛**。
7.  CNI 外掛會負責**產生並設定虛擬乙太網路設備 (veth)**，並建立必要的路由。

![](https://cdn.sanity.io/images/xinsvxfu/production/2299f5faf10a661d6451458d799ce98baec476f4-2048x1764.webp?auto=format&q=80&fit=clip&w=1152) From isovalent


##### 釐清：CNI 不負責流量轉發

很重要的一點是，CNI 外掛**通常不處理流量轉發 (traffic forwarding) 或負載平衡 (load balancing)**。

* **預設情況：** 在 Kubernetes 中，預設的網路代理是 **kube-proxy**。它利用 `iptables` 或 `IPVS` 等技術，將傳入的網路流量導向到叢集內正確的 Pod。
* **Cilium 的做法：** 然而，**Cilium** 提供了一個更優越的替代方案。它透過將 **eBPF** 程式直接載入到核心 (kernel) 中，以更高的速度完成相同的任務。

  
