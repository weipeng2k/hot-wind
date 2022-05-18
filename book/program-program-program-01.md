# 程序！程序！程序！—— 程序的视角

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们使用计算机来完成工作，其实用的就是计算机应用程序。进行文字编辑的时候，我们会打开**Word**，跟朋友聊天的时候，我们会使用微信，这些都是计算机应用程序，纵使它们运行在不同的终端上。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/program-program-program/program-view.jpg" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;内行的人会说，这些终端上都运行着不同的操作系统，比如：**windows**或**iOS**，它们上面跑着不同的应用。那么一个应用程序能否在不同的操作系统上运行吗？计算机从诞生的一刻，就有操作系统吗？如果要回答这些问题，就需要我们更深入的学习一下了。

## 一个C的例子

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;计算机程序离不开编程语言，时至今日，有不下百种编程语言，比如：**Java**、**Go**以及**Python**，它们有着迥异的语言特性，但在控制方式上都会有顺序、条件和循环。因为从本质上讲，这些语言都是**冯·诺伊曼**语言，它们都被打上了**C**语言的烙印。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们使用**C**语言编写一个简单的计算机程序，它会要求我们输入两个数，然后通过判断，输出较大的一个。首先我们看一下程序的源代码：

```c
#include <stdio.h>

int gt(int a, int b);

int main() {
    int a, b;
    printf("输入第一个数：");
    scanf("%d", &a);
    printf("输入第二个数：");
    scanf("%d", &b);

    int x = gt(a, b);
    printf("较大的数是：%d\n", x);

    return 0;
}

int gt(int a, int b) {
    return a > b ? a : b;
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;保存源代码为文件*gt.c*，通过`cc -o gt gt.c`可以将源文件编译成为可执行文件*gt*，可执行文件也就是程序，通过双击*gt*或者在终端运行`./gt`就可以运行程序。

```sh
% ./gt
输入第一个数：123
输入第二个数：321
较大的数是：321
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过编译生成的程序*gt*和我们安装的**Word**程序有什么不同吗？其实没有什么本质不同，它们都是可执行文件，运行在对应的运行环境中。

## 程序的运行环境

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;程序是运行在运行环境中的，运行环境不只是操作系统，而是操作系统和硬件的集合，这里的硬件可以狭义的理解为**CPU**，因为程序都是由**CPU**来解析执行的。**CPU**只能解释其自身能够理解的机器语言，如果遇到不认识的机器语言指令，就无法执行了，这点没有我们想象中的智慧。当然**CPU**不是只会一种语言，它会若干种，以**Intel**的**i9-8950HK**为例，它能够懂的语言可以使用如下方式展示出来，在终端输入命令`sysctl machdep.cpu`，可以看到如下（只是部分的）输出：

```sh
machdep.cpu.features: FPU VME DE PSE TSC MSR PAE MCE CX8 APIC SEP MTRR PGE MCA CMOV PAT PSE36 CLFSH DS ACPI MMX FXSR SSE SSE2 SS HTT TM PBE SSE3 PCLMULQDQ DTES64 MON DSCPL VMX EST TM2 SSSE3 FMA CX16 TPR PDCM SSE4.1 SSE4.2 x2APIC MOVBE POPCNT AES PCID XSAVE OSXSAVE SEGLIM64 TSCTMR AVX1.0 RDRAND F16C
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这些语言就是指令集，指令集包含了指令，比如：**AVX1.0**指令集，**ARM**处理器就不懂，它是用来增强**CPU**浮点运算的，那么**ARM**不懂是不是意味着在浮点运算上输了**x86**一阵呢？其实不然，**ARM**处理器也会有自己提升浮点运算能力的指令，也会说自己能懂的指令（或语言）。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以看到在运行环境中，**CPU**可以根据指令集的不同分为几个大类，比如：**x86**、**ARM**以及**risc-v**。编译器编译生成的可执行文件一定是基于某些指令集的，或者说隶属于某个大类的，比如：针对**x86**编译的程序，可以看出，面相某一类处理器的程序是无法在另一类处理器上运行的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;除了硬件，运行环境还包括软件，我们一般可以理解为操作系统。我们编写的程序都会显性或隐性的依赖操作系统的能力，显性依赖很好理解，在编写程序时依赖对应操作系统提供的**SDK**，比如：**Win32API**或者 **.Net**运行时，一旦依赖这些内容后，程序就会和具体的操作系统绑定。有同学会说，我就是一个简单的像*gt*一样的程序，只是依赖了标准库，这样编译出来的程序就和操作系统无关了吧？其实不然，这属于隐性依赖，虽然通过使用标准库，可以让我们不修改源代码在不同的操作系统上进行编译，但是它们都需要与具体操作系统中的二进制内容进行链接后才能生成可执行文件，而在某个操作系统下编译生成出了可执行文件后，该文件已经同具体的操作系统完成了链接，这种链接就是隐性依赖。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;早期计算机硬件厂商很多，处于百花齐放的阶段，不同的硬件（**CPU**或输入输出设备），提供了不同的指令。那个年代的操作系统还很薄弱，具体的程序会选择使用硬件提供的指令，导致程序好虽好，但是既挑硬件又挑操作系统，程序编写起来很痛苦，移植很困难。程序与软硬件关系的变迁如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/program-program-program/program-with-software-and-hardware.png" width="70%" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，**X**软件在早期是同时依赖软件（操作系统）和硬件（指令集）的，如果软件要有广泛的使用面，那就需要做许多版本。操作系统的快速发展，收拢了访问硬件的入口，使得软件只需要针对操作系统环境进行开发即可。从变迁过程可以看出，操作系统的出现使得程序能够与硬件逐步解耦，这样的依赖关系也会让人觉得有层次感，这也说明了**好的架构是逐步演进出来的**，但是时至今日，我们的设计中再出现依赖混乱的结构就不应该了。

## 程序与操作系统

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;程序依靠运行环境得以运行，而运行环境中的操作系统是一个承上启下的存在，向下抽象硬件，避免程序毫无依靠的野战，向上提供一致考究的**API**供开发者使用，也就是所谓的赋能。那么操作系统是如同宇宙大爆炸一样突然出现的吗？肯定不是，它也是逐步发展而来的，操作系统的发展过程如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/program-program-program/os-history.png" />
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，在没有操作系统的时代，所有的程序都要从头写到尾，如何启动和运行都需要自己负责，这时肯定就有人希望把这些通用的能力给沉淀下来，所以早期的监控程序就是操作系统的雏形。罗马不是一天建成的，操作系统也是如此，更重要的是，操作系统不是一个独立的程序，而是一个程序集合体。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;程序运行在操作系统之上，由操作系统来管理硬件，访问硬件的形式变成了调用操作提供的**API**，这种间接控制硬件的方式，使得程序的移植方便了许多。以前文中，程序对操作系统的隐性依赖为例，程序源代码和操作系统的关系如下图所示：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/program-program-program/sourcecode-relation.png" width="70%"/>
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如上图所示，程序的源代码（或产出物）依赖标准函数库，看起来程序没有直接依赖操作系统，但是实际上标准函数库就像接口一样，不同的操作系统会加以实现。操作系统实现的标准函数库底层还是会使用系统调用，因此程序的每次调用，最终都是系统调用，所以说操作系统决定了应用程序的能力上限。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;操作系统之于程序的重要性已经不言而喻，但我们的硬件是直接与操作系统关联吗？看起来像是，毕竟我们拿到新电脑后第一件事就是安装操作系统。其实在操作系统启动前，首先会运行一个**BIOS**（**B**asic **I**nput/**O**utput **S**ystem），这个系统一般存储在主机板的**ROM**中，有引导程序的能力。开机后，**BIOS**会确认硬件是否工作正常，比如：常见的内存自检等环节，当众多检查通过后，会启动引导程序。引导程序会读取磁盘的起始位置，按照要求加载操作系统到内存中，然后结束，此时控制权自然就落到了操作系统手中。
