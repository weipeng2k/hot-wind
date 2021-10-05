# 基础Paxos算法的9页笔记

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Paxos**算法是[**Leslie Lamport**](https://www.microsoft.com/en-us/research/people/lamport/)发明的一种基于消息传递，用于解决分布式环境下共识的算法。所谓分布式环境下的共识，是指在分布式多节点环境下，如何让不同的节点就某个值达成一致的算法（或者策略），而达到这一点，需要能够可靠的应对分布式环境中出现的各种不确定性和故障。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/greece-paxos.jpeg">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Lamport**寄期望模拟一种民主议会制度来让分布式环境中的多个节点达成共识，因此假设了一个叫做**Paxos**的希腊城邦，而该城邦通过民主议会制度来解决问题，这个制度就是分布式共识的解法，而这个解法（或算法）就用该城邦的名字来命名，这也是**Paxos**的由来。

## 关于**Paxos**算法

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本文是在阅读了**Lamport**的《Paxos made simple》、Wiki百科对于Paxos的介绍以及一些博主分享的基础上所形成的。文中包含了笔者思考的过程，**Lamport**对于算法的描述是偏数学的，所以需要自己不断的做延展和梳理，否则很容易被他有些不切实际的言语带偏，比如：*议员认为收到了提案，等待最终的批准，但之前有人提出了设置的值，请查看*，什么是最终的批准，之前的值该怎么判定，这些内容都需要读者自己理解，所以不同人理解的**Paxos**在主链路上会基本一致，但到了细节，就会不一样这也是大家认为**Paxos**晦涩难懂的原因之一。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们读懂一个算法，目的是用它解决问题，这需要工程化的思考。笔者认为**Lamport**的工程能力不会很强，而且他对其数学表达有一种优越感，可能因为他是数学专业的。相比较而言，他没有**Doug Lea**那种学术和实践两开花的水平，所以在阐述**Paxos**时，他没有讲明它的主要数据结构有哪些，状态有哪些，所以就会造成工程实现**Paxos**一定是具有二义性的，因为它会融合工程实践者自身的一些思考在其中。

> **Raft**算法对于数据结构和算法的描述就会比较到位，不同人实现的会基本类似。**Raft**算法也是解决分布式共识问题的，它被开发出来的原因是为了让大家更好的理解**Paxos**算法。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;那为什么还需要了解和掌握**Paxos**算法呢？**Google Chubby**的作者**Mike Burrows**说过，*这个世界上只有一种一致性算法，那就是**Paxos**，其它的算法都是残次品*。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看出该算法对于分布式环境下的共识问题，是具有里程碑意义的。这好比我们定义了食物的功能是什么？当然食物的种类千千万，谁先说出最基本的东西，没有人会不承认它的重要性，因为它解决和阐明了大家都能看到的、最基本和最核心的问题。不是说这个问题有多难，而是人家就是**很早**阐述清楚了，而这是你的必由之路，你就得拜师，有点这个意思。因此，对于分布式共识是我们需要理解和掌握的，而**Paxos**算法是无法回避的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Lamport**认识到**Basic Paxos**的低效，在**Basic Paxos**基础上提出了**Multi Paxos**和**Fast Paxos**，这两种变体，用于减少算法中的消息传递次数，提升算法效率。本文不涉及这两种算法，只会集中在**Basic Paxos**。

## 基础**Paxos**算法笔记

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本文阐述的内容基本和《Paxos made simple》一致，但会增加一些笔者的思考、示例和推导，是**Paxos**的学习笔记。

### 第一页

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;第一页笔记主要说明共识和一致性的关系，以及**Paxos**算法的主要构成角色和角色的相关职能。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;关键词：**共识**、**一致性**、**分布式通信**和**Paxos算法角色**。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-note-1.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Paxos**算法是一种共识（Consensus）算法，而非一致性（Consistency）算法。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们常见认知中，认为**Paxos**就是一个能够解决一致性的神奇东西，但是它并没有那么强大，它只是一个算法策略，没有一点工程化的能力，而一致性才是工程需要考虑的问题。可以认为：一致性是一个目标，是我们在分布式环境中追寻的一个目标，而要在分布式环境中达成这个目标，就需要（分布式环境中的）多个节点，它们能够形成共识，拟人的话就是：*对某件事情有一致的看法*。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这里的共识就是一种手段，因此利用共识可以达成一致性，它们的关系如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/consensus-consistency.png" width="50%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在共识之上，实际可以做很多应用场景，共识是基础，也是一种工具。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果要在分布式环境中需要形成共识，那就一定需要（分布式环境中的）各个节点能够进行通信，否则那就是玄学。分布式通信方式主要有两种，一种是共享内存，一种是消息传递，前者可以认为通过远程网络让各个计算节点共享一块内存，从而做到如同单个机器中的数据交换一样，只需要做好并发控制，就能实现多机互通，而后者使用消息的方式在多个节点之间传递信息，而这种异步，看似不可靠的方式实际是分布式通信常用的方式。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;消息传递是异步的，也就代表了多节点之间不用过度考虑相互依赖，使得整体系统的体系结构变得简单且容易实施。消息由于在传输中会出现延迟、丢失和重投，这些由于网络不可靠的带来的问题其实不仅困扰着消息传递这种通讯方式，实际也会给对任何分布式通信带来麻烦，只是消息通信从一开始就要考虑这些问题。面向失败设计，以应对消息传递中的问题以及节点出现的故障。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;共识可以简单的认为是分布式环境中各节点就某一个值达成一致。你没有看错，就是这么Low，论文里就是这么写的。但实际是这个值可能是一个字符串的值，也有可能是一条日志记录或者是一个文件。如果共识针对的值是一条日志，那么多个节点就对日志的顺序和内容产生共识，理解一致，如果将日志在不同节点进行回放，那么就算节点是一个复杂的系统，也不会导致出现不同状态的节点。如果这么说，就会觉得共识有点作用了吧？原本的论文没有提到应用，所以就做了一个值的比喻，因此会看的没有什么感觉。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Paxos**是**Lamport**虚构的一个希腊城邦，它实行西方人最崇尚的民主议会制度，而这个民主议会制度就是**Paxos**共识算法，可见**Lamport**将该算法拟人化了，也从侧面证明了他对该算法非常喜爱。在算法中，每个分布式中的节点被城邦中的议员代替，普通的民众通过将自己的想法（也就是设置值的请求）提供给议员，由议员提交到议会进行讨论，议员们在议会中讨论这个提议，并形成大家认可的决议。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于议员可以响应民众，也可以提起提议，更能够参与决议的表决，这么多职责很难形式化到算法中，所以**Lamport**认为议员实际上是有角色之分的。议员的角色包括：提议者、接受者和学习者，它们的名称和基本职能见下表：

|角色|名称|职能描述|
|----|----|----|
|**Proposer**|提议者|接收请求，发起提议|
|**Acceptor**|接受者|讨论提议，形成决议|
|**Learner**|学习者|接受决议，发送响应|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;一个议员可以身兼多个角色，这代表一个节点可以干多种事情，从侧面上看不同角色的特定属性不会设置在议员身上，而是和角色相关联。

### 第二页

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;第二页笔记探讨了主从结构和**Paxos**算法角色的关系，以及算法中的提案信息结构和批准过程。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;关键词：**主从结构**、**提案**、**决议**和**批准过程**。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-note-2.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Paxos**算法的过程是由**Proposer**提出提案，**Acceptor**讨论提案形成决议，可见如果决议是一次被多节点承认的变更，那么该决议对应提案的提出则是数据变更的入口。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果数据变更的入口是集中的，也就是一个人说了算，那么这个结构就是简单的，比如：主从模式（*Master-Slave*）。

> *主从模式*是分布式环境中一种常见的节点拓扑关系，它常见于数据存储层，如：**Mysql**的主从模式，通过将写请求统一派发给唯一的主节点，同时将读请求离散派发到多个读节点，而数据变更首先流入到主节点，然后再异步复制到读节点，通过大量的读节点（在可以容忍极小延迟的情况下）来提升系统吞吐量。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;主从模式通过将写收敛到一个节点来达成共识，如果用**Paxos**算法角色来描述主从模式，那么也就是`Master = Proposer + Acceptor`，数据变更发起以及生效，在一个节点。如果主从模式的写会发生在多个节点，主从模式将无法工作，因为无法判定各个节点中的变更，哪些是被多节点所认可的，会出现数据混乱。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;有同学会问：*单元化是不是可以解决主从结构这种只有单点可写的问题呢？*

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**单元化**是一种按照业务领域（比如：用户ID）分区的技术，它将部分业务数据的写控制在某一个单元（一批机器，一般在一个机房中），但数据的写也还会同步回其他单元，通过使用多单元的形式，让全量机器都参与工作，提升利用率（不用冷备模式）的同时，也提升了可用性（通过切换单元的方式），其概念如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/unit-write-mode.png" width="50%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;实际仔细看**单元化**，它也是主从模式的一个变体。因为它将可以预见的一种模式的写，比如：用户ID按10取模为5的写请求，派发到固定的机器上，通过添加了这层路由，使得写吞吐量变大，但每个单元内还是主从结构。这种技术方案只是在原有**主从模式**基础上，做了一个**集群版**，并没有真正的解决多节点写的问题。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**数据变更请求 = 写请求 = 提案（Proposal）**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Paxos**算法将一个写请求抽象为**Proposal**，如果将**Proposal**就视为请求的内容，也就是一个值，那多方一起写，就无法区分先后，这属于给自己找麻烦，毕竟写的发起是对方，但写的协议我们是可以控制的。因此，**Proposal**可以包含两个部分：编号和值，前者可以理解为一个全局唯一且顺序的编号，后者就是变更请求的内容。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;当**Proposal**通过了多数**Acceptor**的表决同意后，**Proposal**就通过了，形成了多个节点认可的内容，我们可以称为决议（**Resolution**）。

> 决议来自于提案，但高于提案（被多方认可）。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Proposal**批准的过程可以看笔记中的示例，多个**Proposer**可以提出**Proposal**，然后不同的**Acceptor**进行表决，如果某个**Proposal**得到多数**Acceptor**的支持，那么该**Proposal**就成为**Resolution**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;以*P1*提案为例，一个**Proposer**提出**Proposal**，*P1*到议会讨论，总共有三位**Acceptor**，它们接受了该**Proposal**，从而使**Proposal**成为**Resolution**。从这里可以看出，**Proposer**想要提案通过，它必须知晓有多少个**Acceptor**，也必须将**Proposal**发给多数的**Acceptor**寄期望它能够得以通过。

> 发往多数的**Acceptor**是论文中始终扭扭捏捏没有正面说明的，可以想象，如果你不知道这个约束，你就会认为**Paxos**算法是个神仙算法，随便一发，怎么就多数了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于提案编号没有重复，这可以理解，但提案产生的一刻会出现重复吗？也就是说不同的**Proposer**接收到不同客户端的并发请求后，会自然的获取到不同的提案编号，还是会获取到一样的提案编号呢？如果注意力集中在编号唯一的约束上，可能会认为获取到不同的提案编号，一定是**Paxos**算法要求一个单点的编号生成器，但你通读论文都不会找到它，因为实际是后者，你会看到相同的编号，只是在提案阶段，而最终成文的决议，它一定是唯一的。相同编号的提案一定会在多个**Acceptor**之间产生角逐和竞争，然后通过一个提案，另外一个，只能再来一遍提案批准流程。

> 但另外一个提案会看到前一提案形成决议的结果。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;至此，我们对于提案批准过程有以下（没有在论文中提到的）隐含约束：

* **隐含约束1**. **Proposer**知晓所有的**Acceptor**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这样它能够发起有意义的提案，也能判定自己的提案是否得到多数人的支持；

* **隐含约束2**. **Proposal**的编号会产生重复

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;因为它的生成需要结合相应**Proposer**的状态信息，而批准过程会使之去重。

### 第三页

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;第三页笔记讲述了**Acceptor**接受提案的逻辑，以及相应的逻辑约束。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;关键词：**Acceptor**、**接受提案**、**提案**和**时间**。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-note-3.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Proposer**提出提案，**Acceptor**进行批准，该怎样批准呢？如果是节点之间进行相互协商，那么可以肯定，这是一个复杂的过程，最好**Acceptor**之间不要进行通信，而是按照一致的批准策略进行提案的审批。提案包含了编号和值，可以想象，一定是在编号上做文章，那么这个批准策略，可以是如果是更大（或更小）的提案，就一定会通过。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;论文中没有明确描述批准策略的步骤，而是先给定了约束。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**约束1**. 一个**Acceptor**必须接受第一次收到的提案。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**约束2**. 一旦一个具有Value的提案被批准，那之后批准的提案必须具有Value。

> 这两个约束感觉不知所云，**Lamport**在自嗨，没有顾及到普通的读者，所以需要翻译一下。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Acceptor**接收到一个提案，如果是第一次收到提案就会接受该提案，实际可以认为**Acceptor**能够识别出哪些提案它以前收到过，哪些提案它没有收到过。如果**Acceptor**能够进行识别，那它一定是有状态的，它至少记录了提交给它的所有提案，如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/approve-proposal.png" width="50%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Acceptor**集群中，每个**Acceptor**都会记录自己收到的提案，如果只有一个**Acceptor**，在**Paxos**算法中，它一定会记录到所有的提案，但如果是多个**Acceptor**呢？那一定是各记录各自的提案，但是所有**Acceptor**的知识一定可以反映出所有的提案，只是在某一个**Acceptor**中，只有部分提案而已，如拼图一样，通过拼接，就可以得到完整的图画。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Lamport**在**约束2**的基础上，做了增强。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**约束2a**. 一旦一个具有Value的提案被批准，那之后的**Acceptor**接收的提案必须具有Value。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**约束2b**. 一旦一个具有Value的提案被批准，那之后的**Acceptor**接收的提案必须具有Value。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**约束2c**. 如果Value V的N号提案提出，多数**Acceptor**要么没有接收N-1号提案，要么接收的最近一个提案（在N-1号之前）包含有Value V。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到**约束2a**将约束推到了决议讨论阶段，而**约束2b**进一步反推到了提议阶段，也就是一旦满足**约束2b**，那就一定会满足**约束2a**，可以将**约束2a**称为**约束2b**的必要条件。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;理解**约束2**及其变体，需要从时间角度去看，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/proposer-submit-proposal-timeline.png" width="50%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，从一个**Proposer**角度去看，如果其提案被批准形成了决议，则之后再次发起提案时，以往的决议将能够被**Proposer**所见，且不仅限于该**Proposer**可见自己提出的提案（或决议），只要是决议，就算是其他**Proposer**提出的，也是能够可见的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;以数据库事务中事务隔离级别去思考这个问题也是可行的，比如：读已提交隔离级别，就和该约束有些含义上的共通点。至于**约束2c**，实在有些高不太清楚想表达什么意思，先放在这里吧。

### 第四页

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;第四页笔记讲述了**Proposer**发起提案的约束，以及**Paxos**算法的两个阶段和相关流程。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;关键词：**Proposer**、**发起提案**、**准备阶段**和**批准阶段**。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-note-4.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Proposer**知晓所有**Acceptor**的存在，同时每次发起提案时，会将提案发往多数的**Acceptor**。可以看到**Proposer**会有**Acceptor**列表，同时该列表会不断的（随着**Acceptor**启停而）更新，同时在发起提案前，会从可用的**Acceptor**列表中找到一个多数的子集用于发送提案。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这里会涉及到**Acceptor**的注册发现诉求，如果动态新增一个**Acceptor**，那么所有**Proposer**的**Acceptor**列表中就会出现该元素，这样当然体感会好很多，但是这超出了本文讨论的范畴，可以认为每个**Proposer**静态的设置了一批**Acceptor**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Lamport**针对**约束1**做了增强。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**约束1a**. 当且仅当**Acceptor**没有回应过提案编号大于`N`的**Prepare**请求时，**Acceptor**才接受`N`号提案。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从前文中可以看到**Acceptor**拥有提案列表属性，因此可以在收到提案的**Prepare**请求后，检查当前提案列表中最大的提案，如果最大的提案编号小于收到提案编号，则回复**Proposer**已接受该提案。这里提到的**Prepare**请求，是在**Paxos**算法中的准备阶段进行的，算法将一次提案的批准过程分为两个阶段：准备阶段和批准阶段，论文中如下描述：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过一个决议分为两个阶段：

* **准备阶段**
    - **Proposer**选择一个提案编号n并将**Prepare**请求发送给**Acceptor(s)**中的一个多数派；
    - **Acceptor**收到**Prepare**消息后，如果提案的编号大于它已经回复的所有**Prepare**消息(回复消息表示接受**Accept**)，则**Acceptor**将自己上次接受的提案回复给**Proposer**，并承诺不再回复小于n的提案；
* **批准阶段**
    - 当一个**Proposer**收到了多数**Acceptor(s)**对**Prepare**的回复后，就进入批准阶段。它要向回复**Prepare**请求的**Acceptor(s)**发送**Accept**请求，包括编号n和根据**约束2c**决定的value（如果根据**约束2c**没有已经接受的value，那么它可以自由决定value）。
    - 在不违背自己向其他**Proposer**的承诺的前提下，**Acceptor**收到**Accept**请求后即批准这个请求。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这个过程在任何时候中断都可以保证正确性。例如如果一个**Proposer**发现已经有其他**Proposer(s)**提出了编号更高的提案，则有必要中断这个过程。因此为了优化，在上述准备过程中，如果一个**Acceptor**发现存在一个更高编号的提案，则需要通知**Proposer**，提醒其中断这次提案。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;两阶段描述完毕。

### 第五页

### 第六页

### 第七页

### 第八页

### 第九页

## 学习总结和感悟
