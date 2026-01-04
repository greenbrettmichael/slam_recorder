# Android SLAM Recorder - Code Documentation

## Overview
The Android SLAM Recorder application provides ARCore-based SLAM tracking and multi-camera video recording capabilities. This document summarizes the professional code documentation added to all core components.

## Documented Components

### Core Recording Classes

#### `RecordingCoordinator`
- Orchestrates all recording activities (IMU, video, ARCore)
- Manages recording lifecycle and mode switching
- Implements 1.5s camera warmup delays for stable focus/exposure
- Provides session export as ZIP files

#### `RecordingViewModel`
- MVVM ViewModel for recording UI state
- Manages camera selection (up to 2 cameras)
- Coordinates user interactions with recording system
- Implements StateFlow for reactive UI updates

### Camera Management

#### `CameraOption`
- Represents selectable camera options (physical/logical)
- Generates user-friendly labels with facing and focal length hints
- Provides metadata for camera selection UI

#### `CameraEnumerator`
- Enumerates available cameras via Camera2 API
- Exposes physical cameras from logical multi-cameras
- Implements deduplication based on facing/focal length

#### `MultiCamSupportChecker`
- Detects LOGICAL_MULTI_CAMERA capability
- Validates device support for simultaneous camera recording

### Video Recording

#### `VideoCaptureController`
- Single-camera CameraX-based video recording
- Highest quality selection with H.264 encoding
- Optional preview support

#### `MultiCameraCaptureController`
- Dual-camera simultaneous recording (max 2)
- Supports independent cameras and physical sub-cameras
- Uses Camera2 API with SessionConfiguration for physical targeting
- Per-camera MediaRecorder instances

### ARCore Integration

#### `SimpleArCoreRecorder`
- ARCore pose tracking without video encoding
- OpenGL ES context management for camera texture
- Records 6-DOF poses at ~30Hz
- Skips initial 10 frames for stable tracking
- Filters poses by tracking state (only TRACKING written)

### Data Management

#### `SessionFiles`
- Manages timestamped session directories
- Provides paths for all session files (IMU, poses, videos, timestamps)
- Supports multi-camera file naming

#### `CsvBufferedWriter`
- Thread-safe CSV writer with buffering
- High-frequency sensor data optimized
- Silent error handling to prevent recording crashes

#### `ImuRecorder`
- Records accelerometer and gyroscope data
- SENSOR_DELAY_FASTEST with SENSOR_DELAY_GAME fallback
- Timestamps in seconds for ARCore compatibility

### UI Components

#### `MainActivity`
- Handles permissions (CAMERA, RECORD_AUDIO)
- Initializes recording coordinator and ViewModels
- Manages session export and sharing

### Enums and Constants

#### `RecordingMode`
- ARCore: Single camera + pose tracking
- Multi-camera: Dual camera recording without AR

## Documentation Standards

All documentation follows KDoc conventions:
- Class-level: Purpose, architecture, dependencies
- Method-level: Parameters, return values, side effects
- Property-level: Meaning and constraints
- Complex logic: Implementation details and rationale

## Key Features Documented

1. **Camera warmup delays**: 1.5s pause before recording for stable autofocus/exposure
2. **ARCore frame skipping**: First 10 frames discarded for reliable tracking
3. **Tracking state filtering**: Only TRACKING state poses written to CSV
4. **Physical camera support**: Android P+ SessionConfiguration API usage
5. **Thread safety**: Synchronized CSV writing and atomic state management
6. **Resource cleanup**: Proper exception handling during teardown

## Build Verification

- ✅ All Kotlin code compiles successfully
- ✅ All unit tests pass
- ✅ No new warnings introduced
- ✅ Documentation follows professional standards

