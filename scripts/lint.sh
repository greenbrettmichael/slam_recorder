#!/bin/bash
set -e

echo "Running SwiftFormat check..."
if ! command -v swiftformat &> /dev/null; then
    echo "SwiftFormat not found. Installing via Homebrew..."
    brew install swiftformat
fi

# Find all Swift files and lint them
find SLAMRecorder SLAMRecorderTests -name "*.swift" | while read file; do
    if ! swiftformat --lint "$file" > /dev/null 2>&1; then
        echo "SwiftFormat issues found in $file"
    fi
done

echo "Running SwiftLint check..."
if ! command -v swiftlint &> /dev/null; then
    echo "SwiftLint not found. Installing via Homebrew..."
    brew install swiftlint
fi

swiftlint lint SLAMRecorder SLAMRecorderTests

echo "Swift linting completed."
