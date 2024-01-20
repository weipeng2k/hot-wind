# 感悟《计算机网络：自顶向下》（03b.传输层）

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在完成RDT协议从`1.0`到`3.1`的演进后，可以证明在一个不可靠的网络层服务商上是能够利用软件协议构建出一个不出错、不丢失和不乱序的传输层服务。如果只是局限在两端通信的维度，将两端之间的分组交换设备视作透明的，那`RDT 3.1`其实已经算是一个挺不错的传输层协议了，但是网络的复杂性始终在向你证明，看似简单而相同的节点所组成的网络，随着规模的扩大，有很多意想不到的问题会出现。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分组交换由于具备高可用和低成本的特点，从而取代了线路交换，计算机通信终于摆脱了电报电话网络。而在分组交换上构建网络时，面对的是众多接入方（以及旧有网络），势必需要提出一致且简洁的协议来应对需求，这就是[TCP/IP协议](https://baike.baidu.com/item/TCP/IP协议/212915)。其中TCP向上承担不同种类网络通信SDK的接入，向下利用不可靠的IP协议构筑可靠的通信服务，同时能够观察网络状况，避免拥塞。TCP协议自1968年开始出现，随着1995年的互联网大发展而成为使用最为广泛的传输层协议。

## 协议结构

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;回想`RDT 3.1`协议中对报文`Segment`的定义，其中包括属性：`srcPort`、`disPort`、`data`、`checkSum`、`sequence`、`ack`、`rwnd`以及`sign`，共`8`个。用一句话概述就是，报文`Segment`定义了来源端口`srcPort`，表示数据来自`srcPort`对应的进程，需要发送到目标端口`dstPort`对应的进程，同时携带了数据`data`以及`data`的签名`checkSum`，该`Segment`的序号是`sequence`，而本地已经成功收到了对端`ack`个数据，`Segment`的业务含义见`sign`，收到请求后如果发回响应数据，建议连续发送报文的长度不要超过`rwnd`。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这么看`Segment`考虑的挺周到，接下来看一下TCP协议是如何设计的，如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/tcp-protocol.jpg" width="90%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，TCP协议设计的比较紧凑，从第`4`行的数据偏移量，也就是协议头的长度可以看出来，TCP协议是一个变长协议。协议自上而下，分别是发送端和接收端的端口，发送编号与响应编号，以及`6`位的保留位，`6`位的控制位和`16`位的窗口大小。如果对应到`RDT 3.1`的`Segment`上，缺失的概念就只剩下数据偏移量和紧急指针了，后者协议栈实现可以不关注，算是个可有可无的概念，接下来还是看一下数据偏移量。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;数据偏移量`Headersize`表示的是TCP头的长度，字节数一般会乘以`4`，主要是只有`4`位的Headersize最多也就表示`15`，所以用一个乘`4`的方式可以多表示一些内容。如果只有TCP头的长度，那么携带的`data`长度如何表示呢？这就需要用到IP协议，因为在IP协议上会标出IP分组的长度以及IP头的长度，由于TCP报文是作为IP的`payload`，所以用户需要传输的data长度可以通过公式`(IP分组长度 - IP头长度 - TCP头长度)`计算得到。如果从变长协议的规范看，变长协议至少要包括数据报的总长度以及协议头长度（或者数据体长度）两个长度才能正常工作，因此TCP协议其实算不上一个能独立运作的协议，更直白的说，TCP是IP上的一种功能应用，是IP协议上的一种处理策略。

> TCP/IP协议最原始的版本TCP和IP本来就设计在一起。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;UDP协议是定长协议，也就是头部始终是`8`个字节，但是其数据内容长度字段是单独标识的，所以UDP协议可以算是一个能独立运作的协议，从这点看TCP协议设计的水平还不怎么高，不自洽，不完备，但是和很多计算机底层技术一样，设计的不完美，但是不妨碍用。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于控制位，功能也就是类似RDT协议中`Segment.sign`，它是`6`位的，也就是有`6`种功能，由于是按位表示功能，所以这些功能可以叠加。具体功能和描述如表所示，其中位数是自右向左：

|名称|位数|描述|
|----|----|----|
|URG|6|表示紧急指针有效|
|ACK|5|表示ACK号有效，因为ACK号是每次TCP传输中都携带的，假设第一次建立连接的TCP报文，其ACK号字段显然是无意义的，此时就需要控制位中的ACK来告知当前报文中的ACK号是否有意义|
|PSH|4|Flush操作，将发送数据从缓存中发到网络|
|RST|3|强制断开连接|
|SYN|2|发送和接收相互确认的需要，回忆RDT协议中建立连接的过程，目的就是同步序号到对端的游标，目的是达成共识|
|FIN|1|断开连接|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;TCP协议的实现依靠协议栈程序，不同操作系统的实现会有不同，但由于TCP协议是标准的，所以不同操作系统的协议栈程序依旧能完成相互通信，简单说就是不同操作系统可以使用网络进行相互通信。

## 建立连接

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在RDT协议的设计演化过程中，`3.1`版本的RDT提到了连接建立，它是通过三次单向的报文请求来实现通信两端对于连接状态能够达成共识。TCP协议也是一样，通过“三次握手”来建立连接。连接建立除了交换发送编号、接收数据的窗口大小，还包括链路层帧的大小，也就是[MTU（Maximum Transmission Unit）](https://baike.baidu.com/item/最大传输单元)的大小。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;传输层的连接建立关数据链路层什么事？管得也太宽了吧。在介绍原因之前，先简单看一下MTU是什么。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;MTU表示数据链路层一个帧所能携带的最大数据量，帧的单位还是字节，毕竟在二层以上还属于字节，到物理层就是信号了。数据链路层的实现由很多，目前使用最广泛的就是以太网，以太网默认是`1500`字节，其结构如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/tcp-ethernet-with-ip.jpg" width="60%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到IP分组被装在一个帧里面，如果一个IP分组的大小超过了当前数据链路层的上限，它会被拆分到多个帧中，那么除了第一个帧还可以从IP分组头部信息中知道自己是谁，后面的帧里面装的就是阿巴阿巴了。从完整性的角度考虑，IP分组需要能够按照当前数据链路层定义的MTU大小来做好自身分片的规划，IP协议如此，TCP协议作为IP协议上层的一个“**应用**”，连协议头都不完备的它（TCP）就更没有资格讨价还价了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;虽然数据链路层定义了MTU，但是传输的数据中包含了IP与TCP的头信息，所以还需要将头信息数据从MTU的载荷中减去，由此得到[MSS（Maximum Segment Size）](https://baike.baidu.com/item/MSS/3567802)，最大的报文长度，看Segment就知道它是面向传输层的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于数据传输而言，上述分片策略如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/tcp-mss.jpg" width="90%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，对于一个完整的HTTP协议消息（注意：称消息表示该协议属于应用层），它的尺寸无疑是相对较大的，因此它会被按照MSS做分拆，拆好的数据会添加对应的TCP协议头，最终被放置到IP分组中发往对端。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;不同数据链路层通过适配TCP/IP协议来做到互联互通。如果一个MTU是6400字节的数据链路层实现与以太网（1500字节）进行通信，以太网向对端发送的帧理论上能够被其识别，反之则不然。因此在进行TCP建连时，还需要交换自身的MSS大小，双方需要协商出一个用于通信的MSS，也就是取得`min(MSS[src], MSS[dst])`作为当前TCP连接所使用的MSS。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;发起建连的一方，TCP报文的控制位SYN为真，sequence是随机生成的，只是表示一个位点，随后发送多少字节，它就会增加多少，而随机初始化一个值的目的主要是出于安全考虑。至于接收窗口是TCP报文头中定义的，而MSS这类的信息会放在TCP协议定义的可选字段中携带过去。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;TCP协议建连的“三次握手”过程，如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/tcp-connect-seq.jpg" width="90%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，客户端发起建连操作，由程序调用`socket`来完成，一般步骤都是先定义服务端的IP和端口，也就是准备好服务端的`Endpoint`，然后客户端调用`connect`方法进行连接。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在发送`SYN报文`之前，客户端协议栈需要为当前TCP连接分配好接收与发送缓存，同时完成本地（随机）端口的绑定，该端口的目的是向协议栈注册进程与端口的对应关系，保证对方回报文后，能根据它找到来时的路。当缓存开辟完成，准备工作就绪后，还需要使用网络层提供的[Path MTU Discovery机制](https://www.ibm.com/docs/en/aix/7.3?topic=protocol-path-mtu-discovery)，查询出当前数据链路层的MTU大小。一般该机制通过网络层ICMP协议实现，也就是调用对端之前，先撸一下自己，得到MSS后，就可以发送`SYN报文`了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`SYN报文`包含了随机生成的`sequence`，接收窗口`rwnd`以及MSS等信息，然后将报文转换为分组并依托IP协议的路由转发，如果一切顺利将会抵达服务端。如果发送的`SYN报文`丢失，TCP还会有重试机制，通过报文重传来确保可靠性，当然服务端收到报文后，也会校验一下，如果通过了，接下来就该服务端出牌了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;服务端收到`SYN报文`，由于服务端程序先期绑定到了对应网卡和端口上，所以`SYN报文`中的目标端口是可以找到服务端程序的。协议栈根据`SYN报文`以及分组中的端口和IP，创建出一个`socket`连接，该连接可以由`<src-IP, src-Port, dst-IP, dst-Port>`唯一确定。

> 以服务端的角度看，服务端程序绑定端口启动起来，外部有一个客户端通过TCP连接上来，此时会存在两个连接，一个是用来接收建连的连接，另一个是客户端和服务端之间的连接。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;服务端连接一旦创建，就需要分配接收与发送缓存，同时会将连接信息注册到协议栈，这样协议栈可以通过`<src-IP, src-Port, dst-IP, dst-Port>`来定位到对应的TCP连接，也能从该连接找到服务端程序。服务端的初始化工作完成后，就需要将服务端生成的序号以及针对`SYN报文`的响应进行回复，也就是发出`SYNACK报文`，这个报文同时包含了SYN和ACK，简称为`SYNACK报文`。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`SYNACK报文`中SYN相关的部分就是服务端随机生成的`sequence`，以及和先前客户端发送的`SYN报文`中相类似的`rwnd`以及MSS等信息，而ACK相关的部分就是针对`SYN报文`中`sequence`的回复。假设`SYN.sequence=23`，那`SYNACK.ack`就会是`24`，表示`24`以前的数据已经收到，目前需要收到从`24`开始的数据。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`SYNACK报文`发回客户端后，客户端协议栈程序能够根据`<src-IP, src-Port, dst-IP, dst-Port>`确定是哪个TCP连接，以及定位到哪一个进程。根据`SYNACK`中`src-Port`以及分组中的`src-IP`，将对应的数据更新到协议栈，同时协议栈针对`SYNACK报文`中的`SYN`部分进行响应回复，发出`ACK报文`。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;客户端发送的`ACK报文`主要包括了对`SYNACK.sequence`的回复，如果服务端发送的`SYNACK.sequence=10`, 则`ACK.ack=11`，这和之前的服务端行为是类似的。需要注意两点：第一，ACK回复的是SYN或者说SYNACK的SYN部分，不会存在针对ACK的`ACK报文`；第二，上述建连过程都是操作系统内核中的协议栈进程来完成的，对用户进程是透明的，或者说无感的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过“**三次握手**”，TCP连接就在双方的共识中建立起来，客户端和服务端如何知晓该发送`SYN`或者`SYNACK报文`呢？答案是状态，根据各自的连接状态来期望得到的报文，以及得到报文后所做出何种动作。建连状态的变迁如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/tcp-connect-state.jpg" width="90%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，`CLOSE`、`LISTEN`、`SYN-SENT`、`SYN-RCVD`和`ESTABLISHED`这`5`个状态构成了TCP连接两端的状态全集，一旦连接建立完成，一切顺利的情况下两端状态最终都处于`ESTABLISHED`。客户端和服务端双方动作不一样，服务端有监听端口和接收连接建立请求的动作，所以状态也有所不同，客户端具有的状态是`CLOSE`、`SYN-SENT`和`ESTABLISHED`，服务端是`CLOSE`、`LISTEN`、`SYN-RCVD`和`ESTABLISHED`。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从服务端开始，创建了TCP连接，绑定到某个网卡接口（IP）和端口，状态从`CLOSE`变为`LISTEN`，代表该监听连接正常工作，可以用来接收其他`Endpoint`的`建连请求。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;客户端开启“**三次握手**”的第一步，发出`SYN报文`，客户端连接状态由`CLOSE`变为`SYN-SENT`。服务端监听连接收到`SYN报文`，复制并初始化一个连接，该连接状态为`SYN-RCVD`，该连接和客户端连接是对应的，然后发出`SYNACK报文`。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;客户端处于`SYN-SENT`状态，收到`SYNACK报文`后，更新本地连接信息，同时将连接状态变更为`ESTABLISHED`，发出针对`SYNACK`的确认报文，即`ACK报文`。服务端收到`ACK报文`后，状态从`SYN-RCVD`变为`ESTABLISHED`，两端TCP连接建立完成。

## 传输数据

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;两端连接建立完成后，就进入数据传输阶段，该阶段的执行过程与RDT协议类似，采用发送与确认的方式来确保数据可靠传输。以两台主机之间`echo协议`为例，TCP协议传输过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/tcp-echo-protocol.jpg" width="60%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，`主机A`向`主机B`发送字符c，按照`echo协议`，`主机B`会回复相同的字符给`主机A`。`主机A`发送的报文序号为`42`，而确认`ack`是`79`，这代表当前报文的字节序号是`42`，而已经收到了`78`个字节，接下来期望从第`79`个字节收。`主机B`回复`主机A`，该报文不仅有对`42`号的确认，也就是确认`ack`为`43`，代表已经收到`42`个字节的数据，同时序号是`79`，也是`主机A`所期望的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;用户在`主机A`上输入了字符`c`，主机B返回了字符`c`，最后`主机A`针对`主机B`的回复做了确认，表示已经成功收到了`79`个字节。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;报文序号并不是根据报文的数量来进行自增的，TCP传输的标的是字节，因此是按照字节序号来定义，这点和RDT有些不同，不过本质没有区别。可以把TCP的工作理解为将一根香肠从一台主机搬到另一台主机，这根香肠无限长，TCP就根据MSS来切，它可以切成N段，然后一段段的传递过去。每一段都有长度，可以使用毫米计数，这样第N段香肠的序号就可以是`Length(N - 1) + 1`，也就是前`N - 1`段长度的毫米数再加1，这样序号可以保证自增，同时序号也可以用来作为传输香肠长度的参考，比如：传输的香肠段序号是`1234`，不用关心它到底是第几段，而是能知道已经有`1233`毫米的香肠被传送到对端了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;报文发送离不开发送缓冲区，这点与RDT也差不多，过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/tcp-swnd.jpg" width="90%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，应用需要通过网络发送的数据不断的追加到缓冲区中，而将数据发送到网络后，需要有确认才能继续发送，为了解决可靠性和效率这两个矛盾的问题，使用发送窗口`swnd`来进行调和。TCP超时任务会与发送窗口的`baseseq`相关联，定时关注`swnd`中发送较早的数据是否收到响应，而对端传回的响应会推动`baseseq`向前移动，使得更多的数据能够从缓冲区中发往网络。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;发往网络不是同步过程，只是操作系统协议栈将报文最终转换成为数据帧，由网卡驱动将二进制的帧变为电信号，并通过网卡的端口将信号已高低电平的形式“表述”一遍即可，至于连接线材那边的事情，当前主机一概不管。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用滑动窗口的方式来管理数据发送和ACK响应，目的就是发送报文后不必等待`ack`响应而是继续发送下一个报文，这样就可以充分跑满网络，有效提升利用率。因此TCP协议也有类似RDT协议的`rwnd`属性，用来告诉发送方，自己还能收多少数据，也就是你还能不看`ack`无脑的发多少数据。与RDT协议类似，TCP依靠序号解决发送的顺序问题，依靠ACK解决接收可靠性问题，依靠缓冲区解决发送和消费的效率问题，再通过滑动窗口解决发送和响应能够异步高效处理的问题。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;因为有了滑动窗口的存在，TCP响应除了完成ACK响应的工作还需要支持`rwnd`大小带回（给发送方的）工作。这两个响应分开发送是没有问题的，但是TCP协议能同时传输`ack`和`rwnd`，所以会合并到一起。如果频繁的发送响应，会导致网络效率变低，所以TCP会有一定的积蓄效应，就是将响应累积一下再发，比如：两个响应报文，`ack`分别为`100`和`300`，第一个响应报文一创建就发送不如等几秒，第二个响应报文创建后，直接发`ack`为`300`的一个报文更高效。这种累积效应不仅在接收端生效，发送端也是一样，需要发送的数据放入发送缓冲区后，尽可能将报文接近MSS后再发送，充分的利用网络。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述策略是专门的算法，叫[Nagle](https://baike.sogou.com/v10500918.htm)，但对于时间敏感型应用就无法接受了，所以会通过配置`SO_TCPNODELAY`属性来禁止它，也就是告知协议栈，对于当前连接，当数据进入发送缓冲区后，立刻发送。这和JVM的GC策略很像，面向吞吐还是响应优先，二者是有矛盾的，需要具体情况具体分析。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;报文抵达对端，协议栈收到数据，检查完整性，并将多个连续报文中的数据连接起来，还原出来的数据会复制到应用进程相应的内存地址中，再触发中断告知应用进程可以读取数据。当应用进程消费相关数据后，协议栈就会找合适的时间发送响应，响应包含了`ack`和`rwnd`。

## 断开连接

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;TCP连接建立完成后就可以进行数据传输，当通信双方目标已经达成，就可以选择断开连接，参与通信的两端都可以发起断开连接的操作。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;假设服务端发起断开连接，这需要使用到TCP报文控制位中的`FIN`，表示连接完结，两端交互的流程如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/tcp-disconnect-seq.jpg" width="90%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，通过“**四次挥手**”两端完成TCP连接的拆除，两端各自发出了`FIN报文`，同时也对远端的`FIN报文`做出了`ACK响应`。由于TCP连接只存在于本地，所以TCP连接在发起断开后不会立刻删除，如果服务端发出`FIN报文`，客户端没有响应，服务端会进行重发，这样最大限度的让双方对于连接断开能够达成共识。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述过程都是由操作系统协议栈负责的，对于应用进程而言是透明的，假设通信双方其中一方应用进程崩溃，上述断开连接的动作还是可以由协议栈程序来完成的，但如果是系统掉电这种突发情况，对端就不会认为连接已经断开，只能经历若干次重传无果后强制断开。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;和建连一样，断开连接也需要进行状态控制，断连状态的变迁如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/tcp-disconnect-state.jpg" width="90%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，由客户端发起断开连接操作，此时客户端TCP连接的状态是`ESTABLISHED`，客户端进程调用`close`方法准备断开连接。客户端的`FIN报文`发送后，客户端TCP连接状态变为`FIN_WAIT_1`，此时如果客户端进程再调用`socket`的写方法将会报错。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;按照断开连接的契约，服务端会回复客户端的`FIN报文`，也就是发送`ACK报文`，客户端收到服务端发来的`ACK报文`后，状态变更为`FIN_WAIT_2`，该状态就开始关注服务端何时发出`FIN报文`了，其实就是等待对端调用`close`方法来关闭连接。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;服务端的`FIN报文`到达客户端后，客户端会针对该`FIN报文`做`ACK`回复，同时状态变为`TIME_WAIT`，由于收到了服务端的`FIN报文`，所以理论上没有数据再会由该连接到达客户端，客户端会等待一段时间，将连接状态变为`CLOSE`，随后拆除。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;以客户端视角看完后，接着以服务端视角来看看。服务端收到客户端发来的`FIN报文`后，连接状态变为`CLOSE_WAIT`，服务端回复`ACK`后，向客户端发送的数据已经完毕，就调用`close`方法，向客户端发出`FIN报文`。`FIN报文`发出后，服务端连接状态变为`LAST_ACK`，当客户端的`ACK报文`抵达服务端后，由于客户端之前已经不会再传输数据过来，所以直接将连接状态变为`CLOSE`，随之拆除当前连接，回收其缓冲区等分配的资源。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从TCP连接的建立和断开来看，除了传递请求和响应数据，就单独为了维护两端连接状态就需要`7`次往复，除去两端缓存资源创建的开销不论，对于系统之间存在频繁的远程通信场景而言，选择短连接通信是非常不明智的。

## 流量控制

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;TCP为连接两端提供了流量控制机制，实现的方式是基于`rwnd`。和RDT协议类似，在TCP报文中存在`rwnd`属性，它用来告诉对端自己的缓存还剩多少，如果可以发过来的数据尽量不要超过它。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;网络传输的双方，只要一方的接收缓存快满了，原因可能是应用程序处理的比较慢，也可能是系统负载非常高，这样协议栈回复给对端报文中的rwnd值就小，这就可以压制对端发送数据的速率，从而间接的控制了流量。

## 拥塞控制

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;TCP工作在分组交换网络上，通信的两端各自在本地虚拟了一个连接，但传输的数据要真实的穿过路径中的若干节点。每个节点都像一个消息处理器，接收外部分组，根据IP进行分组路由，这种接收、存储和转发的工作在每个分组交换节点上时刻进行着。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果设备使用TCP快速的向网络中发送数据，虽然目的是单纯的，地址也是正确的，但由于分组数据包太多，导致网络中某些节点超载，就会使得通过超载节点的所有数据包都发生延迟，影响的设备就不止一个了。这就要求TCP传输时，需要关注链路中不同节点的工作状态，不能太快，也不能太慢的发送数据，但这对于参与通信的两端来说，要求太高了。既然无法观测路径中的节点状态，那就退而求其次，通过观察网络，也就是对端回复数据包的情况，猜测当前网络的状态，根据间接观察到的结果，来决定发送数据的速率。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;TCP观测哪些结果呢？一般有两个，即`超时`和`3次连续相同冗余确认`。对于`超时`而言，如果发送的报文在一段时间内没有被确认，这就代表路径不太畅通。`连续收到3次冗余确认`是指，发送方发送报文后，对端回复的多个报文中`ack`号相同，这就代表发送的若干报文中存在丢失，而只有出现缺失报文时，对端才会回复需要从某个序号开始的报文。从拥塞程度上看，`超时`被认为是严重的拥塞，而`3次连续相同冗余确认`被认为是较轻的拥塞。

> 3次的原因是置信度较高且经济。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;随着对端的响应到达，本地就能观测出拥塞情况，TCP协议通过引入拥塞窗口（Congestion Window，简称为`cwnd`）来干预发送速率。一般来说`cwnd`会从1开始，逐步增大，观测到拥塞后，再减小，一旦发现恢复后，再次增大，这种不断挑战网络传输底线的方式就构成了拥塞控制的解决方案。因此，发送窗口就是由接收窗口和拥塞窗口来决定的，如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/tcp-swnd-cal.jpg" width="90%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，对于`cwnd`的增加或减少，可以影响到`swnd`，也就是影响网络的传输效率，而TCP的目的就是在保证网络（或者说大家）可用的情况下，尽可能快的传输数据，提升网络利用率。因此，会有很多拥塞控制算法来优化这个过程，但基本思路就是在没有触发拥塞的情况下，逐步增加向网络中发送的数据量，如果一旦观察到拥塞发生，就降低发送速率。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;cwnd常见的变化过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/tcp-cwnd-sample.jpg" width="90%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，在初期`cwnd`会开启`慢启动阶段`，虽然叫慢启动，但是`cwnd`的扩张其实非常快，因为它是指数级别的，只是它从`0`或者`1`开始的。如果发现超时，`cwnd`会跌到`1`，基本处于跌停状态，然后通过慢启动恢复到原来最高点的`1/2`，随后线性增长，而保守的线性增长阶段称为`拥塞避免阶段`。如果发现`3次连续冗余ACK`，代表出现了较轻拥塞，`cwnd`会跌到当前的`1/2`，而不是跌到1，随后开启`拥塞避免阶段`。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到对于超时，TCP会使用慢启动配合拥塞避免的方式来逐步恢复流量，而对于轻度拥塞，会直接使用拥塞避免来处理。这样复杂的处理策略目的不是为了限制速率，而是为了提升传输效率，保持两端尽可能的接近拥塞发生的临界点，在网络能够承载的前提下，尽快的完成传输。不计其数的分组交换设备组成的互联网，在TCP的支持下，仿佛一张巨大的网，在有节奏的上下律动着。
