# 基础Paxos算法笔记(9/9)

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;第九页笔记讨论**Paxos**算法中的主要数据结构和关键逻辑行为，是该算法进行工程化实践的思考。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;关键词：**数据结构**、**逻辑**和**状态**。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-note-9.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在前8节的笔记中，我们讲述了异步消息是该算法的沟通方式，从**Client**如何发起**Request**开始，到**Proposer**收到**Request**将其转换为**Proposal**，然后将提案发给多数的**Acceptor**。我们详细讨论了**Acceptor**收到**Prepare**请求后的处理逻辑，并将生成的决议发给**Learner**的过程。在**Learner**收到决议后，如何能够高效的在**Learner**之间完成共享，并将**Response**发回给**Client**，从而完成一次**Paxos**算法。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过前面的讲述，我们应该对**Paxos**算法有了一个大致的了解，在开始本节的内容之前，笔者会再次罗列一下关键的功能点，这样也便于后续对该算法数据结构的讨论。以算法角色（或参与者）为视角，其功能如下表（其中顺序一栏表示该功能在算法中的使用次序，升序排列）：

|角色|功能|描述|顺序|
|---|---|---|---|
|**Client**|发起请求|生成请求ID，包装请求，选择一个**Proposer**发送请求|1|
|**Client**|接受响应|收到响应，将响应中包含的请求ID提取出来，完成请求和响应的映射|13|
|**Proposer**|接收请求|收到请求，解析请求内容，随机睡眠一段时间，准备发起**Prepare**请求|2|
|**Proposer**|发起提案|生成提案，访问多数的**Acceptor**获得最新的编号，设置编号，发送**Prepare**请求给多数**Acceptor**|3|
|**Proposer**|接收承诺|收到**Acceptor**回复的**Promise**，更新提案与**Acceptor**的关系，包括支持数量，如果是非**Agree**的**Promise**，需要进行重试|6|
|**Proposer**|接受提案|当多数**Agree**的**Promise**收到后，向回复**Agree**的**Acceptor**发起**Accept**请求|7|
|**Acceptor**|接收提案|收到**Prepare**请求，提取出提案，进行相应处理，详细内容可以参见第7节|4|
|**Acceptor**|回应承诺|生成**Promise**，回复**Proposer**|5|
|**Acceptor**|决议发布|将决议发布到**Learner**集合|9|
|**Acceptor**|接受提案|接受到**Proposer**发送的**Accept**请求，生成决议并保存|8|
|**Learner**|回复响应|根据决议，构建响应，回复**Client**|11|
|**Learner**|接收决议|收到**Acceptor**发送来的决议，生成本地记录，进行处理|10|
|**Learner**|同步决议|定时查询其他**Learner**，获取对方的新增记录，完成增量同步|12|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;接下来需要看一下算法中的主要领域对象，在**Paxos**算法中，参与者包括：**Client**、**Proposer**、**Acceptor**和**Learner**。其中**Client**是入口，也可以作为使用算法的SDK，部署在使用方的应用中。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Client**会具有**Proposer**列表，在每次发起请求时，会随机选用一个**Proposer**发起请求。**Proposer**会具有**Acceptor**列表，每次在**Prepare**请求发起前会将提案发往这个列表中的多数（或者是发往多数后，停止发送）。**Acceptor**会具有**Learner**列表，在发布决议时，选择其中一个集合进行通知。**Learner**会根据请求中的地址发起对**Client**的建链，只需要确保网络可达即可。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述关系如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-role-ds.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在**Client**一端，具有一个请求ID到**Request**的`Map`结构，用来在请求时将数据放置其中，当**Learner**发回响应时，取出其中的**Request**来进行应答处理。每个**Client**都会具有**Proposer**列表。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Proposer**具有提案列表，在发送**Prepare**请求前，需要先保存在本地。**Acceptor**具有提案和决议列表，用来接收**Prepare**请求，以及在**Accept**请求处理时，将提案转为决议并存储。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Learner**除了知晓其他**Learner**的地址，还需要保有同步其他**Learner**的进度记录，只有这样才能在后续的定时同步时做到有的放矢。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;除了上述参与者，算法中出现最多的就是提案、决议和请求等数据了，它们之间的关系，以及各自所具有的属性，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-data-ds.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从请求到最终的响应，环环相扣，最终的响应能够知晓它的决议是谁？之前的提案是什么？谁发起的？只有这样，一个响应发回才能对应的上请求，同时能够给到**Client**以详实的信息。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;请求中的**Client**关键信息，包括了**Client**的IP等关键信息，目的是能够在之后**Learner**回复响应时，找到发起的**Client**，也只有将响应回复到该节点，才有意义。如果回复到其他**Client**将没有任何效果，这是为什么呢？读者可以自行思考。

> 参考**Client**的数据结构。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;提案中的与**Acceptor**的关系，来自于**Acceptor**回复的**Promise**，每个**Promise**都会形成一条关系。决议中的新增日志，就是为了**Learner**之间同步数据而准备的，每条日志都会有（自增）主键，便于其他**Learner**掌握同步进度。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Basic Paxos**算法到这里就基本描述完了，它说起来复杂，但本质也很简单。它利用了多数原则，通过一定的冗余和决策，解决了分布式环境中的共识问题，这个思想在分布式系统中具有广泛的运用场景。
