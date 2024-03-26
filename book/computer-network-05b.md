# 《计算机网络》第5章-数据链路层（b.以太网）

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如今是移动互联网时代，生活中用手机和Pad上网看视频，工作中用笔记本电脑连`Wi-Fi`办公，感觉有线网已经很少见到。人们对有线网的记忆仿佛就停留在无线路由器背后那根线一样，已经不那么重要了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;其实无线网络只是终端接入形式的转变，有线网络依旧是互联网的基础，从带宽、延迟和效率来说，有线网络都会远远强于无线网络，我们短视频程序背后所用的服务器，它们都是由有线网络连接起来的，没有这些设备之间的有线连接，是无法向消费者提供稳定可靠的网络服务。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;既然有线网络这么重要，那该了解它哪些有用的信息呢？有线网络涉及的技术种类很多，比如：光纤、同轴电缆以及双绞线，在不同的介质上使用着不同的有线网络技术，而它们之间的差别也非常巨大。虽然种类很多，但使用最广泛的就是以太网技术，无论是电竞主机网卡上插的网线，还是数据中心里交换机上的线缆，它们都使用了一样的技术，即以太网技术。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;以太网技术是一种具体的网络通信技术，它涵盖了TCP/IP五层结构中最下面两层，也就是数据链路层和物理层，这也是具体网络技术的特点--提供软件驱动和硬件，实现主机间的通信。本文主要从数据链路层上介绍以太网技术，主要是软件层面的协议设计。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在正式开始介绍前，还是需要声明数据链路层的职责：面向物理媒介，完成数据到帧以及帧到数据的转换与传输，其详细内容可以[参考这里](https://weipeng2k.github.io/hot-wind/book/computer-network-05a.html)。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;以太网协议设计的比较简单，它包括：前导码（SFD）、以太网头部和帧校验序列（FCS）构成。上述三者的关系如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/dl-ethernet-protocol.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，前导码占用了`8`个字节，以太网头部占用了`14`个字节，FCS占用了`4`个字节。以太网协议的特点在于加入了前导码，从字节数据来看，它是有规律的从`1`到`0`的位变换，通过连续`7`个字节，至少`28`次周期变换，目的就是告知对方电信号变化的频率，对端通过学习前导码中的变换频率，能够掌握以何种频率去度量后续收到的帧。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;前导码的字节内容如下图所示。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/dl-ethernet-pre.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，当前导码最后一个字节，也就是SDF中出现了（紫色所示）连续的两个`1`，这代表接下来开始接收帧的本体。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从概念上理解一下前导码的作用，好比`A`唱一首歌给`B`，唱歌的速度有快慢，为了能让`B`更好的了解到`A`有没有开启2倍速唱歌，好的做法是让`A`先唱一段`B`知道正常速率的歌，这样`B`就对`A`接下来的歌有所准备了。一样的道理，当对端网卡开始接收到信号时，它会假设变换的信号要传递前导码中约定的内容，无论是快速的信号变换，还是慢速的信号变换，通过对已知内容的监听，对端网卡就能确定信号的度量分割窗口，然后使用该窗口去划分接下来帧的本体，直到FCS接收完成。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到前导码为真实网络通信作出的努力，没有它，双方无法协调信号之间的语速，正确通信更是无从谈起了。常见的网络层（及其以上）协议，是见不到前导码这样的设计，原因就是数据链路层协议需要根据自身硬件特点来定义协议，既要考虑软件语义，又要考虑硬件实现，二者缺一不可。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;以太网头部主要由三部分构成，它和数据负载以及FCS的格式如下图所示。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/dl-ethernet-header.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，以太网协议是一个定长头，变长体的通信协议。这里需要传输的通信内容，也就是数据负载长度在`46`到`1500`字节之间。之前常提到的MTU大小，指的就是它，以太网的MTU是`1500`字节。这里有点奇怪，既然数据负载长度是变化的，那为什么以太网协议没有字段标识当前帧包含的数据负载大小呢？讲道理是应该有专门字段做长度标识才会显得科学些，在`IEEE 802.3`规范中确实有帧长度的字段来描述数据负载大小，但实际使用的DIX规范中没有这个字段，它是靠类型以及FCS之间是数据负载这一默认约定来实现的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;类型字段是对数据负载类型的描述，比如：`0800`是IP协议，`86DD`是IPv6协议，以太网驱动会根据具体的类型值，将数据转交给对应的协议栈进行处理。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;数据发送方网卡的MAC模块将数据包装成帧，填充好帧的头部，包括：来源和目标MAC地址，并且确定好处理类型，在帧的前部增加前导码，尾部加上根据数据计算得来的FCS，这样一个帧就组装好了，随后便交给MAU模块进行信号的调制与发送。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;数据接收方网卡的MAU模块收到信号，它知道对方一定会按照约定的前导码内容发送信号，因此就跟着接收到的信号进行默念，通过多次默念，对传递过来的信号有了一定的认识，当读到`11`时，就代表要开始接收正式内容了。信号解调成帧后放在接收方网卡的缓冲区中，其MAC模块会检查FCS，看是否有差错，如果没有再核对一下目标MAC地址是不是自己，如果一切正常，就发起中断，通知操作系统来取货了，否则就丢掉这个帧。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用wireshark，随意抓取一个分组，可以在Ethernet一栏中依据以太网协议查看数据内容，如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/dl-ethernet-wireshark.jpg" width="90%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，序号1和2标识了目标和来源MAC地址，序号3标识了类型，它表明数据负载是IP协议，可以使用IP协议对数据负载进行处理。
