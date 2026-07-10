# SceneZero AI Coding + Figma 工作流

> 参考资料：`以 AI Coding 为核心的 UX 设计流程实现.pdf`  
> 目标：把 Figma、AI Coding 和 SceneZero 当前项目结合起来，用更高效的方式制作 App 效果图、产品原型和后续前端/SwiftUI 实现。

## 1. 结论

可以参考该 PDF 实现 AI Coding + Figma 工作流，但不建议理解为“让 AI 直接在 Figma 里完成所有设计”。

更适合 SceneZero 的方式是：

**Figma 负责设计表达和视觉 mockup，AI Coding 负责结构拆解、文案生成、界面实现、代码还原和迭代检查。**

最佳流程不是：

```text
Figma MCP → AI 自动生成完整设计 / 完整 App
```

而是：

```text
Figma 高保真界面
→ 截图 + 页面结构描述
→ AI 生成组件结构
→ 再用 Figma MCP / 截图补细节
→ 分模块迭代
→ 落地到 SwiftUI 或宣传效果图
```

## 2. 从 PDF 中得到的关键经验

### 2.1 Figma MCP 的价值

Figma MCP 可以让 AI Coding 工具读取 Figma 中的结构化设计数据，包括：

- 图层结构
- 组件体系
- 颜色
- 间距
- 字体
- 设计变量
- 设计系统样式

它适合用来减少“截图靠猜”的误差。

### 2.2 Figma MCP 的局限

PDF 的实践结论显示：

- 仅靠 Figma MCP 效果不稳定。
- 一次性把整个设计稿交给 AI，token 消耗大，效果反而可能不如截图。
- 从 0 到 1 时，“设计稿截图 + 页面结构描述”通常比“只给 MCP 数据”更有效。
- MCP 更适合补充精确样式，而不是独立完成创意设计。

这对 SceneZero 很重要：  
我们今天要做的是宣传效果图和产品 mockup，不是从一个成熟设计稿还原生产代码，因此不应过度依赖 MCP。

### 2.3 最优输入方式

PDF 推荐的有效方式可以概括为：

```text
截图 + 页面结构描述 + 分模块任务 + 设计系统约束
```

对 SceneZero 来说，可以这样用：

```text
Figma 中画好 Capture / AI Brief / Visual Journal 三个屏幕
→ 分别截图
→ 给 AI 每张截图的功能说明和结构说明
→ 让 AI 输出 SwiftUI 组件、宣传文案或布局校验建议
```

## 3. 你的当前 MCP 配置判断

你当前 VS Code 配置为：

```json
{
  "servers": {
    "figma": {
      "url": "https://mcp.figma.com/mcp",
      "type": "http"
    }
  }
}
```

这说明你已经配置了 Figma MCP 入口。

但当前 Codex 会话尚未暴露可直接调用的 Figma 工具，因此我现在不能直接读取或修改你的 Figma 文件。

另外，PDF 中展示的手动配置示例是：

```json
{
  "mcpServers": {
    "my-figma-tool": {
      "url": "http://127.0.0.1:xxxx/mcp",
      "headers": {
        "Accept": "application/json, text/event-stream"
      }
    }
  }
}
```

这个示例偏向 Figma Dev Mode 本地 MCP 服务。你现在使用的是 Figma 官方远程 MCP 地址，两者可能都可用，但接入方式、权限、是否支持写入能力可能不同。

## 4. 建议的 SceneZero 工作流

### 阶段一：先在 Figma 做高保真效果图

目标：

- 做出 3 个核心手机界面。
- 做出 1 张 16:9 宣传效果图。
- 不追求真实可交互，只追求评委 5 秒看懂。

建议屏幕：

1. Capture：真实场景 + AR/2.5D 预演。
2. AI Brief：自由想法 → 结构化 Prompt。
3. Visual Journal：默认私密的长期视觉灵感库。

参考文档：

```text
App效果图Figma制作步骤.md
```

### 阶段二：优化 Figma 文件结构

在 Figma 中做这些前置优化：

- 删除隐藏图层和废弃图层。
- 不要滥用 Group，尽量使用 Frame。
- 每个业务区块用清晰 Frame 承载。
- 使用 Auto Layout 整理纵向/横向结构。
- 给图层语义化命名。
- 常用元素组件化。

推荐命名：

```text
Screen - Capture
Screen - AI Brief
Screen - Visual Journal

Card - Reference Item
Card - AI Brief Field
Chip - Mood Tag
Button - Export Prompt
Marker - Human Placeholder
Marker - Light Source
```

避免命名：

```text
Group 1
Rectangle 23
Frame 188
Untitled
```

### 阶段三：截图 + 结构说明喂给 AI

不要一次性给 AI 整个 Figma 文件。  
建议每次只处理一个屏幕或一个模块。

例如第一轮 Prompt：

```text
这是 SceneZero 的 AI Brief 页面设计稿截图。
请先忽略颜色和精确样式，只分析页面结构：
顶部导航、自由文本输入区、结构化字段区、Prompt Draft 区、底部操作按钮。
请输出 SwiftUI 组件层级，不要写具体样式。
```

第二轮 Prompt：

```text
结构保持不变。
现在根据 Figma 中的颜色、间距、圆角和字体细节，补充 SwiftUI 样式。
页面背景为 #10141A，卡片为 #1A2029，字段标签使用 #72E0D6。
```

### 阶段四：组件化实现

把界面拆成小组件，而不是一次生成完整页面。

建议组件：

```text
PromoPhoneFrame
CaptureMockScreen
AIBriefMockScreen
VisualJournalMockScreen
ReferenceCard
AIBriefFieldCard
WorkflowPill
MoodTagChip
```

如果后续要把概念界面落地到 SwiftUI，也可以对应：

```text
ReferencePackageView
AIBriefEditorView
VisualJournalView
ReferenceCardView
```

### 阶段五：用 AI 做检查

AI 很适合做这些检查：

- 文案是否表达清楚。
- 页面结构是否过载。
- 字号是否能在 PPT 中看清。
- 三个屏幕是否共同说明产品流程。
- 是否误导评委以为 App 直接生成视频。
- 是否偏离“默认私密、长期积累、AI Brief、Reference Package”的定位。

示例 Prompt：

```text
请从比赛评委视角检查这张 SceneZero 效果图：
1. 5 秒内是否能看懂产品功能？
2. 是否能看出它不是通用 AI 视频生成器？
3. 是否突出 AI Brief 和 Reference Package？
4. 哪些文字应该删减？
5. 哪些界面信息不够清楚？
```

## 5. 如果要用 Figma MCP，需要怎么做

### 5.1 先确认 MCP 是否在当前 AI 工具中可用

你需要在 VS Code / AI 插件里确认是否出现 Figma 工具，例如：

```text
get_file
get_node
get_selection
get_code
get_image
```

如果没有出现，就说明当前对话还不能直接调用 Figma。

### 5.2 选择一个具体 Frame

不要让 AI 读取整个文件。  
在 Figma 中选中一个具体 Frame，例如：

```text
Screen - AI Brief
```

然后复制 node link。

### 5.3 使用小范围任务

推荐任务：

```text
读取这个 Figma node，提取颜色、间距、字体和组件层级。
不要生成完整页面，只输出结构摘要。
```

不推荐：

```text
读取整个 Figma 文件并帮我完成全部 App。
```

### 5.4 MCP + 截图组合使用

最稳输入：

```text
1. 截图：让 AI 看整体视觉。
2. Figma MCP：让 AI 读精确样式。
3. 文字描述：告诉 AI 页面功能和业务语义。
```

这正是 PDF 中最有价值的结论。

## 6. 对今天制作效果图的建议

今天时间有限，建议不要把精力放在搭 MCP 调用链。

更现实的路线：

```text
Figma 手工制作 3 个 mockup 屏幕
→ 按 App效果图Figma制作步骤.md 排版成 16:9 效果图
→ 导出 PNG/PDF
→ 用 AI 辅助检查文案和逻辑
```

如果之后要做真正的 SwiftUI 页面，再进入：

```text
Figma mockup
→ 截图 + 结构描述
→ AI 生成 SwiftUI 原型
→ 真机预览
→ 迭代
```

## 7. SceneZero 专用 Prompt 模板

### 7.1 让 AI 分析 Figma 截图

```text
这是 SceneZero 的 [页面名称] Figma 截图。
请先不要写代码，只分析页面结构和信息层级。

产品定位：
SceneZero 是 AI 影像生成前的导演视觉笔记本，
用于把现实灵感整理成 Reference Package 和 AI Brief。

请输出：
1. 页面主要区域
2. 每个区域的功能
3. 建议的组件拆分
4. 哪些信息应突出
5. 哪些信息可以删减
```

### 7.2 让 AI 生成 SwiftUI 结构

```text
请根据刚才分析的页面结构，生成 SwiftUI 组件层级。
要求：
1. 先只写结构，不写复杂样式。
2. 拆成可复用组件。
3. 使用 SwiftUI 原生布局。
4. 不接入真实数据。
5. 文案使用 SceneZero 当前定位。
```

### 7.3 让 AI 补样式

```text
现在保持组件结构不变，只补充视觉样式：
- 背景：#0B0D10
- 卡片：#1A2029
- 描边：#2B333F
- 主文字：#F4F6F8
- 次文字：#A8B0BC
- AI Brief 强调色：#72E0D6
- 圆角：12 / 16 / 24
- 间距：8 / 12 / 16 / 24

不要改变页面结构。
```

### 7.4 让 AI 检查宣传效果图

```text
请以移动应用创新赛初赛评委视角检查这张 SceneZero 宣传效果图。
判断：
1. 是否能看懂 App 是什么？
2. 是否能看懂核心流程？
3. 是否突出 AI Brief / Reference Package？
4. 是否误导为 App 直接生成 AI 视频？
5. 是否有文字太小、信息过多、视觉重心不清的问题？
请给出具体修改建议。
```

## 8. Figma 文件整理规范

为了后续 AI Coding 更顺利，建议 Figma 中这样命名：

```text
Page: 01 Promo
Frame: Promo 16x9
Frame: Phone - Capture
Frame: Phone - AI Brief
Frame: Phone - Visual Journal

Component: Phone Frame
Component: Reference Card
Component: AI Brief Field
Component: Workflow Pill
Component: Tag Chip
Component: Icon Button
```

图层组织：

```text
Promo 16x9
  Header
  Phone Screens
    Phone - Capture
    Phone - AI Brief
    Phone - Visual Journal
  Workflow
  Value Tags
  Footer
```

## 9. 避坑清单

不要：

- 一次让 AI 读取整个 Figma 文件。
- 只给 MCP，不给截图。
- 只给截图，不解释业务语义。
- 让 AI 自己画复杂人物或真实图片。
- 让 AI 猜产品定位。
- 把宣传效果图做成 App Store 风格但看不出工作流。
- 暗示 SceneZero 直接生成最终视频。

应该：

- 每次只处理一个页面或模块。
- 先结构，后样式。
- 截图 + 结构描述 + MCP 数据组合使用。
- 把复杂图片作为图片资产，不让 AI 手绘。
- 明确告诉 AI：SceneZero 是生成前的视觉参考工作台。
- 用 AI Brief 作为宣传图视觉焦点之一。

## 10. 当前最推荐路线

今天做效果图：

```text
Figma 手工画 mockup
AI 辅助文案与结构检查
不依赖 MCP
```

之后做 SwiftUI 原型：

```text
Figma mockup
截图 + 页面结构描述
必要时 MCP 读取精确样式
AI 分模块生成 SwiftUI
真机预览后迭代
```

如果未来 Figma MCP 在当前 Codex 会话可用，再尝试：

```text
读取选中 Frame
提取 tokens / colors / spacing
生成 SwiftUI 组件结构
```

但现阶段，不要把 MCP 当作今天交付效果图的前置条件。
