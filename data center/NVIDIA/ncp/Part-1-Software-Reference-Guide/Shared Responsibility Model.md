# Shared Responsibility Model

安全性與合規性 (Security and compliance) 是營運商 (Operator)、租戶 (Tenant) 以及終端使用者 (End user) 之間的共同責任。

![共同責任模型架構圖](https://files.buildwithfern.com/nvidia-dsx.docs.buildwithfern.com/dsx/c34b6e16baaa594ac6f0eaadefeb9bd13503a73571c513e422c49c7445234328/_dot_dot_/docs/ncp/software-reference-guide/assets/images/ncp-srg-shared-responsibility-model.png)

營運商負責監督與控制實體主機作業系統、虛擬化層、編排調度系統，一直到運行該服務之機房設施的實體安全。它也可能包含平台服務。營運商最終有責任維護嚴格的租戶隔離並防止跨租戶的資料洩漏。

租戶管理員 (Tenant administrator) 負責確保租戶所消耗的所有機器與服務僅能由擁有對應服務存取權限的租戶使用者存取。租戶負責管理與配置其所開發的應用程式軟體，這些軟體會作為容器在由 NVIDIA® 雲端合作夥伴 (NCP) 提供的 KaaS (Kubernetes-as-a-Service) 方案中運行。租戶還負責與外部第三方的整合方式、管理其自身的 IT 環境，以及遵守相關的法律與法規。

終端使用者負責應用程式的安全、使用者驗證，以及由應用程式產生或使用的資料之安全性。

---

## 重點整理 (Key Takeaways)

1. **安全性與合規性之共同責任定義**
   * 安全性與合規性由**營運商 (Operator)**、**租戶 (Tenant)**（包含租戶管理員）與**終端使用者 (End User)** 三個角色共同分擔，各司其職。

2. **營運商 (Operator) 的責任範圍**
   * 負責管理與保護底層所有硬體與虛擬化基礎設施，包括機房的實體安全、主機作業系統 (Host OS)、虛擬化層 (Hypervisor) 以及容器編排系統。
   * 其核心關鍵職責是確保實體和邏輯上的租戶隔離，防範跨租戶資料洩漏事件。

3. **租戶 (Tenant) 的責任範圍**
   * **存取控制**：租戶管理員負責維護租戶內部的權限管理，確保合適的使用者存取正確的服務。
   * **軟體與 IT 維運**：管理與配置在其 KaaS 叢集中運行的容器化應用程式，並負責外部系統對接安全、內部 IT 環境管理以及法律法規合規性。

4. **終端使用者 (End User) 的責任範圍**
   * 負責其自身應用程式層的安全。
   * 負責使用者端身分驗證 (Authentication) 安全。
   * 負責應用程式處理、輸入與產生之資料本身的機密性與安全性。
