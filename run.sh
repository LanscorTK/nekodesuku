#!/bin/bash
set -e
cd "$(dirname "$0")"

# Build if needed (any .swift file newer than the binary)
needs_build=0
[ ! -f NekoDeskuToppu ] && needs_build=1
if [ "$needs_build" = 0 ]; then
    while IFS= read -r f; do
        if [ "$f" -nt NekoDeskuToppu ]; then needs_build=1; break; fi
    done < <(find main.swift Sources -name "*.swift" 2>/dev/null)
fi
[ "$needs_build" = 1 ] && bash build.sh

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
