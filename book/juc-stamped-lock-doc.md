# JUC中的StampedLock文档

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`StampedLock`是**Java8**新增的并发控制装置，它虽然是一个锁，但是没有实现`Lock`接口，在读多写少的场景下，它能够提供比`ReentrantReadWriteLock`更好的吞吐量。它的文档挺多，目前没有看到很好的翻译，这里我就做一下这个工作。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/juc-summary/stamped-lock-banner.jpg">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;以下是笔者对这篇文章的（摘录）翻译和理解。如果是笔者的理解将会以![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png)来开头，以引言的形式来展示，比如：

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 这个是作者的理解。。。
>
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;描述内容示例。。。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;一个基于功能的锁，它使用三种模式来控制读写访问。`StampedLock`的状态由版本和模式组成。获取锁的方法会返回一个邮戳，该邮戳用来表示锁的状态，同时在后续对锁的访问控制做出更改时，需要依赖该邮戳，而这些访问控制以**try**开头的方法，如果接受邮戳后返回一个**0**，则表示控制访问失败。释放和转换锁的方法都需要依赖传入邮戳，如果邮戳与锁的状态不一致，操作会失败返回。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 邮戳相当于一个印章，是对当前状态的一个摘要，如果邮戳发生变化，与系统新生成的邮戳不一致，这代表系统发生了变化。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;三种模式分别是：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;写模式。调用`writeLock`方法获取写锁，可能会由于排他访问而阻塞，该方法会返回一个邮戳，同时也就获取到了写锁，当同步逻辑操作完成，使用`unlockWrite`进行解锁时，需要用到它。具备获取超时的`tryWriteLock`方法也有提供，当锁的状态为写模式，没有读锁可以被获取，同时所有乐观读锁的验证都会返回失败。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png)  `writeLock`与`writeLockInterruptibly`都是获取写锁，同时后者会响应中断。
>
> 乐观读锁的验证针对的是乐观读锁的操作步骤，获取乐观读锁后，在实际使用数据时，需要进行验证，这种两步走的操作方式基于读多于写的前提，提供更高的并发访问能力

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;读模式。调用`readLock`方法获取读锁，可能会由于非排他访问而阻塞，该方法会返回一个邮戳，可以用来调用`unlockRead`进行解锁。具备获取超时的`tryReadLock`方法也有提供。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;乐观读模式。当锁没有处于写模式时，方法`tryOptimisticRead`会返回一个非0的邮戳，方法`validate`可以用来验证邮戳，如果获取邮戳后到验证前，锁没有进入过写模式，验证方法会返回**true**。该模式可以被看作是读模式的一个极度弱化的版本，只要有写操作，它就会被打破。乐观读模式在简短只读的代码片段上表现更好，因为它能减少竞争并提升吞吐量。但是乐观读用起来比较的凌乱，乐观读部分的代码只能将需要访问的字段读取存放到本地变量，然后再通过`validate`方法验证完成后，方可以使用。在乐观读模式下读取的数据可能非常不一致，需要使用者对数据非常清楚，并且通过反复调用`validate`方法进行验证。例如：当读取到对象或者数组时，在访问其字段、元素或者方法时，就需要使用这些步骤。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png)  通过获取乐观读锁后，需要将数据保存到本地变量，然后在使用数据前，需要进行`validate`，只有`validate`通过，方能继续使用，也就是说这段时间数据的确没有写访问。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`StampedLock`也提供了有条件的模式转换方法。例如，`tryConvertToWriteLock`方法可以完成模式的升级，也就是转换到写模式，需要锁处于以下条件：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（1）已经处于写模式；<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（2）在读模式中，但是当前没有其他的读取线程；<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（3）在乐观读模式中，并且（写）锁可以被获取。<br>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这些Convert类型的方法被设计用来减少用户手写重试转换的代码。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 不仅有`tryConvertToWriteLock`的升级方法，也有转换到读或者乐观读的降级方法。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`StampedLock`是个被设计用来构筑线程安全组件的内部工具。想使用好`StampedLock`，首先需要了解想用锁保护的数据、对象和方法实现，它是不支持重入的，所以在同步逻辑中如果调用当前类的其他方法，开发者需要确认该方法的实现没有获取锁的行为。读模式的正确性是依赖于同步逻辑没有副作用，乐观读模式下，如果没有进行验证，就不要调用无法容忍潜在不一致性的方法。邮戳的表达是有限的，并且没有进行加密，使用者可以进行邮戳的猜测和尝试。邮戳会在一年后回收，如果获取了邮戳，长时间不使用或者验证，那么很可能在时间到达后，无法进行使用和正确验证。`StampedLock`实现了序列化接口，但是它反序列化时，锁的状态会被初始化，因此想用它来实现远程分布式锁是不可能的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`StampedLock`像`Semaphore`，而不像其他的`Lock`实现，它对（线程）所有者没有所有权的概念，同时它可以由一个线程获取后，由另一个线程释放或者转换。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`StampedLock`的调度策略没有总是喜欢读或者写，反之亦然。所有**try**开头的方法都会尽最大努力来完成，而并不一定符合任何调度或者公平策略。任何调用**try**开头方法进行锁的获取或者转换的方法，如果返回的邮戳为**0**，这个返回并不会代表锁的任何信息，而后续的调用尝试可能会成功。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;因为`StampedLock`可以实现多种类型的锁，所以该类没有直接实现`Lock`或者`ReadWriteLock`接口。出于方便而言，`StampedLock`提供了一些视图方法，比如：`asReadLock`、`asWriteLock`以及`asReadWriteLock`，提供给使用者以简化的方式。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;下面演示了一个平面点的抽象`Point`类，通过演示该示例可以了解该类的使用方式以及一些约定。

```java
import java.util.concurrent.locks.StampedLock;

/**
 * @author weipeng2k 2022年02月13日 下午22:39:49
 */
public class Point {
    private final StampedLock sl = new StampedLock();
    private double x, y;

    // 排他的锁定方法
    void move(double deltaX, double deltaY) {
        long stamp = sl.writeLock();
        try {
            x += deltaX;
            y += deltaY;
        } finally {
            sl.unlockWrite(stamp);
        }
    }

    // 只读方法
    // 如果乐观读失效，将会晋升到读模式
    double distanceFromOrigin() {
        long stamp = sl.tryOptimisticRead();
        try {
            for (; ; stamp = sl.readLock()) {
                if (stamp == 0L) {
                    continue;
                }
                // possibly racy reads
                double currentX = x;
                double currentY = y;
                if (!sl.validate(stamp)) {
                    continue;
                }
                return Math.hypot(currentX, currentY);
            }
        } finally {
            if (StampedLock.isReadLockStamp(stamp)) {
                sl.unlockRead(stamp);
            }
        }
    }

    // 从乐观读升级到写
    void moveIfAtOrigin(double newX, double newY) {
        long stamp = sl.tryOptimisticRead();
        try {
            for (; ; stamp = sl.writeLock()) {
                if (stamp == 0L) {
                    continue;
                }
                // possibly racy reads
                double currentX = x;
                double currentY = y;
                if (!sl.validate(stamp)) {
                    continue;
                }
                if (currentX != 0.0 || currentY != 0.0) {
                    break;
                }
                stamp = sl.tryConvertToWriteLock(stamp);
                if (stamp == 0L) {
                    continue;
                }
                // exclusive access
                x = newX;
                y = newY;
                return;
            }
        } finally {
            if (StampedLock.isWriteLockStamp(stamp)) {
                sl.unlockWrite(stamp);
            }
        }
    }

    // 从读升级到写
    void moveIfAtOrigin2(double newX, double newY) {
        long stamp = sl.readLock();
        try {
            while (x == 0.0 && y == 0.0) {
                long ws = sl.tryConvertToWriteLock(stamp);
                if (ws != 0L) {
                    stamp = ws;
                    x = newX;
                    y = newY;
                    break;
                } else {
                    sl.unlockRead(stamp);
                    stamp = sl.writeLock();
                }
            }
        } finally {
            sl.unlock(stamp);
        }
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;算法笔记：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;该类的设计采用了顺序锁以及有序读写锁，前者被应用在**Linux**的内核中，可以参考**Lameter**的论文：[http://www.lameter.com/gelato2005.pdf](http://www.lameter.com/gelato2005.pdf)，以及其他地方，**Boehm**的文章：[http://www.hpl.hp.com/techreports/2012/HPL-2012-68.html](http://www.hpl.hp.com/techreports/2012/HPL-2012-68.html)，后者可以参考**Shirako**的文章：[http://dl.acm.org/citation.cfm?id=2312015](http://dl.acm.org/citation.cfm?id=2312015)。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从概念上讲，锁的状态的特定位（`long`类型的第**8**位）为真时，表示存在写锁，而该位为假时，表示不存在写锁。对于读的状态在验证乐观读时会被忽略，因为`StampedLock`使用了一个较小且有限的数（`long`类型的前**7**位，也就是**127**个）来保存读状态，或者是存在的读数量，当超过该界限(`RBITS`，也就是**127**）的读继续出现时，会使用一个`int`类型的`readerOverflow`来保存。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**StampedLock**使用了一个**CLH**队列的变体来处理等待获取锁的请求，**CLH**队列在**AbstractQueuedSynchronizer**中使用过，对于等待的读或者写请求，都会以节点的形式进入到队列中。**StampedLock**中对于读请求会汇聚到一起，以节点中的`cowait`字段来连接。队列结构由于其功能诉求，不需要节点的编号，每个新进入的节点只需要连接到它的前驱上即可。特别的，该类使用了阶段公平且反冲突的原则：如果当前读锁被获取，且同步队列中有一个写请求排队，此时新进入的读请求将会排队。（这个规则可以从`acquireRead`的复杂实现中看出端倪，如果没有这个规则，锁将会变得非常不公平）。释放读锁的方法不会唤醒等待的`cowaiter`，它会由唤醒节点对应的线程来完成。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这些规则适用于实际排队的线程。所有`tryLock`形式的方法，会投机的获取锁，而不去遵循这些规则，看起来会增加冲突。随机的自旋被用来减少（日益昂贵的）上下文切换，同时避免多个线程之间的内存抖动。`StampedLock`会在队列的头部进行自旋尝试，如果一个被唤醒的线程再次获取锁失败了，那么很可能另一个线程通过`tryLock`的形式刚好获取到了锁，这种冲突竞争的形式会通过自旋升级来应对，获取锁失败后，将自旋的上限提升到`MAX_HEAD_SPINS`，避免当前线程在面对持续可能出现的冲突时处于下风。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;几乎所有这些机制都会在`acquireWrite`和`acquireRead`方法中展示出来，其中这些操作和重试都依赖于一致的本地缓存变量。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 代码中对于状态没有直接的使用，而是尝试载入到本地变量后，再用一致的逻辑加以判断或者使用，仅在**CAS**设置时会与状态变量进行交互。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如之前**Boehm**的论文提到的，序列（或者说邮戳）的验证（也就是`validate`方法）需要比`volatile`提供更加严格的顺序保障。为了确保验证，`StampedLock`在`validate`方法中使用了`acquireFence`。人们不期望看到**CAS**操作被重排序，因为这里存在控制流的依赖或者说先后顺序，但这些在理论上是可能存在的，因此`StampedLock`通过在**CAS**操作后添加`storeStoreFence`来进行保障。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;内存布局将锁状态和队列指针放在一起（通常在同一缓存行上），对于读来说是非常适合的。
