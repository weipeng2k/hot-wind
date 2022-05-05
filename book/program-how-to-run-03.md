# 计算机进行小数运算时出错的原因

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;用于描述二进制小数的位权（指数）是负数，二进制小数转十进制小数依旧是多项式相加，而十进制小数转成二进制，需要循环乘`2`后取整数。就像十进制`1/3`一样，十进制转成二进制小数也会遇到无法表示的问题，所以表述都存在误差，更何况计算呢？

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;计算机表述二进制小数依靠**IEEE**标准，使用了**符号**、**指数**和**尾数**三个区段来表示，而其中尾数需要使用到正则运算，而指数需要依靠**EXCESS**系统。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/program-how-to-run-03/chapter-3-1.jpg" />
</center>
<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/program-how-to-run-03/chapter-3-2.jpg" />
</center>
<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/program-how-to-run-03/chapter-3-2.jpg" />
</center>
