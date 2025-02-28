---
layout: default
title: Orbstack上搭建NFS服务器
date: 2025-03-29 15:25 +0800
categories: nfs
---

我在NAS上启用了NFS，并且在Mac上成功挂载，倒是没有什么太多的问题。但是在Mac上启动NFS服务器，就遇到了很多问题。

## Mac上如何启动NFS

Mac上可以通过修改`/etc/exports`文件来启动NFS，但是文件格式却和Linux的不一样。问ChatGPT，很多时候都是Linux上的语法。

```bash
/tmp/nfs-data -mapall=root -alldirs
/tmp/nfs-data -mapall=root -alldirs -network 192.168.0.0 -mask 255.255.0.0
```

然后`sudo nfsd restart`启动NFS服务，`nfsd checkexports`查看是否有语法错误，`showmount -e`会输出下面启动的NFS文件夹。

```bash
Exports list on localhost:
/Users/pzhong/Documents/github/wallets/local/nfs-data Everyone
```

`rpcinfo -p`会输出NFSD对应的端口和协议

```bash
   program vers proto   port
    100000    2   udp    111  rpcbind
    100000    3   udp    111  rpcbind
    100000    4   udp    111  rpcbind
    100000    2   tcp    111  rpcbind
    100000    3   tcp    111  rpcbind
    100000    4   tcp    111  rpcbind
    100024    1   udp    991  status
    100024    1   tcp   1021  status
    100021    0   udp    940  nlockmgr
    100021    1   udp    940  nlockmgr
    100021    3   udp    940  nlockmgr
    100021    4   udp    940  nlockmgr
    100021    0   tcp   1017  nlockmgr
    100021    1   tcp   1017  nlockmgr
    100021    3   tcp   1017  nlockmgr
    100021    4   tcp   1017  nlockmgr
    100011    1   udp    900  rquotad
    100011    2   udp    900  rquotad
    100011    1   tcp    999  rquotad
    100011    2   tcp    999  rquotad
    100003    2   udp   2049  nfs
    100003    3   udp   2049  nfs
    100003    2   tcp   2049  nfs
    100003    3   tcp   2049  nfs
    100005    1   udp    865  mountd
    100005    3   udp    865  mountd
    100005    1   tcp    752  mountd
    100005    3   tcp    752  mountd
```


## Linux中挂载Mac的NFS文件夹

假设Mac主机的IP是192.168.1.27，尝试`mount -t nfs -v 192.168.1.27:tmp/nfs-data /tmp/nfs-data`会报错。

```bash
mount.nfs: timeout set for Fri Feb 28 15:50:24 2025
mount.nfs: trying text-based options 'vers=4.2,addr=192.168.1.27,clientaddr=198.19.249.104'
mount.nfs: mount(2): Protocol not supported
mount.nfs: trying text-based options 'vers=4,minorversion=1,addr=192.168.1.27,clientaddr=198.19.249.104'
mount.nfs: mount(2): Protocol not supported
mount.nfs: trying text-based options 'vers=4,addr=192.168.1.27,clientaddr=198.19.249.104'
mount.nfs: mount(2): Protocol not supported
mount.nfs: trying text-based options 'addr=192.168.1.27'
mount.nfs: prog 100003, trying vers=3, prot=6
mount.nfs: trying 192.168.1.27 prog 100003 vers 3 prot TCP port 2049
mount.nfs: prog 100005, trying vers=3, prot=17
mount.nfs: trying 192.168.1.27 prog 100005 vers 3 prot UDP port 865
mount.nfs: mount(2): Permission denied
mount.nfs: access denied by server while mounting 192.168.1.27:tmp/nfs-data
```

但是换成`mount -t nfs -v 198.19.249.3:tmp/nfs-data /tmp/nfs-data`却可以成功挂载。

```bash
mount.nfs: timeout set for Fri Feb 28 15:52:26 2025
mount.nfs: trying text-based options 'vers=4.2,addr=198.19.249.3,clientaddr=198.19.249.104'
mount.nfs: mount(2): Protocol not supported
mount.nfs: trying text-based options 'vers=4,minorversion=1,addr=198.19.249.3,clientaddr=198.19.249.104'
mount.nfs: mount(2): Protocol not supported
mount.nfs: trying text-based options 'vers=4,addr=198.19.249.3,clientaddr=198.19.249.104'
mount.nfs: mount(2): Protocol not supported
mount.nfs: trying text-based options 'addr=198.19.249.3'
mount.nfs: prog 100003, trying vers=3, prot=6
mount.nfs: trying 198.19.249.3 prog 100003 vers 3 prot TCP port 2049
mount.nfs: prog 100005, trying vers=3, prot=17
mount.nfs: trying 198.19.249.3 prog 100005 vers 3 prot UDP port 865
```

## Linux之间互相挂载

Linux上安装`apt install nfs-kernel-server`，创建`/etc/exports`文件，通过`systemctl enable nfs-kernel-server`和`systemctl restart nfs-kernel-server`启动NFS即可。


```bash
/tmp/nfs_data *(rw,sync,no_subtree_check,all_squash,anonuid=0,anongid=0)
```

另外一个Linux上通过`mount -v -t nfs 198.19.249.104:/tmp/nfs_data /tmp/nfs_data`即可正常挂载。


## Mac挂载Linux的NFS

Mac上不能够挂载虚拟机中的NFS文件夹，现在看上去是跨网段的挂载都不行，无论从VM挂Mac，还是Mac挂VM的。

```bash
mount_nfs: can't mount /tmp/nfs_data from 198.19.249.104 onto /private/tmp/nfs_data: Operation not permitted
mount: /private/tmp/nfs_data failed with 1
```