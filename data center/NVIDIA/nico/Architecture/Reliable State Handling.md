# Reliable State Handling (可靠狀態處理)

NVIDIA Infra Controller (NICo) 透過稱為「狀態控制器（State Controller）」的機制，為多種資源提供可靠的狀態處理。

「可靠的狀態處理」是指資源即使在遇到間歇性錯誤時（例如主機 BMC 或依賴服務暫時無法使用），也能透過自動的定期重試，順利完成其生命週期狀態的轉移。這也意味著狀態處理是確定性的，且免於競爭條件（Race conditions）。

以下是由狀態控制器管理的資源：

*   受控主機生命週期 (Managed Host Lifecycle)
*   IB 分區生命週期 (IB Partition Lifecycle)
*   網路區段生命週期 (Network Segment Lifecycle)
*   機器生命週期 (Machine Lifecycle)

---

## 狀態控制器功能 (State Controller Functionality)

*   NICo 為需要處理狀態的資源定義了一些通用介面：[StateHandler 介面](https://github.com/NVIDIA/metal-manager/blob/main/crates/api/src/state_controller/state_handler.rs) 以及 [IO 介面](https://github.com/NVIDIA/metal-manager/blob/main/crates/api/src/state_controller/io.rs)。處理常式（Handler）的實現指定了如何在狀態之間進行轉換，而 IO 則定義了如何從資料庫載入資源並將其存回資料庫。
*   處理常式函數會定期執行（通常每 30 秒一次），並以冪等（Idempotent）的方式實現。因此，即使發生間歇性失敗，系統也會在下一次反覆運算中自動重試。
*   狀態處理常式是唯一可以直接變更資源生命週期狀態的實體。轉換至新狀態的唯一途徑是藉由處理常式函數回傳新狀態作為結果。其他組件（例如 API 處理常式）僅能將意圖或請求加入佇列（例如「將此主機用作執行個體」、「回報網路狀態變更」、「回報健康狀態變更」），從而防止許多競爭條件的發生。
*   對於主機/機器而言，其實現基本上是一個大型的單一 Switch/Case（「若是此狀態，則等待此訊號，然後進入下一個狀態」）。在這裡，將狀態建模為 Rust 的列舉（Enum）極其有用。如果某個特定狀態或子狀態未被處理，編譯器就會報錯。頂層的主機生命週期狀態[定義於此](https://github.com/NVIDIA/metal-manager-snapshot/blob/main/crates/api/src/state_controller/machine/handler.rs)，且內容非常龐大。所有狀態也都可以序列化為 JSON 值，管理員工具可以藉此觀察每個資源的狀態歷程記錄。
*   狀態圖可在 [Managed Host State Diagrams](https://docs.nvidia.com/infra-controller/documentation/architecture/state-machines/managed-host) 頁面中找到。
*   每次狀態處理常式執行時，它還會為其管理的每項資源產生一組指標，讓管理員能清楚看見各資源處於何種狀態、退出狀態需要多少時間、在哪裡因為失敗而導致退出狀態失敗，以及與資源相關的專屬指標（例如主機健康狀態指標）。
*   每個狀態也都附帶一個 SLA（服務層級協定）—— 即資源離開該狀態的預期時間。此 SLA 用於在 API 中產生額外資訊（例如「該資源處於特定狀態的時間是否超出了 SLA？」），並用於指標和告警中，從而讓管理員能夠掌握有多少資源或主機處於卡住（Stuck）的狀態。

---

## 狀態處理常式的執行 (Execution of State Handlers)

*   處理常式函數被排程為定期執行（通常每 30 秒一次），其方式保證了不同資源的狀態處理常式可以並行（Parallel）執行，但同一個資源的狀態處理常式最多只能執行一個實例。定期執行保證了即使發生間歇性失敗，也會在下一次反覆運算中自動重試。
*   如果狀態處理常式的狀態處理函數回傳 `Transition`（轉換到下一個狀態），則狀態處理常式將被排程立即再次執行。這避免了 30 秒的等待時間 —— 這在資源需要經歷多個細微狀態（且每個細微狀態都應能獨立重試）時特別有用。
*   除了定期排程和狀態轉換時的排程外，NICo 控制平面組件還可以透過 [Enqueuer (入隊器)](https://github.com/NVIDIA/metal-manager/blob/main/crates/api/src/state_controller/controller/enqueuer.rs) 組件，明確請求儘快重新執行任何給定資源的狀態處理常式。這使系統能夠對外部事件做出最快的反應，例如來自主機的重開機通知。

---

## 重點整理 (Key Takeaways)

1.  **容錯與冪等設計**：可靠狀態處理（Reliable State Handling）核心在於容許間歇性錯誤。狀態處理常式（StateHandler）通常每 30 秒定期排程，且其函數為冪等實現，即使 BMC 或外部依賴服務暫時斷線，也會在下一輪自動重試。
2.  **單一變更實體（無競爭條件）**：狀態處理常式是唯一被授權直接修改資源狀態的組件。外部組件或 API 只能提交意圖/請求至佇列（Intents Queue），由狀態控制器統一消化，杜絕併發產生的競爭條件（Race conditions）。
3.  **強型別 Rust 列舉建模**：主機和機器狀態在 Rust 代碼中以列舉（Enum）進行嚴格建模，並透過一個龐大的 Switch/Case 控制跳轉。若漏寫任何一個子狀態，編譯器將無法通過，藉此在編譯期保證業務邏輯的完整度。
4.  **SLA 監控與指標監測**：為每個狀態定義了退出時間 SLA，當主機停留超時，系統會自動在 API、指標及告警系統中提示「卡住（Stuck）」的設備。
5.  **三種執行排程機制**：
    *   **定期執行**：預設每 30 秒巡檢一次。
    *   **即時跳轉**：若回傳 `Transition` 訊號表示跳轉下一狀態，則不等待 30 秒，立即排程執行下一狀態，優化多級微狀態轉換流暢度。
    *   **Enqueuer 外部事件驅動**：其他控制平面組件可透過入隊器（Enqueuer）直接通知處理常式立即重新運行（如主機發出重開機通知時），以達到最快回應。
