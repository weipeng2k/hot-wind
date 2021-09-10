# 使用**Seata**来实现**TCC**

## **TCC**的交互过程

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**TCC**是***TRY**-**CANCEL**/**CONFIRM***的缩写（以下简称为**TCC**），它是一种柔性事务的代表技术，相关描述可以在 [https://weipeng2k.github.io/hot-wind/book/compensation-and-tcc.html](https://weipeng2k.github.io/hot-wind/book/compensation-and-tcc.html) 找到。**TCC**本质上仍是一种两阶段提交的变体，也就是在**TRY**阶段将资源的变更已经做完，达到万事俱备只欠东风的状态，而之后所有的事务参与者如果对此无异议，则事务发起者将会请求整体提交，也就是触发**CONFIRM**，反之会执行**CANCEL**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**TCC**需要事务协调者的参与来完成**TCC**中**CANCEL**或**CONFIRM**的触发工作。**TCC**的全局事务由事务参与者发起，所涉及的事务参与者都会创建本地分支事务，这点同**2PC**类似，而本地事务的提交和回滚操作就分别对应于**CONFIRM**和**CANCEL**。**TRY**-**CONFIRM**的过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/tcc-using-seata/try-confirm.png" width="50%" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到全局事务由应用程序发起，一般应用程序也是一个事务参与者，承担全局事务管理角色，负责全局事务的提交或者回滚。由应用程序在事务逻辑中请求不同的事务参与者，收到请求的事务参与者会将本地事务作为一个分支事务和全局事务形成关联，同时也会将上述信息注册至事务协调者。如果应用程序事务逻辑执行完成，各事务参与者均响应正常，代表全局事务可以提交，应用程序则会通知事务协调者提交全局事务，事务协调者在收到通知后会触发各个参与者的确认（**CONFIRM**）逻辑。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**TRY**-**CANCEL**的过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/tcc-using-seata/try-cancel.png" width="50%" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;该过程和**TRY**-**CONFIRM**过程相似，在这个过程中，如果在事务逻辑中调用事务参与者出现错误，则应用程序会通知事务协调者对当前全局事务进行回滚，事务协调者在收到通知后会触发各个参与者的取消（**CANCEL**）逻辑。

## **TCC**的主要优势

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**TCC**的主要优势在于性能不错，有较高的吞吐量。以电商的商品订购场景为例，买家订购商品生成订单，同时会进行商品库存扣减，这个过程需要保证如果库存满足订购的数量，订单有效，反之则订单无效，也就是说订购过程是一个事务。简单起见，整个过程涉及三个事务参与者，分别是：交易前台、订单和商品库存三个微服务系统，交易前台会调用订单和商品库存两个微服务完成订购。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果使用**2PC**来确保该分布式事务的执行，假设在订购过程中，订单微服务生成了订单，但由于调用商品库存系统出现错误（库存不足或调用出错），该全局事务会进行回滚，而该过程对资源的占用如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/tcc-using-seata/2pc-abort-cost-time.png" width="60%" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到参与到该分布式事务的交易前台、订单和商品库存三个微服务，会将参与事务的资源（比如：订单数据和商品库存数据等）进行锁定，而锁定时间会横跨两个阶段。商品库存微服务反馈中止，全局事务必然中止，可是订单微服务依旧要等待协调者的通知才能继续，这使得订单资源被长时间锁定。可以看到，在**2PC**模式下，整个系统的吞吐量存在短板，事务参与者中如果存在比较耗时的操作，将会导致该问题更加明显。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果换用**TCC**来处理这个场景，**TCC**事务参与者会在接受到请求后即刻提交本地事务，事务参与者之间不会由于对方处理耗时过长而相互影响，该过程对资源的占用如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/tcc-using-seata/tcc-cancel-cost-time.png" width="60%" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从**TCC**的交互过程可以看到各个事务参与者所负责的本地事务在接收到调用请求后就会开始处理，一旦完成就会提交。订单微服务在接受到交易前台微服务的调用后就会进行订单创建，不会等待商品库存微服务的处理结果，而当事务协调者发送取消事件给订单微服务时，订单微服务会根据通知所包含的事务上下文关键信息（比如：订单ID）来取消对应的订单，且取消订单的操作也是一个本地事务。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;相比较**2PC**而言，**TCC**对资源的锁定占用时间会短很多，呈现出一种对资源离散且短时占据的形态，而非**2PC**在整个事务周期内都会整块长时间的锁定资源。由于资源锁定时间变短，相同时间下处理本地事务数量自然增多，使得**TCC**模式下，整个系统的吞吐量会有显著的提升。

> 在微服务架构下，可以通过适当提升**TCC**链路上较为耗时的微服务实例数量，使的整个系统的吞吐量更进一步提升。

## **TCC**的使用代价

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**TCC**对资源锁定时间的减少无疑会提升系统的吞吐量，有更好的性能表现，但任何好处都会有交换的代价，而这些代价主要体现在以下两个方面。

### 产品交互方式的改变

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在之前的商品订购场景中，**2PC**和**TCC**模式的不同之处除了在资源锁定上，在数据的可见性上也有非常大的不同。**2PC**在处理该场景时，当订单由于库存不足生成失败，用户（或买家）在后台是无法看到订购失败的订单，并且在数据库层面也不会出现失败订单的记录，因为**2PC**追求的是强一致性，数据被回滚了。用户的订购体感就是感觉订购失败，可能是网络或者系统不稳定，那接下来再试一下就好。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**TCC**在处理该场景时，订单和商品库存之间没有强依赖，虽然在一个全局事务中，但是订单数据会生成，虽然可以通过状态位等技术手段使用户无法查看到该失败订单，可是它确实在数据库中生成了，只是在之后对生成的数据做取消或确认操作，是一种最终一致性的体现。当然可以在随后的**CANCEL**事件处理中将该订单删除，但是这些特殊的处理逻辑已经侵入到了系统实现中，不是一个好的选择。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;适当改变产品的交互方式以适应**TCC**模式会是一个更好的选项。由于**TCC**是两段异步的处理模式，产品需要一定程度上面向失败设计，将失败的订单认为是一种正常的情况，用户可以看到失败的订单并能看到失败的原因。这样在订单生成的初始阶段，可以展示给用户处理中的提示信息，而最终的**CONFIRM**或者**CANCEL**通知完成处理后，反馈给用户最终的处理结果。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;产品交互方式的适当改变，增加面向失败和容错的些许设计，会使得**TCC**模式获得更好的用户体验，同时业务产品和技术实现能够做到对齐。

### 技术实现方式的改变

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**2PC**本质是在数据层面做分布式事务，它不需要应用代码做改造，而**TCC**实质是应用层面的**2PC**，它需要应用代码做改造来满足**TCC**所需的语义。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;微服务接口定义需要做出改变以适应**TCC**，以订单生成接口为例，在**2PC**和**TCC**模式下的不同如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/tcc-using-seata/tcc-interface.png" width="70%" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到在**2PC**（上图左半部分）模式下，应用对于接口的定义不会受到约束，这点是**2PC**的优势，事务协调者同数据源进行协作实现分布式事务，一定程度上对应用透明。而**TCC**（上图右半部分）模式下，应用成为分布式事务中的主角，它需要同事务协调者进行交互，所以在接口定义上需要定义出数据的创建、取消和确认三个不同的方法来分别应对**TCC**中的**TRY**、**CANCEL**和**CONFIRM**逻辑处理。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于**2PC**而言，如果准备阶段投票出现了中止，则在后续的提交阶段数据源会将数据进行回滚。**TCC**实际是需要用户编写取消的逻辑来处理之前**TRY**阶段生成的数据，对于数据源而言，这又是另一次提交。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在上图中的**TCC**模式下，对于订单生成服务`OrderCreateService`定义了三个方法`createOrder`、`cancelOrder`和`confirmOrder`分别应对订单生成过程中的**TRY**、**CANCEL**和**CONFIRM**逻辑。**TCC**除了对应用接口定义产生了侵入，对于这些方法的实现也有隐性的要求，也就是方法实现需要做到幂等。以`cancelOrder`为例，在取消订单时需要先获取订单，且订单是新生成、没有被取消且没有被确认的情况下才能够进行取消处理，这么做的原因在于事务协调者对于应用的通知可能会由于网络（或其他）原因出现延迟或重复通知，所以需要由应用自身的代码逻辑保证逻辑的幂等。

## **Seata**支持**TCC**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用**TCC**，需要一个事务协调者来完成对全局事务（和分支事务）的状态维护与驱动。事务协调者接受事务参与者（也就是微服务应用）本地分支事务的注册，并且在全局事务提交或回滚时调用各个事务参与者相应的确认或取消接口。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**TCC**事务协调者的开源实现目前在业界有多个，其中使用广泛、功能完备且稳定可靠的参考实现当属**Seata**。

> 本文使用的**Seata**版本是2021年4月发布的1.4.2版本，讲述内容主要涉及到**TCC**的使用，更详尽的内容可以访问*seata.io*，参考其官方文档。

### 什么是**Seata**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Seata**是一款开源的分布式解决方案，支持诸如：**AT**（类似**2PC**）、**TCC**、**SAGA**和**XA**多种事务模式。**Seata**是基于**C/S**架构的中间件，微服务应用需要依赖**Seata**客户端来完成和**Seata**服务端的通信，通信协议基于**Seata**自有的RPC协议。微服务应用通过**Seata**远程调用完成分布式事务的开启、注册，同时该链路也接受来自**Seata**服务端（由于事务状态变更而带来）的回调通知，其架构如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/tcc-using-seata/seata-architecture.png" width="70%" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用**Seata**之前，需要先部署**Seata**服务端，服务端会将**Seata**服务注册到注册中心，目的是当依赖**Seata**客户端的微服务应用启动时，可以通过注册中心订阅到**Seata**服务，使**Seata**服务以集群高可用的方式暴露给开发者。**Seata**的客户端和服务端有许多参数可以配置，比如：提交的重试次数或间隔时间，这些配置可以配置在微服务应用或者**Seata**服务端上，但也可以通过将其配置在配置中心上统一的管理起来。**Seata**服务端可以通过依赖外部的数据存储将事务上下文等信息持久化存储起来，使得**Seata**服务端无状态化，进一步提升可用性。**Seata**可以选择多种开源的注册和配置中心以及数据存储，如下表所示：

|类型|可选产品|功能描述|
|---|---|---|
|注册中心|文件、ZooKeeper、Redis、Nacos和ETCD等|**Seata**服务端注册**Seata**服务，**Seata**客户端进行服务发现|
|配置中心|文件、ZooKeeper、Nacos、ETCD和SpringCloud Config等|统一管理和维护**Seata**的配置信息|
|数据存储|文件、关系数据库和Redis|持久化存储全局事务、分支事务以及事务上下文信息|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;微服务应用通过依赖**Seata**客户端来获得同**Seata**服务端通信的能力，**Seata**客户端通过AOP以及对主流RPC框架的扩展来完成对微服务应用间远程调用的信息，在远程调用前开启（或注册）分布式事务，当**Seata**服务端发现事务状态变化时，再回调部署在微服务应用中的**Seata**客户端来执行相应的逻辑。

### **Seata**如何支持**TCC**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在**TCC**模式中，由事务管理器（一般也是事务参与者）开启全局事务，在事务逻辑执行过程中，该链路上所有节点（微服务应用）的分布式调用都会注册相应的分支事务，全局事务和分支事务会产生关联。当事务逻辑执行成功，代表全局事务可以提交，事务协调者会回调各个事务参与者的确认逻辑，反之，回调其取消逻辑。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到事务的开启和（节点之间的）传播是实现**TCC**的关键，**Seata**利用了AOP以及对主流RPC框架进行扩展来提供支持，接下来会简单介绍一下**Seata**对全局事务开启以及传播的主要逻辑，涉及到**Seata**更细节的知识需要读者自行了解。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在需要全局事务控制的方法上，通过添加注解@GlobalTransactional将其标识为全局事务方法，该方法中的逻辑即事务逻辑，在方法中的远程调用也会被全局事务所管理，其主要接口和类（以及部分主要方法）如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/tcc-using-seata/seata-aop.png" width="70%" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到**Seata**客户端通过实现**spring-aop**的方法拦截器来获得对用户方法的拦截。**Seata**将全局事务抽象为`GlobalTransaction`，它和普通事务一样具备开始、提交和回滚等方法，当拦截到用户方法的调用（或异常）时，会触发全局事务对应的方法。**Seata**客户端与服务端通信底层基于**netty**，传输的自有**RPC**协议为`RpcMessage`，当事务管理器`TransactionManager`被调用时，会将相关事务操作远程通知到**Seata**服务端，可以认为在微服务之间进行业务远程调用下还存在着一层透明的**Seata**远程调用。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过AOP以及远程调用的方式，可以让应用透明的开启全局事务，但在微服务架构下，如何能够做到当前事务在微服务之间传播呢？答案是，扩展应用使用的RPC框架。以**Apache Dubbo**为例（以下简称Dubbo），可以看到**Seata**通过扩展**Dubbo**过滤器的方式，在微服务之间传播事务，部分关键代码如下所示：

```java
@Activate(group = {DubboConstants.PROVIDER, DubboConstants.CONSUMER}, order = 100)
public class ApacheDubboTransactionPropagationFilter implements Filter {

    @Override
    public Result invoke(Invoker<?> invoker, Invocation invocation) throws RpcException {
        String xid = RootContext.getXID();
        BranchType branchType = RootContext.getBranchType();

        String rpcXid = RpcContext.getContext().getAttachment(RootContext.KEY_XID);
        String rpcBranchType = RpcContext.getContext().getAttachment(RootContext.KEY_BRANCH_TYPE);
        boolean bind = false;
        if (xid != null) {
            RpcContext.getContext().setAttachment(RootContext.KEY_XID, xid);
            RpcContext.getContext().setAttachment(RootContext.KEY_BRANCH_TYPE, branchType.name());
        } else {
            if (rpcXid != null) {
                RootContext.bind(rpcXid);
                if (StringUtils.equals(BranchType.**TCC**.name(), rpcBranchType)) {
                    RootContext.bindBranchType(BranchType.**TCC**);
                }
                bind = true;
            }
        }
        try {
            return invoker.invoke(invocation);
        } finally {
            // 略
        }
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Dubbo**提供了对调用链路扩展的能力，这也是一款成熟的**RPC**框架需要必备的基础能力。可以看到在上述代码逻辑中，**Seata**的扩展点先尝试获取本地事务信息（包括：事务ID和事务模式），然后尝试获取**Dubbo**请求上下文中对应的远程事务信息。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果能够获取到存储在`ThreadLocal`中的本地事务信息，表明当前代码运作在一个全局事务中，则尝试将事务信息放置到**Dubbo**请求上下文中，使之能够传递到下一个微服务节点。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果本地事务信息没有获取到，而远程事务信息存在，这表明本次调用是**Seata**事务调用，则需要恢复远程事务信息到当前`ThreadLocal`中，将全局事务能够连接起来。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过扩展**Dubbo**的`Filter`，使得**Seata**的全局事务具备了击鼓传花般的远程传输能力，事务逻辑中所有的分布式调用，均会在请求中“**沾染**”上事务信息，而这些信息也会被**Seata**服务端所掌握，最终在事务完成时，发起对所有事务参与者的回调。

## 一个基于**Seata**的参考示例

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;以前文中商品订购场景为例，基于**SpringBoot**和**Dubbo**来实现该功能，同时依靠**Seata**确保分布式事务。示例中的部分业务代码仅打印了参数或结果，目的是方便读者观察执行的过程，本文接下来针对关键代码进行介绍，应用全部代码可以在：[https://github.com/weipeng2k/seata-tcc-guide](https://github.com/weipeng2k/seata-tcc-guide) 找到。

### 部署**Seata**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在运行示例前需要部署**Seata**服务端，**Seata**服务端一般以集群的方式进行部署，依赖注册和配置中心以及外部存储做到高可用。由于本文主要介绍微服务应用如何使用**Seata**实现**TCC**，简单起见采用单节点的方式进行部署。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以选择在官网下载**Seata**服务端，解压后运行`seata-server.sh`启动，如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/tcc-using-seata/seata-server-download.png" width="70%" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;默认**Seata**服务端的依赖（注册和配置中心以及外部存储）是本地文件。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;当然也可以使用**Docker**进行部署，在安装了**Docker**的机器上运行如下命令：

```sh
docker run --name seata-server -p 8091:8091 -d seataio/seata-server:latest
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;该命令在当前机器上启动了**Seata**服务端，同时暴露了**Seata**服务端的（默认）端口。

> 如果不在本机部署**Seata**服务端，需要记录部署了**Seata**服务端机器的**IP**，并且能够确保之后部署的微服务应用能够访问该**IP**。微服务应用中的配置项`seata.service.grouplist.default`需要配置为服务端的**IP**和端口。

### 应用代码简介

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本示例中商品订购场景涉及三个微服务应用，其相关信息如下表所示：

|应用|前台交易微服务|订单微服务|商品微服务|
|---|---|---|---|
|名称|**trade-facade**|**order-service**|**product-service**|
|领域实体|无|订单|商品库存<br>库存占用明细|
|接口服务|TradeAction，商品下单接口|`OrderCreateService`，订单创建服务|`ProductInventoryService`，商品库存服务|
|功能描述|接收前端请求，调用`OrderCreateService`创建订单，同时调用`ProductInventoryService`扣减对应商品的库存|实现并发布`OrderCreateService`，维护订单模型与数据|实现并发布`ProductInventoryService`，维护商品库存相关模型与数据|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;用户订购请求通过**trade-facade**进入，首先会调用**order-service**生成订单，此时订单的是否可用状态为`false`，然后**trade-facade**调用**product-service**进行库存扣减，如果库存充足则减少商品预扣库存数量同时生成库存占用明细，以上为**TRY**阶段，相关部分代码如下：

```java
@Component("tradeAction")
public class TradeActionImpl implements TradeAction {

    @DubboReference(group = "dubbo", version = "1.0.0")
    private `OrderCreateService` orderCreateService;
    @DubboReference(group = "dubbo", version = "1.0.0")
    private `ProductInventoryService` productInventoryService;

    // fake id generator
    private final AtomicLong orderIdGenerator = new AtomicLong(System.currentTimeMillis());

    @Override
    @GlobalTransactional
    public Long makeOrder(Long productId, Long buyerId, Integer amount) {
        RootContext.bindBranchType(BranchType.**TCC**);
        CreateOrderParam createOrderParam = new CreateOrderParam();
        createOrderParam.setProductId(productId);
        createOrderParam.setBuyerUserId(buyerId);
        createOrderParam.setAmount(amount);
        Long orderId;
        try {
            orderId = orderIdGenerator.getAndIncrement();
            orderCreateService.createOrder(createOrderParam, orderId);
        } catch (OrderException ex) {
            throw new RuntimeException(ex);
        }

        OccupyProductInventoryParam occupyProductParam = new OccupyProductInventoryParam();
        try {
            occupyProductParam.setProductId(productId);
            occupyProductParam.setAmount(amount);
            occupyProductParam.setOutBizId(orderId);
            productInventoryService.occupyProductInventory(occupyProductParam, orderId.toString());
        } catch (ProductException ex) {
            throw new RuntimeException(ex);
        }

        return orderId;
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到`makeOrder`方法上标注了`GlobalTransactional`注解，表示该方法需事务保证，同时通过`RootContext`设置当前的事务模式为**TCC**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于`OrderCreateService`和`ProductInventoryService`，也需要增加**Seata**的注解，使得之后的**CANCEL**或**CONFIRM**通知能够调用到相应的逻辑，以`OrderCreateService`为例，代码如下：

```java
@LocalTCC
public interface OrderCreateService {

    /**
     * 根据参数创建一笔订单
     *
     * @param param   订单创建参数
     * @param orderId 订单ID
     * @throws OrderException 订单异常
     */
    @TwoPhaseBusinessAction(name = "orderCreateService", commitMethod = "confirmOrder", rollbackMethod = "cancelOrder")
    void createOrder(CreateOrderParam param,
                     @BusinessActionContextParameter(paramName = "orderId") Long orderId) throws OrderException;

    /**
     * <pre>
     * 根据订单ID确认订单
     * </pre>
     *
     * @param businessActionContext 业务行为上下文
     * @throws OrderException 订单异常
     */
    void confirmOrder(BusinessActionContext businessActionContext) throws OrderException;

    /**
     * <pre>
     * 根据订单ID作废当前订单
     * </pre>
     *
     * @param businessActionContext 业务行为上下文
     * @throws OrderException 订单异常
     */
    void cancelOrder(BusinessActionContext businessActionContext) throws OrderException;
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到接口声明需要标注`LocalTCC`注解，同时在**TRY**阶段（也就是`createOrder`）方法上标注`TwoPhaseBusinessAction`注解，而其中`commitMethod`和`rollbackMethod`分别对应**CONFIRM**和**CANCEL**阶段方法。通过`TwoPhaseBusinessAction`注解的声明，**Seata**会知晓在全局事务提交或回滚时调用该微服务应用的哪个方法。

> `LocalTCC`、`TwoPhaseBusinessAction`和`BusinessActionContextParameter`注解需要标注在接口上才能被**Seata**所识别，这也是为什么**TCC**模式对应用的侵入性较强的一个原因

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果订购成功，全局事务可以提交，**Seata**服务端会回调参与事务微服务的**CONFIRM**逻辑。**order-service**的`confirmOrder`方法会被调用，订单的可用状态会被更新为`true`。**product-service**的`confirmProductInventory`方法会被调用，真实库存会被扣减，库存占用明细状态会更新为成功。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果订购失败，全局事务需要回滚，失败的原因可能是调用**order-service**或**product-service**服务出现业务异常，比如：生成订单失败或库存不足，也有可能是系统异常，比如：调用超时或网络传输异常等，**Seata**服务端会回调参与事务微服务的**CANCEL**逻辑。**order-service**的`cancelOrder`方法会被调用，订单可用状态会被更新为`false`。**product-service**的`cancelProductInventory`方法会被调用，预扣库存会被增加，库存占用明细状态会更新为取消。

> **Seata**服务端会回调参与事务微服务的相应逻辑，这个参与代表着业务远程调用已经发起，如果没有执行则不会发起对应的回调。比如：在`makeOrder`方法代码中，逻辑上的事务参与者有**trade-facade**、**order-service**和**product-service**，但如果`makeOrder`方法在实际执行中，调用到**order-service**就抛错了，则**CANCEL**回调只会通知到**trade-facade**和**order-service**。

### 订购示例演示

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;订购示例逻辑为，先初始化一个商品的库存为20，然后本地模拟10个并发请求用于订购商品，每次订购的数量为3，相关代码如下所示：

```java
@SpringBootApplication
@EnableDubbo
@Configuration
public class TradeApplication implements CommandLineRunner {

    private final ThreadPoolExecutor threadPoolExecutor = new ThreadPoolExecutor(10, 10, 5, TimeUnit.SECONDS,
            new LinkedBlockingQueue<>());
    @Autowired
    private TradeAction tradeAction;

    public static void main(String[] args) {
        SpringApplication.run(TradeApplication.class, args);
    }

    @Override
    public void run(String... args) throws Exception {
        tradeAction.setProductInventory(1L, 20);
        CountDownLatch start = new CountDownLatch(1);
        CountDownLatch stop = new CountDownLatch(10);
        AtomicInteger orderCount = new AtomicInteger();
        for (int i = 1; i <= 10; i++) {
            int userId = i;
            threadPoolExecutor.execute(() -> {
                try {
                    start.await();
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
                try {
                    tradeAction.makeOrder(1L, (long) userId, 3);
                    orderCount.incrementAndGet();
                } catch (Exception ex) {
                    // Ignore.
                } finally {
                    stop.countDown();
                }
            });
        }

        start.countDown();

        stop.await();

        Thread.sleep(1000);

        System.err.println("订单数量：" + orderCount.get());
        System.err.println("库存余量：" + tradeAction.getProductInventory(1L));
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;先启动**order-service**和**product-service**，然后运行**trade-facade**，可以看到输出：

```sh
订单数量：6
库存余量：2
```

> 微服务需要依赖注册中心，本示例的注册中心使用的是**ZooKeeper**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;输出显示生成6笔订单，每笔订单包含3件商品，因此商品库存还剩2件，这表示有4笔订单被取消，可以观察**order-service**的标准输出，能够看到**TRY**阶段的相关（部分）输出：

```sh
买家{7}购买商品{1}，数量为{3}，订单{1631264872732}生成@2021-09-10 17:07:56[DubboServerHandler-192.168.31.133:20880-thread-3] in Tx(172.18.0.3:8091:27191024100888792)
.
.
买家{10}购买商品{1}，数量为{3}，订单{1631264872731}生成@2021-09-10 17:07:56[DubboServerHandler-192.168.31.133:20880-thread-4] in Tx(172.18.0.3:8091:27191024100888799)
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;总共10条记录，可以看到每笔订单均在不同的事务（Tx）中生成，且运行的线程为**Dubbo**服务端线程。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在**TRY**阶段之后，会出现**CANCEL**和**CONFIRM**阶段的（部分）输出：

```sh
买家{7}购买商品{1}，数量为{3}，订单{1631264872732}启用@2021-09-10 17:07:56[rpcDispatch_RMROLE_1_1_24] in Tx(172.18.0.3:8091:27191024100888792)
.
.
买家{9}购买商品{1}，数量为{3}，订单{1631264872728}取消@2021-09-10 17:07:57[rpcDispatch_RMROLE_1_8_24] in Tx(172.18.0.3:8091:27191024100888793)
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;其中订单启用的输出有6条，订单取消的输出有4条，同时注意到运行的线程为**Seata**的资源管理器线程。

> **TCC**不同阶段的逻辑一般是由不同线程运行的，所以在实际使用过程中，需要注意线程安全问题。

## **Seata**的一些问题
