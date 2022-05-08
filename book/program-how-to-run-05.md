# 内存和磁盘的亲密关系

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;程序保存在存储设备中，内存和磁盘都可以被视为存储设备，只是**CPU**能够直接访问内存。内存和磁盘会有交互，比如：虚拟内存，会将磁盘上的一部分空间当作内存使用，采用分页或者分段的方式完成其与内存之间的数据交换。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;磁盘是以扇区的方式提供使用，只是切分的粒度更大，一次读取和写入的数据单位也就更大。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/program-how-to-run-05/chapter-5-1.jpg" />
</center>
<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/program-how-to-run-05/chapter-5-2.jpg" />
</center>
<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/program-how-to-run-05/chapter-5-3.jpg" />
</center>
