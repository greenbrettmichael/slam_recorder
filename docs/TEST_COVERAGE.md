# Test Coverage

This project uses Xcode's built-in code coverage tools to track test coverage, enhanced with ViewInspector for SwiftUI testing.

## Running Tests with Coverage Locally

```bash
# Using the coverage script (recommended)
xcodebuild test \
  -scheme SLAMRecorder \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -enableCodeCoverage YES \
  -resultBundlePath ./test_results.xcresult

bash scripts/coverage.sh test_results.xcresult

# Manual approach
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
2. Coverage report is generated using scripts/coverage.sh
3. Summary is added to the GitHub Actions summary page with emoji indicators
4. Coverage artifacts (JSON and text reports) are uploaded for download

## ViewInspector Integration

ViewInspector is used to test SwiftUI view structures:
- Verifies view hierarchies and component existence
- Tests view properties and state
- Validates conditional rendering
- Limited to structural testing (user interactions require UI tests)

## Notes

- Camera-related code (`MultiCamRecorder`) has low coverage because it requires physical camera hardware
