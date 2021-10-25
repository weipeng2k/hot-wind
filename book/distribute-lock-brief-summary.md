# 分布式锁小结

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在微服务环境中，除了会遇到分布式事务问题，还会有并发控制的需求。在分布式环境下完成并发控制，如果只使用普通的`JUC`锁是无法完成工作的，因此只能依靠分布式锁。`JUC`中的锁主要是解决在一个进程内的访问控制问题，而分布式锁解决的是进程间的，如果将`JUC`中内存操作的指令更换为网络调用是不是就可以实现分布式锁了呢？理论上是的，但是一旦和网络沾边，考虑到网络的不可靠性，就没这么简单了。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock.jpeg">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;接下来，先看一下分布式锁和普通的锁有何不同，然后再详细的讨论两种不同类别的分布式锁，本文最后，需要问自己：**我真的需要使用分布式锁来解决这个问题吗？**

## 锁是什么？

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;锁是一种提供了**排他性**和**可见性**的并发访问控制工具，它保证了在同一时刻，只能有一个访问者可以访问到锁保护的**资源**。锁是我们常用的一种并发访问控制工具，而**排他性**是它功能性最直接的体现，以至于它成为了**排他性**的代名词，但其隐含的**可见性**以及它的**资源状态**往往被我们忽略。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**可见性**表达的是一个访问者对数据（比如：内存中的某个值）做了修改，其他的访问者能够及时发现数据的变化，从而做出相应的行为。这点看起来挺简单，甚至感觉有些理所应当，但如果带入到现代计算机体系结构下，就觉得没这么简单了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;CPU和内存之间是有缓存的，这个缓存一般封装在CPU上，每个CPU核心同缓存进行沟通，当缓存无法命中时，才会将内存中的数据载入到缓存中，再进行处理。封装在CPU内的缓存目的是离CPU核心更近，因为对它的访问时间一般在1纳秒左右，而对内存的访问时间一般在100纳秒左右。这个过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/cpu-cache-memory-model.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于存在访问时长的差距，缓存的目的是让数据相对于CPU核心而言，更加就近，这也使得这种架构存在可见性的问题。比如：一个值在内存中是A，由于程序是多线程执行，导致在某个CPU缓存中的值是旧值B，这时就是可见性问题了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果要解决这个问题，就需要程序能够在需要访问值之前，先作废掉CPU上的缓存，从内存中加载最新的数据，同样也需要在数据变更后，将值显式的刷回内存。而锁就具有这个特性，锁能够完成**排他性**工作，同时它也隐含的完成了**可见性**这个工作。当我们使用锁的时候，程序会执行系统指令，将CPU中的缓存作废，然后载入内存中的最新数据，现在通过一个示例来看一下。

```java
public class NoVisibilityTest {
	private static boolean ready;
	private static int number;

	private static class ReaderThread extends Thread {

		public void run() {
			while (!ready) {
			}
			System.out.println(number);
		}
	}

	public static void main(String[] args) throws Exception {
		// 获取Java线程管理MXBean
		ThreadMXBean threadMXBean = ManagementFactory.getThreadMXBean();

		IntStream.range(0, 15)
				.forEach( i -> {
					ReaderThread readerThread = new ReaderThread();
					readerThread.setName("Reader:" + i);
					readerThread.start();
				});

		number = 42;
		ready = true;


		for (int i = 0; i < 20; i++) {
            System.err.println("=============" + (i + 1) + "===============");
			// 不需要获取同步的monitor和synchronizer信息，仅仅获取线程和线程堆栈信息
			ThreadInfo[] threadInfos = threadMXBean.dumpAllThreads(false, false);
			// 遍历线程信息，仅打印线程ID和线程名称信息
			for (ThreadInfo threadInfo : threadInfos) {
				System.out.println("[" + threadInfo.getThreadId() + "] "
						+ threadInfo.getThreadName() + ", status:" + threadInfo.getThreadState());
			}

			Thread.sleep(1000);

		}
	}
}

```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这个程序首先定义了两个静态变量，然后启动了15个线程进行执行，执行策略是如果发现`ready`为`true`，则退出循环，打印并结束。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果不存在**可见性**问题，自定义线程应该可以很快发现`ready`值被修改，然后跳出死循环，最终退出。但实际情况会是这样吗？运行程序后，观察不同批次的线程打印信息，这里截取最后几个批次，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/visible-variable-problem.png" width="50%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到最后一批（也就是第20批）打印的线程内容，之前创建的`ReaderThread`大部分都存活着，它们都对`ready`值的变化视而不见吗？其实它们不是看不见，它们只是盯着缓存中的值去看，对内存中值的变化不清楚罢了。线程运行在CPU核心上，在线程执行时，将值从内存载入到缓存中，依照缓存中的值来运行。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;那什么时候，执行的线程才会从内存中获取最新的数据呢？有一种简单的做法是使用`volatile`关键字来修饰`ready`变量，当然还可以等执行的线程被操作系统交换出去后。当线程下一次被调度时，会从内存中获取数据并恢复缓存，这时该线程有几率能够恢复过来。除此之外，还有别的方式吗？有的，使用锁。因为锁的**资源状态**在内存中，需要保证访问锁的线程能够正确看到锁背后的**资源**。基于这个前提，我们通过使用一个**无意义**的锁来获得**可见性**，这里提到的**无意义**是指没有发挥出锁的**排他性**。我们只需要对示例做出一些修改：

```java
private static class ReaderThread extends Thread {

    public void run() {
        while (!ready) {
            Lock lock = new ReentrantLock();
            lock.lock();
            try {

            } finally {
                lock.unlock();
            }
        }
        System.out.println(number);
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到上述修改只是在`ReaderThread`的死循环中，创建了一个`ReentrantLock`，在这个临时的锁上做了`lock`。如果从功能角度上看这个修改，实际一点作用都没有，但是我们运行这个程序，会看到以下结果。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/lock-protect-visible.png" width="50%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;线程读到了内存中的值，它们安全的退出了，这就是锁**可见性**的体现，它保证在锁保护的代码块中，能够看到最新的值，不论是锁的**资源状态**，还是数据变量。在使用锁时，会通过系统指令将CPU上的缓存作废，以期望获取到内存中的值，而作废的内容不止是**资源状态**，而是整块缓存，因此变相的使得线程获取到了最新的`ready`值。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，锁是依靠**可见性**的保障来看清楚**资源状态**，并在此基础之上封装出能够提供**排他性**语义的并发控制装置。我们在使用锁功能的同时，也会间接的享受到它对于**可见性**的确保。

## 分布式锁

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分布式锁，顾名思义，就是在分布式环境下使用的锁。它能够提供进程间的并发控制，当然也包括在一个进程内的并发控制，因此，就功能而言，狭义上讲，**分布式锁是可以替代一般`JUC`这种单机锁的**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分布式锁对于锁资源的申请和占用，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-concept.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，在一个实例（或进程）中存在多个线程，而多个实例都可以访问资源，访问资源的最小单位是线程，因此分布式锁控制的粒度同单机锁一样。`JUC`单机锁是否能够获取是依靠内存中的状态值来实现的，在本机内存中的状态值称为锁的**资源状态**，如果将内存中锁的资源移动到进程外，对资源进行获取的系统调用换成网络调用，单机锁不就转变成了分布式锁吗？没错，确实如此，但背后隐含了几个问题，就如同单机锁隐含了**可见性**问题一样。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**资源状态**由内到外的移动不会产生任何变化，而系统调用换成网络调用会产生巨大的变化，主要在以下三个方面：性能、超时和可用性问题，而超时问题会进一步引出死锁问题，接下来我们来看看这几个方面。

### 性能问题

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;不论是单机锁还是分布式锁，在实现锁时，都需要获取锁的**资源状态**，然后进行比对，如果是单机锁，那需要读入保存在内存中的值，如果是分布式锁，则需要网络一来一回请求远端的值。这链路的变化，导致性能会出现巨大差异，我们可以通过看一下该图来理论分析一下存在的性能差距。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/access-equipment-speed.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;该图参考自**Jeff Dean**发表的 *《Numbers Everyone Should Know》* 2020版。通过观察该图可以发现，访问CPU的缓存是在纳秒级别，访问内存在百纳秒级别，而在一个数据中心内往返一次在百微秒级别，而一旦跨数据中心将会到达百毫秒级别。从访问不同的设备的延迟可以看到，如果是单机锁，它能提供纳秒级别的延迟，而如果是分布式锁，延迟会在上百微秒也可能在毫秒级别，二者的差距至少存在上千倍。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果网络变得更快会不会提升分布式锁的性能呢？答案是肯定，但也是存在极限的。通过观察[历年的延迟数据](https://colin-scott.github.io/personal_website/research/interactive_latency.html)，从1990年开始到2020年，30年的时间里，计算机访问不同设备装置的速度有了巨大提升。可以发现网络的延迟虽然有很大改善，但是趋势在逐渐变缓，也就是说硬件与工艺提升带来的红利变得很微薄，虽然有提升，但是还不足以引起质变。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于分布式锁在访问**资源状态**相比单机锁存在巨大的延迟，就锁的性能而言肯定是低于单机锁的。当然会有同学提出，单机锁解决不了分布式环境下的并发控制问题呀。没错，这里就访问延迟来比较二者的性能有所偏颇，但需要读者明白，分布式锁的引入并不是整个系统高性能的保证，不见得分布式环境会比单机更加有效率，使用分布式锁需要接受它带来的延迟，而它的目的是为分布式环境中水平伸缩的应用服务提供并发控制能力。

### 超时问题

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分布式锁除了面对由于链路变化导致出现的延迟问题之外，还需要考虑锁**资源状态**的可靠性问题。由于锁**资源状态**放置在远程存储上，所以它的管理是依靠（使用锁的）进程实例（或线程）的网络请求来完成的，这个过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-remote-status.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在单机锁中，锁的**资源状态**和应用实例是一体的，而分布式锁的**资源状态**与应用实例相互独立，这会带来锁资源占用超时的问题。我们先考虑一种最简单的分布式锁实现方式，依靠一个数据库来维护**资源状态**。在关系数据库（比如：MySQL）中，创建一个`lock`表，如果需要获取锁就需要在表中增加一行记录，可以根据锁的名称来查询锁，且在名称这个字段上增加了唯一约束。如果客户端能够新增一行记录，则代表它成功的获取到了锁，否则需要不断的尝试新增记录（并忽略主键冲突错误），当释放锁时需要主动的删除这行记录，该过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-mysql.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到图中**实例A**和**B**在尝试抢占一个名为`order_lock`的锁，而实例获取锁的方式是在`lock`表中成功新增一行当前锁对应的记录。由于`lock`表在`lock_name`一列上存在唯一约束，所以同一时刻只会有一个实例（也就是**实例A**）能够完成新增记录获取到锁。当实例完成操作后，需要释放锁，在当前场景下，可以通过删除这行记录来完成锁资源的释放。

> 需要注意`lock`表中`client`字段，它记录了当前实例的**IP**，目的是在删除时，通过条件语句`WHERE LOCK_NAME = ? AND CLIENT=?`来保证只有拥有锁的实例才能释放锁，防止其他实例误释放锁。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述锁看起来可以完成分布式并发控制的工作，但它实际上存在超时问题。假设一种场景，实例在获取到锁后，由于异常导致没有释放锁（可能是没有释放锁或系统错误导致实例崩溃），但锁记录仍旧存在，这会使得再也没有实例可以获取到锁，分布式系统进入死锁状态。解决分布式锁可能带来的死锁问题，最直接的办法是增加锁记录的超时时间，通过增加占用锁的最长时间这一约束，从而避免分布式系统陷入死锁的窘境。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以通过在`lock`表中新增一个`expire_time`字段，每次实例获取到锁时需要设置超时时间，当超时时间到达时，将会删除该记录，纵使可能会违反锁的排他性，导致两个实例同时执行，也不能使系统存在死锁的风险。清除超时锁记录的工作可以交给一个专属的应用实例去完成，该过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-mysql-expire-time.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，可以通过一个分布式锁超时清除实例来定时的清除过期的锁记录，这样做的好处在于不需要将是否过期的判断强行放置在应用实例获取锁的逻辑中，但需要保障这个清除实例的可用性。应用实例在获取锁时，需要将过期时间计算好，一般是当前时间加上一个超时时间差，至于这个时间差需要设置多少，需要结合应用获取锁后执行逻辑的最大耗时来考虑，也就是说时间差设置长短的问题还是抛给了分布式锁的使用者。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过增加分布式锁的占用超时时间，可以有效的避免由于实例自身稳定性问题而导致分布式锁**资源状态**没有正常释放的问题。使用一个超时清除实例来定期删除过期的锁记录，可以有效的避免超时问题带来的死锁，但总感觉有些累赘。可以使用**Redis**之类的缓存系统来存放锁的**资源状态**，通过设置缓存的过期时间，不仅能够完成过期锁记录的自动删除，还使得超时响应变得更加及时，但是分布式锁的可用性又会受到影响。

### 可用性问题

继续举例，mysql挂掉
redis

## 自旋式

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;

## 事件通知式

## 更进一步
