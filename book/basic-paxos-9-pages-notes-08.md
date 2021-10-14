# 基础Paxos算法笔记(8/9)

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;第八页笔记讨论决议的发布过程，以及决议在不同**Learner**中如何传播的问题，同时也会讨论**Paxos**算法如何避免死锁的问题，该方案在**Raft**中也会看到，是一种保障算法过程的常用方案。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;关键词：**Acceptor**、**Learner**、**广播**和**随机睡眠**。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-note-8.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;当**Acceptor**接收到**Accept**请求后，就会将（当前节点中的）提案转换为决议，同时会将决议通知到**Learner**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;论文中对于**Learner**的描述有限，基本都集中在**Proposer**和**Acceptor**上，但是不是说**Learner**不重要，我们需要看一下**Learner**的职责有哪些？第一，存储决议；第二，响应请求。前者是**Learner**的本职工作，其实这点（如果看了前面的文章就能理解到）**Acceptor**实际也可以做到，因为**Acceptor**才是策源地，但是可以理解**Learner**为决议的备份，有它存在，整个系统的可用性会有保证。后者是**Learner**的核心工作，这个工作是参与到**Paxos**算法过程中的，由**Learner**来生成响应，并将响应发回给**Client**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**为什么不是Acceptor来做这个工作？**其实是可以的，但是如果这样来定义**Acceptor**，就会让它变得很重。因此，一个能够尝试对**Client**建链接发响应，同时存储备份一下决议，是比较符合单一职责的。这么看来**Learner**实际承担了**Paxos**算法末段关键流程了，但是论文掐头去尾只着重在中间一段（**Proposer**和**Acceptor**），对这部分内容会描写的比较简单，但涉及到问题却不能那么简单的带过，需要详细看一下。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**主要的问题在于：如何确保决议在Learner中形成共识？**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Learner(s)**也是一个集群，每个**Acceptor**都会发布相同决议的通知到**Learner**，如何确保这些**Learner(s)**不漏掉，同时这个过程是高效的。这个又是一个共识问题，如果再机械的按照旧有模式解有些不现实，所以需要一个高效的方案。论文中提到了**Acceptor**将通知发往**Learner**集群中的一个子集，再由子集来通知全量的**Learner**，这句话很简单，但让作者自己去实现，估计他也会崩溃，毕竟节点是计算机，不是人，它需要一个具体且无歧义的方案。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Acceptor**能够通知**Learner**，这代表**Acceptor**知晓**Learner**，可以假设每个**Acceptor**都具有一个**Learner**集合。这里选择一个集合，目的是增强通知的可靠性。当决议通知抵达**Learner**后，其他的**Learner**要么被通知，要么主动的来获取，这个过程如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/learner-notification.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;红色和黑色线条的区别就是选择拉或者推。两种模式都能够解决数据同步的问题，但是在解决这些问题之前，我们先要看一下**Acceptor**通知**Learner**的问题。这是**Learner**收到变化的入口，每个**Acceptor**都会尝试通知一个**Learner**集合，这样会确保通知能够下达。在这个集合中，每个节点对于新增的决议都应该有一个业务无关的主键，该主键在节点内是严格自增的，这会在同步数据时发挥作用。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果选用推的模式，集合中的每个**Learner**节点都会将新增决议的通知发往其他的**Learner**，来自`N`个**Acceptor**的通知最终会演变成为一场风暴，这么做是有些低效的。虽然推比拉的时效性更好，但是效率会低很多，我们只需要集合中的**Learner**能够实时的通知**Client**就好，而数据同步的工作，交给其他的**Learner**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果数据同步的工作由其他的**Learner**来做，这就是典型的拉模式。每个**Learner**都应该知晓其他**Learner**的存在，同时会维护同步其他**Learner**数据的主键（或游标），这样一个**Learner**就有`N-1`个游标。每隔一段时间，会问询其他`N-1`个**Learner**，如果发现对应的游标有偏差，就获取对方的增量，完成合并与同步，同时需要更新游标，这个过程是需要幂等的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;现在可以梳理一下一个**Learner**的工作：如果接受到来自**Acceptor**的通知，将决议存储到本地（并更新主键）同时根据决议中的请求，生成响应回复**Client**。处理消息的同时，还需要定时的轮询其他的**Learner**，维护其他同步的游标记录，如果发现数据有变化，则发起同步，并更新游标。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到**Learner**集合的概念是从**Acceptor**角度来看的，每个**Learner**的工作是相同的。集合存在的目的，除了为有效和可靠的保存决议以外，还是为了快速的通知**Client**，完成一次**Paxos**算法过程。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;接下来我们掉转头，看一下**Proposer**生成提案编号的问题，通过前文中的描述，编号是通过获取各个**Acceptor**的状态数据来得到的，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/proposer-require-proposal-no.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述策略存在一个死锁的问题，如果多个（超过3个）**Proposer**同时进行问询，很可能会得到相同的编号，然后各自将**Prepare**请求发往**Acceptor**后，得到的**Promise**不会是**Agree**，只能重新走一遍流程，结果很有可能再次撞车。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;解决的方式比较简单，可以在**Acceptor**返回之后，随机睡眠一段时间，然后再询问各个**Acceptor**，这样就可以错开。当然，如果要通用化的解决，可以选择在上图红色X部分引入一个随机睡眠，也就是在**Client**并行请求到达**Proposer**后，会经过各个节点（各自）随机的睡眠，然后再进行处理。通过引入这种*整流*的形式，降低冲突和死锁的几率。
