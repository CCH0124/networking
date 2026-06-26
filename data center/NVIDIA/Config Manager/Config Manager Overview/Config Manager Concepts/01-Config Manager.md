# Config Manager 概念

NVIDIA Config Manager 是一個透過 Helm 部署的網路自動化與組態管理平台，旨在啟動（bootstrap）與運營 NVIDIA AI 工廠網路。它結合了 API、worker（工作程序）、Nautobot、資料儲存庫、事件處理和面向裝置的服務，以實現大規模的網路組態渲染、部署與運營。

## 概述

Config Manager 運行於 [Nautobot](/switch-infrastructure/config-manager/config-manager/nautobot) 之上，為網路自動化提供了一套完整的服務：

| 服務 | 說明 |
| :--- | :--- |
| **UI** | 用於工作流、審批和組態瀏覽的維運人員介面 |
| **[Temporal 服務](/switch-infrastructure/config-manager/services/temporal/overview)** | 用於網路維運的編排式自動化工作流 |
| **[Render 服務](/switch-infrastructure/config-manager/services/render/overview)** | 透過 NATS 事件進行組態渲染與範本處理 |
| **[Config Store](/switch-infrastructure/config-manager/services/config-store/overview)** | 基於 PostgreSQL 的組態儲存與版本控制 |
| **[ZTP 服務](/switch-infrastructure/config-manager/services/network-ztp/overview)** | 用於裝置引導（bootstrapping）和韌體分發的零接觸部署（Zero Touch Provisioning） |
| **[DHCP 服務](/switch-infrastructure/config-manager/services/dhcp/overview)** | 為 ISC Kea DHCP 伺服器進行動態組態生成 |
| **[遠端 MCP](/switch-infrastructure/config-manager/config-manager/overview/mcp)** | 用於驗證工具存取的串流式 HTTP MCP 端點 |

## 設計原則

Config Manager 遵循以下運作原則：

**平台獨立性 (Platform Independence)**
* 不依賴單一網路作業系統 (NOS) 技術套件
* 支援多種供應商平台和作業系統版本
* 設計與組態無關的架構

**簡化維運 (Simplified Operations)**
* 消除中間編排層（例如 Ansible 或 SaltStack）
* 對引導（bootstrap）和變更操作使用直接的基於工作流的自動化
* 為網路工程師提供單一的工作流路徑來進行資源置備（provisioning）、驗證與部署

**自給足的系統 (Self-Contained System)**
* 完全自給自足，無外部依賴
* 所有組件均為開源或內部研發
* 對技術堆疊擁有完全的控制權

**零接觸引導 (Zero-Touch Bootstrap)**
* 無需透過主控台 (console) 或 CLI 存取每台裝置即可引導網路
* 自動化從裝置開機到預期組態的置備流程
* 支援新站點和更換裝置的可重複啟用

**組態無關性 (Configuration Agnostic)**
* 系統中無嵌入式邏輯
* 設計與組態採外部管理
* 彈性的架構支援任何網路設計

**符合 SOC2 合規性 (SOC2 Compliance)**
* 納入 Day Two（營運階段）變更的審批工作流
* 記錄所有組態變更的稽核軌跡 (audit trail)
* 內建變更管理與治理機制

**即時數據驗證 (Live Data Validation)**
* 使用即時數據源驗證拓撲
* 驗證佈線是否符合預期設計
* 偵測並報告不一致之處

**版本控制 (Version Controlled)**
* 所有程式碼與組態均受原始碼控制
* 具備完整的版本歷史與回滾能力
* 基於 GitOps 的組態管理

---

## 重點整理

NVIDIA Config Manager 是 NVIDIA 為 AI 工廠網路設計的自動化與組態管理平台，其核心要點如下：

1. **架構與底層技術**：
   - 基於 **Helm** 進行部署。
   - 運行於 **Nautobot**（做為網路單一真理源 Single Source of Truth, SSOT）之上。
   - 整合多個核心服務，包含：使用者介面 (UI)、工作流編排 (Temporal)、範本渲染 (Render with NATS)、資料庫儲存 (Config Store with PostgreSQL)、零接觸置備 (ZTP) 以及動態 DHCP。
   
2. **核心設計理念**：
   - **簡化維運**：摒棄了 Ansible/SaltStack 等傳統的中介層，直接透過內建的工作流驅動網路配置。
   - **平台與組態無關**：不綁定特定的網路作業系統 (NOS)，支援跨供應商平台；系統本身不含特定網路邏輯，架構彈性極高。
   - **完全自給自足**：完全控制技術堆疊，無外部依賴，所有組件均為開源或自研。

3. **運作與合規優勢**：
   - **自動化零接觸 (ZTP)**：從開機到最終預期設定皆為自動化，無須手動連接 Console/CLI。
   - **安全與合規 (SOC2)**：具備 Day Two 變更的審核流程與完整的變更稽核軌跡。
   - **狀態驗證與版本控制**：使用即時資料比對實體佈線與設計，並以 GitOps 理念對所有配置進行版本管理，支援快速回滾。
