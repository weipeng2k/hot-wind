# 什么是分布式锁？

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-distribute.jpg">
</center>

## 分布式锁

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分布式锁，顾名思义，就是在分布式环境下使用的锁。它能够提供进程间（当然也包括进程内）的并发控制能力，因此，就功能而言，**分布式锁是可以替代一般（类似`JUC`这种）单机锁的**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分布式锁对于锁资源的申请和占用，如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-concept.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，在一个实例（或进程）中存在多个线程，而多个实例都可以访问资源，访问资源的最小单位是线程，因此分布式锁控制的粒度同单机锁一样。`JUC`单机锁是否能够获取是依靠内存中的状态值来实现的，在本机内存中的状态值称为锁的**资源状态**，如果将内存中锁的资源移动到进程外，对资源进行获取的系统调用换成网络调用，单机锁不就转变成了分布式锁吗？没错，确实如此，但背后隐含了几个问题，就如同单机锁隐含了**可见性**问题一样。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**资源状态**由内到外的移动不会产生任何变化，而系统调用换成网络调用会产生巨大的变化，主要在以下三个方面：性能、超时和可用性问题，而超时问题会进一步引出死锁问题，接下来我们来看看这几个方面。

## 分布式锁的作用

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在分布式环境中，分布式锁可以保证有相同工作的多个节点，在同一时刻只有一个节点能够进行工作。节点的工作一般称为同步逻辑，它可能是一组计算或是对存储（以及外部API）的一些操作。分布式锁是一项比较实用的技术，使用它一般来说会有两个原因：提升效率或确保正确。如果需要在工作中使用到分布式锁，可以尝试问自己一个问题，如果没有分布式锁，会出现什么问题呢？如果是数据错乱，那就是为了确保正确，如果是集群中所有节点重复工作，那就是为了提升效率。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;区分使用分布式锁的原因是很重要的，因为它会让你对锁失败后产生的问题有了明确认识，同时对使用何种技术实现的分布式锁在选型上会考虑的更周全。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;以Redis和ZooKeeper分别实现的分布式锁为例：前者吞吐量高，访问延时小，可用性一般，但实施成本低；后者吞吐量低，访问延时较高，可用性高，但实施成本高。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果使用分布式锁解决效率问题，那么由于偶尔锁失败造成重复计算的问题应该是可以容忍的，这时选择成本低的分布式锁方案会是一个好的选择。如果用分布式锁解决正确性问题，就需要尽可能保证分布式锁的可用性以及正确性，采用高成本的分布式锁实现方式就变得很必要了。
