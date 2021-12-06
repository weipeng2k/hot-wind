# 更新到Eclipse Temurin

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;最近想更新到**OpenJDK 17**，发现**Homebrew**上的**AdoptOpenJDK**最高只到**16**，是没有更新吗？了解了一下，原来是**AdoptOpenJDK**被废弃了，那该怎么办呢？

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/change-to-temurin/adoptium.png">
</center>

> 之前**JDK16**发布时，朋友圈有一堆同学转发欢呼，而**JDK17**发布时，却安静了许多。我却挺高兴，毕竟是**LTS**版本啊，我不禁想问：你们怎么不欢呼了？

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这就要提到**Eclipse**基金会旗下的[**ADOPTIUM**](https://adoptium.net)了，它是一个发布二进制安装包的项目，而**OpenJDK**的发行版也被其囊括在内。**AdoptOpenJDK**从长远考虑，加入到**ADOPTIUM**，成为[Eclipse Temurin](https://projects.eclipse.org/proposals/eclipse-temurin)。它被设定为用于苛刻的生产环境，换句话说**AdoptOpenJDK**改名了，叫做**Eclipse Temurin**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;接下来，还是基于**Homebrew**，我们来看看怎样切换到**Eclipse Temurin**。

## 已使用AdoptOpenJDK

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;需要卸载**AdoptOpenJDK**，卸载的方式是通过`brew remove --cask $name`命令来进行卸载，其中`$name`是之前安装的**AdoptOpenJDK**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;以**adoptopenjdk8**为例，执行命令：`brew remove --cask adoptopenjdk8`。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;当移除完所有`adoptopenjdk${version}`，就可以对**AdoptOpenJDK**进行`untap`了。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;执行命令：`brew untap AdoptOpenJDK/openjdk`，和**AdoptOpenJDK**说拜拜。

## 还在使用OracleJDK

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**OldTimer**，需要向前走了。首先删除`/Library/Java/JavaVirtualMachines/`目录下的旧有**JDK**，顺便清除下面目录中的内容：

```sh
/Library/Internet Plug-Ins/JavaAppletPlugin.plugin
/Library/PreferencePanes/JavaControlPanel.prefPane
~/Library/Application Support/Oracle/Java
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这样基本清理了旧有**JDK**的内容，开始准备安装**OpenJDK**。

## 安装Temurin

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;还是以二进制包的形式进行安装，所以还是不可避免的使用**cask**，先`tap`上**cask-versions**，使之能够找到所有的**casks**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;运行命令：`brew tap homebrew/cask-versions`。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;然后进行安装，比如要安装**OpenJDK8**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;运行命令：`brew install --cask temurin8`

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;笔者安装了**OpenJDK8**、**11**、**17**三个版本，分别需要运行：

```sh
brew install -- cask temurin8
brew install -- cask temurin11
brew install -- cask temurin // 默认是17
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;安装完成后，在`/Library/Java/JavaVirtualMachines/`目录下会出现三个目录：

<center>
<img src="https://weipeng2k.github.io/hot-wind/resources/change-to-temurin/jdk-path.png">
</center>

## 切换JDK的版本

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在`~/.bash_profile`中添加以下脚本：

```sh
export OPENJDK_JAVA_8_HOME="/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home"
export OPENJDK_JAVA_11_HOME="/Library/Java/JavaVirtualMachines/temurin-11.jdk/Contents/Home"
export OPENJDK_JAVA_17_HOME="/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home"
alias openjdk8='export JAVA_HOME=$OPENJDK_JAVA_8_HOME'
alias openjdk11='export JAVA_HOME=$OPENJDK_JAVA_11_HOME'
alias openjdk17='export JAVA_HOME=$OPENJDK_JAVA_17_HOME'
export JAVA_HOME=$OPENJDK_JAVA_11_HOME
export PATH="/usr/local/bin:/usr/local/sbin:$PATH”
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;然后运行：`source ~/.bash_profile`使之生效，通过运行`openjdk11`，可以将当前**JDK**切换为**OpenJDK11**。
