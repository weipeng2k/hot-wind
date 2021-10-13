# 基础Paxos算法笔记(1/9)

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;第一页笔记主要说明共识和一致性的关系，以及**Paxos**算法的主要构成角色和角色的相关职能。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;关键词：**共识**、**一致性**、**分布式通信**和**Paxos算法角色**。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-note-1.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Paxos**算法是一种共识（Consensus）算法，而非一致性（Consistency）算法。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们常见认知中，认为**Paxos**就是一个能够解决一致性的神奇东西，但是它并没有那么强大，它只是一个算法策略，没有一点工程化的能力，而一致性才是工程需要考虑的问题。可以认为：一致性是一个目标，是我们在分布式环境中追寻的一个目标，而要在分布式环境中达成这个目标，就需要（分布式环境中的）多个节点，它们能够形成共识，拟人的话就是：*对某件事情有一致的看法*。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这里的共识就是一种手段，因此利用共识可以达成一致性，它们的关系如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/consensus-consistency.png" width="70%">
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