# 一种基于补偿的事务处理机制（TCC）

## 介绍

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;随着Web服务的成熟和广泛使用，涉及到Web服务的安全、事务和稳定性相关的技术和协议就变得愈发重要。本文重点关注Web服务的事务，尤其是长时间运行事务的概念以及对Web服务实现者的影响。我们将研究事务和补偿如何满足Web服务实现者的业务模型，以及架构需要得到哪种程度的支持。

> 本文是翻译和总结**Guy Pardon**的论文《Business Transactions, Compensation and the Try- Cancel/Confirm (TCC) Approach for Web Services》，该论文没有涉及数学公式，所以读起来比较简单。在翻译的过程中，会增加笔者自己的所得。

## 定义

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在我们开始之前，让我们确保就一些重要的术语达成一致。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**事务**：就本文而言，事务是一组相关的操作（或交互），它们可能由于（部分失败导致的）回滚，而需要在执行后取消。这些操作可以位于不同的地理位置，例如：Internet上的不同Web服务。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 一个Web服务可能会聚合多个Web服务来完成一个具有业务含义的操作，如果对于用户而言，需要保证要么成功，要么失败，那么这些不同实现者提供的Web服务需要在一个事务语义下得到保证。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**长时间运行的事务（或业务事务）**：就本文而言，长时间运行事务的总持续时间超过单个操作持续时间几个数量级。由于长时间运行事务的持续时间很长，因此导致该类型的事务进行撤销时，会在相对较长的时间内取消操作。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 事务除了可见性的要求，还有完整性的诉求，也就是由多个Web服务聚合的一个事务需要这些Web服务都能够一并完成，所以该事务的持续（或消耗）时间会比单个Web长很多。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**示例**：图1展示通过Web服务来预定旅行的航班，预定的路线是从布鲁塞尔到多伦多，路线是由两个航班组成的，这两个航班是从布鲁塞尔到华盛顿和从华盛顿到多伦多。如果这两个航班的预定是由两个航空公司提供，由两个Web服务在不同的系统中来实现。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/compensation-and-tcc/booking-a-flight-at-two-services.png" width="50%" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果第二个操作调用失败，那么我会被只有一张从布鲁塞尔到华盛顿的机票卡住（这当然很有趣，但它违背了我去多伦多旅行计划的目的）。在这种情况下，取消去往华盛顿的票可能是一个有效的选择，但是，在我决定这样做之前，我可能一直在寻找替代方案，例如：两小时左右后的另一次从华盛顿到多伦多的转机。而这可能会导致非常长时间运行的整体事务。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;请注意，这里的关键点是在我决定取消第一张票时已经进行了预订。也就是说，航空公司预订系统已经接受并验证了我的第一次预订，并且至少会保留我的座位一段时间。如果没有取消事件，那么要么我付款了，白订了一张票，要么航空公司会因不需要的预订而赔钱。无论哪种方式，都会有人赔钱。因此，取消事件是有很大的驱动力（或者说价值）。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;纯粹从技术上讲，取消不同位置的不同操作并不是什么新鲜事：几十年来，它一直由称为事务管理器或事务服务的东西完成。**CORBA**的**OTS**（对象事务服务）就是这种技术的一个例子，**J2EE**的Java事务API和Java事务服务（JTA/JTS）是另一个例子。

> ![self-think](https://weipeng2k.github.io/hot-wind/resources/self-think.png) 这里提到的取消在技术上一般称为回滚，但是这种回滚往往在业务语义上是有描述的，比如：在分支逻辑中进行了描述，如果订购不到第二张票该如何处理。因此对于产品设计而言，考虑容错性和面向失败设计，对于产品的用户体验和技术实现都会获得更好的结果。
>
> 在技术实现过程中，面对分布式事务的问题，往往是开发比较关注的，会花费更多的时间加以实现，保障其可靠性。此时产品需要明白这种局限性和挑战，在产品设计中就能够针对事务中的断裂（权且这么叫）进行贴心的设计，这样会使产品更加的贴心，同时也会让开发人员避免毫无依靠的野战。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这些技术都是基于**ACID**事务的概念。ACID事务要求的工作方式如下：事务访问的所有资源都被当前事务锁定，而其他并行事务无法访问被锁定的资源，直到事务提交（保存更改）或回滚（取消更改）。图2对**ACID**事务的锁定时间进行了说明。
