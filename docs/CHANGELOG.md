# Changelog

All notable changes to the Terranova Protocol Buffers will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-12-15

### Added

- Introduced the Ringbahn binary frame format with CRC16 validation, UART UUID addressing, and documented message ID ranges.
- Added `devices/device_common.proto` for shared commands (system info, heartbeat, acknowledgements, standard errors).
- Added `DeviceUUID` and `CommandResult` helper messages to `common/types.proto`, including nanopb sizing constraints.

### Changed

- Removed the `core/` protos and the `RoutableMessage` envelope in favor of device-specific payloads keyed by message IDs.
- All device protos now import `DeviceUUID` and `CommandResult`, and responses use the shared `CommandResult` structure.
- Documentation (`README.md`, `docs/PROTOCOL.md`, `docs/QUICK_REFERENCE.md`, `docs/MIGRATION.md`) rewritten to describe Ringbahn framing, device UUIDs, and the new workflow for assigning message IDs.
- Updated `CMakeLists.txt` to drop references to the old core sources and include the new device_common/digital_output outputs.

### Fixed

- Removed stale references to `device_efc` and the legacy Endpoint structure throughout the docs.

## [1.0.0] - 2025-12-09

### Added - Repository Restructuring

- **New directory structure** for better organization:

  - `proto/common/` - Shared types and enumerations
  - `proto/core/` - Core protocol messages
  - `proto/services/` - Service-level protocols
  - `proto/devices/` - Device-specific protocols
  - `generated/nanopb/` - Generated code output
  - `docs/` - Comprehensive documentation
  - `scripts/` - Build and utility scripts

- **Versioned package names**: All proto files now use `package ringbahn.v1` for better API evolution

- **Split monolithic proto files**:

  - `terranova.proto` split into:
    - `common/types.proto` - Common message types (DeviceUUID, GPSState, DeviceInfo)
    - `core/routing.proto` - Message routing and state management
    - `core/system.proto` - System information and error handling
    - `core/heartbeat.proto` - Keep-alive messages

- **Enhanced firmware update protocol**:

  - Added `total_size` field to `StartUpdateRequest`
  - Added `firmware_version` field for version tracking
  - Added `checksum` field to `FinishUpdateRequest` for integrity verification
  - Added `block_size` field to `UpdateDataBlockRequest`
  - Added `bytes_received` progress tracking to `FirmwareUpdateResponse`

- **Improved error handling**:

  - Added `error_code` field to `ErrorResponse` for structured error reporting
  - Increased error message buffer size to 64 bytes

- **Build tooling**:

  - Created `scripts/generate.sh` for automated code generation
  - Created `scripts/validate.sh` for proto file validation
  - Added `buf.yaml` and `buf.gen.yaml` for modern protobuf tooling
  - Updated `CMakeLists.txt` with organized source lists and auto-discovery

- **Documentation**:

  - Comprehensive `README.md` with quick start guide, installation instructions, and best practices
  - Detailed `PROTOCOL.md` specification document
  - This `CHANGELOG.md` for tracking version history

- **Nanopb options files** organized by proto file location with proper versioned package names

### Changed

- **File organization**: Proto files moved from flat structure to organized subdirectories
- **Import paths**: Updated all import statements to use new directory structure
- **Generated code location**: Now outputs to `generated/nanopb/` (with backward compatibility for `nanopb/`)
- **CMakeLists.txt**: Enhanced with better organization, auto-discovery of proto files, and support for both old and new output paths

### Fixed

- **Missing device_efc.proto**: Now properly included in build configuration
- **Import inconsistencies**: All imports now properly reference the correct paths
- **Nanopb options**: Updated to match new package versioning (`ringbahn.v1.*`)

### Documentation

- Added comprehensive protocol specification in `docs/PROTOCOL.md` covering:

  - Architecture and message routing
  - Communication patterns
  - Device-specific protocols
  - Error handling
  - Security considerations
  - Performance characteristics
  - Testing guidelines

- Enhanced README with:
  - Clear repository structure diagram
  - Installation instructions for multiple platforms
  - Code generation examples
  - Integration guides
  - Development best practices
  - Migration guide from old structure

## [0.9.0] - Pre-restructuring (Legacy)

### Included Devices

- ADC (Analog-to-Digital Converter)
- VFD (Variable Frequency Drive)
- Rover (Mobile robot control)
- EFC (Electronic Frequency Converter)

### Included Services

- Discovery protocol
- Firmware update protocol
- Heartbeat mechanism
- System information queries

### Structure

- Flat proto file structure
- Package name: `ringbahn` (unversioned)
- Generated files in `nanopb/` directory
- Basic CMake configuration

---

## Version Compatibility

### v1.0.0 Migration Notes

**Breaking Changes from 0.9.0:**

- Package names changed from `ringbahn` to `ringbahn.v1`
- Import paths changed to use subdirectories
- Nanopb options namespace updated

**Migration Steps:**

1. Update your build system to use new proto file paths
2. Update imports in your code to reference `ringbahn.v1` package
3. Regenerate all protocol buffer code
4. Update any hardcoded package references in your application

**Backward Compatibility:**

- CMakeLists.txt supports both old (`nanopb/`) and new (`generated/nanopb/`) output directories
- Old proto files remain in repository for reference during migration

### Future Versions

- **v2.0.0**: Reserved for major protocol changes (future)
- Minor versions (v1.x.0): New features, backward compatible
- Patch versions (v1.0.x): Bug fixes and documentation updates

---

## Guidelines for Contributors

### Adding to Changelog

When contributing, please update this file with:

- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Features to be removed in future versions
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security improvements

### Version Numbering

- **Major version** (x.0.0): Breaking changes
- **Minor version** (1.x.0): New features, backward compatible
- **Patch version** (1.0.x): Bug fixes and documentation

---

**Note**: Versions prior to 1.0.0 were internal development versions and are not fully documented here.
