# 基础Paxos算法笔记(8/9)

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;第八页笔记讨论决议的发布过程，以及决议在不同**Learner**中如何传播的问题，同时也会讨论**Paxos**算法如何避免死锁的问题，该方案在**Raft**中也会看到，是一种保障算法过程的常用方案。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;关键词：**Acceptor**、**Learner**、**广播**和**随机睡眠**。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-note-8.jpg" width="70%">
</center>

