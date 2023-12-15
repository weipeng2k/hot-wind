# **Java**Network's ARP与pcap4j

数据链路层是网络传输的基础，在常见的TCP/IP五层（也有四层的说法）结构中，数据链路层处于物理层的上方，网络层的下方，自顶向下的倒数第二层。本文会介绍数据链路层的作用，以及在网络应用在工作中，网络层同数据链路层完成的一些交互，会涉及到ARP（地址解析协议）以及路由表和路由计算。在正式开始前，先说一个咒语“路由靠网络，传输靠链路”，如果需要具像化一些，可以改为“路由靠IP，传输靠以太”。

## 网络拓扑

实验环境的网络环境非常典型，笔记本通过wlan连接到路由器（小米），而路由器的WAN口连接到光猫路由的LAN口上，如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-network/arp-and-pcap4j-local-network-arch.png" width="70%">
</center>

可以看到从笔记本发起的一次对外部的HTTP请求，要经过笔记本网卡，经过路由器，在透过光猫，到达电信局局端接入，再通过隧道抵达ISP网络，而多个ISP通过分组路由，最终抵达服务器。同样，服务器的响应在网络传输层面和请求链路没有任何关系，服务器会将生成的文本信息，根据之前请求IP坐标，反向在发送回去，再经过一路坎坷，回到笔记本。

使用Java可以很轻松的发起HTTP请求，例如：使用Feign等客户端，在这里我们基于Java提供的Socket，通过编写应用层（HTTP协议）的语法来发起请求，并输出响应，代码如下：

```java
@Test
public void http() throws Exception {
    InetAddress inetAddress = InetAddress.getByName("www.baidu.com");
    SocketAddress socketAddress = new InetSocketAddress(inetAddress, 80);
    BufferedReader bufferedReader;
    try (Socket socket = new Socket()) {
        // imply bind & connect
        socket.connect(socketAddress, 3000);

        PrintWriter out = new PrintWriter(socket.getOutputStream());
        out.println("GET / HTTP/1.0\r\n");
        out.println("HOST: www.baidu.com\r\n");
        out.println("Accept-Encoding:gzip,deflate\r\n");
        out.println("Accept: */*\r\n");
        out.println("\r\n");
        out.flush();

        bufferedReader = new BufferedReader(new InputStreamReader(socket.getInputStream()));

        String line;
        while ((line = bufferedReader.readLine()) != null) {
            System.out.println(line);
        }
    }
}
```

运行测试用例，输出（部分）内容如下：

```sh
HTTP/1.0 200 OK
Accept-Ranges: bytes
Cache-Control: no-cache
Content-Length: 9508
Content-Type: text/html
Date: Tue, 12 Dec 2023 07:11:09 GMT
P3p: CP=" OTI DSP COR IVA OUR IND COM "
P3p: CP=" OTI DSP COR IVA OUR IND COM "
Pragma: no-cache
Server: BWS/1.1
```

输出内容过长，只是截取了部分HTTP响应头，正文部分都省略了。上述测试用例运行时，会建立笔记本到www.baidu.com主机的连接，通过连接向对端发送HTTP消息。通过使用路由器提供的DNS服务，其实一开始就知道了www.baidu.com的IP，但是再将HTTP消息发送到路由器之前，发生了什么呢？

首先当然是建立连接，其次准备好的HTTP消息会被协议栈根据MSS进行内容分割，这当然是传输层的工作，最后封装好的Segment会被放置到IP分组中，这个IP分组会写上发送方笔记本的IP，以及接收方，也就是DNS服务查询到的那个IP，封装好的IP分组就进入缓冲区，等待发送窗口的到来。

## Router机制

笔记本连接在路由器上，路由器也连接了多个设备，当然它们也都分配了子网IP。那为什么从笔记本发起对www.baidu.com的访问，会到路由器，而根据其他设备的主机名进行访问，会到内网设备呢？其实本质上讲，笔记本也是路由器，只要支持IP规范的设备，理论上都会是一台路由器。

基于IP的分组交换网络，状态体现在两点：第一，是在分组信息上，它描述了来源和目标等信息，第二，是路由器的路由规则，它定义了当前路由设备处理分组的策略。每一个IP分组信息都有自己的状态，每一台路由设备都有自己的路由策略。之前不是提到笔记本也是路由器么？那么它的路由策略是什么样的？在访问www.baidu.com的过程中起了什么作用呢？

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-network/arp-and-pcap4j-netstat-router.jpg" width="70%">
</center>

通过在控制台输入`netstat -rln`，可以输出当前系统的路由策略，也就是路由表。输出的内容挺多，我们只需要关注其中几列：destination、gateway和netif，其中netif应该是net interface，也就是网络接口的意思，代表网卡。

当需要路由处理一个分组时，首先需要进行destination匹配，匹配的规则会越精确越好，然后根据IP分组中目标IP的子网进行向上匹配，如果都没有命中，那么就会选择destination为default的这一行记录。一般来说，访问外网，都会命中到这一行。

分组会通过netif发往gateway指定的IP，这里就是通过en0网卡，发往192.168.31.1，后者就是路由器的IP。可以想象，在运行测试用例时，访问www.baidu.com的IP分组在发送前，会首先依据路由表中的路由信息找到目标gateway，然后使用netif进行发送。

为什么要找到en0网卡，因为操作系统发送网络数据时，内核会调用网卡驱动，将数据写入到网卡设备的内存，也就是发送缓冲区中，接下来网卡进行成帧以及调制/解调工作就是网卡自己的事情了。这里和本文所要描述的内容没有多少关系，只是简单的说明一下。

## 根据IP找MAC

网络接口确定了，IP分组也构建好了，准备要发网络包了，上述动作在Java中没有编程API，或者说进入到操作系统内核后，Java管不了了。虽然Java管不了，但是起点还是在Java，Java over OS，IP over ethernet。IP协议只是在操作协议栈中的逻辑概念，最终进行传递的时候还是需要依赖数据链路层，或者说承载网。

瑟夫和卡恩设计TCP/IP时，其目的就是为了连接不同的承载网络，比如：夏威夷的ALOHA网、美国军方的ARPA网或者施乐公司的以太网等，这些网络实际都是自底向上建设的。它们会考虑物理连接，以及在这些物理连接上如何传输信号，信号的制式以及语法都会定义和实现。不同的网络无法进行连接，因为它们上面传输的协议格式都不统一，如果需要做到不同的网络能够互联互通，该怎么办呢？

大概率你会想到：抽取一个中间层，这个中间层里定义了公共协议（含数据格式）以及行为（接口），然后不同的网络适配它就行了。说的没错，软件工程中的依赖反转原则就是解决这个问题的，而瑟夫和卡恩就设计了这个中间层，也就是TCP/IP协议，通用的IP协议有了，应用层就可以基于它来编程了，这也就是所谓的everything over IP。

光包装也不能解决所有问题，毕竟还是要底层实现的，就像spring再厉害，还是需要tomcat来提供HTTP服务。逻辑上可以理解为链路层适配IP的SPI，完成到IP协议的接入，但实现上适配逻辑中还是要根据具体网络实现来办事。网络实现或者说承载网能不能脱离IP单独使用呢？当然可以，但是反过来，网络就无法工作。以太网（Ethernet）是现在使用最广泛的数据链路层网络，看到具备RJ-45接口的网卡以及双绞线都是它的产物。

以太网依靠MAC地址来进行通信，可以理解为每一个支持以太网传输的设备都会拥有全球唯一个MAC地址，这个MAC地址是生产设备时烧录进去的，它有48位，讲道理是非常大的，在控制台输入：ifconfig，一般就可以看到它，以下是命令输出（的部分）内容：

weipeng2k@weipengdeNewMBP ~ % ifconfig
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
    options=6460<TSO4,TSO6,CHANNEL_IO,PARTIAL_CSUM,ZEROINVERT_CSUM>
    ether f0:18:98:1f:91:e4
    inet6 fe80::c9e:ec76:dab0:24f4%en0 prefixlen 64 secured scopeid 0x6 
    inet 192.168.31.137 netmask 0xffffff00 broadcast 192.168.31.255
    nd6 options=201<PERFORMNUD,DAD>
    media: autoselect
    status: active

比如：f0:18:98:1f:91:e4就是笔记本en0网卡的MAC地址，一般MAC地址还具备一些隐私性的，因为它48位的部分会和当前设备的厂商相关，比如：Apple，因此是可以通过MAC地址分析出设备的大概种类。

IP分组构建好了，出口的网卡en0选择好了，目标gateway的IP：192.168.31.1也准备好了，到了最终发送之前，还是要乖乖的切换到以太网上，说以太网才能听懂的话。这就需要将IP换成MAC地址的服务，也就是ARP（address resolvtion protocol）的支持。ARP协议构建在数据链路层，也就是以太网之上，所以从层级关系上讲，它和网络层是平级的。

在以太网中传输，需要将IP分组放置到以太网能看懂的帧里，以太网支持点对点传输，来源就是本机网卡en0的MAC地址，这个在系统加载的时候就会初始化，不需要额外获取，而网关192.168.31.1的MAC地址就需要ARP的帮助了。ARP工作的方式大致分为三步：第一步，需要查询某个IP对应MAC地址的节点，使用以太网广播的方式，吼一声谁有这个IP；第二步，有指定IP的设备会点对点的告知第一步中发起查询的节点，我有这个IP；第三步，发起查询的节点会将IP与MAC地址的对应关系缓存起来，加速未来的查询。

通过wireshark，可以进行网络抓包，看一下上述过程，如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-network/arp-and-pcap4j-wireshark-arq-req.png" width="70%">
</center>

如上图所示，按照序号进行介绍，先看第一个，wireshark的包过滤功能。可以通过输入表达式来过滤需要关注的包，如果你使用wireshark进行抓包，会发现网络包非常多，虽然只是抓自己网卡的包，但是整个（局域）网络中充斥着不同协议的包，时而点对点传输，时而进行广播，甚是嘈杂。eth.type == 0x0806，代表以太网帧中类型是ARP协议，当然IP协议也是有类型的，只是不同的数值而已，网络数据最终从链路层出来，交给操作系统协议栈，内核按照不同的类型来进行策略处理就行了。如果只是限定类型为ARP也会很多，所以通过eth.src来指定来源可以是笔记本en0网卡或者路由器。

> 对应的MAC地址需要你根据自己的实际情况来看，它们肯定是不同的。

顺便说一句，如果想过滤IP协议相关的，就可以使用ip.dst_host（目标IP）等不同的key来进行过滤，输入时wireshark会有提示，非常的贴心。

通过表达式过滤出包之后，接下来看第二个，ARP执行过程。前文已经讲述过ARP的工作步骤，这里可以更加形象的看到网络包的关系，第381号包，笔记本进行以太网广播，问询谁拥有192.168.31.1这个IP，紧接着第382号包，也就是拥有对应IP的这个设备会点对点回复它具备这个IP，并且自己的MAC地址是什么。

## ARP协议分析

从ARP工作的过程来看，一次广播，一次点对点，还是很简洁的。由于ARP是构建在以太网上的协议，所以必须按照以太网的规范来，梅特卡夫和博格斯设计的以太网需要在通信时指定源MAC地址和目标MAC地址，对于发起方来说，源MAC地址是很容易获取到的，但是目标MAC地址不一定，比如广播的时候，MAC地址该设置成什么呢？看一下第381号包的内容就明白了，如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-network/arp-and-pcap4j-wireshark-arp-req-detail.png" width="70%">
</center>

如上图所示，可以看到ARP请求报文的详细内容，按照序号进行介绍。第一个，以太网的目标MAC地址。在进行ARP请求时，这是一个广播调用，它会将包发给局域网中所有支持以太网协议的设备，由于这是一个未知的设备集合，所以它们有一个专属的MAC地址，即：ff:ff:ff:ff:ff:ff，也就是48位全为1的MAC地址，向它发送帧，即向所有设备发送帧。ARP协议，选择使用以太网广播的形式，向局域网中所有的设备发起问询。

第二个，ARP问询的内容。ARP协议设计的比较短小，Opcode代表当前报文是请求还是响应，而发送方和目标方的IP和MAC地址紧随其后。在进行ARP请求时，发送方的IP和MAC地址是已经具备的，但目标方只有IP地址是确定的，其MAC地址并不知晓，因此采用全为0的00:00:00:00:00:00代替。

ARP请求报文准备完成，封装到以太网的帧中，广播给所有设备。可以猜测，收到对应帧的设备进行解码，然后根据帧类型调用操作系统协议栈进行处理，而协议栈进行策略处理时，会交给ARP协议处理器完成处理。ARP处理过程也会比较简单，首先看目标IP是不是本机（某块网卡的）IP，如果不是就忽略，如果是就回复请求报文中对应发送方自己的MAC地址。

第382号包为ARP响应报文，如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-network/arp-and-pcap4j-wireshark-arp-resp-detail.png" width="70%">
</center>

如上图所示，依旧按照序号进行介绍。第一个，以太网发送的目标、来源以及类型。该帧发自路由器，目标是笔记本en0网卡，类型是ARP，这代表着拥有192.168.31.1这个IP的设备，它应答了。第二个，ARP响应报文。可以看到Opcode代表当前报文是响应，由于是点对点通信，发送方和目标方的IP以及MAC地址都完备。

笔记本通过en0网卡收到ARP响应报文后，会更新内存中IP与MAC地址的对应关系，当需要进行IP与MAC地址转换时，就可以从内存中获取，而不用发起网络调用了。如果缓存在本地，假设IP变动了怎么办？其实任何缓存都是有过期时间的，当这个对应关系在本地存在了几十分钟后，就会自动被删除，若要获取需要再次发起ARP请求。

## Java与ARP

ARP完成了IP到MAC地址的转换，有效的连接了网络层和数据链路层，是计算机网络中非常重要的组成部分。那么Java和ARP有什么关系呢？或者说使用Java能发送ARP请求和处理ARP响应吗？很遗憾，Java构建在传输层之上，使用面向传输层的socket进行编程，网络层是Java无法触及到的。当然，凡事没有绝对，使用JNI的帮助，也会有一些Java类库支持ARP协议处理，pcap4j就是其中之一。

访问其主页，可以选择安装pcap4j，在maven项目中依赖如下坐标：

```xml
<dependency>
    <groupId>org.pcap4j</groupId>
    <artifactId>pcap4j-core</artifactId>
    <version>1.8.2</version>
</dependency>
<dependency>
    <groupId>org.pcap4j</groupId>
    <artifactId>pcap4j-packetfactory-static</artifactId>
    <version>1.8.2</version>
</dependency>
```

然后新建测试用例ARPTest，代码如下：

```java
import org.junit.Test;
import org.pcap4j.core.BpfProgram;
import org.pcap4j.core.PacketListener;
import org.pcap4j.core.PcapHandle;
import org.pcap4j.core.PcapNetworkInterface;
import org.pcap4j.core.Pcaps;
import org.pcap4j.packet.ArpPacket;
import org.pcap4j.packet.EthernetPacket;
import org.pcap4j.packet.Packet;
import org.pcap4j.packet.namednumber.ArpHardwareType;
import org.pcap4j.packet.namednumber.ArpOperation;
import org.pcap4j.packet.namednumber.EtherType;
import org.pcap4j.util.ByteArrays;
import org.pcap4j.util.MacAddress;

import java.net.InetAddress;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class ARPTest {

    private static final MacAddress SRC_MAC_ADDR = MacAddress.getByName("f0:18:98:1f:91:e4");

    private static MacAddress resolvedAddr;

    @Test
    public void arpRequest() throws Exception {
        // 本机IP
        String strSrcIpAddress = "192.168.31.139";
        // 目标IP，带查询MAC的IP
        String strDstIpAddress = "192.168.31.58";

        InetAddress addr = InetAddress.getByName(strSrcIpAddress);
        // 根据IP获取到对应的Pcap网络接口，可以理解获取到了en0网卡
        PcapNetworkInterface nif = Pcaps.getDevByAddress(addr);

        // 监听网卡的流入数据，每个包监听的长度为65536 bytes
        PcapHandle handle = nif.openLive(65536, PcapNetworkInterface.PromiscuousMode.PROMISCUOUS, 10);
        // 向网卡发送数据的入口，使用它来发送ARP请求报文
        PcapHandle sendHandle = nif.openLive(65536, PcapNetworkInterface.PromiscuousMode.PROMISCUOUS, 10);
        // 构建监听网卡流量运行任务的线程池
        ExecutorService pool = Executors.newSingleThreadExecutor();

        try {
            // 设置监听流量的规则：监听ARP包，IP地址以及目标MAC地址是本机的包
            handle.setFilter(
                    "arp and src host "
                            + strDstIpAddress
                            + " and dst host "
                            + strSrcIpAddress
                            + " and ether dst "
                            + Pcaps.toBpfString(SRC_MAC_ADDR),
                    BpfProgram.BpfCompileMode.OPTIMIZE);
            // 对于ARP协议的包进行处理，且仅处理ARP响应报文，记录并打印
            Task t = new Task(handle, packet -> {
                if (packet.contains(ArpPacket.class)) {
                    ArpPacket arp = packet.get(ArpPacket.class);
                    if (arp.getHeader().getOperation().equals(ArpOperation.REPLY)) {
                        ARPTest.resolvedAddr = arp.getHeader().getSrcHardwareAddr();
                        System.err.println(packet);
                    }
                }
            });
            pool.execute(t);

            // 构建ARP报文，可以看到ARP被设计用在多种链路层上，而目标MAC地址设置为全0
            ArpPacket.Builder arpBuilder = new ArpPacket.Builder();
            arpBuilder
                    .hardwareType(ArpHardwareType.ETHERNET)
                    .protocolType(EtherType.IPV4)
                    .hardwareAddrLength((byte) MacAddress.SIZE_IN_BYTES)
                    .protocolAddrLength((byte) ByteArrays.INET4_ADDRESS_SIZE_IN_BYTES)
                    .operation(ArpOperation.REQUEST)
                    .srcHardwareAddr(SRC_MAC_ADDR)
                    .srcProtocolAddr(InetAddress.getByName(strSrcIpAddress))
                    .dstHardwareAddr(MacAddress.getByAddress(new byte[]{0, 0, 0, 0, 0, 0}))
                    .dstProtocolAddr(InetAddress.getByName(strDstIpAddress));
            // 将ARP报文放置到以太网的分组中，目标MAC地址为：ff:ff:ff:ff:ff:ff
            EthernetPacket.Builder etherBuilder = new EthernetPacket.Builder();
            etherBuilder
                    .dstAddr(MacAddress.ETHER_BROADCAST_ADDRESS)
                    .srcAddr(SRC_MAC_ADDR)
                    .type(EtherType.ARP)
                    .payloadBuilder(arpBuilder)
                    .paddingAtBuild(true);

            Packet p = etherBuilder.build();
            System.out.println(p);
            // 发送分组
            sendHandle.sendPacket(p);

            TimeUnit.SECONDS.sleep(2);
        } finally {
            if (handle.isOpen()) {
                handle.close();
            }
            if (sendHandle.isOpen()) {
                sendHandle.close();
            }
            if (!pool.isShutdown()) {
                pool.shutdown();
            }

            System.out.println(strDstIpAddress + " was resolved to " + resolvedAddr);
        }
    }

    private record Task(PcapHandle handle, PacketListener listener) implements Runnable {

        @Override
        public void run() {
            try {
                handle.loop(1, listener);
            } catch (Exception ex) {
                // Ignore.
            }
        }
    }
}
```

上述代码做了详细注释，这里就不做重复解释了，运行测试用例，可以看到如下输出：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-network/arp-and-pcap4j-pcap4j-arp.png" width="70%">
</center>

可以看到从192.168.31.139发起的ARP查询，目标IP地址是192.168.31.58，得到其MAC地址是2a:d1:f7:53:e1:88，整个过程与wireshark抓包分析的情况类似。

最后，如果还记得wireshark抓包的截图，再回想提到的MAC地址和设备的厂商的关系，就会发现00:00:00:00:00:00被wireshark标注的厂商前缀是xerox，这是什么公司？Xerox，即施乐公司，就是它发明了以太网，不经意间构筑起了互联网的躯干。Xerox没有因为互联网而赚得盆满钵满，梅特卡夫和博格斯也没有凭借以太网这项技术实现财富自由，他们只是专注在做喜欢的事情，掸掸身上的尘土，无意间却改变了世界。本文所提到的ARP协议也是一样，在没有多少人关注的角落里，进行着无比重要的工作。

待到山花烂漫时，她在丛中笑。
