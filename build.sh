#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "Building NekoDeskuToppu (universal binary)..."
swiftc -O -target arm64-apple-macos13 -o NekoDeskuToppu-arm64 main.swift
swiftc -O -target x86_64-apple-macos13 -o NekoDeskuToppu-x86_64 main.swift
lipo -create NekoDeskuToppu-arm64 NekoDeskuToppu-x86_64 -output NekoDeskuToppu
rm NekoDeskuToppu-arm64 NekoDeskuToppu-x86_64
echo "Done. Run with: ./NekoDeskuToppu"
