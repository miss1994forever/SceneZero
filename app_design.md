# 📱 SceneZero (零号场景)

**产品定位**：面向 AIGC 影视创作的 AR 场景预演与视觉 Prompt 生成工具。

SceneZero 不直接生成最终影片，而是帮助创作者在真实空间中快速确定构图、光位、色彩风格与空间关系，并把这些参数转化为可保存、可复用、可输入下游 AI 视频模型的视觉参考包。

## 一、市场痛点与产品愿景 (Market Pain Points & Vision)

1. **AIGC 视频创作的“空间失控”**：现代 AI 生成视频模型（如 Runway、Sora、Kling）具备较强的视觉生成能力，但纯文本 Prompt 难以稳定约束透视关系、人物站位、光源方向和镜头空间，创作者经常需要反复试错。
2. **影视前制的“沟通损耗”**：导演、摄影、灯光与美术在勘景时，如果只依赖文字、草图或口头描述，很难准确同步“光从哪里来、阴影落在哪里、画面整体是什么色调”。
3. **行业趋势验证**：2026 年 6 月初，Martin Scorsese 加入 AI 图像公司 Black Forest Labs 担任顾问，并围绕 AI 辅助 storyboarding / pre-visualization 展开合作。这说明 AI 正在进入专业影视前制流程，但现有 AI 分镜工具更多解决二维叙事草图，仍缺少与真实空间绑定的光位、构图和色彩参考。SceneZero 关注的正是这个“真实场景到 AI 输入”的过渡环节。

## 二、核心功能需求矩阵 (Core PRD)

功能模块对应课程作业中的 AR 交互、多界面逻辑、本地数据持久化与创新应用场景。

### 模块 1：空间光影映射引擎 (RealityKit / ARKit 渲染层)

**定位**：AR 作业核心验收点。

**核心功能**：

- 使用 ARKit 平面检测与 raycast，在真实取景地中放置人物、道具、灯位等虚拟参考物。放置优先命中水平面，避免模型误贴到墙面或不稳定估计平面。
- 在三维空间中添加虚拟影视灯光标记，例如主光、辅光、轮廓光，并通过 RealityKit 的 `SpotLight` / `PointLight` / `DirectionalLight` 影响虚拟物体。
- 支持拖拽、旋转、缩放与删除虚拟物体，让用户可以快速搭建一个轻量级电影场景草图。
- MVP 采用“内置轻量 `.usdz` + RealityKit primitive fallback”的资产策略。Subject 支持 `Subject Block` 与 `Human`，Prop 支持 `Prop Box / Chair / Table / Sofa / Desk / Bookcase / Bed / Night Stand`，Light 使用灯架标记。所有 bundle 模型加载失败时都会回退到程序生成的 primitives。

**技术边界与降级方案**：

- 有 LiDAR 的设备上，优先启用 scene reconstruction / mesh occlusion，用于增强真实物体对虚拟内容的遮挡关系。
- 无 LiDAR 的设备上，使用水平/垂直平面检测作为降级方案，保证基本放置、构图和灯光标记功能可演示。
- 为了让虚拟物体更自然地“落在地面上”，系统会在检测到的水平面上动态放置一个低可见度的阴影接收平面。该平面用于承接虚拟物体与虚拟灯光产生的阴影效果，必要时可结合 RealityKit 的 `OcclusionMaterial` 或半透明材质增强真实地面融合感。
- 虚拟灯光不能真正改变现实墙面材质的物理光照，因此产品目标是“AR 光位与阴影预览”，而不是改变现实画面的真实光照。阴影、高光和光斑通过虚拟物体、阴影接收平面、半透明覆盖层或截图后处理进行视觉模拟。
- 内置 `.usdz` 模型加载后会根据 `visualBounds` 自动归一化到预设尺寸，并对底部高度做贴地修正。交互命中使用贴近模型可见范围的 collision proxy，避免在离模型较远处误拖动物体。
- `Subject Block` 使用不透明哑光材质，避免半透明材质在 AR 相机画面和阴影接收面混合时产生不自然光晕。

**Frame / Lens 构图工具**：

- SceneZero 不在 AR 空间中放置虚拟摄影机模型。第一版把原 Camera 工具改为 Frame / Lens 屏幕层构图工具，用于直接影响实时预览、截图结果和 Prompt。
- Frame 提供常用画幅比例，例如 16:9、2.39:1、1:1、9:16。Frame Line 常驻显示，代表最终保存到 Lookbook 的裁切边界；Composition Guides 则作为可开关的构图辅助线，包含三分线、安全框和中心参考线。
- Lens 提供镜头语言选项，例如 24mm wide、35mm standard、50mm normal、85mm portrait。MVP 阶段不控制真实摄像头焦距，而是用于构图参考、截图遮罩/裁切策略和 Prompt 文本。
- Shot Type 不只修改 Prompt。Wide Shot / Medium Shot / Close-Up / Low Angle 会在画面遮罩或构图框上产生可见差异，让用户看到当前镜头语言如何影响最终参考图。
- Filter 作为 Frame 模式下的视觉输出参数，提供 Realistic、Teal Orange、Neon Night、Noir Gold 等拍摄后风格选择。

**灯光参数设计**：

- 第一版不提供自由 3D 旋转球，而是提供影视常用光位预设，例如左前 45° 主光、右后轮廓光、正前方柔光、顶部俯光、低位侧光。
- 每个光位预设在代码中映射为固定的方向向量与 `transform.rotation`，降低调参难度并避免复杂 3D 旋转交互。
- 色温使用有限档位，例如 3200K 暖光、4500K 中性光、5600K 日光、7000K 冷光，并在内部转换为 RealityKit 灯光颜色。
- 每次添加 Light 时，系统会记录该灯光实例的空间位置、方向预设、色温、强度和 spread 参数快照。Prompt 和 Lookbook 的灯光描述来自实际放置的 Light records，而不是当前 UI 面板里的默认灯光参数。
- 没有放置 Light 时，Prompt 使用 natural ambient lighting；放置多盏 Light 时，Prompt 和 Lookbook 使用 multi-light setup 类型的汇总描述，并在 `layoutJSON` 中保存每盏灯的详细参数。

### 模块 2：拍摄后电影色彩管线 (CoreImage 滤镜层)

**定位**：创新性与视觉表现提升。

**核心功能**：

- 提供若干电影风格预设，例如冷暖对冲、低饱和写实、霓虹夜景、高反差黑金。
- 用户先在 `ARView` 中完成构图、物体摆放、画幅选择和光位调整，然后点击快照 (Capture) 生成静态图片。
- 使用 CoreImage 对快照图片 (`UIImage`) 进行拍摄后滤镜处理，生成更接近影视概念图的参考底图。
- Capture 保存图会按屏幕中稳定的 Frame Line 裁切，只保存取景框内画面；右侧控制 UI、Frame Line 和 Composition Guides 不写入最终 Lookbook 图片。
- 在 MVP 阶段优先使用系统内置滤镜或预设参数组合；如果时间允许，再扩展为 `.cube` LUT 文件解析与 `CIColorCube` 应用。

**技术目标**：

- 保证滤镜预览与截图保存稳定可用。
- 第一阶段不对 `ARView` 的实时渲染流做 CoreImage 全局后处理，也不编写自定义 Metal 后处理管线，避免把课程项目的主要风险集中在底层视频渲染性能上。
- `ARView.snapshot` 是异步流程。用户点击 Capture 后，界面进入 `isCapturing` 状态并临时禁用重复点击；快照完成后，再在 completion 闭包中串联执行 CoreImage 滤镜处理、图片文件写入和 SwiftData 元数据保存。

### 模块 3：灵感画廊与智能提示词翻译器 (SwiftUI / SwiftData 数据层)

**定位**：工程完整度与数据持久化。

**核心功能**：

- 设计“导演监视器”式控制界面，使用 SwiftUI 搭建 AR 视图、右侧相机式控制列、顶部状态胶囊和作品画廊页。
- 支持一键快照 (Capture)，保存当前取景框裁切图、实际灯光 records、占位物位置、色彩风格和生成时间。
- 使用 SwiftData 进行本地持久化，形成可回看的 Lookbook / 灵感画廊。SwiftData 仅保存结构化元数据，例如标题、创建时间、Prompt、灯光参数、物体坐标、滤镜名称和图片文件路径；实际截图图片写入 App 沙盒的 Documents 或 Application Support 目录，避免把高分辨率图片二进制直接塞入数据库。
- 根据当前场景参数自动生成结构化 Text Prompt。MVP 阶段采用确定性模板拼接，不调用外部 LLM API，确保离线可用、结果可控、演示稳定。例如：

```text
Cinematic wide shot, subject standing near the left wall, warm key light from upper right, soft blue fill light, low saturation film look, realistic interior location.
```

**Apple 风格界面原则**：

- AR 画面是第一优先级。控制界面使用轻量浮层，不应长期遮挡主体构图区域。
- 主界面不再保留大面积 `ControlPanelView`。高频参数集中在右侧 Apple Camera-style 控制列中。
- 右侧控制列由三部分组成：中部白色圆形 Capture，下面是纵向滑动模式选择器，上面是当前模式的调节按钮。
- 模式固定为 `Subject / Prop / Frame / Light`。其中 `Frame` 包含 `Frame / Lens / Shot / Filter`，`Light` 包含 `Direction / Color / Intensity / Spread`。
- 点击调节按钮时，在按钮左侧展开短时内联参数胶囊；胶囊可以临时覆盖取景框线，但不会改变取景框位置。
- 顶部状态胶囊只承担状态、Lookbook、Reset 和 Composition Guides 开关，不承担重复参数面板功能。
- 优先使用 SF Symbols、Material 背景、44pt 触控目标和圆形相机式按钮，保持 iOS 原生触感。

**数据闭环**：

用户在真实空间中布置虚拟场景 → 选择光位与色彩风格 → 截图保存 → 自动生成 Prompt → 将图片与文字一起作为下游 AI 视频模型的参考输入。

**Prompt 生成机制**：

Prompt 由用户在 UI 中选择或调整的结构化字段拼接生成，例如：

- 镜头类型：wide shot / close-up / low angle shot。
- 画幅比例：16:9 / 2.39:1 / 1:1 / 9:16。
- Lens 语言：24mm wide / 35mm standard / 50mm normal / 85mm portrait。
- 主体位置：center frame / near the left wall / foreground right。
- 灯光方向：来自实际放置的 Light records，例如 warm key light from upper right / soft fill light from front left。
- 色彩风格：low saturation film look / neon cyberpunk look / high contrast noir look。
- 场景描述：realistic interior location / empty classroom / narrow corridor。

最终生成逻辑类似：

```text
\(shotType), subject \(subjectPosition), \(keyLightDescription), \(colorStyle), \(locationDescription).
```

**历史场景重载策略**：

ARKit 每次启动时的世界坐标原点并不稳定，因此 MVP 阶段不保存和恢复完整 `ARWorldMap`，也不承诺跨房间精确复原绝对坐标。SceneZero 将历史记录定义为“相对布光方案”：

- 保存时，把第一个主体占位符作为局部坐标系原点。
- 其他灯光、道具和参考物体保存为相对于主体的相对位置、旋转与参数。
- 重载时，用户先在当前地面上重新放置主体锚点，系统再按相对坐标整体复现灯光和道具布局。
- 这样既能重用布光设计，又避免 AR 世界坐标漂移导致历史场景错位。

## 三、深度竞品分析 (Competitor Analysis)

SceneZero 的定位不是替代现有分镜或 AI 视频工具，而是补足它们在真实空间约束上的不足。

| 竞品类别 | 代表产品 | 核心运作逻辑 | 核心劣势（SceneZero 的突破口） |
| --- | --- | --- | --- |
| **传统 2D 取景器** | Artemis Pro | 在摄像头画面上叠加画幅框线与焦段模拟。 | 缺少三维空间编辑能力，无法快速表达光位、人物站位和虚拟道具关系。 |
| **AR 分镜/预演工具** | Previs Pro, CineVision | 在空间中放置人物模型、相机和灯光，生成预演画面。 | 更偏完整预演生产流程，学习成本较高；SceneZero 更强调轻量勘景、快速截图与 AI Prompt 输出。 |
| **AI 生成分镜工具** | Storyboarder AI 等 | 通过文本生成二维故事板，辅助叙事规划。 | 画面依赖模型想象，真实空间坐标与光位约束较弱，难以直接指导现场布置。 |
| **AIGC 视频模型** | Runway, Sora, Kling 等 | 通过文本、图片或视频参考生成最终影像。 | 如果输入缺少明确空间和光影参考，容易出现透视不稳定、光照逻辑不统一等问题。 |

**SceneZero 的竞争壁垒 (The Edge)**：

SceneZero 做的是“真实场景中的视觉参考采集器”。它把导演现场勘景时的构图、光位、色彩和空间关系沉淀为截图与结构化 Prompt，作为 AI 分镜、图生图或图生视频流程的上游输入。

## 四、后续开发路线图指引

### 第一阶段：MVP 验证

- 在 SwiftUI 中加载 `ARView`。
- 跑通平面检测与 raycast 放置虚拟几何体。
- 建立内置轻量 `.usdz` 资产链路，并保留 RealityKit primitives 作为 fallback。
- 支持 Subject 与 Prop 的 asset preset 选择，当前内置人物、椅子、桌子、沙发、书桌、书架、床、床头柜和灯架等模型。
- 将 Camera 改为 Frame / Lens 构图工具，提供稳定 Frame Line、Composition Guides、镜头语言和 Shot Type 可视化反馈。
- 添加基础灯光标记与参数面板，例如光源类型、强度、色温档位和预设光位方向。
- 按 Apple 风格优化主界面：右侧相机式控制列、顶部状态胶囊、轻量内联参数胶囊、稳定取景框。
- 使用 `ARView.snapshot` 完成异步截图保存，验证 AR 场景可以形成稳定视觉参考。

### 第二阶段：视觉表现提升

- 增加电影风格滤镜预设。
- 截图保存时先按 Frame Line 裁切到最终参考图范围，再叠加屏幕空间光效和拍摄后滤镜。
- 对截图图片应用 CoreImage 拍摄后滤镜，并将滤镜参数与截图结果绑定保存。
- 优化虚拟物体材质、碰撞 proxy、贴地修正、透明光斑和阴影提示，使画面更接近影视勘景参考。

### 第三阶段：工程闭环

- 搭建 Lookbook 画廊界面。
- 使用 SwiftData 保存元数据与图片文件路径，截图图片存入 App 沙盒目录。
- 使用确定性模板拼接生成 Prompt，并支持一键复制。
- 保存 Frame / Lens 元数据，包括画幅比例、Lens 选项、Shot Type 和 Filter。
- 保存多灯光实例 records，并基于实际灯光数量生成 Prompt 与 Lookbook 汇总。
- 增加删除记录、重载相对布光方案等功能。

## 五、作业实现范围说明

为了保证课程项目可落地，SceneZero 的第一版实现重点放在以下可演示能力：

- AR 空间识别与虚拟物体放置。
- 内置轻量 `.usdz` 模型资产与 RealityKit primitives fallback。
- Subject / Prop 资产 preset 选择，以及贴地、缩放归一化和精确选中操作。
- 虚拟灯光/预设光位标记与参数调节。
- Frame / Lens 画幅线、Composition Guides、镜头语言、Filter 和取景框裁切。
- 拍摄后电影风格滤镜处理。
- 本地画廊与 SwiftData 持久化。
- 基于当前场景参数和实际 Light records 确定性生成 AI 视频 Prompt。
- 基于主体锚点的相对布光方案重载。

不把“实时 60fps 全局后处理”“真实墙面物理打光”“真实摄像头光学变焦控制”“完整摄影机轨迹/运镜系统”“复杂角色动画”“完整视频生成”“外部 LLM Prompt 润色”“跨 session 精确 ARWorldMap 复原”“在线 3D 素材库”“复杂高精度 `.usdz` 资产制作”作为第一版目标。这些方向可作为后续扩展，而不是期末作业的核心风险点。
