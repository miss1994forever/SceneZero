# SceneZero 具体开发步骤

本文档根据 `app_design.md` 拆分，用于后续正式开发时按阶段推进。第一版目标是完成一个稳定可演示的 AR 场景预演与 Prompt 生成 MVP。

## 一、开发原则

- 优先完成可演示闭环：AR 放置 → 参数调节 → 快照 → 拍摄后滤镜 → 本地保存 → Prompt 生成。
- 不实现实时 60fps 全局后处理、不做完整视频生成、不追求真实墙面物理打光。
- 第一版资产以 RealityKit primitives 为 fallback；Final Project 可加入少量内置 `.usdz` 白模资产，例如人物、桌子、椅子、沙发、灯架等，但不做在线素材库。
- 图片文件写入 App 沙盒目录，SwiftData 只保存元数据和图片路径。
- 历史场景重载使用“主体锚点 + 相对坐标”，不做跨 session 精确 `ARWorldMap` 恢复。
- 灯光效果采用“三层模拟”方案：RealityKit light 影响虚拟物体，屏幕空间 overlay 预览现实画面上的光斑/光束，Capture 后把 overlay 合成到静态截图中。
- Camera 不作为空间中的虚拟摄影机模型实现。第一版改为 Frame / Lens 构图工具，用画幅遮罩、构图线、镜头类型和截图裁切/遮罩来辅助生成 AI 参考图。
- UI 优先贴近 Apple Human Interface Guidelines：AR 画面优先、控件轻量、层级清晰、使用系统控件和 SF Symbols、避免长期遮挡取景区域。
- 控制面板采用固定高度加内部滚动，不再使用 `More / Less` 二级展开；完全收起后的入口放在右下角浮动按钮，并避开 safe area。
- Capture 和 Lookbook 不属于参数调节工具，应从工具面板中分离。Capture 作为独立高频主操作按钮常驻在 AR 画面上，Lookbook 作为独立页面入口放在轻量导航位置。
- 产品结构按多界面设计推进：Capture 负责 AR 采集，Studio 负责 Lookbook / 灵感夹 / 项目管理，Explore 作为未来电影参考图浏览与搜索界面。
- AR 物体交互应从“面板参数调节”升级为“直接操控”：支持 tap 选中、拖拽移动、双指缩放和双指旋转；面板滑杆保留为精细调整。

## 二、灯光效果技术方案

### 目标

SceneZero 的灯光功能目标不是让虚拟灯真正改变现实墙面或桌面的物理光照，而是为导演提供清晰、可保存、可输入 AIGC 工具的“布光参考图”。

### 最佳方案：三层灯光模拟

1. **RealityKit 虚拟灯光层**
   - 用户添加 Light 后，在 AR 空间中创建灯位标记。
   - 同时创建 RealityKit 的 `SpotLight` 或 `PointLight`，用于影响虚拟 `Subject`、`Prop` 等 primitives。
   - 该层只影响虚拟物体，不影响真实摄像头画面。

2. **屏幕空间光效预览层**
   - 在 SwiftUI 层叠加一个可调颜色、强度、半径和方向的光斑/光束 overlay。
   - overlay 使用当前 Light 的参数生成，例如色温、方向、强度、扩散范围。
   - 该层用于让用户在实时 AR 预览中看到“灯大概打在哪里”，不依赖 RealityKit 改变真实画面。

3. **Capture 后合成层**
   - 用户点击 Capture 后，先通过 `ARView.snapshot` 得到静态图。
   - 再把光斑/光束 overlay 合成到截图上。
   - 最后应用 CoreImage 电影风格滤镜，并保存到 Lookbook。

### 为什么采用该方案

- RealityKit 的灯光不能直接照亮摄像头画面中的真实墙面或桌面。
- 纯虚拟阴影接收平面可以增强虚拟物体落地感，但无法表现“现实画面被灯打亮”的直观效果。
- 屏幕空间 overlay 更符合本项目定位：生成导演可理解、AI 可参考的视觉底图。
- Capture 后合成能保证保存图和实时预览一致，也避免实时 60fps 全局后处理的性能风险。

### 第一版不做

- 不做真实环境材质重建。
- 不做实时摄像头像素级全局后处理。
- 不承诺虚拟灯照亮现实物体。
- 不为每个现实表面计算真实阴影和反射。

## 三、Frame / Lens 构图方案

### 目标

SceneZero 的构图功能不是替代专业摄影机控制，也不是一般电影拍摄 App，而是为 AIGC 视频生成提供更明确的视觉参考图和结构化镜头语言。

### 方案说明

1. **Frame 画幅层**
   - 在 AR 画面上叠加可选画幅遮罩，例如 16:9、2.39:1、1:1、9:16。
   - 显示安全框、中心十字和三分线，辅助用户安排主体、道具和光位。
   - Capture 时可选择把画幅遮罩合成进图片，或按画幅裁切输出参考图。

2. **Lens 镜头语言层**
   - 提供镜头参考选项，例如 24mm wide、35mm standard、50mm normal、85mm portrait。
   - 第一版不直接控制 iPhone 物理焦距，也不接入复杂 `AVCaptureDevice` 变焦。
   - Lens 选项主要用于改变构图提示、Prompt 文本和截图裁切/遮罩策略。

3. **Shot Type 视觉反馈**
   - `Wide Shot / Medium Shot / Close-Up / Low Angle` 不应只修改 Prompt。
   - 至少需要在实时预览中通过构图框或参考遮罩体现差异。
   - Capture 后保存图也应体现当前画幅和镜头类型，避免用户看到的和保存的参考图不一致。

### 为什么替代 Camera

- 当前 Camera 只是空间中的虚拟机位盒子，不改变画面，不影响截图，也不直接提升 AI 参考图质量。
- 对 AIGC 辅助创作来说，画幅比例、构图线、镜头语言和 Prompt 结构比“放一个摄影机模型”更有价值。
- Frame / Lens 可以直接影响实时预览、保存图和 Prompt，产品闭环更清楚。

### 第一版不做

- 不做真实光学变焦控制。
- 不做完整摄影机轨迹或运镜系统。
- 不把 SceneZero 扩展成通用拍摄 App。

## 四、阶段 0：项目基础整理

### 目标

建立后续开发所需的基础结构，避免所有逻辑堆在 `ContentView.swift` 中。

### 建议任务

1. 创建基础目录结构：
   - `Views/`
   - `AR/`
   - `Models/`
   - `Services/`
   - `Utilities/`
2. 将主界面拆成 SwiftUI 容器：
   - `MainView`
   - `ARSceneView`
   - `ControlPanelView`
   - `LookbookView`
3. 引入 RealityKit / ARKit 基础桥接：
   - 使用 `UIViewRepresentable` 包装 `ARView`。
   - 配置 `ARWorldTrackingConfiguration`。
   - 启用水平/垂直平面检测。

### 验收标准

- App 可以启动并显示 AR 摄像头画面。
- SwiftUI 页面结构清晰，不再只有默认的 `Hello, world!`。

## 四点五、Apple 风格 UI 与控制面板方案

### 目标

让 SceneZero 在横屏和竖屏下都保持“AR 画面优先”的使用体验，同时保留快速调参能力。

### 设计原则

1. **沉浸优先**
   - AR 预览和构图线是主内容。
   - 控制面板只在需要调参时出现。
   - 横屏默认进入沉浸模式，只显示一个右下角浮动工具入口。

2. **固定高度 + 内部滚动**
   - 控制面板不根据内容无限增高。
   - Header 固定。
   - 中间参数区使用 `ScrollView` 查看更多内容。
   - 避免横屏压缩导致 Picker、Label、Slider 重叠。

3. **单一收起逻辑**
   - 不再保留 `More / Less`。
   - “查看更多参数”交给滚动。
   - “减少遮挡”交给完全收起为浮动按钮。

4. **右下角浮动入口**
   - 收起后的按钮放在右下角，使用 `slider.horizontal.3` 或类似 SF Symbol。
   - 按钮尺寸约 52-56pt，符合触控目标。
   - 右侧和底部需要留出 safe area padding，避免 Home Indicator 和系统手势区域。
   - 点击按钮或向上滑动屏幕都可以重新打开面板。

5. **Apple 风格视觉约束**
   - 使用 `.regularMaterial` 或 `.ultraThinMaterial` 作为浮层背景。
   - 使用系统 `Button`、`Picker`、`Slider`、`Toggle`。
   - 工具入口尽量使用图标，不用过长说明文字。
   - 横屏下减少大面积卡片按钮，必要时可把工具选择改为更紧凑的图标 segmented toolbar。

6. **Capture / Lookbook 分离**
   - `Capture` 是最高频主动作，不放在工具面板内部。
   - `Capture` 使用独立浮动按钮，面板收起后仍然可用。
   - `Capture` 按钮建议放在右下角附近，但需要与“打开工具面板”按钮形成清楚层级：Capture 更突出，工具入口更轻。
   - `Lookbook` 是结果管理入口，不放在参数工具面板内部。
   - `Lookbook` 可放在顶部状态栏右侧、左下角轻量图标，或作为单独 sheet / navigation 入口。
   - 保存成功后可以用 toast / alert 提供 “Saved to Lookbook” 反馈，不要求用户立即进入 Lookbook。

7. **视觉密度 Apple 化**
   - 工具面板只负责参数调节，不承载 Capture / Lookbook 等页面级动作。
   - `Subject / Prop / Frame / Light` 从大卡片改为紧凑图标工具栏。
   - 工具栏按钮使用 44-48pt 触控目标，优先显示 SF Symbols。
   - 当前选中工具的名称在参数标题处显示，工具栏本身可减少文字。
   - 参数面板减少重复 label 和大面积背景，优先使用系统间距、细分隔线和轻量 selected state。

### 建议实现步骤

1. 调整 `MainView`：
   - 使用 `GeometryReader` 判断横竖屏。
   - 横屏默认 `isControlPanelVisible = false`。
   - 竖屏默认显示固定高度控制面板。
   - 隐藏状态下把浮动按钮放到 `.bottomTrailing`。
   - 浮动按钮使用 safe area padding，例如 trailing 20pt、bottom 20-28pt。

2. 调整 `ControlPanelView`：
   - 移除 `More / Less` 状态。
   - 使用 `VStack` 固定 header 和 scroll content。
   - 参数内容放入 `ScrollView(.vertical)`。
   - 从面板中移除 Capture / Lookbook 操作栏。
   - 横屏面板高度控制在约 200-240pt。
   - 竖屏面板高度控制在约 260-320pt。

3. 压缩工具选择区域：
   - 保留 Subject / Prop / Frame / Light 四个工具。
   - 将大卡片按钮改为紧凑图标工具栏或 segmented toolbar。
   - 工具按钮高度控制在 44-48pt。
   - 默认只显示 SF Symbols，当前选中工具的文字在参数标题处显示。
   - VoiceOver accessibility label 保留完整工具名称。

4. 分离 Capture：
   - 在 `MainView` 中新增独立 Capture 浮动按钮。
   - 面板显示和隐藏时 Capture 都保持可用。
   - Capture 按钮使用 `.borderedProminent` 或圆形/胶囊形主按钮样式。
   - Capture 执行时显示 `isCapturing` 状态，并禁用重复点击。
   - Capture 位置需要避开右下角工具入口、Home Indicator 和画幅 overlay 底部标签。

5. 分离 Lookbook：
   - 从 `ControlPanelView` 移除 Lookbook 按钮。
   - 在 `MainView` 顶部状态胶囊或独立轻量图标中提供 Lookbook 入口。
   - Lookbook 继续使用 sheet 或 NavigationStack 展示独立页面。
   - 删除、复制 Prompt、查看元数据等操作留在 Lookbook 页面内。

6. 处理安全区域：
   - 浮动按钮避开 Home Indicator。
   - 画幅 overlay 底部标签不要和浮动按钮、Home Indicator 重叠。
   - 横屏时 top status pill 和控制面板避免同时占据画面中心。

7. 真机验证：
   - 竖屏 Light 设置滚动是否顺畅。
   - 横屏 Frame 设置是否没有文字重叠。
   - 右下角按钮是否容易点击，且不挡主体构图。
   - Capture 在面板收起后是否仍能稳定触发。
   - Lookbook 入口是否清楚但不抢主视觉。
   - 上滑唤出是否与系统 Home Indicator 手势冲突。

## 四点六、多界面信息架构

### 目标

将 SceneZero 从单一 AR 工具整理为轻量的 AIGC 电影前制工作台，同时控制 Final Project 的实现范围。

### 界面结构

1. **Capture**
   - 当前 AR 主界面。
   - 负责放置 Subject / Prop / Light。
   - 负责 Frame / Lens 构图、打光预览、Capture 和 Prompt 生成。
   - 保持最轻，不承载历史管理和参考图搜索。

2. **Studio**
   - 用户个人工作区。
   - 包含 Lookbook。
   - 包含灵感夹 / 项目分区。
   - 可以用 Pinterest-like 瀑布流或网格展示历史截图和参考图。
   - 每个灵感夹保存图片、Prompt、Frame / Lens、Light 参数和备注。

3. **Explore** future work
   - 浏览和搜索已有电影场景图片作为参考灵感。
   - 可按电影名、镜头类型、色彩风格、光位、空间类型筛选。
   - 第一版不接入云端电影图库，最多使用本地 mock 数据或手动导入参考图。

### Final Project 建议范围

- 必做：Capture 主界面。
- 建议做：Studio / Lookbook 独立界面。
- 可选做：Lookbook 灵感夹分区。
- 不建议做：真实在线电影图库、账号系统、云端同步、素材市场。

### 实现步骤

1. 将 `LookbookView` 升级为 Studio 入口：
   - 顶部展示最近捕获。
   - 提供 All Captures。
   - 提供 Boards / 灵感夹列表。
2. 为 `LookbookEntry` 增加 board / collection 字段：
   - 默认 `All Captures`。
   - 可标记 Favorites。
   - 后续支持自定义 board 名称。
3. 创建简单 board UI：
   - Board 列表。
   - Board 详情网格。
   - 图片详情页继续展示 Prompt 和参数。
4. Explore 暂时只写入文档：
   - 如果时间充足，可以做本地静态参考图库。
   - 不引入服务器依赖。

### 验收标准

- Capture 与 Studio 入口清晰分离。
- 用户可以在 Studio 中查看历史截图。
- 用户可以按至少一个维度分组或筛选 Lookbook。
- Explore 被明确标注为未来扩展或静态 mock，不影响主演示链路。

## 四点七、内置 3D 模型资源方案

### 目标

让 Subject / Prop 不再只显示方块，提高电影场景预演的专业感，同时避免引入云端素材库和版权风险。

### 资产策略

1. **Primitive fallback**
   - 所有模型都必须有 RealityKit primitive fallback。
   - 模型加载失败时自动回退到 box / sphere / capsule。

2. **少量内置 USDZ**
   - Final Project 只内置少量通用白模资产。
   - 推荐资产：
     - Human / Mannequin。
     - Chair。
     - Table。
     - Sofa。
     - Lamp stand。
     - Prop box。
   - 动物、复杂角色、复杂室内家具作为 future work。

3. **不做云端素材库**
   - 不需要服务器。
   - 不做在线搜索和下载 3D 模型。
   - 不做用户账号和云同步。
   - 不做素材版权管理系统。

4. **可选本地导入**
   - 时间允许时支持从 Files 导入 `.usdz`。
   - 导入后保存在本地沙盒。
   - 失败时提示并回退 primitive。

### 数据模型建议

新增 Asset Preset 概念：

- `AssetCategory`: subject / prop / lightMarker。
- `AssetPreset`: block / human / chair / table / sofa / lampStand。
- `assetName`: 用于加载 bundle 中的 `.usdz`。
- `defaultScale`: 不同模型的默认缩放。
- `fallbackPrimitive`: 模型失败时使用的 primitive。

### 实现步骤

1. 创建 `AssetPreset` 模型。
2. 在工具面板中为 Subject / Prop 增加模型 preset 选择。
3. 把 `.usdz` 放入 app bundle。
4. 放置时优先加载 `ModelEntity.loadModel(named:)`。
5. 加载失败时使用当前 primitive。
6. 为所有模型生成 collision shapes。
7. 统一模型默认尺寸和地面高度。
8. 保存 Lookbook 时记录 asset preset。

### 验收标准

- Subject 至少支持 primitive 和 human preset。
- Prop 至少支持 box、chair/table/sofa 中的两个 preset。
- 模型加载失败不会导致 App 崩溃。
- 内置模型可以被 Capture 保存到截图中。
- Lookbook 元数据能记录所用资产类型。

## 四点八、AR 物体直接操控方案

### 目标

让 AR 搭场景更接近真实 iOS AR 工具，而不是只靠参数面板调节。

### 交互设计

- Tap 空地：放置当前工具。
- Tap 已有物体：选中物体。
- 单指拖拽：移动选中物体。
- 双指捏合：缩放选中物体。
- 双指旋转：调整 yaw。
- 面板 slider：保留为精细缩放。
- Light 的方向仍由 preset 控制，避免自由 3D 旋转过复杂。

### RealityKit 技术方案

1. 为可交互实体生成 collision shapes。
2. 使用 RealityKit 默认手势作为第一版：
   - `arView.installGestures([.translation, .rotation, .scale], for: entity)`
3. 后续如需更高控制，再自定义 gesture recognizer。
4. 对人物模型限制 pitch / roll，保持站立。
5. 对道具主要允许平面移动、yaw 旋转和等比缩放。
6. 对灯光允许移动位置，但方向继续由 Light Preset 决定。

### 数据同步要求

- 手势改变位置、旋转或缩放后，需要同步 `SceneObjectRecord`。
- 保存 Lookbook 时使用最新 transform，而不是初次放置时的 transform。
- 相对布光方案重载时使用更新后的相对坐标。

### 实现步骤

1. 在 `PlacedObject` 中保存 entity 与 record id。
2. Tap 命中实体时更新 selected object。
3. 安装 translation / rotation / scale gestures。
4. 手势结束后更新 records 中的位置、yaw 和 scale。
5. UI 面板显示当前选中物体类型和 scale。
6. 保留 reset scene 能清除所有手势对象。

### 验收标准

- 用户可以拖动 Subject / Prop 改变位置。
- 用户可以双指缩放 Subject / Prop。
- 用户可以旋转 Prop 的朝向。
- 交互后的 transform 能正确保存到 Lookbook。
- 物体不会明显漂浮或沉入地面。

## 五、阶段 1：AR 空间放置 MVP

### 目标

完成 AR 空间识别、raycast 放置、基础占位资产、Frame / Lens 构图辅助、虚拟灯光和屏幕空间光效预览。

### 建议任务

1. 实现平面检测与 raycast：
   - 用户点击屏幕时，在检测到的平面上放置主体占位符。
   - 主体占位符作为后续相对布光方案的局部原点。
2. 创建 RealityKit primitives 占位资产：
   - 人物：胶囊形或竖直圆柱。
   - 道具：不同尺寸 box。
   - 灯光：小 sphere + 方向锥体。
3. 加入少量内置 3D 模型 preset：
   - Subject 支持 primitive / human。
   - Prop 支持 box / chair / table / sofa 中的至少两个。
   - 模型加载失败时回退 primitive。
   - 每个 preset 定义默认 scale 和地面高度。
4. 实现 Frame / Lens 构图工具：
   - 将原 Camera 工具替换为 Frame / Lens 工具。
   - 提供画幅比例选择：16:9、2.39:1、1:1、9:16。
   - 提供构图线开关：三分线、安全框、中心十字。
   - 提供镜头语言选择：24mm、35mm、50mm、85mm。
   - Shot Type 改变时，实时构图参考框应产生可见变化。
5. 实现基础编辑：
   - 选中物体。
   - 拖拽移动位置。
   - 双指缩放。
   - 双指旋转 yaw。
   - 删除物体。
   - 面板滑杆保留为精确缩放。
6. 添加阴影接收平面：
   - 在检测到的水平面上放置低可见度平面。
   - 用于增强虚拟物体落地感。
7. 实现 RealityKit 虚拟灯光：
   - 添加 Light 时创建灯位标记。
   - 同时创建 `SpotLight` 或 `PointLight`。
   - 灯光颜色由色温档位转换得到。
   - 灯光强度由 Intensity 参数控制。
   - 灯光方向由预设光位映射为 `transform.rotation`。
8. 实现屏幕空间光效 overlay：
   - 使用 SwiftUI overlay 或 Canvas 绘制半透明光斑/光束。
   - overlay 颜色跟随色温。
   - overlay 透明度跟随 Intensity。
   - overlay 方向跟随 Light Preset。
   - overlay 仅作为视觉预览，不代表真实物理照明。
9. 实现灯光预设：
   - 左前 45° 主光。
   - 右后轮廓光。
   - 正前方柔光。
   - 顶部俯光。
   - 低位侧光。
10. 实现色温档位：
   - 3200K 暖光。
   - 4500K 中性光。
   - 5600K 日光。
   - 7000K 冷光。
11. 实现灯光强度控制：
   - 使用滑杆控制 Intensity。
   - 同时影响 RealityKit light intensity 和屏幕空间 overlay opacity。

### 验收标准

- 用户可以在真实空间中放置人物、道具和灯光占位物。
- 用户可以选择至少少量内置 3D 模型 preset，并在失败时回退 primitive。
- 用户可以通过拖拽、双指缩放和双指旋转直接调整 AR 物体。
- 用户可以在 AR 画面上切换画幅、构图线、镜头语言和 Shot Type，并看到可见的构图参考变化。
- 灯光方向通过预设选择完成，不需要自由 3D 旋转。
- RealityKit light 能明显影响虚拟物体亮度或颜色。
- 屏幕空间 overlay 能在现实画面上提供清晰的打光参考效果。
- 虚拟物体能稳定显示在检测平面上。

## 六、阶段 2：快照、构图遮罩、光效合成与拍摄后滤镜

### 目标

完成 `ARView.snapshot` 异步截图，把 Frame / Lens 构图遮罩和屏幕空间光效合成进静态图，并对静态图片应用 CoreImage 拍摄后滤镜。

### 建议任务

1. 实现 Capture 按钮：
   - Capture 不放在工具面板内部，而是作为独立主操作按钮常驻。
   - 面板收起后仍然可以点击 Capture。
   - 点击后设置 `isCapturing = true`。
   - 临时禁用 Capture 按钮，避免重复保存。
   - 可加入简单闪白或 loading 状态。
2. 使用 `ARView.snapshot` 获取静态图片：
   - 后续逻辑必须放在 snapshot completion 闭包内。
   - 快照失败时恢复 UI 状态并提示错误。
3. 实现 CoreImage 滤镜服务：
   - `FilterService`
   - 输入 `UIImage`。
   - 输出处理后的 `UIImage`。
4. 实现光效合成服务：
   - `LightingOverlayService` 或同等服务。
   - 输入原始快照、灯光预设、色温、强度、光斑半径。
   - 输出合成光斑/光束后的 `UIImage`。
   - 合成逻辑使用 CoreGraphics / CoreImage，在静态图上绘制径向渐变或方向性渐变。
5. 实现构图遮罩 / 裁切服务：
   - `FramingOverlayService` 或同等服务。
   - 输入原始快照、画幅比例、构图线开关、Shot Type、Lens 选项。
   - 输出带画幅遮罩/构图线或按画幅裁切后的 `UIImage`。
6. 调整保存流程：
   - `ARView.snapshot` 得到原始图。
   - 先应用 Frame / Lens 构图遮罩或裁切。
   - 再合成灯光 overlay。
   - 然后应用电影风格滤镜。
   - 最后写入沙盒目录并保存 SwiftData 元数据。
7. 第一版滤镜预设：
   - 低饱和写实。
   - 冷暖对冲。
   - 霓虹夜景。
   - 高反差黑金。
8. 保存处理后的图片：
   - 写入 Documents 或 Application Support 目录。
   - 文件名使用 UUID 或时间戳。
   - 返回相对路径或文件名供 SwiftData 保存。

### 验收标准

- 点击 Capture 后不会重复触发多次保存。
- 保存图能体现当前画幅比例、构图线或 Shot Type 视觉参考。
- 快照图片可以成功合成光斑/光束并应用滤镜。
- 保存到 Lookbook 的图片应接近实时预览中看到的打光效果。
- 处理后的图片能写入本地沙盒目录。

## 七、阶段 3：Studio / SwiftData 画廊与 Prompt 生成

### 目标

完成 Studio 工作区、Lookbook 画廊、本地持久化和确定性 Prompt 生成。

### 建议任务

1. 定义 SwiftData 模型：
   - 标题。
   - 创建时间。
   - 图片文件路径。
   - Prompt 文本。
   - 镜头类型。
   - Lens 选项。
   - 画幅比例。
   - 构图线开关。
   - Shot Type。
   - 主体位置描述。
   - 灯光方向预设。
   - 色温档位。
   - 灯光强度。
   - 光斑半径或扩散范围。
   - 滤镜名称。
   - Asset preset。
   - Board / collection 名称。
   - 物体相对坐标数据。
2. 避免图片二进制进入 SwiftData：
   - SwiftData 只保存路径。
   - 图片由文件服务读取。
3. 实现 Prompt 模板拼接：
   - `\(shotType), subject \(subjectPosition), \(keyLightDescription), \(colorStyle), \(locationDescription).`
   - 支持一键复制。
4. 实现 Lookbook 画廊：
   - Lookbook 作为独立界面，不放在参数调节面板中。
   - 主界面只保留轻量入口，例如顶部图标按钮或独立 sheet 入口。
   - 缩略图列表或网格。
   - 详情页展示图片、Prompt 和参数。
   - 删除记录时同步删除图片文件。
5. 实现 Studio / 灵感夹：
   - 提供 All Captures。
   - 提供 Favorites 或 Boards。
   - 支持至少一个默认 board。
   - 可选支持用户创建自定义 board。
6. 实现相对布光方案保存：
   - 主体占位符作为局部原点。
   - 其他物体保存相对位置、旋转、类型和参数。
   - Asset preset 需要一并保存。
   - Light 记录需要额外保存方向、色温、强度和 overlay 参数。
   - Frame / Lens 记录需要保存画幅比例、Lens、Shot Type 和构图线设置。
7. 实现相对布光方案重载：
   - 用户先在地面重新放置主体锚点。
   - 系统按相对坐标整体复现灯光与道具布局。
   - 系统恢复 RealityKit 虚拟灯光和屏幕空间 overlay 参数。

### 验收标准

- 画廊中可以看到历史截图。
- Studio 中可以按 All Captures / Board 查看内容。
- 详情页可以复制 Prompt。
- 重载历史记录时，不依赖旧 session 的绝对世界坐标。
- 历史记录能保留 Light 的方向、色温、强度和合成效果参数。
- 历史记录能保留 Frame / Lens 的画幅、镜头语言和构图线设置。
- 历史记录能保留 Asset preset。

## 八、阶段 4：演示与收尾

### 目标

让项目稳定适合课程演示和报告展示。

### 建议任务

1. 优化界面：
   - AR 主视图。
   - 轻量参数控制面板。
   - 固定高度滚动面板。
   - 右下角浮动收起入口。
   - 独立 Capture 主按钮。
   - 独立 Lookbook 页面入口。
   - Studio / 灵感夹入口。
   - 紧凑图标工具栏。
   - 横屏默认沉浸式取景。
   - 风格选择。
   - Capture 状态反馈。
2. 增加错误处理：
   - 相机权限未开启。
   - 平面尚未检测到。
   - 快照失败。
   - 图片写入失败。
   - 灯光 overlay 参数缺失或没有 Light 时的降级保存。
   - Frame / Lens 参数缺失时使用默认 16:9 wide shot。
3. 准备演示流程：
   - 打开 App。
   - 扫描平面。
   - 放置人物和道具。
   - 切换人物或道具模型 preset。
   - 拖拽、缩放、旋转道具。
   - 选择 Frame / Lens 设置，例如 2.39:1 + 35mm + Close-Up。
   - 添加灯光预设。
   - 调节灯光强度和色温。
   - 展示现实画面上的光斑/光束 overlay。
   - Capture。
   - 合成光效并应用滤镜。
   - 保存到 Lookbook。
   - 在 Studio / Board 中查看结果。
   - 复制 Prompt。
   - 重载相对布光方案。
4. 整理文档：
   - 每日开发日志。
   - 功能截图。
   - 已完成 / 未完成说明。
   - 技术边界说明。

### 验收标准

- App 可以完成一条完整演示链路。
- Frame / Lens 演示时需要明确说明：这是 AI 视觉参考与 Prompt 构图工具，不是专业相机变焦控制。
- 灯光演示时需要明确说明：现实画面上的打光是屏幕空间视觉模拟，虚拟物体受光来自 RealityKit light。
- 主要风险点在文档中已有解释。
- 演示失败时有可替代流程或截图材料。

## 九、推荐开发顺序

1. ARView 基础显示。
2. 平面检测与 raycast 放置。
3. primitives 占位资产。
4. 内置 3D 模型 preset 和 primitive fallback。
5. AR 物体手势交互：选中、拖拽、缩放、旋转。
6. 将 Camera 工具替换为 Frame / Lens 工具。
7. 实现画幅遮罩、构图线、Shot Type 可视化和 Lens 选项。
8. RealityKit 虚拟灯光、灯光预设、色温档位和强度控制。
9. 屏幕空间光斑/光束 overlay 实时预览。
10. 异步 Capture。
11. 静态截图构图遮罩/裁切合成。
12. 静态截图光效合成。
13. CoreImage 拍摄后滤镜。
14. 文件写入服务。
15. SwiftData 元数据模型。
16. Studio / Lookbook 画廊。
17. Prompt 模板拼接。
18. 相对布光方案保存与重载。
19. 分离 Capture 和 Lookbook：Capture 独立常驻，Lookbook 独立页面入口。
20. Apple 风格 UI polish：紧凑图标工具栏、固定高度滚动面板、右下角浮动入口、横竖屏 safe area 验证。
21. Explore 静态 mock 或未来扩展说明。
22. 演示准备。

## 十、每日开发日志建议

每天开发结束后，在 `dev_logs/` 中复制 `log_template.md`，并按日期命名，例如：

```text
2026-06-09.md
```

日志应重点记录：

- 今天完成了哪个功能。
- 改了哪些文件。
- 遇到了什么问题。
- 明天继续做什么。
- 当前是否有影响演示的风险。
