# Terranova Protocol Buffers

[![CI](https://github.com/Terranova/Protobufs/actions/workflows/ci.yml/badge.svg)](https://github.com/Terranova/Protobufs/actions/workflows/ci.yml)
[![Lint](https://github.com/Terranova/Protobufs/actions/workflows/lint.yml/badge.svg)](https://github.com/Terranova/Protobufs/actions/workflows/lint.yml)
[![Build](https://github.com/Terranova/Protobufs/actions/workflows/build.yml/badge.svg)](https://github.com/Terranova/Protobufs/actions/workflows/build.yml)

This repository contains the Protocol Buffer definitions for the Terranova distributed control system. These definitions enable communication between various devices in the Terranova ecosystem including hubs, nodes, sensors, and actuators.

## 📁 Repository Structure

```
protobufs/
├── proto/                      # Protocol Buffer definitions
│   ├──                 # Shared types and enumerations
│   │   ├── enums.proto       # Device types and common enums
│   │   └── types.proto       # Device UUIDs, CommandResult, GPSState, etc.
│   └──                # Device-specific protocols + shared helpers
│       ├── device_common.proto      # Shared commands (system info, ping, errors)
│       ├── device_routing.proto     # UART-to-CAN bridge, discovery, firmware tools
│       ├── device_adc.proto         # Analog-to-Digital Converter
│       ├── device_digital_output.proto # PWM/digital outputs
│       ├── device_rover.proto       # Rover control
│       └── device_modbus_bridge.proto # Modbus RTU/TCP bridge
├── generated/                 # Generated code (not committed)
│   └── nanopb/               # Nanopb C implementations
├── docs/                      # Documentation
│   ├── PROTOCOL.md           # Protocol specification
│   └── CHANGELOG.md          # Version history
├── buf.yaml                   # Buf module + lint config
├── buf.gen.yaml               # Buf codegen config (nanopb + TypeScript)
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

#### Using Buf (Recommended)

```bash
# Validate protos (compilation)
buf build

# Lint
buf lint

# Generate nanopb (C) + modern TypeScript
buf generate
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
buf build
buf lint
```

## 📦 Package Versioning

All proto files use versioned packages:

```protobuf
package ringbahn;
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

### Ringbahn Frames

All commands and telemetry are sent inside the Ringbahn frame. The base layout is:

- **0xA5** – Start-of-frame sentinel (not included in CRC)
- **uint16 message_id** – Host-assigned tracking ID for request/response correlation
- **uint16 payload_length** – Number of payload bytes
- **payload** – Protobuf bytes for the selected message
- **crc16** – CRC computed over message_id, payload_length, and payload bytes

For UART links we also include addressing (inside the CRC):

- **12-byte sender UUID** – Device UUID of the source
- **12-byte recipient UUID** – Device UUID of the target

This removes the need for a giant envelope message. Each device only imports the proto file that defines the payload it cares about (e.g., `device_adc.proto`).

#### Device UUIDs

`types.proto` defines `DeviceUUID`, a fixed 12-byte identifier that mirrors the IDs carried in the Ringbahn header. `DeviceInfo` now contains this UUID along with any legacy short IDs so both discovery flows and payloads speak the same addressing language.

### Device Types

The system supports multiple device types:

- `DEVICE_TYPE_HUB`: Main hub/coordinator
- `DEVICE_TYPE_NODE`: Generic node module
- `DEVICE_TYPE_ROUTING`: UART-to-CAN routing bridge (handles discovery + firmware)
- `DEVICE_TYPE_ADC`: Analog-to-Digital Converter
- `DEVICE_TYPE_SD_ADC`: Sigma-delta ADC
- `DEVICE_TYPE_ROVER`: Mobile robot platform
- `DEVICE_TYPE_DIGITAL_OUT`: PWM / digital output bridge
- `DEVICE_TYPE_MODBUS_BRIDGE`: Modbus RTU/TCP bridge
- Additional values can be added as needed in `enums.proto`

### Communication Patterns

1. **Request-Response**: Commands return responses with matching message_id
2. **State Updates**: Devices broadcast their `<Device>State` payloads (e.g., `ADCState`, `RoverDeviceState`)
3. **Discovery**: Automatic device detection via routing device
4. **Ping**: In-band connectivity test using `PingCommand` (returns `CommandResult` with success=1)

**Note**: Heartbeat/keep-alive is handled out-of-band by the transport layer and is not part of the protobuf protocol.

See [PROTOCOL.md](docs/PROTOCOL.md) for detailed protocol specification.

### Shared Commands

`proto/device_common.proto` hosts messages that every device understands: `SystemInfoRequest/Response`, `PingCommand`, `AcknowledgeResponse`, and `ErrorResponse`.

### Routing Device

`proto/device_routing.proto` defines the UART-to-CAN bridge. It now owns every discovery primitive (attached devices, active channel selection) as well as both firmware paths:

- **Internal OTA**: Commands (`InternalOta*`) stream new firmware into the routing MCU and return compact `InternalOtaStatus` updates.
- **Terraboot CAN bootloader**: `Terraboot*` messages map one-to-one with the Katapult/Terraboot protocol (`connect`, `send_block`, `eof`, `request_block`, `complete`, `get_canbus_id`) so routing firmware can forward frames down the CAN bus without extra wrappers.

All other device protos cover nodes that live exclusively on the CAN bus.

## 🛠️ Development

### Adding New Device Types

1. Create a new proto file in `proto/` (or extend `device_common.proto` if the command is shared).
2. Create a `.options` file for nanopb settings that matches the package name (`ringbahn`).
3. Update this README and the protocol docs to describe the new device's messages.

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
ringbahn.ADCState.values max_count:8
```

## 🔄 Migration from Old Structure

The repository has been restructured for better organization. If you're migrating from the old flat structure:

1. Old proto files are in `proto/` (root level)
2. New proto files are organized in subdirectories
3. CMakeLists.txt supports both old (`nanopb/`) and new (`generated/nanopb/`) output paths
4. Package names now include version: `ringbahn`

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
3. Run `buf build` and `buf lint`
4. Run `buf generate`
5. Submit a pull request

## 📞 Support

For questions or issues, please open an issue on GitHub or contact the Terranova team.

---

**Version**: 1.2.0  
**Last Updated**: December 15, 2025  
**Maintainer**: Terranova Team
