#!/bin/bash
set -e

echo "Running SwiftFormat auto-fix..."
if ! command -v swiftformat &> /dev/null; then
    echo "SwiftFormat not found. Installing via Homebrew..."
    brew install swiftformat
fi

find SLAMRecorder SLAMRecorderTests -name "*.swift" -exec swiftformat {} \;

echo "SwiftFormat auto-formatting completed."
