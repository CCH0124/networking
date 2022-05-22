- [Virtual File System](#virtual-file-system)
          + [tags: `Ubuntu` `VFS`](#tags---ubuntu---vfs-)
  * [proc file system](#proc-file-system)
  * [Writing to Proc Files](#writing-to-proc-files)
  * [Persisting /proc Files Changes](#persisting--proc-files-changes)
  * [Common /proc Entries](#common--proc-entries)
  * [Listing /proc Directory](#listing--proc-directory)
  * [/proc Useful Examples](#-proc-useful-examples)
  * [sysfs Virtual File System](#sysfs-virtual-file-system)
  * [tmpfs Virtual File System](#tmpfs-virtual-file-system)

# Virtual File System
作業系統的虛擬層，底下是實體的檔案系統。Virtual File System 主要功用，讓上層軟體，能夠以單一的方式，跟底層不同的檔案系統溝通。作業系統與之下的各種檔案系統之間，虛擬檔案提供一個標準的介面，好讓作業系統能夠很快的支援新的檔案系統。

## proc file system
proc file system 式安裝在 /proc 目錄下的 Virtual File System。

/proc 上沒有真正的 file system，它是一個用於處理 kernel 功能的虛擬層。

```shell=
# cat /proc/cpuinfo # 獲取 cpu 處裡器資訊
```
如果檢查 /proc 目錄中檔案的大小，會發現所有大小都是 0，因為它們在 disk 上不存在

/proc 目錄中唯一具有大小的文件是`/proc/kcore` 檔案，它顯示了RAM 內容。實際上，此檔案不佔用磁盤上的任何空間。
```shell=
itachi@ubuntu:~$ ls -l /proc | grep kcore
-r--------  1 root             root             140737477881856 Sep  1 09:32 kcore
```
## Writing to Proc Files
在 /proc 下可以讀取檔案內容，但其中一些也是可寫的。
如果有多張網卡 `/proc/sys/net/ipv4/ip_forward` 控制 IP 轉發。

更改 /proc 目錄下的任何檔案或值時，無法驗證您正在執行的操作，如果設定錯誤的值或配置，可能會導致系統崩潰。

## Persisting /proc Files Changes
在 `/proc/sys/net/ipv4/ip_forward` 裡修改值，重啟後無法生效，因為沒寫入檔案裡，也因為這是 Virtual File System，更改都發生在 memory 中。

要在 /proc 下成功保存更改如下
1. 在 `/etc/rc.local` 檔案執行並啟用 systemd 服務單元
2. sysctl 指令用於更改 `/proc/sys/ ` 目錄中的檔案
```shell=
$ sysctl net.ipv4.ip_forward
$ sysctl -w net.ipv4.ip_forward=1 # -w 進行更改
$ echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf # 將更改寫入 `/etc/sysctl.conf`
```
## Common /proc Entries

|command|description|
|---|---|
|/proc/cpuinfo |information about CPUs in the system.|
|/proc/meminfo |information about memory usage.|
|/proc/ioports |list of port regions used for I/O communication with devices.|
|/proc/mdstat |display the status of RAID disks configuration.|
|/proc/kcore |displays the system actual memory.
|/proc/modules |displays a list of kernel loaded modules.|
|/proc/cmdline|displays the passed boot parameters.|
|/proc/swaps|displays the status of swap partitions.|
|/proc/iomem|the current map of the system memory for each physical device.|
|/proc/version |displays the kernel version and time of compilation.|
|/proc/net/dev |displays information about each network device like packets count.|
|/proc/net/sockstat|displays statistics about network socket utilization.|
|/proc/sys/net/ipv4/ip_local_port_range|display the range of ports that Linux uses.|
|/proc/sys/net/ipv4/tcp_ syncookies|protection against syn flood attacks.|

## Listing /proc Directory
列出 /proc 目錄中的檔案，會注意到許多具有數字名稱的目錄，這些目錄包含有關正在運行的進程的信息，而數值是相應的 process ID（PID）。
可以透過這些目錄中的特定 process 檢查消耗的資源。
```shell=
$ ls /proc
1     14    183   194  207  220  234  3    493  54   81         bus          iomem        misc          swaps
10    15    184   195  208  221  235  30   497  545  9          cgroups
```
如果看到為 1 的目錄，它屬於 **init 進程**或 **systemd**（如CentOS 7），這是 **Linux 啟動時運行的第一個進程**。

```shell=
$ sudo ls -l /proc/1
[sudo] password for itachi:
total 0
dr-xr-xr-x 2 root root 0 Sep  1 10:07 attr
-rw-r--r-- 1 root root 0 Sep  1 10:07 autogroup
-r-------- 1 root root 0 Sep  1 10:07 auxv
-r--r--r-- 1 root root 0 Sep  1 09:30 cgroup
--w------- 1 root root 0 Sep  1 10:07 clear_refs
-r--r--r-- 1 root root 0 Sep  1 09:30 cmdline
-rw-r--r-- 1 root root 0 Sep  1 09:30 comm
-rw-r--r-- 1 root root 0 Sep  1 10:07 coredump_filter
-r--r--r-- 1 root root 0 Sep  1 10:07 cpuset
lrwxrwxrwx 1 root root 0 Sep  1 10:07 cwd -> /
-r-------- 1 root root 0 Sep  1 09:29 environ
lrwxrwxrwx 1 root root 0 Sep  1 09:30 exe -> /lib/systemd/systemd
...
```
`/proc/1/exe` 檔案是個 **symbolic link** 到  `/lib/systemd/systemd` binary or `/sbin/init` 在使用二進制代碼 init 其它系統。

相同的概念適用於 /proc 目錄下的所有數字名稱的資料夾。

## /proc Useful Examples
1. SYN flood
保護您的服務器免受 SYN flood 攻擊，可以使用 iptables 來阻止 SYN packet。

最好的解決辦法使用 **SYN cookie**。kernel 中的特別用法，用於跟蹤 SYN packet，如果 SYN packet 在合理的時間間隔內沒有移動到建立狀態，內核將丟棄它們。

```shell=
$ sysctl -w net.ipv4.tcp_syncookies=1
$ echo "net.ipv4.tcp_syncookies = 1" >> /etc/sysctl.conf
```
2. 同時打開的最大文件
`/proc/sys/fs/file-max`，這個值顯示了可以同時打開的最大文件（包括 socket、file 等）。
```shell=
$ sysctl -w "fs.file-max=96992"
$ echo "fs.file-max = 96992" >> /etc/sysctl.conf
```
## sysfs Virtual File System
sysfs 是一個 Linux Virtual File System，表示它也在 memory 中。
可在 /sys 找到 sysfs 檔案系統。sysfs 可用於獲取有關系統硬體的 資訊。
```shell=
$ ls -l /sys
total 0
drwxr-xr-x   2 root root 0 Sep  1 09:30 block
drwxr-xr-x  36 root root 0 Sep  1 09:29 bus
drwxr-xr-x  66 root root 0 Sep  1 09:29 class
drwxr-xr-x   4 root root 0 Sep  1 09:29 dev
drwxr-xr-x  14 root root 0 Sep  1 09:29 devices
drwxr-xr-x   5 root root 0 Sep  1 09:30 firmware
drwxr-xr-x   9 root root 0 Sep  1 09:29 fs
drwxr-xr-x   2 root root 0 Sep  1 10:18 hypervisor
drwxr-xr-x  10 root root 0 Sep  1 09:29 kernel
drwxr-xr-x 160 root root 0 Sep  1 09:29 module
drwxr-xr-x   2 root root 0 Sep  1 10:18 power
```
檔案大小都是零，因為知道這是一個 Linux Virtual File System。
|目錄名稱|描述|
|---|---|
|Block|list of block devices deected on the system like sda.|
|Bus|contains subdirectories for physical buses detected in the kernel.|
|class|describes class of device like audio, network or printer.|
|Devices|list all detected devices by the physical bus registered with the kernel.|
|Module|lists all loaded modules.|
|Power|the power state of your devices.|

## tmpfs Virtual File System
tmpfs 是一個 Linux Virtual File System，用於將數據保存在系統虛擬 memory 中。它與任何其他 Virtual File Syste 一樣，任何文件都臨時存儲在內核的內部緩存中。

- /tmp 檔案系統用作臨時檔案的存儲位置
- /tmp 檔案系統由實際的基於 disk 的存儲支援，而不是由虛擬系統支援
- /tmp 是在引導系統時，由 systemd 服務自動創建的

使用 mount 指令設置所需大小的 tmpfs 樣式檔案系統
```shell=
mount it tmpfs -o size=2GB tmpfs  /home/myfolder
```
