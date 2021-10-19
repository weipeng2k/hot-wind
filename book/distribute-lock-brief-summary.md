# 分布式锁小结

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在微服务环境中，除了会遇到分布式事务问题，还会有并发控制的需求。在分布式环境下完成并发控制，如果只使用普通的`JUC`锁是无法完成工作的，因此只能依靠分布式锁。`JUC`中的锁主要是解决在一个进程内的访问控制问题，而分布式锁解决的是进程间的，如果将`JUC`中内存操作的指令更换为网络调用是不是就可以实现分布式锁了呢？理论上是的，但是一旦和网络沾边，考虑到网络的不可靠性，就没这么简单了。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock.jpeg">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;接下来，先看一下分布式锁和普通的锁有何不同，然后再详细的讨论两种不同类别的分布式锁，本文最后，需要问自己：**我真的需要使用分布式锁来解决这个问题吗？**

## 锁是什么？

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;锁是一种提供了**排他性**和**可见性**的并发访问控制工具，它保证了在同一时刻，只能有一个访问者可以访问到锁保护的**资源**。锁是我们常用的一种并发访问控制工具，而**排他性**是它功能性最直接的体现，以至于它成为了**排他性**的代名词，但其隐含的**可见性**以及它的**资源状态**往往被我们忽略。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**可见性**表达的是一个访问者对数据（比如：内存中的某个值）做了修改，其他的访问者能够及时发现数据的变化，从而做出相应的行为。这点看起来挺简单，甚至感觉有些理所应当，但如果带入到现代计算机体系结构下，就觉得没这么简单了。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/cpu-cache-memory-model.png">
</center>


## 分布式锁

## 类CAS自旋式

## 事件通知式

## 更进一步
