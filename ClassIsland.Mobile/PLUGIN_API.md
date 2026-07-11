# ClassIsland 移动端插件开发文档

本文适用于 ClassIsland Mobile Plugin API v1、`mobile/plugin.json` 的 `schemaVersion: 1`，以及 iOS/iPadOS 17.0 及以上版本。

移动端插件采用声明式运行时。插件开发者不需要学习 Swift，也不能在 iOS 中动态执行插件 DLL、Swift、JavaScript、Wasm 或下载后的代码。

现有桌面插件可以继续使用 C# 和 Avalonia，只需在原 `.cipx` 中增加 `mobile` 清单和 `mobile/plugin.json`。同一个包可同时服务桌面端和移动端：

| 平台 | 实际加载内容 |
| --- | --- |
| Windows、Linux、macOS 桌面端 | `entranceAssembly` 指向的 .NET 程序集及桌面资源 |
| iOS、iPadOS | `manifest.yml`、插件图标和 `mobile/` 下的声明式文件 |

桌面插件开发可继续参考 [ClassIsland 插件开发文档](https://docs.classisland.tech/dev/plugins/)。本文只描述移动端载荷。

## 1. 支持范围

Mobile Plugin API v1 支持：

- 在课表页显示文本、指标、状态、进度和列表组件；
- 由 JSON 自动生成开关、文本、数字和选择设置；
- 读取宿主提供的课表与天气数据；
- 响应应用激活、上下课、放学和天气更新事件；
- 发布本地通知、写入插件设置、发起受限 HTTPS GET 请求；
- 用户点按组件后打开 HTTPS 链接；
- 向 Live Activity 的通用“插件信息”组件提供标题和值。

当前不支持：

- 直接运行现有桌面插件 DLL；
- 自定义 SwiftUI、Avalonia 或原生页面；
- 自定义后台常驻任务；
- 任意文件系统访问；
- POST、上传、自定义请求头或带凭据的网络请求；
- 自定义 ActivityKit 布局或任意灵动岛视图。

需要这些能力时，应先扩展宿主的 Mobile Plugin API，再通过新的声明式字段开放给插件，而不是让插件执行任意代码。

## 2. 十分钟快速开始

### 2.1 创建目录

在现有插件项目中增加：

```text
YourPlugin/
├── YourPlugin.csproj
├── manifest.yml
├── README.md
├── icon.png
└── mobile/
    └── plugin.json
```

### 2.2 修改项目文件

确保 `mobile/` 会复制到构建输出目录。SDK 打包时会将输出目录整体写入 `.cipx`。

```xml
<ItemGroup>
  <None Update="mobile\**\*">
    <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
  </None>
</ItemGroup>
```

项目还需要启用插件包生成：

```xml
<PropertyGroup>
  <CreateCipx>true</CreateCipx>
</PropertyGroup>
```

### 2.3 修改 `manifest.yml`

保留原有桌面字段，并增加 `mobile`：

```yaml
id: example.lesson-helper
name: 课程助手
description: 同时支持桌面端和移动端
entranceAssembly: Example.LessonHelper.dll
apiVersion: 2.0.0.0
version: 1.0.0
author: Example
icon: icon.png

mobile:
  apiVersion: 1
  runtime: declarative
  entry: mobile/plugin.json
  capabilities:
    - schedule.read
```

### 2.4 创建 `mobile/plugin.json`

下面的最小示例在课表页显示下一节课：

```json
{
  "schemaVersion": 1,
  "components": [
    {
      "id": "nextLesson",
      "kind": "metric",
      "title": "下一节课",
      "subtitle": "{{schedule.next.start}}",
      "value": "{{schedule.next.subject}}",
      "systemImage": "arrow.right.circle.fill",
      "tint": "#05ABE8"
    }
  ]
}
```

### 2.5 构建和安装

```bash
dotnet build YourPlugin/YourPlugin.csproj -c Debug
```

默认生成位置为：

```text
YourPlugin/cipx/YourPlugin.cipx
```

Plugin SDK 默认调用 `pwsh` 生成校验摘要。构建机没有 PowerShell 时，可以安装 `pwsh`，或在项目中设置 `<GenerateHashSummary>false</GenerateHashSummary>` 跳过该步骤。

在 iPhone 或 iPad 上打开“ClassIsland > 设置 > 插件 > 安装本地插件”，从“文件”App 选择该 `.cipx`，确认权限并启用插件。

仓库内的 [ClassIsland.ExamplePlugin](../ClassIsland.ExamplePlugin) 是可直接构建的双载荷示例。

## 3. `.cipx` 包结构

推荐结构如下：

```text
YourPlugin.cipx
├── manifest.yml
├── README.md
├── icon.png
├── Example.LessonHelper.dll
├── 其他桌面依赖文件
└── mobile/
    ├── plugin.json
    └── assets/
        └── optional-data.json
```

iOS 安装器只会提取：

- 根目录的 `manifest.yml`；
- `manifest.yml` 声明且实际存在的图标；
- `mobile/` 下的文件；
- 由宿主生成的安装状态文件。

桌面 DLL 即使存在，也不会在 iOS 中被提取或执行。移动端入口必须位于 `mobile/` 下，并且扩展名必须为 `.json`。

移动端允许不包含 DLL 的纯声明式包，但这种包不能作为普通桌面插件运行。需要双端兼容时，应保留桌面 DLL 和原有清单字段。

## 4. `manifest.yml`

### 4.1 完整示例

```yaml
id: example.lesson-helper
name: 课程助手
description: 展示课程信息并在上课时通知
entranceAssembly: Example.LessonHelper.dll
icon: icon.png
readme: README.md
url: https://example.com/lesson-helper
apiVersion: 2.0.0.0
version: 1.2.0
author: Example

dependencies:
  - id: example.shared-data
    isRequired: true
  - id: example.optional-theme
    isRequired: false

mobile:
  apiVersion: 1
  runtime: declarative
  entry: mobile/plugin.json
  capabilities:
    - schedule.read
    - notification.post
```

### 4.2 公共字段

| 字段 | 类型 | 移动端要求 | 说明 |
| --- | --- | --- | --- |
| `id` | String | 必填 | 全小写插件 ID，1 至 128 个字符 |
| `name` | String | 必填 | 显示名称，1 至 80 个字符 |
| `version` | String | 必填 | 插件版本，1 至 32 个字符 |
| `description` | String | 可选 | 插件说明，最多 1000 个字符 |
| `author` | String | 可选 | 作者，最多 120 个字符 |
| `url` | String | 可选 | 项目地址，最多 2048 个字符 |
| `icon` | String | 可选 | 图标路径，默认 `icon.png` |
| `readme` | String | 可选 | 桌面端自述文件路径，默认 `README.md` |
| `entranceAssembly` | String | 双端包需要 | 桌面端入口程序集，iOS 不执行 |
| `apiVersion` | String | 双端包需要 | 桌面 Plugin API 版本，iOS 仅保留元数据 |
| `dependencies` | Array | 可选 | 最多 32 个插件依赖 |
| `mobile` | Object | 必填 | 移动端入口声明 |

插件 ID 必须匹配：

```regex
^[a-z0-9](?:[a-z0-9._-]{0,126}[a-z0-9])?$
```

依赖 ID 采用相同格式。依赖不能重复、不能引用插件自身。`isRequired` 默认为 `true`。

必需依赖未安装时，插件会安装但保持停用。必需依赖被停用时，依赖它的插件也不会进入运行状态。API v1 暂不支持依赖版本范围。

### 4.3 `mobile` 字段

| 字段 | 类型 | 要求 | 说明 |
| --- | --- | --- | --- |
| `apiVersion` | Integer | 必须为 `1` | Mobile Plugin API 版本 |
| `runtime` | String | 必须为 `declarative` | 声明式运行时 |
| `entry` | String | 必填 | `mobile/` 下的 JSON 文件，路径大小写必须精确匹配 |
| `capabilities` | String[] | 必填，可为空 | 插件请求的宿主能力，不得重复 |

### 4.4 能力列表

| 能力 | 用途 | 何时需要 |
| --- | --- | --- |
| `schedule.read` | 读取当前课程、课间、下一节课和课程进度 | 使用 `schedule.*` 模板、条件或课程事件 |
| `weather.read` | 读取宿主已缓存的天气 | 使用 `weather.*` 模板、条件或天气事件 |
| `network.fetch` | 发起受限 HTTPS GET 请求 | 使用 `network.fetch` 行动或非空 `allowedDomains` |
| `notification.post` | 发布本地通知 | 使用 `notification.post` 行动 |
| `url.open` | 打开外部 HTTPS 链接 | 给组件绑定 `url.open` 点按行动 |
| `liveActivity.render` | 提供 Live Activity 插件信息 | 声明 `liveActivity` |

能力必须同时满足两项才可使用：插件在清单中声明，并且用户在安装或插件管理页授予权限。用户可随时撤销权限，模板在缺少权限时会返回空字符串。

插件更新不会重新授予用户已经撤销的权限。更新后的权限集合只会保留“新版本仍然请求”且“旧版本已经获准”的交集。

## 5. `mobile/plugin.json` 根对象

```json
{
  "schemaVersion": 1,
  "settings": [],
  "components": [],
  "events": [],
  "allowedDomains": [],
  "liveActivity": null
}
```

| 字段 | 类型 | 默认值 | 限制 |
| --- | --- | --- | --- |
| `schemaVersion` | Integer | 无 | 必填，必须为 `1` |
| `settings` | Array | `[]` | 最多 64 项 |
| `components` | Array | `[]` | 最多 32 项 |
| `events` | Array | `[]` | 最多 32 个处理器 |
| `allowedDomains` | String[] | `[]` | 最多 16 个精确主机名 |
| `liveActivity` | Object/null | `null` | 可选的通用 Live Activity 内容 |

`mobile/plugin.json` 未声明的可选数组会按空数组处理。未知字段当前会被忽略，但插件不应依赖这一行为实现版本兼容。

## 6. 插件设置

设置会自动出现在插件详情页，并保存在插件自己的数据目录中。更新或普通卸载插件不会覆盖这些值。

每个设置包含：

| 字段 | 类型 | 要求 |
| --- | --- | --- |
| `key` | String | 必填，在 `settings` 内唯一 |
| `title` | String | 必填，最多 80 个字符 |
| `description` | String | 可选，最多 240 个字符 |
| `type` | String | `toggle`、`text`、`number` 或 `choice` |
| `defaultValue` | Boolean/String/Number | 必填，类型必须与 `type` 匹配 |
| `placeholder` | String | `text` 可选 |
| `minimum` | Number | `number` 可选 |
| `maximum` | Number | `number` 可选 |
| `step` | Number | `number` 可选，必须大于 0 |
| `options` | Array | `choice` 必填 |

`key`、组件 ID 和列表项 ID 均采用：

```regex
^[A-Za-z][A-Za-z0-9._-]{0,63}$
```

### 6.1 开关

```json
{
  "key": "notifyOnClassStart",
  "title": "上课通知",
  "description": "课程开始时发布通知。",
  "type": "toggle",
  "defaultValue": false
}
```

### 6.2 文本

文本设置最多保存 2048 个字符。

```json
{
  "key": "greeting",
  "title": "问候语",
  "type": "text",
  "defaultValue": "今天也要加油",
  "placeholder": "输入问候语"
}
```

### 6.3 数字

默认值必须是有限数字并位于声明范围内。未填写 `step` 时，界面步长为 1。

```json
{
  "key": "targetProgress",
  "title": "目标进度",
  "type": "number",
  "defaultValue": 0.8,
  "minimum": 0,
  "maximum": 1,
  "step": 0.1
}
```

### 6.4 选择

最多 32 个选项。选项 `value` 必须唯一，默认值必须出现在选项中。

```json
{
  "key": "displayMode",
  "title": "显示方式",
  "type": "choice",
  "defaultValue": "subject",
  "options": [
    { "value": "subject", "title": "课程名称" },
    { "value": "teacher", "title": "任课教师" }
  ]
}
```

选项 `value` 最多 128 个字符，`title` 最多 80 个字符。

## 7. 模板值

模板使用双花括号：

```text
下一节：{{schedule.next.subject}}
```

模板标记可以出现在组件文本、通知、URL、网络请求 URL 和字符串类型的 `setting.write` 中。单个模板字符串最多 1024 个字符。

建议使用不带额外空格的形式 `{{schedule.next.subject}}`。未知字段、当前无数据或权限未授予时会解析为空字符串。

### 7.1 通用值

| 模板 | 说明 |
| --- | --- |
| `{{settings.<key>}}` | 当前插件设置，Boolean 输出 `true` 或 `false` |
| `{{now.time}}` | 当前本地时间 |
| `{{now.date}}` | 当前本地日期 |
| `{{plugin.name}}` | 插件显示名称 |
| `{{plugin.version}}` | 插件版本 |

### 7.2 课表值

以下模板需要 `schedule.read`：

| 模板 | 说明 |
| --- | --- |
| `{{schedule.phase}}` | 阶段原始值 |
| `{{schedule.phase.title}}` | 本地化阶段名称 |
| `{{schedule.profile}}` | 当前档案名称 |
| `{{schedule.plan}}` | 当前课表名称 |
| `{{schedule.current.subject}}` | 当前课程名称 |
| `{{schedule.current.initial}}` | 当前课程简称 |
| `{{schedule.current.teacher}}` | 当前任课教师 |
| `{{schedule.current.start}}` | 当前课程开始时间 |
| `{{schedule.current.end}}` | 当前课程结束时间 |
| `{{schedule.break.name}}` | 当前课间名称 |
| `{{schedule.break.start}}` | 当前课间开始时间 |
| `{{schedule.break.end}}` | 当前课间结束时间 |
| `{{schedule.next.subject}}` | 下一节课程名称 |
| `{{schedule.next.initial}}` | 下一节课程简称 |
| `{{schedule.next.teacher}}` | 下一节任课教师 |
| `{{schedule.next.start}}` | 下一节开始时间 |
| `{{schedule.next.end}}` | 下一节结束时间 |
| `{{schedule.session.count}}` | 当天课程数量 |
| `{{schedule.progress}}` | 当前课程或课间的 0 至 1 进度 |

`schedule.phase` 可能为 `upcoming`、`inClass`、`breakTime`、`afterSchool` 或 `noSchedule`。

### 7.3 天气值

以下模板需要 `weather.read`：

| 模板 | 说明 |
| --- | --- |
| `{{weather.city}}` | 城市显示名称 |
| `{{weather.condition}}` | 天气状况 |
| `{{weather.temperature}}` | 当前温度 |
| `{{weather.feelsLike}}` | 体感温度 |
| `{{weather.humidity}}` | 湿度 |
| `{{weather.pressure}}` | 气压 |
| `{{weather.windSpeed}}` | 风速 |
| `{{weather.aqi}}` | 空气质量指数 |
| `{{weather.alert.count}}` | 当前气象预警数量 |

时间、日期、温度等值由宿主按用户系统区域格式化。插件不应依赖固定语言或固定时间格式进行二次解析。

## 8. 条件

组件和事件处理器可以声明 `when`：

```json
{
  "source": "settings.showWeather",
  "equals": "true"
}
```

支持字段：

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `source` | String | 必填，不使用 `{{ }}`，直接填写模板键名 |
| `equals` | String | 值必须等于该字符串 |
| `notEquals` | String | 值不得等于该字符串 |
| `isEmpty` | Boolean | 值的空状态必须匹配 |

多个条件字段同时出现时按“且”处理。API v1 不支持条件嵌套、大小比较、正则表达式或“或”逻辑。

`source` 可以引用 `settings.*`、`schedule.*`、`weather.*`、`now.*` 和 `plugin.*`。引用课表或天气时仍需声明并获得相应能力。

```json
{
  "source": "schedule.phase",
  "notEquals": "noSchedule",
  "isEmpty": false
}
```

## 9. 课表页组件

所有组件当前都显示在课表页，`placement` 只能为 `schedule`，省略时也默认为 `schedule`。

### 9.1 公共字段

| 字段 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `id` | String | 无 | 必填，在 `components` 内唯一 |
| `placement` | String | `schedule` | 当前只支持 `schedule` |
| `kind` | String | 无 | 必填，组件类型 |
| `title` | String | 无 | 必填，最多 80 个字符 |
| `subtitle` | String | `""` | 最多 240 个字符 |
| `value` | String | `""` | 主值，渲染后最多显示 160 个字符 |
| `body` | String | `""` | 正文，最多 512 个字符 |
| `systemImage` | String | `puzzlepiece.extension` | SF Symbol 名称 |
| `tint` | String | 宿主强调色 | `#RRGGBB` |
| `minimum` | Number | `0` | `progress` 最小值 |
| `maximum` | Number | `1` | `progress` 最大值，必须大于最小值 |
| `items` | Array | `[]` | `list` 项目，最多 16 项 |
| `when` | Object | 无 | 可选显示条件 |
| `action` | Object | 无 | 可选点按行动，当前仅支持 `url.open` |

`systemImage` 最多 64 个字符，只能包含字母、数字、点和连字符。若当前系统没有该 SF Symbol，宿主会回退到通用插件图标。

### 9.2 组件类型

| `kind` | 渲染行为 |
| --- | --- |
| `text` | 显示 `body`；`body` 为空时显示 `value` |
| `metric` | 以大号数字或文本显示 `value` |
| `status` | 显示状态圆点和 `value`；`value` 为空时显示 `body` |
| `progress` | 将 `value` 按 `minimum...maximum` 归一化为进度条 |
| `list` | 显示 `items` 中的键值行 |

### 9.3 指标组件

```json
{
  "id": "nextLesson",
  "kind": "metric",
  "title": "下一节课",
  "subtitle": "{{schedule.next.start}}",
  "value": "{{schedule.next.subject}}",
  "systemImage": "arrow.right.circle.fill",
  "tint": "#1FB88C"
}
```

### 9.4 进度组件

`value` 解析失败时按最小值处理，超出范围时会被限制到 0% 至 100%。

```json
{
  "id": "courseProgress",
  "kind": "progress",
  "title": "当前阶段进度",
  "body": "{{schedule.phase.title}}",
  "value": "{{schedule.progress}}",
  "minimum": 0,
  "maximum": 1,
  "systemImage": "chart.bar.fill"
}
```

### 9.5 列表组件

`list` 至少需要一个项目。项目 ID 在当前列表内必须唯一。

| 项目字段 | 类型 | 要求 |
| --- | --- | --- |
| `id` | String | 必填，在当前列表内唯一 |
| `label` | String | 必填，支持模板 |
| `value` | String | 必填，支持模板 |
| `systemImage` | String | 可选的 SF Symbol 名称 |

```json
{
  "id": "weather",
  "kind": "list",
  "title": "当前天气",
  "subtitle": "{{weather.city}}",
  "items": [
    {
      "id": "condition",
      "label": "天气",
      "value": "{{weather.condition}}",
      "systemImage": "sun.max"
    },
    {
      "id": "temperature",
      "label": "温度",
      "value": "{{weather.temperature}}",
      "systemImage": "thermometer.medium"
    }
  ]
}
```

项目标签渲染后最多显示 80 个字符，项目值最多显示 160 个字符。

### 9.6 点按打开链接

组件点按行动当前只支持 `url.open`：

```json
{
  "id": "website",
  "kind": "text",
  "title": "插件主页",
  "body": "点按打开项目网站",
  "action": {
    "kind": "url.open",
    "url": "https://example.com/plugin"
  }
}
```

必须声明并获得 `url.open`。链接只能使用 HTTPS，不能包含用户名或密码，并且必须由用户主动点按组件触发。`url.open` 不受 `allowedDomains` 控制。

## 10. 事件

事件处理器格式：

```json
{
  "event": "schedule.classStarted",
  "when": {
    "source": "settings.notifyOnClassStart",
    "equals": "true"
  },
  "actions": [
    {
      "kind": "notification.post",
      "title": "{{schedule.current.subject}}开始上课",
      "body": "任课教师：{{schedule.current.teacher}}"
    }
  ]
}
```

### 10.1 事件列表

| 事件 | 触发时机 | 所需能力 |
| --- | --- | --- |
| `app.active` | 应用启动或重新进入前台 | 无 |
| `schedule.classStarted` | 当前课程切换为新的上课阶段 | `schedule.read` |
| `schedule.breakStarted` | 当前阶段切换为新的课间 | `schedule.read` |
| `schedule.afterSchool` | 当天首次进入放学阶段 | `schedule.read` |
| `weather.updated` | 宿主成功取得新的天气数据 | `weather.read` |

课程事件依据宿主持久化的课程检查点判断。应用重新打开时，如果课程状态已跨过边界，也可能补发一次对应的状态切换事件。

每个事件处理器最多包含 8 个行动，其中最多 2 个 `network.fetch`。单个插件全部事件的行动总数不得超过 64。

## 11. 行动

| `kind` | 用途 | 所需能力 | 自动事件可用 |
| --- | --- | --- | --- |
| `notification.post` | 发布本地通知 | `notification.post` | 是 |
| `url.open` | 打开 HTTPS 链接 | `url.open` | 否，仅组件点按 |
| `setting.write` | 写入已声明的插件设置 | 无 | 是 |
| `network.fetch` | 发起 HTTPS GET 请求 | `network.fetch` | 是 |
| `components.refresh` | 请求插件组件重新渲染 | 无 | 是 |

事件中的行动按数组顺序执行。行动执行前会再次确认插件仍处于启用状态、包版本未变化、必需依赖可用且对应权限仍然有效。

### 11.1 发布通知

`title` 必填且最多 128 个字符，`body` 必填且最多 512 个字符。两者都支持模板。

```json
{
  "kind": "notification.post",
  "title": "下一节：{{schedule.next.subject}}",
  "body": "{{schedule.next.start}} 开始"
}
```

用户仍需允许 ClassIsland 的系统通知权限。插件权限获准不代表系统通知权限一定可用。

### 11.2 写入设置

`settingKey` 必须指向当前插件已声明的设置，`value` 类型必须匹配。只有字符串值支持模板替换。

```json
{
  "kind": "setting.write",
  "settingKey": "lastSubject",
  "value": "{{schedule.current.subject}}"
}
```

### 11.3 刷新组件

```json
{
  "kind": "components.refresh"
}
```

通常可在 `setting.write` 或 `network.fetch` 后使用。课表、天气和设置本身发生变化时，宿主也会触发相应刷新。

## 12. 网络请求

先在清单中请求 `network.fetch`，再在 `mobile/plugin.json` 中声明精确主机名：

```json
{
  "allowedDomains": [
    "api.example.com"
  ]
}
```

域名只能是主机名，不能包含：

- `https://` 等协议；
- 端口；
- 路径或查询参数；
- 通配符；
- 用户名或密码；
- 连续的点。

白名单采用精确匹配。声明 `example.com` 不会自动允许 `api.example.com`。

请求行动：

```json
{
  "kind": "network.fetch",
  "url": "https://api.example.com/status?class={{schedule.current.subject}}",
  "responseSettingKey": "lastResponse"
}
```

`responseSettingKey` 可省略。提供时，它必须指向已声明的 `text` 设置，响应正文会以 UTF-8 文本写入该设置，并遵循文本设置最多 2048 个字符的限制。省略时，响应正文会在校验成功后丢弃。

网络运行时限制：

- 仅支持 HTTPS GET；
- URL 最多 1024 个字符；
- 连接超时 15 秒；
- 只接受 2xx 响应；
- 响应必须是 UTF-8 文本；
- 响应上限为 256 KB；
- 不使用 Cookie 和 URL Cache；
- 重定向后的每个主机仍必须精确位于白名单中；
- 不支持自定义请求头、请求体、认证信息或证书绕过。

## 13. Live Activity 和灵动岛

插件可以向宿主通用的“插件信息”组件提供一组标题和值：

```json
{
  "liveActivity": {
    "title": "下一节课",
    "value": "{{schedule.next.subject}}",
    "systemImage": "book.closed.fill"
  }
}
```

必须声明并获得 `liveActivity.render`。如果内容使用课表或天气模板，还需要对应的读取能力。

用户需要在 ClassIsland 的 Live Activity 布局编辑器中加入“插件信息”组件。当前只会采用第一个已启用、依赖可用、权限已授予且内容非空的插件结果。

载荷限制：

- `title` 最多 24 个 UTF-8 字节；
- `value` 最多 48 个 UTF-8 字节；
- 超出部分按完整 Unicode 字符裁剪；
- `{{now.*}}` 不允许用于 `liveActivity`，持续时钟应使用宿主时钟组件；
- 内容只在宿主刷新 ActivityKit 状态时更新，不是插件自己的后台循环。

为控制 ActivityKit 载荷，Live Activity 图标会映射到安全集合：

| 可声明名称 | 实际类别 |
| --- | --- |
| `calendar`、`calendar.badge.clock` | 日历 |
| `book`、`book.closed`、`book.closed.fill` | 课程 |
| `bell`、`bell.fill`、`bell.badge` | 通知 |
| `star`、`star.fill`、`sparkles` | 强调 |
| `cloud.sun`、`cloud.sun.fill`、`sun.max`、`sun.max.fill` | 天气 |
| `clock`、`clock.fill`、`timer` | 时间 |
| `info.circle`、`info.circle.fill` | 信息 |
| 其他名称 | 通用插件图标 |

iPadOS 使用同一份 Live Activity 数据，但只显示锁屏区域，不显示灵动岛区域。

## 14. 完整示例

下面的示例包含设置、课表组件、天气组件、条件、通知事件和 Live Activity：

```json
{
  "schemaVersion": 1,
  "settings": [
    {
      "key": "showWeather",
      "title": "显示天气组件",
      "type": "toggle",
      "defaultValue": true
    },
    {
      "key": "notifyOnClassStart",
      "title": "上课通知",
      "type": "toggle",
      "defaultValue": false
    }
  ],
  "components": [
    {
      "id": "nextLesson",
      "kind": "metric",
      "title": "下一节课",
      "subtitle": "{{schedule.next.start}}",
      "value": "{{schedule.next.subject}}",
      "systemImage": "arrow.right.circle.fill",
      "tint": "#05ABE8"
    },
    {
      "id": "weather",
      "kind": "status",
      "title": "当前天气",
      "value": "{{weather.condition}} {{weather.temperature}}",
      "systemImage": "cloud.sun.fill",
      "when": {
        "source": "settings.showWeather",
        "equals": "true"
      }
    }
  ],
  "events": [
    {
      "event": "schedule.classStarted",
      "when": {
        "source": "settings.notifyOnClassStart",
        "equals": "true"
      },
      "actions": [
        {
          "kind": "notification.post",
          "title": "{{schedule.current.subject}}开始上课",
          "body": "任课教师：{{schedule.current.teacher}}"
        }
      ]
    }
  ],
  "allowedDomains": [],
  "liveActivity": {
    "title": "下一节课",
    "value": "{{schedule.next.subject}}",
    "systemImage": "book.closed.fill"
  }
}
```

对应清单至少需要：

```yaml
mobile:
  apiVersion: 1
  runtime: declarative
  entry: mobile/plugin.json
  capabilities:
    - schedule.read
    - weather.read
    - notification.post
    - liveActivity.render
```

仓库中的 [示例定义](../ClassIsland.ExamplePlugin/mobile/plugin.json) 包含更多组件类型。

## 15. 安装器限制

| 项目 | 限制 |
| --- | --- |
| `.cipx` 压缩包 | 最大 20 MB |
| 解压后总大小 | 最大 20 MB |
| 单个 ZIP 条目 | 最大 5 MB |
| ZIP 条目数量 | 最多 256 |
| `manifest.yml` | 最大 256 KB，必须位于包根目录 |
| `mobile/plugin.json` | 最大 1 MB |
| 图标文件 | 最大 1 MB |
| 图标尺寸 | 单边不超过 2048，像素总数不超过 4,194,304 |
| 已安装移动插件 | 最多 64 个 |

图标支持 `png`、`jpg`、`jpeg`、`heic` 和 `webp`。图标必须是单帧有效图片。

安装器会拒绝：

- `../`、绝对路径、Windows 盘符或反斜杠路径；
- 符号链接；
- 大小写不敏感情况下重复的路径；
- 路径大小写与 `mobile.entry` 不一致；
- 超过数量或大小限制的压缩包；
- 安装确认后内容被替换的包。

安装时会记录整个 `.cipx` 的 SHA-256，并在最终写入前再次检查。当前本地插件包不要求发布者数字签名，SHA-256 只能检测确认后的包变更，不能证明发布者身份。

## 16. 更新、卸载和数据保留

- 相同插件 ID 的新包会作为更新安装；
- 更新时保留已有插件设置；
- 新增设置使用其 `defaultValue`；
- 删除或类型发生变化的旧设置不会继续参与运行；
- 更新不会重新授予已撤销权限；
- 普通卸载会保留插件设置，方便以后重新安装；
- 插件停用后不会渲染组件、处理事件或提供 Live Activity 内容；
- 必需依赖缺失或停用时，插件不会进入运行状态。

开发者不应把插件包本身当作用户数据存储。需要持久化的简单状态应声明为设置，并通过 `setting.write` 或 `network.fetch.responseSettingKey` 更新。

## 17. 将现有桌面插件适配到移动端

1. 保留原有 C#、Avalonia、DLL 和桌面清单字段。
2. 在 `manifest.yml` 增加 `mobile`。
3. 创建 `mobile/plugin.json`，只声明移动端需要的行为。
4. 在 `.csproj` 中复制 `mobile/**` 到输出目录。
5. 只请求实际使用的能力。
6. 构建 `.cipx`，确认包中同时存在 DLL 和 `mobile/plugin.json`。
7. 在真机或 Simulator 中安装，分别测试拒绝权限和授予权限两种情况。

适配难度通常如下：

| 原插件类型 | 移动端适配情况 |
| --- | --- |
| 展示课表、天气、文本或进度 | 可直接改写为声明式组件 |
| 简单提醒或状态联动 | 可使用事件和行动 |
| 简单远程文本读取 | 可使用受限 `network.fetch` |
| 自定义桌面设置页 | 需改写为四种声明式设置控件 |
| 任意 C# 业务逻辑 | 不能直接运行，需拆成宿主能力或声明式规则 |
| 原生系统集成、自定义 UI | 需要先扩展 ClassIsland 移动端本体 |

## 18. 调试清单

构建后先检查包内容：

```bash
unzip -l YourPlugin/cipx/YourPlugin.cipx
```

至少应看到：

```text
manifest.yml
mobile/plugin.json
```

推荐依次验证：

1. 插件能通过安装预检。
2. 安装页显示的 ID、名称、版本和权限正确。
3. 拒绝全部权限时插件不会泄露课表、天气或执行受保护行动。
4. 授予权限后模板能显示真实数据。
5. 停用插件后组件、事件和 Live Activity 内容消失。
6. 更新插件后设置仍保留，已撤销权限不会恢复。
7. 缺少、停用必需依赖时插件不会运行。
8. 网络请求的原始地址和重定向地址都受白名单约束。

## 19. 常见错误

| 错误现象 | 常见原因 |
| --- | --- |
| 缺少移动入口 | `.csproj` 没有复制 `mobile/**`，或 `entry` 路径写错 |
| `runtime` 不受支持 | 不是 `declarative` |
| 不支持 API 版本 | `mobile.apiVersion` 不是 `1` |
| 移动定义无效 | `schemaVersion`、字段类型、ID、数量或长度不符合限制 |
| 模板始终为空 | 未声明能力、用户未授权、当前没有课表/天气，或模板名称错误 |
| 插件已启用但不运行 | 必需依赖缺失或依赖插件已停用 |
| 通知没有显示 | 插件权限或 iOS 系统通知权限未开启 |
| URL 无法打开 | 不是用户点按、不是 HTTPS，或 URL 带有凭据 |
| 网络请求被拒绝 | 主机未精确列入 `allowedDomains`，或重定向离开白名单 |
| Live Activity 不显示插件信息 | 未授权能力、布局未加入“插件信息”，或已有其他插件先提供内容 |

若文档与实现出现差异，以安装器的校验结果为准。实现入口位于：

- `App/Models/MobilePluginModels.swift`
- `App/Services/MobilePluginPackageService.swift`
- `App/Services/MobilePluginRuntime.swift`
- `App/Services/MobilePluginManager.swift`
