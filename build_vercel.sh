#!/bin/bash
set -e

echo "=== Installing Flutter SDK for Vercel Build ==="
if [ ! -d "_flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable _flutter
fi

export PATH="$PWD/_flutter/bin:$PATH"

echo "=== Flutter Version ==="
flutter --version

echo "=== Building Flutter Web Application ==="
flutter build web --release

echo "=== Build Complete: output in build/web ==="
