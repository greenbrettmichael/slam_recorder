# Test Coverage

This project uses Xcode's built-in code coverage tools to track test coverage.

## Current Coverage

As of the latest run:
- **Overall Coverage**: ~53% (for SLAMRecorder.app target)
- **Test Suite Coverage**: ~97% (for SLAMRecorderTests)

### Coverage by File:
- `CSVWriter.swift`: 92%
- `VideoRecorder.swift`: 93%
- `SLAMLogger.swift`: 63%
- `MultiCamRecorder.swift`: 36%
- `RecordingMode.swift`: 100%
- `ContentView.swift`: 43% (UI code - harder to unit test)

## Running Tests with Coverage Locally

```bash
# Run tests with coverage enabled
xcodebuild test \
  -scheme SLAMRecorder \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -enableCodeCoverage YES \
  -derivedDataPath ./DerivedData

# View coverage report
xcrun xccov view --report ./DerivedData/Logs/Test/*.xcresult

# Generate JSON coverage report
xcrun xccov view --report --json ./DerivedData/Logs/Test/*.xcresult > coverage.json
```

## CI Integration

Coverage is automatically collected and reported in GitHub Actions:
1. Tests run with coverage enabled
2. Coverage report is generated
3. Summary is added to the GitHub Actions summary page
4. Coverage artifacts are uploaded for download

## Coverage Goals

- **Unit-testable code**: Aim for >80% coverage
- **UI code**: Difficult to unit test, consider UI tests for critical paths
- **Integration paths**: Focus on testing public APIs and critical workflows

## Uncovered Code

The following areas have low/no coverage and may need additional tests or are intentionally untested (UI):

### Low Priority (UI Code)
- `MultiCamPreviewContainer` - SwiftUI view layout (43% covered)
- `CameraSelectionView` - SwiftUI controls (0% covered)
- `ARViewContainer` - ARKit view wrapper (100% makeUIView, 100% updateUIView)

### Medium Priority (Integration Code)
- `MultiCamRecorder.startRecording()` - Requires actual camera hardware (0% covered)
- `MultiCamRecorder.stopRecording()` - Camera teardown (0% covered)
- `MultiCamRecorder.captureOutput()` - Camera delegate (0% covered)
- `SLAMLogger.session(_:didUpdate:)` - ARKit delegate (0% covered)
- `SLAMLogger.startIMU()` closure - IMU data capture (11% covered)

### High Priority (Unit-testable)
- ✅ `VideoRecorder.setPreferredStartTime()` - Now tested
- ✅ `CameraID.resolveDevice()` - Now tested
- ✅ All enum properties - Now tested

## Test Statistics

- **Total Tests**: 52 (counting both test runs in report)
- **Unique Tests**: 26 test methods across 5 test classes
  - CSVWriterTests: 6 tests
  - VideoRecorderTests: 9 tests  
  - MultiCamRecorderTests: 11 tests
  - RecordingModeTests: 6 tests
  - SLAMLoggerTests: 20 tests

## Notes

- Camera-related code (`MultiCamRecorder`) has low coverage because it requires physical camera hardware
- UI code has expected low unit test coverage - consider snapshot or UI tests for these
- Core business logic (CSV writing, video recording, mode management) has good coverage (>90%)
