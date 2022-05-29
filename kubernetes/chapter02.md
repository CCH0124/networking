假設一個程式在 Linux 服務器上運行，並且外部客戶端向 `/` 路徑發出請求。服務器上會發生什麼？首先，我們的程式需要監聽地址和端口。我們的程式為該地址和端口創建一個套接字(socket)並綁定到地址和端口。套接字將接收發往指定地址和端口的請求。

使用 docker 運行一個 nginx。
```bash
$ docker ps -a
CONTAINER ID   IMAGE                                COMMAND                  CREATED       STATUS                   PORTS                               NAMES
7b860261207f   nginx                                "/docker-entrypoint.…"   2 weeks ago   Up 19 seconds            0.0.0.0:80->80/tcp, :::80->80/tcp   peaceful_greider
```

使用 `ss` 查看該主機上監聽的應用程式服務，在啟動 nginx 容器後，主機監聽了 80 port。

```bash
$ ss -lt
State         Recv-Q        Send-Q               Local Address:Port               Peer Address:Port       Process
LISTEN        0             4096                       0.0.0.0:http                    0.0.0.0:*
LISTEN        0             4096                          [::]:http                       [::]:*
```

有多種方法可以檢查套接字(socket)，下面使用 ` ls -lah /proc/<server proc>/fd`。

```bash
$ ps -aux | grep "nginx"
root     10130  0.0  0.0   8852  6060 pts/0    Ss+  16:15   0:00 nginx: master process nginx -g daemon off;
...
```

```bash
# 當 process 運行時會產生 PID，會映射 fd 到目錄
$ sudo su -c "ls -lah /proc/10130/fd"
[sudo] password for cch:
total 0
dr-x------ 2 root root  0 May 29 16:15 .
dr-xr-xr-x 9 root root  0 May 29 16:15 ..
lrwx------ 1 root root 64 May 29 16:15 0 -> /dev/pts/0
lrwx------ 1 root root 64 May 29 16:15 1 -> /dev/pts/0
lrwx------ 1 root root 64 May 29 16:19 10 -> 'socket:[98195]'
lrwx------ 1 root root 64 May 29 16:19 11 -> 'socket:[98196]'
lrwx------ 1 root root 64 May 29 16:19 12 -> 'socket:[98197]'
...
```

內核將給定的封包映射到特定的連接，並使用內部狀態機來管理連接狀態。像套接字一樣，可以通過各種工具檢查連接。 Linux 用一個*檔案*表示每個連接，接受連接需要內核向我們的程序發出通知，然後程序能夠將內容傳輸到檔案和從檔案中送出。
