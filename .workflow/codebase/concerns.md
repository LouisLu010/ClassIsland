# ClassIsland 横切关注点与风险分析

生成时间：2026-07-09

## 验证现状

- 本次运行 `dotnet build ClassIsland.Desktop/ClassIsland.Desktop.csproj -c Debug --no-restore --no-incremental -v:minimal`，结果成功，`0` 错误。
- 构建摘要显示 `1367` 个警告；按输出解析的主要类型包括 `CS1591`、`CS8767`、`CS1998`、`CA1416`、`CS8618`、`AVLN3001`、`CS0108`、`PInvoke004`、`CS0436`、`MSB3277`。
- 未发现正式 test project 或 xUnit/NUnit/MSTest 引用；当前质量门主要依赖编译、Qodana/CodeFactor 和人工验证。
- 工作区 Git 状态干净；本次分析新增 `.workflow` 分析产物。

## 日志与可观测性

- 日志注册在 `App.Services.xaml.cs`，包括 console formatter、Sentry logging、AppLoggerProvider、FileLoggerProvider。
- Sentry 在 `Program.AppEntry` 中初始化，支持 release health、trace sample rate、metrics；设置中可关闭。
- 对经纬度日志做了正则遮罩：`latitude=`、`longitude=`。
- `DiagnosticService` 可导出诊断 zip，启动诊断模式会在桌面生成诊断数据。

## 配置与恢复

- `ConfigureFileHelper` 统一 JSON 加载、保存、备份和损坏恢复；加载失败时优先尝试 `.bak`。
- 备份策略避免保存时覆盖备份，降低断电导致主备同时损坏的概率。
- 恢复模式由 `.startup-count` 触发，可清理设置、Config、Profiles 或从备份恢复。
- 风险：`ConfigureFileHelper` 静态构造函数反射修改 `JsonSerializerOptions` 的内部 `s_defaultOptions` 字段，对运行时内部实现敏感。

## 安全与隐私

- 本地密码授权 provider 使用随机 salt + SHA256 单轮哈希；对本地离线攻击不如 PBKDF2/Argon2/bcrypt 等慢哈希稳健。
- 网络 JSON 支持可选 PGP detached signature 验证；更新链路还使用 hash/签名相关 helper。
- Sentry DSN 硬编码在源码中，属于公开客户端 DSN 模式；隐私控制依赖设置、采样率和日志遮罩。
- 插件系统会加载本地目录中的插件程序集，本质是高权限扩展点；现有机制有 API version、OS support、依赖、禁用/卸载标记，但不是安全沙箱。

## 架构风险

- `IAppHost.Host` 和 `PlatformServices` 都是静态全局入口，便于 Avalonia/插件访问，但会降低单元测试隔离性，也让启动顺序更敏感。
- `ClassIsland/App.Services.xaml.cs` 是大型 composition root，注册了大量服务、页面、组件、规则和插件入口；继续增长会增加冲突和启动耦合。
- 主应用 `ClassIsland/` 承载约 `69k` 行业务/UI 代码，是最大变化面；长期可考虑把更新、插件市场、集控、自动化等域进一步拆成 feature assembly。
- `ClassIsland.Shared` 多目标 `net472`，需要持续防止现代 API 渗透；当前 `#if !NETFRAMEWORK` 已用于 `IAppHost`。

## 可疑代码点

- `ClassIsland/Services/PluginService.cs` 的 `ResolveDependencyNode` 接收 `walkingNodes` 用于循环依赖检测，但递归前没有把当前 node 加入路径，循环依赖不会被检测到。
- `NotificationHostService.StartAsync/StopAsync` 返回 `new Task(()=>{})`，如果未来被注册为 HostedService，会返回未启动任务并可能阻塞 Host 启动/停止；当前它是以接口单例注册，所以暂未触发。
- 大量 `CS8767`/nullable 警告说明 converter、Avalonia 接口实现和 nullability 标注不完全匹配，可能掩盖真实空引用问题。
- `MSB3277` 指向依赖版本冲突，当前可见冲突涉及 `System.Collections.Immutable`；`dotnet list package --include-transitive` 显示传递版本为 `9.0.3`，同时 Roslyn 4.3.0 等旧依赖存在。

## 建议优先级

- P0：为插件依赖循环写最小测试或复现脚本，并修正 `ResolveDependencyNode` 的 path tracking。
- P1：建立测试项目，优先覆盖 `ClassIsland.Shared` profile 计算、`LessonsService` 时间状态、`AutomationService` workflow、`PluginService` 依赖排序、`ConfigureFileHelper` 损坏恢复。
- P1：清理构建警告基线，先处理 `CS8618`、`CS8602/CS8603/CS8604`、`CS8767`、`MSB3277`，文档类 `CS1591` 可单独降噪或补齐。
- P2：把密码 provider 迁移到 PBKDF2/Argon2，并保留旧 hash 迁移路径。
- P2：减少 static service locator 使用范围，为核心服务增加可注入 seam，提高测试性。
