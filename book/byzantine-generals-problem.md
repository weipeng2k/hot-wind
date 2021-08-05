# 拜占庭将军问题

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;《拜占庭将军问题》来自于对[**Leslie Lamport**](https://www.microsoft.com/en-us/research/people/lamport/)一篇在1982年发表的论文，可以通过检索*the-byzantine-generals-problem*来下载阅读。这篇论文的主旨是阐述了一个将军和若干中尉协作进攻一个城池的问题，通过假设和分析问题场景中的多种情况，比如：存在叛徒和信息传递丢失的问题，来设计一组算法，使得忠诚的将军（或中尉）有统一的行动计划，并将这组算法应用到可靠计算机系统的建设中。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/byzantine-generals-problem/lamport.jpeg" width="50%"/>
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;论文整体上有些散（或者说目标多），并且在定理阐述阶段也不断的修改，比如：在假设阶段，不断的修改拜占庭将军问题的题设，从多将军协作，到将军和中尉，再到作战时间的协商，有兴趣的读者可以自己下载原文阅读，由于作者在一篇论文中尝试说明多个场景的解法，导致笔者的阅读体感并不好，而实际作为一篇论文，20页的体积还是相当大的。该论文阐述的问题和思考是有价值的，尤其在分布式环境下构建一个可靠的计算机系统有指导意义。

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

## 不可能的结果

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;拜占庭将军问题看起来是有一些欺骗性的简单，其困难在于如果将军和中尉之间仅通过口头消息传递信息，那么如果将军和中尉的数量中没有超过2/3的人是忠诚的话，这个问题是无解的。如果只有一个将军和两个中尉，也就是三个参与者，只要其中出现一个叛徒，无论是将军还是中尉，都无法时忠诚的参与者们达成共识。口头消息的内容完全由发送者控制，所以一个叛徒能够传递任意可能的信息。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们现在说明：通过口头信息，三个参与者中有一个叛徒是无解的。为简单起见，我们考虑唯一可能的决定是“进攻”或“撤退”的情况。如下图场景，其中*指挥官*忠诚并发送“进攻”命令，但*中尉2*是叛徒并向*中尉1*报告他收到了“撤退”命令。为了满足**IC2**，*中尉1*必须服从命令进行攻击，但*中尉1*面对一个“进攻”命令和一个“撤退”命令，无法做出决策。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/byzantine-generals-problem/3g-l-is-t.png" width="50%"/>
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;其中红色框的头像是忠诚的参与者，而蓝色的是叛徒。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;现在考虑另一个场景，如下图所示，其中指挥官是叛徒，向中尉1发送“进攻”命令，向中尉2发送“撤退”命令。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/byzantine-generals-problem/3g-g-is-t.png" width="50%"/>
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*中尉1*不知道叛徒是谁，他不能告诉*指挥官*实际上给*中尉2*发送了什么信息。因此，这两个场景在*中尉1*看来是完全相同的。如果叛徒一直在说谎，那么*中尉1*就无法区分这两种情况，在这种两难的境地，*中尉1*无法得出能够满足**IC1**和**IC2**的结论。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 需要证明3m个参与者，其中m个叛徒，是无法使2m个忠诚参与者采用一致的结论或遵循忠诚*将军*的命令，这也就是**IC1**和**IC2**的要求。证明过程使用了反证法，将一个拜占庭将军负责的部队拆分为一组阿尔巴尼亚军团，利用递归的思路加以证明。但是笔者认为通过例证的方式会更加明确，因为对于忠诚的参与者面对的信息一定是相反且均数的。
> 
> 下面模拟4个参与者，1个叛徒，也就是超过3m个参与者，首先看一下忠诚的*将军*和一个叛徒*中尉*。
>
> <center>
> <img src="https://weipeng2k.github.io/hot-wind/resources/byzantine-generals-problem/4g-l-is-t.png" width="50%"/>
> </center>
>
> 忠诚的*将军*发起“进攻”命令，*中尉1*收到的信息是三个：*指挥官*的“进攻”、*中尉2*说收到指挥官的命令是“进攻”和叛徒*中尉3*说收到指挥官的命令是“撤退”，这样*中尉1*可以做出决策：进攻（2票进攻，1票撤退）。这个结论就同时满足了**IC1**和**IC2**。
>
> 如果*将军*是叛徒，那么他会发送给不同的*中尉**以不同的命令，如下图所示：
> 
> <center>
> <img src="https://weipeng2k.github.io/hot-wind/resources/byzantine-generals-problem/4g-g-is-t.png" width="50%"/>
> </center>
>
> 可以看到叛徒*指挥官*发送了命令进攻和撤退数量是不等的，同时忠诚的*中尉*之间会正确的传递信息，这样忠诚的*中尉*会采取进攻（2票进攻，1票撤退），满足了**IC1**，同时对于**IC2**，由于*指挥官*是叛徒，所以也满足**IC2**。
>
> 接下来作者会将命题再次更改（第三次），提出了对于攻击时间的协商，实际和“进攻”或“撤退”的二元选择没有区别，因为对于最终协商的结果一定是准确和无歧义的。这里对于更改后的命题以及证明不再描述，并且更改后的命题在后文中并没有出现引用。

## 一种基于口头消息的解法

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在前文中已经说明，对于使用口头消息来解决拜占庭将军问题以应对**m**个叛徒，必须至少有**3m+1**个参与者。我们现在给出一个适用于**3m+1**或更多参与者的解决方案。每个参与者都能够向其他参与者发送口头消息。口头消息的定义有以下假设（或约束）：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**A1**. 发送的每条消息都能被正确传递；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**A2**. 消息的接收者知道是谁发送的；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**A3**. 可以检测到缺失哪个发送者的消息。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**假设A1和A2**可以防止叛徒干扰其他两个参与者之间的通信，因为通过**A1**，叛徒不能干扰传递的消息，而通过**A2**，叛徒不能通过引入虚假信息来混淆他们的交流。**假设A3**将挫败一个试图通过不发送消息来阻止决策的叛徒。这些假设的实际实现在第6节中讨论。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本节和下一节中的算法要求每个参与者都能够直接向其他参与者发送消息。在第5节中，我们描述了没有此要求的算法。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果*指挥官*是叛徒，*指挥官*可以决定不下达任何命令，以此来使*中尉们*无法达成共识。由于*中尉*必须服从某些命令，需要获得输入，在这种情况下他们需要某些默认命令来服从。因此让“撤退”成为这个默认命令。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;定义口头消息算法 **OM(m)**，对于所有非负整数**m**，*指挥官*通过它向**n-1**名*中尉*发送命令。我们接下来证明**OM(m)**在最多m个叛徒存在的情况下解决了**3m+1**或更多*将军*的拜占庭将军问题。我们发现用*中尉*“获得一个值”而不是“服从命令”来描述这个算法更方便。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 分布式环境下的共识，实际目的就是对于一个问题（变量）有共识（值）。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;该算法假定函数**majority**具有以下特性：如果值`v(i)`的大多数等于**v**，则`majority(v1, v2, … , vn-1)`等于**v**。对`majority(v1,v2,…,vn-1)`：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**1**. `v(i)` 中的多数值，如果不存在则为“撤退”；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**2**. `v(i)` 的中位数，假设它们来自一个有序集合。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 涉及到分布式环境中，一个节点的值，那么上述函数就是一种最朴素的算法，也就是取其他**n-1**个节点的值，然后多数值为自己的值。这点可以理解为，一个节点去获取值，如果集群中其他的节点都会返回这个值的内容，那么就取多数。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;根据上述的**majority**算法约束，m为非负整数，对于**OM**算法描述如下：

```java
if (m == 0) {
    (1) 指挥官将他的值发送给每个中尉；
    (2) 每个中尉使用他从指挥官那里得到的值，如果没有收到值，则默认“撤退”。
} else {
    (1) 指挥官将他的值发送给每个中尉；
    (2) 对于每个中尉i，令vi是中尉i从指挥官那里得到的值，如果没有收到任何值，则默认“撤退”。中尉i接下来作为指挥官，运行OM(m-1)算法，将值vi发送给n-2个其他中尉；
    (3) 对于每个中尉i，以及每个j不等于i（也就是其他中尉），令v(j)是在步骤(2)中从中尉j那里得到的值，如果没有收到值，则默认“撤退”。中尉i使用值为majority(v1, v2, … , vn-1)。
}
```

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 针对`m=1, n=4`的场景，在上一节中笔者已经做了描述，这里不再赘述。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;为了证明算法`OM(m)`对任意m的正确性，我们首先证明以下引理。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**引理1**. 对于任何**m**和**k**，如果有超过`2k+m`名*将军*（或参与者）和至多**k**名叛徒，则算法`OM(m)`满足**IC2**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**证明**：使用数学归纳法通过对**m**的归纳来证明。很容易看出算法`OM(0)`在*指挥官*忠诚的情况下是成立的，因此当`m=0时`引理成立。**IC1**要求所有忠诚的*中尉*有一致的值，而**IC2**要求忠诚的*中尉*会执行忠诚**将军**的命令，在`m=0`时，**IC2**会达成，且**IC1**会随之达成。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们现在假设`m-1`并且`m>0`成立，然后证明**m**时引理成立。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在步骤(1)中，忠诚的*指挥官*将值**v**发送给所有`n-1`名*中尉*。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在步骤(2)中，每个忠诚的*中尉*对`n-1`个参与者应用`OM(m-1)`。由于假设`n>2k+m`，可知`n-1 > 2k+(m-1)`。由于最多有k个叛徒，并且 `n-1 > 2k+(m-1) >= 2k`，因此，对于`n-1`个值**i**中的大多数忠诚的*中尉*，每个忠诚的*中尉*都有`v(i) = v`，因为他在步骤（3）中获得了 `majority(v1,v2,…,vn-1)=v`，所以我们可以应用归纳假设得出结论：对于每个忠诚的*中尉j*，`v(j)=v`。由此，证明了**引理1**满足**IC2**。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 对于引理的证明，实际可以通过分析获得。原因在于`2k+m`，可以拆解为 `k + k + m`，对于接收到值的*中尉*需要面对上述的结论集合，而k与非k（叛徒的结果，权且这么称呼）相互低效，关键票就到了**m**，而**m**为大于0的，使得`2k+m`为真。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在此基础上，提出以下定理，算法`OM(m)`解决了拜占庭将军问题。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**定理1**. 对于任意**m**，如果*将军*（参与者）超过**3m**，叛徒最多**m**，则算法`OM(m)`满足条件**IC1**和**IC2**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**证明**：使用数学归纳法通过对m的归纳来证明。如果没有叛徒，那么很容易看出`OM(0)`满足**IC1**和**IC2**。我们假设该定理对于`OM(m-1)`成立并证明它对于`OM(m), m > 0`成立。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们首先考虑*指挥官*忠诚的情况。通过在**引理1**中取**k**等于**m**，我们看到`OM(m)`满足**IC2**。如果*指挥官*是忠诚的，**IC1**被**IC2**所包含，所以我们只需要在*指挥官*是叛徒的情况下证明**IC1**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;最多有**m**个叛徒，*指挥官*是其中之一，所以最多`m-1`个*中尉*是叛徒。既然有超过**3m**的参与者，就有不少于`3m-1`的*中尉*，`3m - 1 > 3(m - 1)`。因此，我们可以应用归纳假设来得出`OM(m-1)`满足条件**IC1**和**IC2**的结论。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) **Lamport**与其说是一位计算机科学家，还不如说是一名数学家。这点在他的自我描述中也能感觉到，对于定理的提出而言，不是直接描述定理，而是提出引理，利用引理来道出定理，使更具实践性的定理显得更加生动，这点可以看出作者的造诣之深。

## 一种基于签名消息的解法

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;正如我们从之前场景中看到的，正是叛徒撒谎的能力使拜占庭将军问题变得如此困难。如果可以限制这种能力，问题就会变得更容易解决。一种方法是允许*将军*发送不可伪造的签名消息。在消息假设中新增一个约束：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**A4**. (a) 忠诚*将军*的签名不能被伪造，伪造会被（忠诚的*将军*或*中尉*收到后）发现；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;(b) 任何人都可以验证消息签名的真实性。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 由于在实际场景中，不常见到基于签名消息的这种一致性算法，同时它强约束，使得运用起来较为困难。基于签名消息的解法不再赘述，想了解的同学可以参考原文。

## 丢失通信路径

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;同上一节，不赘述。

## 可靠计算机系统

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;除了使用本体上可靠的电路元件之外，我们所知道的实现可靠计算机系统的唯一方法是使用几个不同的“处理器”来计算相同的问题，然后将计算结果进行收集，对其输出进行多数投票以获得单个值。投票可以在系统内执行，也可以由输出给用户，在外部执行。无论是使用冗余电路来实现可靠的个人计算机还是弹道导弹防御系统，思路都是一样的，唯一的区别在于冗余的“处理器”的规模。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用多数投票来实现可靠性是基于所有无故障处理器将产生相同输出的假设。只要它们都使用相同的输入，这就是正确的，因为会通过计算得到相同的输出。然而输入的数据来自某个组件的输出，而这个组件一旦有问题，它会将问题输出给到一个或者多个组件作为它们的输入。此外，如果不同的处理器在值变化时读取该值，即使从一个无故障的输入单元也可以获得不同的值。例如，如果两个处理器在时钟前进的一瞬读取时间值，那么一个可能获得旧时间，另一个可能获得新时间，而这只能通过将读取与时钟的前进同步来防止。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;为了让多数投票产生一个可靠的系统，应该满足以下两个条件：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1. 所有无故障处理器必须使用相同的输入值（因此它们产生相同的输出）。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2. 如果输入单元无故障，则所有无故障进程都使用它提供的值作为输入（因此它们产生正确的输出）。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这些只是我们的交互一致性条件**IC1**和**IC2**，其中*“指挥官”*是产生输入的单位，*“中尉”*是处理器，*“忠诚”*意味着无故障。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 拜占庭将军问题的命题映射到了可靠计算机系统的构建过程。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们已经给出了几种解决方案（口头消息和签名消息的解法），但它们是根据拜占庭将军而不是计算系统来表述的。我们现在研究如何将这些解决方案应用于可靠的计算系统。当然用处理器实现拜占庭将军问题，就需要满足原有的假设A1-A3（算法签名消息SM(m)的假设是A1-A4）的消息传递系统。我们现在按顺序考虑这些假设。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**A1**. 由无故障处理器发送的每条消息都被正确传递。在实际系统中，通信线路虽然会出现故障，但这基本可以保障的；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**A2**. 表明处理器可以确定它收到的任何消息的发送者。这里对计算机系统中传递的消息是可以做到收到消息时，知晓对端是谁的；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**A3**. 可以检测到消息的缺失。消息的缺失只能通过它在某个固定的时间长度内未能到达来检测——换句话说，通过使用某种超时约定。使用超时来满足 A3 需要两个假设：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1. 消息的生成和传输需要固定的最长时间X；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2. 发送方和接收方的时钟在某个固定的最大误差Y范围内同步。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果接收方在X+Y的时刻后还没有收到消息，那么就认为该消息是缺失的，纵使在时刻后收到了该消息，该消息也不会认为被收到。

## 结论

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们已经在各种假设下提出了拜占庭将军问题的几种解决方案，并展示了如何将它们用于实现可靠的计算机系统。这些解决方案在所需的时间量和消息数量方面都是昂贵的。算法`OM(m)`和`SM(m)`都需要长度为`m+1`的消息路径。换句话说，每个*中尉*可能必须等待来自*指挥官*的消息，然后通过**m**个其他*中尉*进行消息交换。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在面对任何可能的故障时实现可靠性是一个难题，其解决方案似乎天生就很昂贵。降低成本的唯一方法是对可能发生的故障类型进行假设。例如：通常假设计算机可能无法响应，但永远不会错误响应。但是当需要极高的可靠性时，不能做这样的假设，需要想求解拜占庭将军问题一样花费大量的精力。
