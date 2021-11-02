# 如何实现分布式锁

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本文是[**Martin Kleppmann**](https://martin.kleppmann.com)论证**Redlock**难以确保分布式锁正确性的文章，文章原文[在这里](https://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html)。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-debate.jpeg">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Redlock**算法看起来是一个不错且高可用的分布式锁实现，但是通过仔细的推敲，现实远比理想复杂，它并不是一个可靠的分布式锁实现，文中详细的阐述其问题所在，并对于分布式锁给予了自己的见解。整体文章偏学术化，严谨以及精确的表述让人读起来很惬意。**Redlock**算法的描述可以看[我翻译的文档](https://weipeng2k.github.io/hot-wind/book/distribute-lock-with-redis.html)。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;以下是笔者对这篇文章的（摘录）翻译和理解。如果是笔者的理解将会以![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png)来开头，以引言的形式来展示，比如：

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 这个是作者的理解。。。
>
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;描述内容示例。。。

---------

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;作为我书研究的一部分，我在Redis网站上发现了一种名为Redlock的算法。该算法声称在Redis上实现容错分布式锁，页面要求进入分布式系统的人提供反馈。该算法本能地在我脑海中敲响了一些警钟，所以我花了一些时间思考并写下这些笔记。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/book-cover.png" width="60%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于Redlock已经有超过10个独立实现，并且我们不知道谁已经在依赖此算法，我认为值得公开分享我的笔记。我不会讨论Redis的其他方面，其中一些已经在[其他地方](https://aphyr.com/tags/Redis)受到了批评。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在我讨论Redlock的细节之前，请允许我说，我非常喜欢Redis，我过去曾在生产中成功使用它。我认为这非常适合您想在服务器之间共享一些瞬时、非精确、快速变化的数据，如果您出于任何原因偶尔丢失这些数据，这没什么大不了的。例如：可以将启用在请求计数器上，用于记录每个IP访问的次数，或者记录用户使用的IP列表，用来检测登录异常。但是 Redis被越来越多用在数据管理领域，而该领域数据强一致性和可靠性要求而著称，这显然不是Redis擅长的。分布式锁就是属于这个领域的内容，我接来下详细展开。

## 使用分布式锁来干什么？

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用分布式锁的目的是为了能够在进行相同工作的多个节点中确保只有一个节点在同一时刻处理工作。这个工作可能是向一个共享存储写入数据或进行一些计算，也有可能是调用外部的API。在更高的层面，在分布式环境中使用锁，一般会有两个原因：要么是为了效率，要么是为了正确性。为了能够区分你是哪一种，你需要问自己，如果锁失败，你的场景会出现什么问题呢？

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**效率**：使用锁可以避免不必要的两次相同工作（例如一些昂贵的计算）。如果锁失败，两个节点最终完成相同的工作，结果是成本略有增加（您最终向AWS支付的费用比平时多5美分）或小的不便（例如：用户最终收到两封相同的电子邮件）。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**正确性**：使用锁可以防止进程并发的处理任务，从而导致互相影响，最终把系统搞乱。如果锁失败，两个并行的节点会在同一行数据上工作，结果要么是文件被弄乱，数据丢失或混乱，好比医药管理员给病人发错了药，甚至会引起严重的问题。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述两个使用分布式锁的原因都是合情合理，但是你需要清楚你的原因究竟是哪一个。我想指出如果仅仅是因为解决效率问题，那完全没有必要选择成本昂贵的Redlock，运行5个Redis服务器来提供分布式锁服务。你最好使用一个单Redis实例来解决你的问题，如果好的话可以使用一个支持主从的Redis集群。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果使用单个Redis实例，当Redis实例出现掉电或其他故障，可能会使部分锁失效。但是如果出于效率问题使用分布式锁，短时的失效是可以容忍的，而且Redis实例并不会经常崩溃。对于使用单节点Redis分布式锁的系统，使用者会认为这个锁不能够提供完全可靠的分布式锁服务，这样会给使用者一个暗示。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;另一方面，Redlock算法及其5个副本和多数票，乍一看，它似乎适合解决分布式锁用于应对正确性的场景。我将在下面的章节中论证，它并不适合解决正确性的问题。在本文的其余部分，我们将假设您的锁很关注正确性，如果两个不同的节点同时认为它们持有相同的锁，这是一个严重的错误。

## 使用锁来保护资源的访问

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们暂时把Redlock放到一边，先讨论分布式锁的一般使用方式（独立于使用的某些算法）。重要的是要记住，分布式系统中的锁不像多线程应用程序中的互斥锁，这是一只更复杂的野兽，因为不同的节点和网络都可能以各种方式出现故障。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;举个例子，假设你有一个应用，它会修改共享存储（如：HDFS或S3）上的文件。客户端首先获取到锁，然后读取文件，作出一些更改，然后将修改后的文件写会存储，最后释放锁。这个锁能够确保两个客户端不会同时在一个文件上进行操作，如果这么做了，可能会丢失一些更新。上述代码如下所示：

```java
function writeData(filename, data) {
    var lock = lockService.acquireLock(filename);
    if (!lock) {
        throw 'Failed to acquire lock';
    }

    try {
        var file = storage.readFile(filename);
        var updated = updateContents(file, data);
        storage.writeFile(filename, updated);
    } finally {
        lock.release();
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;非常不幸，纵使你有一个完美的锁服务，这块代码依旧存在问题。下面的图示会演示你如何遇到被损坏的数据：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/redlock-while-gc.jpg">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在这个例子中，客户端获取锁后，持有锁很长时间，比如：GC导致的暂停。分布式锁具有的超时，一般这会是一个好主意（毕竟如果一个客户端获取了锁，随后它崩溃了，这回导致锁一直不被释放）。然而在这种情况下，如果GC暂停时间超过锁的过期时间，并且客户端没有意识到它已经过期，如果此时锁已经被另一个客户端获取并完成了处理，那么当前客户端的继续执行就会造成问题。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这个Bug不是理论上的，HBase就曾发现有这个问题。一般情况下GC的停顿很短，但是stop-the-world形式的GC有可能会造成长达数分钟的停顿，这足以长到锁超时。虽然以并发收集而著名Hotspot JVM的CMS回收策略，也不能做到回收与应用代码同时进行，它也需要stop-the-world。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;你也无法通过在写会存储之前做持有锁的检查来解决这个问题。需要注意的是GC可以在任何时候暂停正在运行的线程，包括对你来说最可能发生的点（在检查和写入操作之间）。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果你认为可以选择使用没有运行时（或者说GC停顿）的语言来避免面对这个问题，那你需要知道还有很多情况让你的进程暂停。也许你的进程试图读取一个尚未加载到内存中的地址，结果在加载它的时候出现了页失效，从而需要等待从磁盘中加载。也许你的磁盘是使用的亚马逊的EBS服务，因此在亚马逊拥堵的网络上，读取变量无意中变成了同步网络请求。也许还有许多其他进程争夺CPU，而您在调度器树中遇到了一个黑色节点。也许有人不小心把SIGSTOP发送到了该进程。总之，运行的进程被暂停是无法避免的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果你还是不相信进程会被暂停，那么可以想象对存储文件的写请求出现了延迟。在网络上的传输的包出现了延迟，比如：重传导致。在Github出现的一次网络故障中，在网络中传输的包被延迟了大约90秒。这意味着应用实例在发送写请求时出现了延迟，但是锁已经过期释放，从而导致可能出现多个实例对存储的并行写。即使在管理良好的网络中，这种事情也可能发生。您根本无法对时间安排做出任何假设，这就是为什么无论您使用什么分布式锁，上述代码基本上都是不安全的原因。

## 使用令牌来提升锁的正确性保障

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;解决这个问题实际上也挺简单，只需要在向存储服务写时使用一个令牌即可，或者说乐观锁。在这个场景中，令牌可以是一个简单自增数字（通过锁服务提供），当获取锁时，如果获取成功，锁服务会返回一个令牌。该过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/redlock-with-fence.jpg">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Client1获取到了锁并同时得到了令牌33，但是在执行操作的时候，由于暂停而导致锁实质已经过期。Client2在Client1暂停期间（由于锁超时释放而）获取到了锁，同时获得了更新的令牌34，然后执行操作，将数据完成写入，也包括了令牌34。Client1随后恢复过来，然后开始尝试向存储写数据，同时包括之前获取到了令牌33。由于存储服务记得之前处理过一个令牌为34的请求，所以将会拒绝Client1的这次请求。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;请注意，这要求存储服务能够支持令牌的检测，在发生令牌倒退时，拒绝写入请求。一旦你知道了诀窍，这并不特别难。如果锁服务生成严格单调增加的令牌，这样能够充分的确保分布式锁的正确性。例如：如果你使用ZooKeeper作为分布式锁的底层，那可以使用zxid或znode版本号作为令牌，并且它们能很好的工作。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;回过头来看一下Redlock算法，它没有使用令牌来保证在出现进程暂停或者网络延迟时不出现问题。虽然这个算法看起来很不错，但是用起来不是那么安全，因为一旦出现了进程暂停或者网络延迟，客户端之间的数据竞争就会有出现的概率。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我没有完善Redlock算法，以期望其能够支持自增的令牌。这是有些难度的，如果使用随机值不会产生效果，而再一个Redis节点上完成自增计数可靠性又不高，因为这个节点可能失效，而在多个节点进行计算会导致需要进行同步，从而引入分布式共识算法来保证自增。

## 用时间来解决共识问题

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Redlock没有使用令牌，这也表明在对锁的正确性有依赖的场景不适合使用Redlock。但是这里有更多的问题值得讨论。理论上讲，一个更具有实践性质的算法应该是类似 asynchronous model with unreliable failure detectors 。简单的说，这意味着该算法对于时间（或者延迟）没有任何假设：进程被暂停任意时长，网络出现了任意时长的延迟，系统时钟之前出现了偏差，这些都不会影响到算法的正确性。鉴于我们之前讨论的问题，这是对于假设一个非常合理的要求。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 其实Redlock的问题所在，就是对时间的假设，带来可用性的同时，降低了正确性（或一致性）。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用时钟以及超时的分布式锁算法（比如：Redlock），其目的就是为了避免出现由于实例的故障导致死锁。但是超时往往不会那么精确，只是一次请求超时并不意味着对端机器（Redis实例）挂掉，因为这可能时网络上突然出现的抖动，或者本地时钟出现问题。使用超时作为故障检测的手段，只能获取一个大概的结果，也就是猜测对端可能出现了问题（如果可以的话，分布式算法完全没有时钟，但共识就不可能[10]。获取锁就像比较和设置操作，这需要达成共识[11]）。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;需要注意Redis使用了gettimeofday函数，而非monotonic clock来判定是否过期。根据gettimeofday的说明文档表明，它返回的时间可能会出现跳转——也就是说，它可能会突然向前跳几分钟，甚至跳回时间（例如：如果时钟因与NTP服务器差异太大而由NTP介入，或者如果时钟由管理员手动调整）。因此，如果系统时钟正在做奇怪的事情，很容易发生Redis中KEY的过期速度比预期要快得多或慢得多的问题。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) monotonic clock是以系统启动时间开始计算的，它不受时钟调整的影响，是一个严格单调递增的时钟序列。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于异步网络模型中的分布式算法来说，这不是一个大问题：这些算法通常确保其正确性，而不做出任何关于时间的假设[12]。只有可用性要求依赖于超时或其他故障检测器。简单的说，这意味着即使系统中的计时到处都是（进程暂停、网络延迟、时钟向前和向后跳跃）问题，就算算法的性能糟透了，但算法永远不会做出错误的决定。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;然而Redlock不是这样的，其正确性取决于它对于时间的多个假设：它假设所有Redis节点上的相同KEY在过期时间上大致相同；网络延迟相对于过期时间短很多；进程暂停比过期时间短得多。

## 使用糟糕的延迟让Redlock失效

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;让我们看一些例子来证明Redlock对时间假设的依赖。假设系统有五个Redis节点（A、B、C、D和E）和两个客户端（1和2）。如果其中一个Redis节点上的时钟向前跳动会发生什么？

1. 客户端1获取了节点A，B，C，由于网络问题，D和E不可达
2. 在节点C上的时钟出现前跳，导致C上的锁过期
3. 客户端2获取了节点C，D，E，由于网络问题，A和B不可达
4. 客户端1和2，在这一时刻，都获得了锁

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果节点C在将锁持久化之前崩溃了，并重新启动，也可能会发生上述问题。在Redlock算法文档中，建议节点重启时进行延迟，以期望锁能够过期，但是这种重启延迟还是讲问题抛给了时间，如果处理不当，还是会出现问题。当然，如果你认为时钟的跳跃是难以发生的，因为在数据中心里已经配置好了NTP，并保证其服务质量。基于这个假设，我们看一下如果进程暂停，是否也会导致失败：

1. 客户端1在A，B，C，D，E节点上获取锁
2. Redis实例都返回获取成功，但响应在客户端1网口开始排队时，客户端1发生fullGC，出现了暂停
3. 锁在所有的Redis实例上过期
4. 客户端2获取A，B，C，D，E节点上的锁
5. 客户端1的GC完成，并收到延迟后的响应，根据响应判断客户端1获取到了锁
6. 客户端1和2都认为获取到了锁

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;虽然Redis时用C实现的，它不存在GC，但是对当前问题没有任何帮助，因为客户端可能是使用了有GC特性的语言编写的。如果想要在这种情况下保证正确性，就一定要在客户端2获取到锁后，客户端1不会执行相关操作，而解法就可以使用前面提到的令牌方式。网络延迟（TCP窗口排队）也可以产生与进程暂停相同的问题。

## Redlock基于同步的假设

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Redlock需要在同步系统模型的假设下才能正常工作，所谓同步系统模型有以下特性：

1. 有界网络延迟（您可以保证数据包总是在有保证的最大延迟内到达）
2. 有届进程暂停（换句话说就是强实时约束，就像汽车上的安全气囊一样及时）
3. 有界时钟错误（祈祷不会从有问题的NTP服务端获取时间）

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;需要注意的是同步系统模型并不是意味着节点的系统时钟完全同步，只是意味着你假设了一个网络延迟、进程暂停以及时钟偏差的上限[12]。Redlock算法假设这些延迟和偏差要远小于过期时间（TTL），如果这个时间假设长于过期时间，该算法就会失效。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在网络环境很好的数据中心内，对于时间的假设基本上都能够满足，这就是partially synchronous system [12]。但是这样就够了吗？只要时间的假设被推翻，Redlock算法就不能够保证其正确性，会出现一个客户端获取了一个过期（但被另一个客户端认为其持有的）锁。如果你需要锁具有最大程度的正确性，那么基本上这个假设就是不足够的，你需要的确定性的正确性。在同步网络中可以运行的模式或者假设在部分同步网络中不适用已经有了很多例子[7,8]。提醒自己不要忘了Github的 90-second packet delay 故障，同时Redlock很大可能无法通过 Jepsen测试。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;另一方面，使用了为部分同步网络（或者带有故障检测的异步网络）而设计的共识算法对解决这个问题是有帮助的。Raft、Viewstamped Replication、Zab和Paxos都属于这一类算法。这种算法必须放弃所有对于时间的假设。很容易假设网络、进程和时钟比实际更可靠，但在分布式系统这种不可靠的环境中，你必须非常谨慎地对待你的假设。

## 结论

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我认为Redlock算法是一个糟糕的选择，因为它不伦不类，完全不必要的重量级解决方案以及昂贵的实施代价，但是花了这么大的代价却无法兑现足够的正确性保障。尤其是该算法作出了关于时间和系统时钟有危险性的假设，而这种假设一旦不被满足，将会对其正确性带来损失。此外，它还或缺一个令牌生成的装置，用来最终确保算法不会收到网络延迟和进程暂停的影响。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果你只是关注锁的效率，我建议你可以直接使用单节点的Redis来实现 straightforward single-node locking algorithm ，并且在文档中说明，该锁能够提供近似正确的分布式锁服务，可能存在偶尔的失败，而不是使用一个至少需要 5个Redis节点的Redlock。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果你关注锁的正确性，那就不要使用Redlock，使用一个适合的共识系统，例如：zookeeper，通过一些组件，比如： Curator recipes 的支持（甚至它已经实现了一个分布式锁）来实现分布式锁。还需要确保底层存储都支持令牌。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 发消息怎么办，清理缓存怎么办，这些都是存储服务，让其底层支持令牌，不切实际。如果存储都支持令牌了，那么要锁干什么，其实看来这个令牌也没什么价值，只是把问题转嫁给了后续流程。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;就像我开始说的，Redis如果用在正确的场景中，是一个非常出色的工具。上述所有的观点都没有降低Redis本身的成绩。 Salvatore 在Redis这个项目上工作了很多年，它的成功是理所因当的，但是任何工具都有它的局限性，识别它们以及用好它们更加重要。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果你更深入的了解这些问题，我在 chapters 8 and 9 of my book 做了更深入的阐述。如果想更深入的了解zookeeper，我推荐 Junqueira and Reed’s book [3]。对于分布式系统如果需要更好的了解，我推荐Cachin, Guerraoui and Rodrigues’ textbook [13]。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;谢谢 Kyle Kingsbury, Camille Fournier, Flavio Junqueira, 和 Salvatore Sanfilippo 的校审。

 &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;更新自2016年2月9日：Salvatore,Redlock的作者，也是Redis的作者，他发表了一片文章来反驳我的观点。他有一些论点是不错的，但是我还是坚持我的结论。如果有时间我会更加详细的阐述这个问题，但是请你自己能够有主意，当然你可以参考我的引文，大多数都是严谨的学术文章，它们更加可信。

 ## 参考引用

 [1] Cary G Gray and David R Cheriton: “Leases: An Efficient Fault-Tolerant Mechanism for Distributed File Cache Consistency,” at 12th ACM Symposium on Operating Systems Principles (SOSP), December 1989. doi:10.1145/74850.74870
[2] Mike Burrows: “The Chubby lock service for loosely-coupled distributed systems,” at 7th USENIX Symposium on Operating System Design and Implementation (OSDI), November 2006.
[3] Flavio P Junqueira and Benjamin Reed: ZooKeeper: Distributed Process Coordination. O’Reilly Media, November 2013. ISBN: 978-1-4493-6130-3
[4] Enis Söztutar: “HBase and HDFS: Understanding filesystem usage in HBase,” at HBaseCon, June 2013.
[5] Todd Lipcon: “Avoiding Full GCs in Apache HBase with MemStore-Local Allocation Buffers: Part 1,” blog.cloudera.com, 24 February 2011.
[6] Martin Thompson: “Java Garbage Collection Distilled,” mechanical-sympathy.blogspot.co.uk, 16 July 2013.
[7] Peter Bailis and Kyle Kingsbury: “The Network is Reliable,” ACM Queue, volume 12, number 7, July 2014. doi:10.1145/2639988.2639988
[8] Mark Imbriaco: “Downtime last Saturday,” github.com, 26 December 2012.
[9] Tushar Deepak Chandra and Sam Toueg: “Unreliable Failure Detectors for Reliable Distributed Systems,” Journal of the ACM, volume 43, number 2, pages 225–267, March 1996. doi:10.1145/226643.226647
[10] Michael J Fischer, Nancy Lynch, and Michael S Paterson: “Impossibility of Distributed Consensus with One Faulty Process,” Journal of the ACM, volume 32, number 2, pages 374–382, April 1985. doi:10.1145/3149.214121
[11] Maurice P Herlihy: “Wait-Free Synchronization,” ACM Transactions on Programming Languages and Systems, volume 13, number 1, pages 124–149, January 1991.doi:10.1145/114005.102808
[12] Cynthia Dwork, Nancy Lynch, and Larry Stockmeyer: “Consensus in the Presence of Partial Synchrony,” Journal of the ACM, volume 35, number 2, pages 288–323, April 1988. doi:10.1145/42282.42283
[13] Christian Cachin, Rachid Guerraoui, and Luís Rodrigues: Introduction to Reliable and Secure Distributed Programming, Second Edition. Springer, February 2011. ISBN: 978-3-642-15259-7, doi:10.1007/978-3-642-15260-3