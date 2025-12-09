# Terranova Protocol Specification

## Overview

The Terranova protocol is a binary message-passing protocol designed for distributed control systems. It uses Protocol Buffers (protobuf) for efficient serialization and is optimized for embedded systems using nanopb.

## Protocol Version

**Current Version**: 1.0 (`ringbahn.v1`)

## Architecture

### Message Routing

All protocol messages are wrapped in a `RoutableMessage` envelope that provides source and destination addressing:

```protobuf
message RoutableMessage {
  Endpoint source = 1;        // Originating device
  Endpoint destination = 2;   // Target device
  oneof payload { ... }       // Actual message content
}
```

### Endpoints

An endpoint uniquely identifies a device in the Terranova network:

```protobuf
message Endpoint {
  bytes mcu_id = 1;  // 16-byte unique MCU identifier
}
```

The `mcu_id` is typically the device's hardware serial number or MAC address.

## Communication Patterns

### 1. Request-Response

Most device interactions follow a request-response pattern:

```
Client → [Request] → Device
Client ← [Response] ← Device
```

Example: System Information Query

```protobuf
// Request
SystemInfoRequest system_info_req = 3;

// Response
SystemInfoResponse system_info_res = 4;
```

### 2. State Updates

Devices can broadcast their state periodically or on-demand:

```
Controller → [StateUpdateRequest] → Device
Controller ← [StateUpdateResponse] ← Device
```

### 3. Discovery

The discovery protocol allows dynamic device detection:

1. **Identify Active Device**: Query which device is currently active on a channel
2. **Attached Devices**: List all devices connected to a hub
3. **Set Channel Identity**: Configure channel assignments

### 4. Heartbeat

Periodic heartbeat messages maintain connection state:

```protobuf
HeartbeatRequest → Device
HeartbeatResponse ← Device (with timestamp)
```

## Device Types

### Supported Device Types

| Type                       | Value | Description                           |
| -------------------------- | ----- | ------------------------------------- |
| `DEVICE_TYPE_HUB`          | 1     | Main hub/coordinator                  |
| `DEVICE_TYPE_NODE`         | 2     | Generic node module                   |
| `DEVICE_TYPE_ADC`          | 4     | Analog-to-Digital Converter           |
| `DEVICE_TYPE_SD_ADC`       | 5     | Sigma-Delta ADC                       |
| `DEVICE_TYPE_VFD`          | 6     | Variable Frequency Drive (deprecated) |
| `DEVICE_TYPE_ROVER`        | 7     | Mobile robot platform                 |
| `DEVICE_TYPE_DIGITAL_OUT`  | 8     | Digital output module                 |
| `DEVICE_TYPE_RS485_BRIDGE` | 9     | RS485 communication bridge            |

## Device-Specific Protocols

### ADC (Analog-to-Digital Converter)

**Purpose**: Read analog sensor values

**Messages**:

- `ADCCommandRequest` / `ADCCommandResponse`: Currently read-only
- `ADCState`: Contains array of channel readings

**Usage**:

```protobuf
message ADCState {
  repeated ADCChannelValue values = 1;  // Up to 8 channels
}

message ADCChannelValue {
  int32 channel_number = 1;
  int32 adc_value = 2;  // Raw ADC value
}
```

### VFD (Variable Frequency Drive)

**Purpose**: Control motor speed and direction

**Messages**:

- Set frequency (Hz)
- Set drive mode (stop/forward/reverse)
- Set fail-safe mode
- Clear alarms

**State Information**:

```protobuf
message VFDState {
  float frequency_hz = 1;
  float power_w = 2;
  float current_a = 3;
  float voltage_v = 4;
  VFDDriveMode drive_mode = 5;
  VFDFailSafeMode fail_safe_mode = 6;
  int32 alarm_code = 7;
  float min_frequency_hz = 8;
  float max_frequency_hz = 9;
}
```

### Rover

**Purpose**: Control mobile robot movement

**Commands**:

```protobuf
message RoverMovementCommand {
  bool tracks_active = 1;
  int32 left_right = 2;        // 0-100, 50=stopped
  int32 forward_backward = 3;   // 0-100, 50=stopped
}
```

### EFC (Electronic Frequency Converter)

**Purpose**: Control frequency converter channels

**Messages**:

```protobuf
message EFCChannelValue {
  int32 channel_number = 1;
  int32 efc_value_pct = 2;  // 0-100%
}
```

## Services

### Discovery Service

**Purpose**: Automatic device detection and identification

**Operations**:

1. **List Attached Devices**:

   ```protobuf
   AttachedDevicesRequest → Hub
   AttachedDevicesResponse ← Hub (list of DeviceInfo)
   ```

2. **Identify Active Device**:

   ```protobuf
   IdentifyActiveDeviceRequest → Hub
   DeviceInfo ← Hub
   ```

3. **Set Channel Identity**:
   ```protobuf
   SetChannelIdentityRequest → Hub
   (activates/deactivates channel)
   ```

### Firmware Update Service

**Purpose**: Over-the-air firmware updates

**Flow**:

1. **Start Update**:

   ```protobuf
   StartUpdateRequest (total_size, firmware_version)
   ```

2. **Send Data Blocks**:

   ```protobuf
   UpdateDataBlockRequest (data_block, block_offset, block_size)
   // Repeat for all blocks
   ```

3. **Finish Update**:
   ```protobuf
   FinishUpdateRequest (do_reboot, checksum)
   ```

Each step returns a `FirmwareUpdateResponse` with success status and progress information.

## Error Handling

### Standard Responses

**Acknowledge Response**: Simple acknowledgment

```protobuf
message AcknowledgeResponse {}
```

**Error Response**: Detailed error information

```protobuf
message ErrorResponse {
  string error_message = 1;
  int32 error_code = 2;
}
```

### Error Codes

Error codes are application-specific but follow these conventions:

- `0`: Success
- `1-99`: General errors
- `100-199`: Communication errors
- `200-299`: Device-specific errors
- `300-399`: Protocol errors

## Data Types and Constraints

### Nanopb Constraints

The protocol uses nanopb for embedded C generation with the following constraints:

| Field                                  | Max Size  | Notes          |
| -------------------------------------- | --------- | -------------- |
| `Endpoint.mcu_id`                      | 16 bytes  | Fixed length   |
| `SystemInfoResponse.hardware_codename` | 32 bytes  | Fixed length   |
| `SystemInfoResponse.software_codename` | 32 bytes  | Fixed length   |
| `ErrorResponse.error_message`          | 64 bytes  | Fixed length   |
| `ADCState.values`                      | 8 items   | Array          |
| `EFCState.values`                      | 8 items   | Array          |
| `AttachedDevicesResponse.devices`      | 32 items  | Array          |
| `UpdateDataBlockRequest.data_block`    | 256 bytes | Firmware chunk |

### GPS Data

For devices with GPS capabilities:

```protobuf
message GPSState {
  bool has_gps = 1;
  double latitude = 2;      // degrees
  double longitude = 3;     // degrees
  float altitude = 4;       // meters
  float speed = 5;          // m/s
  float heading = 6;        // degrees
  int32 satellites = 7;     // count
}
```

## Protocol Evolution

### Versioning Strategy

1. **Package versioning**: All types use `package ringbahn.v1`
2. **Field numbering**: Never reuse or change field numbers
3. **Backward compatibility**: New fields are optional
4. **Deprecation**: Mark deprecated fields in comments

### Adding New Features

To add new device types or commands:

1. Create new proto file in appropriate subdirectory
2. Add to `RoutableMessage` payload oneof
3. Assign unique field numbers (never reuse)
4. Add corresponding `.options` file for nanopb
5. Update documentation

### Breaking Changes

Breaking changes require a new package version (e.g., `ringbahn.v2`).

Examples of breaking changes:

- Removing fields
- Changing field types
- Renaming messages or fields
- Changing field numbers

## Security Considerations

### Current Implementation

- No built-in encryption (transport layer responsibility)
- No authentication mechanism
- MCU ID used for device identification

### Recommendations

For production deployments:

1. Use TLS/DTLS at transport layer
2. Implement device authentication
3. Add message signing/verification
4. Implement access control lists
5. Rate limiting and DDoS protection

## Performance Characteristics

### Message Sizes

Typical message sizes (serialized):

- `HeartbeatRequest`: ~2 bytes
- `SystemInfoRequest`: ~2 bytes
- `ADCState` (8 channels): ~80 bytes
- `VFDState`: ~40 bytes
- `FirmwareUpdateDataBlock`: ~260 bytes

### Throughput

- Nanopb encoding/decoding: ~1-10 μs per message (typical MCU)
- Maximum message size: Limited by transport layer (typically 1KB-4KB)
- Recommended update rates:
  - Heartbeat: 1 Hz
  - State updates: 0.1-10 Hz (device-dependent)
  - Commands: On-demand

## Testing

### Validation

Use the validation script to check proto files:

```bash
./scripts/validate.sh
```

### Unit Testing

Example test structure:

1. Serialize message in language A
2. Deserialize in language B
3. Verify field values match
4. Test round-trip serialization

### Integration Testing

1. Test request-response pairs
2. Verify error handling
3. Test state updates
4. Validate discovery flow
5. Test firmware update process

## Examples

See the main README for code generation examples and integration guides.

## References

- [Protocol Buffers Language Guide](https://protobuf.dev/programming-guides/proto3/)
- [Nanopb Documentation](https://jpa.kapsi.fi/nanopb/)
- [Buf Style Guide](https://buf.build/docs/best-practices/style-guide)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

**Document Version**: 1.0  
**Last Updated**: December 9, 2025  
**Status**: Current
