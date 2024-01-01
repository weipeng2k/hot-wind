# 感悟《计算机网络：自顶向下》（02.应用层）

## 应用层简介

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;应用层处于计算机网络TCP/IP协议栈`5`层结构中的最上层，也是是最丰富多彩的一层，今天用户使用的互联网应用大都处于这一层，并且大部分知名应用（也包括游戏）都是分布式应用。例如，手机淘宝应用，在用户手机终端会安装手机淘宝APP，同时淘宝也会部署服务器，在服务器上跑着会员、商品和交易等系统，手机淘宝APP和服务器应用进行网络通信，其通信基于协议。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;协议的目的就是就双方沟通而言，无歧义的讲清楚一件事，它包括：语法、语义、次序和动作，在文本随后常见应用层技术一节，会以HTTP协议为例进行介绍。应用层协议一般来说分为公开协议和私有协议，比如：HTTP协议就是公开协议，开发者可以自由的编写其客户端或服务端，并与其他的客户端或服务端兼容，只要你遵守这个公开协议即可，而私有协议是开发者或组织自行定义的，外部人员很少掌握，定义的目的往往在于偏科式的解决某些特定问题。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;应用层位于传输层上面，使用（传输层提供的）socket编程接口来实现应用功能，应用层对于传输层服务有以下几点要求：

1. 可靠，能否将字节数据可靠的传输到目标端；
2. 延迟，数据传递时尽可能的少受到外界影响，尽快的抵达目标端；
3. 吞吐，单位时间内传输的数据尽可能多；
4. 安全，传输过程是否安全，能否做到通信私密、防篡改或不丢失。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这些点不是说所有应用都要求传输层能做到，并且传输层也不可能同时兑现这么多要求，而且有些点是相互矛盾的，这只能是一种tradeoff。以视频在线播放为例，短时间要传递大量数据，数据中偶尔有一些字节出错，或者部分包丢失，问题也不大，只是影响一点点画质，所以这种应用对于延迟和吞吐就很关注，对于可靠性就没有那么在意。再以电子邮件为例，它要求数据传输准确，不能有偏差，对于可靠性要求很高，但是延迟和吞吐就没有多少诉求。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;因此不同的应用需要结合自身的需求，来选择传输层提供的服务。传输层一般提供的服务有两种：一种是面向连接可靠的传输服务[TCP](https://baike.baidu.com/item/TCP/33012)，另一种是仅在[IP](https://baike.baidu.com/item/IP/224599)协议上做了薄层封装，基于用户数据报的传输服务[UDP](https://baike.baidu.com/item/UDP)，它们的共性是都具备了端口这个概念。

### 进程通信

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;传输层拥有端口的概念，就是为了支持（应用）进程通信。手机淘宝APP和淘宝服务器应用的通信，是手机操作系统上一个叫手机淘宝的进程与部署在阿里巴巴数据中心里某台服务器上的一个服务端应用进程的通信。通过给定端口，可以指定对端的进程，比如：指定对端IP的`80`号端口，该端口可能就对应一个进程ID为`4321`的Apache服务器进程，因此标识一个进程，需要有三个属性，如下表所示：

|名称|描述|
|----|----|
|主机IP|对端主机的IP|
|传输层协议|TCP或UDP|
|端口|端口号|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，如果IP相同，端口也相同，但是提供的服务端进程还需要区分是跑在UDP或TCP上，在不同的传输层协议上，也是不同的，因为客户端在进行socket编程时，会明确的使用不同的编程接口。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;应用层基于socket进行编程，不同语言SDK的网络编程界面有所不同，但是编程模型和方式都是类似的，因为本质上这些SDK都是通过`socket`与本地操作系统的协议栈打交道。对于网络的访问都是委托给操作系统协议栈来完成，而不同操作系统基本都集成了TCP/IP协议栈，遵守其规范，所以功能层面差不多，这就使得这些SDK的网络部分基本都长得差不多。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果进行网络编程时，两端IP和端口，至少`4`个属性，用起来感觉不麻烦的话，大抵也就没有`socket`编程了。因为完全可以基于这些参数调用系统API，但是这样会显得非常凌乱，所以提供了一个封装了上述`4`个属性的数据结构来作为双方通信的标识，它就称为`socket`。

> socket可以是编程界面，也可以是对网络编程数据结构的定义。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于TCP而言，`socket`是一个四元组，可以表示为`<dst-IP, dst-Port, src-IP, src-Port>`，其中`dst`表示目标，而`src`表示来源。这个四元组的内容仅本地操作系统协议栈知晓，对端并不知情，本质上就是一种便于管理的数据结构，它可以对应到本机系统中的一个进程，也属于一种本地标识。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于UDP而言，`socket`是一个二元组，可以表示为`<src-IP, src-Port>`，它在数据发送时，才会要求提供目标的IP和端口，当然它也是本地的一个标识，只是不用事先提供目标IP和端口而已。

### 网络架构

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从应用层角度看，网络架构分为两种：一种是`C/S`，另一种是`P2P`。`C/S`好理解，我们使用的浏览器其实就是`C/S`，`C`是浏览器，`S`是某个网站，只是浏览器比较复杂，支持很多功能特性，说好听点就叫`B/S`，但本质上还是`C/S`。`P2P`是（无中心节点的）点到点通信，管理难度高，但是可用性和利用率上相较于`C/S`有优势，毕竟`S`的服务能力是存在上限的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;虽然应用网络架构分为两种，但是应用并不会执着于一种，而是存在混合架构的情况。以分布式RPC框架[Dubbo](https://baike.baidu.com/item/Dubbo/18907815)为例，它就是一种典型的混合架构，其架构特点如图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/dubbo-arch.png" width="80%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到Dubbo在服务发现阶段是C/S架构，而运行时调用阶段又属于`P2P`架构。因此选择应用网络架构时，需要结合应用自身特点和需求来进行设计，而不是一种非`0`即`1`的选择。

## 常见应用层技术

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;应用层常见的技术有很多，我们就算简单的打开浏览器访问一个网站，也会同时用到多种技术，比如：域名需要解析为IP，会使用到DNS技术；访问页面，会使用到HTTP技术；如果页面中包含了一些图片或样式资源，会使用到CDN技术。可以看到不同的技术解决不同的问题，虽然用户做了一个简单操作，但实际会涉及到非常多的技术。接下来，简单介绍几种常见的应用层技术。

### HTTP

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;HTTP是互联网中最常用的技术，它遵循请求和响应模型，HTTP协议的请求和响应结构如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/http-protocol.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;前文提到，协议包括：语法、语义、次序和动作，对于HTTP协议而言，语法就是命令式的指令，语义包括了HTTP的操作，比如：获取资源的GET、提交资源的POST，每一个语义都代表了HTTP协议的行为目的。HTTP协议由客户端发起，服务端响应，一来一回，这就是它的次序，而请求到达服务端，服务端如何处理，以及回复的响应，客户端该如何理解发回的响应，这就是协议对应的动作。

### Email

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Email在即时通讯以及社交软件走红后，大家用的越来越少了，但是在互联网早期它和HTTP网页应用是两个最主流的应用，它由用户代理客户端和邮件服务器组成，它们之间的关系如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/email-protocol.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;用户代理或邮件服务器通过SMTP协议向对端传送邮件，其中邮件服务器中会给每个用户一个专属的邮箱。邮件服务器之间也是通过SMTP协议来进行互传的，用户代理通过POP3协议从邮件服务器上拉取邮件到本地。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Email协议以及运作过程看起来像模拟了真实邮件的传递，邮件从一家邮局到另一家，而用户只需要到自己开户的邮局去取件即可。可以想象，如果对该过程进行建模，将协议中的需求放到HTTP协议中，也是可以实现电子邮件的，只是说在互联网早期，很多应用层协议就是根据自己的场景，专属化的被定义出来，其协议的数据结构也是良莠不齐，扩展性也很拙劣。