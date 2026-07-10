# ClassIsland 功能分析

生成时间：2026-07-09

## 用户侧核心功能

- 课表显示：主窗口显示当天课表、当前课程、上下课状态；核心在 `ClassIsland/MainWindow.axaml.cs`、`ClassIsland/Services/LessonsService.cs`。
- 课表编辑：Profile 设置窗口、课表表格控件、时间线控件支持课程、时间表、科目、换课、多周轮换编辑；主要在 `ClassIsland/Views/ProfileSettingsWindow.axaml.cs`、`ClassIsland/Controls/ScheduleDataGrid/`、`ClassIsland/Controls/TimeLine/`。
- 通知提醒：上课、课间、放学、天气、管理、Action 通知 provider；主要在 `ClassIsland/Services/NotificationProviders/` 与 `ClassIsland/Services/NotificationHostService.cs`。
- 语音与音频：Windows `SystemSpeechService`、Edge TTS、GPT-SoVITS，音频播放由 `AudioService` 与 `SoundFlow` 支撑。
- 天气：定位、天气数据、天气图标模板、降雨/日出日落/天气预警规则；主要在 `ClassIsland/Services/WeatherService.cs`。
- 自动化：触发器 + 规则集 + 行动组模型；支持定时、URI、信号、托盘菜单、上课/下课/放学、时间点等触发；主要在 `ClassIsland/Services/AutomationService.cs` 和 `ClassIsland/Services/Automation/`。
- 自定义组件：文本、分隔线、课表、日期、时钟、天气、倒计日、轮播、滚动、分组、堆叠组件；注册在 `ClassIsland/App.Services.xaml.cs`。
- 主题系统：内置 Classic、Fluent XAML theme，可通过 `XamlThemeService` 加载配置主题。
- 插件系统：插件市场、插件安装/卸载/禁用、依赖排序、外部插件路径；主要在 `ClassIsland/Services/PluginService.cs` 和 `ClassIsland/Services/PluginMarketService.cs`。
- 集控管理：manifest、policy、credentials、audit event、远程配置/课表下载；主要在 `ClassIsland/Services/Management/` 与 `ClassIsland.Shared/Models/Management/`。

## 设置与窗口

- 设置页由 `AddSettingsPage` 注册，覆盖通用、时钟、存储、隐私、刷新、进阶、组件、外观、提醒、窗口、天气、自动化、插件、主题、调试、关于、管理等。
- ViewModel 多集中在 `ClassIsland/ViewModels/SettingsPages/`，窗口多集中在 `ClassIsland/Views/`。
- URI navigation 注册在 `App.axaml.cs` 启动末尾，支持 `classisland://app/settings/...`、`profile`、`helps` 等内部导航。

## 导入导出与迁移

- README 标注支持 Excel、CSES、ClassIsland 1.x、Class Widgets 1.2 导入，以及导出 CSES/表格类能力。
- 代码中 profile transfer provider 注册在 `App.Services.xaml.cs`：`CsesImportProvider`、`ClassIsland1ImportProvider`、`ClassWidgets1ImportProvider`、CSES export handler。
- 数据迁移和诊断导出主要在 `ClassIsland/Views/DataTransferPage.axaml.cs` 与 `ClassIsland/Services/DiagnosticService.cs`。

## 平台能力

- Windows：窗口样式/前台窗口检测、定位、系统事件、Toast、快捷方式、OSK integration、RawInput/CsWin32 patcher。
- Linux：X11 窗口服务、DBus/desktop toast、`.desktop` 快捷方式；README/AGENTS 说明 X11 是支持路径。
- macOS：窗口服务、定位、Toast、bundle resources 和 macOS icon assets。
- 平台能力通过 `PlatformServices` 静态服务聚合，运行时由 `ClassIsland.Desktop.Program.ActivatePlatforms` 注入实现。

## 后台与生命周期

- Generic Host 启动后会启动 HostedService；通知 provider 通过 `AddHostedService` 注册，`MemoryWatchDogService` 直接注册为 hosted service。
- 应用维护 startup-count 文件，连续启动失败会进入恢复模式。
- Stop 流程会保存 Settings、Automation、Profile、Component 配置，停止 Lessons timer，并释放平台服务。
- 自动备份由 `FileFolderService` 支持，备份 Config、Profiles 和 `Settings.json`。

## 开发者/扩展 API

- 插件开发者面向 `ClassIsland.PluginSdk`，继承 `PluginBase` 并注册 Core 提供的扩展点。
- IPC 客户端面向 `ClassIsland.Shared.IPC.IpcClient` 与公开服务接口，可触发 URI navigation、读取 lessons/profile 公开状态或接收通知。
- Core 中的 `ComponentBase`、`TriggerBase`、`ActionBase`、`NotificationProviderBase` 是主要扩展基类。
