# ClassIsland for iOS/iPadOS

这是 ClassIsland 的原生 SwiftUI 移动端，当前范围聚焦于：

- 导入 Windows 版 `Profile.json` 和 `Settings.json`；
- 显示当天、当前及下一节课程；
- 支持普通、预定、临时课表、课表群与多周轮换；
- 在应用内编辑课表、时间表、科目、课表群和预定课表；
- 通过 ActivityKit 在锁屏和灵动岛显示当前课程；
- 编辑锁屏、灵动岛展开/紧凑/最小视图中的组件布局；
- 查询城市天气、近期预报和气象预警，并在实时活动中显示天气指标；
- 安装带声明式移动入口的 `.cipx` 插件，管理权限、设置、组件和事件；
- 提供移动端显示、外观和 Live Activity 设置。

桌面端插件 DLL 不会在 iOS 上加载。插件可以在同一个 `.cipx` 中同时携带桌面 DLL 和 `mobile/plugin.json`，由两个平台分别使用。桌面端插件字段、附加设置及时间点行动仍会在移动端编辑和重排后保留。

最低系统版本为 iOS/iPadOS 17.0。

## 打开工程

仓库已包含可直接打开的 Xcode 工程，需要 macOS 和 Xcode 16：

```bash
open ClassIsland.Mobile.xcodeproj
```

`project.yml` 是工程结构的声明式来源。新增 target 或批量调整文件后，可选择使用 XcodeGen 重新生成：

```bash
brew install xcodegen
xcodegen generate
```

在 Xcode 的 Signing & Capabilities 中为 `ClassIslandMobile` 和 `ClassIslandLiveActivity` 选择同一个开发团队。若默认 Bundle ID 已被占用，请同时修改两个 target 的 Bundle ID。

## 导入 Windows 数据

移动端会自动判断所选 JSON 的类型：

- 课表：选择 Windows ClassIsland 数据目录下 `Profiles/*.json`；
- 应用设置：选择数据目录下的 `Settings.json`；当前会迁移主题、强调色来源、当前课程显示方式、多周轮换、时间偏移及天气城市设置。

课表解析同时兼容当前版本的 `StartTime` / `EndTime` 字段和旧版的 `StartSecond` / `EndSecond` 字段。强调色会按照 Windows 的 `ColorSource` 选择自定义颜色或已提取的壁纸/屏幕颜色；系统强调色会回退到移动端预设。

文件可通过 iCloud Drive、AirDrop 或“文件”App 传入；也可以在系统分享菜单中直接选择 ClassIsland 打开 JSON。为了快速体验，可以在移动端设置页载入内置示例课表。

## 档案与组件编辑

“档案编辑”提供与桌面端相同的核心数据工作区，可维护课程、时间点、课表群和指定日期课表。时间点增删或重排时，所有引用该时间表的课表会同步调整课程数量和顺序。有效改动在点击“保存”或离开页面时写回本机 `Profile.json`。

“灵动岛组件”可分别设置锁屏、展开、紧凑和最小视图。每个区域支持从组件库添加内容、排序、删除，以及设置图标和主题色强调；保存后会立即刷新已有 Live Activity。iPadOS 使用同一份锁屏布局，但不显示灵动岛区域。

“时钟”设置页实时显示课程时钟，并支持在 ±300 秒内调整课程时间偏移；导入 Windows 版 `Settings.json` 时会同步 `TimeOffsetSeconds`。灵动岛时钟组件会持续走时，可单独设置是否显示秒数、是否绕过课程偏移使用系统时间，日期组件也会在跨午夜后自动更新。

“天气”设置页使用小米天气 HTTPS 接口，可搜索并手动选择城市，不要求定位权限或 WeatherKit entitlement。应用会缓存最近一次天气，在断网时继续显示，并在前台约每 15 分钟刷新；当前天气、湿度、风速、AQI、气压和体感温度都可作为独立的 Live Activity 组件。导入 Windows 版 `Settings.json` 时会同步 `CityId` 和 `CityName`。

## 移动插件

“插件”设置页可从“文件”App 导入 `.cipx`，在安装前查看包信息并逐项确认权限。安装器会校验 ZIP 路径、符号链接、重复文件、文件数量和解压大小，只提取 `manifest.yml`、图标及 `mobile/`；桌面程序集不会被提取或执行。插件包会记录 SHA-256，插件配置存放在独立目录，更新插件时不会覆盖。

声明式运行时支持课表页文本、状态、指标、进度和列表组件，动态开关/文本/数字/选择设置，以及课程、天气事件的受控行动。实时活动编辑器中的“插件信息”组件可显示首个已授权插件提供的受限内容。完整包格式和 JSON schema 见 [PLUGIN_API.md](PLUGIN_API.md)。

## 验证

```bash
xcodebuild test \
  -project ClassIsland.Mobile.xcodeproj \
  -scheme ClassIslandMobile \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

Live Activity 需要真机验证。iPhone 支持灵动岛的型号会同时显示灵动岛视图；iPad 只显示锁屏 Live Activity。

仓库的 `build_ios.yml` 会在 `macos-15` runner 上自动选择可用的 iPhone Simulator、运行同一组测试，并构建 Release device archive。成功后可在 workflow 的 Artifacts 中取得 `ClassIsland-iOS-unsigned-<commit>`，其中包含 unsigned IPA 及 SHA-256 校验文件，也支持从 Actions 页面手动触发。

CI 生成的 IPA 不含 Apple 签名，需通过 AltStore、Sideloadly 或其他签名流程重新签名后才能安装。要直接生成可安装的正式 IPA，还需要分别为主 App 和 Live Activity Extension 配置 Apple Distribution 证书及 provisioning profile。

## ActivityKit 限制

当前版本使用本地 ActivityKit 更新：应用在前台时会为下一个课程边界安排精确刷新，并以每 30 秒轮询作为兜底；重新进入前台时也会立即刷新。每次同步还会以最近的课程边界或天气刷新时间作为 `earliestBeginDate` 提交一个 `BGAppRefreshTask`，系统允许执行时会在后台更新已有实时活动；后台任务不会尝试新建实时活动。

`BGAppRefreshTask` 的执行时间由系统根据电量和使用习惯决定，不能保证准点；用户关闭系统“后台 App 刷新”后也不会执行。倒计时会继续由系统显示；若边界后约 1 秒仍未收到更新，实时活动会改为“待同步”，避免继续展示已经结束的旧课程。若需要 App 被完全挂起时仍全天候、准点切换到下一课程，必须接入 ActivityKit push token 与服务端推送更新。后台刷新调度需要在真机上验收。
