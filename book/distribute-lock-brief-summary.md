# 分布式锁

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在微服务环境中，除了会遇到分布式事务问题，还会有并发控制的需求。在分布式环境下完成并发控制，如果只使用普通的`JUC`锁是无法完成工作的，因此只能依靠分布式锁。`JUC`中的锁主要是解决在一个进程内的访问控制问题，而分布式锁解决的是进程间的，如果将`JUC`中内存操作的指令更换为网络调用是不是就可以实现分布式锁了呢？理论上是的，但是一旦和网络沾边，考虑到网络的不可靠性，就没这么简单了。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock.jpeg">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;笔者通过一系列的文章来讨论分布式锁，寄期望为这个话题画上休止符。在正式开始之前会通过[锁是什么？](https://weipeng2k.github.io/hot-wind/book/distribute-lock-what-is-lock.html)介绍一下锁的主要特性，特别是可见性，这个容易被忽略的特性。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分布式锁和锁有什么异同之处呢？[分布式锁是什么？](https://weipeng2k.github.io/hot-wind/book/distribute-lock-what-is-distribute-lock.html)会简要的带着读者走一遍。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;开发一个分布式锁不难，但是会有[很多问题需要解决](https://weipeng2k.github.io/hot-wind/book/distribute-lock-problem.html)，当看到这些问题的时候，你还会觉得简单吗？然后笔者设计开发了一个[分布式锁框架](https://github.com/weipeng2k/distribute-lock)，有[文章](https://weipeng2k.github.io/hot-wind/book/distribute-lock-framework.html)会介绍它的设计与使用方式。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;基于该框架，将[**Redis**](https://weipeng2k.github.io/hot-wind/book/distribute-lock-spin-impl.html)和[**ZooKeeper**](https://weipeng2k.github.io/hot-wind/book/distribute-lock-event-impl.html)可以快速的整合入框架，并且该框架具备良好的扩展能力。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Redis**是最常用来做分布式锁的底层实现了，但是围绕它做分布式锁的问题，[**Salvatore Sanfilippo**](http://antirez.com)和[**Martin Kleppmann**](https://martin.kleppmann.com)，一个是**Redis**的作者，一个是分布式专家，两个人吵了一架，他们撕逼的文章笔者做了翻译和注释，有兴趣的可以看一下。

> [使用Redis实现分布式锁](https://weipeng2k.github.io/hot-wind/book/distribute-lock-with-redis.html)，第一篇，**Salvatore**教大家如何使用使用**Redis**做分布式锁。
>
> [如何实现分布式锁](https://weipeng2k.github.io/hot-wind/book/distribute-lock-how-to-do-it.html)，第二篇，**Martin**怼**Salvatore**的文章，表示你的姿势不对。
>
> [Redlock能保证锁的正确性吗？](https://weipeng2k.github.io/hot-wind/book/distribute-lock-is-redlock-safe.html)，第三篇，**Salvatore**回怼的文章，表示自己没有问题。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，分布式锁实现起来不是那么容易，连大神们都会吵起来。不过，我是支持**Martin Kleppmann**的，你呢？理想是美好的，但现实总不会完美，因此需要结合自己的场景来实现和使用分布式锁。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;最后，需要问自己：[**我真的需要使用分布式锁来解决这个问题吗？**](https://weipeng2k.github.io/hot-wind/book/distribute-lock-another-way.html)
