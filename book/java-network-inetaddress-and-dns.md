# **Java**Network's InetAddress与DNS

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用**Java**进行**Socket**编程，需要知晓对端的主机和端口，然后使用**SocketAPI**进行编程通信。以发送一个**HTTP**请求和获取响应为例，使用**Java**可以这样写：

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

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述示例创建了一个`socket`，连接到`www.baidu.com`，然后请求其首页，将**HTTP**响应以文本形式打印出来。这里我们不关注通过socket获取输入输出流的操作，而是关注`socket`是如何构造和初始化的。任何语言构建`socket`都差不多，底层都是依赖操作系统提供的协议栈，也就是一个通用的内核级别程序，由它来专门负责同网卡打交道。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-network/inetaddress-and-dns-net.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在示例中的第一步，首先会通过静态方法`getByName()`创建`InetAddress`实例，然后再使用`InetAddress`实例再加上端口创建`SocketAddress`实例。构建好的**Socket**实例，然后通过传入`SocketAddress`实例和连接超时，调用`connect()`方法，协议栈会在绑定本地网卡和（随机）端口后，尝试同`www.baidu.com:80`建立**TCP**连接。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`InetAddress`代表了**IP**协议中的地址信息，**IP地址**是**IP协议**中的重要组成部分，网络包的路由都依托于**IP**地址，**IP地址**是一个32位(或128位）的无符号整数。`InetAddress`类提供了一些静态方法，如：`getByName()`和`getAllByName()`，传入主机名返回相应的**IP地址**。这些方法是基于**DNS协议**来实现的，可以通过**DNS服务器**来解析主机名。在使用`getByName()`方法时，如果主机名无法解析**IP地址**，则会抛出`UnknownHostException`异常。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;客户端不能同`www.baidu.com`直接建立连接，而是要通过**DNS解析**，将域名或主机名转换为**IP**，这里的`www.baidu.com`是主机，而`baidu.com`是域名。因此可以推断出，在调用`InetAddress`的`getByName()`方法时，会发起网络调用，而这个网络调用就是**DNS查询**。

## InetAddress#getByName分析

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`InetAddress getByName(String host)`，该方法接受一个主机或者域名，返回**DNS查询**的结果，结果类型是`InetAddress`，它包括了主机名以及地址，例如：

```java
@Test
public void getByNameStringInternet() throws Exception {
    InetAddress address = InetAddress.getByName("www.taobao.com");
    System.out.println("HostName:" + address.getHostName());
    System.out.println("HostAddress:" + address.getHostAddress());
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;运行测试用例，输出如下：

```sh
HostName:www.taobao.com
HostAddress:61.174.43.210
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;既然是**IP地址**是查询**DNS服务器**获得的，那`getByName()`方法势必要发起远程调用，**Java**是怎样实现的呢？我们接下来看一下代码实现，以下代码基于**JDK17**。首先是调用`getAllByName()`，获取主机host对应的**IP地址**，以下是部分代码。

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

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到该方法的实现是针对传入的host参数是**IP类型**的判断，没有涉及到域名解析，它主要完成了参数是**IP类型**的请求处理，那域名解析呢？域名解析为什么还需要接受**IP类型**参数？这是因为**DNS解析**是双向的，可以给定**IP**查询对应的主机名。而在最后的`getAllByName0()`方法中，比较关键的逻辑如下：

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

> 其中`Addresses`接口是返回多个`InetAddress`的内部接口，其实完全可以使用`Supplier<T>`接口来替代，这里不得不说，**Java**的net包下，`InetAddress`等相关实现类，写的不怎么好，有些乱，**API**和**SPI**傻傻的分不清楚。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到获取**IP地址**时，会从静态缓存中获取，通过配置，是可以修改缓存过期时间的，在某些**HTTP**短连接场景，是一个不错的优化方案，这个我们在后面讲述。接下来就是调用**DNS查询**，**Java**对**DNS服务**做了抽象，定义了如下内部接口：

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

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到该服务定义了两个方法，使用主机名获取**IP地址**的`lookupAllHostAddr()`和根据**IP地址**获取主机名的`getHostByAddr()`。能抽象出一个`NameService`是非常有必要的，但是这是在**Java9**中定义的，都已经有模块化的支持了，如果要扩展`NameService`怎么办？这里大胆的猜测，定义`NameService`以及相关抽象的同学，在重构这块代码时，不太理解**Java9**的模块化编程方式，只是简单的使用了静态初始化的方式，用传统手艺完成了工作。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在`NameService`的默认实现`PlatformNameService`中，以`IPv4`为例，调用的是`Inet4AddressImpl`本地方法`lookupAllHostAddr()`来获取。

```java
class Inet4AddressImpl implements InetAddressImpl {
    public native InetAddress[]
        lookupAllHostAddr(String hostname) throws UnknownHostException;
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Java**自己不是有**SocketAPI**么？为什么还需要使用**native**方法来完成这个工作？其实好理解，如果`InetAddress`依赖**Socket**，结果**Socket**创建又依赖`InetAddress`，就有些尴尬了，没关系，我们接着看**JVM**的实现。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;部分**JVM**实现代码：

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

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到通过调用系统函数`gethostbyname()`来解析域名，该函数背后的实现是通过**UDP**发起**DNS查询**，从而获得到主机（或域名）对应的**IP列表**。操作系统在启动时，会获取本地网络中的**DNS服务器**IP，并将其设置给协议栈，所以`InetAddress`不用去指定**DNS服务器**。我们运行测试用例，执行`getByNameStringInternet()`测试方法，然后使用`wireshark`抓包看看。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-network/inetaddress-and-dns-wireshark-dns.png" width="80%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，从上到下就是网络协议自底向上，这是抓取到从`en0网卡`发出的**DNS查询**请求与响应，图中标注了一些重点，按照序号：

1. 说明网络包是从`en0网卡`发出的；
2. 以太网头部，其中SRC和DST分别指的是来源和目标的MAC地址，因为链路层只负责点对点的数据传输；
3. IP头部，其中协议值为17，表示在IP之上跑的传输层协议是**UDP**；
4. IP头部，目标地址是**DNS服务器**地址；
5. UDP头部，其中端口是53，**DNS服务器**默认端口是53；
6. 应用层协议头部，DNS请求的查询参数，其中`Class`类型是`IN`(ternet)，业务类型`type`是主机地址，参数是：`www.taobao.com`。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看出来**DNS**并不是设计出来专门针对互联网，也想支持其他网络，但是现如今互联网占据了统治地位。同时**DNS请求**头中有`Transaction ID`，这个**ID**用来将请求和响应在客户端对应起来，因此**DNS协议**是异步的，效率应该挺高的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;既然`192.168.31.1`能够返回**DNS响应**，想必它存储了一些数据，一般**DNS服务器**会存储域名和IP的相关信息，可以理解为一张表，它记录着：`domain`、`class`、`type`以及`data`，其中`data`这一列中可以存域名别名或者IP等。刚发起对`www.taobao.com`的**DNS查询**，就可以理解为：`select data from dns where domain=“www.taobao.com” and class=“IN” and type=“A”`。

## InetAddress#getHostName分析

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果是查表，能否支持根据`data`来查询呢？也就是使用IP查询当前的主机名，答案是可以的。接着看如下测试用例：

```java
@Test
public void getByNameStringInternet1() throws Exception {
    InetAddress address = InetAddress.getByName("192.168.31.1");
    System.out.println(address.getHostName());
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;运行测试用例，输出如下：

```sh
xiaoqiang
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;不知道为什么小米路由器的主机名为什么叫小强，八卦了一下，貌似代码都是`xiaoqiang`开头，参见[视频](https://www.bilibili.com/video/av839373557)。接下来看一下**Java**实现，其中（主要）部分如下：

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

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到通过调用`NameService`的`getHostByAddr()`方法获取到IP对应的主机名。运行测试用例，通过`wireshark`抓包，通过观察DNS响应。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-network/inetaddress-and-dns-wireshark-name.png" width="90%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，调用`InetAddress`实例的`getHostName()`方法，会发起**DNS查询**。通过观察**DNS响应**，可以看到请求和响应内容，按照序号：

1. 查询参数，IP是192.168.31.1；
2. 响应结果，`domain`是`XiaoQiang`。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;根据某个主机（或域名）构造一个`InetAddress`，然后建立**TCP**连接后，就可以进行数据交换。如果每次连接建立都进行**DNS解析**，就显得有些累赘，毕竟主机（或域名）对应的IP不经常变动。因此，**Java**会通过一个静态缓存来存储解析成功和不成功的`InetAddress`。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;默认情况下，**Java**会将解析成功的`InetAddress`缓存`30`秒，对于解析不成功的主机名会缓存`10`秒。如果希望增加解析成功的缓存时间，可以通过设置**Java**系统变量`networkaddress.cache.ttl`，单位是**秒**，如果对解析不成功的缓存时间，可以使用变量`networkaddress.cache.negative.ttl`，如果需要永久缓存，值可以设为`-1`。如果系统中有短连接的访问方式，适当的增加**DNS缓存时间**，对提升链路性能会有所帮助。
