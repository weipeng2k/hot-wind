# 我怎么写概要设计？

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;软件开发既是一门艺术，也是一种工程。艺术性体现在它的抽象以及从无到有的创作性工作，工程性体现在它的产出物不仅需要有实用价值，而且产出的过程需要做到标准化、可度量和能复制。如果从工程化的角度去观察软件开发，会发现它是由：需求分析、概要设计、详细设计、开发测试和部署维护等多个阶段组成。这些阶段中，设计阶段，尤其是概要设计，是从无到有的阶段。建筑工人按照图纸去盖房子，软件工程师会按照设计文档去搭建系统，而在此之前，建筑师在图纸上已经建起了概念中的房子，软件设计师也是在设计文档中描述了系统的蓝图，二者的共性在于，他们都在心里建立了原型，只有想得越清楚，做的才会越好。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;一般没有无缘而起的软件开发，它们都属于项目的一部分，项目的目标是完成任务和创造利润，除了软件开发，还包括：客户需求、合同签署以及交付维保等。软件开发被项目流程中的其他部分夹在中间，是最容易盘剥的。软件开发在中国很容易被视为成本，而项目各部分涉及到了很多角色，比如：客户、销售、运营、产品、商务以及董事长等，这里面最终容易欺负的角色就是研发人员了，细心的你会发现涉众角色里没有研发人员，因为中国公司一向把研发视为成本资源，是上不了台面的，“它们”只是作为达成目的临时合作的人而已。中国公司还是会把形象做足，会宣导软件交付的结果，创造了所谓客户价值，但是软件如何设计开发，就是研发人员自己的事。这种资源型看法和做事方式，就会导致研发人员对设计过程能省则省，由于时间被压缩，很多内容都是边开发边想（或者设计），而这种中国式敏捷，会带领行业走向冥界。客观地讲，设计之于软件开发，是极为重要的，明知道设计很重要，但是轻设计的目的究竟是为了省资源，还是满足管理人员那狭隘的心里呢？我想两者都会有吧。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;轻设计是在这种环境下的自然选择，但我还是想说，软件在更新维护过程中，由于需求遗漏或设计缺失引出的问题，最终还是需要研发人员来做代偿。软件的问题，不应该是研发人员自己负责的吗？出了问题就扣钱惩罚。如果简单思考确实如此，但是如果不压榨这个环节，问题是不是会少一些？心虽不平，但现实如此，毕竟系统的维护还是研发人员在做，为了减少痛苦，就需要提升设计效率，虽然有很多指导设计的书籍，以及方法，比如：RUP，但是这些体系化的做法很难在有限的时间里充分展开。有没有好的方法或者模式，能够在相同的时间下，进行更有效的概要设计呢？

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;用一套简单且必要的概要设计模版来指导设计，会是一个好的解决方案。

## 概要设计模版

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;每个公司和组织都可能有属于自己的项目设计模版，如果是项目制的公司，可能连模版都没有。不论有没有模版，使用模版来思考概要设计，会使得思考相对完善，避免后续出现因为设计缺失而导致的返工问题。以下是一个可供参考的概要设计模版，以Markdown的形式呈现：

```sh
# 当前问题

# 解决方案

# 设计目标

# [总体|主要]架构（如果客户端和服务端都有，选择：总体，否则：主要）

# 系统用例（可选，一般有两端多种涉众参与才会需要）

# [客户端｜服务端]概念模型(如果只有一端，则可以都不选择，另外可以按需增加子主题)

# [客户端｜服务端]模块说明(如果只有一端，则可以都不选择，另外可以按需增加子主题)

# [客户端｜服务端]关键点（可选，另外可以按需增加子主题）
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，概要设计模版包含了8个部分，从当前问题开始，到关键点结束。当前问题部分是简要的说明项目需要解决什么问题，以及解决问题需要采取何种解决方案，针对这个方案以及项目，设计目标是什么，前三点的目的是解决是什么、为什么以及怎么办。接下来的内容是系统架构、用例、模型和模块，是解决方案从整体到细节的拆分。整体内容会形成文字以及表格，基于这些内容可以提炼出PPT。

## 概要设计示例

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;根据概要设计模版，接下来展示一些示例，这样会更容易理解一些。示例中的案例摘自一些项目，包括：客户端ioc容器、关系数据库服务和分布式缓存服务等。

### 概要设计示例-当前问题

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;项目：客户端IoC容器。

```md
客户端组件，尤其是中间件客户端，其自身如何组织形式，管理依赖以及生命周期是一个难以回避的问题。虽然在Java生态中，有Spring框架来实现对象的依赖注入和生命周期管理，但是客户端组件不建议直接依赖Spring。假设中间件客户端组件依赖了Spring框架，那么就会将Spring容器的版本隐形的传递给客户端的使用者，一来违反了迪米特法则，让中间件客户端感知了过多的依赖，二来Spring功能过于丰富，仅为了依赖注入和生命周期功能而引入Spring有些得不偿失。

可以选择不使用任何IoC（Inversion of Control）框架来组织中间件客户端，从用户使用角度上看，没有任何问题，但是客户端自身的扩展性以及维护性都会降低，随着客户端的不断迭代，代码量的增长，没有统一的依赖注入和生命周期管理会成为制约客户端发展的一个重要因素。

## 依赖注入

客户端的实现由容器进行组装，同时用户对客户端的扩展也会由容器载入，除了方便用户扩展框架，还实现了框架代码与用户扩展代码平权。

## 生命周期

容器负责实例化客户端，同时也会维护客户端对象的生命周期，不仅能够保证用户能够使用状态安全的客户端，而且对客户端扩展更加友好。
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;当前问题这一部分，提出和描述清楚需要解决的问题即可，概要设计需要针对问题进行阐述，没有明确需要解决的问题，很难在后续维护过程中翻看设计时产生共情。

### 概要设计示例-解决方案

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;项目：客户端IoC容器。

```md
构建一个支持依赖注入和生命周期管理的IoC容器，该容器应该支持Java9+之后的模块化，采用构造函数和setter注入。中间件客户端依赖该IoC容器，使用其依赖注入服务，同时依靠它的生命周期管理来实现启动和停止等核心逻辑。
```

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/how-do-i-write-a-design-doc/solution-architect.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到针对问题有各个层面的解法，从而汇集成为解决方案。解决方案最好以图形化的方式加以呈现。

### 概要设计示例-设计目标

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;项目：关系数据库服务。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/how-do-i-write-a-design-doc/target.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;针对解决方案，概要设计需要在设计目标中声明需要达成的技术目标，比如：M个N型规格实例下，做到不低于X个TPS的服务能力，99.9%均时访问最大延迟不超过W个毫秒。设计目标是为了更好的检测概要设计是否完备，同时也定义好了与上游的契约。可以看到，文字版的概要设计，也很容易转换为PPT。

### 概要设计示例-架构

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;项目：客户端IoC容器。

```md
面向服务设计容器功能，使用扩展点以及责任链模式连接各服务实例。
```

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/how-do-i-write-a-design-doc/ioc-architecture.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;概要设计的架构部分需要按模块并使用分层描述，标注出主要的实体、扩展点以及服务。每一层的职责和粗粒度模块的功能需要描述清楚。概要设计文档不仅是用来描述如何解决问题的思路，也需要作为后续系统更新维护的参考。

### 概要设计示例-系统用例

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;项目：分布式缓存服务。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/how-do-i-write-a-design-doc/usercase.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;系统如果涉及多种用户，在概要设计文档中需要描述用例，最起码是粗粒度的用例。以参与者的视角观察系统，对设计系统很有裨益，针对不同的涉众设计开发不同的接口，将会有利于后续的系统维护和扩展，减少相互影响的情况。

### 概要设计示例-概念模型

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;项目：关系数据库服务。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/how-do-i-write-a-design-doc/model.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;概要设计文档对于概念模型的描述需要包含主要的模型以及模型之间的关系，这些模型可以理解为领域对象，目的是通过演绎模型来解决问题。

### 概要设计示例-模块说明

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;项目：客户端IoC容器。

```md
# 模块说明

一个支持ioc的容器，有5个模块组成：

1. xworks-ioc-bean：bean的定义，包括bean的生成，管理与获取；
2. xworks-ioc-core：resource的定义，是对资源的抽象以及基础服务，比如：pipeline服务；
3. xworks-ioc-container：container的定义，包括获取bean以及生命周期维护；
4. xworks-ioc-common：common部分，包含了ServiceRegistry；
5. xworks-ioc-test：test部分，支持测试用例的编写。
```

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/how-do-i-write-a-design-doc/ioc-component.jpg" width="70%">
</center>

```md
## 模块说明：xworks-ioc-common

1. 简要描述
提供了面向ServiceLoader的服务加载和管理功能，以单例的形式进行创建与管理，支持自引用对服务的暴露。
2. 领域实体
Service：服务，xworks-ioc框架中承担核心逻辑的实体。
3. 接口服务
ServiceRegistry：构建服务注册，同时将服务引用管理在自身，用户通过构造ServiceRegistry来获得服务。ServiceRegistry托管的服务均为单例。
```

|方法|描述|
|----|----|
|`getService(Class<T> clazz): T`|根据类型获取服务，如果没有返回空|
|`getService(String name, Class<T> clazz): T`|根据指定的名称和类型获取服务实例，如果没有返回空|
|`listServices(Class<T> clazz)`|根据类型获取服务列表，使用@Order进行了排序，排序方式为升序|

```md
4. 扩展服务

ServiceRegistryAware：对于ServiceRegistry托管的服务，如果类型实现了该接口，将会得到ServiceRegistry的引用。
```

|方法|描述|
|---|---|
|`setServiceRegistry(ServiceRegistry serviceRegistry): void`|设置ServiceRegistry|

```md
5. 依赖组件
```

|组件|描述|
|---|---|
|`xworks-common-model`|基础支持|
|`xworks-common-tool`|基础支持|
|`slf4j-api`|日志|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;模块说明需要描述主要的模块以及关系，模块可以理解为maven中的一个artifact或者一个jar。除了分别介绍模块的主要职责和领域实体，还需要包括模块提供的接口服务、扩展以及主要依赖。

### 概要设计示例-关键点

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;项目：客户端IoC容器。

```md
## 关键点：容器初始化

需要依靠BeanContainerBuilder来进行容器的构建，在BeanContainerBuilder中，会开始创建ServiceRegistry，这一步没有放到BeanContainer中，其目的就是为了让BeanContainer也被托管在ServiceRegistry中，兑现ioc个服务的平权。完成Container的构建工作，当构建完成Container后，就会运行该阶段，与Spring容器中的refresh过程类似。
需要实现扩展接口：ContainerInitStage
```

|步骤|备注|
|---|---|
|检查状态，只有NEW状态可以初始化，也就是compareAndSet(NEW, INIT)|不属于stage，而是getBean(String)中的内容。|
|解析并加载配置文件|当前BeanFactory中没有定义，才会找寻parent，No BeanDefinition。不属于stage，而是getBean(String)中的内容。需要创建Bean时，开始走stage。|
|完成BeanDefinition的注册||
|设置当前BeanFactory#parent|如果BeanContainer有parent，则会设置当前BeanContainer中的BeanFactory服务|
|实例化当前容器中的所有单例Bean|通过遍历所有的BeanDefinition来获取一遍所有的Bean|
|按照顺序初始化所有的单例Bean|使用LifecycleRegistry进行初始化Bean回调|

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;概要设计中一般对关键细节的描述会以关键点的形式来呈现，因为关键细节决定成败，所以对这些关键点做较为详细的描述是非常有必要的，往往这也是系统中核心创新性的体现。

## 概要设计策略

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;概要设计的策略在于：对于目标需要明确，模块拆分需要与模型设计结合着做，关键细节一定要完成推演，尽可能的使用图与表的形式。
