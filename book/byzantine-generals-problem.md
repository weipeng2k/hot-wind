# 拜占庭将军问题

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;《拜占庭将军问题》来自于对**Leslie Lamport**一篇在1982年发表的论文，可以通过检索*the-byzantine-generals-problem*来下载阅读。这篇论文的主旨是阐述了一个将军和若干中尉协作进攻一个城池的问题，通过假设和分析问题场景中的多种情况，比如：存在叛徒和信息传递丢失的问题，来设计一组算法，使得忠诚的将军（或中尉）有统一的行动计划，并将这组算法应用到可靠计算机系统的建设中。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;论文整体上有些散，并且在定理阐述阶段也有些故弄玄虚，比如：在假设阶段，不断的修改拜占庭将军问题的题设，从多将军协作，到将军和中尉，再到作战时间的协商，有兴趣的读者可以自己下载原文阅读，只是笔者的阅读体感并不好，但是其阐述的问题和思考是有价值的，尤其在分布式环境下构建一个可靠的计算机系统有指导意义。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;以下是笔者对这篇论文的（摘录）翻译和理解。如果是笔者的理解将会以![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png)来开头，以引言的形式来展示，比如：

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 这个是作者的理解。。。
>
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;描述内容示例。。。

---------

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分布式系统是由多个部分组成，当有部分组件或者系统出现问题，向其他组件或者系统发出具有冲突性的信息时，可靠的计算机系统必须能够正确应对这种情况。这种情况可以用这个场景来形容，一组拜占庭将军率领各自的部队包围了敌人的城池，将军们只能通过信使交流，必须就共同的作战计划达成一致。然而不幸的是，他们中的一个或多个可能是叛徒，他们会试图迷惑其他人。问题是找到一种算法来确保忠诚的将军们会达成一致。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/byzantine-generals-problem/byz.jpg" width="50%"/>
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;结果表明：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（1）仅使用口头信息时，当且仅当超过三分之二的将军忠诚时，这个问题是可以解决的，所以一个叛徒可以迷惑两个忠诚的将军；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;（2）当信息无法伪造时，任何数量的将军和可能的叛徒都可以解决这个问题。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 口头信息
> 
> 口头信息可以被伪造，叛徒收到一位将军的信息，然后可能会进行篡改，将相反的信息传递给其他人。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;基于这个结论，然后讨论该结论在可靠计算机系统中的应用。

## 引言

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;一个可靠的计算机系统必须能够在系统中若干组件出错的情况下正常工作。一个出错的组件，在系统中时常表现的行为是向其他组件传递有冲突的信息。这个应对出错组件的问题被抽象为拜占庭将军问题。本文的主要内容是探讨这个问题以及如何解决这个问题，并将解法应用到如何实现一个可靠的计算机系统。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们设想若干拜占庭军团包围了敌人的城池，每个军团都有一个将军指挥。将军之间通过信使来通信。通过对敌人的观察，将军们必须形成统一的决策，然后行动，但是将军们中间可能存在叛徒，叛徒会阻止忠诚的将军们形成决策。将军们需要一个算法来保证：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**条件A**. 所有忠诚的将军们有相同的行动计划。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;忠诚的将军会按照算法计算所得的结果来行动，而叛徒会按照他们自己的意愿来行动。这个算法需要确保条件A能够在叛徒无论做什么行动的前提下都能够成立。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;忠诚的将军们应该不仅限于达成一致决策，而且应该做到是一个合理的决策，需要确保：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**条件B**. 少量的叛徒不能导致忠诚的将军们采纳一个不好的决策。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**条件B**很难形式化表达，因为无法精确的说什么是不好的决策，而且我们也不会尝试这么做。相反，我们考虑将军们如何达成一致的决策。每个将军都会观察敌人并将他的观察结果（或者说决策）传达给其他将军。令`v(i)`是第`i`个将军传达的信息。每个将军使用某种方法将值`v(1).....v(n)`组合成一个唯一的行动计划，其中n是将军的数量。**条件A**可以通过让所有将军使用相同的方法组合信息来实现，**条件B**需要使用更加健壮的方法来加以实现。例如，如果唯一要做的决定是进攻还是撤退，那么`v(i)`就是将军i对这两个选项的最好意见，最终决定可以基于它们之间的多数票。只有当忠诚的将军在两者之间几乎平均分配时，少数叛徒才有影响决策可能性，在这种情况下，没有所谓不好的决策。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 作者到当前依旧没有提出拜占庭将军问题的标准题设，当前的**条件A和B**对于输入没有描述，只是描述为 **“通过对敌人的观察”** ，毕竟对于计算机系统，需要执行的指令是需要外部触发或者给出的，因此题设经历了两轮调整来到了将军和中尉模型，这也就是大家熟知的拜占庭将军问题。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**拜占庭将军问题**：一个负责指挥的将军必须发送命令给他的**n-1**个中尉，要求：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**IC1**. 所有忠诚的中尉服从一致的命令。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**IC2**. 如果指挥官是忠诚的，那么每个忠诚的中尉都会服从他的命令。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**IC1**和**IC2**是交互一致性条件，如果**IC2**成立，则**IC1**自然成立。

