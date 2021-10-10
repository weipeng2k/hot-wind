# 基础Paxos算法笔记(3/9)

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
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/approve-proposal.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Acceptor**集群中，每个**Acceptor**都会记录自己收到的提案，如果只有一个**Acceptor**，在**Paxos**算法中，它一定会记录到所有的提案，但如果是多个**Acceptor**呢？那一定是各记录各自的提案，但是所有**Acceptor**的知识一定可以反映出所有的提案，只是在某一个**Acceptor**中，只有部分提案而已，如拼图一样，通过拼接，就可以得到完整的图画。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Lamport**在**约束2**的基础上，做了增强。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**约束2a**. 一旦一个具有Value的提案被批准，那之后的**Acceptor**接收的提案必须具有Value。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**约束2b**. 一旦一个具有Value的提案被批准，那之后的**Acceptor**接收的提案必须具有Value。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**约束2c**. 如果Value V的N号提案提出，多数**Acceptor**要么没有接收N-1号提案，要么接收的最近一个提案（在N-1号之前）包含有Value V。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到**约束2a**将约束推到了决议讨论阶段，而**约束2b**进一步反推到了提议阶段，也就是一旦满足**约束2b**，那就一定会满足**约束2a**，可以将**约束2a**称为**约束2b**的必要条件。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;理解**约束2**及其变体，需要从时间角度去看，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/proposer-submit-proposal-timeline.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，从一个**Proposer**角度去看，如果其提案被批准形成了决议，则之后再次发起提案时，以往的决议将能够被**Proposer**所见，且不仅限于该**Proposer**可见自己提出的提案（或决议），只要是决议，就算是其他**Proposer**提出的，也是能够可见的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;以数据库事务中事务隔离级别去思考这个问题也是可行的，比如：读已提交隔离级别，就和该约束有些含义上的共通点。至于**约束2c**，实在有些搞不太清楚想表达什么意思，先放在这里吧。
