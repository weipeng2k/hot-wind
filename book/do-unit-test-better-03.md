# 基于Spring的单元测试

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;企业级**Java**程序基本都离不开[Spring](https://spring.io/projects/spring-framework)和[SpringBoot](https://spring.io/projects/spring-boot)，它们是目前企业级**Java**事实上的标准。我们的代码中或多或少都会使用到 **@Autowired**注解来引入依赖，或者在类型上声明 **@Compoenent**注解来将类型实例托管到（**Spring**）容器中，这就带来了一个问题，如果没有**Spring**，谁来帮我们组装类之间的依赖关系？

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/do-unit-test-better/chapter03-preface.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在前文中可以看到**MemberServiceImpl**依赖了**UserDAO**，通过调用**setUserDAO**方法，可以将**MemberServiceImpl**依赖的实例设置给它，可是如果需要测试的类型有很多依赖怎么办呢？还需要一一调用set方法设置吗？

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;答案是否定的。**Spring**从诞生的开始，就考虑到如何在**Spring**环境下做单元测试，而**Spring-Test**就是**Spring**提供的单测套件。**Spring-Test**是**springframework**中一个模块，也是由spring作者[Juergen Hoeller](https://spring.io/team/jhoeller)亲自操刀设计开发的，它可以方便的测试基于**spring**的代码。

## 使用**Spring**-Test来进行单元测试

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Spring-Test**是基于**JUnit**的单测套件，由于测试会启动**spring**容器，所以需要依赖**Spring**配置，同时要继承**Spring-Test**提供的超类。在使用**Spring-Test**前，首先要进行依赖配置，依赖的maven坐标如下：

```xml
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-test</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.mockito</groupId>
    <artifactId>mockito-core</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>junit</groupId>
    <artifactId>junit</artifactId>
    <scope>test</scope>
</dependency>
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;MemberServiceImpl依赖UserDAO，而**Mockito.mock(Class clazz)**方法可以创建一个clazz类型的Mock对象，在spring体系中，Mockito就如同一个FactoryBean，因此我们可以通过一段spring配置，将MemberServiceImpl装配起来，对应的spring配置如下所示：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd"
       default-autowire="byName">

    <bean id="memberService" class="com.murdock.tools.mockito.service.MemberServiceImpl"/>

    <bean id="userDAO" class="org.mockito.Mockito" factory-method="mock">
        <constructor-arg value="com.murdock.tools.mockito.dao.UserDAO"/>
    </bean>
</beans>
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上述配置所示，熟悉spring的同学一定会觉得很亲切，MemberServiceImpl被声明为id为memberService的bean，而userDAO对应的bean是由Mockito创建出来的Mock对象。接下来，只需要使用**Spring-Test**提供的超类，就可以编写基于**Spring-Test**的测试了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**MemberService**的单测（部分代码）如下所示：

```java
@ContextConfiguration(locations = {"classpath:MemberService.xml"})
public class MemberSpringTest extends AbstractJUnit4SpringContextTests {
    @Autowired
    private MemberService memberService;
    @Autowired
    private UserDAO userDAO;

    /**
     * 可以选择在测试开始的时候来进行mock的逻辑编写
     */
    @Before
    public void mockUserDAO() {
        Mockito.when(userDAO.insertMember(Mockito.any())).thenReturn(
                System.currentTimeMillis());
    }

    @Test(expected = IllegalArgumentException.class)
    public void insert_member_error() {
        memberService.insertMember(null, "123");

        memberService.insertMember(null, null);
    }

    /**
     * 也可以选择在方法中进行mock
     */
    @Test(expected = IllegalArgumentException.class)
    public void insert_exist_member() {
        MemberDO member = new MemberDO();
        member.setName("weipeng");
        member.setPassword("123456abcd");
        Mockito.when(userDAO.findMember("weipeng")).thenReturn(member);

        memberService.insertMember("weipeng", "1234abc");
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从上述测试代码可以看出，**Spring-Test**会要求测试类型继承**AbstractJUnit4SpringContextTests**，同时使用注解@ContextConfiguration指定当前测试需要使用的**Spring**配置。我们编写的单元测试肯定不止一个，当编写另一个单元测试类时，就有同学会想着用已有的配置文件，这么做，好吗？可以看到示例中，配置专门放在**MemberService.xml**中，没有使用共用的配置文件，目的就是让大家在测试的时候能够相互独立，避免搞坏别人的测试，让不同的测试相互之间不影响。并且在一个配置文件中配置的Bean越多，就证明你要测试的类依赖越复杂，承担的责任过多，从而提醒自己做重构。

## 现代化的**Spring**-Test使用方式

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Spring**从4.0后，就开始推荐使用**Java**配置方式了，也就是大家常用的@Configuration和@Bean，通过编写**Java**配置类来装配**Spring**的Bean。现阶段大家使用的**Spring**都比较新，因此我们可以将以传统形式配置的**Spring**-Test单测改造为现代化的配置方式。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用**Java**配置方式的MemberService单测代码如下所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/do-unit-test-better/chapter03-sprintut.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到基于**Java**配置方式的单测比传统基于xml的**Spring-Test**要显得内聚很多，没有了测试配置文件，只有一个单元测试类，**Spring**的配置和测试类也可以是一体的。通过@Configuration修饰的MemberServiceConfig可以被配置在@ContextConfiguration中，被用来装配一个测试的**Spring**容器。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;测试类也不需要继承AbstractJUnit4SpringContextTests，只需要使用@RunWith注解修饰即可。不需要xml配置，配置和测试是一体的，现代化的**Spring-Test**变得更好了，和配置文件一样，当配置类中的@Bean变多时，就要反思实现类是否职责过多或者依赖过重了。

## **Spring**Boot环境下的测试方法

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Spring**框架诞生后，成为了企业级**Java**（与互联网Powered by **Java**）的事实标准，IoC无往不利，势如破竹，从代码组成和思维方式上改变了整个**Java**开发生态。在*2.5.6*发布后，**Spring**框架就进入了一个低潮期，**Spring**不愿意触及部署与实现，这种不愿下场的做法使得其多年没有任何实质变化，被淘汰只是时间问题，但是这时候[Phil Webb](https://spring.io/team/philwebb)等人发起的[SpringBoot](https://spring.io/projects/spring-boot)项目挽狂澜于既倒，点燃了**Spring**的第二春。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**SpringBoot**提供了开箱即用的starter体系，通过自动装配能够提供给应用更便捷的bean配置方式，同时它支持迅速打包为jar-in-jar的形式，并通过java -jar的形式进行运行，改变了企业级**Java**使用容器部署的主流方式。在改变部署形态的同时，提供了多环境和配置的解决方案，在微服务和容器化崛起的时候，顺势而为，一举成为企业级**Java**部署的现实标准。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到相比**Spring**框架，**Spring**Boot会载入更多的Bean，同时由于测试类可能依赖了starter，就需要在单测执行前完成starter的配置，因此**Spring**Boot也提供了相应的测试套件，即**Spring-Boot-Test**。

> **Spring-Boot-Test** 对Mockito进行了整合，在进行Mock时，相比**Spring-Test**会方便一些。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;接下来，让我们用**Spring-Boot-Test**改造一下MemberService的单测，改造后的测试代码如下：

```java
@SpringBootTest(classes = SpringBootMemberTest.Config.class)
@TestPropertySource(locations = "classpath:test-application.properties")
@RunWith(SpringRunner.class)
public class SpringBootMemberTest {

    @Autowired
    private Environment env;
    @MockBean
    private UserDAO userDAO;
    @Autowired
    private MemberService memberService;

    @Before
    public void init() {
        Mockito.when(userDAO.insertMember(Mockito.any())).thenReturn(System.currentTimeMillis());
    }

    @Test
    public void insert_member() {
        System.out.println(memberService.insertMember("windowsxp", "abc123"));
        Assert.assertNotNull(memberService.insertMember("windowsxp", "abc123"));
    }

    @Configuration
    static class Config {

        @Bean
        public MemberService memberService() {
            return new MemberServiceImpl();
        }
    }

}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上述代码所示，基于**Spring**-Boot-Test的单测需要使用注解@**SpringBootTest**标注，声明该类为一个**SpringBoot**测试类，同时与**Spring-Test**类似，通过classes属性声明当前测试类使用的配置，本示例中是**SpringBootMemberTest.Config**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于需要Mock的类型，可以使用@MockBean注解来修饰，它会生成对应类型的Mock对象，并将其注入到容器中。当然**SpringBoot**离不开application配置，可以通过@TestPropertySource注解指定当前测试用例所使用的application配置。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果测试的类需要依赖一些starter才能工作，那就需要在测试类上增加@EnableAutoConfiguration，同时在application配置中增加一些属性，这样该测试就会像一个**SpringApplication**一样被启动起来。

## **Spring**Boot环境下持久层测试

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;持久层的单测很重要，是应用单测的基础，而且由于持久层的单测一般不会选择mock数据源，因此测试过程除了正确性的保证之外，还需要确保测试过程对数据库中的数据不会产生影响。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;还是通过UserDAO的单测来演示**SpringBoot**的持久层单测编写，由于测试需要依赖数据库，因此在示例中需要先使用StartDB启动一个hsqldb，然后再运行单测UserDAOImplTest。hsqldb是一款**Java**编写的嵌入式数据库，可以使用内存或主机模式启动，本示例中采用后者，以独立进程的方式启动，在数据库启动后，接下来看一下对应的测试，代码如下所示：

```java
@RunWith(SpringRunner.class)
@SpringBootTest(classes = UserDAOImplTest.Config.class)
@TestPropertySource(locations = "classpath:test-application.properties")
@EnableAutoConfiguration
public class UserDAOImplTest extends AbstractTransactionalJUnit4SpringContextTests {
    @Autowired
    private UserDAO userDAO;
    @Test
    public void findMember() {
        MemberDO member = new MemberDO();
        member.setId(1L);
        member.setName("name");
        member.setPassword("password");
        member.setGmtCreate(new Date());
        member.setGmtModified(new Date());
        userDAO.insertMember(member);
        MemberDO name = userDAO.findMember("name");
        Assert.assertNotNull(name);
        Assert.assertEquals("password", name.getPassword());
    }
    @Import(MyBatisConfig.class)
    @Configuration
    static class Config {
        @Bean
        UserDAO userDAO() {
            return new UserDAOImpl();
        }
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，测试类需要继承**AbstractTransactionalJUnit4SpringContextTests**，这样任意测试方法都会进行回滚，避免对数据造成实际的影响。我们运行一个持久层的测试，不希望它更改已有的测试数据，也希望测试方法之间相互不存在影响，而该超类能够让所有测试方法的执行最终都会进行回滚，从而避免对数据库中的数据产生副作用。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;测试方法需要进行数据准备，然后进行查询验证。除了验证数据是否为空，最好能够抽检几个字段，看看是否符合预期。
