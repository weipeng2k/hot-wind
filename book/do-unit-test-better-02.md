# Java程序员使用JUnit做单元测试

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在许多稍大一点的公司，会有自己维护一套单元测试框架的冲动，比如：在阿里巴巴，很早之前就存在一套基于**TestNG**的单测框架，叫**JTester**，随着时间的流逝，这个框架就**GG**了。自己维护框架，有这个冲动时需要冷静一下，因为公司自己搞一个单元测试框架，维护将成为大问题，而使用业界成熟的解决方案，将会是一个更好的选择。业绩成熟的解决方案，意味着有一组非常专业的人替你维护，而且不断地有新**Feature**可以使用，同样你熟悉这些之后，你就可以不断的复用这些知识，而不会局限在某个特定的框架下。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/do-unit-test-better/chapter02-preface.jpg" width="80%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Java**单元测试框架有不少，但以**JUnit**为事实上的标准，而**JUnit**只是解决了单元测试的基本问题，对于**Mock**和容器是不提供支持的。在**Mock**方面，**Java**也有很多开源的选择，诸如：**JMock**、**EasyMock**和**Mockito**，而**Mockito**也同样为其中的翘楚，二者结合起来，能够很好的完成单元测试的工作。

> 在**Github**上对开源**Java**项目的[依赖分析](https://developer.aliyun.com/article/835099)中，**JUnit**和**Mockito**高居前十，其中**JUnit**拔得头筹。[Kent Beck](https://www.kentbeck.com)和[Erich Gamma](https://github.com/egamma)共同打造的**JUnit**，前者是敏捷宣言的发起人，后者是设计模式**GoF**之一，可谓是出自豪门。

## 使用JUnit单元测试

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;接下来让我们使用**JUnit**来进行单元测试，首先需要说明一下，从本章开始的代码，都可以在[Mockito Sample](https://github.com/weipeng2k/mockito-sample)项目中找到，这个项目实际开始于**2014**年，自项目创建到今天，单元测试在**Java**开发环境中出现了多次变化，比如：基于**spring**的测试和基于**springboot**的测试就有所不同，笔者随着这些变化也进行了多次增补维护。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Java**应用大都使用**maven**进行依赖管理和项目构建的，在项目中通过声明依赖，就可以将**junit**引入项目，新增依赖如下：

```xml
<dependency>
    <groupId>junit</groupId>
    <artifactId>junit</artifactId>
    <scope>test</scope>
</dependency>
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;注意依赖坐标的**scope**是**test**，我们习惯将**test**作用域的依赖，放置到**dependencies**标签的最下面，就像这样：

```xml
<dependencies>
    <dependency>
        <groupId>org.apache.commons</groupId>
        <artifactId>commons-lang3</artifactId>
    </dependency>
    <!-- Test -->
    <dependency>
        <groupId>junit</groupId>
        <artifactId>junit</artifactId>
        <scope>test</scope>
    </dependency>
</dependencies>
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;好处就是依赖管理很明确，感官上也会舒服很多，如果项目的依赖管理不讲究，散乱的放着一堆依赖，维护这种项目的同学，想必自己家里也是很乱的吧。**Maven**项目中对于单元测试和生产代码（以及配置）的目录要求如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/do-unit-test-better/chapter02-directory.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们编写的测试类以及测试类路径上能够找到的文件或配置，分别放置在*test/java*和*test/resources*目录中。依赖**junit**后，我们就可以编写单元测试了。接下来，选择测试**commons-lang3**中的**StringUtils**，在*test/java*中新建测试类**TestCaseSample**，代码如下所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/do-unit-test-better/chapter02-TestCaseSample.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上述代码所示，该测试类有三个方法，方法上需要增加 **@org.junit.Test**注解，有注解修饰的方法会被**JUnit**框架理解为需要执行的测试方法。**@Test**注解还支持属性的配置，相关配置和描述如下表所示：

|属性名|描述|
|---|---|
|**timeout**|测试超时时间，单位是毫秒。如果该测试方法的执行时间超出了**timeout**所指定的时间，那么测试会失败。以**timeoutTest()**方法为例，如果该测试方法执行时间超过330毫秒，那么测试结果就是失败|
|**expected**|指定期望的异常类型。如果测试预期就会失败，比如：测试异常分支，那么可以通过使用**expected**属性来指定测试将会抛出的异常类型，如果测试执行时预期的抛出了指定类型的异常，那么测试会通过，反之测试失败。以**exception()**方法为例，expected指定了**NullPointerException**，如果测试方法执行时抛出了空指针异常，测试就算通过了|

## 断言选择

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;测试执行时会输出结果，当然我们可以使用**System.out.println**来完成目测，但是有时候需要让**JUnit**框架或者**maven**的**surefire**插件能够捕获住测试的失败，这个时候就需要使用断言了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如**TestCaseSample**类所示，我们使用**org.junit.Assert**来实现断言的判断，可以看到通过简单的**assertEquals**就可以了，当然该类提供了一系列的**assertXxx**来完成断言，比如：**assertTrue**。

> 使用**IDEA**在进行断言判断时非常简单，比**Eclipse**要好很多，比如：针对一个**int x**判断它等于0，就可以直接写**x == 0**，然后代码提示生成断言。

## 使用Mockito更好的单元测试

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;单元测试的标的是类，因此它更加关注的一个类的行为是否符合预期，但是现实中没有类是孤立存在的，自定义类或多或少的依赖其他的类。这时就需要使用**Mock**工具，它能够将被测试类的依赖都**Mock**掉，潜意识的认为依赖类都是正常工作的，只需要测试当前类即可。当然这么说也有些绝对，在持久层的单测中，还是会将持久层实现所依赖的数据层组件（比如：**mybatis**的**sqlSessionTemplate**）初始化，真实的和数据库进行交互，因为单测的目的是测试行为是否符合预期，而持久层的关键是数据操作是否正确，所以就需要与数据库进行通信来测试正确性，事情需要分情况来看。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于业务层的单元测试，将持久层的接口进行Mock就没什么异议了。**Mock**工具一般会选择**Mockito**，通过添加以下依赖可以引入项目：

```xml
<dependency>
    <groupId>org.mockito</groupId>
    <artifactId>mockito-core</artifactId>
    <scope>test</scope>
</dependency>
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Mockito**采用了**fluent**形式的**API**，我们可以选择**Mock**一个类或者接口，生成一个**mock**对象，然后向**mock**对象中添加**mock**逻辑，以期望在后续调用这个**mock**对象时能够执行逻辑返回预期的值。接下来我们看一段代码，简单介绍一下**Mocktio**该如何使用，代码如下所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/do-unit-test-better/chapter02-mock.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，通过**Mockito**提供的静态方法**mock**，能够创建出一个**mock**对象，该**mock**对象实现了接口**List**，如果调用该**mock**对象，它会返回一些默认内容，比如：如果调用返回类型是引用类型的方法，**mock**对象会返回空，如果返回类型是原型，则返回**0**。**Mock**对象创建完成后，就需要植入mock逻辑，如上述代码所示，通过调用**when**和**thenReturn**两个方法，能够完成指定方法的逻辑植入。`Mockito.when(list.get(0)).thenReturn(“one”);`表示如果调用**mock**对象的**get**方法，且输入参数为**0**，就返回字符串”one”。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用**Mock**，我们就能够将类的依赖都替换掉，让它们返回我们预期的内容，这样就可以进行真正意义上的单元测试了。虽然**Mockito**能够生成**Mock**对象，并且可以让Mock对象接收请求时，返回预期的值，但有时我们的逻辑会比较复杂，比如：要求**Mock**对象能够根据参数的值，返回出不一样的结果，这样我们的单元测试可以做的更全面，也会更加真实。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Mockito**提供了**thenAnswer**方法来解决这个稍显复杂的问题，代码如下所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/do-unit-test-better/chapter02-mock-answear.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上述代码所示，当**list（Mock）**对象，接收任意整型的请求时，会使用lambda表达式中的内容来处理，这个**lambda**是一个**Function**，接收的参数是**Invocation**。**Mock**逻辑不复杂，从Invocation中获取参数，当输入为0时，返回字符串”0”，当输入等于2时，会抛出异常。而该测试方法会用到**expected**属性，最后调用list.get(2)时，会抛出异常，但是符合预期，测试通过。

## 使用JMockData生成Mock数据

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Mockito**能够让Mock对象返回我们期望的对象（或数据），但是它不会帮我们构建数据，如果你去操作这个对象，会发现它所有的字段都是默认值或者为空。这就需要我们自己构造对象，而构造方式是通过一堆set方法进行赋值。如果期望的对象只有几个字段还好，要是遇到一个几十上百个字段的数据结构，那就要了亲命了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这时候，就需要**JMockData**来帮助我们完成**Mock**数据的构建了，首先添加依赖：

```xml
<dependency>
    <groupId>com.github.jsonzou</groupId>
    <artifactId>jmockdata</artifactId>
    <version>4.3.0</version>
    <scope>test</scope>
</dependency>
```

> 注意scope是test，不要忘了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;接下来演示一下Mock数据如何构造，代码如下所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/do-unit-test-better/chapter02-jmockdata.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，命令行输出内容中包含了Student和Hobby属性，一个Student可以有多个Hobby，只需要通过**JMockData.mock(Student.class)**方法，就可以创建出一个Student对象，该对象会被JMockData随机填充一些属性值，这样就方便使用者进行测试了。

> 如果属性值不符合预期，可以再通过调用set方法做一些微调。

## 一个真实案例

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;接下来，我们以会员注册为例，看看该如何做单元测试。对于会员注册而言，会有一些业务逻辑（或限制），不同公司的业务逻辑会不大一样，但是代码逻辑大都长成这样。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/do-unit-test-better/chapter02-memberserviceimpl.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到注册一个名称为name，密码为password的会员，主要逻辑是判断会员名长度、密码以及同名会员不能注册，如果条件都符合，则可以进行注册。这些逻辑不复杂，但是由于业务类依赖了userDAO，而业务层单元测试不会在测试会员注册服务类时连接数据库，这时就需要mock掉依赖的userDAO。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在**Mockito**的支持下，我们可以方便的完成mock，因为测试类依赖userDAO，所以需要调用一下setUserDAO完成引用的设置，该类的单元测试类如下：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/do-unit-test-better/chapter02-memberservicetest.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，在测试开始的时候，利用了 **@Before**注解修饰的mockUserDAO方法，来完成Mock对象的构建。在当前测试类中的任意测试方法执行前，都会执行mockUserDAO方法，该方法能够保证Mock对象的初始化工作。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**MemberWithoutSpringTest**虽然能够测试会员注册类，但是它看起来有些不顺眼，因为**MemberServiceImpl**是直接构造出来的。另外一个坏味道就是**UserDAO**也是硬塞给**MemberService**的实现，在生产代码中，**Spring**会帮助我们完成依赖关系的装配工作，如果我们需要单测也有Spring的那种感觉，就需要使用**Spring-Test**来实现了。
