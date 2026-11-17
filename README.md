# Mat: Photo Widget Maker — Architecture & Implementation Guide

This project breaks down how **Mat: Photo Widget Maker** (App Store ID: `id6778914750` by Rahul Bhadauriya) works, provides technical evidence of its core engines, and supplies a production-ready implementation for your project.

---

## 1. How the MAT App Works (Evidence & Anatomy)

### Core User Loop:
1. **Camera / Photo Ingestion:** The user captures a photo or picks one from their library.
2. **Instant On-Device Cutout ("Subject Lifting"):** The subject (person, pet, cup, plant, object) is isolated from its background in real time without any cloud upload.
3. **Mat Customization Canvas:** Cutouts, letters, sticky notes, emojis, and polaroids are arranged onto a customizable virtual mat with simultaneous drag, pinch-to-scale, and rotation gestures.
4. **WidgetKit Synchronization:** The mat configuration and cutout PNGs are stored in a shared App Group container (`group.com.yourcompany...`).
5. **Home Screen Widget:** A WidgetKit extension renders the collage onto the iOS home screen across Small, Medium, and Large widget families.

---

## 2. Technical Evidence & Native APIs

| Feature | Underlying Apple API | Why / Evidence |
| :--- | :--- | :--- |
| **Instant Subject Lifting** | `VNGenerateForegroundInstanceMaskRequest` (Vision Framework) | Introduced in iOS 17+. Replaces the older person-only segmentation with a class-agnostic model powered by Apple Neural Engine (ANE). It can segment pets, objects, drinks, and food with `.generateMaskedImage(ofInstances:from:croppedToInstancesExtent:)`. |
| **Alternative Interactive UI** | `ImageAnalysisInteraction` (VisionKit) | Provides Apple Photos' native long-press "glow & lift" interaction directly attached to image views. |
| **Widget Rendering** | `WidgetKit` + `TimelineProvider` | Renders SwiftUI views in an isolated widget extension process using shared App Group storage. |
| **Multi-Touch Gestures** | SwiftUI `DragGesture`, `MagnificationGesture`, `RotationGesture` | Uses `.simultaneousGesture()` to allow seamless manipulation of collage stickers. |
| **Shared Storage** | `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)` | Widgets cannot access the main app's sandbox. Cutout PNGs and `MatBoard.json` must be saved in the App Group container. |

---

## 3. Included Implementation Files

The full implementation has been generated directly in your workspace:

* [SubjectLifter.swift](file:///c:/REA%20MAT/ios/SubjectLifter.swift): Native Swift class leveraging Vision's `VNGenerateForegroundInstanceMaskRequest` to crop and extract transparent subject cutouts.
* [MatCoreModels.swift](file:///c:/REA%20MAT/ios/MatCoreModels.swift): Data models (`MatBoard`, `MatItem`, `MatItemType`) and `MatStorageService` with atomic App Group persistence.
* [MatEditorView.swift](file:///c:/REA%20MAT/ios/MatEditorView.swift): SwiftUI drag-and-drop editor canvas supporting simultaneous pan, rotation, and scaling gestures.
* [MatWidgetView.swift](file:///c:/REA%20MAT/ios/MatWidgetView.swift): Complete WidgetKit extension bundle (`MatPhotoWidget`, `TimelineProvider`, and canvas renderer).
* [web-demo/index.html](file:///c:/REA%20MAT/web-demo/index.html): Interactive browser prototype showcasing the collage editor, drag-and-drop mechanics, rotation controls, and widget simulation.

---

## 4. How to Integrate Into Your Xcode Project

1. **Add App Groups Capability:**
   * In Xcode, select your project target &rarr; **Signing & Capabilities** &rarr; **+ Capability** &rarr; **App Groups**.
   * Add `group.com.yourcompany.matmaker` to both your main app target and your Widget Extension target.
2. **Add Vision & WidgetKit Frameworks:**
   * Ensure `Vision`, `CoreImage`, and `WidgetKit` are linked.
3. **Deploy:**
   * Run on an iOS 17.0+ physical device (the Vision Neural Engine segmentation request runs on-device).
