#!/bin/bash
set -e
cd "$(dirname "$0")"

# Build if needed
if [ ! -f NekoDeskuToppu ] || [ main.swift -nt NekoDeskuToppu ]; then
    bash build.sh
fi

# Auto-detect Kittens pack location
PACK="${1:-}"
if [ -z "$PACK" ]; then
    for candidate in \
        "./Kittens pack" \
        "$HOME/Downloads/Kittens pack" \
        "$HOME/Desktop/Kittens pack"; do
        if [ -d "$candidate" ]; then
            PACK="$candidate"
            break
        fi
    done
fi

if [ -z "$PACK" ]; then
    echo "Error: Kittens pack not found. Pass the path as argument:"
    echo "  bash run.sh \"/path/to/Kittens pack\""
    exit 1
fi

echo "Using assets: $PACK"
./NekoDeskuToppu "$PACK" &
echo "NekoDeskuToppu is running (PID $!)"
