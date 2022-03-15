# StampedLock的接口与示例

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`StampedLock`提供了很多方法，乍一看有些乱，但它们可以分为以下五类：获取与释放读锁、获取与释放写锁、获取状态与验证邮戳、获取锁视图和转换锁模式。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/juc-summary/juc-stampedlock-inf-page.jpg">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;获取与释放读锁主要包括以下方法，如下表所示：

|方法名称|描述|
|---|---|
|`long readLock()`|获取读锁并返回`long`类型的邮戳，如果当前存在写锁，那么该方法会阻塞，直到获取到读锁，邮戳可以用来解锁以及转换当前的锁模式。该方法不响应中断，但与`Lock`接口类似，该类提供了`readLockInterruptibly()`方法|
|`long tryReadLock(long time, TimeUnit unit)`|在给定的超时时间内，尝试获取读锁并返回`long`类型的邮戳，如果未获取到读锁，返回`0`|
|`long tryOptimisticRead()`|获取乐观读锁并返回`long`类型的邮戳，该方法不会产生阻塞，也不会阻塞其他线程获取锁，如果当前写锁已经被获取，则会返回`0`。返回的邮戳可以使用`validate(long stamp)`方法进行校验|
|`void unlockRead(long stamp)`|根据指定的邮戳释放读锁|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;写锁的操作和读锁类似，而获取锁视图如前文所介绍，可以通过调用**as**开头的方法来获取对应的锁视图，比如：调用`asReadWriteLock()`方法可以获得一个读写锁的视图引用。如果`StampedLock`提供了获取锁的视图方法，是不是可以不用掌握该类复杂的**API**，直接用适配的方式来使用它就可以了？答案是否定的，以`StampedLock`提供的乐观读模式为例，需要配合验证邮戳的的`boolean validate(long stamped)`方法才能工作，而该方法会验证获取乐观读锁后是否有其他线程获取了写锁，如果验证通过，则表示写锁没有被获取，本地数据是有效的，而该过程在读多写少的场景下会带来性能的大幅提升，这点是通过锁视图无法做到的。除了验证邮戳的方法，还支持获取锁的状态，比如：`boolean isReadLocked()`方法用来判断写锁是否已经被获取。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;除了上述方法，`StampedLock`还支持三种模式的相互转换，比如：在获取了读锁后，如果要升级为写锁，可以使用之前获取读锁的邮戳，调用`long tryConvertToWriteLock(long stamp)`将读锁升级为写锁，其他的转换方式可以查阅包含**tryConvertTo**的方法，这里不再赘述。

## 代码示例

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`StampedLock`使用不善会导致死锁和一些诡异问题，因此有一套推荐的编程模式。接下来，通过一个缓存示例说明`StampedLock`的使用方式，示例代码如下所示：

```java
public class SLCache<K, V> implements Cache<K, V> {
    private final Map<K, V> map = new HashMap<>();
    private final StampedLock stampedLock = new StampedLock();

    @Override
    public V get(K k) {
        long stamp = stampedLock.tryOptimisticRead();

        try {
            for (; ; stamp = stampedLock.readLock()) {
                if (stamp == 0L) {
                    continue;
                }

                V v = map.get(k);

                if (!stampedLock.validate(stamp)) {
                    continue;
                }

                return v;
            }
        } finally {
            if (StampedLock.isReadLockStamp(stamp)) {
                stampedLock.unlockRead(stamp);
            }
        }
    }

    @Override
    public V put(K k, V v) {
        long stamp = stampedLock.writeLock();
        try {
            return map.put(k, v);
        } finally {
            stampedLock.unlockWrite(stamp);
        }
    }

    @Override
    public V putIfAbsent(K k, V v) {
        long stamp = stampedLock.tryOptimisticRead();

        try {
            for (; ; stamp = stampedLock.writeLock()) {
                if (stamp == 0L) {
                    continue;
                }

                V prev = map.get(k);

                if (!stampedLock.validate(stamp)) {
                    continue;
                }

                // 验证通过，且存在值
                if (prev != null) {
                    return prev;
                }

                stamp = stampedLock.tryConvertToWriteLock(stamp);

                if (stamp == 0L) {
                    continue;
                }

                prev = map.get(k);
                if (prev == null) {
                    map.put(k, v);
                }

                return prev;
            }
        } finally {
            if (StampedLock.isWriteLockStamp(stamp)) {
                stampedLock.unlockWrite(stamp);
            }
        }
    }

    @Override
    public void clear() {
        long stamp = stampedLock.writeLock();
        try {
            map.clear();
        } finally {
            stampedLock.unlockWrite(stamp);
        }
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上述代码所示，写操作`put(K k, V v)`方法，通过调用`writeLock()`方法获取写锁以防止其他线程并发修改`HashMap中`的值，同时返回的邮戳需要保存到本地变量，在更新完`HashMap`后，再调用`unlockWrite(long stamp)`进行解锁。`StampedLock`对写锁和读锁的操作与`Lock`接口类似，只需要注意邮戳的处理即可，而主要不同在于乐观读锁的使用，它需要遵循的编程模式，使用伪码如下所示：

```java
// 获取乐观读锁
long stamp = stampedLock.tryOptimisticRead();
// 将锁保护的数据读入到本地变量
copyDataToLocalVariable();
// 验证邮戳
if(!lock.validate(stamp)){   
    // 验证失败，升级为读锁，此时可能会阻塞
    stamp = stampedLock.readLock();
    try {
        // 刷新本地变量
        refreshLocalVariableData();
     } finally {
       lock.unlockRead(stamp);
    }

}
// 使用本地变量执行业务操作
doBizUseLocalVariable();
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上述伪码所示，乐观读锁的获取仅仅返回了代表那一刻锁状态的邮戳，开销很低。获取到乐观读锁后，需要拷贝数据到本地变量，如果之后的邮戳验证失败，就需要获取读锁并刷新之前本地变量对应的数据。乐观读锁的编程模式会让人感到有些琐碎，尤其是需要获取多个本地变量的时候，在刷新逻辑中稍有遗漏，就有可能导致使用到过期数据而产生问题。为了避免出现遗漏，在读操作`get(K k)`方法中，可以看到通过使用for循环将`copyDataToLocalVariable()`以及`refreshLocalVariableDate()`两段逻辑合并来减少重复代码的做法。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;写操作`putIfAbsent(K k, V v)`方法演示了乐观读锁升级为写锁的用法，与`get(K k)`方法中升级到读锁类似，从非阻塞轻量级的“乐观读锁”升级到具备阻塞能力“重量级”的写锁，可以调用`tryConvertToWriteLock(long stamp)`方法来完成。

> 如果升级转换失败，返回的邮戳为`0`，则会调用`writeLock()`再次获取写锁。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到`StampedLock`使用复杂度主要是由乐观读锁带来的，即然编程难度增加，那它的性能提升有多大呢？下面我们就通过测试来对比一下。

## 微基准测试

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;开发者对于一些代码实现差异或不同类库使用存在性能疑虑时，往往会编写测试代码，采用重复多次计数的方式来进行度量解决。随着**JVM**不断的演进，以及本地缓存行命中率的影响，使得重复多少次才能够得到一个可信的测试结果变得让人困惑，这时候有经验的同学就会引入预热，比如：在测试执行前先循环上万次。没错！这样做确实可以获得一个偏向正确的测试结果，但是**Java**提供了更好的解决方案，即**JMH (the Java Microbenchmark Harness)**，它能够照看好**JVM**的预热、代码优化，让测试过程变得简单，测试结果显得专业。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**JMH**的使用较为简单，首先在项目中新增`jmh-core`以及`jmh-generator-annprocess`的依赖，坐标如下所示：

```xml
<dependency>
    <groupId>org.openjdk.jmh</groupId>
    <artifactId>jmh-core</artifactId>
    <version>1.34</version>
</dependency>
<dependency>
    <groupId>org.openjdk.jmh</groupId>
    <artifactId>jmh-generator-annprocess</artifactId>
    <version>1.34</version>
</dependency>
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;创建测试类`StampedLockJMHTest`，代码如下所示：

```java
import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.annotations.Scope;
import org.openjdk.jmh.annotations.Setup;
import org.openjdk.jmh.annotations.State;

/**
 * @author weipeng2k 2022年02月19日 下午22:18:06
 */
@State(Scope.Benchmark)
public class StampedLockJMHTest {

    private Cache<String, String> rwlCache = new RWLCache<>();
    private Cache<String, String> slCache = new SLCache<>();

    @Setup
    public void fill() {
        rwlCache.put("A", "B");
        slCache.put("A", "B");
    }

    @Benchmark
    public void readWriteLock() {
        rwlCache.get("A");
    }

    @Benchmark
    public void stampedLock() {
        slCache.get("A");
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上述测试代码所示，`fill()`方法标注了`@Setup`注解，表示在微基准测试运行前将会调用它初始化两个缓存。另外两个方法，`readWriteLock()`和`stampedLock()`，标注了`@Benchmark`的注解，声明对应的方法为微基准测试方法，**JMH**会在编译期生成基准测试的代码，并运行它。`StampedLockJMHTest`还需要入口类来启动它，代码如下所示：

```java
import org.openjdk.jmh.runner.Runner;
import org.openjdk.jmh.runner.RunnerException;
import org.openjdk.jmh.runner.options.Options;
import org.openjdk.jmh.runner.options.OptionsBuilder;

/**
 * @author weipeng2k 2022年02月19日 下午22:19:25
 */
public class StampedLockJMHRunner {
    public static void main(String[] args) throws RunnerException {
        Options opt = new OptionsBuilder()
                .include("StampedLockJMH")
                .warmupIterations(3)
                .measurementIterations(3)
                .forks(3)
                .threads(10)
                .build();

        new Runner(opt).run();
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上述代码所示，`StampedLockJMHRunner`不仅是一个入口，它还完成了**JMH**测试的配置工作。默认场景下，**JMH**会找寻标注了`@Benchmark`类型的方法，但很有可能会跑到一些你不期望运行的测试，毕竟微基准测试跑起来比较耗时，这样就需要通过`include`和`exclude`两个方法来完成包含以及排除的语义。`warmupIterations(3)`的意思是预热做`3`轮，`measurementIterations(3)`代表正式计量测试做`3`轮，而每次都是先执行完预热再执行正式计量，内容都是调用标注了`@Benchmark`的代码。`forks(3)`指的是做`3`轮测试，因为一次测试无法有效的代表结果，所以通过`3`轮测试较为全面的测试。`threads(10)`指的是运行微基准测试的线程数，这里使用`10`个线程。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;运行`StampedLockJMHRunner`（测试环境：i9-8950HK 32GB），经过一段时间，测试结果如下：

```sh
Benchmark                          Mode  Cnt          Score          Error  Units
StampedLockJMHTest.readWriteLock  thrpt    9    5166194.657 ±   235170.493  ops/s
StampedLockJMHTest.stampedLock    thrpt    9  828896328.843 ± 22702892.910  ops/s
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，相较于读写锁实现的缓存，基于`StampedLock`实现的缓存在`get`操作上是前者的**160**多倍，达到了每秒**8**亿次以上。

> **Mode**类型为`thrpt`，也就是**Throughput**吞吐量，代表着每秒完成的次数。**Error**表示误差的范围。
