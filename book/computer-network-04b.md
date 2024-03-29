# 感悟《计算机网络：自顶向下》（04b.网络层）

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;网络层负责分组的路由和转发，而核心设备就是路由器，它是分组交换网络的核心设备。现在家庭接入互联网，大部分采用的是ADSL或者[FTTH](https://baike.baidu.com/item/FTTH)，可能FTTH越来越多了，在安装完ISP（电信或者移动等）提供的[Modem](https://baike.baidu.com/item/调制解调器)后，一般就需要选择购买一款路由器了。现在的家用路由器一般都具有[Wi-Fi](https://baike.baidu.com/item/Wi-Fi)无线功能，它长得样子可能类似这样，如下图所示。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/ip-xiaomi-ax9000.jpg" width="50%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，这是小米的[AX9000](https://www.mi.com/mirouter/ax9000)路由器，价格不便宜，性能不错，它有环绕机身的4根天线，外观看起来很科幻，底部有五个[RJ45](https://baike.baidu.com/item/RJ45/3401007)的接口，其中4个并作一排，另一个蓝色的单独在一边。路由器的4个接口用来连接家用有线设备，比如：台式机或者NAS存储，蓝色的RJ45接口用来连接光猫（其实也是路由器），光猫的样子一般如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/ip-modem.jpg" width="50%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，一个光猫一般会有许多不同的接口，除了DC电源接口，比较特殊的就是光纤接口（或者电话线的[RJ11](https://baike.baidu.com/item/RJ11)接口），图中蓝黄色的线就是光纤，而它连接的就是光纤接口，剩下的RJ45接口就是Modem提供的接口。光猫一般也是一个路由器，所以通过RJ45接口连接的设备也会被分配IP地址，无论它连着主机或另一个路由器，现实中光猫的RJ45接口一般就只连接到家中自费购买的路由器上。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这样看来，从家里任意一台连接到路由器的设备访问外网，至少会经历两跳（HOP），第一跳是本地主机到路由器，第二跳是路由器到光猫，然后光猫最终从光纤发射信号。我们可以通过`traceroute`命令来看一下分组的路由情况，执行过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/ip-traceroute-taobao.jpg" width="90%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，`traceroute -m 3 www.taobao.com`命令可以对分组路由执行跟踪，通过设置IP分组中TTL为3来尝试在一个端点跟踪向外的3次分组跳跃，并将跳跃的路径输出。在本示例中，尝试对`www.taobao.com`进行跟踪，第一跳是本机到路由器，第二跳是路由器到光猫（`192.168.1.1`），第三跳是住宅的光猫设备到杭州市余杭区城域网的网络设备（`183.128.118.129`），当然，如果taobao没有垮掉，经历若干次分组跳跃，分组最终会抵达`taobao.com`的`www`服务器。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到从家中任意的一次对外访问，都要做一次无谓的跳跃，如果光猫能够让ISP放开，家庭能够在市场上自由选择购买喜爱的光猫产品，这样每家每户除了省掉这多余的一跳以外，还能节省不少线材和能耗。另外在现有拓扑关系中，就算你家的路由器再强，但如果光猫性能孱弱，也是不利于发挥性能的，同时也要注意光猫和路由器之间的连接线材，至少是5E类级别及其以上的千兆网线，短板往往存在于不经意间。

## 基本构成

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在主机发起网络请求之前，操作系统协议栈程序会根据目标IP计算路由策略，通过目标IP找到网关（Gateway）进行路由，本机的网卡（Netif）会与对应的网关相连，在类UNIX系统中，可以通过`netstat`命令查看本机的路由信息。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/ip-netstat-rn.jpg" width="80%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，使用`netstat -rn`，查看当前系统的路由表，可以看到Destination目标一栏中，`default`默认网关的IP是`192.168.31.1`，这正是路由器的IP。在访问外网时，比如：访问`taobao.com`的主机，其IP在本机的路由表目标一栏中找不到，则会选择将分组路由到默认网关。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分组中目标IP地址依旧是`taobao.com`的主机IP地址，但是包含分组的以太网帧，其目标MAC地址是默认网关也就是`192.168.31.1`的MAC地址。在子网中，根据IP地址查询MAC地址的服务叫做ARP服务，这里的细节在后续介绍到数据链路层时在详细展开。

> 关于ARP服务，可以通过[《JavaNetwork's ARP与pcap4j》](https://zhuanlan.zhihu.com/p/672488936)进一步了解。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;路由器包含两个模块，包转发模块和端口模块，如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/ip-router-component.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;路由器的端口模块支持多种通信接口，比如：ADSL、FTTH以及以太网等。有些接口可以连接到外部互联网，比如：ADSL、FTTH、Cable或者以太网的RJ45，有些接口则提供给子网设备进行接入，比如：提供Wi-Fi的WLAN或者以太网的RJ45。路由器的端口模块有连接到上游网络设备的接口，也有连接内部子网设备的接口，从角色上看，路由器本质就是一个完成上传下达的中转节点。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;路由器内部有路由表，路由表包含了若干的路由规则，路由规则记录了目标地址，与之匹配网关（路由器或者主机，其实就是一个分组交换设备）的IP地址，以及路由器通过哪个接口与之（网关）相连。路由匹配的状态数据，也就是路由表有了，路由端口的设备也通过接口联通了，接下来就可以介绍路由器的运行机制。

## 运行机制

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;主机节点、交换机、路由器和光猫通过网线连接起来，这里提到了交换机，它是工作在数据链路层的设备，主要用来连接子网中所有的网络设备，一般来说路由器也会作为一台主机设备连接到交换机上，只是路由器会同时有一根线连接到了子网外部的设备，比如：光猫。现在的路由器基本都具备交换机的功能，所以它们是可以放到一起的，但是在介绍路由器运行机制时，还是需要将它们分开，至于交换机，将会在数据链路层进行介绍，在这里只用知道它是用来完成子网中任意两个设备之间进行通信的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从主机节点发起一个对外部网络的请求，比如：打开浏览器访问`www.taobao.com`，这些设备连接的拓扑以及在拓扑上的请求顺序如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/ip-router-work.jpg" width="60%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，根据编号顺序，从访问方向，参与设备以及详细执行过程几个方面进行说明，其中涉及到交换机的部分会做简要介绍。

（1）主机节点出

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;涉及设备：主机节点、交换机和路由器。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（1.1）主机节点根据域名`www.taobao.com`发起DNS解析，在操作系统启动时，会获取到DNS服务端的IP地址，一般来说它会部署在路由器上。主机节点的DNS解析通过交换机向路由器发起请求，主机节点获得`www.taobao.com`对应的IP地址；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（1.2）获得的IP地址结合本机的路由表进行路由计算，得到目标网关是路由器，再根据路由器的IP进行ARP查询获取路由器IP的MAC地址。一般来说交换机的端口没有分配MAC地址，是以连接到接口上的分组交换设备MAC地址为主的；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（1.3）构造好以太网帧，其中目标MAC地址是路由器的MAC地址，而以太网帧中包含IP分组中的目标IP地址是先前经过DNS解析出来的IP地址，IP分组中包含的TCP报文目标端口是80，而报文内容是HTTP请求体。

（2）交换机出

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;涉及设备：交换机和路由器。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（2.1）交换机根据以太网帧中的目标MAC地址查得路由器连接的端口，然后将以太网帧转发到对应端口，完成数据传输；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（2.2）路由器收到以太网帧，进行目标MAC地址核对，如果不是发给它的，则丢弃。拆开IP分组，根据目标IP地址进行路由计算，得知需要发送给光猫（路由器）。

（3）路由器出

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;涉及设备：路由器和光猫。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（3.1）路由器将以太网帧的头部，包括来源和目标MAC地址丢弃，将内容装到新的帧中，来源MAC地址是路由器的MAC地址，而目标MAC地址是光猫，至于怎么知道光猫的MAC地址，还是需要依靠ARP查询；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（3.2）路由器将以太网帧发送给光猫。

（4）光猫出

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;涉及设备：光猫。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（4.1）光猫收到以太网帧，进行目标MAC地址匹配，然后再依据其中IP分组中目标IP地址进行路由计算，得到需要使用光纤接口进行发送数据；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（4.2）光猫将比特数据进行调制编码，转换为光信号，发送之；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（4.3）光猫收到光信号，进行解调，转换为比特数据，然后再将比特数据转换为分组，IP分组中的目标IP是子网中的主机节点IP，经过路由计算，需要将分组发送给路由器。

（5）路由器出

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;涉及设备：光猫、路由器和主机节点。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（5.1）光猫将分组发送给路由器，路由器将以太网帧进行目标比对，通过后再获取分组中的目标IP；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（5.2）根据目标IP进行ARP转换，通过交换机广播后，路由器得知主机节点的MAC地址；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（5.3）使用主机节点的MAC地址作为目标MAC地址，重新构建以太网帧，并发送到交换机。

（6）交换机出

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;涉及设备：交换机和主机节点。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（6.1）交换机根据以太网帧中的目标MAC地址，通过交换机内部的对应表得到该MAC地址的设备处于哪个端口；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（6.2）将以太网帧数据发往对应端口，主机节点收到数据。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，一次普通的HTTP请求和应答，竟然如此的复杂，上述过程中还有很多细节没有展开，但是分组交换网络这种接收、存储、处理和转发的模式应该能看的很清楚。对于路由器而言，端口模块将请求收进来，转发模块会根据目标IP地址，结合自身的路由表进行计算，得到需要派发的接口，然后再委托端口模块调用驱动，将数据透过对应接口（硬件）发送出去，这些动作其实都是有开销和耗时的，与一次RPC网络调用很相似，因此，减少一个路由节点，长时间看，能效提升还是很大的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;路由器端口模块中的以太网接口，不仅会分配IP地址，还具有MAC地址，这点与交换机不同，交换机的以太网接口没有MAC地址，它是跟着连接到交换机的设备MAC地址一致的。具备MAC地址，就是一个能够被链路层标识的点，这样看来，路由器和主机没有多少区别，只是它的工作更为专注，收到分组后，进行路由转发而已。路由器是IP网络中的重要参与者，交换机只是将进来的以太网帧进行转发。

> 关于交换机的详细内容，到数据链路层再谈。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;路由器在进行路由计算时，会忽略主机号部分，只匹配网络号部分，路由表示例如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/ip-router-table.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，子网掩码表示匹配目标地址需要比对的比特数量，比如：`255.255.255.0`，代表需要比对前`24`个比特，也可以看到路由规则对应的目标地址是`192.168.1.0`。网关和接口表示需要转发的目标，一般接口常见的是本地网卡`localhost0`或者本机的无线网卡`en0`等，它们对应了硬件（或者虚拟硬件），具有调制和解调的能力，能够将比特变为电信号，或者反过来。网关是接口连接的目标，图中`e1`接口连接的就是一个分组交换设备，IP是`192.0.2.1`，一般这个设备对应的就是路由器。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;路由计算策略一般遵循如下步骤：

1. 先按照子网掩码位数最多的目标地址进行匹配；
2. 减少子网掩码的位数再尝试匹配，不断重复步骤2；
3. 如果目标地址中没有与之匹配的项目，则返回默认规则。

> 默认路由规则一般对应的是`0.0.0.0`（或`default`）的目标地址

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;举个例子，如果分组的目标IP地址是`192.168.1.4`，首先匹配`255.255.255.255`子网掩码对应的目标地址`10.10.1.101`，结果是不匹配；其次匹配`255.255.255.0`子网掩码对应的目标地址，`192.168.1.0`，也就是子网号为`192.168.1`的目标地址与之匹配，匹配成功，返回对应的路由规则。端口模块随后会使用接口`e3`将分组发送出去。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果分组的目标IP地址是`192.192.192.192`，最终经过路由计算会匹配到默认规则，也就是`0.0.0.0`，将分组发往`192.0.2.1`，委托它（路由器）将分组数据送到目标IP为`192.192.192.192`的分组交换设备。如果路由计算出的路由规则，其网关为空或者是MAC地址，则代表目标IP已经处于当前路由器所管理的子网中，数据到站了，按照目标MAC进行转发即可。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从上述路由器的运作过程可以看出，路由器就相当于一台会进行分组转发的主机，其实本质上它就是一台主机，上面运行着一个Linux，在Linux上面运行着路由器程序而已，这个程序使用的协议栈和普通主机使用的协议栈没有多少区别，功能都是类似的，只是这个程序能够驱动多个端口以及操纵属于它的硬件设备，比如：`Wi-Fi`天线等，它的执行过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/ip-router-route.jpg" width="25%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，从以太网接口收到帧，判断是发给自己（也就是路由器）的后，丢弃掉MAC头部，然后从IP分组中拿出目标IP，依据本地路由表进行计算，匹配到合适的路由规则，委托端口模块将数据转发到与路由规则中接口相连的网关上。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;端口模块接收到IP分组以及路由计算得出的路由规则，就开始转发工作，该工作执行过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/ip-router-redirect.jpg" width="25%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，选择路由规则中的接口，将IP分组中的TTL作修改（一般来说是减1），再根据接口MTU进行IP分片，然后再将分片后的IP分组按照接口类型（或者说数据链路层媒介）进行数据转发。这里按照MTU进行分片的原因是IP分组毕竟要跑在具体的承载网技术上，比如：以太网，如果接口是RJ45，也就是以太网，那就要求待转发的IP分组载荷不超过以太网帧的最大要求。分片后的IP分组就可以按照接口类型进行数据转发了，如果是以太网，那就加上以太网的头部以及结束帧，按照以太网帧的形式进行调制，将调制后的电信号从接口发送出去。

> 这个过程本质上是将IP分组装进以太网帧的数据部分，然后委托以太网进行传输，因为IP协议没有传输数据的能力。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;回过头来看一下路由表，前面提到在一个分组交换设备中，保存有两个状态，一个是IP地址，另一个就是路由表。互联网中存在大量的路由器，路由器之间独立维护路由表，在一个路由器内部，路由表的维护也是同分组转发操作是相互独立的。相互连接的路由器要感知到彼此的存在，才能完成分组路由工作，路由表的维护工作可以由人工或者路由协议机制，比如：[RIP](https://baike.baidu.com/item/路由信息协议/2707187)、[OSPF](https://baike.baidu.com/item/组播扩展OSPF)或者[BGP](https://baike.baidu.com/item/边界网关协议)协议，它们是如何让路由器达成共识，接下来会进行介绍。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;路由器还具备路由规则的聚合与拆分功能，比如：路由器中有三个规则，分别涉及到三个子网，`10.10.1.0/24`，`10.10.2.0/24`和`10.10.3.0/24`，这三个规则的网关如果一样，那么就可以进行聚合，即聚合成`10.10.0.0/16`一条路由规则，目的就是为了减少路由规则，节约资源，提升判断的效率。拆分是针对一个子网中的单个主机，如果子网中存在多个主机，那么可以按照子网掩码`255.255.255.255`的形式增加一条针对具体主机的路由规则（多台主机会有多条），它的网关可以使用这台主机的MAC地址，这样在子网内部主机互访时，就变得高效许多。

## 达成共识

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Internet上存在大量的路由器，各个路由器下有规模不一的子网，通过聚合后，有大约几十万个子网。相邻两点的路由器需要进行路由信息（或者路由表）交换，不相邻的则不必交换，因为只有通过交换路由信息，一台路由器才能对自己所处的位置有明确的认识，有了认识后才可以实现路由计算。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;RIP协议用来实现路由器之间的路由信息交换，该协议的实现一般基于UDP协议，端口在520，用来完成数据传输。交换的内容是当前路由器的路由表，路由器运行时会广播请求，收到请求的路由器会单播回复该路由器自己的路由表，而发起广播的路由器会将收到的路由表做好处理并加入到自己的路由表中。这样如果当前路由器收到一个分组，其目标IP地址属于另一个路由器所管理的，那么通过路由计算，因为本地路由表已经更新，这就可以得到路由规则，从而完成路由转发工作。

> 一般每隔30秒会进行一次路由信息交换。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果按照RIP的运作方式，最终互联网上的任意路由器节点都会具备全量的路由信息。路由器拥有全量的路由信息这显然不现实，因此将网络（子网）按照自治区的方式进行划分，路由信息的交换只发生在自治区的部分路由器上。可以分为自治区之间的协议和自治区内的协议，而自治区之间的路由交换协议就是BGP，边界网关协议。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;BGP协议分为两种：eBGP和iBGP。eBGP，即externalBGP，目的是收集内部子网可达信息，通过eBGP告知其他自治区。iBGP，即internalBGP，任务是通知自治区内部收到的可达信息。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/computer-network/ip-bgp.jpg" width="60%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，eBGP收集内部子网信息，然后做好聚集，将信息给到另一个自治区的边界网关，表示如果有分组要发给这些子网，可以由我来路由。收到信息的边界网关，通过iBGP将信息分发给自治区内的路由器，表示如果有分组要发给这些子网，可以来交给我路由。这样两个边界网关就完成了路由信息交换，自治区之间更大规模的子网信息就能达成共识。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;互联网中一个个路由器如同夜晚大洋中的一座座灯塔，相邻的彼此感知到对方的存在，而传输的分组如同一艘艘小船，它们向最近的灯塔诉说自己的目的地，而身边的灯塔总会告诉它该怎样去往下一个灯塔，纵使小船需要跨过整个海洋，借助灯塔们的接力，它也能轻松做到。
