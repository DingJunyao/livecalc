# Mobile Merchant Picker Current Location Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let merchant create/edit map pickers locate and select the device's current position from a button immediately to the right of the layer control.

**Architecture:** Add one reusable `MapLocateButton` that owns geolocator permission checks, loading state, timeout, and error feedback. `MapPointPicker` and `AppleMapPicker` render it beside their layer controls; on success they set their selected point to WGS84, invoke `onChanged`, and move the map camera using each engine's existing coordinate conversion.

**Tech Stack:** Flutter, Riverpod, flutter_map, apple_maps_flutter, geolocator.

---

### Task 1: Reusable Locate Button

**Files:**
- Create: `mobile/lib/features/merchants/widgets/map_locate_button.dart`
- Test: `mobile/test/features/merchants/widgets/map_locate_button_test.dart`

- [x] Add failing tests for successful location callback and permission-denied feedback using a fake `GeolocatorPlatform`.
- [x] Run the focused test and confirm the missing widget fails.
- [x] Implement the button with `Icons.my_location_outlined`, loading spinner, tooltip `定位并选择当前位置`, high accuracy, and a 10 second timeout.
- [x] Run the focused test and confirm both cases pass.

### Task 2: Android FlutterMap Picker

**Files:**
- Modify: `mobile/lib/features/merchants/widgets/map_point_picker.dart`
- Test: `mobile/test/features/merchants/widgets/map_point_picker_test.dart`

- [x] Add failing integration test: tapping the locate key invokes `onChanged` with WGS84, shows the selected marker/text, moves the camera to the GCJ02 display coordinate, and places the button right of the layer button.
- [x] Confirm the new test fails because the button is absent.
- [x] Put the layer popup and locate button in one compact control row. On success set `_wgs`, call `widget.onChanged`, and `_controller.move(_toDisplay(point), kPointZoom)`.
- [x] Run the picker test file and confirm all tests pass.

### Task 3: iOS MapKit Picker

**Files:**
- Modify: `mobile/lib/features/merchants/widgets/apple_map_picker.dart`
- Test: `mobile/test/features/merchants/widgets/apple_map_picker_test.dart`

- [x] Add a direct widget test for `AppleMapPicker` on the host test platform: tapping locate updates the callback to WGS84 and the selected annotation to the GCJ02 display coordinate, with the locate button right of the layer button.
- [x] Confirm the new test fails because the button is absent.
- [x] Add an `AppleMapController`, store it in `onMapCreated`, render the same locate button beside the layer menu, select the WGS84 point, invoke `onChanged`, and animate the camera to `_toDisplay(point)` at point zoom.
- [x] Run the new iOS picker test and confirm it passes.

### Task 4: Regression and Record

**Files:**
- Create: `cc/FEATURE_移动端商家选点定位.md`

- [x] Run all merchant widget and screen tests.
- [x] Run `flutter analyze`.
- [x] Run a Windows debug build if the toolchain permits it.
- [x] Record implementation, decisions, and verification in the `cc` feature note.
