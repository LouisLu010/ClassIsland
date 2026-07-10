# ClassIsland 项目画像

生成时间：2026-07-09

## 一句话概览

ClassIsland 是一个基于 Avalonia/.NET 的跨平台大屏课表工具，核心是课表/profile 领域模型、主窗口展示、通知/语音/天气/自动化/插件/集控等扩展能力，架构上采用 Desktop 启动层 + 主应用层 + Core/Shared 抽象层 + 平台实现层。

## 当前状态

- 工作区：`master...origin/master`，Git 状态干净。
- 近期 workflow：未发现 `.workflow` 目录或 7 天内会话。
- 构建：Windows Debug 桌面入口构建成功，`0` 错误，`1367` 个警告。
- 测试：仓库没有正式测试项目；验证主要依赖编译和人工路径。
- 文档：已生成本次分析文件：`tech-stack.md`、`architecture.md`、`features.md`、`concerns.md`。

## 最重要的结构事实

- `ClassIsland.Desktop` 是真正进程入口；`ClassIsland` 是主应用库而不是 exe。
- `App.Services.xaml.cs` 是注册中心，新增业务通常会在这里注册服务、页面、组件、规则、触发器或 action。
- `ClassIsland.Core` 是插件和主应用共享的扩展面；不要把具体业务倒灌进 Core。
- `ClassIsland.Shared` 和 `ClassIsland.Shared.IPC` 需要兼顾 `net472`，跨目标改动要特别小心。
- 平台差异不要直接散落到业务层，优先通过 `ClassIsland.Platforms.Abstractions` 扩展服务接口。

## 推荐下一步

1. 先修复 `PluginService.ResolveDependencyNode` 循环依赖检测，并补测试。
2. 建立最小测试项目，从 `Shared` 领域模型和纯逻辑服务开始。
3. 分阶段清理 warning baseline，优先处理 nullable、版本冲突和平台 API 警告。
4. 为插件/自动化/集控这类高风险域补充开发文档和边界说明。
