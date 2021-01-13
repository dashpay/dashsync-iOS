#!/bin/sh

# Create input for OCLint
xcodebuild clean build -workspace DashSync.xcworkspace -scheme DashSync-Example -sdk iphonesimulator COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=NO | xcpretty -r json-compilation-database --output compile_commands.json

# Excludes
# grep-like syntax
LINT_EXCLUDES="Pods|Example"

oclint-json-compilation-database -exclude ${LINT_EXCLUDES} -- -report-type xcode ${LINT_RULES} ${LINT_THRESHOLD}


# Remove intermediate files
rm compile_commands.json
