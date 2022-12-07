# 维护好单元测试

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;单元测试只是在开发阶段用来测试生产代码是否正确运行的工具吗？它们的使命随着生产代码的发布就结束了吗？它们的地位注定比不上生产代码吗？不！绝对不是。我们编写生产代码时会使用高质量的三方组件，应用会部署在tomcat/jboss等容器中运行，我们对类似spring或tomcat这样的开源产品赞不绝口，从来不会怀疑它们的质量。这些框架（或服务器）的质量为什么这么好呢？答案就是规范、设计和测试，而测试就包含了充足的单元测试。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/do-unit-test-better/chapter04-preface.jpg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;记得前同事罗毅讲过他们**WebLogic Server**的质量保证策略：有充足的单测覆盖率，行覆盖率在70%以上，重点模块会更高。每天会进行日常构建，执行单测、回归和性能等多种测试，如果一旦测试被阻断，所有正在进行的项目就会立刻停止，相关和不相关的人都会看到是什么问题阻断了测试执行，直到问题被找到和解决为止。当时我对这种处理方式很不解，这样做不是会经常阻断，导致效率很低呢？回答是：一年基本都不会发生一次，而且效率相当高。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这里不去探讨**BEA**是如何提高产品质量的，而是想说两点：第一，好质量是做出来的，是测试和验证出来的；第二，好质量是积累出来的，是聚沙成塔般堆起来的。如果从这两点去思考，你还会觉得单元测试没什么价值吗？

## 开发资产与复利思维

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;开发资产除了生产代码，就只剩下配置、机器和单元测试了。应用代码、配置和机器，只是用来实现开发者的目标，让机器能够按照开发者的意愿去执行，而单元测试，只有单元测试，能够验证生产代码，测试其执行逻辑是否符合预期。单元测试不会在生产环境中执行，但是它是开发资产中真正对生产代码产生积极效应的一环，所以需要维护好单测，每次提交前跑通所有的单测，是一个良好的习惯。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;有同学会认为，既要写生产代码，又要写单元测试，工作量不就变得更大了吗？有这个观点很正常，而且这个观点一般也是不常做单测同学的主要问题。试想一下：我们在写持久层功能时，有没有因为配置拼写错误，导致自测功能阶段才发现问题？此时应用已经经历了漫长的构建和部署阶段，十几分钟后，才发现一个低级错误。改正了配置拼写，再次启动应用，结果又发现持久层实现的参数没有传递，那只有再来一遍。这时候，如果持久层有单元测试，伴随着测试的运行，低级错误会在应用启动前全部被找到并修复，除了多编写了一个测试类，时间可能并不会慢多少，假设你经常做单测，那么效率可能会变得更高，这样下次再修改持久层代码时，会不会比没有单测显得更加自信一点呢？答案是一定的。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/do-unit-test-better/chapter04-buffett.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;单测发挥作用是缓慢且持久的，跑不过的单测一定在向你告知问题，不要忽略它们。单测数量的提升，一定会让你的代码更自信，不用启动应用也能检验它们是否按照预期运行，效率变得更高。就像巴菲特投资一样，不求暴利，但求稳定的增长，当时间这个因素加入到公式中后，最终价值是巨大的，复利思维如此，单元测试亦是如此。不要因为没人做而不做，不要因为做的少就忽略，眼光放长远些，从结果和技能上看，这都是最划算的投资。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/do-unit-test-better/chapter04-istanbul.jpeg" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**1453**年君士坦丁堡陷落，奥斯曼帝国苏丹看到宏伟的**圣索菲亚大教堂**，赞叹不已，那是奥斯曼帝国无法企及的水平，之后的日子里只能在圣索菲亚大教堂旁立起一根小小的宣礼塔。感受到艺术冲击的奥斯曼人并没有放弃学习和尝试，随着一根比一根宏伟的宣礼塔在圣索菲亚大教堂旁立起来，帝国自认为建筑水平已经到了，**1617**年，在圣索菲亚大教堂对面落成了更加宏伟的**蓝色清真寺**。单元测试，开始做的时候感觉很困难，那只是不熟悉而已，等到时间久了，就会变得熟练，只要不放弃，最终都会运用自如。

## 单元测试覆盖率

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果做了单元测试，如何衡量单测的充分程度呢？这就需要引入单元测试覆盖率这个指标了。单元测试覆盖率会从行覆盖和分支覆盖等多个维度来考察单元测试对生产代码的覆盖情况，覆盖率越高，生产代码的质量也会更好。在项目中，可以通过引入**jacoco**插件来生成当前项目中的单元测试覆盖率。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以在项目的根pom下配置jacoco插件，配置如下所示：

```xml
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.7</version>
    <executions>
        <execution>
            <id>prepare-agent</id>
            <goals>
                <goal>prepare-agent</goal>
            </goals>
        </execution>
        <execution>
            <id>report</id>
            <phase>prepare-package</phase>
            <goals>
                <goal>report</goal>
            </goals>
        </execution>
        <execution>
            <id>post-unit-test</id>
            <phase>test</phase>
            <goals>
                <goal>report</goal>
            </goals>
            <configuration>
                <dataFile>target/jacoco.exec</dataFile>
                <outputDirectory>target/jacoco-ut</outputDirectory>
            </configuration>
        </execution>
    </executions>
</plugin>
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;上述配置会在执行**mvn clean test**命令时，在各个项目中的*target/jacoco-ut*目录下输出单测覆盖率文件，形式一般是html页面，文件打开之后，会看到类似页面：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/do-unit-test-better/chapter04-coverage.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以通过点击对应的package，查看行覆盖率缺失的代码，随后可以对缺失的路径进行测试补充。这就像刻意的刷分一样，单元测试覆盖率也是一个我们追求的目标，当单元测试行覆盖率超过70%的时候，整个项目的质量会很不错。持续稳定的单元测试覆盖率，会保障一个应用一直处于较稳定的状态，后续投入维护的资源会降低。
