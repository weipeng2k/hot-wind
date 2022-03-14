# StampedLock简介

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/juc-summary/juc-stampedlock-summary.jpg">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`StampedLock`是**Java8**引入的一款锁，在功能层面与`ReentrantReadWriteLock`（以下简称：`RRWLock`）相似，它被定义为内部工具类，用来创建其他的线程安全组件。**Stamp**意为邮戳，而使用`StampedLock`获取锁时会返回一个邮戳，这个邮戳是对锁状态的一个快照摘要，当后续操作锁（比如释放锁）时，就需要传入先前获取的邮戳，而`StampedLock`会验证邮戳与当前锁状态，假设二者能够匹配，则表示操作是线程安全的，否则就可能存在并发安全问题。可以看到，邮戳的出现，使得`StampedLock`的使用方式不同于原有`Lock`，以获取写锁为例，使用方式如下所示：

```java
StampedLock stampedLock = new StampedLock();
long stamp = stampedLock.writeLock();
try {
    // 写操作的同步逻辑
} finallY {
    stampedLock.unlockWrite(stamp);
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上述代码所示，调用`writeLock()`方法会获取写锁，如果此时写锁或读锁已被获取，则该方法会阻塞，最终会返回一个邮戳`stamp`，当执行完写操作的同步逻辑后，在释放锁时需要传入先前获取的邮戳。由于使用方式与`Lock`不同，所以`StampedLock`没有直接实现`Lock`或者`ReadWriteLock`接口，但是出于简化使用考虑，还是提供了一些视图方法，比如：`asReadLock()`、`asWriteLock()`以及`asReadWriteLock()`，让开发者以熟悉的方式来操作而不用去了解邮戳的概念。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`StampedLock`有三种模式用来获取锁，分别是：读模式、写模式和乐观读模式，前两者与`RRWLock`中的读和写功能相似，而乐观读模式很特别，它不会阻塞写锁的获取，可以被看作是读模式的一个弱化版本。如果**线程A**获取了乐观读锁，在此过程中**线程B**获取了写锁，**线程A**是可以感知到锁的变化，并需要进行重试来避免使用到过期的数据。乐观读模式在读多写少的情况下表现的很好，因为它能减少竞争并提升吞吐量，但使用起来比较麻烦，获取乐观读锁后会得到邮戳，同步逻辑将需要访问的字段读取到本地变量，然后再通过`validate(long stamp)`方法验证通过后，方可以使用，如果验证失败，需要进行重试。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`StampedLock`并没有基于同步器`AbstractQueuedSynchronizer`来实现，而是选择了自定义类似**CLH**队列的变体，基于其全新的状态和队列设计，优化了读锁和写锁的访问，相比`RRWLock`，在性能方面有了很大提升。在读多写少的场景下，`RRWLock`往往会造成写线程的**“饥饿”**，而`StampedLock`的队列设计采用了一种相对公平的排队策略，使得该问题得以缓解，同时在队列首节点引入随机的自旋，有效的减少了（日益昂贵的）上下文切换。`RRWLock`仅支持写锁降级为读锁，`StampedLock`则能够做到读锁和写锁之间的相互转换，但它不支持重入和`Condition`，并且有特定的编程方式，如果使用不当，会导致死锁或其他诡异问题。
