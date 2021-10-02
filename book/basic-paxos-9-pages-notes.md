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

### 第三页

### 第四页

### 第五页

### 第六页

### 第七页

### 第八页

### 第九页

## 学习总结和感悟
