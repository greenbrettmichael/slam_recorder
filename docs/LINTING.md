# SwiftLint & SwiftFormat Integration

This project now uses SwiftLint and SwiftFormat for code quality and consistency.

## Configuration Files

- **`.swiftlint.yml`** - SwiftLint configuration
  - Enforces consistent Swift style
  - Disabled problematic rules that conflict with practical development
  - Line length set to 120 characters
  
- **`.swiftformat`** - SwiftFormat configuration
  - Auto-formats Swift code
  - Indentation: 4 spaces
  - Ensures consistent formatting

## Local Usage

### Check Code Style
```bash
bash scripts/lint.sh
```
Runs both SwiftFormat and SwiftLint checks. Reports any violations but does not fix them.

### Auto-Fix Formatting
```bash
bash scripts/format.sh
```
Automatically fixes formatting issues using SwiftFormat.

## CI Integration

Both tools run automatically in GitHub Actions CI pipeline:
- **lint job** (runs first): Checks for style violations
- **build-and-test job** (depends on lint): Runs only if lint passes

The CI workflow ensures all code merged to main is properly formatted and linted.

## Common Issues & Fixes

### Long Lines
If SwiftLint reports "Line Length Violation", restructure the code to fit within 120 characters:
```swift
// Bad
let result = someVeryLongFunctionName(withArgument: value1, anotherArgument: value2, yetAnotherArgument: value3)

// Good
let result = someVeryLongFunctionName(
    withArgument: value1,
    anotherArgument: value2,
    yetAnotherArgument: value3
)
```

### Sorted Imports
SwiftLint enforces alphabetically sorted imports:
```swift
// Good
import AVFoundation
import CoreMotion
import SceneKit
import SwiftUI
```

### Trailing Commas (Disabled)
While SwiftFormat can add trailing commas, this is disabled in the SwiftLint config for more practical formatting.
