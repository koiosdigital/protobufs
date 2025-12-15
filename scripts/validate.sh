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
BUF_CONFIG=""
if [ -f "$ROOT_DIR/buf.yaml" ]; then
    BUF_CONFIG="$ROOT_DIR/buf.yaml"
elif [ -f "$ROOT_DIR/buf.work.yaml" ]; then
    BUF_CONFIG="$ROOT_DIR/buf.work.yaml"
fi

if command -v buf &> /dev/null && [ -n "$BUF_CONFIG" ]; then
    echo "✓ Using buf for enhanced validation"
    USE_BUF=true
else
    if ! command -v buf &> /dev/null; then
        echo "ℹ️  buf not found, using protoc only (install buf for better validation)"
    else
        echo "ℹ️  buf config not found, using protoc only"
    fi
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
    buf lint --config "$BUF_CONFIG" || {
        echo "❌ buf lint failed"
        exit 1
    }
    
    echo ""
    echo "🔄 Running buf format check..."
    buf format --config "$BUF_CONFIG" --diff --exit-code || {
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
