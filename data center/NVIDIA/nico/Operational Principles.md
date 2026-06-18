# Operational Principles

NICo (NVIDIA Infra Controller) 的設計圍繞著五個奠定其架構與維運模型的基石原則。

綜合起來，這些原則構成了 NICo 針對裸機基礎設施的零信任 (Zero-trust) 安全模型。BlueField DPU 是信任根源 (Trust anchor)：它強制執行網路隔離，獨立於主機作業系統管理所有面向主機的安全邊界，並保存用於鎖定 SuperNIC 韌體以防止租戶篡改的加密金鑰。對於各層的技術實作：

- [DPU 生命週期管理 (DPU Lifecycle Management)](https://docs.nvidia.com/infra-controller/documentation/operations-day-2/dpu-management/dpu-lifecycle-management) —— NICo 如何在不信任主機作業系統的情況下安裝、配置和管理 DPU。
- [DPU 配置 (DPU Configuration)](https://docs.nvidia.com/infra-controller/documentation/operations-day-2/dpu-management/dpu-configuration) —— 在 DPU 層級的主機隔離機制與 VPC 強制執行。
- [SuperNIC 鎖定金鑰管理 (SuperNIC Lockdown Key Management)](https://docs.nvidia.com/infra-controller/documentation/architecture/super-nic-lockdown-key-management) —— 加密韌體鎖定，防止租戶修改 SuperNIC 韌體或配置。

## 主機是不可信的 (The machine is untrustworthy)

NICo 從不依賴運行在主機作業系統內部的軟體來做出安全或隔離決策。BlueField DPU 是強制的安全邊界。它獨立於主機運作，且不會受到其上運行之任何內容的影響或危害。遭到篡改的主機無法破壞 NICo 所強制執行的隔離。

## 不對主機強加任何作業系統需求 (Operating system requirements are not imposed on the machine)

NICo 不需要在主機作業系統內部安裝任何代理程式 (Agents)、守護行程 (Daemons) 或特定配置。支援任何可透過 iPXE 安裝的作業系統。作業系統的管理（修補、升級、配置）是營運商的責任。NICo 在開機引導後交付，且在租戶使用期間不會重新進入主機。

## 機器上架後，必須在無需人工干預的情況下準備就緒 (After being racked, machines must become ready for use with no human intervention)

一旦機器上架機櫃、接妥線纜並接通電源，NICo 就會自動化完成從探索到準備好佈署的完整路徑（包含驗證、韌體基準對齊、DPU 配置和安全證明），無需任何手動步驟。

## 所有對機器的監控都必須使用頻外方法進行 (All monitoring of the machine must be done using out-of-band methods)

NICo 專門透過 Redfish 以及 DPU 代理程式來監控硬體健康狀況、韌體狀態和機器狀態 —— 絕不透過可能被受損或無回應的主機作業系統所影響、阻擋或欺騙的頻內 (In-band) 路徑。這確保了無論主機處於何種狀態，監控都能保持可靠。

## 即使在租戶變更期間，網路織網也保持靜態 (The network fabric stays static even during tenancy changes)

當租戶變更或主機進行佈署與釋放時，Leaf 交換器和路由器不需要重新配置。隔離完全是在 DPU 層級（透過 HBN 的乙太網路）以及透過織網管理 API（透過 UFM 的 InfiniBand，透過 NMX-M 的 NVLink）來強制執行。保持實體底層網路 (Underlay) 的穩定可降低維運風險，並簡化大規模的網路運作。

---

## 重點整理 (Key Takeaways)

1. **信任根源以 DPU 為核心 (DPU-Centric Trust Anchor)**
   * NICo 的裸機零信任模型以 BlueField DPU 作為信任錨點 (Trust anchor)，獨立於主機 OS 實作網路隔離與安全邊界管理，並持有 SuperNIC 韌體加密鎖定金鑰，杜絕租戶惡意竄改。

2. **主機不可信原則 (Zero-Trust Host OS)**
   * 安全與隔離決策絕不仰賴主機 OS 內部的軟體。安全邊界強制在 DPU 層，即使實體主機遭租戶提權或篡改，也無法破壞網路隔離防護。

3. **無作業系統侵入 (OS-Agnostic with Zero Agents)**
   * NICo 在主機上不強制要求任何特定作業系統或配置，亦不需安裝任何監控 Agent 或 Daemon，僅需支援 iPXE 引導。在引導完成移交租戶後，NICo 在使用期間不會再次切入主機內部。

4. **全自動上線佈署 (Zero-Touch Onboarding)**
   * 硬體機櫃上架、接線與上電後，NICo 自動化執行探索、規格驗證、韌體版本對齊、DPU 配對部署與遠端安全證明，全程免除手動維運。

5. **純頻外 (OOB) 監控遙測 (Exclusive Out-of-Band Monitoring)**
   * 硬體、韌體與節點健康監控皆透過 Redfish 與 DPU 代理進行，完全避開頻內通道，防範主機 OS 掛載、無響應或遭到劫持時偽造健康狀態報告。

6. **物理底層網路保持靜態 (Static Underlay Network)**
   * 租戶輪替時，實體的 Leaf 交換器與路由器保持靜態配置，毋需頻繁變動。VPC 與網路隔離規則在邊緣的 DPU (HBN/VXLAN)、UFM (IB/P_Keys) 與 NMX-M (NVLink) 直接執行，極大降低大規模營運下的網路異動風險。
