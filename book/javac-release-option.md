# 使用Javac's Release选项

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果在编程语言中选择一个版本帝的话，Java绝对是最有力的竞争者。拜模块化技术所赐，从Java9之后，每隔6个月Java就会发布一个新版本，从底层VM到上层语法特性都会进行特性的更新（以及删除）。在以前的Java8时代，Java开发人员下载一个JDK（Java Development Kit）能用好久，但随着Java版本的快速发布，就需要区分需要哪个版本的JDK：自己学习使用的JDK版本，生产环境上用的JDK版本，以及哪个版本是LTS（Long Term Support）的。为什么这么麻烦呢？原因是低版本的JVM无法运行高版本class文件。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;向前兼容是Java的核心特性，Java21的JVM可以运行Java8的class文件，问题是：可以使用JDK21的编译器生成Java8的class文件，并顺利运行在Java8的JVM上吗？讲道理是可以的，也是兑现向前兼容特性的要求之一。如果一切顺利的话，Java开发同学就只用选择最新的JDK版本，然后按需编译生成目标版本的class文件即可，那为什么还有那么多的Java开发同学会在机器上准备那么多不同版本的JDK呢？事实就是Java并不会完全兑现向前兼容，只是说尽可能的做到向前兼容。

> 在Mac上使用Eclipse Termurin，不同版本JDK切换的知识可以参考[这里](https://zhuanlan.zhihu.com/p/456426472)。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在利用`javac`编译生成class文件时，可以通过指定source和target两个选项来选择目标class的版本，在JDK8下，尝试以Java7的语法来源作为输入，Java7的目标class作为输出。

```sh
% openjdk8
% javac -version 
javac 1.8.0_422
% javac -source 1.7 -target 1.7 T.java
警告: [options] 未与 -source 1.7 一起设置引导类路径
注: T.java使用了未经检查或不安全的操作。
注: 有关详细信息, 请使用 -Xlint:unchecked 重新编译。
1 个警告
% java T
[A]
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;其中`T.java`的内容为：

```java
public class T {
        public static void main(String[] args) {
                java.util.concurrent.ConcurrentHashMap map = new java.util.concurrent.ConcurrentHashMap();
                map.put("A", "B");
                System.out.println(map.keySet());       
        }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;利用`source`和`target`选项，可以在JDK8下实现编译输出Java7可以运行的class，感觉这看起来很正常。如果我们在maven中，可以通过配置compile插件来做到一样的效果，如下所示：

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-compiler-plugin</artifactId>
    <configuration>
        <source>1.7</source>
        <target>1.7</target>
    </configuration>
</plugin>
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这一切看着都像一回事，甚至通过`javap`去观察`T.class`时，也可以看到class的major version值是`51`，妥妥的Java7，但事实上如果你在Java7的环境中运行T，就会得到一个类找不到的错误，原因就是`ConcurrentHashMap`的`keySet()`方法返回的类型是`KeySetView`，一个Java8新增的类型。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;使用`javap`仔细观察`T.class`，可以看到如下端倪。

```sh
public static void main(java.lang.String[]);
    descriptor: ([Ljava/lang/String;)V
    flags: ACC_PUBLIC, ACC_STATIC
    Code:
      stack=3, locals=2, args_size=1
         0: new           #2                  // class java/util/concurrent/ConcurrentHashMap
         3: dup
         4: invokespecial #3                  // Method java/util/concurrent/ConcurrentHashMap."<init>":()V
         7: astore_1
         8: aload_1
         9: ldc           #4                  // String A
        11: ldc           #5                  // String B
        13: invokevirtual #6                  // Method java/util/concurrent/ConcurrentHashMap.put:(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;
        16: pop
        17: getstatic     #7                  // Field java/lang/System.out:Ljava/io/PrintStream;
        20: aload_1
        21: invokevirtual #8                  // Method java/util/concurrent/ConcurrentHashMap.keySet:()Ljava/util/concurrent/ConcurrentHashMap$KeySetView;
        24: invokevirtual #9                  // Method java/io/PrintStream.println:(Ljava/lang/Object;)V
        27: return
      LineNumberTable:
        line 3: 0
        line 4: 8
        line 5: 17
        line 6: 27
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;第21行指令调用`ConcurrentHashMap`的`keySet()`方法，返回类型为Java8新增的`KeySetView`。一个Java7的class，在Java7的JVM上运行，结果就报错了，世界就是这么一个草台班子。这么看来，如果要杜绝这种问题，只能根据目标Java版本选择对应的JDK了。这的确是一个方案，如果是Mac用户，可以参考[这篇文章](https://zhuanlan.zhihu.com/p/456426472)，除此之外，还有没有更简单的办法呢？

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;答案是：使用（Java9新增的）`release`选项可以更好的编译生成class文件。

## 实验一：使用ConcurrentHashMap的keySet()方法，输出Java7的class

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于是Java9新增的，所以切换到JDK17，该版本是最后几个可以输出Java7的JDK了，如果你使用JDK21，就无法输出major version为`51`的class了。

```sh
% openjdk17 
% javac --version
javac 17.0.12
% javac -version
javac 17.0.12
% javac --release 7 T.java
警告: [options] 源值7已过时, 将在未来所有发行版中删除
警告: [options] 目标值7已过时, 将在未来所有发行版中删除
警告: [options] 要隐藏有关已过时选项的警告, 请使用 -Xlint:-options。
注: T.java使用了未经检查或不安全的操作。
注: 有关详细信息, 请使用 -Xlint:unchecked 重新编译。
3 个警告
% java T
[A]
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在通过`javap`观察一下`main(String[] args)`方法中的指令。

```sh
public static void main(java.lang.String[]);
    descriptor: ([Ljava/lang/String;)V
    flags: (0x0009) ACC_PUBLIC, ACC_STATIC
    Code:
      stack=3, locals=2, args_size=1
         0: new           #7                  // class java/util/concurrent/ConcurrentHashMap
         3: dup
         4: invokespecial #9                  // Method java/util/concurrent/ConcurrentHashMap."<init>":()V
         7: astore_1
         8: aload_1
         9: ldc           #10                 // String A
        11: ldc           #12                 // String B
        13: invokevirtual #14                 // Method java/util/concurrent/ConcurrentHashMap.put:(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;
        16: pop
        17: getstatic     #18                 // Field java/lang/System.out:Ljava/io/PrintStream;
        20: aload_1
        21: invokevirtual #24                 // Method java/util/concurrent/ConcurrentHashMap.keySet:()Ljava/util/Set;
        24: invokevirtual #28                 // Method java/io/PrintStream.println:(Ljava/lang/Object;)V
        27: return
      LineNumberTable:
        line 3: 0
        line 4: 8
        line 5: 17
        line 6: 27
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，第21行指令，调用`ConcurrentHashMap`的`keySet()`方法，返回的是`java.util.Set`接口，这样该class一定可以运行在Java7上。从这个实验可以看出`release`相比较`source`和`target`的组合而言，能够做到更好的向前兼容，事实上`release`确实修复了不少Java编译器的bug，也是被用作解放`source`和`target`的。

## 实验二：ByteBuffer的flip方法，输出Java8的class

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在Java的nio中，`ByteBuffer`是`Buffer`的子类，其中`Buffer`具有`flip()`方法，在Java8中，它是这样定义的：

`public final Buffer flip()`

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这就使得`ByteBuffer`也继承了`flip()`方法，调用后会返回自己的超类`Buffer`。这一切在Java9中有所改变，首先超类`Buffer`的`flip()`方法没有了`final`修饰，子类`ByteBuffer`扩展了它。`Buffer`中的定义：

`public Buffer flip()`

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;再看`ByteBuffer`的扩展代码。

```java
public ByteBuffer flip() {
    super.flip();
    return this;
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这样改动的目的是为了`ByteBuffer`在调用`flip()`方法后返回`ByteBuffer`类型，这样外部就不需要再次转型，根本上讲就是早期`Buffer`类型没有设计好。接下来看一下这段代码：

```java
import java.nio.ByteBuffer;

public class B {

    public static void main(String[] args) {
        ByteBuffer bb = ByteBuffer.allocate(16);
        bb.flip();
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`flip()`方法被调用，这就需要看B的class文件中对`flip()`方法的链接是否正确，如果能够在Java8下运行，那就需要使用`Buffer`的`flip()`方法，但是如果稍有不慎，喜欢虚方法的Java就会将其链接到`ByteBuffer`的`flip()`方法上，这就会导致出现问题。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;切换到JDK21，然后使用`source`和`target`选项编译生成一个Java8的class，然后再切换回Java8去运行该class，结果如何？

```sh
% openjdk21
% javac --version
javac 21.0.4
% javac -source 8 -target 8 B.java
警告: [options] 未与 -source 8 一起设置引导类路径
警告: [options] 源值 8 已过时，将在未来发行版中删除
警告: [options] 目标值 8 已过时，将在未来发行版中删除
警告: [options] 要隐藏有关已过时选项的警告, 请使用 -Xlint:-options。
4 个警告
% openjdk8
% java B
Exception in thread "main" java.lang.NoSuchMethodError: java.nio.ByteBuffer.flip()Ljava/nio/ByteBuffer;
    at B.main(B.java:7)
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到结果是找不到方法`flip()`，它需要返回`ByteBuffer`类型的`flip()`方法，但是Java8中`ByteBuffer`实际没有该方法，它只有一个返回超类`Buffer`的`flip()`方法。虽然使用`source`和`target`选项，要求编译生成的class文件能够运行在Java8上，但是JDK编译器还是蠢蠢的将Java9中的改动输出到自己以为能够运行在Java8上的class中。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这就是一个Bug，一个JDK编译器的Bug。是不是Oracle或者社区修复它就好了？估计他们想着如果修复了这个问题，可能会导致问题，所以干脆不要改了，做一个新的，也就是release选项，用它来搞定。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;还是切换到JDK21，然后用release选项编译生成一个Java8的class，重新做一下测试看看。

```sh
% openjdk21
% javac --version
javac 21.0.4
% javac --release 8 B.java
警告: [options] 源值 8 已过时，将在未来发行版中删除
警告: [options] 目标值 8 已过时，将在未来发行版中删除
警告: [options] 要隐藏有关已过时选项的警告, 请使用 -Xlint:-options。
3 个警告
% openjdk8
% java -version 
openjdk version "1.8.0_422"
OpenJDK Runtime Environment (Temurin)(build 1.8.0_422-b05)
OpenJDK 64-Bit Server VM (Temurin)(build 25.422-b05, mixed mode)
% java B
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;正常执行并返回，再使用`javap`观察一下class文件。

```sh
public static void main(java.lang.String[]);
    descriptor: ([Ljava/lang/String;)V
    flags: ACC_PUBLIC, ACC_STATIC
    Code:
      stack=1, locals=2, args_size=1
         0: bipush        16
         2: invokestatic  #7                  // Method java/nio/ByteBuffer.allocate:(I)Ljava/nio/ByteBuffer;
         5: astore_1
         6: aload_1
         7: invokevirtual #13                 // Method java/nio/ByteBuffer.flip:()Ljava/nio/Buffer;
        10: pop
        11: return
      LineNumberTable:
        line 6: 0
        line 7: 6
        line 8: 11
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;其中第7行指令，调用的方法就是超类`Buffer`的`flip()`方法，从字节码层面看，是符合预期的。这样看来在Java9之后，`source`和`target`选项就应该成为历史了，使用`release`选项会更好一些。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在maven中使用`release`选项也很简单，修改一下配置即可。

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-compiler-plugin</artifactId>
    <configuration>
        <release>8</release>
    </configuration>
</plugin>
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;JDK17可以使用`release`选项输出Java7的字节码，而JDK21最低只能输出Java8的字节码，能够看出来随着JDK的继续演进，通过`release`选项输出的最低字节码版本也在逐渐升高。这种有策略，工业化的语言演进机制，也只有唯一完成模块化改造的主流编程语言Java所具备。不要再固守Java8了，赶快升级吧。
