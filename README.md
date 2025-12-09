# Terranova Protocol Buffers

[![CI](https://github.com/Terranova/Protobufs/actions/workflows/ci.yml/badge.svg)](https://github.com/Terranova/Protobufs/actions/workflows/ci.yml)
[![Lint](https://github.com/Terranova/Protobufs/actions/workflows/lint.yml/badge.svg)](https://github.com/Terranova/Protobufs/actions/workflows/lint.yml)
[![Build](https://github.com/Terranova/Protobufs/actions/workflows/build.yml/badge.svg)](https://github.com/Terranova/Protobufs/actions/workflows/build.yml)

This repository contains the Protocol Buffer definitions for the Terranova distributed control system. These definitions enable communication between various devices in the Terranova ecosystem including hubs, nodes, sensors, and actuators.

## 📁 Repository Structure

```
protobufs/
├── proto/                      # Protocol Buffer definitions
│   ├── common/                # Shared types and enumerations
│   │   ├── enums.proto       # Device types and common enums
│   │   └── types.proto       # Common message types (Endpoint, GPSState, etc.)
│   ├── core/                  # Core protocol messages
│   │   ├── routing.proto     # Message routing and state updates
│   │   ├── system.proto      # System information and error handling
│   │   └── heartbeat.proto   # Keep-alive messages
│   ├── services/              # Service-level protocols
│   │   ├── discovery.proto   # Device discovery and identification
│   │   └── firmware_update.proto  # Over-the-air firmware updates
│   └── devices/               # Device-specific protocols
│       ├── device_adc.proto  # Analog-to-Digital Converter
│       ├── device_efc.proto  # Electronic Frequency Converter
│       ├── device_rover.proto # Rover control
│       └── device_vfd.proto  # Variable Frequency Drive
├── generated/                 # Generated code (not committed)
│   └── nanopb/               # Nanopb C implementations
├── docs/                      # Documentation
│   ├── PROTOCOL.md           # Protocol specification
│   └── CHANGELOG.md          # Version history
├── scripts/                   # Build and utility scripts
│   ├── generate.sh           # Code generation script
│   └── validate.sh           # Proto validation script
├── buf.yaml                   # Buf configuration
├── buf.gen.yaml              # Buf generation configuration
└── CMakeLists.txt            # CMake build configuration
```

## 🚀 Quick Start

### Prerequisites

- **Protocol Buffers Compiler**: `protoc` version 3.0 or higher
- **Nanopb**: For embedded C code generation
- **CMake**: Version 3.15 or higher (for C/C++ projects)
- **Buf** (optional but recommended): Modern protobuf tooling

### Installation

#### macOS

```bash
# Install protoc
brew install protobuf

# Install buf (recommended)
brew install bufbuild/buf/buf

# Install nanopb (if needed for C generation)
pip3 install nanopb
```

#### Linux

```bash
# Install protoc
sudo apt-get install protobuf-compiler

# Install buf
curl -sSL "https://github.com/bufbuild/buf/releases/latest/download/buf-$(uname -s)-$(uname -m)" -o /usr/local/bin/buf
chmod +x /usr/local/bin/buf

# Install nanopb
pip3 install nanopb
```

### Generating Code

#### Using the Generation Script (Recommended)

```bash
# Make script executable (first time only)
chmod +x scripts/generate.sh

# Generate nanopb C code
./scripts/generate.sh
```

#### Using CMake

```bash
mkdir build && cd build
cmake ..
make
```

#### Manual Generation

```bash
# Generate for all proto files
protoc --proto_path=proto \
       --nanopb_out=generated/nanopb \
       proto/**/*.proto
```

### Validation

Validate your proto files before committing:

```bash
./scripts/validate.sh
```

## 📦 Package Versioning

All proto files use versioned packages:

```protobuf
package ringbahn.v1;
```

This allows for future API evolution while maintaining backward compatibility.

## 🔌 Integration

### C/C++ Projects (ESP-IDF, Embedded)

Add to your `CMakeLists.txt`:

```cmake
add_subdirectory(path/to/protobufs)
target_link_libraries(your_target PRIVATE protobufs)
```

### Python Projects

```bash
# Generate Python code
protoc --proto_path=proto \
       --python_out=. \
       proto/**/*.proto
```

### Other Languages

See [Protocol Buffers documentation](https://protobuf.dev/) for language-specific generation.

## 📖 Protocol Overview

### Message Routing

All messages are wrapped in a `RoutableMessage` which contains:

- **Source endpoint**: Originating device
- **Destination endpoint**: Target device
- **Payload**: The actual command or data (oneof)

### Device Types

The system supports multiple device types:

- `DEVICE_TYPE_HUB`: Main hub/coordinator
- `DEVICE_TYPE_NODE`: Generic node module
- `DEVICE_TYPE_ADC`: Analog-to-Digital Converter
- `DEVICE_TYPE_VFD`: Variable Frequency Drive
- `DEVICE_TYPE_ROVER`: Mobile robot platform
- `DEVICE_TYPE_EFC`: Electronic Frequency Converter
- And more...

### Communication Patterns

1. **Request-Response**: Commands return responses
2. **State Updates**: Devices broadcast state periodically
3. **Discovery**: Automatic device detection
4. **Heartbeat**: Keep-alive mechanism

See [PROTOCOL.md](docs/PROTOCOL.md) for detailed protocol specification.

## 🛠️ Development

### Adding New Device Types

1. Create a new proto file in `proto/devices/`
2. Define your message types with package `ringbahn.v1`
3. Add corresponding entry in `core/routing.proto`
4. Create a `.options` file for nanopb settings
5. Update this README

### Breaking Changes

Use `buf` to detect breaking changes:

```bash
buf breaking --against '.git#branch=main'
```

### Best Practices

- Use clear, descriptive field names
- Add comments for all messages and fields
- Use enums for fixed sets of values
- Reserve field numbers for deleted fields
- Never change field numbers of existing fields
- Use `optional` for nullable fields in proto3

## 📝 Nanopb Options

Each proto file has a corresponding `.options` file that configures:

- Maximum array sizes (`max_count`)
- String buffer sizes (`max_size`)
- Fixed-length arrays (`fixed_length`)

Example (`device_adc.options`):

```
ringbahn.v1.ADCState.values max_count:8
```

## 🔄 Migration from Old Structure

The repository has been restructured for better organization. If you're migrating from the old flat structure:

1. Old proto files are in `proto/` (root level)
2. New proto files are organized in subdirectories
3. CMakeLists.txt supports both old (`nanopb/`) and new (`generated/nanopb/`) output paths
4. Package names now include version: `ringbahn.v1`

## 📚 Additional Resources

- [Protocol Buffers Documentation](https://protobuf.dev/)
- [Nanopb Documentation](https://jpa.kapsi.fi/nanopb/)
- [Buf Documentation](https://buf.build/docs)
- [Terranova Project Documentation](https://github.com/Terranova)

## 📄 License

See [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Run `./scripts/validate.sh` to ensure proto files are valid
4. Test with `./scripts/generate.sh`
5. Submit a pull request

## 📞 Support

For questions or issues, please open an issue on GitHub or contact the Terranova team.

---

**Version**: 1.0.0  
**Last Updated**: December 9, 2025  
**Maintainer**: Terranova Team
