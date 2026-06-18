# SceneZero 具体开发步骤

本文档根据 `app_design.md` 拆分，用于后续正式开发时按阶段推进。第一版目标是完成一个稳定可演示的 AR 场景预演与 Prompt 生成 MVP。

## 一、开发原则

- 优先完成可演示闭环：AR 放置 → 参数调节 → 快照 → 拍摄后滤镜 → 本地保存 → Prompt 生成。
- 不实现实时 60fps 全局后处理、不做完整视频生成、不追求真实墙面物理打光。
- 第一版资产采用“内置轻量 `.usdz` + RealityKit primitives fallback”。当前已加入人物、椅子、桌子、沙发、书桌、书架、床、床头柜和灯架等模型；不做在线素材库。
- 图片文件写入 App 沙盒目录，SwiftData 只保存元数据和图片路径。
- 历史场景重载使用“主体锚点 + 相对坐标”，不做跨 session 精确 `ARWorldMap` 恢复。
- 灯光效果采用“三层模拟”方案：RealityKit light 影响虚拟物体，屏幕空间 overlay 预览现实画面上的光斑/光束，Capture 后把 overlay 合成到静态截图中。
- Camera 不作为空间中的虚拟摄影机模型实现。第一版改为 Frame / Lens 构图工具，用画幅遮罩、构图线、镜头类型和截图裁切/遮罩来辅助生成 AI 参考图。
- UI 优先贴近 Apple Human Interface Guidelines：AR 画面优先、控件轻量、层级清晰、使用系统控件和 SF Symbols、避免长期遮挡取景区域。
- 主界面不再使用长期占屏的 `ControlPanelView`。当前真实实现采用右侧 Apple Camera-style 控制列：中部 `Capture`、下方纵向模式选择、上方当前模式调节按钮。
- Capture 和 Lookbook 不属于参数调节工具。Capture 作为独立高频主操作按钮常驻在右侧中线；Lookbook 作为顶部轻量入口打开独立页面。
- 产品结构按多界面设计推进：Capture 负责 AR 采集，Studio 负责 Lookbook / 灵感夹 / 项目管理，Explore 作为未来电影参考图浏览与搜索界面。
- AR 物体交互已从“面板参数调节”升级为“直接操控”：支持 tap 选中、拖拽移动、双指缩放和双指旋转；Size 滑杆不进入主界面常驻控制。
- 内置模型交互已改为更贴近可见模型范围的 collision proxy，优先选中最近放置/最上层命中的对象，避免在离模型较远处误拖动其他物体。
- AR 放置优先使用水平面 raycast。USDZ 模型根据未缩放 `visualBounds` 做尺寸归一化和贴地修正，减少模型悬空或沉入地面的情况。
- `Subject Block` 已改为不透明哑光材质，避免半透明 block 在 AR 合成中产生不正常光晕。
- 取景框线代表最终输出边界，常驻显示且不提供关闭。Composition Guides 是构图辅助线，由顶部按钮开关，不影响最终裁切。
- Capture 保存的是稳定取景框内的裁切图，不保存全屏 AR 截图，也不保存右侧 UI 控件。
- 灯光 Prompt 和 Lookbook 元数据来自实际放置的 Light records。没有放置 Light 时不写入默认灯光参数；多灯时按灯光实例汇总。

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
   - Capture 时按稳定 Frame Line 裁切输出参考图，不把右侧 UI、Frame Line 或 Guides 写入最终图片。

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
   - `FramingOverlayView`
   - `LightingOverlayView`
   - `LookbookView`
3. 引入 RealityKit / ARKit 基础桥接：
   - 使用 `UIViewRepresentable` 包装 `ARView`。
   - 配置 `ARWorldTrackingConfiguration`。
   - 启用水平/垂直平面检测。

### 验收标准

- App 可以启动并显示 AR 摄像头画面。
- SwiftUI 页面结构清晰，不再只有默认的 `Hello, world!`。

## 四点五、Apple 风格主界面方案（当前真实实现）

### 目标

让 SceneZero 在横屏和竖屏下都保持“AR 画面优先”的取景体验，同时把高频创作参数收束到右侧相机式控制列。

### 当前 UI 结构

1. **顶部状态胶囊**
   - 左侧显示 AR 状态，例如 surface / capture / placement 状态。
   - 右侧提供 Lookbook 入口、Reset Scene 和 Composition Guides 开关。
   - 顶部不再提供泛用 `slider.horizontal.3` 高级参数面板入口。

2. **右侧常驻控制列**
   - 中部：白色圆形 `Capture` 快门按钮，固定在右侧垂直中线。
   - 下方：`Subject / Prop / Frame / Light` 纵向滑动模式选择器，固定选择位为透明描边。
   - 上方：当前模式的调节按钮列，按钮圆心与 Capture 和模式选择器对齐。
   - 调节按钮使用 44pt 触控目标和 SF Symbols，不再放在大面积控制面板中。

3. **按钮左侧内联参数胶囊**
   - 点击某个调节按钮后，在该按钮左侧展开一个临时胶囊栏。
   - `Asset / Frame / Lens / Shot / Filter / Direction / Color` 使用横向 chip picker。
   - `Intensity / Spread` 使用短滑杆。
   - 参数胶囊是短时操作层，可以临时覆盖取景框线，但不改变取景框位置和最终裁切。

4. **取景框与构图辅助**
   - Frame Line 常驻显示，代表最终 Lookbook 裁切边界，不提供关闭选项。
   - Composition Guides 是三分线、中心十字和安全框的辅助线，由顶部按钮开关。
   - Guides 不属于右侧 Frame 创作参数，也不影响最终裁切边界。

5. **Capture / Lookbook 分离**
   - Capture 是最高频主动作，常驻右侧中线。
   - Lookbook 是结果管理入口，放在顶部状态胶囊中，通过 sheet / NavigationStack 打开独立页面。
   - `ControlPanelView` 已移除，主界面不再保留备用大面板。

### 模式与调节按钮分工

- `Subject` 模式：
  - `Asset`：选择 Subject Block / Human。
  - `Reset`：重置当前选中 Subject 的 scale。
  - 缩放主要通过双指捏合完成，不提供常驻 Size 滑杆。
- `Prop` 模式：
  - `Asset`：选择 Prop Box / Chair / Table / Sofa / Desk / Bookcase / Bed / Night Stand。
  - `Reset`：重置当前选中 Prop 的 scale。
  - 移动、缩放、旋转通过 RealityKit 手势完成。
- `Frame` 模式：
  - `Frame`：选择 16:9 / 2.39:1 / 1:1 / 9:16。
  - `Lens`：选择 24mm / 35mm / 50mm / 85mm。
  - `Shot`：选择 Wide Shot / Medium Shot / Close-Up / Low Angle。
  - `Filter`：选择 Realistic / Teal Orange / Neon Night / Noir Gold。
- `Light` 模式：
  - `Direction`：选择 Key Left / Rim Right / Front Soft / Top / Low Side。
  - `Color`：选择 3200K / 4500K / 5600K / 7000K。
  - `Intensity`：短滑杆，影响 RealityKit light 和 overlay opacity。
  - `Spread`：短滑杆，影响 overlay 半径和 spot light angle。

### 当前实现状态

- 已移除 `ControlPanelView`。
- 已移除独立 `Look` 模式，Filter 合并进 Frame。
- 顶部按钮只负责 Composition Guides 显示开关。
- 右侧四个主模式保持稳定：`Subject / Prop / Frame / Light`。
- Capture 会先收起临时参数胶囊，再保存取景框裁切图。
- Lookbook 保存图不包含右侧 UI，不保存 frame line 或 guides。

### 真机验收标准

- 横屏和竖屏下右侧控制列不遮挡取景框主体区域。
- Capture、模式选择器、调节按钮列在右侧圆心对齐。
- 展开临时参数胶囊时取景框不跳动。
- Guides 顶部开关能正确显示/隐藏构图辅助线。
- Frame Line 始终稳定显示并代表最终裁切边界。
- Lookbook 保存图与屏幕取景框一致。

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
   - Final Project 只内置少量通用、轻量、静态资产。
   - 当前已内置：
     - `Human.usdz`：Quaternius Background Posed Humans Pack 的 `Female_Standing`，CC0。
     - `Chair.usdz`、`Table.usdz`、`Sofa.usdz`、`Desk.usdz`、`Bookcase.usdz`、`Bed.usdz`、`NightStand.usdz`：Quaternius Ultimate Furniture Pack，CC0。
     - `LampStand.usdz`：Kenney Furniture Kit，CC0。
   - 保留 `Subject Block` 和 `Prop Box` 作为程序生成 fallback / 快速占位资产。
   - 动画角色、高清贴图角色、复杂室内套装、在线素材搜索作为 future work。

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

已实现 Asset Preset 概念：

- `AssetCategory`: subject / prop / lightMarker。
- `AssetPreset`: subjectBlock / human / propBox / chair / table / sofa / desk / bookcase / bed / nightStand / lampStand。
- `bundleModelName`: 用于加载 bundle 中的 `.usdz`。
- `defaultScale`: 不同模型的默认缩放。
- `fallbackPrimitive`: 模型失败时使用的 primitive。
- `systemImage`: 对应右侧 asset chip 的 SF Symbols 图标。

### 实现步骤

1. 创建 `AssetPreset` 模型。已完成。
2. 在右侧 Apple Camera-style 控制列中为 Subject / Prop 增加 Asset preset 选择。已完成。
3. 新建资源目录：
   - 当前目录：`SceneZero/SceneZero/Assets3D/`。
   - 文件命名与 `AssetPreset.bundleModelName` 保持一致，例如 `Human.usdz`、`Chair.usdz`、`Table.usdz`、`Sofa.usdz`。
   - 当前已加入 9 个 `.usdz` 资源：Human、Chair、Table、Sofa、Desk、Bookcase、Bed、NightStand、LampStand。
4. 控制资产范围：
   - 优先选择低面数、白模、静态模型。
   - 单个 `.usdz` 尽量控制在 1-5 MB。
   - 不加入复杂动画、骨骼角色、高清贴图包或高面数家具。
   - 只使用自己制作、课程允许或明确可商用/可教学使用的模型。
   - 当前资源来源记录在 `SceneZero/SceneZero/Assets3D/README.md`。
5. 加入 bundle：
   - 将 `.usdz` 加入 Xcode target 的 Copy Bundle Resources。
   - 构建后确认 app bundle 中能找到模型文件。
6. 加载策略：
   - 放置时优先通过 bundle URL 加载 `.usdz` 模型。
   - 加载成功后根据 `visualBounds` 自动归一化尺寸。
   - 使用模型缩放前 bounds 计算贴地偏移，避免 scale 重复参与高度计算导致模型悬空。
   - 加载失败、文件缺失或碰撞体生成失败时，回退到当前 primitive / 几何组合模型。
7. 碰撞与手势：
   - 为 bundle 模型生成独立 collision proxy，而不是直接使用过大的递归碰撞体。
   - proxy 根据可见 bounds 设置大小和中心，提升 tap / drag 命中精度。
   - 确认真机上 tap 选中、拖拽、双指缩放和旋转仍然可用。
   - 如果模型原点不在底部，使用 `AssetPreset` 的地面高度 offset 和 bounds 对齐修正。
8. 元数据保存：
   - 保存 Lookbook 时继续记录 `assetPreset`，不保存 `.usdz` 二进制。
   - 相对布光方案重载时，根据 `assetPreset` 再次加载对应 bundle 模型。
9. 转换工具：
   - 当前使用 `tools/obj_to_usdz.py` 将简单 OBJ / MTL 转为 USDZ。
   - 打包 USDZ 时保留 ZIP extra fields，不使用 `zip -X`，避免破坏 USDZ 64-byte alignment。
   - Apple 官方 `realitytool` 当前主要用于 Reality Composer Pro 资产编译，不作为本项目通用 OBJ/FBX 转 USDZ 工具。
10. 不做的内容：
   - 不做在线素材库。
   - 不做运行时下载模型。
   - 不做账号、云同步或素材版权管理系统。
   - 不在第一版支持任意复杂模型编辑。

### 验收标准

- Subject 支持 `Subject Block` 和 `Human` preset。
- Prop 支持 `Prop Box / Chair / Table / Sofa / Desk / Bookcase / Bed / Night Stand` preset。
- Light 支持 `Lamp Stand` preset / fallback。
- 模型加载失败不会导致 App 崩溃。
- 内置模型可以被 Capture 保存到截图中。
- Lookbook 元数据能记录所用资产类型。
- 删除或重命名 `.usdz` 后，App 仍能使用 primitive fallback 完成演示。
- 真机上加载 `.usdz` 后，交互手势与截图保存仍然稳定。
- Tap / drag 命中范围应贴近可见模型，不能在明显远离模型的位置误拖动物体。
- 模型应基本贴合水平检测面，不应明显悬空。

## 四点八、AR 物体直接操控方案

### 目标

让 AR 搭场景更接近真实 iOS AR 工具，而不是只靠参数面板调节。

### 交互设计

- Tap 空地：放置当前工具。
- Tap 已有物体：选中物体。
- 单指拖拽：移动选中物体。
- 双指捏合：缩放选中物体。
- 双指旋转：调整 yaw。
- Size slider 不进入主界面常驻调节；缩放以双指捏合为主，必要时后续放入高级设置。
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
6. 底部调节按钮提供 Reset，必要时重置当前选中物体的 scale 或 transform。
7. 保留 reset scene 能清除所有手势对象。

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
   - 用户点击屏幕时，在检测到的水平平面上放置主体、道具或灯光标记。
   - 找不到水平面时提示 `Find a horizontal surface`。
   - 主体占位符作为后续相对布光方案的局部原点。
2. 创建 RealityKit primitives 占位资产：
   - 人物：胶囊形或竖直圆柱。
   - 道具：不同尺寸 box。
   - 灯光：小 sphere + 方向锥体。
3. 加入少量内置 3D 模型 preset：
   - Subject 支持 primitive / human。
   - Prop 支持 box / chair / table / sofa / desk / bookcase / bed / night stand。
   - Light 支持 lamp stand。
   - 模型加载失败时回退 primitive。
   - 每个 preset 定义默认 scale、proxy size、地面高度和图标。
   - Bundle 模型使用 `visualBounds` 自动缩放并对齐地面。
4. 实现 Frame / Lens 构图工具：
   - 将原 Camera 工具替换为 Frame / Lens 工具。
   - 提供画幅比例选择：16:9、2.39:1、1:1、9:16。
   - Frame Line 常驻显示，代表最终裁切边界。
   - 提供顶部 Composition Guides 开关：三分线、安全框、中心十字。
   - 提供镜头语言选择：24mm、35mm、50mm、85mm。
   - Shot Type 改变时，实时构图参考框应产生可见变化。
   - Filter 合并在 Frame 模式下，作为最终参考图视觉风格参数。
5. 实现基础编辑：
   - 选中物体。
   - 拖拽移动位置。
   - 双指缩放。
   - 双指旋转 yaw。
   - 删除物体。
   - 使用贴近模型可见 bounds 的 collision proxy，减少误选中和远距离拖拽。
   - Subject / Prop 主界面不保留 Size 滑杆，缩放通过双指捏合完成。
   - Subject / Prop 的底部调节按钮保留 Asset 和 Reset。
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
- 用户可以选择内置 3D 模型 preset，并在失败时回退 primitive。
- 人物、家具和灯架模型能正常显示，且默认比例适合 AR 勘景。
- 用户可以通过拖拽、双指缩放和双指旋转直接调整 AR 物体。
- 用户需要直接命中模型附近才能选中/拖动，不应在明显远离模型处误触。
- 用户可以在 AR 画面上切换画幅、镜头语言、Shot Type 和 Filter，并看到可见的构图或视觉风格变化。
- 用户可以通过顶部按钮开关 Composition Guides，但 Frame Line 始终稳定显示。
- 灯光方向通过预设选择完成，不需要自由 3D 旋转。
- RealityKit light 能明显影响虚拟物体亮度或颜色。
- 屏幕空间 overlay 能在现实画面上提供清晰的打光参考效果。
- 虚拟物体能稳定显示在检测平面上。
- 模型底部应基本贴合水平面，不能明显悬空。

## 六、阶段 2：快照、构图遮罩、光效合成与拍摄后滤镜

### 目标

完成 `ARView.snapshot` 异步截图，把实时画面裁切到稳定取景框范围，再合成屏幕空间光效并应用 CoreImage 拍摄后滤镜。

### 建议任务

1. 实现 Capture 按钮：
   - Capture 不放在工具面板内部，而是作为右侧常驻主操作按钮。
   - 点击后设置 `isCapturing = true`。
   - 临时禁用 Capture 按钮，避免重复保存。
   - 可加入简单闪白或 loading 状态。
   - 点击 Capture 前先收起临时参数胶囊，避免操作态 UI 影响用户判断。
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
   - 输入原始快照、画幅比例、Shot Type、Lens 选项和主界面 `FramingSafeInsets`。
   - 输出按稳定取景框裁切后的 `UIImage`。
   - Lookbook 保存图默认不保留 frame line 或 guides，只保存干净参考图。
6. 调整保存流程：
   - `ARView.snapshot` 得到原始图。
   - 先按 Frame / Lens 取景框裁切。
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
- 保存图能体现当前画幅比例、Shot Type、Lens 和 Filter。
- 保存图范围应与屏幕上的 Frame Line 对应，不包含右侧 UI。
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
   - Composition Guides 开关。
   - Shot Type。
   - 主体位置描述。
   - 灯光实例汇总。
   - 多灯光 records 中保存每盏灯的方向、色温、强度和光斑半径。
   - 滤镜名称。
   - Asset preset。
   - Board / collection 名称。
   - 物体相对坐标数据。
2. 避免图片二进制进入 SwiftData：
   - SwiftData 只保存路径。
   - 图片由文件服务读取。
3. 实现 Prompt 模板拼接：
   - `\(shotType), subject \(subjectPosition), \(keyLightDescription), \(colorStyle), \(locationDescription).`
   - 灯光描述来自实际放置的 Light records，不来自当前默认 UI 参数。
   - 没有放置 Light 时使用 natural ambient lighting。
   - 多灯时生成 multi-light cinematic setup 汇总。
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
   - Frame / Lens 记录需要保存画幅比例、Lens、Shot Type 和 Filter。
7. 实现相对布光方案重载：
   - 用户先在地面重新放置主体锚点。
   - 系统按相对坐标整体复现灯光与道具布局。
   - 系统恢复 RealityKit 虚拟灯光和屏幕空间 overlay 参数。

### 验收标准

- 画廊中可以看到历史截图。
- Studio 中可以按 All Captures / Board 查看内容。
- 详情页可以复制 Prompt。
- 重载历史记录时，不依赖旧 session 的绝对世界坐标。
- 历史记录能保留每盏 Light 的方向、色温、强度和合成效果参数。
- 历史记录能保留 Frame / Lens 的画幅、镜头语言、Shot Type 和 Filter。
- 历史记录能保留 Asset preset。

## 八、阶段 4：演示与收尾

### 目标

让项目稳定适合课程演示和报告展示。

### 建议任务

1. 优化界面：
   - AR 主视图。
   - Apple Camera-style 右侧控制列。
   - 右侧中线白色圆形 Capture 主按钮。
   - 下方纵向模式选择：Subject / Prop / Frame / Light。
   - 上方当前模式调节按钮。
   - 按钮左侧内联参数胶囊：chip picker、短滑杆。
   - 顶部 Composition Guides 开关。
   - 独立 Lookbook 页面入口。
   - Studio / 灵感夹入口。
   - 横屏默认沉浸式取景。
   - Filter 合并在 Frame 模式内。
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
   - 通过右侧纵向模式选择切到 Subject / Prop。
   - 通过上方 Asset 调节按钮切换 `Subject Block / Human` 或家具道具模型 preset。
   - 放置人物、椅子/桌子/沙发/书桌/床等道具。
   - 拖拽、缩放、旋转道具。
   - 演示模型贴地和精确选中：只有直接点到模型附近才会操作对应物体。
   - 切到 Frame，通过 Frame / Lens / Shot / Filter 调节按钮选择 2.39:1 + 35mm + Close-Up + Realistic/Teal Orange。
   - 通过顶部 Guides 按钮演示构图辅助线开关。
   - 切到 Light，添加灯光预设。
   - 通过 Direction / Color / Intensity / Spread 调节按钮控制灯光。
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
5. 资源转换链路：OBJ / MTL 转 USDZ、Copy Bundle Resources、资源 README 记录来源和授权。
6. AR 物体手势交互：选中、拖拽、缩放、旋转。
7. Bundle 模型贴地、尺寸归一化、精确 collision proxy 和水平面 raycast 修复。
8. 将 Camera 工具替换为 Frame / Lens 工具。
9. 实现画幅遮罩、构图线、Shot Type 可视化和 Lens 选项。
10. RealityKit 虚拟灯光、灯光预设、色温档位和强度控制。
11. 屏幕空间光斑/光束 overlay 实时预览。
12. 异步 Capture。
13. 静态截图构图遮罩/裁切合成。
14. 静态截图光效合成。
15. CoreImage 拍摄后滤镜。
16. 文件写入服务。
17. SwiftData 元数据模型。
18. Studio / Lookbook 画廊。
19. Prompt 模板拼接。
20. 相对布光方案保存与重载。
21. 分离 Capture 和 Lookbook：Capture 独立常驻，Lookbook 独立页面入口。
22. Apple Camera-style 右侧控制列：右侧中线 shutter、下方纵向模式选择、上方当前模式调节按钮。
23. 将 Subject / Prop 的 Size 滑杆从主界面移除，保留手势缩放和 Reset。
24. 将 Shot 和 Filter 合并进 Frame 调节组，将 Guides 作为顶部显示辅助开关。
25. Apple 风格 UI polish：轻量浮层、固定选择位、横竖屏 safe area 验证。
26. Explore 静态 mock 或未来扩展说明。
27. 演示准备。

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
