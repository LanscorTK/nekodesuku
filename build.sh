#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "Building NekoDeskuToppu..."
swiftc -O -o NekoDeskuToppu main.swift
echo "Done. Run with: ./NekoDeskuToppu"
