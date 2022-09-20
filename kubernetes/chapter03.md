# Container Networking Basics

## Applications
一個通用的作業系統盡可能支援多樣應用類型，所以它的內核包括各種驅動程式、協定庫和調度程式。從網路的角度來看，對於一個作業系統，就有一個 TCP/IP 堆棧。

![image](https://user-images.githubusercontent.com/17800738/191271665-34c5a1fe-904f-4bb0-aa55-03f605edc089.png)

## Hypervisor
Hypervisor 模擬來自主機的硬體資源、CPU 和記憶體，以創建客戶作業系統或虛擬機。其允許系統管理員與多個客戶操業系統共享底層硬體，如下圖。這種資源共享提高了主機的效率。

![image](https://user-images.githubusercontent.com/17800738/191272491-41f9294d-f208-4c5b-ae83-24ca98d7c82c.png)

其架構還為每個應用程式開發團隊提供了一個單獨的網路堆棧，從而*消除了共享系統上的端口衝突問題*。

## Containers

下圖為一個容器化應用程式的架構，每個容器都是*獨立*的；*每個應用程式，無須依賴底層的函式庫或者作業系統*；每個容器都有自己的網路堆棧。容器允許開發人員打包和部署應用程式，同時保持主機的效率。

![image](https://user-images.githubusercontent.com/17800738/191274871-9145ec33-3963-45b1-85a4-3673bb829fce.png)
