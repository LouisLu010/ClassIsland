# 在 C# 中调用移动端实时活动

Avalonia iOS 版本通过一个很薄的 Swift ActivityKit 桥提供锁屏实时活动和灵动岛。
课程计算、状态组织和调用入口都在 C# 中，普通功能开发者不需要编写 Swift。

## 运行要求

- iOS 17.0 或更高版本。
- 用户在系统设置中允许 ClassIsland 使用实时活动。
- iPhone 需要具有灵动岛硬件才能显示灵动岛；其他支持机型仍可显示锁屏实时活动。
- 应用包必须包含 `ClassIslandLiveActivity.appex`。项目的 MSBuild 目标会在 macOS 构建时自动编译并嵌入它。

## API 命名空间

```csharp
using ClassIsland.Mobile.Avalonia.Services;
```

主要入口是 `LiveActivityClient`：

```csharp
bool canShowLiveActivity = LiveActivityClient.IsSupported;
bool canShowDynamicIsland = LiveActivityClient.IsDynamicIslandSupported;
```

能力值来自系统版本、ActivityKit 授权状态和设备型号。调用方仍应处理系统随后关闭权限的情况。

## 启动或更新

`UpdateAsync` 会在没有活动时创建活动，在已有相同档案的活动时更新活动：

```csharp
var now = DateTimeOffset.Now;
var classEnd = now.AddMinutes(40);

var state = new LiveActivityState
{
    ProfileName = "高二 1 班",
    Phase = LiveActivityPhase.InClass,
    Headline = "数学",
    CompactTitle = "数",
    Teacher = "张老师",
    TimerStart = now,
    TimerEnd = classEnd,
    NextTitle = "英语",
    NextStart = classEnd.AddMinutes(10),
    UpdatedAt = now,
    StaleAt = now.AddHours(8),
    AccentRgba = 0x05ABE8FF
};

var result = await LiveActivityClient.UpdateAsync(state);
if (!result.Succeeded)
{
    Console.WriteLine(result.Message);
}
```

日期使用 `DateTimeOffset`。桥接层会自动转换为 Unix 时间戳，调用方不要自行拼接 JSON。

## 预载上下课切换

把后续状态放入 `Timeline` 后，Widget Extension 会在指定边界自行切换课程内容。
这样即使 Avalonia 进程被 iOS 挂起，也不需要每次上下课都打开应用。

```csharp
var lessonEnd = now.AddMinutes(40);
var nextLessonStart = lessonEnd.AddMinutes(10);

var state = new LiveActivityState
{
    ProfileName = "高二 1 班",
    Phase = LiveActivityPhase.InClass,
    Headline = "数学",
    CompactTitle = "数",
    TimerStart = now,
    TimerEnd = lessonEnd,
    NextTitle = "英语",
    NextStart = nextLessonStart,
    StaleAt = now.Date.AddDays(1).AddMinutes(5),
    Timeline =
    [
        new LiveActivityTimelineEntry
        {
            StartsAt = lessonEnd,
            EndsAt = nextLessonStart,
            Phase = LiveActivityPhase.BreakTime,
            Headline = "课间休息",
            CompactTitle = "休",
            TimerStart = lessonEnd,
            TimerEnd = nextLessonStart,
            NextTitle = "英语",
            NextStart = nextLessonStart
        },
        new LiveActivityTimelineEntry
        {
            StartsAt = nextLessonStart,
            EndsAt = nextLessonStart.AddMinutes(40),
            Phase = LiveActivityPhase.InClass,
            Headline = "英语",
            CompactTitle = "英",
            TimerStart = nextLessonStart,
            TimerEnd = nextLessonStart.AddMinutes(40)
        }
    ]
};

await LiveActivityClient.UpdateAsync(state);
```

ActivityKit 的状态负载有大小限制。原生桥会在编码后自动裁剪最远的时间点，并优先保留近期切换和最后的放学状态。

## 自定义组件布局

不传 `Layout` 时使用 ClassIsland 默认布局。需要自定义时，为每个区域提供组件列表：

```csharp
var layout = new LiveActivityLayout
{
    Regions = new Dictionary<LiveActivityRegion, IReadOnlyList<LiveActivityComponent>>
    {
        [LiveActivityRegion.CompactLeading] =
        [
            new LiveActivityComponent
            {
                Kind = LiveActivityComponentKind.CurrentLesson,
                IsEmphasized = true,
                ShowsIcon = false
            }
        ],
        [LiveActivityRegion.CompactTrailing] =
        [
            new LiveActivityComponent
            {
                Kind = LiveActivityComponentKind.Countdown,
                IsEmphasized = true,
                ShowsIcon = false
            }
        ]
    }
};

await LiveActivityClient.UpdateAsync(state with { Layout = layout });
```

每个紧凑或最小区域只会使用第一个组件。完整区域的组件数量也会由 Swift 端按系统空间限制归一化。

## 天气和插件文字

```csharp
var updated = state with
{
    Weather = new LiveActivityWeather
    {
        WeatherCode = "0",
        Temperature = "24℃",
        Humidity = "45%",
        WindSpeed = "3m/s",
        AirQualityIndex = "42",
        Pressure = "1012hPa",
        FeelsLike = "25℃"
    },
    Plugin = new LiveActivityPluginPresentation
    {
        Title = "值日",
        Value = "第一组",
        SystemImage = "star.fill"
    }
};

await LiveActivityClient.UpdateAsync(updated);
```

## 结束实时活动

```csharp
var result = await LiveActivityClient.EndAsync();
```

结束请求使用立即移除策略。没有活动时重复调用也是安全的。

## ClassIsland 内置自动同步

Avalonia iOS 宿主会自动创建 `AvaloniaLiveActivityCoordinator`。它读取：

- `ILessonsService`：当前课表和时间状态。
- `IProfileService`：档案、科目和教师信息。
- `IExactTimeService`：校准后的本地时间。
- `IWeatherService`：最近一次天气结果。

协调器在应用启动、回到前台、课程状态变化、天气变化和设置变化时调用同一套 C# API。
它会预先发送当天后续课程边界，因此业务代码通常不需要手动调用。

## 错误处理

平台调用不会因“不支持”而抛出异常，而是返回失败的 `PlatformOperationResult`。常见消息包括：

- 当前系统版本不支持实时活动。
- 系统已关闭实时活动权限。
- ActivityKit 原生桥未随应用一起加载。
- 实时活动数据无效。

参数取消仍遵循标准 `CancellationToken` 行为，并会抛出 `OperationCanceledException`。

## 实现位置

- C# API：`ClassIsland.Mobile.Avalonia/ClassIsland.Mobile.Avalonia/Services/`
- iOS 平台调用：`ClassIsland.Mobile.Avalonia/ClassIsland.Mobile.Avalonia.iOS/IosMobilePlatform.cs`
- C# 自动同步：`ClassIsland.Mobile.Avalonia/ClassIsland.Mobile.Avalonia.iOS/AvaloniaLiveActivityCoordinator.cs`
- Swift C ABI 桥：`ClassIsland.Mobile.Avalonia/Native/AvaloniaLiveActivityBridge.swift`
- Widget Extension：`ClassIsland.Mobile/LiveActivity/`

Swift 层属于平台基础设施。扩展普通 C# 业务时，应优先增加 `LiveActivityState` 字段或组件类型，再由平台维护者统一更新桥接协议。
