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

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;那为什么还需要了解和掌握**Paxos**算法呢？**Google Chubby**的作者**Mike Burrows**说过，*这个世界上只有一种一致性算法，那就是**Paxos**，其它的算法都是残次品*。可以看出该算法对于分布式环境下的共识问题，是具有里程碑意义的。这好比我们定义了什么叫吃，当然食物的种类千千万，谁先说出最基本的东西，没有人会不承认它的重要性，因为它解决和阐明了大家都能看到的、最基本和最核心的问题。不是说这个问题有多难，而是人家就是**很早**阐述清楚了，而这是你的必由之路，有点这个意思。因此，对于分布式共识是我们需要理解和掌握的，而**Paxos**算法是无法回避的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Lamport**认识到**Basic Paxos**的低效，再**Basic Paxos**基础上提出了**Multi Paxos**和**Fast Paxos**，这两种变体，用于减少算法中的消息传递次数，提升算法效率。本文不涉及这两种算法，只会集中在**Basic Paxos**。

## 基础**Paxos**算法笔记

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本文阐述的内容基本和《Paxos made simple》一致，但会增加一些笔者的思考、示例和推导，是**Paxos**的学习笔记。

### 第一页

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/basic-paxos-9-pages-notes/paxos-note-1.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Paxos**算法是一个共识（Consensus）算法，而非一致性（Consistency）算法。我们常见认知中，认为**Paxos**就是一个能够解决一致性的神奇东西，但是它并没有那么强大，它只是一个算法策略，没有一点工程化的能力，而一致性是工程需要考虑的问题。可以认为，一致性是一个目标，是我们在分布式环境中追寻的一个目标，而要在分布式环境中达成这个目标，就需要（分布式环境中的）多个节点，它们能够形成共识，拟人的话就是：*对某件事情有一致的看法*，这里的共识就是一种手段，因此利用共识可以达成一致性，它们是这样的关系。

### 第二页

### 第三页

### 第四页

### 第五页

### 第六页

### 第七页

### 第八页

### 第九页

## 学习总结和感悟
