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

- 使用 ARKit 平面检测与 raycast，在真实取景地中放置基础几何占位符，例如人物站位、道具盒、墙面参考标记。
- 在三维空间中添加虚拟影视灯光标记，例如主光、辅光、轮廓光，并通过 RealityKit 的 `SpotLight` / `PointLight` / `DirectionalLight` 影响虚拟物体。
- 支持拖拽、旋转、缩放与删除虚拟物体，让用户可以快速搭建一个轻量级电影场景草图。
- MVP 阶段优先使用 RealityKit primitives 生成占位资产，例如 `MeshResource.generateBox`、`MeshResource.generateSphere`、胶囊形人物占位符、摄影机视锥和灯光方向锥体；后续再按需要引入通用 `.usdz` 白模、灯架或摄影机模型作为视觉增强。

**技术边界与降级方案**：

- 有 LiDAR 的设备上，优先启用 scene reconstruction / mesh occlusion，用于增强真实物体对虚拟内容的遮挡关系。
- 无 LiDAR 的设备上，使用水平/垂直平面检测作为降级方案，保证基本放置、构图和灯光标记功能可演示。
- 为了让虚拟物体更自然地“落在地面上”，系统会在检测到的水平面上动态放置一个低可见度的阴影接收平面。该平面用于承接虚拟物体与虚拟灯光产生的阴影效果，必要时可结合 RealityKit 的 `OcclusionMaterial` 或半透明材质增强真实地面融合感。
- 虚拟灯光不能真正改变现实墙面材质的物理光照，因此产品目标是“AR 光位与阴影预览”，而不是改变现实画面的真实光照。阴影、高光和光斑通过虚拟物体、阴影接收平面、半透明覆盖层或截图后处理进行视觉模拟。

**灯光参数设计**：

- 第一版不提供自由 3D 旋转球，而是提供影视常用光位预设，例如左前 45° 主光、右后轮廓光、正前方柔光、顶部俯光、低位侧光。
- 每个光位预设在代码中映射为固定的方向向量与 `transform.rotation`，降低调参难度并避免复杂 3D 旋转交互。
- 色温使用有限档位，例如 3200K 暖光、4500K 中性光、5600K 日光、7000K 冷光，并在内部转换为 RealityKit 灯光颜色。

### 模块 2：拍摄后电影色彩管线 (CoreImage 滤镜层)

**定位**：创新性与视觉表现提升。

**核心功能**：

- 提供若干电影风格预设，例如冷暖对冲、低饱和写实、霓虹夜景、高反差黑金。
- 用户先在 `ARView` 中完成构图、物体摆放和光位调整，然后点击快照 (Capture) 生成静态图片。
- 使用 CoreImage 对快照图片 (`UIImage`) 进行拍摄后滤镜处理，生成更接近影视概念图的参考底图。
- 在 MVP 阶段优先使用系统内置滤镜或预设参数组合；如果时间允许，再扩展为 `.cube` LUT 文件解析与 `CIColorCube` 应用。

**技术目标**：

- 保证滤镜预览与截图保存稳定可用。
- 第一阶段不对 `ARView` 的实时渲染流做 CoreImage 全局后处理，也不编写自定义 Metal 后处理管线，避免把课程项目的主要风险集中在底层视频渲染性能上。
- `ARView.snapshot` 是异步流程。用户点击 Capture 后，界面进入 `isCapturing` 状态并临时禁用重复点击；快照完成后，再在 completion 闭包中串联执行 CoreImage 滤镜处理、图片文件写入和 SwiftData 元数据保存。

### 模块 3：灵感画廊与智能提示词翻译器 (SwiftUI / SwiftData 数据层)

**定位**：工程完整度与数据持久化。

**核心功能**：

- 设计“导演监视器”式控制界面，使用 SwiftUI 搭建 AR 视图、参数控制面板、风格选择页和作品画廊页。
- 支持一键快照 (Capture)，保存当前 AR 场景截图、灯光参数、占位物位置、色彩风格和生成时间。
- 使用 SwiftData 进行本地持久化，形成可回看的 Lookbook / 灵感画廊。SwiftData 仅保存结构化元数据，例如标题、创建时间、Prompt、灯光参数、物体坐标、滤镜名称和图片文件路径；实际截图图片写入 App 沙盒的 Documents 或 Application Support 目录，避免把高分辨率图片二进制直接塞入数据库。
- 根据当前场景参数自动生成结构化 Text Prompt。MVP 阶段采用确定性模板拼接，不调用外部 LLM API，确保离线可用、结果可控、演示稳定。例如：

```text
Cinematic wide shot, subject standing near the left wall, warm key light from upper right, soft blue fill light, low saturation film look, realistic interior location.
```

**数据闭环**：

用户在真实空间中布置虚拟场景 → 选择光位与色彩风格 → 截图保存 → 自动生成 Prompt → 将图片与文字一起作为下游 AI 视频模型的参考输入。

**Prompt 生成机制**：

Prompt 由用户在 UI 中选择或调整的结构化字段拼接生成，例如：

- 镜头类型：wide shot / close-up / low angle shot。
- 主体位置：center frame / near the left wall / foreground right。
- 灯光方向：warm key light from upper right / soft fill light from front left。
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
- 使用 RealityKit primitives 搭建人物、道具、摄影机和灯光占位资产。
- 添加基础灯光标记与参数面板，例如光源类型、强度、色温档位和预设光位方向。
- 使用 `ARView.snapshot` 完成异步截图保存，验证 AR 场景可以形成稳定视觉参考。

### 第二阶段：视觉表现提升

- 增加电影风格滤镜预设。
- 对截图图片应用 CoreImage 拍摄后滤镜，并将滤镜参数与截图结果绑定保存。
- 优化虚拟物体材质、透明光斑和阴影提示，使画面更接近影视勘景参考。

### 第三阶段：工程闭环

- 搭建 Lookbook 画廊界面。
- 使用 SwiftData 保存元数据与图片文件路径，截图图片存入 App 沙盒目录。
- 使用确定性模板拼接生成 Prompt，并支持一键复制。
- 增加删除记录、重载相对布光方案等功能。

## 五、作业实现范围说明

为了保证课程项目可落地，SceneZero 的第一版实现重点放在以下可演示能力：

- AR 空间识别与虚拟物体放置。
- RealityKit primitives 占位资产。
- 虚拟灯光/预设光位标记与参数调节。
- 拍摄后电影风格滤镜处理。
- 本地画廊与 SwiftData 持久化。
- 基于当前场景参数确定性生成 AI 视频 Prompt。
- 基于主体锚点的相对布光方案重载。

不把“实时 60fps 全局后处理”“真实墙面物理打光”“复杂角色动画”“完整视频生成”“外部 LLM Prompt 润色”“跨 session 精确 ARWorldMap 复原”“复杂 `.usdz` 资产制作”作为第一版目标。这些方向可作为后续扩展，而不是期末作业的核心风险点。
