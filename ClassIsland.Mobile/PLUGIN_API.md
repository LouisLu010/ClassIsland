# ClassIsland Mobile Plugin API v1

移动插件沿用桌面 `.cipx` 包。桌面端继续加载 `entranceAssembly`，iOS/iPadOS 只读取 `mobile` 声明和 `mobile/` 目录，不加载 DLL 或下载执行代码。

## manifest.yml

```yaml
id: classisland.example
name: 示例插件
description: 同时支持桌面和移动端
entranceAssembly: ClassIsland.ExamplePlugin.dll
apiVersion: 2.0.0.0
version: 2.0.0.0
author: ClassIsland

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

可用能力：

- `schedule.read`：读取当前/下一节课程、课间和课程进度；
- `weather.read`：读取宿主缓存的天气；
- `network.fetch`：向 `allowedDomains` 中的 HTTPS 主机发起 GET 请求；
- `notification.post`：发布本地通知；
- `url.open`：在用户点按组件后打开 HTTPS 链接；
- `liveActivity.render`：向通用“插件信息”组件提供受限文本。

## mobile/plugin.json

```json
{
  "schemaVersion": 1,
  "settings": [
    {
      "key": "enabled",
      "title": "显示组件",
      "type": "toggle",
      "defaultValue": true
    }
  ],
  "components": [
    {
      "id": "nextLesson",
      "kind": "metric",
      "title": "下一节课",
      "value": "{{schedule.next.subject}}",
      "systemImage": "arrow.right.circle",
      "when": {
        "source": "settings.enabled",
        "equals": "true"
      }
    }
  ],
  "events": [],
  "allowedDomains": [],
  "liveActivity": {
    "title": "下一节课",
    "value": "{{schedule.next.subject}}",
    "systemImage": "puzzlepiece.extension"
  }
}
```

### 组件

`kind` 支持 `text`、`metric`、`status`、`progress` 和 `list`。公共字段包括 `id`、`title`、`subtitle`、`value`、`body`、`systemImage`、`tint`（`#RRGGBB`）、`when` 和可选的 `action`。

`progress` 使用 `minimum`、`maximum` 和可解析为数字的 `value`。`list` 使用 `items` 数组，每项包含 `id`、`label`、`value` 和可选 `systemImage`。

为保证 ActivityKit 载荷稳定低于 4 KB，`liveActivity` 文本会按 UTF-8 字节裁剪，图标会映射到宿主内置的安全 SF Symbols 集合。

组件点按行动当前仅支持：

```json
{
  "kind": "url.open",
  "url": "https://classisland.tech"
}
```

### 设置

设置 `type` 支持：

- `toggle`：Boolean `defaultValue`；
- `text`：String `defaultValue`，可提供 `placeholder`；
- `number`：Number `defaultValue`，可提供 `minimum`、`maximum`、`step`；
- `choice`：String `defaultValue`，并提供 `{ "value", "title" }` 组成的 `options`。

### 事件与行动

事件支持 `app.active`、`schedule.classStarted`、`schedule.breakStarted`、`schedule.afterSchool` 和 `weather.updated`。

自动事件行动支持 `notification.post`、`setting.write`、`network.fetch` 和 `components.refresh`。`url.open` 不能由自动事件触发。

```json
{
  "event": "schedule.classStarted",
  "when": {
    "source": "settings.notify",
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

`network.fetch` 只允许无凭据 HTTPS URL，主机必须完全匹配 `allowedDomains`；重定向也必须停留在同一白名单中。响应上限为 256 KB，若提供 `responseSettingKey`，UTF-8 响应会写入已声明的文本设置。

## 模板值

常用模板包括：

- `{{settings.<key>}}`、`{{now.time}}`、`{{now.date}}`；
- `{{schedule.phase.title}}`、`{{schedule.current.subject}}`、`{{schedule.current.teacher}}`、`{{schedule.next.subject}}`、`{{schedule.next.start}}`、`{{schedule.progress}}`；
- `{{weather.city}}`、`{{weather.condition}}`、`{{weather.temperature}}`、`{{weather.humidity}}`、`{{weather.aqi}}`；
- `{{plugin.name}}`、`{{plugin.version}}`。

模板只能读取安装时声明且用户已授权的能力。未授权或不可用的数据会解析为空字符串。

## 打包

将 `mobile/**/*` 复制到插件输出目录后，现有 ClassIsland Plugin SDK 会把它们与 `manifest.yml`、DLL 和资源一同写入 `.cipx`。仓库中的 `ClassIsland.ExamplePlugin` 是可直接构建的双载荷示例。
