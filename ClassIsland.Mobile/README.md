# ClassIsland for iOS/iPadOS

这是 ClassIsland 的原生 SwiftUI 移动端，当前范围聚焦于：

- 导入 Windows 版 `Profile.json` 和 `Settings.json`；
- 显示当天、当前及下一节课程；
- 支持普通、预定、临时课表、课表群与多周轮换；
- 通过 ActivityKit 在锁屏和灵动岛显示当前课程；
- 提供移动端显示、外观和 Live Activity 设置。

插件、自动化、天气、集控和课表编辑暂不在此版本范围内。

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
- 应用设置：选择数据目录下的 `Settings.json`；当前会迁移主题、强调色来源、当前课程显示方式及多周轮换设置。

课表解析同时兼容当前版本的 `StartTime` / `EndTime` 字段和旧版的 `StartSecond` / `EndSecond` 字段。强调色会按照 Windows 的 `ColorSource` 选择自定义颜色或已提取的壁纸/屏幕颜色；系统强调色会回退到移动端预设。

文件可通过 iCloud Drive、AirDrop 或“文件”App 传入；也可以在系统分享菜单中直接选择 ClassIsland 打开 JSON。为了快速体验，可以在移动端设置页载入内置示例课表。

## 验证

```bash
xcodebuild test \
  -project ClassIsland.Mobile.xcodeproj \
  -scheme ClassIslandMobile \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

Live Activity 需要真机验证。iPhone 支持灵动岛的型号会同时显示灵动岛视图；iPad 只显示锁屏 Live Activity。

仓库的 `build_ios.yml` 会在 `macos-15` runner 上自动选择可用的 iPhone Simulator 并运行同一组测试，也支持从 Actions 页面手动触发。

## ActivityKit 限制

当前版本使用本地 ActivityKit 更新：应用在前台时每 30 秒同步，并在重新进入前台时立即刷新。每次同步还会在下一课程边界后提交一个 `BGAppRefreshTask`，系统允许执行时会在后台更新已有实时活动；后台任务不会尝试新建实时活动。

`BGAppRefreshTask` 的执行时间由系统根据电量和使用习惯决定，不能保证准点；用户关闭系统“后台 App 刷新”后也不会执行。倒计时会继续由系统显示，超过预计边界 2 分钟后，实时活动会标记为“待同步”。若需要全天候、准点切换课程内容，仍需接入 ActivityKit push token 与服务端推送更新。后台刷新调度需要在真机上验收。
