# C语言概述

## C语言的历史

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**C**诞生于上个世纪70年代初的贝尔实验室，由**Ken Thompson**和**Dennis Ritchie**设计开发出来的，目的是为了重写**UNIX**操作系统。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-01/figure-1.png" width="90%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;也可以说**C**语言是**UNIX**系统的“**副产品**”。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**C**语言不是凭空创作出来的，而是诞生于一个演化过程。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-01/figure-2.png" width="90%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Ken**在贝尔实验室在一台**DEC PDP-7**机器上，使用改进后的**BCPL**语言，也就是**B**语言，设计开发了初版的**UNIX**系统。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**BCPL**语言源自**ALGOL60**，也就是算法语言，它长得样子大概是这样：

```algol
BEGIN
    FILE F(KIND=REMOTE);
    EBCDIC ARRAY E[0:11];
    REPLACE E BY "HELLO WORLD!";
    WRITE(F, *, E); 
END
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到函数`WRITE`的方法调用，`;`结尾的语句。当然它已经具备了`IF`选择，`FOR`循环等高级语言的特性了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**BCPL**语言更近一步，它是*Basic Combined Programming Language*的缩写，可以看到它的样子：

```bcpl
GET "libhdr"
LET start() = VALOF
{ 
    FOR i = 1 TO 5 
    DO writef("fact(%n) = %i4*n", i, fact(i))
    RESULTIS 0
}

AND fact(n) = n=0 -> 1, n*fact(n-1)
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**BCPL**有主函数`start()`，有获取外部库函数的`GET`指令，同时有格式化输出函数`writef`，看起来已经很有感觉了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Ken**所作业的**DEC PDP-7**不是一个很强的系统，只有4K的内存。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-01/dec-pdp-7.jpg" width="50%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Ken**发明的**B**语言。

```b
/* The following function will print a non-negative number, n, to
the base b, where 2<=b<=10, This routine uses the fact that
in the ANSCII character set, the digits 0 to 9 have sequential
code values. */
printn(n,b) {
extrn putchar;
auto a;
if(a=n/b) /* assignment, not test for equality */
printn(a, b); /* recursive */
putchar(n%b + '0');
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到已经和**C**很像了，这个时候**Dennis**加入了项目组，同时他们更换了一台性能强劲的新机器**DEC PDP-11**。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-01/dec-pdp-11.jpg" width="50%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于**B**不能很好的利用新机器的特性，比如一些新的指令集，因此**Dennis**的主要工作就是给**B**打patch。可是patch打到最后导致**B**已经不再像原有的**B**了，**Dennis**就索性推翻了重干，操刀设计出了**C**，并用它和**Ken**一起重写了**UNIX**。

> 那个年代的程序员就像刀客：荒漠里一酒家，满屋皆是恶人。外来一人执刀，躬身不惧而入，刀光闪剑影舞。独他推门而出，收刀带帽上马。马踏夕阳西下，只留无人酒家。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;任何软件的目的，都是为了驱动硬件。和硬件交互最深入的软件，就是操作系统。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-01/figure-3.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在**Java**语言中，RUNTIME（JVM）针对不同的操作系统做了不同的实现，但是它们需要兑现一个目标，为上层代码（Java代码）提供一致的标准，也就是**Java Spec**。可以看到很多语言及功能的特性，诸如：网络、文件和线程等，都抽象到了**Java Spec**中，**Java**开发者可以在SDK中看到这些内容，而它们需要得到RUNTIME的支持与兑现。**Java**应用和程序都是基于**Java Spec**的，而整个**Java**实际上就是一个平台。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在**C**语言中，不同的操作系统提供各自对应的编译器，而**C**只是定义了**C Spec**，具体编译和链接就需要依靠不同操作系统上的编译器。这也是**C**编译器在不同操作系统（如：Windows或Linux）迥异的原因了。

## C语言的优缺点

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**C**语言的优缺点。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-01/figure-4.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Java**的语言特性比较多，并且在不断的增加，而**C**只能依靠标准库，如果没有标准库，那么移植性就存在问题。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;同时**C**的编译器能力不强，有些隐藏错误难以发现。所以对于**C**需要注意。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-01/figure-5.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;针对下面的代码。

```c
#include<stdio.h>

void main() {
    printf("hello, world!\n");
}

```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;尝试使用gcc进行编译。

```sh
ch02 % gcc -o target/warn warn.c
warn.c:3:1: warning: return type of 'main' is not 'int' [-Wmain-return-type]
void main() {
^
warn.c:3:1: note: change return type to 'int'
void main() {
^~~~
int
1 warning generated.
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;编译结果出现告警。然后使用新的命令再次编译。

```sh
ch02 % gcc -O -Wall -W -pedantic  -std=c99 -o target/warn warn.c
warn.c:3:1: error: 'main' must return 'int'
void main() {
^~~~
int
1 error generated.
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;编译失败，只是因为增加了`-std=c99`，也就是说要求编译前按照c99的标准检查代码，而对于主函数返回类型，c99要求必须为`int`，所以直接报错。通过增加`-Wall -W`，也能够看到告警，这样会让我们知道哪里可能存在风险。
