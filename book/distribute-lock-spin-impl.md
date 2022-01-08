# 拉模式的分布式锁

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;拉模式的分布式锁，需要实例（通过客户端）以自旋的形式，主动去调用**存储服务**，根据调用结果来判断是否获取到了锁。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-pull-mode.jpg">
</center>

## 什么是拉模式？

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;拉模式的分布式锁，需要实例（通过客户端）以自旋的形式，主动去调用**存储服务**，根据调用结果来判断是否获取到了锁。调用的逻辑为：是否能够在存储服务中新增锁对应的**资源状态**（或一行记录），**资源状态**需要包含能够代表获取锁的实例（或线程）标识，并且该标识能够确保全局唯一，不同获取锁的实例标识各不相同。获取拉模式分布式锁的流程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-pull-mode-acquire-flow.png" width="60%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，虚线框中的流程就是获取锁的自旋过程，但在介绍它之前，先要看一下获取锁时需要确定的输入，这些输入变量的名称以及描述如下表所示：

|变量|名称|描述|
|----|----|----|
|*T*|当前时间|当前系统时间|
|*D*|超时时长|实例获取锁能够等待的最长时间|
|*TTL*|过期时长|**资源状态**在**存储服务**上存活的最长时间|
|*S*|睡眠时长|新增**资源状态**（也就是获取锁）失败需要睡眠的时长|
|*RN*|锁资源名称|分布式锁的名称，可以是某个业务编号|
|*RV*|锁资源值|获取锁的实例标识，需要保证唯一性，可以是**UUID**|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在自旋过程中，首先需要判断是否已经超时，如果没有超时，则会调用**存储服务**的新增接口，尝试新增当前锁的**资源状态**，**资源状态**包括名称*RN*和值*RV*。**存储服务**的新增接口需要提供`addIfAbsent`语义，如果已经存在了一个*RN*的记录，则会返回新增失败，否则新增记录成功，且过期时间在*TTL*之后。该过程需要确保是原子化的，这样多个实例对相同的*RN*进行新增操作时，只会有一个能够成功，这样就兑现了锁的排他性。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果调用新增接口返回失败，这代表实例没有获取到锁，此时客户端需要不断的循环尝试新增直至成功，以此来满足实例获取锁的诉求。如果退出循环的条件只是新增**资源状态**成功，由于调用**存储服务**需要通过网络，稍有不慎会导致实例陷入长时间阻塞。因此，循环退出的条件还包括获取锁的超时时间到，每次新增**资源状态**失败可以睡眠一段时间，避免对**存储服务**产生过多无效请求。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;当释放锁时，实例通过传入锁的资源名称*RN*和值*RV*来删除**资源状态**。**存储服务**的删除接口需要具备`compareAndDelete`（以下简称：**CAD**）语义，只有**资源状态**中的值与*RV*相同才能够删除，这样就使得只有获取到锁的实例才能够执行成功，并且多次执行删除操作也是无副作用的。

## 需要注意的点

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;拉模式的流程看起来是很简单的，实例通过客户端去获取锁，如果无法在**存储服务**中新增**资源状态**，就进行重试，要么超时返回，要么获取到锁。通过一个循环以及少量的时间运算与判断，通过几行代码就可以实现上述逻辑了。如果从能用的角度去看，就是这么简单，但想用的安心，就需要多考虑一点了。拉模式获取锁的主要步骤包括：访问**存储服务**（调用其新增接口）、时间运算与判断以及睡眠，其中访问**存储服务**和睡眠对实例获取锁有实际影响，接下来分析它们各自需要被关注的点。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;访问**存储服务**需要注意的点包括：请求的**I/O**超时、访问**存储服务**耗时和过期时长设置。首先，请求需要有**I/O**超时，举个例子：我们经常使用**HttpClient**去请求**Web**服务来获取数据，如果**Web**服务很慢或者网络延迟很高，调用线程就会被挂在那里很久。访问**存储服务**和这个问题一样，为了避免客户端陷入未知时长的等待，对**存储服务**的请求需要设置**I/O**超时。其次，访问**存储服务**耗时越短越好，如果访问耗时很低，会提升客户端的响应性，当然不同的**存储服务**访问耗时也会不一样，基于**Redis**的分布式锁在访问耗时上就优于数据库分布式锁。最后，过期时长支持定制，新增**资源状态**时会设置过期时长，一般来说这个时长会结合同步逻辑的最大耗时来考虑，是个固定值，比如：`10`秒。获取锁时，实例其实可以根据当前的上下文估算出可能的耗时，比如：发现**同步逻辑**中处理的列表数据包含的元素数量比平均数高一倍，如果此时能够适当增加对应的过期时长，会是一个好的选择。这就需要分布式锁框架提供**API**，能够支持实例设置过期时长，通过设置一个更大的值，就能有效减少由于过期自动释放锁而导致的正确性问题。

> 过期时长的设置只会影响到本次获取的锁，是基于请求的，不是全局性的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;睡眠需要关注对**存储服务**产生的压力。对于睡眠而言，简单的做法是固定一个时长，比如：一旦客户端新增**资源状态**失败，就睡眠`15`毫秒。如果某个锁资源在多个实例之间有激烈的竞争，这种方式会使得未获取到锁的实例在一个较小的时间范围内同时醒来，并发起对**存储服务**的重试，无形中增加了**存储服务**的瞬时压力。如果实例中又以多线程并发的方式获取锁，会导致这个问题变得更糟，解决方式就是引入随机。可以通过指定最小睡眠时长*min*和随机睡眠时长*random*来计算本次应该睡眠的时长，每次睡眠时长不固定，只是在`[min, min + random)`内随机取值。通过随机睡眠会使重试变得离散，一定程度上减轻了对**存储服务**的压力。

## **Redis**分布式锁实现

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分布式锁使用**Redis**之类的缓存系统来存储锁的**资源状态**，可以简化其实现方式，毕竟不需要用编程的方式来清除过期的**资源状态**，因为缓存系统固有的过期机制可以很好的处理这项工作。通过实现*LockRemoteResource*接口，可以将**Redis**适配成为分布式锁实现，并集成到框架中。**Redis**能够满足分布式锁对**存储服务**的诉求，综合考虑性能和成本，它非常适合作为拉模式的分布式锁实现。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在分布式锁框架中，介绍了**Redis**分布式锁实现（*RedisLockRemoteResource*）的构造函数以及其涉及的参数变量，接下来从获取和释放锁两个方面来介绍实现内容。

### Redis分布式锁的获取

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Redis**作为**存储服务**的新增接口，需要使用类似命令：`SET $RN $RV NX PX $D`。该命令通过**NX**选项，确保只有在键（也就是`$RN`）不存在的情况下才能设置（添加），同时**PX**选项表示该键将会在`$D`毫秒后过期，而值`$RV`需要做到所有客户端唯一。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用**Lettuce**客户端，上述操作的代码如下所示：

```java
private boolean lockRemoteResource(String resourceName, String resourceValue, int ownSecond) {
    SetArgs setArgs = SetArgs.Builder.nx().ex(ownSecond);
    boolean result = false;
    try {
        String ret = syncCommands.set(resourceName, resourceValue, setArgs);
        // 返回是OK，则锁定成功，否则锁定资源失败
        if ("ok".equalsIgnoreCase(ret)) {
            result = true;
        }
    } catch (Exception ex) {
        throw new RuntimeException("set key:" + resourceName + " got exception.", ex);
    }

    return result;
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述方法提供了基于**Redis**的`addIfAbsent`语义，且支持过期时长的一并设置。参数**SetArgs**使用构建者模式创建，`syncCommands`是**Lettuce**提供的**RedisCommands**接口，由于当前逻辑需要同步获得设置的结果，所以采用同步模式。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;获取锁的方法，代码如下所示：

```java
public AcquireResult tryAcquire(String resourceName, String resourceValue, long waitTime,
                                TimeUnit timeUnit) throws InterruptedException {
    // 目标最大超时时间
    long destinationNanoTime = System.nanoTime() + timeUnit.toNanos(waitTime);
    boolean result = false;
    boolean isTimeout = false;

    Integer liveSecond = OwnSecond.getLiveSecond();
    int ownTime = liveSecond != null ? liveSecond : ownSecond;

    AcquireResultBuilder acquireResultBuilder;

    try {
        while (true) {
            // 当前系统时间
            long current = System.nanoTime();
            // 时间限度外，直接退出
            if (current > destinationNanoTime) {
                isTimeout = true;
                break;
            }
            // 远程获取到资源后，返回；否则，spin
            if (lockRemoteResource(resourceName, resourceValue, ownTime)) {
                result = true;
                break;
            } else {
                spin();
            }
        }
        acquireResultBuilder = new AcquireResultBuilder(result);
        if (isTimeout) {
            acquireResultBuilder.failureType(AcquireResult.FailureType.TIME_OUT);
        }
    } catch (Exception ex) {
        acquireResultBuilder = new AcquireResultBuilder(result);
        acquireResultBuilder
                .failureType(AcquireResult.FailureType.EXCEPTION)
                .exception(ex);
    }

    return acquireResultBuilder.build();
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述方法，首先将获取锁的超时时间单位统一到纳秒，由超时时长`waitTime`计算出最大的超时时间`destinationNanoTime`。在接下来的自旋中，如果当前系统时间`current`大于`destinationNanoTime`就会超时返回。如果调用**存储服务**返回新增失败，则会执行`spin()`方法进行睡眠，而睡眠的时长为：`ThreadLocalRandom.current().nextInt(randomMillis) + minSpinMillis`，它会在一个时间范围内进行随机，以此避免对**存储服务**产生无谓的瞬时压力。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以通过*OwnSecond*工具对**资源状态**的占用时长（也就是**Redis**键值的过期时间）进行自定义设置。如果需要更改本次调用对于锁的占用时长，可以在调用锁的`tryLock()`方法之前，执行`OwnSencond.setLiveSecond(int second)`方法，该工具依靠**ThreadLocal**将实例设置的占用时长传递给框架。

### Redis分布式锁的释放

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;释放锁可以通过资源名称*RN*和资源值*RV*删除对应的资源状态即可，但该过程必须是原子化的。如果是先根据*RN*查出资源状态，再比对*RV*与资源状态中的值是否一样，最后使用`del`命令删除对应键值，这样的两步走会导致锁有被误释放的可能，该过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-redis-lock-release-problem.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，**客户端A**在锁的有效期（也就是占用时长）快结束时调用了`unlock()`方法。如果采用两步走逻辑，在使用`del`命令删除键值前，锁由于超时时间到而自动释放，此时**客户端B**成功获取到了锁，并开始执行**同步逻辑**。**客户端A**由于（旧）值比对通过，使用`del`命令删除了**资源状态**对应的键值，这时运行在**客户端B**上的**同步逻辑**就不会再受到锁的保护，因为其他实例可以获取到锁并执行。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Redis**可以通过**Lua**脚本做到原子化**CAD**的支持，脚本如下：

```lua
if redis.call("get", KEYS[1]) == ARGV[1] then
    return redis.call("del", KEYS[1])
else
    return 0
end
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到其实就是两步走逻辑的**Lua**版本，只是**Redis**对于**Lua**脚本的执行是确保原子性的。

> 如果使用阿里云的**RDB**缓存服务，可以使用其`cad`扩展命令，不使用上述脚本。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;释放锁的方法，代码如下所示：

```java
public void release(String resourceName, String resourceValue) {
    try {
        syncCommands.eval(
                "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end",
                ScriptOutputType.INTEGER, new String[]{resourceName}, resourceValue);
    } catch (Exception ex) {
        // Ignore.
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述方法通过调用**RedisCommands**的`eval()`方法执行**CAD**脚本来安全的删除**资源状态**来完成锁的释放。

## **Redis**分布式锁存在的问题

### 主从切换带来的问题

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果**存储服务**出现故障，则会导致分布式锁不可用，为了确保其可用性，一般会将多个**存储服务**节点组成集群。以**Redis**为例，使用主从集群可以提升分布式锁服务的可用性，但是它会带来正确性被违反的风险。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Redis**主从集群会在所有节点上保有全量数据，主节点负责数据的写入，然后将变更异步同步到从节点。这种同步模式会导致在主从切换的一段时间内，由于新旧主节点上的数据不对等，导致部分分布式锁存在可能被多个实例同时获取到的风险，该过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-redis-master-slave.png" width="80%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上图中，主从集群可以提升分布式锁的可用性，避免出现由于**Redis**节点挂掉后导致的不可用。虽然可用性提升了，但是正确性会下降。在**步骤1到2**过程中，**实例A**先成功的在切换前的**Redis**主节点上新增了记录，也就是获取到了*order_lock*锁。随后**Redis**主节点挂掉，集群进行主从切换，数据仍在异步的向新晋升的**Redis**主节点上同步。**步骤5到6**，**实例B**刚好此时获取锁，它会尝试在新晋**Redis**主节点上新增记录，由于数据并未在此时完成同步，所以**实例B**成功的新增了记录并获取到了*order_lock*锁。在这一刻，**实例A和B**都会宣称获取到了*order_lock*锁，而相应的**同步逻辑**也会被并行执行，锁的正确性被违反。

### 看似完美的**Redlock**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Redis**单节点是**CP**型**存储服务**，使用它可以满足分布式锁对于正确性的诉求，但存在可用性问题。使用**Redis**主从集群技术后，会转为**AP**型存储服务，虽然提升了分布式锁的可用性，但正确性又会存在风险。面对可用性和正确性两难的局面，**Redis**作者（**Salvatore**）设计了不基于**Redis**主从技术的**Redlock**算法，该算法使用多个**Redis**节点，使用基于法定人数过半（**Quorum**）的策略，以期望该算法能做到正确性与可用性的兼得。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Redlock**需要使用多个**Redis**节点来实现分布式锁，节点数量一般是奇数，并且至少要**5**个节点才能使其具备良好的可用性。该算法是一个客户端算法，也就是说它在每个客户端上运行方式是一致的，且客户端之间不会进行相互通信。接下来以**5**个节点为例，**Redlock**算法过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-redlock.png" width="80%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，首先**Redlock**算法会获取当前时间`T`，然后使用相同的锁资源名称`$RN`和资源值`$RV`并行的向**5**个**Redis**节点进行操作。执行的操作与获取单节点**Redis**分布式锁的操作一致，如果对应的**Redis**节点上不存在`$RN`则会成功设置，且过期时长为`$D`。对**5**个**Redis**节点进行设置的结果分别为`R1`至`R5`，再取当前时间`T’`，如果结果成功数量大于等于**3**且 `(T’-T)`小于`$D`，表明在多数**Redis**节点上成功新增了`$RN`且这些键均没有过期，则代表客户端获取到了锁，有效期为`ET1`至`ET5`的最小值减去`T`。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果设置结果成功数量小于**3**，表明在多个**Redis**节点上，对于新增`$RN`没有寻得共识。如果 `(T’-T)`大于等于`$D`，表明当前客户端获取的锁已经超时。上述两种情况只要出现一个，则客户端获取锁失败。此时需要在所有**Redis**节点上运行无副作用的删除脚本，将当前客户端创建的记录（如果有的话，就）删除，避免记录要等到超时才能被清除。

> 分布式锁框架通过使用**Redisson**客户端，可以很容的将Redlock集成到框架中，该分布式锁实现代码可以参见[分布式锁项目](https://github.com/weipeng2k/distribute-lock)中的*distribute-lock-redlock-support*模块。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Redlock**算法看起来能够在分布式锁的可用性和正确性之间寻得平衡，少量**Redis**节点挂掉，不会引起分布式锁的可用性问题，同时正确性又得以保证。理想情况下，**Redlock**看似很完美，但在分布式环境中，进程的暂停或网络的延迟，会打破该算法，使之失效。以**Java**应用为例，如果在算法判定获取到锁，客户端执行同步逻辑时引入**GC**暂停，则会可能导致该算法对于正确性的保证失效，该过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-redlock-problem.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，**客户端A**获取到了锁，然后开始执行锁保护的**同步逻辑**，该逻辑在同一时刻只能有一个客户端能够执行。当**客户端A**开始执行逻辑时，由于**GC**导致进程出现停顿（**GC暂停**，即**stop-the-world**，不会由于运行的是业务线程而对其特殊对待，它会一律暂停**Java**虚拟机中除**GC**外的线程），而暂停时长超出了锁的有效期，此时锁已经由于超时而释放。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**客户端B**在锁超时后获取到了锁，然后开始执行**同步逻辑**，**客户端A**由于**GC**结束而恢复执行，此时原本被锁保护的**同步逻辑**被并发执行，锁的正确性被违反。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到虽然**Redlock**算法通过基于法定人数的设计，在理论上确保了正确性和可用性，但是在真实的分布式环境中，会出现正确性无法被保证的风险。有同学会问，如果使用没有**GC**特性的编程语言来开发应用，是不是就可以了？实际上除了**GC**导致进程暂停，如果同步逻辑中有网络交互，也可能由于**TCP**重传等问题导致实际的执行时间超出了锁的有效期，最终导致两个客户端又有可能并发的执行**同步逻辑**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;单节点（或主从集群）的**Redis**分布式锁也存在上述问题，本质在于基于**Redis**实现的分布式锁，对于锁的释放存在超时时间的假设。虽然超时避免了死锁，但是会导致锁超时（释放）的一刻，两个客户端有同时进行操作的可能，这是能够在理论模型上推演出来的，毕竟释放锁的不是锁的持有者，而是锁自己。

## 扩展：本地热点锁

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;拉模式分布式锁需要依靠不断的对**存储服务**进行自旋调用，来判断是否能够获取到锁，因此会产生大量的无效调用，平添了**存储服务**的压力。对于分布式锁而言，竞争的最小单位不是进程，而是线程，由于实际情况中的（应用）实例都是以多线程模式运行的，导致竞争会更加激烈。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在激烈的竞争中，如果遇到热点锁，情况会变得更糟。比如：使用商品ID作为锁的资源名称，对于爆款商品而言，多机多线程就会给**存储服务**带来巨大的压力，该问题如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-pull-mode-process-thread-problem.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，实例内通过多线程并发的方式获取锁。在单个实例内，假设获取商品锁的并发度是**10**，那么两个实例就能够给**存储服务**带来**20**个并发的调用。以线程的角度来看这**20**个并发，是合理的，虽然每次请求绝大部分都是无功而返（没有获取到锁），但是这都是为了保证锁的正确性，纵使再高的并发，也只能通过不断的扩容**存储服务**来抵消增长的压力。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以想象，**存储服务**上处理的请求，基本全都是无效的，不断的扩容**存储服务**显得不现实，是否有其他方法可以优化这个过程呢？答案就是通过本地热点锁来解决。通过使用（单机）本地锁可以有效的降低对**存储服务**产生的压力，该过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-pull-mode-local-hotspot.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，实例中的多线程应该先尝试竞争本地（基于**JUC**的单机）锁，成功获取到本地锁的线程才能参与到实例间的分布式锁竞争。从实例的角度去看，如果都是获取同一个分布式锁，在同一时刻只能由一个实例中的一个线程获取到锁，因此理论上对**存储服务**的并发上限只需要和实例数一致，也就是**2**个并发就可以了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以通过在分布式锁前端增加一个本地锁就能得以实现，但事实上并没有这么容易，因为实例中的多线程需要使用同一把本地锁才会有意义，所以需要有一个**Map**结构来保存锁资源名称到本地锁的映射。如果对该结构管理不当，对任意分布式锁的访问都会创建并保有本地锁，那就会使实例有**OOM**的风险。一个比较现实的做法就是针对某些热点锁进行优化，只创建热点锁对应的本地锁来有效减少对**存储服务**产生的压力。

> 在实际工作场景中，可以根据生产数据发现实际的热点数据，比如：爆款商品ID或热卖商家ID等，将其提前（或动态）设置到分布式锁框架中，通过将分布式锁“本地化”，来优化这个过程。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于本地锁的获取是在分布式锁之前，通过扩展分布式锁框架的*LockHandler*就可以很好的支持这一特性，对应的*LockHandler*扩展（的部分）代码如下：

```java
package io.github.weipeng2k.distribute.lock.plugin.local.hotspot;

import io.github.weipeng2k.distribute.lock.spi.AcquireContext;
import io.github.weipeng2k.distribute.lock.spi.AcquireResult;
import io.github.weipeng2k.distribute.lock.spi.ErrorAware;
import io.github.weipeng2k.distribute.lock.spi.LockHandler;
import io.github.weipeng2k.distribute.lock.spi.ReleaseContext;
import io.github.weipeng2k.distribute.lock.spi.support.AcquireResultBuilder;
import org.springframework.core.annotation.Order;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.Lock;

/**
 * <pre>
 * 本地热点锁LocalHandler
 *
 * 获取锁时，会先获取本地的锁，然后尝试获取后面的锁
 *      如果后面的锁获取成功，则返回
 *      如果后面的锁获取失败，则需要解锁
 *
 * 释放锁时，会先释放后面的锁，然后尝试释放当前的锁，不要抛出错误即可
 *
 * </pre>
 *
 * @author weipeng2k 2021年12月14日 下午18:43:29
 */
@Order(10)
public class LocalHotSpotLockHandler implements LockHandler, ErrorAware {

    private final LocalHotSpotLockRepo localHotSpotLockRepo;

    public LocalHotSpotLockHandler(LocalHotSpotLockRepo localHotSpotLockRepo) {
        this.localHotSpotLockRepo = localHotSpotLockRepo;
    }

    @Override
    public AcquireResult acquire(AcquireContext acquireContext, AcquireChain acquireChain) throws InterruptedException {
        AcquireResult acquireResult;
        Lock lock = localHotSpotLockRepo.getLock(acquireContext.getResourceName());
        if (lock != null) {
            // 先获取本地锁
            if (lock.tryLock(acquireContext.getRemainingNanoTime(), TimeUnit.NANOSECONDS)) {
                acquireResult = acquireChain.invoke(acquireContext);
                // 没有获取到后面的锁，则进行解锁
                if (!acquireResult.isSuccess()) {
                    unlockQuietly(lock);
                }
            } else {
                AcquireResultBuilder acquireResultBuilder = new AcquireResultBuilder(false);
                acquireResult = acquireResultBuilder.failureType(AcquireResult.FailureType.TIME_OUT)
                        .build();
            }
        } else {
            acquireResult = acquireChain.invoke(acquireContext);
        }
        return acquireResult;
    }

    @Override
    public void release(ReleaseContext releaseContext, ReleaseChain releaseChain) {
        releaseChain.invoke(releaseContext);
        Lock lock = localHotSpotLockRepo.getLock(releaseContext.getResourceName());
        if (lock != null) {
            unlockQuietly(lock);
        }
    }
    
    private void unlockQuietly(Lock lock) {
        try {
            lock.unlock();
        } catch (Exception ex) {
            // Ignore.
        }
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，本地热点锁都存储在*LocalHotSpotLockRepo*中，由使用者进行设置。通过*DistributeLock*获取锁时，框架会先从*LocalHotSpotLockRepo*中查找本地锁，如果没有找到，则执行后续的*LockHandler*，反之，会尝试获取本地锁。需要注意的是，成功获取到本地锁后，如果接下来没有获取到分布式锁，就需要释放当前的本地锁，避免阻塞其他线程获取分布式锁的行为。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于释放锁而言，需要在`releaseChain.invoke(releaseContext);`语句之后释放本地锁，也就是在分布式锁（的**存储服务**）被释放后，再释放本地锁。如果释放顺序反过来，提前释放了本地锁，会使得被（释放本地锁而）唤醒的线程立刻向**存储服务**发起无效请求。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述功能以插件的形式提供给使用者，只需要依赖如下坐标就可以激活使用：

```xml
<dependency>
    <groupId>io.github.weipeng2k</groupId>
    <artifactId>distribute-lock-local-hotspot-plugin</artifactId>
</dependency>
```

> 该插件会在应用的**Spring**容器中注入*LocalHotSpotLockRepo*，通过调用它的`createLock(String resourceName)`方法完成本地锁的创建。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;接下来通过两个测试用例：*distribute-lock-redis-testsuite*和*distribute-lock-redis-local-hotspot-testsuite*来展示本地热点锁的优化效果。考察的指标是通过执行**Redis**提供的`info commandstats`来查看**SET**命令执行的数量来进行判定的，因为获取分布式锁就是依靠**SET**命令。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;两个测试用例都会运行**3**个实例，分两个批次执行，获取的分布式锁名称都是`lock_key`。每个实例都会以**4**个并发获取分布式锁，尝试获取**400**次，数据对比如下表所示：

|用例|执行前**SET**命令数量|执行后**SET**命令数量|获取锁成功数量|获取锁失败数量|对**Redis**的**SET**请求数量|
|---|---|---|---|---|---|
|**Redis**锁测试集|183168|204413|1099|101|21245|
|**Redis**锁测试集（包含本地热点锁插件）|204413|210518|1147|53|6105|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上表所示，可以看到本地热点锁插件能够显著的降低热点锁对**存储服务**的请求，有**70%**的无效请求被该插件所阻挡。随着对**Redis**请求量的下降，分布式锁获取成功率也随之上升。
