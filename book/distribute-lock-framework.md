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

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分布式锁实现DistributeLockImpl会将客户端获取锁（以及释放锁）的调用请求委派给SPI，由SPI中的LockHandler来处理。

### 分布式锁SPI

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;面向开发者的分布式锁SPI，以责任链模式进行构建，开发者可以扩展不同的分布式锁实现以及拦截分布式锁获取与释放链路。分布式锁SPI是框架扩展的体现，其主要类图如下所示：
