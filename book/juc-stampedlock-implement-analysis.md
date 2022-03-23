# StampedLock的实现分析

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;接下来分析`StampedLock`的实现，主要包括：状态与（同步队列运行时）结构设计、写锁的获取与释放以及读锁的获取与释放。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/juc-summary/juc-stampedlock-implement-page.jpg">
</center>

## 状态与结构设计

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`StampedLock`没有选择使用**AQS**来实现，原因是它对状态和同步队列的实现有不同需求。首先看状态，`StampedLock`需要状态能够体现出版本的概念，随着写锁的获取与释放，状态会不断的自增，而自增的状态能够反映出锁的历史状况。如果状态能够像数据库表中的主键一样提供唯一约束的能力，那么该状态就可以作为快照返回给获取锁的使用者，而这个快照，也就是邮戳，可以在后续同当前状态进行比对，以此来判断数据是否发生了更新。相比之下，**AQS**的状态反映的是任意时刻锁的占用情况，不具备版本的概念，因此`StampedLock`的状态需要全新设计。接着是同步队列的实现，**AQS**将同步队列中的节点出入队以及运作方式做了高度的抽象，这种使用模版方法模式的好处在于扩展成本较低，但是面对新场景却力不从心。虽然在程序运行在多处理器环境下，但并发冲突却不是常态，以获取锁为例，适当的自旋重试要优于一旦无法获取锁就立刻进入阻塞状态，**AQS**的实现与后者相似，它会导致过多的上下文切换，而选择前者的StampedLock就需要重新实现同步队列。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`StampedLock`使用了名为`state`的`long`类型成员变量来维护锁状态，其中低**7**位表示读，第**8**位表示写，其他高位表示版本，划分方式如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/juc-summary/juc-stampedlock-status.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，`state`实际仅使用低**8**位用于存储当前锁的状态，第**8**位如果是真（也就是`1`）表示存在写，反之不存在写。写锁具有排他性，使用一个位来表示，理论是足够的，但读锁具有共享性，需要使用一个数来保存状态。多个线程获取到读锁时，会增加低**7**位的数，而释放读锁时，也会相应的减少它，但二进制的**7**位最大仅能描述`127`，所以一旦超过范围，`StampedLock`会使用一个名为`readerOverflow`的`int`类型成员变量来保存**“溢出”**的读状态。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`StampedLock`仅用一位来表示写状态，就不能像**AQS**实现的读写锁那样，用一个**16**位的数来描述写被获取了多少次，从这里就可以看出该锁不支持重入的原因。如果写锁被获取，第**8**位会被置为`1`，但写锁的释放不是简单的将第**8**位取反，而是将`state`加上`WBITS`，这样操作，不仅可以将第**8**位置为`0`，还可以产生进位，影响到高**56**位，让高**56**位如同一个自增的版本一样，每次写锁的获取与释放，都会使得（数据）版本变得不同。如果不同线程看到的锁版本是一致的，那么它们本地所保存受到锁保护的数据也应该是相同的，这也就是乐观读锁运行的基础。

> `StampedLock`实际使用包含了写操作位的高**57**位作为锁的版本。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`StampedLock`定义了若干`long`类型的常量，比如：描述写操作位为真的`WBITS`，`state`能够描述的最大读状态`RBITS`等，这些常量与状态进行表达式运算可以实现一些锁相关的语义，比如：判断锁是否存在读等。主要语义与表达式描述如下表所示：

|语义|表达式|描述|
|---|---|---|
|是否存在读|`state & RBITS > 0`|为真代表存在读|
|是否存在写|`state & WBITS != 0`|为真代表存在写|
|验证邮戳（或版本）|`(stamp & SBITS) == (state & SBITS)`|`stamp`为指定的邮戳，验证邮戳会比对`stamp`和`state`的高**57**位|
|是否没有读写|`state & ABITS == 0`|为真代表没有读写|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;状态能够表示锁的读写情况，而等待获取锁的读写请求如何排队，就需要同步队列来解决。`StampedLock`自定义了同步队列，该队列由自定义节点（`WNode`）组成，该节点比**AQS**中的节点复杂一些，其成员变量与描述如下表所示：

|字段名称|字段类型|描述|
|---|---|---|
|`prev`|`WNode`|节点的前驱|
|`next`|`WNode`|节点的后继|
|`cowait`|`WNode`|读链表，实际是栈|
|`thread`|`Thread`|等待获取锁的线程|
|`status`|`int`|节点的状态<br>`0`，默认<br>`1`，取消<br>`-1`，等待|
|`mode`|`int`|节点的类型<br>`0`，读<br>`1`，写|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`WNode`通过`prev`和`next`组成双向链表，而`cowait`会将等待获取锁的读请求以栈的形式进行分组排队。接下来用一个例子来说明队列是如何运作的，假设有**5**个线程（名称分别为：**A**、**B**、**C**、**D**和**E**）顺序获取`StampedLock`，其中线程**A**和**E**获取写锁，而其他**3**个线程获取读锁，这些线程都只是获取锁而不释放锁，因此只有线程**A**可以获取到写锁，其他线程都会被阻塞。当线程**E**尝试获取写锁后，同步队列的节点组成如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/juc-summary/juc-stampedlock-clh-queue.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，`StampedLock`通过`whead`和`wtail`分别指向同步队列的头尾节点。节点**A**是首节点，它是由第一个未获取到锁而被阻塞的线程所创建的，也就是线程**B**，该节点的类型是写，状态为等待。节点**E**是尾节点，线程**E**由于未获取到写锁，从而创建该节点并加入到队列中，节点类型为写，而状态为默认。节点状态的修改，是由后继节点在获取锁的过程中完成的，因为没有第**6**个线程获取锁，所以节点E的状态是默认，而非等待，获取锁的过程会在后续章节中详细介绍。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，同步队列的主队列是横向的节点**A**、**B**和**E**，而在节点**B**出现了纵向的子队列，原因是`StampedLock`将被阻塞的连续读请求进行了分组排队。节点**B**先进入同步队列，随后读类型的节点**C**会挂在前者`cowait`引用下，形成节点**B**至**C**的一条纵向队列。线程**D**由于未能获得读锁，也会创建节点并加入到了同步队列，此时尾节点是节点**B**，`StampedLock`选择将节点**D**入栈，形成顺序为节点**B**、**D**和**C**的栈。为什么纵向队列使用栈来实现，而不是链表呢？原因在于读类型的节点新增只需要由读类型的尾节点发起即可，这样做既省时间又省空间，因为不需要遍历到链表的尾部，更不需要保有一个链表尾节点的引用。

> 如果有被阻塞的离散读请求，中间再混有若干写请求，则会产生多个纵向子队列（栈），此时保有链表尾节点引用的实现方式就显得不切合实际了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果线程**E**是获取读锁，那么栈中节点的顺序是节点**B**、**E**、**D**和**C**。如果有第**6**个线程获取锁，不论是它是获取读锁还是写锁，都会排在节点**E**之后，同时节点E的状态会被设置为`-1`，即等待状态。

## 写锁的获取与释放

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;获取写锁的流程主要包括两部分，尝试获取写锁并自旋入队和队列中自旋获取写锁。如果打开`StampedLock`源码，会发现获取写锁的逻辑看起来十分复杂，实现包含了大量的循环以及分支判断，而主要逻辑并不是在一个分支中就完成的，而是由多次循环逐步达成。获取写锁的主要流程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/juc-summary/juc-stampedlock-acquire-write-lock.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，左右两侧分别对应流程的两部分。线程在获取写锁时，首先会尝试自旋获取，而获取的操作就是在没有读写状态的情况下设置写状态，如果设置成功会立刻返回，否则将会创建节点加入到同步队列。接下来，在同步队列中，如果该节点的前驱节点处于等待状态，则会阻塞当前线程。在队列中成功获取写锁的条件是前驱节点是头节点，并成功设置写状态，而被阻塞的线程会被前驱节点的释放操作所唤醒，这点与**AQS**的同步队列工作机制相似。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;成功获取写锁后会得到当前状态的快照，即邮戳，在释放写锁时，需要传入该邮戳，释放写锁的主要流程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/juc-summary/juc-stampedlock-release-write-lock.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，（外部）输入的邮戳与状态理论上应该相同，因为写锁具有排他性，从写锁的获取到释放，状态不会发生改变，所以之前返回的邮戳和当前状态应该相等。释放写锁会唤醒后继节点对应的线程，被唤醒的线程会继续执行先前获取锁的逻辑，在队列中自旋获取写锁。

## 读锁的获取与释放

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;获取读锁的流程与写锁类似，但实现要复杂的多，主要原因在于`cowait`读栈的存在，新加入队列的读类型节点会根据尾节点的类型来执行不同的操作。获取读锁的主要流程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/juc-summary/juc-stampedlock-acquire-read-lock.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图（左侧）所示，在节点`node`加入到同步队列时，会判断当前尾节点的类型，如果是读类型，就选择入栈尾节点的`cowait`，否则将会被设置为同步队列的尾节点。进入到`cowait`读栈的节点会成为栈顶节点的附属，当栈顶节点被唤醒时，它们也会随之被唤醒。进入到横向主队列的节点会尝试自旋获取读锁，当其前驱节点为头节点时，如果锁的状态仅存在读，则进行读状态的设置，设置读状态成功代表获取到了写锁。读状态的设置需要判断现有的读状态是否超出`state`读状态的上限，如果超过就需要自增`readerOverflow`。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`StampedLock`中的`state`与`readerOverflow`合力维护了读状态，因此读锁的释放相比写锁要复杂一些，写锁一旦释放就可以唤醒后继节点，而释放读锁不能立刻唤醒后继节点，需要等到读状态减为`0`时才能执行。释放读锁的主要流程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/juc-summary/juc-stampedlock-release-read-lock.png">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，需要先判断当前状态与传入的邮戳，二者的版本（也就是高**57**位）是否相同，如果相同则会对读状态进行自减操作。当读状态为`0`时，释放读锁会唤醒后继节点对应的线程，被唤醒的线程会继续执行先前获取读锁的逻辑。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`StampedLock`为了避免状态以及同步队列头尾指针出现数据不一致的情况，在实现锁的获取与释放时，都会提前将其拷贝到本地变量。实现涉及到大量的`for`循环和`if`判断，使得读懂它需要花些时间，建议读者结合流程图阅读一下源码，感受一下作者（**Doug Lea**）缜密的逻辑。
