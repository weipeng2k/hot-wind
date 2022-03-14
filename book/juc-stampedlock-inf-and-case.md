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
|`void unlockRead(long stamp)`|根据传入的邮戳释放读锁|

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