# Terranova Protocol Specification

## Overview

The Terranova protocol is a binary message-passing protocol designed for distributed control systems. It uses Protocol Buffers (protobuf) for efficient serialization and is optimized for embedded systems using nanopb.

## Protocol Version

**Current Version**: 1.2 (`ringbahn.v1`)

## Architecture

### Ringbahn Frame

Ringbahn replaces the monolithic envelope message with a binary frame that keeps routing information outside the protobuf payload. Every frame uses the same base layout:

| Field            | Size    | Description                                         |
| ---------------- | ------- | --------------------------------------------------- |
| `0xA5`           | 1 byte  | Start-of-frame sentinel                             |
| `message_id`     | 2 bytes | Host-assigned tracking ID for request/response pair |
| `payload_length` | 2 bytes | Length of the payload bytes                         |
| `payload`        | N bytes | Serialized protobuf message                         |
| `crc16`          | 2 bytes | CRC-16 over message_id, payload_length, and payload |

#### UART Variant with Device UUIDs

UART transports add two 12-byte fields ahead of the payload:

1. **Sender UUID** – 12-byte `DeviceUUID` identifying the originator
2. **Recipient UUID** – 12-byte `DeviceUUID` identifying the target

This keeps routing metadata standardized while still allowing other transports (CAN, SPI, etc.) to omit the UUIDs if the link already encodes addressing.

#### Validating Frames

The CRC16 is computed over the message ID, payload length, UUID fields (if present), and payload bytes. The sentinel byte is NOT included in the CRC. Receivers MUST validate the CRC before attempting to parse the payload.

### Device UUIDs

`common/types.proto` now defines `DeviceUUID`, a fixed 12-byte identifier referenced by both the transport header and higher-level payloads such as `DeviceInfo`. UUIDs stay stable for the lifetime of the device and replace the older "Endpoint" structure.

### Message IDs

The `message_id` field is an arbitrary 16-bit value assigned by the host system for request tracking and response association. The ID does not encode payload type information—devices must use out-of-band context (device type, command semantics) to determine how to deserialize the protobuf payload.

The host is free to use any numbering scheme for tracking outstanding requests. Common patterns include sequential counters or request/response pairing conventions, but the protocol itself places no requirements on ID assignment.

## Communication Patterns

### 1. Request-Response

Most device interactions follow a request-response pattern:

```
Client → [Request] → Device
Client ← [Response] ← Device
```

The host assigns a `message_id` to each request and the device echoes that same ID in its response, allowing the host to correlate replies with pending requests.

### 2. State Updates

Devices may publish unsolicited state updates (e.g., `ADCState`, `VFDState`) or respond to explicit state query requests. The host must track device types to determine which protobuf message to deserialize.

### 3. Discovery

The discovery protocol allows dynamic device detection:

1. **RoutingIdentifyActiveDeviceRequest/Response** – Reports the device currently bridged to the UART session.
2. **RoutingAttachedDevicesRequest/Response** – Returns the full list of devices (as `DeviceInfo`) detected on the CAN bus.
3. **RoutingSetChannelIdentityRequest/Response** – Activates or deactivates CAN channels from the routing firmware.

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
| `DEVICE_TYPE_ROUTING`      | 3     | UART-to-CAN routing bridge            |
| `DEVICE_TYPE_ADC`          | 4     | Analog-to-Digital Converter           |
| `DEVICE_TYPE_SD_ADC`       | 5     | Sigma-Delta ADC                       |
| `DEVICE_TYPE_VFD`          | 6     | Variable Frequency Drive (deprecated) |
| `DEVICE_TYPE_ROVER`        | 7     | Mobile robot platform                 |
| `DEVICE_TYPE_DIGITAL_OUT`  | 8     | Digital output module                 |
| `DEVICE_TYPE_RS485_BRIDGE` | 9     | RS485 communication bridge            |

## Device-Specific Protocols

`proto/devices/device_common.proto` contains helper payloads shared by every device:

- `SystemInfoRequest` / `SystemInfoResponse` – queries hardware/software metadata and returns `DeviceInfo` (with device UUID).
- `HeartbeatRequest` / `HeartbeatResponse` – lightweight liveness checks.
- `AcknowledgeResponse` and `ErrorResponse` – minimalist success/error replies.

### Routing Device (UART-to-CAN Bridge)

Routing devices (DeviceType `DEVICE_TYPE_ROUTING`) terminate the UART Ringbahn link and fan commands out to the CAN bus. Their proto covers three areas:

- **State**: `RoutingDeviceState` reports overall CAN health (connected node count and optional `GPSState`).
- **Discovery**: `RoutingAttachedDevices*`, `RoutingIdentifyActiveDevice*`, and `RoutingSetChannelIdentity*` replace the legacy discovery service. All results are expressed as `DeviceInfo` structs so controllers can match UUIDs to the Ringbahn header.
- **Firmware**:
  - `InternalOta*` commands update the routing MCU itself and return compact `InternalOtaStatus` structures.
  - `Terraboot*` commands map 1:1 to the [Terraboot/Katapult protocol](https://github.com/Levitree/terraboot/blob/master/protocol.md): `connect (0x11)`, `send_block (0x12)`, `eof (0x13)`, `request_block (0x14)`, `complete (0x15)`, and `get_canbus_id (0x16)`. Each request includes the destination CAN node ID plus the exact payload required by the bootloader, and every response echoes structured data (protocol version, block offsets, UUIDs, etc.) via `CommandResult` fields.

All other devices now live exclusively on CAN, so the routing bridge is the single place where the UART host performs discovery or firmware management.

#### Discovery Flow

1. Issue `RoutingAttachedDevicesRequest` to audit the full CAN roster. The response returns up to 32 `DeviceInfo` entries including UUID, type, and firmware version pulled from each node's `SystemInfoResponse`.
2. Use `RoutingIdentifyActiveDeviceRequest` to confirm which CAN node is currently bound to the UART session (useful while cycling multiple channels through one bridge).
3. Toggle buses by sending `RoutingSetChannelIdentityRequest` with a `channel` index and `active` flag. This is the declarative replacement for the old `SetChannelIdentityRequest` service call.

#### Firmware Update Flow

- **Internal OTA (Routing Firmware)**

  1. Send `InternalOtaBeginRequest` with the total image size and firmware version.
  2. Stream chunks with `InternalOtaWriteRequest` (≤4096 bytes each) until `InternalOtaStatus.next_offset` reaches `image_size`.
  3. Finalize via `InternalOtaEndRequest` to trigger optional SHA-256 validation, or `InternalOtaAbortRequest` to roll back. `InternalOtaSetBootPartitionRequest` only needs to run after a successful upload when you want to boot the new slot.

- **Terraboot CAN Bridge**
  1. Connect to the target node with `TerrabootConnectRequest` (Terraboot `0x11`). Read block size/start address from the response.
  2. Loop over `TerrabootSendBlockRequest` (0x12) with up to 256 bytes per block. The response echoes the accepted address, enabling retransmit logic.
  3. Once all blocks are delivered, call `TerrabootEofRequest` (0x13) then `TerrabootCompleteRequest` (0x15) to finalize the flash session.
  4. If a node requests retransmission, issue `TerrabootRequestBlockRequest` (0x14) to fetch the offending chunk from the bridge cache.
  5. Use `TerrabootGetIdRequest` (0x16) any time you need the Terraboot CAN UUID to reconcile with inventory systems.

### ADC (Analog-to-Digital Converter)

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
  sint32 left_right = 2;        // -100..100 steering input
  sint32 forward_backward = 3;  // -100..100 throttle input
}
```

### Digital Output

**Purpose**: Drive PWM or simple on/off outputs.

**Messages**:

```protobuf
message PWMChannelValue {
  int32 channel_number = 1; // 0-7
  int32 duty_cycle_pct = 2; // 0-100
  int32 frequency_hz = 3;   // Optional override, 0=default
}

message DigitalOutputState {
  repeated PWMChannelValue values = 1; // Up to 8 channels
}
```

## Error Handling

### Standard Responses

**Acknowledge Response**: Simple acknowledgment

```protobuf
message AcknowledgeResponse {}
```

**CommandResult**: Embedded inside most device responses

```protobuf
message CommandResult {
  bool success = 1;
  int32 error_code = 2;
  string detail = 3;
}
```

**Error Response**: Detailed error information for asynchronous faults

```protobuf
message ErrorResponse {
  int32 error_code = 1;
  int64 timestamp_ms = 2;
  string detail = 3;
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

| Field                                       | Max Size   | Notes                      |
| ------------------------------------------- | ---------- | -------------------------- |
| `DeviceUUID.value`                          | 12 bytes   | Fixed length               |
| `CommandResult.detail`                      | 64 bytes   | Optional string            |
| `DigitalOutputState.values`                 | 8 items    | Array                      |
| `ADCState.values`                           | 8 items    | Array                      |
| `RoutingAttachedDevicesResponse.devices`    | 32 items   | Array                      |
| `InternalOtaWriteRequest.data`              | 4096 bytes | Firmware chunk             |
| `InternalOtaStatus.sha256_hash`             | 32 bytes   | Fixed length digest        |
| `TerrabootSendBlockRequest.data`            | 256 bytes  | Terraboot block payload    |
| `TerrabootRequestBlockResponse.data`        | 256 bytes  | Terraboot block payload    |
| `TerrabootConnectResponse.mcu_type`         | 32 bytes   | Null-terminated string     |
| `TerrabootConnectResponse.software_version` | 64 bytes   | Null-terminated string     |
| `TerrabootGetIdResponse.can_uuid`           | 12 bytes   | Terraboot padded 6-byte ID |

### GPS Data

For devices with GPS capabilities:

```protobuf
message GPSState {
  double latitude = 1;      // degrees
  double longitude = 2;     // degrees
  float altitude = 3;       // meters
  float speed = 4;          // m/s
  float heading = 5;        // degrees
  int32 satellites = 6;     // count
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
2. Add corresponding `.options` file for nanopb
3. Update documentation (README + this file) with the new message descriptions

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
