# Archive Build Patcher

A tiny macOS menu bar utility for patching `BuildMachineOSBuild` inside an Xcode `.xcarchive`.

## Requirements

- macOS 13+
- Xcode 15+

## Run

1. Open `ArchiveBuildPatcher.xcodeproj` in Xcode.
2. Select the **ArchiveBuildPatcher** scheme.
3. Set your signing team if Xcode asks for one.
4. Run the app.
5. Click the hammer icon in the menu bar and drag an `.xcarchive` into the popover.
6. Confirm the detected app and Apple's latest public macOS build.
7. Click **Patch Archive**.

The utility can optionally create a sibling `*.backup.xcarchive` before modifying the original archive.

## What it changes

Only this key in the embedded app's `Info.plist`:

```
BuildMachineOSBuild
```

The original plist format (binary or XML) is preserved.

## Important

Editing an app bundle after Xcode archives it changes signed content. This utility is intended for the same pre-distribution workaround you would otherwise perform manually. Apple does not document changing `BuildMachineOSBuild` as a supported distribution workflow, so use it at your own discretion.
