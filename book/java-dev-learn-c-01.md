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

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Ken**在贝尔实验室在一台**DEC PDP-7**机器上，使用改进后的**BCPL**语言，也就会**B**语言，设计开发了初版的**UNIX**系统。

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
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-01/dec-pdp-7.jpg" width="80%">
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

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于**B**不能很好的利用新机器的特性，比如一些新的指令集，因此**Dennis**的主要工作就是给**B**打patch，到最后已经和**B**不一样了，那干脆就推翻了重干，由**Dennis**操刀设计出了**C**，并用它重写了**UNIX**。
