# 基础Paxos算法笔记(5/9)

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;第五页笔记会结合**Paxos**算法的约束，再次梳理细化提案批准过程，设想**Proposer**和**Acceptor**的属性与状态。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;关键词：**Proposer**、**Acceptor**、**准备阶段**和**批准阶段**。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-note-5.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;准备阶段是**Proposer**发起**Prepare**请求给到**Acceptor**，请求的内容是提案（包括：提案编号和议题）。准备阶段的发起方式**Proposer**，但实际是**Citizen**，也可以理解为客户端。准备阶段的目的是为了获得设置值的资格，而其载体就是提案。以**Proposer**的视角来看一下，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-concept-proposer.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Citizen**需要设置值，将请求**Request**发送给**Proposer**。**Proposer**内部会具有一个提案列表，它包括了该**Proposer**提交的所有提案，也拥有将**Request**转换为**Proposal**的能力。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Proposer**收到了**Request**，然后通过询问多数的**Acceptor(s)**，它们最新的提案编号是多少。**Proposer**再得到足够信息后，开始尝试将**Request**转换为**Proposal**，然后进入到提案的**Prepare**阶段。这里可以看出来，提案除了包含议题和编号，还会有**Request**的相关信息，比如：请求ID，Citizen的关键信息，以及当前**Proposer**的关键信息等，这样的**Proposal**才显得充分。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;当**Proposer**接收到了（发起提案的）足够多表示同意的**Promise**后，**Proposer**会发起该提案的批准接受**Accept**请求，使得回复了同意**Promise**的**Acceptor**能够完成提案值的设置以及**Resolution**的生成。这里存在一个问题，两个阶段是在**Proposer**上还是在**Proposal**上？如果同一时刻一个**Proposer**只能提出一个提案的话，设置在**Proposer**上是没有问题的，但如果**Proposer**会同时创建多个提案，那就必须设置在**Proposal**上。由于**Paxos**算法是通过异步消息进行通信，并行处理是必然，所以阶段是设置在**Proposal**，也就是提案上，因此提案会有批准**Acceptor**的列表等信息，这些运行时信息如果能够体现出多数的**Acceptor(s)**同意，那么该提案就进入了批准阶段。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;以**Acceptor**的视角来看，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-concept-acceptor.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Acceptor**收到**Proposer**的**Prepare**请求，然后回复**Promise**。**Acceptor**有提案列表，也有决议列表，如果收到的提案编号能够在决议中找到，那就会回复忽略的**Promise**，因为这都已经成为决议了，没有必要再提了。提案以及回复的**Promise**如下表所示：

|收到提案的情况|回复**Promise**|含义|
|----|----|----|
|提案编号如果能够在决议列表中找到|忽略|已经成为决议了，没有必要再提|
|提案编号如果大于提案列表中最新的提案编号|同意|没有收到过该提案，可以通过|
|提案编号如果小于提案列表中最新的提案编号|中止|已经收到过提案，该提案还没有进入批准阶段，但已经有**Proposer**提过，可以中止|
|提案编号如果等于提案列表中最新的提案编号|建议|提案编号一样，但多个**Proposer(s)**提出了，那回复发送请求的**Proposer(s)**一个建议，建议使用已经存在的提案|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Proposer**不断的收到**Promise**，如果发现其中某个提案中的支持（或同意）数量已经过了半数，那就代表该提案需要进入到批准阶段。进入批准阶段的提案，**Proposer**会发起**Accept**请求，而**Acceptor**一旦收到，就会按照要求将决议转换为决议，并将其发布通知给**Learner**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到在阶段控制上是通过**Proposer**来做到的，接下来看一下**Learner**，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-concept-learner.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Acceptor**发布了**Resolution**，**Learner**收到后会记录下当前决议，同时进行广播给其他**Learner(s)**，最后将**Resolution**转换为**Response**，回复给**Citizen**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这么长的链路，**Learner**怎么能够知道**Citizen**呢？因为**Resolution**包含了**Proposal**，而**Proposal**包含了**Request**，这样自然就能从某一个决议找到发起请求的**Citizen**了。
