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
