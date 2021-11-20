# 分布式锁框架

## 为什么需要分布式锁框架？

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分布式锁的实现方式不同，它相应的性能、可用性和正确性保障以及成本都会有所不同，因此需要提供一种适配多种不同实现方式的技术方案。虽然分布式锁的实现可以有多种，但是都需要有监控、流控以及热点锁访问优化等特性，所以该方案不仅能够提供一致的分布式锁API来适配不同的分布式锁实现方式，还需要具备横向功能扩展的能力。

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/distribute-lock-brief-summary/distribute-lock-framework-page.jpg">
</center>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;既要适配不同的实现方式，又要支持开发者横向扩展，这一纵一横的需求就需要通过设计一个简单的分布式锁框架来达成了。

