# Performance Tuning Using Linux Process Management Commands

- [Performance Tuning Using Linux Process Management Commands](#performance-tuning-using-linux-process-management-commands)
          + [tags: `Ubuntu`](#tags---ubuntu-)
  * [Process Types](#process-types)
  * [Memory Management](#memory-management)
  * [Managing virtual memory with vmstat](#managing-virtual-memory-with-vmstat)
  * [System Load & top Command](#system-load---top-command)
  * [Monitoring Disk I/O with iotop](#monitoring-disk-i-o-with-iotop)
  * [ps command](#ps-command)
  * [Monitoring System Health with iostat and lsof](#monitoring-system-health-with-iostat-and-lsof)
  * [Calculating the system load](#calculating-the-system-load)
  * [pgrep and systemctl](#pgrep-and-systemctl)
  * [Managing Services with systemd](#managing-services-with-systemd)
  * [Nice and Renice Processes](#nice-and-renice-processes)
  * [Sending the kill signal](#sending-the-kill-signal)

在服務器管理中，了解正在運行的進程如何詳細工作非常重要，從高負載到慢響應時間進程。當您的服務器變得如此緩慢或無法響應時，您應該了解特定於操作的進程管理或 Linux 進程管理。

什麼時候 *kill* 進程或者 *renice*，以及如何 *monitor* 當前正在運行的進程以及這些進程如何影響系統負載。讓我們看看 Linux 進程管理將如何幫助我們調整系統。

## Process Types
我們應該檢查進程類型。有四種常見的流程類型：
- Parent process(父進程)
    - 是一個運行 `fork()` 系統調用的進程。除進程 0 之外的所有進程都有一個父 process。
- Child process(子進程)
    - 由父進程創建
- Orphan Process(孤立進程)
    - 在父進程終止或完成時繼續運行。
- Daemon Process(守護程序進程)
    - 總是從子進程創建守護程序進程，然後退出
- Zombie Process(殭屍進程)
    - 殭屍進程雖然終止，但仍存在於進程表(process table)中

孤兒進程是一個仍在執行的進程，其父進程已經死亡，而孤立進程不會成為殭屍進程。

## Memory Management
在服務器管理中，memory 管理是作為系統管理員應該關注的責任之一。

free 是最常見命令之一
```shell
$ free -m
              total        used        free      shared  buff/cache   available
Mem:           1982         216        1142          14         622        1570
Swap:           975           0         975

```

我們主要關注`buff/cache`。

這裡的 `free` 輸出表示使用 622 megabytes，而 1570 megabytes 可用。

第二行是 swap。當 memory 變得擁擠時發生 swap。第一個值是總交換大小，即 975 megabytes。第二個值是使用的swap，它是 0。第三個值是使用的可用交換，即 975 megabytes。

從上面的結果可以看出 memory 狀態是好的，因為沒有使用 `swap`，所以當我們談論 swap 時，讓我們**發現 `proc` 目錄為我們提供了有關 swap 的內容**。

```shell=
$ cat /proc/swaps
Filename                                Type            Size    Used    Priority
/dev/dm-1                               partition       999420  0       -1
```

此顯示 `swap` 大小和使用量：

```shell=
$ cat /proc/sys/vm/swappiness
60
```
此顯示 0 到 100 之間的值，此值表示如果 memory 使用率為 40％，系統將使用 `swap`。

注意：此值的大多數發行版的默認值在 30 到 60 之間，可以像這樣修改它：
```shell=
$ sudo su -c "echo 50 > /proc/sys/vm/swappiness" # method1 
$ sudo sysctl -w vm.swappiness=50 # method2
$ cat /proc/sys/vm/swappiness
50 # 從 60 變更至 50
```

用上述方式更改 `swappiness` 值**不是永久性**的，需將其寫在 `/etc/sysctl.conf` 文件中，如下所示：
```shell=
$ sudo su -c "echo vm.swappiness=50 | tee -a /etc/sysctl.conf"
```

swap 等級衡量將進程從 memory 轉移到 swap 的機會。

為系統選擇準確的 `swappiness` 值需要進行一些實驗，以便為服務器選擇最佳值。

## Managing virtual memory with vmstat
Linux 進程管理中使用的另一個重要命令是 vmstat。 vmstat 命令提供有關 memory，process 和 page 的摘要報告。

```shell=
$ vmstat -a # -a 表示 all，選項用於獲取所有活動和非活動進程
procs -----------memory---------- ---swap-- -----io---- -system-- ----cpu----
 r  b   swpd   free  inact active   si   so    bi    bo   in   cs us sy id wa
 1  0      0 505940 4829432 2356708    0    0    33    58    3    3  0  0 98  2
```
輸出
- si
    - 從 disk 交換了多少進來
- so
    - 從 disk 交換了多少出去
- bi
    - 發送到 block devices 有多少
- bo
    - 從 block devices 取得多少
- us
    - 使用時間(user time)
- sy
    - 系統時間(system time)
- id
    - 閒置時間(idle time)

主要關心的是 `si` 和 `so` 列，其中 `si` 列顯示 `page-ins`，而 `so` 列提供 `page-outs`。

查看這些值的更好方法是使用這樣的延遲選項查看輸出：

```shell=
$ vmstat 2 5 # 2 是以秒為單位的延遲；5 是調用vmstat 的次數，每調用及更新
procs -----------memory---------- ---swap-- -----io---- -system-- ----cpu----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa
 1  0      0 521452 330572 6709628    0    0    33    58    3    3  0  0 98  2
 0  0      0 521536 330572 6709628    0    0     0     2  123  347  0  0 100  0
 0  0      0 521388 330572 6709628    0    0     0    32  114  278  0  0 99  0
 0  0      0 521932 330572 6709624    0    0     0     0  169  340  0  0 100  0
 0  0      0 521076 330572 6709628    0    0     0    60  119  272  0  0 100  0
```

所有數據以 `kilobytes` 為單位。

當啟動應用程式並且訊息被分頁時，會發生 `Page-in（si）`。當 kernel 釋放 memory 時發生` Page out（so）`。

## System Load & top Command
在 Linux 進程管理中，`top` 為您提供正在運行的進程列表以及它們如何使用 `CPU` 和 `memory`，`top` 輸出是即時數據。

```shell=
$ top -c # -c 選項來顯示該進程後面的命令行或可執行檔案路徑。
top - 10:27:59 up 18 days,  9:25,  1 user,  load average: 0.03, 0.36, 0.51
Tasks: 188 total,   1 running, 187 sleeping,   0 stopped,   0 zombie
Cpu(s):  0.2%us,  0.2%sy,  0.0%ni, 98.1%id,  1.5%wa,  0.0%hi,  0.0%si,  0.0%st
Mem:   8068032k total,  7548376k used,   519656k free,   330592k buffers
Swap:  2093052k total,        0k used,  2093052k free,  6711316k cached

  PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND
   16 root      20   0     0    0    0 S    0  0.0   4:27.78 [rcuos/2]
   99 root      20   0     0    0    0 S    0  0.0   2:03.91 [kworker/3:1]
 1640 root      20   0 25112 1684 1364 S    0  0.0  11:17.87 /usr/lib/postfix/master
15518 postfix   20   0 27188 1548 1268 S    0  0.0   0:00.03 trivial-rewrite -n rewrite -t unix -u -c
    1 root      20   0 24448 2400 1340 S    0  0.0   0:32.08 /sbin/init
    2 root      20   0     0    0    0 S    0  0.0   0:00.36 [kthreadd]
    3 root      20   0     0    0    0 S    0  0.0   0:07.65 [ksoftirqd/0]
    5 root       0 -20     0    0    0 S    0  0.0   0:00.00 [kworker/0:0H]
    7 root      RT   0     0    0    0 S    0  0.0   0:01.69 [migration/0]

```

可以在查看 `top` 命令統計信息時按 `1` 鍵以顯示各個`CPU` 狀態。

```shell=
top - 10:29:51 up 18 days,  9:26,  1 user,  load average: 0.83, 0.58, 0.58
Tasks: 231 total,   1 running, 230 sleeping,   0 stopped,   0 zombie
Cpu0  :  0.3%us,  0.0%sy,  0.0%ni, 97.7%id,  2.0%wa,  0.0%hi,  0.0%si,  0.0%st
Cpu1  :  0.0%us,  0.0%sy,  0.0%ni,100.0%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
Cpu2  :  0.0%us,  0.3%sy,  0.0%ni, 99.7%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
Cpu3  :  0.3%us,  0.3%sy,  0.0%ni, 99.3%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
Mem:   8068032k total,  7570252k used,   497780k free,   330600k buffers
Swap:  2093052k total,        0k used,  2093052k free,  6712316k cached
```

請記住，某些進程像子進程一樣生成，可看到同一程序的多個進程，如 `httpd` 和 `PHP-fpm`。


不應該只依賴 `top` 工具，在進行最終操作之前應該檢查其他資源。

## Monitoring Disk I/O with iotop
由於 disk 活動較多，系統開始變慢，因此監控 disk 活動非常重要。這意味著要確定哪些**進程**或**用戶**會導致此 disk 活動。

Linux 進程管理中的 `iotop` 工具可以即時監視 disk I/O。
```shell=
# 安裝
$ sudo apt-get  install iotop -y
```

在沒有任何參數選項的情況下運行 `iotop` 將導致列出所有進程。

```shell=
$ sudo iotop -o # -o 查看讓 disk 活動的進程
Total DISK READ:       0.00 B/s | Total DISK WRITE:      98.02 K/s
  TID  PRIO  USER     DISK READ  DISK WRITE  SWAPIN     IO>    COMMAND
  329 be/3 root        0.00 B/s   15.68 K/s  0.00 %  3.38 % [jbd2/sda1-8]
 6501 be/4 root        0.00 B/s    0.00 B/s  0.00 %  0.39 % [kworker/u8:4]
 1762 be/4 root        0.00 B/s    0.00 B/s  0.00 %  0.29 % [kworker/u8:2]
 8648 be/4 root        0.00 B/s    0.00 B/s  0.00 %  0.20 % [kworker/u8:1]
 7341 be/4 root        0.00 B/s    0.00 B/s  0.00 %  0.10 % [kworker/u8:
```

## ps command
ps 列出當前正在運行的進程。
```shell=
$ ps -aux
Warning: bad ps syntax, perhaps a bogus '-'? See http://procps.sf.net/faq.html
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.0  24448  2400 ?        Ss   Aug21   0:32 /sbin/init
root         2  0.0  0.0      0     0 ?        S    Aug21   0:00 [kthreadd]
root         3  0.0  0.0      0     0 ?        S    Aug21   0:07 [ksoftirqd/0]
root         5  0.0  0.0      0     0 ?        S<   Aug21   0:00 [kworker/0:0H]
root         7  0.0  0.0      0     0 ?        S    Aug21   0:01 [migration/0]
root         8  0.0  0.0      0     0 ?        S    Aug21   0:00 [rcu_bh]
```

類似於 `top -c` 結果

## Monitoring System Health with iostat and lsof

`iostat` 工具為您提供 CPU 使用率報告。它可以與 `-c`參數一起使用以顯示 `CPU` 使用率報告。

```shell=
# instll
$ sudo apt install sysstat -y
```
```shell=
$ iostat -c
Linux 4.4.0-116-generic (ubuntu)        09/08/2019      _x86_64_        (1 CPU)

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.33    0.10    0.61    0.06    0.00   98.89
```

輸出結果很容易理解，但如果系統繁忙，您將看到 `％iowait` 增加。這表示服務器正在傳輸或複制大量檔案。

使用此工具，可以檢查`讀取`和`寫入`操作，因此您應該充分了解放在 disk 的內容並做出正確的決定。

此外，`lsof` 用於列出打開的文件。`lsof` 顯示正在使用該檔案的可執行檔案、進程 ID、用戶以及打開檔案的名稱。

```shell=
$ lsof | grep itachi
sshd       9882     itachi  cwd   unknown                          /proc/9882/cwd (readlink: Permission denied)
sshd       9882     itachi  rtd   unknown                          /proc/9882/root (readlink: Permission denied)
sshd       9882     itachi  txt   unknown                          /proc/9882/exe (readlink: Permission denied)
sshd       9882     itachi NOFD                                    /proc/9882/fd (opendir: Permission denied)
sshd       9883     itachi  cwd   unknown                          /proc/9883/cwd (readlink: Permission denied)
sshd       9883     itachi  rtd   unknown                          /proc/9883/root (readlink: Permission denied)
sshd       9883     itachi  txt   unknown                          /proc/9883/exe (readlink: Permission denied)
sshd       9883     itachi NOFD                                    /proc/9883/fd (opendir: Permission denied)
sftp-serv  9886     itachi  cwd       DIR   8,17     4096  2623749 /home/home1/107GB/student/itachi
sftp-serv  9886     itachi  rtd       DIR    8,1     4096        2 /
sftp-serv  9886     itachi  txt       REG    8,1    63552 12976936 /usr/lib/openssh/sftp-server
sftp-serv  9886     itachi  mem       REG    8,1    52120 23331076 /lib/x86_64-linux-gnu/libnss_files-2.15.so
sftp-serv  9886     itachi  mem       REG    8,1    47680 23331075 /lib/x86_64-linux-gnu/libnss_nis-2.15.so
sftp-serv  9886     itachi  mem       REG    8,1    97248 23330842 /lib/x86_64-linux-gnu/libnsl-2.15.so
sftp-serv  9886     itachi  mem       REG    8,1    35680 23331078 /lib/x86_64-linux-gnu/libnss_compat-2.15.so
sftp-serv  9886     itachi  mem       REG    8,1  1811128 23331080 /lib/x86_64-linux-gnu/libc-2.15.so
sftp-serv  9886     itachi  mem       REG    8,1   149280 23330857 /lib/x86_64-linux-gnu/ld-2.15.so
sftp-serv  9886     itachi    0r     FIFO    0,8      0t0 31451227 pipe
sftp-serv  9886     itachi    1w     FIFO    0,8      0t0 31451228 pipe
sftp-serv  9886     itachi    2w     FIFO    0,8      0t0 31451229 pipe
bash       9887     itachi  cwd       DIR   8,17     4096  2623749 /home/home1/107GB/student/itachi

```
## Calculating the system load
計算系統負載在 Linux 進程管理中非常重要。系統負載是當前正在運行的系統的處理量。它不是衡量系統性能的完美方式，但它為您提供了一些數據。

負載計算如下：
```
Actual Load = Total Load (uptime) / No. of CPUs
```
可以透過查看 `uptime` 或 `top` 來計算正常運行時間：
```shell=
$ uptime
 10:48:50 up 18 days,  9:45,  1 user,  load average: 1.51, 0.67, 0.56
$ top
top - 10:49:37 up 18 days,  9:46,  1 user,  load average: 0.79, 0.60, 0.54
... 
```

服務器負載 `load average` 顯示為 1、5 和 15 分鐘的值。

可以說良好的負載平均值約為 `1`。這並不意味著如果負載超過 `1` 表示存在問題，但如果開始長時間看到更高的數字，則意味著高負載並且存在問題。


## pgrep and systemctl
可使用 `pgrep` 後跟服務名稱來獲取進程 ID。
```shell=
$ pgrep sshd
1235
2161
2170
2256
2273
```
如果顯示的進程 ID 超過 `httpd` 或 `SSH`，則最小的進程ID 是父進程 ID。

另一方面，可以使用 `systemctl` 命令獲取 main PID，如下所示：
```shell=
$ systemctl status [SERVICE]
```
這並非唯一獲取的方法

## Managing Services with systemd
systemd 負責控制現代 Linux 系統上管理服務的方式。啟動、關閉、重啟等操作

Systemd 還附帶了自己版本的 `top`，為了顯示與特定服務相關的進程，您可以使用 `system-cgtop`，如下所示：
```shell=
$ systemd-cgtop
```
輸出所有相關的進程、路徑、任務數、所用 CPU 的百分比、內存分配以及相關的輸入和輸出。


此工具可用於輸出服務內容的遞歸列表，如下所示：
```shell=
$ systemd-cgls
Control group /:
-.slice
├─init.scope
│ └─1 /sbin/init
├─system.slice
│ ├─mdadm.service
│ │ └─1080 /sbin/mdadm --monitor --pid-file /run/mdadm/monitor.pid --daemonis...
│ ├─dbus.service
│ │ └─1012 /usr/bin/dbus-daemon --system --address=systemd: --nofork --nopidf...
│ ├─cron.service
│ │ └─1026 /usr/sbin/cron -f
│ ├─lvm2-lvmetad.service
│ │ └─531 /sbin/lvmetad -f
│ ├─iscsid.service
│ │ ├─1277 /sbin/iscsid
│ │ └─1278 /sbin/iscsid
│ ├─nginx.service
│ │ ├─1384 nginx: master process /usr/sbin/nginx -g daemon on; master_process...
│ │ └─1385 nginx: worker process
│ ├─accounts-daemon.service
│ │ └─1045 /usr/lib/accountsservice/accounts-daemon
│ ├─atd.service
│ │ └─1036 /usr/sbin/atd -f
...
```


## Nice and Renice Processes
進程 nice 值是一個數字指示，屬於進程以及它如何為 CPU 對抗。

高 `nice` 的值表示您的進程的優先級較低，對其他用戶的`nice` 方式，以及此名稱來自此處。

`nice` 的範圍從 `-20` 到 `+19`。

`nice` 在創建時為進程設置 `nice` 值，而 `renice` 命令稍後調整該值。

```shell=
$ sudo nice –n 5 ./myscript
```
增加 `nice` 值，這意味著優先級降低 5。
```shell=
$ sudo renice -5 [servicePID]
```
減少 `nice` 值意味著增加優先級。

## Sending the kill signal
要終止導致問題的服務或應用程序，您可以發出終止信號（SIGTERM）。

這種方法稱為`安全 kill`。但是，根據您的情況，可能需要強制服務或應用程序掛起，如下所示：

```shell=
$ kill -1 [process ID]
```
有時安全 kill 和 reloading 無法執行任何操作，您可以使用 `-9` 選項發送終止信號 `SIGKILL`，該選項稱為強制終止。

```shell=
$ kill -9 [process ID]
```

使用此命令沒有清理操作或安全退出，不是最好的辦法。但是，可以使用 `pkill` 命令執行更合適的操作。再用 `pgrep`去檢測有無成功。

```shell=
$ pkill -9 [serviceName]
```
