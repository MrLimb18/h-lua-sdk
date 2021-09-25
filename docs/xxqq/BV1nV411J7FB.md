### 魔兽争霸h-lua-sdk基础指令介绍

#### B站演示

> <a target="_blank" href="https://www.bilibili.com/video/BV1nV411J7FB">魔兽争霸h-lua-sdk基础指令介绍</a>

#### 命令行

```
必填 ~ 选填
  ./h-lua-sdk> sdk.exe help  //提示cmd工具命令
  ./h-lua-sdk> sdk.exe new [*PROJECT_NAME]  //新建一个地图项目
  ./h-lua-sdk> sdk.exe we [*PROJECT_NAME]  //以YDWE打开地图项目
  ./h-lua-sdk> sdk.exe model [*PROJECT_NAME] [~PAGE:0|~search:'']  //以WE浏览项目模型，一页最大289个，可翻页可搜索
  ./h-lua-sdk> sdk.exe clear [*PROJECT_NAME]  //清理构建的临时文件
  ./h-lua-sdk> sdk.exe test [*PROJECT_NAME]  //构建测试版本并开启游戏进行调试
  ./h-lua-sdk> sdk.exe build [*PROJECT_NAME]  //构建上线版本并开启游戏进行调试
```

#### 模型命令拓展

```
./h-lua-sdk> sdk.exe model demo //查看项目demo的模型，默认第0页
./h-lua-sdk> sdk.exe model demo 2 //查看项目demo的模型，第2页
./h-lua-sdk> sdk.exe model demo ttg //查看项目demo的模型，只要路径带有ttg的
./h-lua-sdk> sdk.exe model demo abc 1  //查看项目demo的模型，第1页且只要路径带有abc的
```