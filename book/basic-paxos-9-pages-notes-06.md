# 基础Paxos算法笔记(6/9)

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;第六页笔记开始通过一个示例来演示**Paxos**算法，同时讲述一些细节。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;关键词：**Proposer**、**Acceptor**、**准备阶段**和**批准阶段**。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-note-6.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在描述**Paxos**算法时，经常会看到这样的图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-classic-diagram.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这样的图有意义吗？当然有的，它以时序的形式来展示出算法中各个角色参与的时间以及所作出的行为，但对于时间线还是没有体现的很好。试想之前的一个场景，如果一个**Acceptor**收到了两个相同编号的提案，也许先收到的提案创建的时间还晚于后收到的提案创建时间，但是由于**约束1**的存在，实际会被接受的是这个创建时间较晚的提案。

> **约束1**. 一个**Acceptor**必须接受第一次收到的提案。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这两个提案的**Prepare**请求对于这个**Acceptor**而言，不会在同一绝对时刻收到，但也可能会在一瞬收到，这就要求它能够很好的应对并发问题，更直白的说：**Acceptor**的提案列表需要是一个线程安全的列表。**Acceptor**的提案列表能够并行的处理接收到的**Prepare**请求，以提案编号为主键，线程安全（或者说读已提交）的处理提案的加入，不分创建时间的先后，一旦加入列表，则后续重复的提案将会被另行处理。

> 注意接收和接受，接收是被动的，接受是有逻辑且主动的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;回到时间这个维度上，对于准备阶段和批准阶段，以时间线的方式展示整个过程会更加的合适，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-timeline.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上图从**Client**发起请求开始，直到**Client**最后收到响应结束，共5个节点参与，其中有1个**Proposer**、5个**Acceptor**和2个**Learner**。在绝对时间轴下，各个参与者接收到请求，以及发送响应的时间点。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过上图可以看到几个细节：

**(1) 具有Proposer和Acceptor角色的节点会接受自己的提案**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果一个节点同时具备了**Proposer**和**Acceptor**角色，该节点收到**Client**的请求后，将请求转换为提案，并发起**Prepare**请求。**Prepare**请求发起的同时，该节点首先会接受该提案，在进程内响应同意的**Promise**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以想象，如果该节点提出的提案，自己不接受，那就会产生混乱。现实中，某个议员会提出提案，同时他自然会接受自己的提案，如果自己提出的提案，自己都不接受，那就是蛇精病了。

**(2) 两个阶段的分界线在于提案有了多数人支持**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;阶段是针对提案的，或者说提案的状态。当一个提案有超过多数**Acceptor(s)**支持时，它就从准备阶段到了批准阶段。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这里可以看到提案应该能够知晓有多少**Acceptor(s)**同意它，提案不可能知晓所有的**Acceptor(s)**，但是**Proposer**应该知晓。**Proposer**发现该提案已经有多数人支持了，那就代表阶段切换了。

**(3) 两阶段转换的触发在Proposer接收达到多数票的最后一个Promise**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Proposer**不断的收到**Acceptor**回复的**Promise**，根据**Promise**可以清晰的看到该提案有多少**Acceptor(s)**支持。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;当任意一个同意的**Promise**被**Proposer**收到，并发现该**Promise**使得该提案的同意过半，此时，该提案的状态会发生变化，从准备阶段进入到批准阶段。随后开始向所有同意的**Acceptor**发送**Accept**请求，进行值的设置。

**(4) 提案进入批准阶段形成决议，而提案的Proposer还会回复Accept请求**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;提案支持人数过半后，提案会进入批准阶段，由于同意的**Acceptor**不回再次发起请求，所以当前**Proposer**会获取到支持该提案的所有**Acceptor(s)**，进行发送**Accept**请求。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;虽然提案已经批准，但不意味着结束。每个收到**Accept**请求的**Acceptor**都会将提案转换为决议，且在收到请求的**Acceptor**本地进行，这也暗示多数的**Acceptor(s)**有对决议的共识。其他的**Acceptor**回复给**Proposer**同意的**Promise**时，**Proposer**会继续发送**Accept**请求，使得更多的**Acceptor(s)**能够进行决议的转化，达成共识。

**(5) 响应Client（或Citizen）的Learner可能很多，Client需要做到幂等**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;当**Acceptor**收到**Accept**请求后，会在本地完成提案到决议的转化，同时会把决议保存到决议列表，当然这个数据结构也是线程安全的，同时会通知它知晓的一个**Learner**，目的是将决议发布给一个学习者，由它记录，由它返回。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以想象，**Learner(s)**最终会保有所有的决议，但是如何让它们互通有无？这点我们在后面探讨，我们只需要知道现在**Learner**可能会受到发布的决议，而且不止来自于一个**Acceptor**。一旦**Learner**接收到发布的决议，会进行保存，如果保存成功，除了会通知它所知晓的**Learner**协助记录之外，还会将决议转换为响应，发送给**Client**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在**Client**的视角看，一定会收到请求对应的多次响应，所幸这些响应对应的是一个概念上的决议。因此在第一次受到响应时，就算完成了整个流程，**Client**可以不用理会后续的响应。
