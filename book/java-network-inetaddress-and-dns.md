# JavaNetwork's InetAddress与DNS

使用Java进行Socket编程，需要知晓对端的主机和端口，然后使用SocketAPI进行编程通信。以发送一个HTTP请求和获取响应为例，使用Java SocketAPI 可以这样写：

```java
@Test
public void http() throws Exception {
    InetAddress inetAddress = InetAddress.getByName("www.baidu.com");
    SocketAddress socketAddress = new InetSocketAddress(inetAddress, 80);
    Socket socket = new Socket();
    // imply bind & connect
    socket.connect(socketAddress, 3000);

    PrintWriter out = new PrintWriter(socket.getOutputStream());
    out.println("GET / HTTP/1.0\r\n");
    out.println("HOST: www.baidu.com\r\n");
    out.println("Accept-Encoding:gzip,deflate\r\n");
    out.println("Accept: */*\r\n");
    out.println("\r\n");
    out.flush();

    BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(socket.getInputStream()));
    String line = null;
    while ((line = bufferedReader.readLine()) != null) {
        System.out.println(line);
    }
}
```

上述示例创建了一个socket，连接到www.baidu.com，然后请求其首页，将HTTP响应以文本形式打印出来。这里我们不关注通过socket获取输入输出流的操作，而是关注socket是如何构造和初始化的。任何语言构建socket都差不多，底层都是依赖操作系统提供的协议栈，也就是一个通用的内核级别程序，由它来专门负责同网卡打交道。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-network/inetaddress-and-dns-net.png" width="70%">
</center>

在示例中的第一步，首先会通过静态方法getByName()创建InetAddress实例，然后再使用InetAddress实例再加上端口创建SocketAddress实例。构建好的Socket实例，然后通过传入SocketAddress实例和连接超时，调用connect方法，协议栈会在绑定本地网卡和（随机）端口后，尝试同www.baidu.com:80建立TCP连接。

InetAddress代表了IP协议中的地址信息，IP地址是IP协议中的重要组成部分，网络包的路由都依托于IP地址，IP地址是一个32位(或128位）的无符号整数。InetAddress类提供了一些静态方法，如：getByName()和getAllByName()，传入主机名返回相应的IP地址。这些方法是基于DNS协议来实现的，可以通过DNS服务器来解析主机名。在使用getByName()方法时，如果主机名无法解析IP地址，则会抛出UnknownHostException异常。

客户端不能同www.baidu.com直接建立连接，而是要通过DNS解析，将域名或主机名转换为IP，这里的www.baidu.com是主机，而baidu.com是域名。因此可以推断出，在调用InetAddress的getByName()方法时，会发起网络调用，而这个网络调用就是DNS查询。

## InetAddress#getByName分析

InetAddress getByName(String host)，该方法接受一个主机或者域名，返回DNS查询的结果，结果类型是InetAddress，它包括了主机名以及地址，例如：

```java
@Test
public void getByNameStringInternet() throws Exception {
    InetAddress address = InetAddress.getByName("www.taobao.com");
    System.out.println("HostName:" + address.getHostName());
    System.out.println("HostAddress:" + address.getHostAddress());
}
```

运行测试用例，输出如下：

```sh
HostName:www.taobao.com
HostAddress:61.174.43.210
```

既然是IP数据是查询DNS服务器获得的，那getByName()方法势必要发起远程调用，Java是怎样实现的呢？我们接下来看一下代码实现，以下代码基于JDK17。首先是调用getAllByName()，获取主机host对应的IP地址，以下是部分代码。

```java
private static InetAddress[] getAllByName(String host, InetAddress reqAddr)
    throws UnknownHostException {

    if (host == null || host.isEmpty()) {
        InetAddress[] ret = new InetAddress[1];
        ret[0] = impl.loopbackAddress();
        return ret;
    }

    // Check and try to parse host string as an IP address literal
    if (IPAddressUtil.digit(host.charAt(0), 16) != -1
        || (host.charAt(0) == ':')) {

        if(addr != null) {
            InetAddress[] ret = new InetAddress[1];
            if (addr.length == Inet4Address.INADDRSZ) {
                if (numericZone != -1 || ifname != null) {
                    // IPv4-mapped address must not contain zone-id
                    throw new UnknownHostException(host + ": invalid IPv4-mapped address");
                }
                ret[0] = new Inet4Address(null, addr);
            } else {
                if (ifname != null) {
                    ret[0] = new Inet6Address(null, addr, ifname);
                } else {
                    ret[0] = new Inet6Address(null, addr, numericZone);
                }
            }
            return ret;
        }
    } else if (ipv6Expected) {
        // We were expecting an IPv6 Literal since host string starts
        // and ends with square brackets, but we got something else.
        throw invalidIPv6LiteralException(host, true);
    }
    return getAllByName0(host, reqAddr, true, true);
}
```

可以看到该方法的实现是针对传入的host参数是IP类型的判断，没有涉及到域名解析，它主要完成了参数是IP类型的请求处理，那域名解析呢？域名解析为什么还需要接受IP参数？这是因为DNS解析是双向的，可以给定IP查询对应的主机名。而在最后的getAllByName0()方法中，比较关键的逻辑如下：

```java
// look-up or remove from cache
Addresses addrs;
if (useCache) {
    addrs = cache.get(host);
} else {
    addrs = cache.remove(host);
    if (addrs != null) {
        if (addrs instanceof CachedAddresses) {
            // try removing from expirySet too if CachedAddresses
            expirySet.remove(addrs);
        }
        addrs = null;
    }
}

if (addrs == null) {
    // create a NameServiceAddresses instance which will look up
    // the name service and install it within cache...
    Addresses oldAddrs = cache.putIfAbsent(
        host,
        addrs = new NameServiceAddresses(host, reqAddr)
    );
    if (oldAddrs != null) { // lost putIfAbsent race
        addrs = oldAddrs;
    }
}

// ask Addresses to get an array of InetAddress(es) and clone it
return addrs.get().clone();
```

> 其中Addresses接口是返回多个InetAddress的内部接口，其实完全可以使用Supplier&lt;T&gt;接口来替代，这里不得不说，Java的net包下，InetAddress等相关实现类，写的不怎么好，有些乱，API和SPI傻傻的分不清楚。

可以看到获取IP地址时，会从静态缓存中获取，通过配置，是可以修改缓存过期时间的，在某些HTTP短连接场景，是一个不错的优化方案，这个我们在后面讲述。接下来就是调用DNS查询，Java对DNS服务做了抽象，定义了如下内部接口：

```java
/**
 * NameService provides host and address lookup service
 *
 * @since 9
 */
private interface NameService {

    /**
     * Lookup a host mapping by name. Retrieve the IP addresses
     * associated with a host
     *
     * @param host the specified hostname
     * @return array of IP addresses for the requested host
     * @throws UnknownHostException
     *             if no IP address for the {@code host} could be found
     */
    InetAddress[] lookupAllHostAddr(String host) throws UnknownHostException;

    /**
     * Lookup the host corresponding to the IP address provided
     *
     * @param addr byte array representing an IP address
     * @return {@code String} representing the host name mapping
     * @throws UnknownHostException
     *             if no host found for the specified IP address
     */
    String getHostByAddr(byte[] addr) throws UnknownHostException;
}
```

可以看到该服务定义了两个方法，使用主机名获取IP地址的lookupAllHostAddr()和根据IP地址获取主机名的getHostByAddr()。能抽象出一个NameService是非常有必要的，但是这是在Java9中定义的，都已经有模块化的支持了，如果要扩展NameService怎么办？这里大胆的猜测，定义NameService以及相关抽象的同学，在重构这块代码时，不太理解Java9的模块化编程方式，只是简单的使用了静态初始化的方式，用传统手艺完成了工作。

在NameService的默认实现PlatformNameService中，以IPv4为例，调用的是Inet4AddressImpl本地方法lookupAllHostAddr()来获取。

```java
class Inet4AddressImpl implements InetAddressImpl {
    public native InetAddress[]
        lookupAllHostAddr(String hostname) throws UnknownHostException;
}
```

Java自己不是有SocketAPI么？为什么还需要使用native方法来完成这个工作？其实好理解，如果InetAddress依赖Socket，结果Socket创建又依赖InetAddress，就有些尴尬了，没关系，我们接着看JVM的实现。

部分JVM实现代码：

```c
/*
* Perform the lookup
*/
if ((hp = gethostbyname((char*)hostname)) != NULL) {
    struct in_addr **addrp = (struct in_addr **) hp->h_addr_list;
    int len = sizeof(struct in_addr);
    int i = 0;

    while (*addrp != (struct in_addr *) 0) {
        i++;
        addrp++;
    }
}
```

可以看到通过调用系统函数gethostbyname()来解析域名，该函数背后的实现是通过UDP发起DNS查询，从而获得到主机（或域名）对应的IP列表。操作系统在启动时，会获取本地网络中的DNS服务器IP，并将其设置给协议栈，所以InetAddress不用去指定DNS服务器。我们运行测试用例，执行getByNameStringInternet()测试方法，然后使用wireshark抓包看看。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-network/inetaddress-and-dns-wireshark-dns.png" width="80%">
</center>

如上图所示，从上到下就是网络协议自底向上，这是抓取到从en0网卡发出的DNS查询请求与响应，图中标注了一些重点，按照序号：

1. 说明网络包是从en0网卡发出的；
2. 以太网头部，其中SRC和DST分别指的是来源和目标的MAC地址，因为链路层只负责点对点的数据传输；
3. IP头部，其中协议值为17，表示在IP之上跑的传输层协议是UDP；
4. IP头部，目标地址是DNS服务器地址；
5. UDP头部，其中端口是53，DNS服务器默认端口是53；
6. 应用层协议头部，DNS请求的查询参数，其中Class类型是IN(ternet)，业务类型type是主机地址，参数是：www.taobao.com。

可以看出来DNS并不是设计出来专门针对互联网，也想支持其他网络，但是现如今互联网占据了统治地位。同时DNS请求头中有Transaction ID，这个ID用来将请求和响应在客户端对应起来，因此DNS协议是异步的，效率应该挺高的。

既然192.168.31.1能够返回DNS响应，想必它存储了一些数据，一般DNS服务器会存储域名和IP的相关信息，可以理解为一张表，它记录着：domain、class、type以及data，其中data这一列中可以存域名别名或者IP等。刚发起对www.taobao.com的DNS查询，就可以理解为：select data from dns where domain=“www.taobao.com” and class=“IN” and type=“A”。

如果是查表，能否支持根据data来查询呢？也就是使用IP查询当前的主机名，答案是可以的。接着看如下测试用例：

```java
@Test
public void getByNameStringInternet1() throws Exception {
    InetAddress address = InetAddress.getByName("192.168.31.1");
    System.out.println(address.getHostName());
}
```

运行测试用例，输出如下：

```sh
xiaoqiang
```

不知道为什么小米路由器的主机名为什么叫小强，八卦了一下，貌似代码都是xiaoqiang开头，参见[视频](https://www.bilibili.com/video/av839373557)。接下来看一下Java实现，其中（主要）部分如下：

```java
private static String getHostFromNameService(InetAddress addr, boolean check) {
    String host = null;
        try {
            // first lookup the hostname
            host = nameService.getHostByAddr(addr.getAddress());

            InetAddress[] arr = InetAddress.getAllByName0(host, check);
            boolean ok = false;

            if(arr != null) {
                for(int i = 0; !ok && i < arr.length; i++) {
                    ok = addr.equals(arr[i]);
                }
            }

            //XXX: if it looks a spoof just return the address?
            if (!ok) {
                host = addr.getHostAddress();
                return host;
            }
        } catch (SecurityException e) {
            host = addr.getHostAddress();
        } catch (UnknownHostException e) {
            host = addr.getHostAddress();
            // let next provider resolve the hostname
        }
    return host;
}
```

可以看到通过调用NameService的getHostByAddr()方法获取到IP对应的主机名。运行测试用例，通过wireshark抓包，通过观察DNS响应。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-network/inetaddress-and-dns-wireshark-name.png" width="90%">
</center>

如上图所示，调用InetAddress实例的getHostName()方法，会发起DNS查询。通过观察DNS响应，可以看到请求和响应内容，按照序号：

1. 查询参数，IP是192.168.31.1；
2. 响应结果，domain是XiaoQiang。

根据某个主机（或域名）构造一个InetAddress，然后建立TCP连接后，就可以进行数据交换。如果每次连接建立都进行DNS解析，就显得有些累赘，毕竟主机（或域名）对应的IP不经常变动。因此，Java会通过一个静态缓存来存储解析成功和不成功的InetAddress。

默认情况下，Java会将解析成功的InetAddress缓存30秒，对于解析不成功的主机名会缓存10秒。如果希望增加解析成功的缓存时间，可以通过设置Java系统变量`networkaddress.cache.ttl`，单位是秒，如果对解析不成功的缓存时间，可以使用变量`networkaddress.cache.negative.ttl`，如果需要永久缓存，值可以设为-1。如果系统中有短连接的访问方式，适当的增加DNS缓存时间，对提升链路性能会有所帮助。
