# 补偿机制说明

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;业务代码在分布式环境（单机也存在）下执行时，由于部分成功，部分失败，会导致不一致的状态，比如：业务执行过程中，存储不可用，或者连续两个服务调用，第一个成功，第二个失败（可能是超时，或者本身的系统问题）。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;业务补偿本质上就是处理分布式环境数据一致性的问题，在分布式数据一致性处理常规手段上，按照强弱大致分为两种：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**强一致性**：XA/TCC，分布式环境下：TXC/Aliyun GTS

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**弱一致性（最终一致）**：失败记录，消息中间件，系统重试

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;强一致性的场景偏向用户直接操作时，需要立刻反馈结果，且重要性很高。有相应的产品支持，基本都是两阶段的方式保证事务的完整性。其中Aliyun的GTS，支持分布式服务的事务，依靠在分布式服务请求中埋点事务ID，依靠旁路系统来推进该事务ID前进或者回滚，GTS对主流服务框架做了适配，对部署环境有一定要求。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;弱一致性是一种比较经济的手段来保证数据的一致性，思路其实和GTS很类似，都是需要依托一个旁路数据，对多个阶段的业务操作保证执行的正确，不同点在于对于事务本身，弱一致性基本都是将事务向前推，很少能做到回滚，而对补偿机制的理解，我认为就是弱一致性的解决方案。

## 消息中间件

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用消息来进行补偿，利用了消息中间件的外部存储以及消息重新投递的特性来推动事务，当执行失败时，对业务场景进行补偿。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;比如有以下业务场景：创建订单，其中涉及到三个调用：生成商品订单，生成支付订单和生成物流订单，如下：

```java
CreateOrder:
    CreateBizOrder;
    CreatePayOrder;
    CreateLogisticOrder;
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果其中一个失败，就需要进行重试补偿。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用消息进行补偿，可以定义消息的数据结构为：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/explanation-of-compensation-mechanism/compensation-message.png" width="50%" />
</center>

### 发送方

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以通过手工编码的方式来进行消息的发送。

```java
CreateOrder:
    try {
        CreateBizOrder;
        try {
            CreatePayOrder;
            try {
                CreateLogisticOrder;
            } catch (Exception ex) {
                //…
            }
        } catch (Exception ex) {
            CompensationMessage msg = new CompensationMessage();
            msg.setBizId(id);
            msg.setScene(“CreateOrder”); // 设置场景
            msg.setPhase(“CreatePayOrder”); // 设置阶段
            msg.setContext(Param); // 设置参数
            MessageProducer.sendMessage(msg);
        }	
    } catch (Exception ex) {
        CompensationMessage msg = new CompensationMessage();
        msg.setBizId(id);
        msg.setScene(“CreateOrder”); // 设置场景
        msg.setPhase(“CreateBizOrder”); // 设置阶段
        msg.setContext(Param); // 设置参数
        MessageProducer.sendMessage(msg);
    }
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;以上逻辑，实际就是在执行出错的时候，将场景、阶段、参数等信息以消息的形式发送出去，利用消息中间件高可用的特性，将状态保存在消息中间件上。

### 消费方（需要注意幂等处理）

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以是本机发消息，本机消费消息。只需要监听消息，然后按照消息格式进行处理即可。消费方逻辑（基于RocketMQ，其他消息中间件也大抵如此）：

```java
//监听消息
consumer.registerMessageListener(new MessageListenerConcurrently() {
    @Override
    public ConsumeConcurrentlyStatus consumeMessage(List<MessageExt> list, ConsumeConcurrentlyContext consumeConcurrentlyContext) {
        String key=null;
        String msgId=null;
            for (MessageExt messageExt : list) {
                key = messageExt.getKeys();
                //判读redis中有没有当前消息key
                if (redis.exist(key)) {
                    // 无需继续重试
                    return ConsumeConcurrentlyStatus.CONSUME_SUCCESS;
                }
                // 可以将key加入到redis中，防止重投后被消费
    redis.add(key);
                msgId = messageExt.getMsgId();
                try {
                    CompensationMessage msg = Convert.convert(messageExt.getBody());
                    // 处理消息，根据阶段，完成补偿操作
                    process(msg);
                    return ConsumeConcurrentlyStatus.CONSUME_SUCCESS;
    } catch (Exception e){                     
                    return ConsumeConcurrentlyStatus.RECONSUME_LATER;
                }
        }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;消费方的处理策略是，接受到消息，如果消息的key能够在Redis中查询到，则消费成功，这里是保证消息的重投能够被正确的处理，只做一次。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;然后将消息转换为`CompensationMessage`，根据消息中的场景和阶段，进行事务的推进。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;基于消息中间件可以手动的编码来保证出现异常时，能够自动的将业务进行补偿，将事务推动下去，保证最终一致性。但是这种编码会比较复杂。可以尝试利用一些框架进行简化，比如：spring-aop，可以自定义注解来简化发送方的代码。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;定义切面和注解，比如：`@Compensation`，当方法抛出异常时，会完成相关操作，比如：发送消息。

```java
@Compensation :
    value() : 场景
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;切面处理逻辑，会根据`@Compensation`，将场景提取，然后将方法作为阶段，参数作为上下文，以消息的形式进行投递。

```java
CreateOrder:
    @Compensation(“CreateOrder”)
    CreateBizOrder;
    @Compensation(“CreateOrder”)
    CreatePayOrder;
    @Compensation(“CreateOrder”)
    CreateLogisticOrder;
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这样，当调用这些方法，出现问题，就会发送对应的消息，使用者不用关注是否使用了消息进行事务的补偿。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于补偿逻辑，可以定义补偿处理的接口，比如：

```java
interface CompensationProcessor {
    void process(long bizId, Map<String, Object> context);
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果抛出异常，将会被重试。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在配合上注解或者接口方法，来定位这个对应的实现，当前可以用注解：

```java
@CompensationProcessorConfig :
    String scene();
    String phase();
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;那么对于消费方，进行失败处理的逻辑，就可以定义为：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;处理创建BizOrder失败的处理器：

```java
@CompensationProcessorConfig(scene = “CreateOrder”, phase = “CreateBizOrder”)
@Component
public class CreateBizOrderFailOverProcess implements CompensationProcessor {
    void process(long bizId, Map<String, Object> context) {
        // Logic
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;处理创建PayOrder失败的处理器：

```java
@CompensationProcessorConfig(scene = “CreateOrder”, phase = “CreatePayOrder”)
@Component
public class CreatePayOrderFailOverProcess implements CompensationProcessor {
    void process(long bizId, Map<String, Object> context) {
        // Logic
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;处理创建LogisticsOrder的处理器：

```java
@CompensationProcessorConfig(scene = “CreateOrder”, phase = “CreateLogisticOrder”)
@Component
public class CreateLogisticsOrderFailOverProcess implements CompensationProcessor {
    void process(long bizId, Map<String, Object> context) {
        // Logic
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;根据这三个场景，三个处理器。对于失败处理和补偿的实现者，不需要知道是否进行消息处理，只用实现逻辑即可。而框架只需要修改消息处理的逻辑，通过消息中的内容来找到对应的`CompensationProcessor`即可。

```java
try {
    CompensationMessage msg = Convert.convert(messageExt.getBody());
    List< CompensationProcessor >  list = applicationContext.getBeans(CompensationProcessor.class);
    String scene = msg.getScene();
    String phase = msg.getPhase();
    for (CompensationProcessor cp : list) {
        CompensationProcessorConfig annotation = cp.getAnnotation(CompensationProcessorConfig.class);
        annotation.getScene();
        annotation.getPhase();
    }
    // 找到对应的CompensationProcessor
    CompensationProcessor.process(msg.getId(), msg.getContxt());
    return ConsumeConcurrentlyStatus.CONSUME_SUCCESS;
} catch (Exception e) {                     
    return ConsumeConcurrentlyStatus.RECONSUME_LATER;
}
```

## 系统重试

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用消息进行补偿的本质是利用外存（消息中间件）来转储状态，成本比较低，但是对于重试场景，还有内存级别的解决方式。当处理失败时，通过内存队列进行重试以及恢复。业界有比较成熟的方案，在分布式微服务环境下，spring提供了spring-retry来应对这个场景，增强分布式环境的一致性。

### 依赖

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在SpringBoot应用中，通过`@EnableRetry`，声明开启重试。

```xml
<dependency>
    <groupId>org.springframework.retry</groupId>
    <artifactId>spring-retry</artifactId>
    <version>1.2.4.RELEASE</version>
</dependency>

<dependency>
    <groupId>org.aspectj</groupId>
    <artifactId>aspectjweaver</artifactId>
    <version>1.9.4</version>
</dependency>
```

### 使用

```java
@Service
public class RetryService {

  private Logger logger = LoggerFactory.getLogger(RetryService.class);

  @Retryable(value = Exception.class, maxAttempts = 3, backoff = @Backoff(delay = 2000L, multiplier = 2))
  public void divide(double a, double b){
      logger.info("开始进行除法运算");
      if (b == 0) {
          throw new RuntimeException();
      }
      logger.info("{} / {} = {}", a, b, a / b);
  }

  @Recover
  public void recover() {
      logger.error("被除数不能为0");
  }

}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`@Retryable`注解:value: 抛出指定异常才会重试include：和value一样，默认为空，当exclude也为空时，默认所以异常exclude：指定不处理的异常maxAttempts：最大重试次数，默认3次backoff：重试等待策略，默认使用`@Backoff`，`@Backoff`的value默认为1000L；multiplier（指定延迟倍数）。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`@Recover`注解：当重试达到指定次数时候该注解的方法将被回调发生的异常类型需要和`@Recover`注解的参数一致@Retryable注解的方法不能有返回值，不然`@Recover`注解的方法无效。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过声明注解到对应的方法上，如果有异常，将会尝试重试，并且根据配置进行延迟重试处理，和spring的生态整合很好，也可以基于它进行扩展。
