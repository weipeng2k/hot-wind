# 锁是什么？

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;锁是一种提供了**排他性**和**可见性**的并发访问控制工具，它保证了在同一时刻，只能有一个访问者可以访问到锁保护的**资源**，这个**资源**可以是一段方法逻辑或是某个存储。锁是我们常用的一种并发访问控制工具，而**排他性**是它功能性最直接的体现，以至于它成了**排他性**的代名词，但其所隐含的**可见性**以及**资源状态**往往被我们忽视。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**可见性**表达的是一个访问者对数据（比如：内存中的某个值）做了修改，其他的访问者能够立即发现数据的变化，从而能够做出相应的行为。这点看起来挺简单，甚至感觉有些理所应当，但如果带入到现代计算机体系结构下，就觉得没这么容易了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**CPU**和内存之间是有缓存的，这个缓存一般封装在**CPU**上，每个**CPU**核心同缓存进行沟通，当缓存中没有数据时，才会将内存中的数据载入到缓存中，然后进行处理。缓存封装在**CPU**内，其目的是离**CPU**核心更近，**CPU**对缓存的访问时间一般在`1`纳秒左右，而对内存的访问时间则在`100`纳秒左右。这个过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/cpu-cache-memory-model.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，与内存访问相比，缓存更加迅捷，但问题却随之而来，数据会同时出现在缓存和内存中，这使得该架构天生就存在可见性问题。比如：一个值在内存中是`A`，由于程序是多线程执行，导致在某个**CPU**缓存中的值是旧值`B`，这时就出现可见性问题了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果要解决这个问题，就需要程序能够在访问数据之前先作废掉**CPU**上的缓存，从内存中加载最新的数据使用，同样也需要在数据变更后，将数据显式的刷回内存。锁就具有这个特性，锁除了能够完成**排他性**工作，它还能隐性的解决**可见性**问题。当使用锁的时候，程序会执行系统指令，将**CPU中**的缓存作废，然后载入内存中的最新数据，现在通过一个示例来看一下，示例代码如下所示：

```java
public class NoVisibilityTest {
	// 准备状态
	private static boolean ready;
	// 数量
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

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述示例定义了两个静态变量，分别是状态`ready`和值`number`，然后启动`15`个线程进行执行操作，操作很简单，如果发现`ready`为`true`，则退出循环，打印并结束。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果不存在**可见性**问题，*ReaderThread*线程应该可以发现`ready`值被修改，然后跳出死循环，打印并退出。实际情况会是这样吗？运行程序后，主线程会每隔`1`秒打印一次线程信息，重复`20`次。这里截取最后几个批次，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/visible-variable-problem.png" width="50%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从第`20`次打印的线程信息可以看出，之前创建的`ReaderThread`大部分都存活着，难道它们都对`ready`值的变化视而不见吗？其实它们不是看不见，而是它们只盯着缓存中的`ready`值去看，对内存中的`ready`值变化不清楚罢了。线程运行在**CPU**核心上，在线程执行时，将值从内存载入到缓存中，依照缓存中的值来运行。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;那怎样才能让执行的线程从内存中获取最新的数据呢？有一种简单的做法是使用`volatile`关键字来修饰`ready`变量。当然更简单的就是什么都不做，等执行的线程被操作系统交换出去后，然后当线程下一次被调度执行时，会从内存中获取数据并恢复缓存，这时该线程有几率能够恢复过来。除此之外，还有别的方式吗？有的，使用锁。因为锁的**资源状态**在内存中，所以需要保证访问锁的线程能够正确看到锁背后的**资源**，而这个保证就是对**可见性**的承诺。基于这个特性，我们使用一个**无意义**的锁来获得**可见性**，这里所谓的**无意义**，是指没有发挥出锁的**排他性**能力。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;只需要对原有示例做出一些修改，如下所示：

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

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，上述修改只是在`ReaderThread`的死循环中，创建了一个`ReentrantLock`，并在这个锁上调用`lock`方法。如果从功能角度上看这个修改，是一点作用也没有的，但重新运行修改后的程序，会看到结果，如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/lock-protect-visible.png" width="50%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`ReaderThread`线程读到了内存中`ready`的新值，它们安全的退出了。这就是锁**可见性**的体现，它保证在锁保护的代码块中，能够看到最新的值，不论是锁的**资源状态**，还是程序中的数据变量。在使用锁时，会将**CPU**上的缓存作废，以期望获取到内存中的值，而作废的数据不止是**资源状态**，因此变相的使得线程获取到了最新的`ready`值。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，锁是依靠**可见性**的保障来看清楚锁的**资源状态**，并在此基础上封装出能够提供**排他性**语义的并发控制装置。在使用锁的功能时，也会间接的享受到它对**可见性**的保证。
