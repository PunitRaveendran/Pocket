#!/usr/bin/env bash
set -e

# Add local flutter to PATH if not present
export PATH="/home/punit-raveendran/.local/flutter/bin:$PATH"

echo "=========================================="
echo " Running Pocket Code Quality & Test Suite "
echo "=========================================="

echo ""
echo "1. Analyzing codebase (flutter analyze)..."
flutter analyze

echo ""
echo "2. Running all unit & widget tests (flutter test)..."
flutter test -r expanded

echo ""
echo "=========================================="
echo " All checks passed! The app is fully working."
echo "=========================================="
