#!/bin/bash
# Terranova Protocol Buffers Validation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PROTO_DIR="$ROOT_DIR/proto"

echo "🔍 Validating Terranova Protocol Buffers..."

# Check if protoc is available
if ! command -v protoc &> /dev/null; then
    echo "❌ Error: protoc not found. Please install Protocol Buffers compiler."
    exit 1
fi

# Check if buf is available (optional but recommended)
USE_BUF=false
if command -v buf &> /dev/null; then
    echo "✓ Using buf for enhanced validation"
    USE_BUF=true
else
    echo "ℹ️  buf not found, using protoc only (install buf for better validation)"
fi

# Find all proto files
PROTO_FILES=$(find "$PROTO_DIR" -name "*.proto" | sort)

echo "📋 Validating proto files:"
for proto in $PROTO_FILES; do
    echo "   - $(basename $proto)"
done

# Validate with buf if available
if [ "$USE_BUF" = true ]; then
    echo ""
    echo "🔄 Running buf lint..."
    cd "$ROOT_DIR"
    buf lint || {
        echo "❌ buf lint failed"
        exit 1
    }
    
    echo ""
    echo "🔄 Running buf format check..."
    buf format --diff --exit-code || {
        echo "⚠️  Formatting issues detected. Run 'buf format -w' to fix."
    }
else
    # Validate with protoc
    echo ""
    echo "🔄 Running protoc validation..."
    for proto in $PROTO_FILES; do
        proto_name=$(basename "$proto")
        protoc \
            --proto_path="$PROTO_DIR" \
            --descriptor_set_out=/dev/null \
            "$proto" || {
            echo "❌ Validation failed for $proto_name"
            exit 1
        }
    done
fi

echo ""
echo "✅ All proto files are valid!"
