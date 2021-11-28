# 分布式锁框架

## 为什么需要分布式锁框架？

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分布式锁的实现方式不同，它相应的性能、可用性和正确性保障以及成本都会有所不同，因此需要提供一种适配多种不同实现方式的技术方案。虽然分布式锁的实现可以有多种，但是都需要有监控、流控以及热点锁访问优化等特性，所以该方案不仅能够提供一致的分布式锁API来适配不同的分布式锁实现方式，还需要具备横向功能扩展的能力。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-framework-page.jpg">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;既要适配不同的实现方式，又要支持开发者横向扩展，这一纵一横的需求就需要通过设计一个简单的分布式锁框架（以下简称为：框架）来达成了。该框架，不仅能够提供给使用者一致且简洁的API，而且能够快速适配不同的分布式锁实现方案，最关键的还可以提供给开发者以横向拦截扩展能力。

## 分布式锁框架

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这个简单的框架分为两类，共5个模块，一类是面向使用者的客户端和starter，另一类是面向开发者的SPI、实现扩展与插件扩展。如果只是想使用分布式锁，那就只需要依赖框架提供的starter，前提是应用基于springboot构建的。如果想扩展分布式锁的实现以及获取与释放锁的链路，可以通过实现框架提供的SPI以达成目的。框架中的各模块都有各自的分工与作用，它们的关系以及包含的主要组件如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-framework-component.png" width="80%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，使用者通过依赖starter来将框架快速的引入到应用，同时使用客户端来完成分布式锁的创建、获取与释放。框架的开发者可以通过依赖扩展SPI中的LockRemoteService来将不同的分布式锁实现（比如：Redis或ZooKeeper）引入到框架中，这些实现会对使用者透明。开发者还可以通过实现SPI中的LockHandler完成对分布式锁获取与释放的链路扩展，扩展实现会以切面的形式嵌入到执行链路中，并且对分布式锁的实现以及使用者透明。

### 分布式锁客户端

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;面向使用者的分布式锁客户端，以工厂模式进行构建，使用者可以通过传入锁名称来获取到分布式锁，并使用之。通过依赖SPI将分布式锁实现同使用者编程界面隔开，其主要类图如下所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-framework-client-class.png" width="80%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;客户端模块主要定义了分布式锁的接口以及实现骨架。分布式锁DistributeLock主要提供了两个方法，分别是获取锁的tryLock(long waitTime, TimeUnit unit)和释放锁的unlock()。为什么没有提供类似JUC中的lock()方法呢？如果有的话，客户端调用后，会等待获取锁后才返回，有更好的使用体验。原因是客户端使用分布式锁进行加锁时，实际会在底层会发起网络通信，由于网络通信的不可靠性，一旦发生阻塞，将会导致出现用户期望外的问题，所以明确的在参数中给出获取锁的超时，使用户对于获取锁有更明确的认知。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分布式锁实现DistributeLockImpl会将客户端获取锁（以及释放锁）的调用请求委派给SPI，由SPI中的LockHandler来处理。使用者可以非常简单实用分布式锁，只需要从DistributeLockManager中获取锁，然后就可以进行操作，示例代码如下：

```java
DistributeLock lock = distributeLockManager.getLock("lock_name");
if (lock.tryLock(1, TimeUnit.SECONDS)) {
    try {
        // do sth...
    } finally {
        lock.unlock();
    } 
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述代码表示获取一个名为lock_name的分布式锁，然后对其尝试加锁，超时时间为1秒，如果1秒内成功加锁，则执行一段逻辑，并在最后完成解锁。

### 分布式锁SPI

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;面向开发者的分布式锁SPI，以责任链模式进行构建，开发者可以扩展不同的分布式锁实现以及拦截分布式锁获取与释放链路。分布式锁SPI是框架扩展的体现，其主要类图如下所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-framework-spi.png" width="80%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SPI模块定义了扩展框架所需的相关接口，包含：面向分布式锁实现的LockRemoteResource和面向链路的LockHandler。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;LockRemoteResource定义了获取锁资源的两个方法，即：tryAcquire和release，前者是在超时时间内对远程锁资源进行获取，并返回获取结果AcquireResult，后者是根据资源名称和资源值对获取的资源进行释放。只要具备资源获取和释放的分布式存储服务，都可以通过扩展LockRemoteResource以分布式锁实现的形式集成到框架中，比如：Redis的String数据类型，具备键值的存取功能，那就可以将键值视作分布式锁资源，键值存储作为资源获取，键值删除作为资源释放，以此将Redis转换为分布式锁实现，从而整合到框架中。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;LockHandler定义了获取与释放锁的行为，分别由acquire和release两个方法来实现。针对获取锁这个场景，框架抽象了获取锁上下文AcquireContext，它由框架构建并传递给acquire方法，LockHandler处理获取锁的工作，并返回获取结果AcquireResult。获取结果描述本次获取锁的操作结果，包括：是否获取成功以及获取失败的原因。对于释放锁而言，框架提供了释放锁上下文ReleaseContext，也由框架构建并传递给release方法。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;多个LockHandler会组成获取与释放锁的链路，开发者可以通过扩展LockHandler，以插件的形式将不同的能力集成到框架中。框架默认提供了头和尾两个LockHandler节点，而开发者（或框架）提供的扩展将会穿在这条链路上，该链路如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-framework-chain.png" width="80%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，锁的获取链路会从Head节点开始，将请求传递给链路上所有LockHandler的acquire方法，最终抵达Tail节点，并由Tail节点调用LockRemoteResource的tryAcquire方法，完成远程锁资源的获取。如果链路上的扩展节点需要提前中断获取锁的请求，可以选择不调用AcquireChain的invoke方法，这会将该责任链提前返回。锁的释放链路与获取链路正好相反，由Tail节点开始，先调用LockRemoteResource的release方法完成远程锁资源的释放，然后再逐步前推，直到Head节点。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;任何节点的增加和删除，对于链路上的其他节点而言都是没有影响的，因此锁获取与释放链路的抽象提供了良好的扩展能力，后面会演示如何通过实现LockHandler来扩展框架。

## 基于Redis的实现

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过扩展LockRemoteResource可以实现分布式锁，接下来以Redis作为锁状态的存储，简单起见，可以通过适配Redisson客户端来进行实现。Redisson客户端版本为：3.16.4，Redis服务端版本为：6.2.6。实现主要代码如下：

```java
import io.github.weipeng2k.distribute.lock.spi.AcquireResult;
import io.github.weipeng2k.distribute.lock.spi.LockRemoteResource;
import io.github.weipeng2k.distribute.lock.spi.support.AcquireResultBuilder;
import org.redisson.Redisson;
import org.redisson.api.RLock;
import org.redisson.api.RedissonClient;
import org.redisson.config.Config;
import java.util.concurrent.TimeUnit;
/**
 * <pre>
 * 基于Redis的锁实现
 * </pre>
 *
 * @author weipeng2k 2021年11月12日 下午22:53:20
 */
public class RedissonLockRemoteResource implements LockRemoteResource {
    private final RedissonClient redisson;
    private final int ownSecond;
    public RedissonLockRemoteResource(String address, int ownSecond) {
        Config config = new Config();
        config.useSingleServer()
                .setAddress(address);
        redisson = Redisson.create(config);
        this.ownSecond = ownSecond;
    }
    @Override
    public AcquireResult tryAcquire(String resourceName, String resourceValue, long waitTime,
                                    TimeUnit timeUnit) throws InterruptedException {
        RLock lock = redisson.getLock(resourceName);
        Integer liveSecond = OwnSecond.getLiveSecond();
        long ownTime = timeUnit.convert(liveSecond != null ? liveSecond : ownSecond, TimeUnit.SECONDS);
        AcquireResultBuilder acquireResultBuilder;
        boolean ret = lock.tryLock(waitTime, ownTime, timeUnit);
        acquireResultBuilder = new AcquireResultBuilder(ret);
        if (!ret) {
            acquireResultBuilder.failureType(AcquireResult.FailureType.TIME_OUT);
        }
        return acquireResultBuilder.build();
    }
    @Override
    public void release(String resourceName, String resourceValue) {
        RLock lock = redisson.getLock(resourceName);
        lock.unlock();
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述代码的逻辑主要是将Redisson的RLock适配到LockRemoteResource上。适配逻辑整体上比较简单，在tryAcquire方法实现中，通过Redisson客户端获取RLock，然后将请求委派给RLock的tryLock方法。release的适配更加简单，只需要获取到RLock进行解锁即可。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分布式锁框架使用起来比较简单，直接依赖distribute-lock-redis-spring-boot-starter即可，该starter会装配一个DistributeLockManager到应用的Spring容器中，使用方式如下所示：

```java
@Autowired
private DistributeLockManager distributeLockManager;
@Autowired
private Counter counter;

@Override
public void run(String... args) throws Exception {
    DistributeLock distributeLock = distributeLockManager.getLock("lock_key");
    int times = CommandLineHelper.getTimes(args, 1000);
    DLTester dlTester = new DLTester(distributeLock, 3);
    dlTester.work(times, () -> {
        int i = counter.get();
        i++;
        counter.set(i);
    });

    dlTester.status();
    System.out.println("counter value:" + counter.get());
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述代码的逻辑比较简单，即获取一个名称为lock_key的分布式锁，然后循环1000次操作（或由启动参数指定），每次操作都会尝试加锁（等待时间为3秒），然后获取远程Redis服务端counter的值，自增后再写回。如果这个过程不加锁，多个进程同时执行，就会出现数据覆盖，导致计数的错乱。Redis中的counter已经提前初始化为0，我们用3个客户端进行操作，每个客户端循环100次，这三个客户端的输出分别为：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-redis-client1.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;客户端1输出：获取锁成功200次，失败0次，最终看到counter值为486。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-redis-client2.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;客户端2输出：获取锁成功192次，失败8次，最终看到counter值为592。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-redis-client3.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;客户端3输出：获取锁成功200次，失败0次，最终看到counter值为332。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-redis-server-counter.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;登录到Redis服务端查看counter最终的值尾592，与客户端2的最后输出一致。可以看到基于Redis的分布式锁工作正常，通过分布式锁将原有不安全的逻辑（获取，自增然后写入）进行了保护，使之能够安全运行于分布式环境。

## 扩展：分布式锁访问日志

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分布式锁的获取与释放会涉及到网络通信，所以对每次分布式锁的使用最好能够打印出包含关键信息的日志，比如：获取锁的名称与耗时。通过收集和分析日志，一来可以掌握分布式锁的指标，二来可以为出现的问题进行报警，减小故障修复时间。通过扩展SPI中的LockHandler，可以将打印访问日志的特性植入到分布式锁的使用链路中，并且该过程对使用者透明。扩展的代码如下所示：

```java
import io.github.weipeng2k.distribute.lock.spi.AcquireContext;
import io.github.weipeng2k.distribute.lock.spi.AcquireResult;
import io.github.weipeng2k.distribute.lock.spi.ErrorAware;
import io.github.weipeng2k.distribute.lock.spi.LockHandler;
import io.github.weipeng2k.distribute.lock.spi.ReleaseContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.annotation.Order;

import java.util.concurrent.TimeUnit;

/**
 * <pre>
 * 日志输出Handler，打印获取锁和释放锁的日志
 * </pre>
 *
 * @author weipeng2k 2021年11月27日 下午20:44:18
 */
@Order(1)
public class AccessLoggingLockHandler implements LockHandler, ErrorAware {

    private static final Logger logger = LoggerFactory.getLogger("DISTRIBUTE_LOCK_ACCESS_LOGGER");

    @Override
    public AcquireResult acquire(AcquireContext acquireContext, AcquireChain acquireChain) throws InterruptedException {
        AcquireResult acquireResult = acquireChain.invoke(acquireContext);

        logger.info("acquire|{}|{}|{}|{}", acquireContext.getResourceName(), acquireContext.getResourceValue(),
                acquireResult.isSuccess(),
                TimeUnit.MILLISECONDS.convert(System.nanoTime() - acquireContext.getStartNanoTime(),
                        TimeUnit.NANOSECONDS));

        return acquireResult;
    }

    @Override
    public void release(ReleaseContext releaseContext, ReleaseChain releaseChain) {
        releaseChain.invoke(releaseContext);

        logger.info("release|{}|{}|{}", releaseContext.getResourceName(), releaseContext.getResourceValue(),
                TimeUnit.MILLISECONDS.convert(System.nanoTime() - releaseContext.getStartNanoTime(),
                        TimeUnit.NANOSECONDS));
    }

    @Override
    public void onAcquireError(AcquireContext acquireContext, Throwable throwable) {
        logger.error("acquire|{}|{}|{}|{}", acquireContext.getResourceName(), acquireContext.getResourceValue(),
                false,
                TimeUnit.MILLISECONDS.convert(System.nanoTime() - acquireContext.getStartNanoTime(),
                        TimeUnit.NANOSECONDS), throwable);
    }

    @Override
    public void onReleaseError(ReleaseContext releaseContext, Throwable throwable) {
        logger.error("release|{}|{}|{}", releaseContext.getResourceName(), releaseContext.getResourceValue(),
                TimeUnit.MILLISECONDS.convert(System.nanoTime() - releaseContext.getStartNanoTime(),
                        TimeUnit.NANOSECONDS), throwable);
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述代码通过实现LockHandler的acquire和release方法在分布式锁使用链路上打印日志，可以看到acquire方法实现中，在获取锁结果AcquireResult返回后，打印了获取锁的名称、值、获取是否成功的结果以及耗时（单位毫秒）。释放锁的release方法与acquire类似。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;另外AccessLoggingLockHandler实现了ErrorAware，如果在链路中出现异常，导致中断，则框架会在对应的链路（获取或释放）回调onAcquireError或onReleaseError方法。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在应用中除了依赖分布式锁的starter，再依赖扩展插件的坐标就能激活该插件，用户在日志配置中声明分布式锁的日志目录即可，配置如下：

```xml
<property name="APP_NAME" value="distribute-lock-redis-testsuite"/>
<property name="LOG_PATH" value="${user.home}/logs/${APP_NAME}"/>

<!--分布式锁日志-->
<property name="DISTRIBUTE_LOCK_LOG_DIR" value="${LOG_PATH}/distribute-lock" />
<include resource="io/github/weipeng2k/distribute-lock/distribute-lock-access-log.xml”/>
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到声明DISTRIBUTE_LOCK_LOG_DIR属性为分布式锁的日志目录，而日志将会输出在这个目录中，文件名为：distribute-lock-access.log。启动应用，可以看到日志（部分）输出，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-redis-access-log.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，基于Redis的分布式锁获取和释放过程输出日志，其中获取锁的耗时基本在35毫秒左右，释放锁也差不多是这个数量。
