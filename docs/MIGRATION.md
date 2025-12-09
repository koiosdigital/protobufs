# Migration Guide: Legacy to v1.0.0

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
  ├── core/
  │   ├── routing.proto
  │   ├── system.proto
  │   └── heartbeat.proto
  ├── services/
  │   ├── discovery.proto
  │   └── firmware_update.proto
  └── devices/
      ├── device_adc.proto
      ├── device_efc.proto
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
#include "core/routing.pb.h"
#include "devices/device_adc.pb.h"
#include "services/discovery.pb.h"
#include "common/types.pb.h"
#include "common/enums.pb.h"
```

**Old type references**:

```c
ringbahn_DeviceType device_type = ringbahn_DEVICE_TYPE_ADC;
ringbahn_RoutableMessage msg = ringbahn_RoutableMessage_init_zero;
```

**New type references**:

```c
ringbahn_v1_DeviceType device_type = ringbahn_v1_DEVICE_TYPE_ADC;
ringbahn_v1_RoutableMessage msg = ringbahn_v1_RoutableMessage_init_zero;
```

#### Python Code

**Old imports**:

```python
import ringbahn_pb2
import device_adc_pb2
```

**New imports**:

```python
from common import enums_pb2, types_pb2
from core import routing_pb2, system_pb2
from devices import device_adc_pb2
```

**Old usage**:

```python
msg = ringbahn_pb2.RoutableMessage()
device = ringbahn_pb2.DEVICE_TYPE_ADC
```

**New usage**:

```python
msg = routing_pb2.RoutableMessage()
device = enums_pb2.DEVICE_TYPE_ADC
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

**Last Updated**: December 9, 2025  
**Applies to**: Migration from legacy to v1.0.0
