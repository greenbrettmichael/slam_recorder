# SLAM Recorder

An iOS application for recording SLAM (Simultaneous Localization and Mapping) related data from iPhones. This project provides a sandbox environment for SLAM development and testing, capturing synchronized ARKit data, IMU measurements, and video streams.

## Overview

SLAM Recorder captures high-frequency sensor data from iOS devices to support SLAM algorithm development and testing:

- **ARKit Data**: 6DOF camera poses with transform matrices at 30-60 Hz
- **IMU Data**: Accelerometer, gyroscope, and attitude filter (quaternions) at 200 Hz
- **Video Recording**: Synchronized H.264 video stream with pixel-aligned timestamps
- **Multi-Camera Mode**: Dual-camera recording support (back wide + front cameras)

All data is saved to timestamped session directories with CSV files and video, ready for post-processing and algorithm evaluation.

## Features

- Real-time AR session monitoring with live camera feed
- High-performance CSV buffering for minimal recording overhead
- Synchronized timestamp alignment between video and sensor data
- File sharing enabled for easy data export via iTunes/Finder
- Clean, production-ready Swift codebase with comprehensive documentation

## Quick Start

### Prerequisites

- macOS with Xcode 15.0+
- iOS device running iOS 17.0+ (ARKit requires physical device)
- [Homebrew](https://brew.sh) package manager
- Apple Developer Account (for device deployment)

### 1. Environment Setup

The project uses environment variables to configure your Apple Development Team ID for code signing.

```bash
# Install direnv for automatic environment management
brew install direnv

# Hook direnv into your shell (add to ~/.zshrc or ~/.bashrc)
eval "$(direnv hook zsh)"

# Create and configure your .env file
cp .env.example .env
# Edit .env and set TEAM_ID=your_apple_development_team_id

# Setup direnv configuration
cp .envrc.example .envrc
direnv allow
```

**Find your Team ID**: Check the [Apple Developer Portal](https://developer.apple.com/account) under "Membership Details" or run `security find-certificate -c "Apple Development" -p | openssl x509 -text | grep "OU="`.

📖 For detailed environment setup instructions, see [docs/ENVIRONMENT_SETUP.md](docs/ENVIRONMENT_SETUP.md)

### 2. Generate Xcode Project

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project from `project.yml`.

```bash
# Install XcodeGen
brew install xcodegen

# Generate the Xcode project
xcodegen generate
```

This creates `SLAMRecorder.xcodeproj` with your Team ID configured for code signing.

### 3. Build and Run

```bash
# Open the project in Xcode
open SLAMRecorder.xcodeproj

# Or build from command line
xcodebuild build \
  -scheme SLAMRecorder \
  -configuration Release \
  -destination 'platform=iOS,id=YOUR_DEVICE_UDID'
```

Deploy to your iOS device and grant camera permissions when prompted.

### 4. Recording Data

1. Launch the app on your iOS device
2. Select **ARKit** or **Multi-Camera** mode
3. Tap **START LOGGING** to begin recording
4. Tap **STOP** to end the session

Recorded sessions are saved to the app's Documents directory with timestamped folders:
```
session_2026-01-03_15-30-45-123/
├── imu_data.csv              # IMU measurements (timestamp, accel, gyro, attitude quaternion)
├── arkit_groundtruth.csv     # AR poses (timestamp, position, quaternion)
├── video.mov                 # H.264 video stream
└── video_start_time.txt      # Video offset for synchronization
```

### 5. Exporting Data

**Option 1: iTunes/Finder File Sharing**
- Connect device to computer
- Open Finder (macOS Catalina+) or iTunes
- Select your device → Files → SLAM Recorder
- Drag session folders to your computer

**Option 2: Xcode Devices Window**
- Window → Devices and Simulators
- Select your device → Download Container
- Navigate to AppData/Documents

## Data Processing Tools

### Setup Pixi Environment

[Pixi](https://pixi.sh) manages the Python environment for data processing tools.

```bash
# Install pixi
curl -fsSL https://pixi.sh/install.sh | bash

# Install project dependencies
pixi install

# Verify installation
pixi run python --version
```

### Extract Video Frames

Extract frames from recorded video with synchronized timestamps:

```bash
# Using pixi task (recommended)
pixi run extract path/to/session_*/video.mov path/to/output_frames

# Or directly with Python
pixi run python extract_frames.py path/to/video.mov path/to/output_folder
```

**What it does:**
- Extracts all video frames as JPEG images
- Reads `video_start_time.txt` for absolute timestamp offset
- Generates `frame_timestamps.csv` mapping filenames to timestamps
- Output: `frame_0000.jpg, frame_0001.jpg, ...` + `frame_timestamps.csv`

**Example:**
```bash
pixi run extract sessions/session_2026-01-03_15-30-45-123/video.mov extracted_frames/
```

## Android (Compose/CameraX/ARCore)

An Android sibling app lives in [android](android) using Kotlin, Jetpack Compose, CameraX/Camera2, ARCore, SensorManager, Kover for coverage, and Spotless/ktlint for formatting. It is optimized for VS Code on macOS/Linux (Android Studio not required).

### Prerequisites

- Java 17 (Gradle/AGP toolchain)
- Android SDK command-line tools with `ANDROID_HOME`/`ANDROID_SDK_ROOT` set and platform tools installed (API 35 recommended)
- VS Code extensions: Kotlin, Gradle, and basic Android syntax highlighting

### Build, Lint, and Test

```bash
cd android

# Format check
./gradlew spotlessCheck

# Assemble debug build
./gradlew :app:assembleDebug

# Unit tests + Robolectric
./gradlew :app:testDebugUnitTest

# Coverage (Kover)
./gradlew :app:koverXmlReport
```

### Multi-camera UX

- Multi-camera support is detected at startup via Camera2 logical camera capabilities.
- If unsupported, the Compose screen shows a clear message and disables the multi-camera mode toggle; ARCore-only mode remains available.

## Development

### Code Quality

```bash
# Run linting checks
bash scripts/lint.sh

# Auto-fix formatting issues
bash scripts/format.sh
```

📖 See [docs/LINTING.md](docs/LINTING.md) for SwiftLint/SwiftFormat configuration details.

### Running Tests

```bash
# Run unit tests with coverage
xcodebuild test \
  -scheme SLAMRecorder \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -enableCodeCoverage YES

# Generate coverage report
bash scripts/coverage.sh test_results.xcresult
```

📖 See [docs/TEST_COVERAGE.md](docs/TEST_COVERAGE.md) for coverage analysis details.