# 基础Paxos算法笔记(4/9)

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

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这个过程在任何时候中断都可以保证正确性。例如：如果一个**Proposer**发现已经有其他**Proposer(s)**提出了编号更高的提案，则有必要中断这个过程。因此为了优化，在上述准备过程中，如果一个**Acceptor**发现存在一个更高编号的提案，则需要通知**Proposer**，提醒其中断这次提案。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;两阶段描述完毕。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在具体分析论文描述两个阶段内容前，先厘清一个概念：**提案并不是贯穿整个Paxos算法的唯一概念实体**。这么说的原因在于，由客户端发起的请求，到**Proposer**发起的提案，到最终**Acceptor**同意批准以及传递给**Learner**知晓，其目的是为了满足客户端的请求能够被分布式环境所无歧义的理解（或者保存），这才是这个算法存在的意义。客户端并不能够发起提案，提案能够不断的更改，而提案一旦通过就无法更改，这些都不能够简简单单的依靠一个**Proposal**就描述能够清楚地，实际是需要结合**Paxos**算法中各个参与者来看这个问题，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/proposal-lifecycle.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到从**Citizen**发起请求，到**Learner**获得到决议，通过提案批准的方式获得了在**Acceptor(s)**层面的共识，同时各方都已自己的角度进行概念传递，这点可以用网络分层传输数据的角度进行类比思考。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;再回到**Paxos**算法两个阶段进行提案批准上来，通过准备阶段使得**Proposer**获得了申请资格，再通过批准阶段使**Proposer**能够设置期望的值。先看一下算法的准备阶段，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/proposal-approve-prepare-phase.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到**Proposer**向多数**Acceptor(s)**发送了**Prepare**请求，这个请求包括了提案编号，比如：当前是编号`N`。如果接收到**Prepare**请求的**Acceptor**会根据自己的提案列表，看一下已有的最新提案编号`M`，假设`N > M`，**Acceptor**会接受该提案，并返回`M`号提案。如果`M > N`则可以看出**Acceptor(s)**已经在讨论更新的提案，当前提案没有必要再进行讨论了，此时会回复**Proposer**中止响应，意思是：不要再发送提案了，你这个已经过时了（，如果需要再发送，需要更新编号了）。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们讨论了`M != N`的情况，那如果`M = N`呢？在回答这个问题之前，我们回忆一下**隐含约束2**。为什么不同的**Proposer**会发送相同提案编号的**Prepare**请求，原因在于算法没有描述**Proposer**选择提案编号的方式。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果将**Proposer**内部维护一个编号指针，每次获取的时候就会递增，这无疑是一种解决办法，因为**Proposer(s)**获取编号的策略是稳定的。可是这种方式虽然简单的解决了编号生成方式，但是它冲突的几率会比较高，同时新加入的**Proposer**节点会很难适应。因此可以考虑另一种方式：**Proposer**在进行提案之前，首先会问询多数的**Acceptor(s)**它们各自最新的提案编号是多少，通过取`Max(N1, N2, N3,...) + 1`来得到提案编号。这个策略有些类似数据库的自增主键，通过获取多数**Acceptor(s)**的提案信息来决策一个合适的提案编号。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;当`M = N`时，**Acceptor**需要回复**Proposer**已经接受的旧有提案信息，并能够告知产生冲突提案的**Proposer(s)**，这点有些复杂，我们在之后探讨。接下来就是算法的批准阶段，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/proposal-approve-commit-phase.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;当**Proposer**收到超过半数批准的**Promise**后，在**Proposer**这段的提案状态就会发生变化，由准备变为批准，此刻该**Proposer**已经具备了设置内容的资格。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Proposer**会通过**Accept**请求，将值和提案信息发送给响应了批准**Promise**的**Acceptor(s)**。在**Acceptor**一端，会将值与提案转换为决议（**Resolution**），留存的同时会通知**Learner**，由**Learner**生成响应，回复客户端。
