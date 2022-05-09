# 亲自尝试压缩数据

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;数据会放在格子里，如果放置的很零散，那利用率就很低，通过压缩的手段，让它们能够密实一些，是一个好办法。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;常见的**RLE**编码，以及哈夫曼树的方式进行压缩数据，都是一种压缩策略。哈夫曼树的构造是自底向上的，从而可以构造出一个节点不重复的树，利用节点编码来描述被压缩的数据文件。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/program-how-to-run-06/chapter-6-1.jpg" />
</center>
<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/program-how-to-run-06/chapter-6-2.jpg" />
</center>
<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/program-how-to-run-06/chapter-6-3.jpg" />
</center>