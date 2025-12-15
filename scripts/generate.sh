#!/bin/bash
# Terranova Protocol Buffers Code Generation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PROTO_DIR="$ROOT_DIR/proto"
OUTPUT_DIR="$ROOT_DIR/generated/nanopb"

echo "🔨 Generating Terranova Protocol Buffers..."
echo "   Proto directory: $PROTO_DIR"
echo "   Output directory: $OUTPUT_DIR"

# Check if nanopb generator is available
if ! command -v protoc &> /dev/null; then
    echo "❌ Error: protoc not found. Please install Protocol Buffers compiler."
    exit 1
fi

# Check for protoc-gen-nanopb plugin
NANOPB_PLUGIN=""
if command -v protoc-gen-nanopb &> /dev/null; then
    NANOPB_PLUGIN=$(which protoc-gen-nanopb)
elif command -v nanopb_generator.py &> /dev/null; then
    NANOPB_PLUGIN=$(which nanopb_generator.py)
elif command -v nanopb_generator &> /dev/null; then
    NANOPB_PLUGIN=$(which nanopb_generator)
elif [ -f "$ROOT_DIR/../nanopb/generator/protoc-gen-nanopb" ]; then
    NANOPB_PLUGIN="$ROOT_DIR/../nanopb/generator/protoc-gen-nanopb"
else
    echo "⚠️  Warning: nanopb generator not found."
    echo "   Install with: brew install nanopb"
    echo "   Or: pip3 install nanopb"
    echo "   Or clone nanopb: git clone https://github.com/nanopb/nanopb.git"
    echo ""
    echo "   Skipping nanopb generation. Proto files are still valid."
    exit 0
fi

echo "   Using nanopb plugin: $NANOPB_PLUGIN"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Find all proto files
PROTO_FILES=$(find "$PROTO_DIR" -name "*.proto" | sort)

echo "📋 Found proto files:"
for proto in $PROTO_FILES; do
    echo "   - $(basename $proto)"
done

# Generate nanopb C code
echo ""
echo "🔄 Generating nanopb C code..."

if [ -n "$NANOPB_PLUGIN" ]; then
    # Generate all proto files in one command to properly handle options files
    # Add -I flag to tell nanopb where to find .options files
    echo "   Running protoc with verbose output..."
    protoc \
        --proto_path="$PROTO_DIR" \
        --plugin=protoc-gen-nanopb="$NANOPB_PLUGIN" \
        --nanopb_out=-I"$PROTO_DIR":$OUTPUT_DIR \
        $PROTO_FILES
    
    echo "   Processed $(echo $PROTO_FILES | wc -w | tr -d ' ') proto files"

    cp -r $ROOT_DIR/nanopb/* "$OUTPUT_DIR"
else
    # Fallback: use basic protoc C generation
    protoc \
        --proto_path="$PROTO_DIR" \
        --c_out="$OUTPUT_DIR" \
        $PROTO_FILES
fi

echo ""
echo "✅ Code generation complete!"
echo "   Generated files are in: $OUTPUT_DIR"
