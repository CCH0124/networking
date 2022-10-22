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
