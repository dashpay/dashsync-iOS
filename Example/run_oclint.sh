#!/bin/sh

# Create input for OCLint
xcodebuild clean build -workspace DashSync.xcworkspace -scheme DashSync-Example -sdk iphonesimulator COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=NO | xcpretty -r json-compilation-database --output compile_commands.json


# Rules
LINT_RULES="-rc LONG_LINE=300 \
    -rc LONG_VARIABLE_NAME=100 \
    -rc LONG_METHOD=200 \
    -rc SHORT_VARIABLE_NAME=0"

# Threshold
LINT_THRESHOLD="-max-priority-1=0 \
    -max-priority-2=200 \
    -max-priority-3=300"

# Excludes
# grep-like syntax
LINT_EXCLUDES="Pods|Example"

oclint-json-compilation-database -exclude ${LINT_EXCLUDES} -- -report-type xcode ${LINT_RULES} ${LINT_THRESHOLD}


# Remove intermediate files
rm compile_commands.json
