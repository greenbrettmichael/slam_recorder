#!/bin/bash
# Generate a coverage summary for GitHub Actions

set -e

XCRESULT_PATH="$1"

if [ -z "$XCRESULT_PATH" ]; then
    echo "Usage: $0 <path-to-xcresult>"
    exit 1
fi

# Generate JSON coverage report
xcrun xccov view --report --json "$XCRESULT_PATH" > coverage.json

# Extract overall coverage percentage
COVERAGE=$(python3 -c "import json; data=json.load(open('coverage.json')); print(f\"{data['lineCoverage']*100:.2f}\")")
echo "Overall Coverage: ${COVERAGE}%"

# Save to GitHub environment if running in CI
if [ -n "$GITHUB_ENV" ]; then
    echo "COVERAGE=${COVERAGE}" >> $GITHUB_ENV
fi

# Generate text report
xcrun xccov view --report "$XCRESULT_PATH" > coverage_report.txt

echo "Coverage report generated successfully"
