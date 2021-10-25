# 分布式锁

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在微服务环境中，除了会遇到分布式事务问题，还会有并发控制的需求。在分布式环境下完成并发控制，如果只使用普通的`JUC`锁是无法完成工作的，因此只能依靠分布式锁。`JUC`中的锁主要是解决在一个进程内的访问控制问题，而分布式锁解决的是进程间的，如果将`JUC`中内存操作的指令更换为网络调用是不是就可以实现分布式锁了呢？理论上是的，但是一旦和网络沾边，考虑到网络的不可靠性，就没这么简单了。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock.jpeg">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;接下来，先看一下分布式锁和普通的锁有何不同，实现分布式锁需要注意哪些问题，然后再详细的讨论两种不同类别的分布式锁。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;最后，需要问自己：**我真的需要使用分布式锁来解决这个问题吗？**
