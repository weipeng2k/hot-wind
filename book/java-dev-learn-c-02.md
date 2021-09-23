# C语言的基本概念

## 编写一个简单的C程序

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;编写**C**程序，是一个从源码到可执行文件的过程，该过程需要编译器提供帮助。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-02/figure-1.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过编译器，将**C**的源代码转换成为二进制可执行文件。二进制可执行文件，顾名思义，**二进制**，也就是CPU（或者说当前计算机体系结构）能够识别的指令集合，**可运行**，该文件不仅是指令的集合，同时已经和当前计算机环境做了链接，它知道访问当前操作系统的相关能力的入口（或接口）在哪里。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这点同**Java**的区别是很大的，**Java**编译出了*class*文件，而这个文件可以在任何装有**JVM**虚拟机的机器上运行，但是注意，运行的方式是：`java T`。这里运行的其实不是编写的*T.class*，而是`java`这个程序，依靠`java`程序来解释运行的*T.class*。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过编译器编译的**C**程序，是可以直接运行的，其实编译出来的产物等同于这台机器上的`java`程序。

> 假设存在一个编译好的*T.class*文件。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;存在下面的**C**程序，我们需要对它进行编译。

```c
#include <stdio.h>

#define X 10

int main(void) {
    int i = X;
    printf("i的值是：%d\n", i);
    return 0;
}

```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在**Mac**上，**C**的编译器底层实际是**LLVM**，如果使用**gcc**，也是可以，只不过它是通过**llvm-gcc**桥接到了**LLVM**。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-02/figure-2.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;安装完**XCode**后，就具备了编译**C**程序的能力，当然不同的系统平台需要找到各自对应的编译器。

> 基于**LLVM**的**clang**的编译产出相比**gcc**更好，同时受到版权的限制也少，目前大部分软件，包括：Chrome都选择使用clang进行编译构建。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;运行命令。

```sh
% cc -o test test.c 
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;将`test.c`编译成可执行文件`test`，然后选择运行。

```sh
% ./test
i的值是：10
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到，这个`test`程序和`java`一样，都是二进制可执行文件，但是把它拷贝到windows机器上，就不能双击运行了，因为它包含的指令不能够被windows机器识别，同时它是和当前机器做了链接，没有同windows机器做链接。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这里说了这么多指令和链接，那么编译一个**C**程序需要经过哪些步骤呢？

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-02/figure-3.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到需要经历主要的三个步骤：预处理、编译和链接。如果使用过脚本语言（或者模板引擎）的，对于预处理肯定不会陌生，它基本就是对源文件做包含和转换等操作。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**C**程序进行预处理都是对指令进行操作，比如：`#include`或者`#define`指令，它们都以`#`开头，预处理器就关注这些内容。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;预处理器对`#include <stdio.h>`指令的处理，就是在编译器中找到源文件中需要的头文件`stdio.h`，将其包含进来。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;预处理器对`#define X 10`指令的处理，就是将源文件中`X`，替换为`10`。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;接下来编译器会将处理过的源文件进行编译，生成二进制目标代码，最终通过链接器将系统文件同目标代码进行整合链接，完成本地化，使之能够运行。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-02/figure-4.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**Java**就不是这个套路，**Java**编译器只是将源码编译为*class*文件，而并没有链接。这个过程有些类似将源码编译成为一种中间状态的文件，然后靠各个平台的程序（完成了本地化）来解释运行这个文件。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;就像一个*html*文件，不同平台的浏览器来解释运行它一样，这个过程就需要类似**JVM**的程序*托着*这个文件。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看出来**C**程序的编译步骤要比**Java**这种托管的程序来的复杂，我们可以慢动作的看一下这个过程。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-02/figure-5.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;运行`cc -E test.c > test.i`，输出预处理器处理后的文件，可以看到该文件（部分内容）：

```sh
# 1 "test.c"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 368 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "test.c" 2
# 1 "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/stdio.h" 1 3 4
# 64 "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/stdio.h" 3 4
# 1 "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/_stdio.h" 1 3 4
# 68 "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/_stdio.h" 3 4

typedef union {
 char __mbstate8[128];
 long long _mbstateL;
} __mbstate_t;

typedef __mbstate_t __darwin_mbstate_t;


typedef long int __darwin_ptrdiff_t;

FILE *fopen(const char * restrict __filename, const char * restrict __mode) __asm("_" "fopen" );

int fprintf(FILE * restrict, const char * restrict, ...) __attribute__((__format__ (__printf__, 2, 3)));
int getc(FILE *);
int getchar(void);
char *gets(char *);
void perror(const char *) __attribute__((__cold__));
int printf(const char * restrict, ...) __attribute__((__format__ (__printf__, 1, 2)));

int main(void) {
 int i = 10;
 printf("i的值是：%d\n", i);
 return 0;
}

```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在文件中通过`#include`指令包含的头文件，内容被包含进了该文件，同时`#define`定义的内容已经做了替换。

> `#define X 10`，其中`X`已经替换成了`10`。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;接下来运行`cc -S test.i > test.s`，将预处理器处理完成的文件作为输入，输出汇编文件。

```assembly
        .section        __TEXT,__text,regular,pure_instructions
        .build_version macos, 11, 0     sdk_version 11, 3
        .globl  _main                           ## -- Begin function main
        .p2align        4, 0x90
_main:                                  ## @main
        .cfi_startproc
## %bb.0:
        pushq   %rbp
        .cfi_def_cfa_offset 16
        .cfi_offset %rbp, -16
        movq    %rsp, %rbp
        .cfi_def_cfa_register %rbp
        subq    $16, %rsp
        movl    $0, -4(%rbp)
        movl    $10, -8(%rbp)
        movl    -8(%rbp), %esi
        leaq    L_.str(%rip), %rdi
        movb    $0, %al
        callq   _printf
        xorl    %eax, %eax
        addq    $16, %rsp
        popq    %rbp
        retq
        .cfi_endproc
                                        ## -- End function
        .section        __TEXT,__cstring,cstring_literals
L_.str:                                 ## @.str
        .asciz  "i\347\232\204\345\200\274\346\230\257\357\274\232%d\n"

.subsections_via_symbols
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到汇编指令描述的程序，这里不做展开。然后运行`cc -c test.s > test.o`，将汇编文件编译为目标二进制文件。

```sh
<CF><FA><ED><FE>^G^@^@^A^C^@^@^@^A^@^@^@^D^@^@^@^H^B^@^@^@ ^@^@^@^@^@^@^Y^@^@^@<88>^A^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@<A0>^@^@^@^@^@^@^@(^B^@^@^@^@^@^@<A0>^@^@^@^@^@^@^@^G^@^@^@^G^@^@^@^D^@^@^@^@^@^@^@__text^@^@^@^@^@^@^@^@^@^@__TEXT^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@/^@^@^@^@^@^@^@(^B^@^@^D^@^@^@<C8>^B^@^@^B^@^@^@^@^D^@<80>^@^@^@^@^@^@^@^@^@^@^@^@__cstring^@^@^@^@^@^@^@__TEXT^@^@^@^@
^@^@^@^@^@^@/^@^@^@^@^@^@^@^Q^@^@^@^@^@^@^@W^B^@^@^@^@^@^@^@^@^@^@^@^@^@^@^B^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@__compact_unwind__LD^@^@^@^@^@^@^@^@^@^@^@^@@^@^@^@^@^@^@^@ ^@^@^@^@^@^@^@h^B^@^@^C^@^@^@<D8>^B^@
^@^A^@^@^@^@^@^@^B^@^@^@^@^@^@^@^@^@^@^@^@__eh_frame^@^@^@^@^@^@__TEXT^@^@^@^@^@^@^@^@^@^@`^@^@^@^@^@^@^@@^@^@^@^@^@^@^@<88>^B^@^@^C^@^@^@^@^@^@^@^@^@^@^@^K^@^@h^@^@^@^@^@^@^@^@^@^@^@^@2^@^@^@^X^@^@^@^A^@^@^@^@^@^K^@^@^C^K^@^@^@^@^@^B^@^@^@^X^@^@^@<E0>^B^@^@^B^@^@^@^@^C^@^@^P^@^@^@^K^@^@^@P^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^A^@^@^@^A^@^@^@^A^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@
^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@UH<89><E5>H<83><EC>^P<C7>E<FC>^@^@^@^@<C7>E<F8>
^@^@^@<8B>u<F8>H<8D>=^O^@^@^@<B0>^@<E8>^@^@^@^@1<C0>H<83><C4>^P]<C3>i的值是：%d
^@^@^@^@^@^@^@^@^@/^@^@^@^@^@^@^A^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^@^T^@^@^@^@^@^@^@^AzR^@^Ax^P^A^P^L^G^H<90>^A^@^@$^@^@^@^\^@^@^@<80><FF><FF><FF><FF><FF><FF><FF>/^@^@^@^@^@^@^@^@A^N^P<86>^BC^M^F^@^@^@^@^@^@^@#^@^@^@^A^@^@-^\^@^@^@^B^@^@^U^@^@^@^@^A^@^@^F^A^@^@^@^O^A^@^@^@^@^@^@^@^@^@^@^G^@^@^@^A^@^@^@^@^@^@^@^@^@^@^@^@_main^@_printf^@^@
test.o (END)
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这里面内容就是机器指令了，人类已经无法阅读，但是它还是不能执行，需要同当前系统环境进行链接。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;运行`cc test.o -o test`，将目标二进制文件进行链接，生成可执行文件`test`。

```sh
% ./test
i的值是：10
```

### 简单程序的一般形式

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**C**程序实际就是一堆函数的集合，其程序代码可以看做有以下组成。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-02/figure-6.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**C**程序就是编写函数，开发者写的是应用函数，而编译器提供的是本系统环境的系统函数，或者叫标准库，它们有能力同系统进行交互，处于程序调用的底层。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;看一个**C**程序。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-02/figure-7.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;指令、函数和语句构成了**C**程序。

### 定义常量和变量

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;变量或者常量的命名同**Java**的规范一样，这些命名的变量和常量可以被称为标识符。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-02/figure-8.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**C**程序是函数的集合，同时如果以符号来看，实际也是一堆记号（符号）的集合。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/java-dev-learn-c-02/figure-9.png" width="70%">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从形式上看，一个**C**程序就是定义一些标识符（变量、常量（或宏）和函数），中间使用语言的关键字来定义数据类型，依靠字面量以及运算符来进行运算，同时需要标点符号来分割不同的记号。由此可见，**C**程序是简单的，这种简单是由其语言本身的简单所带来的优点，它扩充能力的方式是通过调用不同的函数库，而不是增加语言的特性（包括语法特性等）和功能。
