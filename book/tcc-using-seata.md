# 使用`Seata`来实现`TCC`

## TCC的交互过程

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;TCC是TRY-CANCEL/CONFIRM的缩写（以下均简称为TCC），它是一种柔性事务的代表技术，相关描述可以在 连接 找到。TCC本质上仍是一种两阶段提交的变体，也就是在TRY阶段将资源的变更已经做完，达到万事俱备只欠东风的状态，而之后所有的事务参与者如果对此无异议，则事务发起者将会请求整体提交，也就是触发CONFIRM，反之会执行CANCEL。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;TCC需要事务协调者的参与来完成TCC中CANCEL或CONFIRM的触发工作。TCC的全局事务由事务参与者发起，所涉及的事务参与者都会创建本地分支事务，这点同2PC类似，而本地事务的提交和回滚操作就分别对应于CONFIRM和CANCEL。TRY-CONFIRM的过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/tcc-using-seata/try-confirm.png" width="60%" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到全局事务由应用程序发起，一般应用程序也是一个事务参与者，承担全局事务管理角色，负责全局事务的提交或者回滚。由应用程序在事务逻辑中请求不同的事务参与者，收到请求的事务参与者会将本地事务作为一个分支事务和全局事务形成关联，同时也会将上述信息注册至事务协调者。如果应用程序事务逻辑执行完成，各事务参与者均响应正常，代表全局事务可以提交，应用程序则会通知事务协调者提交全局事务，事务协调者在收到通知后会触发各个参与者的确认（CONFIRM）逻辑。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;TRY-CANCEL的过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/tcc-using-seata/try-cancel.png" width="60%" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;该过程和TRY-CONFIRM过程相似，在这个过程中，如果在事务逻辑中调用事务参与者出现错误，则应用程序会通知事务协调者对当前全局事务进行回滚，事务协调者在收到通知后会触发各个参与者的取消（CANCEL）逻辑。

## TCC的主要优势

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;TCC的主要优势在于性能不错，有较高的吞吐量。以电商的商品订购场景为例，买家订购商品生成订单，同时会进行商品库存扣减，这个过程需要保证如果库存满足订购的数量，订单有效，反之则订单无效，也就是说订购过程是一个事务。简单起见，整个过程涉及三个事务参与者，分别是：交易前台、订单和商品库存三个微服务系统，交易前台会调用订单和商品库存两个微服务完成订购。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果使用2PC来确保该分布式事务的执行，假设在订购过程中，订单微服务生成了订单，但由于调用商品库存系统出现错误（库存不足或调用出错），该全局事务会进行回滚，而该过程对资源的占用如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/tcc-using-seata/2pc-abort-cost-time.png" width="60%" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到参与到该分布式事务的交易前台、订单和商品库存三个微服务，会将参与事务的资源（比如：订单数据和商品库存数据等）进行锁定，而锁定时间会横跨两个阶段。商品库存微服务反馈中止，全局事务必然中止，可是订单微服务依旧要等待协调者的通知才能继续，这使得订单资源被长时间锁定。可以看到，在2PC模式下，整个系统的吞吐量存在短板，事务参与者中如果存在比较耗时的操作，将会导致该问题更加明显。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果换用TCC来处理这个场景，TCC事务参与者会在接受到请求后即刻提交本地事务，事务参与者之间不会由于对方处理耗时过长而相互影响，该过程对资源的占用如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/tcc-using-seata/tcc-cancel-cost-time.png" width="60%" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从TCC的交互过程可以看到各个事务参与者所负责的本地事务在接收到调用请求后就会提交，相比较2PC而言，TCC对资源的锁定占用时间会短很多，呈现出一种对资源离散且短时占据的形态，而非2PC在整个事务周期内都会整块长时间的锁定资源。由于资源锁定时间变短，使得TCC模式下，整个系统的吞吐量会有显著的提升。

## TCC的使用代价

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;TCC对资源锁定时间的减少无疑会提升系统的吞吐量，有更好的性能表现，但任何好处都会有交换的代价，而这些代价主要体现在以下两个方面。

### 产品交互方式的改变

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在之前的商品订购场景中，2PC和TCC模式的不同之处除了在资源锁定上，在数据的可见性上也有非常大的不同。2PC在处理该场景时，当订单由于库存不足生成失败，用户（或买家）在后台是无法看到订购失败的订单，并且在数据库层面也不会出现失败订单的记录，因为2PC追求的是强一致性，数据被回滚了。用户的订购体感就是感觉订购失败，可能是网络或者系统不稳定，那接下来再试一下就好。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;TCC在处理该场景时，订单和商品库存之间没有强依赖，虽然在一个全局事务中，但是订单数据会生成，虽然可以通过状态位等技术手段使用户无法查看到该失败订单，可是它确实在数据库中生成了，只是在之后对生成的数据做取消或确认操作，是一种最终一致性的体现。当然可以在随后的CANCEL事件处理中将该订单删除，但是这些特殊的处理逻辑已经侵入到了系统实现中，不是一个好的选择。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;适当改变产品的交互方式以适应TCC模式会是一个更好的选项。由于TCC是两段异步的处理模式，产品需要一定程度上面向失败设计，将失败的订单认为是一种正常的情况，用户可以看到失败的订单并能看到失败的原因。这样在订单生成的初始阶段，可以展示给用户处理中的提示信息，而最终的CONFIRM或者CANCEL通知完成处理后，反馈给用户最终的处理结果。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;产品交互方式的适当改变，增加面向失败和容错的些许设计，会使得TCC模式获得更好的用户体验，同时业务产品和技术实现能够做到对齐。

### 技术实现方式的改变

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2PC本质是在数据层面做分布式事务，它不需要应用代码做改造，而TCC实质是应用层面的2PC，它需要应用代码做改造来满足TCC所需的语义。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;微服务接口定义需要做出改变以适应TCC，以订单生成接口为例，在2PC和TCC模式下的不同如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/tcc-using-seata/tcc-interface.png" width="70%" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到在2PC（上图左半部分）模式下，应用对于接口的定义不会受到约束，这点是2PC的优势，事务协调者同数据源进行协作实现分布式事务，一定程度上对应用透明。而TCC（上图右半部分）模式下，应用成为分布式事务中的主角，它需要同事务协调者进行交互，所以在接口定义上需要定义出数据的创建、取消和确认三个不同的方法来分别应对TCC中的TRY、CANCEL和CONFIRM逻辑处理。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于2PC而言，如果准备阶段投票出现了中止，则在后续的提交阶段数据源会将数据进行回滚。TCC实际是需要用户编写取消的逻辑来处理之前TRY阶段生成的数据，对于数据源而言，这又是另一次提交。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在上图中的TCC模式下，对于订单生成服务OrderCreateService定义了三个方法createOrder、cancelOrder和confirmOrder分别应对订单生成过程中的TRY、CANCEL和CONFIRM逻辑。TCC除了对应用接口定义产生了侵入，对于这些方法的实现也有隐性的要求，也就是方法实现需要做到幂等。以cancelOrder为例，在取消订单时需要先获取订单，且订单是新生成、没有被取消且没有被确认的情况下才能够进行取消处理，这么做的原因在于事务协调者对于应用的通知可能会由于网络（或其他）原因出现延迟或重复通知，所以需要由应用自身的代码逻辑保证逻辑的幂等。

## Seata支持TCC

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用TCC，需要一个事务协调者来完成对全局事务（和分支事务）的状态维护与驱动。事务协调者接受事务参与者（也就是微服务应用）本地分支事务的注册，并且在全局事务提交或回滚时调用各个事务参与者相应的确认或取消接口。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;TCC事务协调者的开源实现目前在业界有多个，其中使用广泛、功能完备且稳定可靠的参考实现当属Seata。

### 什么是Seata

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Seata是一款开源的分布式解决方案，支持诸如：AT（类似2PC）、TCC、SAGA和XA多种事务模式。Seata是基于C/S架构的中间件，微服务应用需要依赖Seata客户端来完成和Seata服务端的通信，通信协议基于Seata自有的RPC协议。微服务应用通过Seata远程调用完成分布式事务的开启、注册，同时该链路也接受来自Seata服务端（由于事务状态变更而带来）的回调通知，其架构如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/tcc-using-seata/seata-architecture.png" width="70%" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用Seata之前，需要先部署Seata服务端，服务端会将Seata服务注册到注册中心，目的是当依赖Seata客户端的微服务应用启动时，可以通过注册中心订阅到Seata服务，使Seata服务以集群高可用的方式暴露给开发者。Seata的客户端和服务端有许多参数可以配置，比如：提交的重试次数或间隔时间，这些配置可以配置在微服务应用或者Seata服务端上，但也可以通过将其配置在配置中心上统一的管理起来。Seata服务端可以通过依赖外部的数据存储将事务上下文等信息持久化存储起来，使得Seata服务端无状态化，进一步提升可用性。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;微服务应用通过依赖Seata客户端来获得同Seata服务端通信的能力，Seata客户端通过AOP以及对主流RPC框架的扩展来完成对微服务应用间远程调用的信息，在远程调用前开启（或注册）分布式事务，当Seata服务端发现事务状态变化时，再回调部署在微服务应用中的Seata客户端来执行相应的逻辑。

> Seata的注册中心支持多种类型，包括：文件、ZooKeeper、Redis、Nacos和ETCD等
>
> Seata的配置中心支持多种类型，包括：文件、ZooKeeper、Nacos、ETCD和SpringCloud Config等
>
> Seata的数据存储支持多种类型，包括：文件、关系数据库和Redis

### Seata如何支持TCC

### 部署Seata

## 一个基于Seata的TCC参考示例

## Seata的一些问题
