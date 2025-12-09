# Quick Reference Guide

## Repository Structure at a Glance

```
protobufs/
├── proto/
│   ├── common/          → Shared types (enums, types)
│   ├── core/            → Core protocol (routing, system, heartbeat)
│   ├── services/        → Services (discovery, firmware_update)
│   └── devices/         → Devices (adc, efc, rover, vfd)
├── generated/nanopb/    → Generated C code (gitignored)
├── docs/                → Documentation
├── scripts/             → Build scripts
└── CMakeLists.txt       → Build configuration
```

## Quick Commands

### Generate Code

```bash
./scripts/generate.sh
```

### Validate Proto Files

```bash
./scripts/validate.sh
```

### Build with CMake

```bash
mkdir build && cd build
cmake ..
make
```

## File Organization

### Common (`proto/common/`)

- **enums.proto**: DeviceType enum
- **types.proto**: Endpoint, GPSState, DeviceInfo

### Core (`proto/core/`)

- **routing.proto**: RoutableMessage, StateUpdateRequest/Response
- **system.proto**: SystemInfoRequest/Response, ErrorResponse
- **heartbeat.proto**: HeartbeatRequest/Response

### Services (`proto/services/`)

- **discovery.proto**: Device discovery protocol
- **firmware_update.proto**: OTA firmware updates

### Devices (`proto/devices/`)

- **device_adc.proto**: Analog-to-Digital Converter
- **device_efc.proto**: Electronic Frequency Converter
- **device_rover.proto**: Rover movement control
- **device_vfd.proto**: Variable Frequency Drive

## Common Message Patterns

### Request-Response

```protobuf
SystemInfoRequest → Device
SystemInfoResponse ← Device
```

### State Updates

```protobuf
StateUpdateRequest → Device
StateUpdateResponse ← Device (with device-specific state)
```

### Device Commands

```protobuf
[Device]CommandRequest → Device
[Device]CommandResponse ← Device
```

## Type Naming Convention

All types use the versioned package: `ringbahn.v1`

**In C/C++:**

```c
ringbahn_v1_DeviceType
ringbahn_v1_RoutableMessage
ringbahn_v1_ADCState
```

**In Python:**

```python
enums_pb2.DeviceType
routing_pb2.RoutableMessage
device_adc_pb2.ADCState
```

## Import Paths

```protobuf
import "common/enums.proto";
import "common/types.proto";
import "core/routing.proto";
import "core/system.proto";
import "services/discovery.proto";
import "devices/device_adc.proto";
```

## Nanopb Options Format

```
ringbahn.v1.MessageName.field_name max_count:N
ringbahn.v1.MessageName.field_name max_size:N fixed_length:true
```

## Device Type Values

| Name         | Value | Description                           |
| ------------ | ----- | ------------------------------------- |
| HUB          | 1     | Main hub                              |
| NODE         | 2     | Node module                           |
| ADC          | 4     | Analog-to-Digital Converter           |
| SD_ADC       | 5     | Sigma-Delta ADC                       |
| VFD          | 6     | Variable Frequency Drive (deprecated) |
| ROVER        | 7     | Mobile robot                          |
| DIGITAL_OUT  | 8     | Digital output                        |
| RS485_BRIDGE | 9     | RS485 bridge                          |

## Common Field Numbers

### RoutableMessage

- source: 1
- destination: 2
- payload: 3+ (oneof)

### Standard Responses

- heartbeat: 251
- heartbeat_response: 252
- acknowledge_response: 253
- error_response: 254

## Useful Scripts

| Script                | Purpose                |
| --------------------- | ---------------------- |
| `scripts/generate.sh` | Generate nanopb C code |
| `scripts/validate.sh` | Validate proto syntax  |

## Documentation Files

| File                      | Content                             |
| ------------------------- | ----------------------------------- |
| `README.md`               | Overview, installation, quick start |
| `docs/PROTOCOL.md`        | Detailed protocol specification     |
| `docs/CHANGELOG.md`       | Version history                     |
| `docs/MIGRATION.md`       | Migration guide from legacy         |
| `docs/QUICK_REFERENCE.md` | This file                           |

## Build Configuration

### CMake Variables

- `PROTO_BASE_DIR`: Base directory for proto files
- `NANOPB_OUT_PATH`: Output directory (auto-detected)
- `PROTO_SRCS`: List of all proto files (auto-discovered)

### Targets

- `protobufs`: Static library with generated code

## Testing Checklist

- [ ] Proto files validate (`./scripts/validate.sh`)
- [ ] Code generates without errors (`./scripts/generate.sh`)
- [ ] CMake build succeeds
- [ ] All includes resolve
- [ ] Device communication works
- [ ] Message serialization/deserialization works

## Common Gotchas

1. **Import paths**: Use subdirectories (e.g., `common/enums.proto`)
2. **Package name**: Always `ringbahn.v1` (with version)
3. **Nanopb options**: Must match package name with version
4. **Field numbers**: Never reuse or change existing field numbers
5. **Generated files**: Organize by subdirectory in output

## Version Information

- **Current Version**: 1.0.0
- **Package**: ringbahn.v1
- **Last Updated**: December 9, 2025

## Quick Links

- [Main README](../README.md)
- [Protocol Specification](PROTOCOL.md)
- [Changelog](CHANGELOG.md)
- [Migration Guide](MIGRATION.md)

---

Keep this file handy for quick reference during development!
