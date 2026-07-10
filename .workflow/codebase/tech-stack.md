# ClassIsland 技术栈分析

生成时间：2026-07-09

## 基础平台

- 主要语言：C#，XAML/Avalonia AXAML，少量 Protobuf、YAML、PowerShell、Shell。
- 本地 SDK：`dotnet --info` 显示当前使用 .NET SDK `9.0.315`；仓库 `global.json` 要求 `9.0.100` 且 `rollForward=latestFeature`。
- UI 框架：Avalonia `11.3.17`，配合 FluentAvaloniaUI、HotAvalonia、Xaml.Behaviors、自定义 `ClassIsland.Core` 控件库。
- 运行目标：主应用以 `net8.0` 为核心；桌面入口通过 `CrossPlatformProps.props` 在 Windows 下变为 `net8.0-windows10.0.19041.0`；Launcher 使用 `net9.0`。
- 多目标兼容：`ClassIsland.Shared` 与 `ClassIsland.Shared.IPC` 在 Windows 上多目标 `net8.0;net472`，需要避免共享层使用仅 net8 可用的 API。

## 解决方案与项目

- 解决方案：`ClassIsland.sln`，另有 `ClassIsland.Filter.Linux.slnf`、`ClassIsland.Filter.MacOs.slnf` 用于平台过滤。
- 入口项目：`ClassIsland.Desktop/ClassIsland.Desktop.csproj`，负责平台激活、Avalonia AppBuilder、资源加载器、窗口渲染模式。
- 应用项目：`ClassIsland/ClassIsland.csproj`，承载主业务、窗口、服务、设置页、通知、自动化、更新、管理、插件。
- 核心库：`ClassIsland.Core/ClassIsland.Core.csproj`，提供抽象、控件、注册扩展、主题、组件、通知、规则、自动化基类。
- 共享库：`ClassIsland.Shared/ClassIsland.Shared.csproj`，提供 profile/domain model、Protobuf、JSON helper、跨进程/集控共享模型。
- IPC 库：`ClassIsland.Shared.IPC/ClassIsland.Shared.IPC.csproj`，基于 `dotnetCampus.Ipc` 暴露公开 IPC 服务接口。
- 平台层：`platforms/ClassIsland.Platforms.{Windows,Linux,MacOs}` 实现窗口、通知、定位、桌面集成等平台服务。
- 插件 SDK：`ClassIsland.PluginSdk` 打包 SDK 和 `.cipx` 生成 target；示例插件在 `ClassIsland.ExamplePlugin`。
- 构建辅助：`build/` 为 NUKE 构建脚本；`roslyn/IconsMappingGenerator` 为源生成器/Analyzer；`vendors/` 存放内嵌依赖。

## 主要依赖

- Avalonia 生态：`Avalonia`、`Avalonia.Desktop`、`Avalonia.Controls.ColorPicker`、`FluentAvaloniaUI`、`Avalonia.Labs.CommandManager`、`HotAvalonia`。
- MVVM/响应式：`CommunityToolkit.Mvvm`、`ReactiveUI`。
- 配置/宿主：`Microsoft.Extensions.Hosting`、`Microsoft.Extensions.Logging.*`、`Microsoft.Extensions.Configuration.*`。
- IPC/管理：`dotnetCampus.Ipc`、`Grpc.Net.Client`、`Google.Protobuf`、`Grpc.Tools`。
- 更新/网络/安全：`Octokit`、`Downloader`、`PgpCore`、`Sentry`、`Sentry.Extensions.Logging`。
- 音频/语音：`SoundFlow`、`System.Speech`、`EdgeTtsSharp` submodule。
- 平台集成：`Microsoft.Windows.CsWin32`、`RawInput.Sharp`、`WindowsShortcutFactory`、`Tmds.DBus`、`Mono.Posix.NETStandard`。

## 构建与发布

- 日常验证命令：`dotnet build ClassIsland.Desktop/ClassIsland.Desktop.csproj -c Debug`。
- 本次验证：`dotnet build ClassIsland.Desktop/ClassIsland.Desktop.csproj -c Debug --no-restore --no-incremental -v:minimal` 成功，`0` 错误，摘要为 `1367` 个警告。
- 发布入口：NUKE `PublishApp`、`PublishLauncher`、`BuildNupkg`；普通验证不应使用 NUKE 默认 target。
- 发布参数：`OsName`、`Arch`、`Package`、`BuildType`、`BuildName`、`AppVersion` 由 NUKE `GenerateMetadata` 组装 RID 与 artifact 名。
- CI：`.github/workflows/build_release.yml` 包含 app、launcher、installer、nupkg、release upload 矩阵；会递归 checkout submodules 并添加 GitHub Package Registry source。
- 子模块：`vendors/EdgeTtsSharp` 指向 `git@github.com:ClassIsland/EdgeTtsSharp.git` 的 `classisland-v2` 分支。

## 体量概览

- 源文件约 `950` 个 C#、`215` 个 AXAML、`30` 个 Protobuf。
- 主要代码量：`ClassIsland` 约 `69k` 行，`ClassIsland.Core` 约 `23k` 行，`ClassIsland.Shared` 约 `4.5k` 行。
- UI 与业务主要集中在 `ClassIsland/`，抽象和可复用控件集中在 `ClassIsland.Core/`，跨平台差异集中在 `platforms/`。
