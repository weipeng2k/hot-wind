# 使用Seata来实现TCC

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

## TCC的相对优势

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从TCC的交互过程可以看到各个事务参与者所负责的本地事务在接收到请求后就会提交，相比较两阶段提交（以下简称为2PC）而言，TCC对资源的锁定占用时间会短很多，呈现出一种对资源离散且短时占据的形态，而非2PC在整个事务周期内都会整块长时间的锁定资源。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;以电商的商品订购场景为例，买家订购商品生成订单，同时会进行商品库存扣减，这个过程需要保证如果库存满足订购的数量，订单有效，反之则订单无效，也就是说订购过程是一个事务。简单起见，整个过程涉及三个事务参与者，分别是：交易前台、订单和商品库存三个微服务系统，交易前台会调用订单和商品库存两个微服务完成订购。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果使用2PC来确保该分布式事务的执行，假设在订购过程中，订单微服务生成了订单，但由于调用商品库存系统出现错误（库存不足或调用出错），该全局事务会进行回滚，而该过程对资源的占用如下图所示：

## Seata支持TCC

## 一个基于Seata的TCC参考示例

## Seata的一些问题
