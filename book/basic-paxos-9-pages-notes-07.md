# 基础Paxos算法笔记(7/9)

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;第七页笔记开始通过另一个示例来演示**Paxos**算法是如何处理不同**Proposer**提出相同编号提案的问题，也是这个算法容错性的一种体现，同时会讲述一些细节。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;关键词：**Proposer**、**Acceptor**、**Proposal**和**两个阶段**。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-note-7.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于**隐含约束2**的存在，**Acceptor**收到的提案编号会产生重复，这点在**第四页**笔记中已经介绍了获取提案编号的方式。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;提案编号可以由**Proposer**自己产生，但是考虑到分布式环境中一定存在不止一个**Proposer**，所以如果每个**Proposer**都自顾自的生成编号，那么产生冲突的概率就会很高。虽然是用一致的策略进行编号生成，但是如果没有通过协商就进行编号生成，会显得比较随意，所以在每次编号生成前，可以选择**咨询**多数的**Acceptor(s)**，由此来确定一个合适的编号。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;假设在一个多**Proposer**的环境中，如果相同提案编号的**Prepare**请求发送到**Acceptor**会有什么效果呢？这里就要详细的讨论一下**第四页**笔记中遗留的`M = N`的问题了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;先要明确一个前提，每个**Proposer**都会给多数的**Acceptor(s)**发送**Prepare**请求，所以一定存在一个**Acceptor**集合，它们会接受到多于两次的**Prepare**请求，只是在绝对时间的一前一后而已。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;考虑如下场景：存在2个**Proposer**和5个**Acceptor**，**Proposer**会将**Prepare**请求发往多数（示例中为3个）**Acceptor(s)**，这个交集就是**A3**。我们考虑**A1**的**Prepare**请求先到达**A3**，然后当先收到的提案已经被批准为提案时，如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-samenum-approve-timeline.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到**A3**时间线上的蓝点是一个关键点，这个点之后，相同编号的提案，先前**A3**收到的（**A1**的提案），已经成为了决议。此时，如果收到了**A5**的**Prepare**请求，按照原有算法描述，可以直接忽略，不回复，但是出于效率，不应该这么做。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果不进行回复，**A1**的提案已经成为决议，多数**Acceptor(s)**认可，但是**A4**和**A5**并不知晓，**A5**作为**Proposer**只会在那里傻等。要解决这种死锁，就需要**Proposer**具备一种自我超时机制，如果提案经过一段时间还没有收到足够的反馈，就查询一下多数**Acceptor(s)**的提案状况，如果发现已经在讨论更新的提案了，就废弃掉当前提案，然后重新发起提案。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;默认的算法逻辑只能如此处理，但是如果假设允许**A3**返回一个**Promise**，其值是**Ignore**，则会使得该过程的活性得以提升，同时这部分逻辑不用依靠超时机制。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这是在决议形成之后，也就是已经收到了来自**A1**的**Accept**请求后，收到来自**A5**的**Prepare**请求。如果在**A1**的提案还没有变为决议前收到呢？如下图：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-samenum-non-approve-timeline.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，**A3**依旧会采纳**A1**的提案，原因是**约束1**的存在。**A3**会回复**A1**和**A5**值为**Suggest**的**Promise**，建议双方使用已有的提案，也就是**A1**的提案。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于**Acceptor**其实做法比较简单，如果存在了这个提案编号，则拿出已有的提案，同时通知当前提案的**A5**和已有提案者**A1**，通知两位相关的建议。如果**A1**和**A5**的两个**Prepare**请求很近，则需要**Acceptor**支持事务性，一定能够确保一个时刻，只能添加一个相同编号的提案。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于**Acceptor**接收到**Prepare**请求，如果`M = N`的场景就应该这么多了，现在我们可以完整的描述一下这块逻辑了。假设：**Acceptor**存在`proposalDAO`和`resolutionDAO`用于访问它的提案列表和决议列表，`Proposal.no`表示提案编号，`Proposal.proposer`表示提案的**Proposer**，`Resolution.proposalNO`表示决议对应的提案编号。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Acceptor**接收**Prepare**请求的步骤如下：

```java

Promise receiveProposal(Proposal p) {
    // 拿到最新的决议
    Resolution localResolution = resolutionDAO.findLasted();
    // 提案已经是决议了
    if (localResolution.proposalNO >= p.no) {
        return Promise.of(Ignore);
    }

    Proposal localProposal = proposalDAO.findLasted();
    if (localProposal.no > p.no) { // 本地提案新，需要提醒中止
        return Promise.of(Abort);
    } else if (localProposal.no == p.no) { // 相同给出建议
        return Promise.of(Suggest);
    } else {
        // 考虑并发控制，如果冲突，则重试
        boolean result = proposalDAO.insert(p);
        if (result) {
            return Promise.of(Agree);
        } else {
            return receiveProposal(p);
        }
    }
}

```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于**Acceptor**的提案列表控制，如果出现插入失败，表明已经有相同编号的提案插入成功，则需要进行重试。
