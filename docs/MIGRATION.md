# Migration Guide: v1.1.0 to v1.2.0

## Quick Summary

### What Changed

1. **Heartbeat removed**: Now handled out-of-band by transport layer
2. **PingCommand added**: All devices support in-band ping (returns `CommandResult` with success=1)
3. **VFD → Modbus Bridge**: Complete replacement with full Modbus protocol support
4. **Field tag consistency**: All devices now have `ping` at field tag 2

### Breaking Changes

- `HeartbeatRequest` and `HeartbeatResponse` removed from `device_common.proto`
- `device_vfd.proto` removed, replaced by `device_modbus_bridge.proto`
- All `VFDDeviceCommand`, `VFDState`, and VFD enums removed

## Migration Steps

### 1. Replace Heartbeat with Transport-Level Keep-Alive

**Old Code**:
```c
ringbahn_v1_HeartbeatRequest req = ringbahn_v1_HeartbeatRequest_init_zero;
// Send heartbeat
```

**New Approach**: Implement keep-alive at the transport layer (e.g., TCP keep-alive, UART timeout detection). For in-band testing, use:

```c
ringbahn_v1_PingCommand ping = ringbahn_v1_PingCommand_init_zero;
// Send and expect CommandResult with success=1
```

### 2. Migrate VFD to Modbus Bridge

If you were using VFD commands, map them to Modbus operations:

**Old VFD Code**:
```c
ringbahn_v1_SetFrequencyRequest req = {
  .frequency_hz = 50.0f
};
```

**New Modbus Bridge Code**:
```c
// Write frequency to holding register (example address 0x1000)
ringbahn_v1_ModbusWriteSingleRegisterRequest req = {
  .slave_address = 1,
  .register_address = 0x1000,
  .value = 5000  // 50.00 Hz * 100
};
```

### 3. Update Device Command Usage

**Old**:
```c
typedef struct _ringbahn_v1_ADCDeviceCommand {
  pb_size_t which_command;
  union {
    ringbahn_v1_SystemInfoRequest system_info;  // tag 1
    ringbahn_v1_HeartbeatRequest heartbeat;     // tag 2 - REMOVED
    ringbahn_v1_PingCommand ping;               // tag 3 - MOVED TO 2
    // ...
  } command;
} ringbahn_v1_ADCDeviceCommand;
```

**New**:
```c
typedef struct _ringbahn_v1_ADCDeviceCommand {
  pb_size_t which_command;
  union {
    ringbahn_v1_SystemInfoRequest system_info;  // tag 1
    ringbahn_v1_PingCommand ping;               // tag 2
    // ...
  } command;
} ringbahn_v1_ADCDeviceCommand;
```

### 4. Update Imports

**Remove**:
```c
#include "devices/device_vfd.pb.h"
```

**Add**:
```c
#include "devices/device_modbus_bridge.pb.h"
```

### 5. Regenerate Code

```bash
./scripts/generate.sh
```

## Detailed Modbus Mapping

### VFD Operations to Modbus

| Old VFD Command | Modbus Equivalent |
|----------------|------------------|
| `SetFrequencyRequest` | Write Single/Multiple Holding Register |
| `SetDriveModeRequest` | Write Single Coil or Holding Register |
| `SetFailSafeRequest` | Write Single Coil or Holding Register |
| `ClearAlarmRequest` | Write Single Coil or Holding Register |
| `VFDGetStateRequest` | Read Holding Registers or Input Registers |

**Note**: The specific register addresses depend on your Modbus device documentation.

## Verification Checklist

- [ ] Removed all `HeartbeatRequest`/`HeartbeatResponse` usage
- [ ] Implemented transport-level keep-alive if needed
- [ ] Updated ping to use `PingCommand` at field tag 2
- [ ] Migrated VFD code to Modbus Bridge operations
- [ ] Updated all device command references
- [ ] Regenerated all protocol buffer code
- [ ] Updated imports to use `device_modbus_bridge.pb.h`
- [ ] Tested connectivity with new PingCommand
- [ ] Verified Modbus operations work correctly

---

# Migration Guide: Legacy to v1.1.0

This guide helps you migrate from the legacy flat structure to the new organized v1.0.0 structure.

## Overview of Changes

### Directory Structure

**Before (Legacy)**:

```
proto/
  ├── levitree.proto
  ├── device_adc.proto
  ├── device_vfd.proto
  ├── device_rover.proto
  ├── device_efc.proto (missing from CMakeLists)
  ├── discovery.proto
  ├── firmware_update.proto
  ├── heartbeat.proto
  └── enums.proto
nanopb/
  └── [generated .pb.c and .pb.h files]
```

**After (v1.0.0)**:

```
proto/
  ├── common/
  │   ├── enums.proto
  │   └── types.proto
  └── devices/
  ├── device_common.proto
  ├── device_routing.proto
      ├── device_adc.proto
  ├── device_digital_output.proto
      ├── device_rover.proto
      └── device_vfd.proto
generated/
  └── nanopb/
      └── [generated files organized by subdirectory]
```

### Package Names

**Before**: `package levitree;`  
**After**: `package ringbahn.v1;`

## Step-by-Step Migration

### 1. Update Your Build System

#### If using CMake:

Update your `CMakeLists.txt` or build configuration:

```cmake
# Old path
add_subdirectory(protobufs)

# No change needed - the updated CMakeLists.txt is backward compatible
# It will automatically use generated/nanopb/ if available, else nanopb/
```

#### If using custom build scripts:

Update proto file paths:

```bash
# Old
protoc --proto_path=proto \
       --nanopb_out=nanopb \
       proto/*.proto

# New
protoc --proto_path=proto \
       --nanopb_out=generated/nanopb \
       proto/**/*.proto
```

Or use the provided script:

```bash
./scripts/generate.sh
```

### 2. Update Code References

#### C/C++ Code

**Old includes**:

```c
#include "terranova.pb.h"
#include "device_adc.pb.h"
#include "discovery.pb.h"
```

**New includes**:

```c
#include "devices/device_common.pb.h"
#include "devices/device_adc.pb.h"
#include "devices/device_digital_output.pb.h"
#include "devices/device_routing.pb.h"
#include "common/types.pb.h"
#include "common/enums.pb.h"
```

**Frame assembly**:

```c
typedef struct __attribute__((packed)) {
  uint8_t start;
  uint16_t message_id;
  uint16_t payload_len;
  uint8_t sender_uuid[12];
  uint8_t recipient_uuid[12];
  uint8_t payload[256];
  uint16_t crc;
} ringbahn_frame_t;

ringbahn_v1_SystemInfoRequest req = ringbahn_v1_SystemInfoRequest_init_zero;
uint8_t payload[sizeof(((ringbahn_frame_t *)0)->payload)];

pb_ostream_t stream = pb_ostream_from_buffer(payload, sizeof(payload));
PB_ASSERT(pb_encode(&stream, ringbahn_v1_SystemInfoRequest_fields, &req));

ringbahn_frame_t frame = {
  .start = 0xA5,
  .message_id = next_request_id++, // Host assigns tracking ID
  .payload_len = (uint16_t)stream.bytes_written,
};
memcpy(frame.sender_uuid, my_uuid, sizeof(frame.sender_uuid));
memcpy(frame.recipient_uuid, target_uuid, sizeof(frame.recipient_uuid));
memcpy(frame.payload, payload, frame.payload_len);
// CRC over message_id, length, UUIDs, and payload (not the sentinel)
frame.crc = ringbahn_crc16((uint8_t *)&frame.message_id,
               offsetof(ringbahn_frame_t, crc) - offsetof(ringbahn_frame_t, message_id));
```

Decode by validating the CRC, then use device context (UUID, command state) to determine which protobuf descriptor to use (e.g., `ringbahn_v1_SystemInfoResponse_fields`). The `message_id` field is used by the host to match responses to requests.

#### Python Code

**Old imports**:

```python
import ringbahn_pb2
import device_adc_pb2
```

**New imports**:

```python
from common import enums_pb2, types_pb2
from devices import (
  device_common_pb2,
  device_adc_pb2,
  device_digital_output_pb2,
  device_routing_pb2,
)
```

**Usage**:

```python
import struct

req = device_common_pb2.SystemInfoRequest()
payload = req.SerializeToString()

message_id = next_request_id()  # Host assigns tracking ID

frame = bytearray()
frame.append(0xA5)  # Sentinel (not in CRC)
frame += struct.pack('<HH', message_id, len(payload))
frame += sender_uuid_bytes  # 12 bytes
frame += recipient_uuid_bytes  # 12 bytes
frame += payload
# CRC over message_id, length, UUIDs, and payload
frame += struct.pack('<H', crc16(frame[1:]))  # Skip sentinel

# Decode
message_id, length = struct.unpack_from('<HH', frame, 1)
payload = frame[1 + 2 + 2 + 12 + 12 : 1 + 2 + 2 + 12 + 12 + length]

# Use device context to determine message type
if is_system_info_response(device_context):
  resp = device_common_pb2.SystemInfoResponse()
  resp.ParseFromString(payload)
```

### 3. Update Nanopb Options

If you have custom `.options` files, update the package prefix:

**Old**:

```
ringbahn.ADCState.values max_count:8
```

**New**:

```
ringbahn.v1.ADCState.values max_count:8
```

### 4. Regenerate All Code

```bash
# Clean old generated files (optional - backup first!)
rm -rf nanopb/*.pb.c nanopb/*.pb.h

# Generate new code
./scripts/generate.sh

# Or using CMake
mkdir build && cd build
cmake ..
make
```

### 5. Test Your Application

1. Compile your application with the new generated code
2. Run unit tests
3. Test communication between devices
4. Verify all protocol messages work correctly

## Common Issues and Solutions

### Issue: "DeviceType not defined"

**Problem**: Missing import statement  
**Solution**: Add `import "common/enums.proto";` to your proto file

### Issue: Compilation errors with type names

**Problem**: Package name changed from `ringbahn` to `ringbahn.v1`  
**Solution**: Update all type references in your code to use `ringbahn_v1_` prefix

### Issue: Cannot find include files

**Problem**: Header file paths changed  
**Solution**: Update your include paths and include statements to use subdirectories

### Issue: CMake cannot find proto files

**Problem**: Proto files reorganized into subdirectories  
**Solution**: The updated CMakeLists.txt uses `file(GLOB)` to auto-discover files. If using custom CMake, update PROTO_SRCS list

### Issue: Nanopb options not applying

**Problem**: Options files use old package name  
**Solution**: Update `.options` files to use `ringbahn.v1.` prefix

## Verification Checklist

- [ ] All proto files generate without errors
- [ ] Code compiles without warnings
- [ ] All imports use new directory structure
- [ ] Package names updated to `ringbahn.v1`
- [ ] Nanopb options files updated
- [ ] Unit tests pass
- [ ] Device communication works
- [ ] No hardcoded references to old package names
- [ ] Build scripts updated
- [ ] CI/CD pipelines updated (if applicable)

## Rollback Plan

If you need to rollback to the legacy structure:

1. Keep the old proto files (they're still in the repository for reference)
2. The CMakeLists.txt supports both `nanopb/` and `generated/nanopb/` directories
3. Checkout the previous commit before migration
4. Rebuild with old configuration

## Backward Compatibility

The new structure maintains backward compatibility:

- CMakeLists.txt checks for both old and new output directories
- Old proto files remain in repository (in root `proto/` for reference)
- Generated code structure can coexist during migration period

## Timeline Recommendation

1. **Week 1**: Update build system and regenerate code
2. **Week 2**: Update code references and test in development
3. **Week 3**: Test in staging environment
4. **Week 4**: Deploy to production

## Support

If you encounter issues during migration:

1. Check this guide for common issues
2. Review the [PROTOCOL.md](PROTOCOL.md) documentation
3. Check the [CHANGELOG.md](CHANGELOG.md) for detailed changes
4. Open an issue on GitHub with:
   - Your current setup
   - Error messages
   - Steps to reproduce

## Additional Resources

- [README.md](../README.md) - Quick start and usage guide
- [PROTOCOL.md](PROTOCOL.md) - Detailed protocol specification
- [CHANGELOG.md](CHANGELOG.md) - Complete list of changes

---

**Last Updated**: December 15, 2025  
**Applies to**: Migration from legacy to v1.1.0
