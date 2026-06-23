# SceneZero 零境

AR scene previsualization and structured prompt generation for AI filmmaking.

SceneZero is an iOS AR app that helps creators build lightweight cinematic references in real spaces. Instead of writing prompts from scratch, users can place subjects, props, and light markers in an AR camera view, adjust frame / lens / lighting / color style, capture a reference image, and save it with a structured AI video prompt.

> Course final project for Mobile Platform Technology Development.

## What It Does

SceneZero focuses on the upstream stage of AI filmmaking: turning real locations into reusable visual reference packages.

- Place virtual subjects, furniture props, and abstract light markers in real space.
- Adjust cinematic frame ratios, lens language, shot type, lighting, and color style.
- Capture a framed AR reference image.
- Generate a deterministic structured prompt from the scene parameters.
- Save references into local Lookbook boards.
- Reorder captures by scene order, export images, and copy prompts.

## Core Features

### AR Capture

- ARKit plane detection and horizontal raycast placement.
- RealityKit-based 3D object rendering.
- Tap to select placed objects.
- Drag, pinch, and rotate direct manipulation.
- Contextual delete button for the selected object.
- Lightweight bundled USDZ models with primitive fallback.

Supported presets include:

- Subject: `Subject Block`, `Human`
- Props: `Prop Box`, `Chair`, `Table`, `Sofa`, `Desk`, `Bookcase`, `Bed`, `Night Stand`
- Light: abstract `Light Marker` instead of a realistic lamp model

### Frame, Lens, and Look Controls

- Frame ratios: `16:9`, `2.39:1`, `1:1`, `9:16`
- Lens presets: `24mm`, `35mm`, `50mm`, `85mm`
- Shot types: wide, medium, close-up, low angle
- Composition guides: rule of thirds, safe frame, center reference
- Film looks: realistic, teal-orange, neon night, noir gold

### Lighting System

SceneZero separates lighting into stable preview and optional model lighting:

- `Light Marker`: a small abstract AR marker used for placement and interaction.
- `Lighting Overlay`: a SwiftUI screen-space light preview that shows color, intensity, direction, and spread.
- `3D Model Lighting`: an optional Profile setting that enables RealityKit `SpotLight` preview on virtual models.

This design keeps the default capture workflow stable while still allowing virtual model lighting preview when needed.

### Lookbook

- Bottom-tab Lookbook interface.
- Built-in `All Captures` and `Favorites`.
- Create and rename custom boards.
- Save a capture into an existing or new board.
- Arrange captures inside custom boards.
- View image, prompt, and metadata.
- Copy prompt with confirmation feedback.
- Export image with the system share sheet.

### Profile / Workspace

- Local-only profile page.
- Capture, board, and favorite counts.
- Workspace settings, including `3D Model Lighting`.

## Technical Architecture

```text
SwiftUI UI Layer
Capture / Lookbook / Profile
        ↓
AR Layer
ARKit + RealityKit + Direct Manipulation
        ↓
Service Layer
Framing / Lighting Overlay / Filter / Prompt / Image Storage
        ↓
Data Layer
SwiftData Metadata + Local PNG Files
```

Key implementation choices:

- `ARSceneController` owns AR placement, selection, gestures, and scene records.
- `SceneObjectRecord` stores object type, relative position, scale, yaw, and light parameters.
- `FramingOverlayService` crops snapshots to the visible frame line.
- `LightingOverlayService` composites the screen-space light preview into saved captures.
- `FilterService` applies CoreImage-based film looks.
- `PromptService` generates deterministic prompts from scene metadata.
- `ImageStorageService` saves PNG images into the app sandbox.
- SwiftData stores Lookbook metadata, not large image binaries.

## Capture Pipeline

```text
Capture Button
   ↓
ARView.snapshot
   ↓
Frame Crop
   ↓
Lighting Overlay Composite
   ↓
CoreImage Filter
   ↓
PNG Save
   ↓
Prompt Generation
   ↓
Save Reference Sheet
   ↓
SwiftData LookbookEntry
```

## Project Structure

```text
SceneZero/
├── SceneZero.xcodeproj
├── SceneZero/
│   ├── AR/
│   │   ├── ARSceneController.swift
│   │   └── ARViewContainer.swift
│   ├── Models/
│   │   └── SceneModels.swift
│   ├── Services/
│   │   ├── FilterService.swift
│   │   ├── FramingOverlayService.swift
│   │   ├── ImageStorageService.swift
│   │   ├── LightingOverlayService.swift
│   │   └── PromptService.swift
│   ├── Views/
│   │   ├── MainView.swift
│   │   ├── LookbookView.swift
│   │   ├── ProfileView.swift
│   │   ├── RootTabView.swift
│   │   ├── FramingOverlayView.swift
│   │   ├── LightingOverlayView.swift
│   │   └── LiquidGlassStyle.swift
│   ├── Assets3D/
│   └── Assets.xcassets/
├── app_design.md
└── development_steps.md
```

## Requirements

- Xcode
- iOS / iPadOS device with ARKit support
- iOS deployment target: `18.2`
- Camera permission

The app can build for simulator, but AR placement should be tested on a real device.

## How to Run

1. Clone the repository.

   ```bash
   git clone <repo-url>
   cd <repo-folder>
   ```

2. Open the Xcode project.

   ```bash
   open SceneZero/SceneZero.xcodeproj
   ```

3. Select a real iPhone or iPad target.

4. Build and run.

5. Grant camera permission when prompted.

Command-line build:

```bash
xcodebuild -project SceneZero/SceneZero.xcodeproj \
  -scheme SceneZero \
  -sdk iphonesimulator \
  -derivedDataPath /tmp/SceneZeroDerivedData build
```

## Usage Flow

1. Open the app. It starts on the `Capture` tab.
2. Move the device to detect a horizontal surface.
3. Choose `Subject`, `Prop`, or `Light`.
4. Tap the scene to place an object.
5. Tap an object to select it.
6. Drag, pinch, rotate, reset, or delete the selected object.
7. Adjust `Frame`, `Lens`, `Shot`, `Filter`, and `Light` settings.
8. Tap the shutter button.
9. Name the reference, choose or create a Lookbook, and save.
10. Open `Lookbook` to view, reorder, export, or copy prompts.

## Known Design Constraints

- SceneZero does not generate final videos.
- It does not call external LLM or AI video APIs in the current version.
- Lens presets are prompt / composition language, not optical camera zoom controls.
- RealityKit lights cannot physically illuminate real camera pixels.
- `Lighting Overlay` is the default stable light preview.
- `3D Model Lighting` is optional because RealityKit dynamic lights can reduce stability on some devices.

## 3D Asset Credits

Bundled assets are lightweight static USDZ models.

- `Human.usdz`: converted from Quaternius Background Posed Humans Pack, CC0.
- `Chair.usdz`, `Table.usdz`, `Sofa.usdz`, `Desk.usdz`, `Bookcase.usdz`, `Bed.usdz`, `NightStand.usdz`: converted from Quaternius Ultimate Furniture Pack, CC0.
- `LampStand.usdz`: historical Kenney Furniture Kit asset, CC0. It is retained in the repository but no longer used as the default Light visual.

See [`SceneZero/SceneZero/Assets3D/README.md`](SceneZero/SceneZero/Assets3D/README.md) for asset notes.

## Documentation

- [`app_design.md`](app_design.md): product design and feature specification.
- [`development_steps.md`](development_steps.md): implementation plan and technical notes.
- `dev_logs/`: development logs and iteration notes.

## License

This repository is a course project. Please check third-party asset licenses before reusing bundled 3D models outside this project.
