# 新装环境配置ssh登录GitHub

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;自从更新到新版macOS，就发现x86架构在mac上越来越力不从心了。2018款的MBP更新到了macOS15.5，发热巨大，电池报故障，开机坚持不到五分钟就会热保护掉电关机。无奈之下，弄了台M4版本的Mac mini，虽然Mac的更换可以选择从另一台设备导入，但是MBP的备份是x86架构的，不太适合arm架构的M系列处理器，那就选择重新安装吧。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;重新安装完成后，发现homebrew的软件路径已经切换到了`/opt/homebrew`，暗自庆幸没有选择从备份中恢复，转到Mac mini后，发现托管在Github上的项目无法提交了，报错信息："`git@github.com: Permission denied (publickey). fatal: Could not read from remote repository. Please make sure you have the correct access rights and the repository exists.`"，我就知道要ssh重新走一遭了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;配置ssh登录Github要比登录一个web账号要麻烦许多，Github为什么建议选择ssh而不是https呢？主要是安全性考虑，ssh通过密钥对（公钥和私钥）进行身份验证，比https的用户名和密码更加安全。即使有人截获了你的通信，也无法伪造你的身份。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;配置与登录的过程，只需要关键字搜索一下，然后照着做就好了，但是本着探究背后发生了什么的习惯，还是记录一下这个过程。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;一个新装系统（类UNIX）环境配置ssh登录Github需要做以下工作：
1. 生成ssh密钥对，使用命令：`ssh-keygen -t rsa -b 4096 -C "your_email@example.com"`；
2. 添加公钥到Github，登录Github，使用`~/.ssh/id_rsa.pub`中的内容完成SSH key的新建工作；
3. 连接测试（可选），使用命令：`ssh -T git@github.com`，祝你一切顺利。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;接下来我们详细聊一下这三个步骤的背后发生了什么，这一切的目的是为了能够让Github确信访问它的是一个真实、可信且确定（身份）的客户端。

## 生成ssh密钥对

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;新装环境需要生成SSH密钥对，密钥对包含了公钥和私钥。使用`ssh-keygen -t rsa -b 4096 -C "your_email@example.com"`命令来生成ssh密钥对，这个命令的具体参数和作用如下。

|选项|参数|说明|
|---|---|---|
|-t|rsa|指定生成的密钥类型为RSA。RSA是一种非对称加密算法，广泛用于ssh密钥生成。|
|-b|4096|指定生成的密钥长度为4096位。密钥长度越长，安全性越高，但也会增加计算开销。|
|-C|your_email@example.com|在生成的密钥中添加一个注释，通常是一个电子邮件地址。这个注释有助于识别密钥的用途或所有者。|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;当你运行`ssh-keygen -t rsa -b 4096 -C "your_email@example.com"`命令时，会生成一个新的RSA密钥对，包含一个私钥和一个公钥，私钥将保存在一个文件中（默认是`~/.ssh/id_rsa`），公钥将保存在另一个文件中（默认是`~/.ssh/id_rsa.pub`）。ssh-keygen是交互式命令，它会提示你输入密码来保护私钥，当然密码可以为空，我这里没有什么需要保护的，就一路回车，直到密钥生成完毕。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;生成密钥对后，ssh-keygen会显示一些关于新生成密钥的信息，包括：密钥的指纹（fingerprint）和随机艺术图（random art），类似下面的内容：

```sh
Your identification has been saved in /home/your_username/.ssh/id_rsa.
Your public key has been saved in /home/your_username/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:abcdefghijklmnopqrstuvwxyz your_email@example.com
The key's random art image is:
+---[RSA 4096]----+
|                 |
|                 |
|                 |
|                 |
|                 |
|                 |
|                 |
|                 |
|                 |
+----[SHA256]-----+
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于生成的文件，私钥文件必须保密，不要泄露给任何人，公钥文件可以安全地分享给需要验证你身份的服务端（如：GitHub）。

## 添加公钥到Github

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;登录Github，进入【settings】，选择【SSH and GPG keys】一栏，可以看到类似如下内容。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/login-github-by-ssh-with-new-mac/github-ssh-keys.jpg" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;点击【New SSH key】，在key一栏中填入id_rsa.pub中的内容，其中title可以重复，这里我还是用了`weipeng2k@126.com`，提交创建之。这个过程就是将公钥给到Github。

## 连接测试

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用`ssh -T git@github.com`命令测试连接，当运行该命令时，你的ssh客户端会尝试通过ssh协议连接到GitHub的服务器。如果一切顺利，你会看到控制台有类似如下输出：

```sh
Hi username! You've successfully authenticated, but GitHub does not provide shell access.
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这个过程没有输入用户名和密码，也没有扫描二维码，简单的验证过程却比前者更安全，接下来你就可以在项目中提交代码到Github了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在执行`ssh -T git@github.com`命令时，通过wireshark进行抓取，可以看到如下访问过程：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/login-github-by-ssh-with-new-mac/ssh-login.jpg" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;认证的过程还是比较复杂的，但简单探寻一下它的过程还是有必要的，毕竟已经做了不少操作，还是弄明白的好。验证本机，也就是客户端身份，需要确定客户端拥有私钥，因为公钥用来加密，私钥用来解密，如果服务端使用客户端的公钥将一个值进行加密，客户端得到数据后能够解密成功，就证明客户端拥有了私钥，服务端将加密的数据发送给客户端的过程被称为“服务端发送挑战”，而客户端解密后进行响应的过程被称为“客户端接受挑战”。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;一般要进行多轮挑战方能确定客户端身份。根据tcpdump的内容，大致能分为三个部分，分别是：

* 红色部分，客户端和服务端在进行Key交换的准备工作，服务端会告知客户端能够支持的加密算法，客户端也会告知服务端自己的环境信息，然后由客户端选择一个双方都支持的加密算法来对传递的数据进行加密；
* 绿色部分，客户端会将公钥信息给到服务端，服务端根据公钥信息进行查询，就大致了解客户端的身份是什么，这里Github就是根据配置的公钥信息找到了Github的用户信息；
* 蓝色部分，服务端发起挑战，客户端接受挑战，服务端使用之前填写的公钥将一个数进行加密，然后客户端完成解密后并发送回服务端，这里忽略签名过程，经历了几轮挑战后，说明客户端是私钥的合法持有者，客户端身份验证成功。
