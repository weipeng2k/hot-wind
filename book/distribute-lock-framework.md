# 分布式锁框架

## 为什么需要分布式锁框架？

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;不同的分布式锁实现（以下简称：**实现**，比如：**Redis**或者**ZooKeeper**），它们之间的性能、可用性和正确性保障以及成本都会有所不同，因此需要提供一种适配多种不同实现方式的分布式锁技术方案（以下简称：**方案**）。虽然分布式锁的实现可以有多种，但是都需要有监控、流控以及热点锁访问优化等特性，所以该方案不仅能够提供给使用者一致的分布式锁**API**，还可以让开发者能够适配不同的分布式锁实现，同时还具备良好的横向功能扩展能力。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-framework-page.jpg">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;既要适配不同的实现方式，又要支持横向扩展，这一纵一横的扩展需求就需要通过设计一个简单的分布式锁框架（以下简称：**框架**）来达成了。该框架，不仅能够提供给使用者一致且简洁的API，而且能够快速适配不同的分布式锁实现，最关键的还可以提供给开发者以横向拦截的方式来扩展分布式锁获取与释放链路（以下简称：**链路**）的能力。

## 分布式锁框架

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这个[**简单框架**](https://github.com/weipeng2k/distribute-lock)组成分为两类，共5个模块。一类是面向使用者的客户端和*starter*，另一类是面向开发者的**SPI**、实现扩展与插件扩展。如果只是想使用分布式锁，那就只需要依赖框架提供的*starter*，前提是应用基于**springboot**构建的。如果想扩展分布式锁的实现或者链路，可以通过实现框架提供的**SPI**以达成目的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;框架中各模块包含的主要组件以及相互关系如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-framework-component.png" width="80%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，使用者通过依赖*starter*将框架引入应用，同时使用客户端来完成分布式锁的创建、获取与释放工作。开发者可以通过扩展**SPI**中的*LockRemoteService*来将不同的实现引入到框架中，同时这些实现会对使用者透明。开发者还可以通过实现**SPI**中的*LockHandler*完成对链路的扩展，这些扩展会以切面的形式嵌入到执行链路中，并且对分布式锁的实现以及使用者透明。

### 分布式锁客户端

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;面向使用者的分布式锁客户端，以工厂模式进行构建，使用者可以通过传入锁名称来获取到对应的分布式锁，并使用之。客户端通过依赖**SPI**将分布式锁实现与客户端分离开，其主要类图如下所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-framework-client-class.png" width="80%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;客户端模块主要定义了分布式锁的接口以及基本实现。分布式锁*DistributeLock*主要定义了两个方法，分别是：获取锁的`tryLock(long waitTime, TimeUnit unit)`和释放锁的`unlock()`。有读者一定会问：为什么没有提供类似**JUC**中的`lock()`方法呢？如果有的话，客户端调用后，会等待获取到锁后才返回，使用起来更加方便。原因是客户端使用分布式锁进行加锁时，实际会在底层会发起网络通信，由于通信的不可靠性，比如：一旦发生阻塞，将会导致长时间的阻塞应用逻辑，这可能未必是用户所期望的。所以明确的在参数中给出获取锁的超时，并要求用户传入，使用户对于获取分布式锁的开销有了更明确的感知。

> 如果要实现类似**JUC**中的`lock()`方法语义，可以通过传入一个较长的等待时间来近似做到。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分布式锁实现*DistributeLockImpl*会将客户端获取锁（以及释放锁）的调用请求委派给**SPI**，由**SPI**中的*LockHandler*来处理。使用者只需要从*DistributeLockManager*中获取锁，然后就可以对锁进行操作，示例代码如下：

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

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述代码表示获取一个名为`lock_name`的分布式锁，然后对其尝试加锁，超时时间为`1`秒。如果`1`秒内能够成功加锁，则执行一段逻辑后进行解锁，如果未能在`1`秒内加锁，则直接返回。

### 分布式锁SPI

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;面向开发者的分布式锁**SPI**，以责任链模式进行构建，开发者可以选择适配不同的实现或者扩展链路。分布式锁**SPI**是框架扩展性的体现，其主要类图如下所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-framework-spi.png" width="80%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**SPI**模块定义了扩展框架所需的相关接口，包含：支持分布式锁实现适配的*LockRemoteResource*和扩展链路的*LockHandler*。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*LockRemoteResource*定义了获取锁资源的两个方法，即：`tryAcquire`和`release`，前者声明在超时时间内对远程锁资源进行获取，并返回获取结果*AcquireResult*，后者声明根据资源名称和值对获取到的资源进行释放。只要具备资源获取和释放的分布式服务，都可以通过适配到*LockRemoteResource*，进而以分布式锁实现的形式集成到框架中。以**Redis**的集成作为一个例子，**Redis**的**String**数据类型，具备键值的存取功能，那就可以将键值视作分布式锁资源，键值新增作为资源获取，键值删除作为资源释放，以此将**Redis**转换为分布式锁实现，从而整合到框架中。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*LockHandler*定义了获取与释放锁的行为，分别由`acquire`和`release`两个方法来实现。框架定义了获取锁上下文*AcquireContext*，它由框架构建并传递给`acquire`方法，*LockHandler*处理获取锁的工作，并返回获取结果*AcquireResult*。获取结果*AcquireResult*主要描述本次获取锁的操作结果，包括：是否获取成功以及获取失败的原因。对于释放锁而言，框架提供了释放锁上下文*ReleaseContext*，也由框架构建并传递给`release`方法。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;多个*LockHandler*会组成分布式锁获取与释放链路，开发者通过扩展*LockHandler*，将实现以插件的形式集成到框架中。框架默认提供了头和尾两个*LockHandler*节点，而开发者（或框架）提供的扩展将会穿在链路上，链路分为获取锁和释放锁两条链路，其中获取锁链路如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-framework-acquire-chain.png" width="80%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，锁的获取链路会从*Head*节点开始，将获取锁上下文*AcquireContext*传递给链路上所有*LockHandler*的`acquire`方法，最终抵达*Tail*节点，并由*Tail*节点调用*LockRemoteResource*的`tryAcquire`方法，完成远程锁资源的获取。如果链路上的扩展节点需要提前中断获取锁的请求，可以选择不调用*AcquireChain*的`invoke`方法，这会使得责任链提前返回。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;锁的释放链路与获取链路相似，如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-framework-release-chain.png" width="80%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，由*Head*节点开始，穿越整条链路，抵达*Tail*节点，由该节点调用*LockRemoteResource*的`release`方法完成远程锁资源的释放。

> 如果在扩展在获取锁链路中，先于*LockRemoteResource*进行了操作，那么在释放锁链路中，推荐在`ReleaseChain#invoke`方法之后进行操作，这样扩展在两条链路上的行为就会对称。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;任何节点的增加和删除，对于链路上的其他节点而言都是没有影响的，因此锁获取与释放链路的抽象提供了良好的扩展能力，后面会演示如何通过实现*LockHandler*来扩展框架。

## 实现：基于**Redis**的分布式锁

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;实现*LockRemoteResource*可以扩展分布式锁实现，接下来以**Redis**作为维护锁资源状态的存储服务，客户端选择[**Lettuce**](https://lettuce.io)，它是一个基于**Netty**的**Redis**客户端，它最大的特点是基于非阻塞**I/O**，能够帮助开发者构建响应式应用，可以很好的替代**Jedis**客户端。

> **Lettuce**版本为：`6.1.2.RELEASE`，**Redis**版本为：`6.2.6`。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Redis**的分布式锁实现*RedisLockRemoteResource*会在[拉模式的分布式锁](https://weipeng2k.github.io/hot-wind/book/distribute-lock-spin-impl.html)中详细介绍，现在只需要知道它通过**5**个参数来进行构建，参数名、类型与描述如下表所示：

|参数名|类型|描述|
|----|----|----|
|`address`|**String**|**Redis**服务端地址|
|`timeoutMillis`|**int**|访问**Redis**的超时（单位：毫秒）|
|`ownSecond`|**int**|占据键值的时间（单位：秒）|
|`minSpinMillis`|**int**|自旋最小时间（单位：毫秒）|
|`randomMillis`|**int**|自旋随机增加的时间（单位：毫秒）|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Lettuce**客户端通过`address`与**Redis**建立长链接。在获取锁时，会尝试新增一个键值，如果新增失败，将会选择睡眠一段时间（时长为：`minSpinMillis + new Random().nextInt(randomMillis)`），醒后再试。如果新增成功，则代表实例成功获取到锁，同时该键值的存活时间为`ownSecond`，在存活时间内实例需要执行完同步逻辑，否则就会出现正确性被违反的风险。

### Redis分布式锁Starter

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于分布式锁框架的使用者而言，可能不希望关注这么多细节，只需要提供一个**Redis**服务器地址，然后添加一下依赖和配置就可以跑起来，那就最好不过了。**SpringBoot**提供了良好的扩展与集成能力，只需要提供相应的**starter**，就可以让使用者获得这种极致的使用体验。

> 该**starter**在子项目*distribute-lock-redis-spring-boot-starter*中。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Redis**分布式锁的**starter**主要包含了一个**Spring**配置，其主要代码如下所示：

```java
@Configuration
@ConditionalOnProperty(prefix = Constants.PREFIX, name = "address")
@ConditionalOnClass(RedisLockRemoteResource.class)
@EnableConfigurationProperties(RedisProperties.class)
@Import(CommonConfig.class)
public class DistributeLockRedisAutoConfiguration implements EnvironmentAware {

    private Environment environment;

    @Bean("redisLockRemoteResource")
    public LockRemoteResource lockRemoteResource() {
        Binder binder = Binder.get(environment);
        BindResult<RedisProperties> bindResult = binder.bind(Constants.PREFIX,
                Bindable.of(RedisProperties.class));
        RedisProperties redisProperties = bindResult.get();

        return new RedisLockRemoteResource(redisProperties.getAddress(), redisProperties.getOwnSecond(),
                redisProperties.getMinSpinMillis(), redisProperties.getRandomMillis());
    }

    @Bean("redisLockHandlerFactory")
    public LockHandlerFactory lockHandlerFactory(@Qualifier("lockHandlerFinder") LockHandlerFinder lockHandlerFinder,
                                                 @Qualifier("redisLockRemoteResource") LockRemoteResource lockRemoteResource) {
        return new LockHandlerFactoryImpl(lockHandlerFinder.getLockHandlers(), lockRemoteResource);
    }

    @Bean("redisDistributeLockManager")
    public DistributeLockManager distributeLockManager(
            @Qualifier("redisLockHandlerFactory") LockHandlerFactory lockHandlerFactory) {
        return new DistributeLockManagerImpl(lockHandlerFactory);
    }

    @Override
    public void setEnvironment(Environment environment) {
        this.environment = environment;
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于在`META-INF/spring.factories`配置中声明了*DistributeLockRedisAutoConfiguration*，所以**Spring**容器能够扫描并识别**Redis**分布式锁的配置，并装配三个**Bean**到使用者的**Spring**容器中，如下表所示：

|BeanName|类型|描述|
|----|----|----|
|`redisLockRemoteResource`|*LockRemoteResource*|从当前应用的环境中解析配置，装配一个类型为分布式锁实现的**Bean**|
|`redisLockHandlerFactory`|*LockHandlerFactory*|依赖`redisLockRemoteResource`，装配一个类型为*LockHandlerFactory*的**Bean**，目的是提供给分布式锁**API**获取*LockHandler*的能力|
|`redisDistributeLockManager`|*DistributeLockManager*|使用者直接依赖该**Bean**，提供分布式锁获取与使用的功能|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于配置被**ConditionalOnProperty**注解修饰，使用者除了依赖该**starter**，还需要在`application.properties`中声明键为`spring.distribute-lock.redis.address`的配置，如果没有声明该配置，该**starter**就不会装配上述三个**Bean**到容器中。

> **Constants**定义了常量`PREFIX`，值为：`spring.distribute-lock.redis`

### 使用分布式锁框架

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;该框架使用起来比较简单，通过依赖*distribute-lock-redis-spring-boot-starter*，然后在`application.properties`中如下配置：

```sh
spring.distribute-lock.redis.address=redis服务端地址，比如：redis://ip:port
spring.distribute-lock.redis.own-second=可选，默认10，表示键值的过期时间，单位：秒
spring.distribute-lock.redis.min-spin-millis=可选，默认10，表示自旋等待的最小时间，单位：毫秒
spring.distribute-lock.redis.random-millis=可选，默认10，表示自旋等待随机增加的时间，单位：毫秒
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;依赖坐标并声明配置后，该*starter*会装配一个*DistributeLockManager*到应用的**Spring**容器中，使用示例如下所示：

```java
@Autowired
@Qualifier("redisDistributeLockManager")
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

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述代码示例，尝试获取一个名称为`lock_key`的分布式锁，然后循环`1000`次（或由启动参数指定次数的）操作，每次操作都会尝试加锁（等待锁的时间为3秒），加锁成功后，获取远程**Redis**服务端`counter`的值，自增后再写回。获取-计算-写回，这个过程如果不加锁，在多进程（或并发）环境中，就会出现数据覆盖的可能，从而导致计数的错乱。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Redis**中的`counter`已经提前初始化为`0`，我们用`3`个客户端进行操作，每个客户端循环`100`次，客户端的输出分别为：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-redis-client1.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**客户端1**输出：获取锁成功`200`次，失败`0`次，最终看到`counter`值为`486`。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-redis-client2.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**客户端2**输出：获取锁成功`192`次，失败`8`次，最终看到`counter`值为`592`。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-redis-client3.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**客户端3**输出：获取锁成功`200`次，失败`0`次，最终看到`counter`值为`332`。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-redis-server-counter.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;登录到**Redis**服务端查看`counter`的最终值为`592`，它与**客户端2**的输出一致。可以看到基于**Redis**的分布式锁能够正常工作，将原有线程不安全的逻辑进行了保护，使之能够安全的运行于分布式环境中。

## 扩展：分布式锁访问日志

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分布式锁的获取与释放会涉及到网络通信，所以该过程需要添加监控，最简单的方式是对每次分布式锁的使用打印日志，日志内容可以是获取与释放锁的关键信息，比如：锁的名称与耗时等。通过收集和分析日志，一来可以掌握分布式锁的数据指标，二来可以为可能出现的问题进行报警，缩短故障反应时间。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过扩展**SPI**中的*LockHandler*，可以将打印访问日志的特性植入到链路中，并且该过程对使用者和锁实现透明。扩展的代码如下所示：

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

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述代码通过实现*LockHandler*的`acquire`和`release`方法在分布式锁使用链路上打印日志，可以看到`acquire`方法实现中，在获取锁结果*AcquireResult*返回后，打印了获取锁的名称、值、获取是否成功的结果以及耗时（单位毫秒）。释放锁的`release`方法与`acquire`实现类似。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;另外*AccessLoggingLockHandler*实现了*ErrorAware*，如果在链路中出现异常，导致链路提前中断，则框架会在对应的（获取或释放）链路回调`onAcquireError`或`onReleaseError`方法。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在应用中除了依赖分布式锁的*starter*，再依赖扩展插件的坐标就能激活日志打印插件。由于锁的日志打印频繁，推荐将该日志同应用日志分开，所以插件提供了日志文件片段，便于用户使用。用户可以选择在日志配置中声明分布式锁的日志目录即可，配置如下：

> 日志系统选用的是**logback**。

```xml
<property name="APP_NAME" value="distribute-lock-redis-testsuite"/>
<property name="LOG_PATH" value="${user.home}/logs/${APP_NAME}"/>

<!--分布式锁日志-->
<property name="DISTRIBUTE_LOCK_LOG_DIR" value="${LOG_PATH}/distribute-lock" />
<include resource="io/github/weipeng2k/distribute-lock/distribute-lock-access-log.xml”/>
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到在应用日志配置中，声明*DISTRIBUTE_LOCK_LOG_DIR*属性为分布式锁的日志目录，而锁访问日志将会输出在该目录中的：*distribute-lock-access.log*文件中。启动应用，然后使用分布式锁，可以看到（部分）日志输出，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-redis-access-log.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，基于**Redis**的分布式锁在获取与释放过程中会打印出访问日志，可以看到，其中获取锁的耗时基本在`35`毫秒左右，而释放锁也差不多是这个量级。

> **Redis**部署在公有云，因此延迟比较大，实际在真实生产环境中会好很多。
