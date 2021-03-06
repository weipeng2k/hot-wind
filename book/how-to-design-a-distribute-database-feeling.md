# 《如何设计一个分布式数据库》观后感

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;看了**PingCAP**的CTO（**黄旭东**）的分享[如何设计一个分布式数据库](https://www.bilibili.com/video/BV1vs411g7Fd)，感觉要写点文字记录一下自己的感想。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**TiDB**在分布式数据库上是一个新贵，虐了不少号称水平扩展能力很好的友商产品，比如：[查询10倍以上的性能虐了OceanBase](https://blog.csdn.net/jiashiwen/article/details/117803689)，那么为什么会有这么大的差距？我想看完了黄旭东的分享后，他极客的做法和思考，也就对**PingCAP**能够打造出碾压平凡人的产品感觉很自然了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**黄旭东**的分享没有细节到分布式数据库如何去做，但是谈了作者的取舍。分享没有涉及到分布式数据库运作细节，但是谈了作者的知识结构以及需要掌握哪些分布式知识。

> 在介绍分享的过程中，会增加笔者自己的所得。
>
> 如果是笔者的理解将会以 ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png)来开头，以引言的形式来展示。

## 为什么要`NewSQL`

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/how-to-design-a-distribute-database/large-data.jpg" width="70%">
</center>

* 数据量级增长的越来越快

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 对于过程和行为数据的广泛收集，目的是更加细致和准确的了解用户。以往在系统建模上，过程数据不会过多的保留，或者以某些实体的属性存在，但现在对于用户所有操作行为的数据都需要加以建模和记录，目的就是更加完整的建立用户画像。
>
>一个很小的业务，如果对于用户的操作能够细致的建模和存储，其实数据量级也不会很小，比如：一个健康记录程序，以往可能记录每天的身体状况，但是如果把用户每个时段的身体状况都通过装置进行存储，那无疑会使数据量增长好几个级别，如果善用存储下来的数据，将会给用户带来更加细致的指导意见。
>
> 从`TB`级别到今天的`PB`和`EB`级别，数据的膨胀只会随着`IoT`的更加普及而变得愈来愈多。传统的关系数据库面对这种量级的数据，自身由于单体部署约束，导致无法应对海量数据的存储和使用。这个过程中，通过传统关系数据库的上层策略（比如：分库分表）可以一时的解决部分问题，但是数据对于业务的侵入（比如：分库键等）以及对限制（跨库查询等）总会使人用起来有些不快。这时`NoSQL`的出现缓解了这个问题，通过注重于水平扩展和无限存储（权且这么叫），再加上不错的性能，使得它虽然从开发人员手中拿走了一些东西（比如：额外的学习、新增的概念以及些许简陋的功能），但是它还给开发人员手中的好处确实让人兴奋，因为它解决问题。
>
> 而结合了`NoSQL`以及`SQL`的`NewSQL`的出现，是否能够给到开发人员以全新的体验，这不仅是在功能上，而且会在设计范式以及解决问题的模式上再一次带来改变。

* 传统的`RDBMS`在水平扩展上存在不足

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 这点就是传统的关系数据库的问题，毕竟诞生的年代是在单体时代，一个单体才能够很好的兑现ACID，而在分布式环境下，受限于CAP原理的约束，很难做到，在那个时代无异于自讨没趣，没有需求。因此在那个时代的产物，兑现要求，完善的工具链，更为重要。
>
> 要水平扩展，就是要CAP中的P，而P一旦满足，C和A总是那么不好拿捏。这些年业务的发展还是在使用传统关系数据库，毕竟使用量大、易维护和功能全，实在不够就在上层搭建一些路由层，以中间件的形式解决一下。但是这种方式面对扩容时都会有些不容易，毕竟相关的操作向前侵入了业务，向后牵扯了运维（需要理解一定业务规则），中间还夹着一个中间件团队，说白了，就是不透明。

* `OLTP`与`OLAP`相互割裂

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 这点是比较有意思的，由于OLTP无法做一些大量的分析型工作，而分析的结果又要向用户透出，结果研发又不愿意承担这个工作，甩锅给数仓团队，就造成了`OLTP`拉出来的数据，通过`ETL`倒腾到`OLAP`，绕一圈再送回到`OLTP`的嘴里，展现给用户。
>
> 这么做的坏处那是太多了，研发团队负责一块业务，数仓又是横向对多个团队，中间就会出现GAP，这里的GAP不仅是技术上的，也有在业务认知上的，导致产出的数据总是差那么些火候，用在关键场景（比如：根据金额判断某个用户，这一时刻，能不能做某些事情），就是不能用，其实就是有偏差。这里的偏差来自于之前说的理解偏差，也有技术造成的偏差，如果用的是离线计算的那种落后技术，差的就不是一星半点了（毕竟数据一天可能变了N次吧）。
>
> 人员、认知和技术的割裂就这么一直搅着这个问题，有数据研发能力的业务技术团队可以解，有超人般的数据团队也可以解，但事实上都不会有。如果能够一份数据存储，又能提供良好的`AP`功能，这种`HTAP`数据库就会好一些了，能够减少一些割裂。为什么说好一些，而不是好多了，原因是在于不可能通过这样一种形式就能解决好实时分析数据获取这件事，能解决2-3成就已经功不可没了。

## `Google Spanner`/ `F1` / `Amazon Aurora`

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/how-to-design-a-distribute-database/google.jpg" width="50%">
</center>

* F1是SQL层，Spanner是NoSQL

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/how-to-design-a-distribute-database/spanner-f1.png" width="50%">
</center>

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) `F1`是一个逻辑处理层，负责将关系数据库的`SQL`进行解析，将`SQL`翻译为`Spanner`可以理解的一系列指令，然后指令下达给`Spanner`，由它来完成数据的操作。谷歌的`F1`和`Spanner`论文需要了解一下。
>
> [F1的论文](https://www.researchgate.net/publication/262403895_F1_A_distributed_SQL_database_that_scales)
>
> [Spanner的论文（含翻译）](http://dblab.xmu.edu.cn/post/google-spanner/)

* Aurora替换了存储引擎

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 以`MySQL`为基础，替换了存储引擎，比如：将`InnoDB`替换为一个具备了分布式水平扩展能力的存储引擎。不愧是具备了电商基因的云厂商，这无疑是一种见效快的方式。
>
> 如果是一般云厂商，大概率都会使用这种方式，因为用户的编程界面不用改，但是它也会有很多限制，而像谷歌那种颠覆性的做法不常见，因此也能感觉其难能可贵。

## `TiDB`总揽

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/how-to-design-a-distribute-database/tidb-architecture.png" width="70%">
</center>

* TiDB的基本架构如上图所示

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 底层的分布式存储层解决的是KV存储问题，如果对一般的KV存储，其实也可以使用`Redis`，但是`TiDB`要求的是分布式，因此就需要一个能够在分布式环境下工作的KV存储。
>
> `TiKV`也是单独的项目，[TiKV](https://github.com/tikv/tikv)。多个实例间通过`Raft`一致性算法，将写入数据能够完成多写，做到高可用。这里底层没有使用分布式文件系统，比如：[`Ceph`](https://www.bookstack.cn/read/ceph_from_scratch/architecture-papers.md)，`HDFS`，原因是如果再使用分布式文件系统，那么数据就会写的更多。`Raft`的3份，文件系统的3份，写9份，因此从效率和经济角度出发，TiKV底层就没有使用分布式文件系统来构造。
>
> `TiDB`通过`gRPC`来请求TiKV，目前来看gRPC是要做到终端到服务端，服务端到服务端以及服务端到终端的全通信工具。`gRPC`的代码（Java版本）在2017年左右看过，写的其实很一般，比较粗糙，没有分层，就更不要提层与层的抽象隔离了，但是架不住谷歌这么一直推动。推动是多方面的，一是谷歌背书和不断的更新，二是基于它来叠罗汉，就是涉及到通信的谷歌产品都会使用它，形成了合力，使得很多开源产品也首要支持它，这点值得很多技术公司学习。
>
> 整个架构看起来很清晰，职责分离明确，伸缩性应该非常不错。无状态SQL层负责计算，而分布式存储层负责存储，状态数据在`PlacementDriver`。
>
> 黄旭东的另一个作品，[codis](https://github.com/CodisLabs/codis)。一个`golang`实现的`Redis`集群代理，能够组建`redis`集群。看了一下，使用方不少，关注度不错。

## 存储总揽

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/how-to-design-a-distribute-database/tikv-architecture.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`TiKV`的基本架构如上图所示。客户端通过`gRPC`访问`TiKV`集群，每个`TiKV`节点都是一个进程，运作在一台计算实例上，在`TiKV`内部将存储进行了`Region`分区，切割成为面上使用者的大小以及适合访问的形态，外部通过`Raft`协议将一次写入能够写到多个`TiKV`节点上，借由此来提升整体可用性。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 存储引擎的数据结构基于`LSM Tree`，日志结构化合并树，这是一种对随机添加更为友好的数据结构。相比较`B+树`，它的随机访问能力更好，而`B+树`是更加适合磁盘的访问形式，在SSD这种场景下，效率并不高。关于`LSM Tree`可以[参考文章](https://blog.csdn.net/baichoufei90/article/details/84841289)。
>
> 每个`TiKV`实际是使用了单机的KV存储引擎—`RocksDB`，这个是脸书基于谷歌的`LevelDB`的改进版本，修复了不少问题，同时`PingCAP`也对`RocksDB`有捐赠源码（包括问题修复）。
>
> 任何分布式的装置都是建立在完善的单机装置上的，基于宏观上可靠的策略，将其形成为一个容易伸缩且高可靠的整体解决方案。`TiKV`的整体代码是使用`Rust`编写，这个新一代的系统编程语言是值得关注的。未来在底层高性能软件上可能会越来越多的看到`Rust`的身影，而系统软件和应用软件之间的中间件将会看到更多的`golang`。

## `TiDB`中的SQL生命周期

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/how-to-design-a-distribute-database/tidb-sql.png" width="50%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;外部请求发起方依旧是`MySQL`客户端，`TiDB`会伪装成为一个`MySQL Server`。当`TiDB`收到`SQL`时会进行语法树解析，生成执行计划，这点和`MySQL Server`工作的步骤有些类似。但是在最终的逻辑执行计划会生成出可选的物理计划，比如一个`SUM`会发给几个物理节点进行执行，最终会进行所有结果集的`SUM`。之所以要做这么一个`SQL`层，就是要将`SQL`和后端的分布式存储层能够联通。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 对于语法解析这段内容，想象中可以照抄`MySQ`L的，但是`PingCAP`并没有这么做，而是抛弃遗留代码，自己做了，目的是在中间能够加入一些自有的优化，同时为解析出来的结果同物理执行计划之间充分分隔开，很有胆略。
>
> 一个概念意义上的SQL输入，最终被翻译成为一组分布式计算的指令。

## 注重测试

* 测试驱动开发

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) TiDB整体项目的单测覆盖率是非常高的，行覆盖在80%左右，很不容易了。黄旭东对于单测的看法比较注重，强调单个构件的可靠性，这点是做高质量软件的必由之路。
>
> 对于任何问题，需要在单测或者测试场景上进行复现，然后通过不断的回归测试来确保正确，同时使用社区的非常多测试样例，保证其测试的覆盖面。
>
> 非常多的开发者对于单测总是忽略，这是一种非常不成熟的表现，很难保证你写出考究的代码。

* 故障注入

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 在软/硬级别进行故障的注入，验证该环境下TiDB的工作是否能够达到预期（或者正常）。包括对磁盘、网络、CPU和时钟等多种环境的调整以及故障预设，使TiDB工作在环境不稳定的场景中，发现问题，加以改善。

* 分布式测试

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 介绍了`Jepsen`和`Namazu`两款测试软件，搜了一下，基本都和PingCAP有关，看到的是其实习生写的分享，实习生后来还去了阿里云的数据库团队。。。
>
> 看样子PingCAP对内部分享也非常在意，有点学院的意思。
>
> 分布式测试之前没有接触过，更多的单元、功能、集成、性能。。。那些传统的测试。
