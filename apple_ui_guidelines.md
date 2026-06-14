# SceneZero Apple UI Guidelines

This document defines the local UI rules for SceneZero. It is not a replacement for Apple's Human Interface Guidelines; it is a project-specific checklist for keeping the app closer to native iOS interaction and visual language.

## 1. Product UI Direction

SceneZero should feel like a lightweight Apple-style creative tool, not a dashboard.

- The AR camera view is the primary surface.
- UI overlays should be temporary, compact, and easy to dismiss.
- Main creative actions should remain available even when parameter controls are hidden.
- Avoid large explanatory panels during capture.
- Prefer system controls, SF Symbols, Material backgrounds, and predictable iOS navigation.

## 2. App Structure

SceneZero should evolve toward a multi-screen app:

1. **Capture**
   - AR preview.
   - Frame / Lens overlay.
   - Subject / Prop / Light placement.
   - Independent capture shutter.
   - Minimal floating controls.

2. **Studio**
   - Profile-like workspace.
   - Lookbook.
   - Inspiration boards.
   - Saved prompts and captured scene metadata.
   - Asset presets used in captured scenes.

3. **Explore** later
   - Film scene references.
   - Search and filters.
   - Save reference images into boards.
   - Local mock content is preferred for the course version.

For the course version, prioritize Capture and a basic Studio / Lookbook page. Explore can remain future work.

## 2.1 Scope Rules For Multi-Screen Design

Course version:

- Capture screen must be reliable.
- Studio can be simple but should feel independent from Capture.
- Lookbook can live inside Studio.
- Boards can start with All Captures and Favorites.
- Explore can be documented or mocked with local images.

Future product:

- Explore can support film-reference search.
- Studio can support project folders and Pinterest-like boards.
- Cloud sync, account systems, and online asset libraries are future work.

## 3. Capture Screen Rules

The Capture screen should behave closer to Camera / Measure / Clips-style iOS tools:

- Keep the camera image visible.
- Use floating controls instead of full-width command panels.
- Hide parameter controls by default in landscape.
- Allow users to reopen controls from a bottom-right floating tool button.
- Keep Capture available when controls are hidden.
- Avoid placing important controls over the Home Indicator.
- Avoid blocking the center of the frame, where subjects usually appear.

## 4. Capture Button

Capture is the primary action and should not live inside the parameter panel.

Preferred design:

- Use a dedicated shutter-style control.
- Portrait: bottom center or lower safe-area position.
- Landscape: right side or lower-right area, depending on frame overlay and Home Indicator.
- Use a circular shutter visual rather than a rectangular text button.
- Suggested visual:
  - Outer translucent or white ring.
  - Inner filled circle.
  - Temporary progress / disabled state while capturing.
- Use `camera.fill` only if a custom shutter visual is not yet implemented.

Rules:

- Capture must remain usable when the tool panel is hidden.
- Disable repeated taps while `isCapturing` is true.
- Provide immediate feedback: flash, haptic, spinner, or button state.
- Do not combine Capture with Lookbook in a shared action bar.
- Avoid blue rectangular Capture buttons; they feel like generic form actions rather than a camera shutter.

## 5. Tool Panel

The tool panel is for parameters only.

It may include:

- Tool selection: Subject / Prop / Frame / Light.
- Object size.
- Frame / Lens settings.
- Light direction, color, intensity, spread.
- Shot and Look settings.

It should not include:

- Capture.
- Lookbook.
- Long help text.
- Page-level navigation.

Layout rules:

- Fixed height.
- Internal vertical scrolling for overflow.
- Header fixed.
- No `More / Less` state.
- Compact in landscape.
- Slightly taller in portrait, but never close to full-screen.
- Use `.regularMaterial` or `.ultraThinMaterial`.
- Keep corner radius moderate, around 16-18pt.

Current target heights:

- Landscape: around 190-220pt.
- Portrait: around 280-320pt.

## 6. Tool Selection

Subject / Prop / Frame / Light should feel like a compact toolbar, not cards.

Preferred design:

- 44-48pt touch targets.
- SF Symbols first.
- Text labels optional.
- Current selected tool name appears in the parameter title area.
- Selected state uses tint or capsule background.

Avoid:

- Large rectangular cards.
- Repeating tool names in multiple places.
- Tool buttons taller than needed.

Accessibility:

- Keep full VoiceOver labels: "Select Subject", "Select Prop", etc.
- Do not rely only on color to communicate selection.

Collapsed capture-mode behavior:

- When the parameter panel is hidden, show only the current tool icon.
- Tapping the current tool icon opens the parameter panel.
- Dragging / sliding from the current tool icon can reveal the other tool icons.
- Releasing the drag collapses the selector back to one icon.
- This interaction should feel closer to Apple Camera's mode picker than to a dashboard menu.
- Preferred Camera-style variant: keep a fixed selection position and let tool icons slide underneath it. The tool under the fixed selection position becomes selected.
- Place tool selection beside the shutter button when possible, so Capture and mode selection form one camera-style control cluster.

## 7. Lookbook / Studio

Lookbook is not a tool-panel action. It belongs to Studio or a dedicated page.

For the course version:

- A top-bar icon is acceptable.
- A sheet is acceptable if the page is clearly independent.
- The Lookbook page should show captures, prompts, and metadata.

Future Studio direction:

- Profile-like workspace.
- Boards / inspiration folders.
- Pinterest-like masonry grid.
- Saved prompt collections.
- Project-based grouping.

Studio UI rules:

- Do not reuse the AR capture control panel style.
- Use standard NavigationStack / sheet patterns.
- Boards should feel like collections, not settings.
- Captured images should be the visual focus.
- Metadata should be visible in detail pages, not crowded into grid cells.

## 7.1 Explore

Explore is a future reference-browsing surface.

Course-friendly version:

- Use local mock reference images if implemented.
- Provide simple filters such as Shot, Color, Light, Space.
- Let users save a reference into a Studio board.

Avoid for Final Project:

- Online scraping.
- Copyright-sensitive large film datasets.
- User accounts.
- Cloud backend.
- Remote 3D model marketplace.

## 8. Floating Buttons

Floating buttons should be sparse and purposeful.

Possible floating controls:

- Tool panel opener: bottom-right, `slider.horizontal.3`.
- Capture shutter: bottom center in portrait, right/lower-right in landscape.
- Lookbook / Studio: top bar icon or separate tab.

Rules:

- Maintain at least 16-24pt from screen edges and safe areas.
- Avoid overlapping Home Indicator.
- Avoid overlapping frame labels.
- Avoid placing multiple same-weight buttons in the same corner.
- Use `.ultraThinMaterial` for secondary floating tools.
- Use more prominent styling only for Capture.

## 9. Frame / Lens Overlay

Frame / Lens should support composition without overwhelming the camera image.

Rules:

- Lines should be thin and semi-transparent.
- Mask opacity should not hide too much of the real scene.
- Bottom labels must not overlap the Capture button, Home Indicator, or floating tool button.
- The overlay should remain visible when the tool panel is hidden.
- Saved images should match the live preview.

## 10. Typography

Use system typography.

- Prefer `.caption`, `.footnote`, `.subheadline`, `.headline`.
- Avoid large headings inside compact panels.
- Avoid negative tracking.
- Keep row labels short: Frame, Lens, Shot, Look, Color.
- Use monospaced digits only for numeric values like percentages.

## 11. Color And Materials

Use Apple-like restraint.

- Prefer system colors: `.primary`, `.secondary`, `.accentColor`.
- Use Material backgrounds for overlays.
- Avoid saturated decorative gradients.
- Avoid one-note dark blue / purple palettes.
- Use tint only for selected states and primary actions.
- Keep AR overlays subtle enough that the real scene is still readable.

## 12. Interaction Rules

AR interaction should feel direct.

Near-term goals:

- Tap to place.
- Tap to select.
- Drag to move selected object.
- Pinch to scale selected object.
- Rotate gesture to adjust yaw.

Panel controls can remain for precision:

- Size slider.
- Light intensity.
- Light spread.
- Frame / Lens pickers.

When gestures change an object:

- Update saved scene records.
- Keep object scale and transform consistent with Lookbook metadata.
- Preserve fallback behavior if a gesture fails.

## 12.1 Built-In Asset Presets

Subject and Prop should not be limited to boxes.

Course-friendly asset strategy:

- Keep primitive fallback for every asset.
- Add a small number of bundled `.usdz` assets.
- Recommended presets:
  - Human / mannequin.
  - Chair.
  - Table.
  - Sofa.
  - Lamp stand.
  - Prop box.
- Avoid cloud asset libraries for the course version.
- Avoid large or copyright-unclear model packs.

Asset UI rules:

- Let Subject / Prop expose an asset preset picker only when that tool is selected.
- Use short names: Human, Chair, Table, Sofa.
- Show failed model loads as fallback primitives with a lightweight warning.
- Store asset preset metadata in captured records.
- Keep scale defaults per preset so objects appear at usable size.

## 12.2 AR Gesture Rules

Direct manipulation should complement panel controls.

Near-term implementation:

- Tap placed object to select.
- Drag selected object to move.
- Pinch selected object to scale.
- Rotate selected object to adjust yaw.
- Keep panel size slider for precision.

RealityKit implementation notes:

- Generate collision shapes for all interactive entities.
- Use `arView.installGestures([.translation, .rotation, .scale], for: entity)` for the first version.
- Keep human models upright.
- Let props rotate around yaw only when possible.
- Keep Light direction preset-driven even if the light marker can move.

Persistence rules:

- Gestures must update saved transform records.
- Lookbook should save latest position, scale, yaw, and asset preset.
- Reloaded scenes should restore relative transforms, not original absolute AR coordinates.

## 13. Orientation Rules

Portrait:

- Show parameter panel by default.
- Capture near bottom center.
- Tool opener hidden unless panel is collapsed.

Landscape:

- Hide parameter panel by default.
- Show bottom-right tool opener.
- Use compact Capture.
- Keep the frame center clear.

## 14. Implementation Checklist

Before considering an UI iteration complete:

- Build passes with `xcodebuild`.
- Portrait has no overlapping text.
- Landscape has no overlapping text.
- Capture remains usable when panel is hidden.
- Lookbook is reachable without opening the parameter panel.
- Tool panel can be opened and hidden quickly.
- Floating buttons avoid Home Indicator.
- Frame overlay labels do not collide with buttons.
- VoiceOver labels exist for icon-only controls.
- The UI still supports the full demo flow.

## 15. Near-Term UI Tasks

Recommended next steps:

1. Replace the current rectangular Capture button with a shutter-style circular control.
2. Fine-tune Capture and tool opener positions in portrait and landscape.
3. Move Lookbook toward a Studio page or clearer independent sheet.
4. Add boards / inspiration folders to Lookbook.
5. Test object manipulation gestures with RealityKit.
6. Consider a compact toolbar-only mode for landscape.
7. Add bundled asset presets with primitive fallback.
8. Document Explore as future work or implement only local mock references.
