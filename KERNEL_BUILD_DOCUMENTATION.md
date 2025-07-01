# Android Kernel Build Script Documentation

## Overview

This comprehensive documentation details every function and process in the `build_garnet_kernel.sh` script, which automatically builds Android kernels for the Redmi Note 13 Pro 5G (garnet) with integrated Sukisu Ultra (KernelSU fork) and SUSFS root hiding capabilities.

## Table of Contents

1. [Script Configuration](#script-configuration)
2. [Logging Functions](#logging-functions)
3. [Dependency Management](#dependency-management)
4. [Toolchain Setup](#toolchain-setup)
5. [Repository Management](#repository-management)
6. [Sukisu Ultra Integration](#sukisu-ultra-integration)
7. [SUSFS Integration](#susfs-integration)
8. [Kernel Configuration](#kernel-configuration)
9. [Build Process](#build-process)
10. [Output Generation](#output-generation)
11. [AnyKernel3 Packaging](#anykernel3-packaging)
12. [Command Line Interface](#command-line-interface)
13. [Main Execution Flow](#main-execution-flow)

---

## Script Configuration

### Global Variables

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/garnet_kernel_build"
KERNEL_DIR="${BUILD_DIR}/kernel"
DT_DIR="${BUILD_DIR}/devicetrees"
MODULES_DIR="${BUILD_DIR}/modules"
SUKISU_DIR="${BUILD_DIR}/sukisu-ultra"
SUSFS_DIR="${BUILD_DIR}/susfs"
```

**Detailed Explanation:**
- **SCRIPT_DIR**: Dynamically determines the absolute path of the script's location using `dirname` and `pwd`, ensuring the script works regardless of where it's called from
- **BUILD_DIR**: Creates a dedicated build workspace within the script directory to contain all kernel-related repositories and build artifacts
- **KERNEL_DIR**: Stores the main kernel source code from the garnet-random repository
- **DT_DIR**: Contains device tree sources that define hardware configurations specific to the garnet device
- **MODULES_DIR**: Houses kernel modules source code for additional functionality
- **SUKISU_DIR**: Dedicated directory for Sukisu Ultra (KernelSU fork) source code and integration files
- **SUSFS_DIR**: Contains SUSFS (root hiding filesystem) source code and patches

### Feature Flags

```bash
ENABLE_SUKISU_ULTRA=true
ENABLE_SUSFS=true
ENABLE_ANYKERNEL3=true
```

**Detailed Explanation:**
- **ENABLE_SUKISU_ULTRA**: Controls whether to integrate Sukisu Ultra (enhanced KernelSU fork) into the kernel build
- **ENABLE_SUSFS**: Determines if SUSFS root hiding filesystem should be integrated
- **ENABLE_ANYKERNEL3**: Toggles creation of flashable ZIP packages for custom recovery installation

### Color Definitions

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
```

**Detailed Explanation:**
These ANSI escape codes provide colored terminal output for better user experience and log readability.

---

## Logging Functions

### log_info()

**Purpose**: Displays informational messages in blue color
**Parameters**: `$1` - Message string to display
**Usage**: `log_info "Setting up build environment"`

**Detailed Process**:
1. Receives message as first parameter
2. Formats message with blue color prefix `[INFO]`
3. Uses `echo -e` to interpret escape sequences
4. Resets color to normal after message

### log_success()

**Purpose**: Displays success messages in green color
**Parameters**: `$1` - Success message string
**Usage**: `log_success "Kernel compilation completed"`

**Detailed Process**:
1. Formats success message with green `[SUCCESS]` prefix
2. Provides visual confirmation of completed operations
3. Helps users identify successful completion of build stages

### log_warning()

**Purpose**: Displays warning messages in yellow color
**Parameters**: `$1` - Warning message string
**Usage**: `log_warning "Patch failed to apply cleanly"`

**Detailed Process**:
1. Highlights potential issues that don't stop execution
2. Uses yellow color to indicate caution
3. Allows build to continue while alerting user to potential problems

### log_error()

**Purpose**: Displays error messages in red color
**Parameters**: `$1` - Error message string
**Usage**: `log_error "Required dependency not found"`

**Detailed Process**:
1. Formats critical error messages in red
2. Typically followed by script termination
3. Provides clear indication of build-stopping issues

---

## Dependency Management

### check_dependencies()

**Purpose**: Verifies all required build tools and libraries are installed
**Parameters**: None
**Returns**: Exits with code 1 if dependencies missing

**Detailed Process**:

1. **Dependency Array Definition**:
   ```bash
   local deps=("git" "make" "bc" "bison" "flex" "libssl-dev" "libelf-dev" "zip")
   ```
   - **git**: Version control system for repository cloning and updates
   - **make**: GNU Make build system for kernel compilation
   - **bc**: Basic Calculator, required for kernel build scripts
   - **bison**: Parser generator for kernel configuration parsing
   - **flex**: Fast lexical analyzer generator for kernel build
   - **libssl-dev**: OpenSSL development libraries for cryptographic functions
   - **libelf-dev**: ELF library development files for binary manipulation
   - **zip**: Archive utility for creating flashable packages

2. **Dependency Checking Logic**:
   ```bash
   for dep in "${deps[@]}"; do
       if ! command -v "$dep" &> /dev/null && ! dpkg -l | grep -q "$dep"; then
           missing_deps+=("$dep")
       fi
   done
   ```
   - Uses `command -v` to check if executable is in PATH
   - Falls back to `dpkg -l` for library packages that may not have executables
   - Redirects output to `/dev/null` to suppress verbose output
   - Accumulates missing dependencies in array

3. **Error Handling**:
   - If any dependencies are missing, displays complete list
   - Provides exact installation command for user convenience
   - Terminates script execution to prevent build failures

**Arch Linux Specific Notes**:
- Package names differ from Debian/Ubuntu
- Script detects system and suggests appropriate package manager commands

---

## Toolchain Setup

### setup_toolchain()

**Purpose**: Configures cross-compilation environment for ARM64 architecture
**Parameters**: None
**Returns**: Exits with code 1 if no suitable toolchain found

**Detailed Process**:

1. **Android NDK Detection**:
   ```bash
   if [ -n "$ANDROID_NDK_HOME" ] && [ -d "$ANDROID_NDK_HOME" ]; then
       export CROSS_COMPILE="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android-"
       export CC="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang"
   ```
   - Checks for ANDROID_NDK_HOME environment variable
   - Verifies NDK directory exists
   - Sets up LLVM-based toolchain with API level 29 target
   - Preferred option for Android kernel compilation

2. **System Toolchain Fallback**:
   ```bash
   elif command -v aarch64-linux-gnu-gcc &> /dev/null; then
       export CROSS_COMPILE="aarch64-linux-gnu-"
       export CC="aarch64-linux-gnu-gcc"
   ```
   - Falls back to system-installed cross-compiler
   - Uses GNU toolchain for ARM64 target
   - Available through package managers on most Linux distributions

3. **Architecture Configuration**:
   ```bash
   export ARCH=arm64
   export SUBARCH=arm64
   ```
   - Sets target architecture for kernel build system
   - ARCH tells kernel build system the target platform
   - SUBARCH provides additional architecture-specific information

**Toolchain Selection Priority**:
1. Android NDK (if available) - Optimized for Android
2. System GNU toolchain - Generic ARM64 support
3. Error if neither available

---

## Repository Management

### clone_repositories()

**Purpose**: Downloads and manages all required source code repositories
**Parameters**: None
**Returns**: None (logs success/failure)

**Detailed Process**:

1. **Build Directory Creation**:
   ```bash
   mkdir -p "$BUILD_DIR"
   cd "$BUILD_DIR"
   ```
   - Creates build workspace if it doesn't exist
   - Changes to build directory for repository operations

2. **Main Kernel Repository**:
   ```bash
   if [ ! -d "$KERNEL_DIR" ]; then
       git clone https://github.com/garnet-random/android_kernel_xiaomi_sm7435.git kernel
   else
       cd "$KERNEL_DIR" && git pull && cd "$BUILD_DIR"
   fi
   ```
   - **Repository**: `garnet-random/android_kernel_xiaomi_sm7435`
   - **Contents**: Main kernel source code for SM7435 chipset
   - **Update Logic**: Clones if new, pulls latest changes if exists
   - **Chipset**: Snapdragon 7s Gen 2 (SM7435) specific optimizations

3. **Device Tree Repository**:
   ```bash
   git clone https://github.com/garnet-random/android_kernel_xiaomi_sm7435-devicetrees.git devicetrees
   ```
   - **Repository**: `garnet-random/android_kernel_xiaomi_sm7435-devicetrees`
   - **Contents**: Hardware description files for garnet device
   - **Purpose**: Defines GPIO mappings, clock configurations, power management
   - **Format**: Device Tree Source (.dts) and Device Tree Include (.dtsi) files

4. **Kernel Modules Repository**:
   ```bash
   git clone https://github.com/garnet-random/android_kernel_xiaomi_sm7435-modules.git modules
   ```
   - **Repository**: `garnet-random/android_kernel_xiaomi_sm7435-modules`
   - **Contents**: Loadable kernel modules for extended functionality
   - **Examples**: Camera drivers, audio codecs, connectivity modules
   - **Advantage**: Modular design allows selective loading

**Repository Update Strategy**:
- Checks for existing directories before cloning
- Performs `git pull` to update existing repositories
- Ensures latest source code without re-downloading
- Maintains clean build environment

---

## Sukisu Ultra Integration

### setup_sukisu_ultra()

**Purpose**: Integrates Sukisu Ultra (advanced KernelSU fork) into kernel source
**Parameters**: None
**Returns**: Returns early if feature disabled

**Detailed Process**:

1. **Feature Gate Check**:
   ```bash
   if [ "$ENABLE_SUKISU_ULTRA" != "true" ]; then
       log_info "Sukisu Ultra integration disabled"
       return 0
   fi
   ```
   - Respects user configuration flags
   - Allows building without root capabilities if desired

2. **Repository Management**:
   ```bash
   if [ ! -d "$SUKISU_DIR" ]; then
       git clone https://github.com/SukiSU-Ultra/SukiSU-Ultra.git sukisu-ultra
   else
       cd "$SUKISU_DIR" && git pull && cd "$BUILD_DIR"
   fi
   ```
   - **Repository**: `SukiSU-Ultra/SukiSU-Ultra`
   - **Contents**: Enhanced KernelSU fork with SUSFS support
   - **Features**: Improved root management, better hiding capabilities

3. **Automatic Integration**:
   ```bash
   if [ -f "$SUKISU_DIR/kernel/setup.sh" ]; then
       bash "$SUKISU_DIR/kernel/setup.sh" susfs-main
   fi
   ```
   - **Primary Method**: Uses official setup script with SUSFS variant
   - **Parameter**: `susfs-main` enables SUSFS-compatible integration
   - **Advantages**: Automated patching, proper configuration

4. **Manual Integration Fallback**:
   ```bash
   if [ -d "$SUKISU_DIR/kernel/drivers/kernelsu" ]; then
       mkdir -p drivers/kernelsu
       cp -r "$SUKISU_DIR/kernel/drivers/kernelsu"/* drivers/kernelsu/
   fi
   ```
   - **Trigger**: When setup script is unavailable
   - **Process**: Manual copying of KernelSU driver source
   - **Location**: `drivers/kernelsu/` in kernel tree

5. **Patch Application**:
   ```bash
   for patch in "$SUKISU_DIR/kernel/patches"/*.patch; do
       if [ -f "$patch" ]; then
           patch -p1 < "$patch" || log_warning "Patch $(basename "$patch") failed"
       fi
   done
   ```
   - **Method**: Applies kernel patches using `patch` command
   - **Level**: `-p1` strips one directory level from patch paths
   - **Error Handling**: Warns on failure but continues build
   - **Content**: Security subsystem modifications, hook installations

**Sukisu Ultra Features**:
- Advanced root management beyond standard KernelSU
- Enhanced compatibility with newer Android versions
- Built-in SUSFS support for better root hiding
- Improved module loading capabilities

---

## SUSFS Integration

### setup_susfs()

**Purpose**: Integrates SUSFS (SU Secure File System) for root detection hiding
**Parameters**: None
**Returns**: Returns early if feature disabled

**Detailed Process**:

1. **Feature Validation**:
   ```bash
   if [ "$ENABLE_SUSFS" != "true" ]; then
       log_info "SUSFS integration disabled"
       return 0
   fi
   ```
   - Allows building without root hiding if not needed
   - Useful for debugging or basic root access

2. **SUSFS Repository**:
   ```bash
   git clone https://github.com/sidex15/susfs4ksu-module.git susfs
   ```
   - **Repository**: `sidex15/susfs4ksu-module`
   - **Purpose**: Root hiding filesystem implementation
   - **Compatibility**: Designed for KernelSU integration
   - **Method**: Filesystem-level hiding of root artifacts

3. **Kernel Patch Integration**:
   ```bash
   if [ -d "$SUSFS_DIR/kernel_patches" ]; then
       for patch in "$SUSFS_DIR/kernel_patches"/*.patch; do
           patch -p1 < "$patch" || log_warning "SUSFS patch $(basename "$patch") failed"
       done
   fi
   ```
   - **Location**: Patches stored in `kernel_patches/` directory
   - **Content**: VFS modifications, overlay filesystem enhancements
   - **Purpose**: Enables filesystem-level root hiding

4. **Filesystem Code Integration**:
   ```bash
   if [ -d "$SUSFS_DIR/ksu_module_susfs" ]; then
       mkdir -p fs/susfs
       if [ -d "$SUSFS_DIR/ksu_module_susfs/jni" ]; then
           cp -r "$SUSFS_DIR/ksu_module_susfs/jni"/* fs/susfs/ 2>/dev/null || true
       fi
   fi
   ```
   - **Integration Point**: `fs/susfs/` in kernel filesystem subsystem
   - **Source**: JNI directory contains native filesystem code
   - **Error Handling**: Ignores copy failures gracefully

**SUSFS Capabilities**:
- Hides root binaries from filesystem scans
- Masks su-related processes in process lists
- Obscures root-related mount points
- Provides configurable hiding policies
- Works at kernel level for maximum effectiveness

---

## Kernel Configuration

### setup_kernel_config()

**Purpose**: Configures kernel build options and enables required features
**Parameters**: None
**Returns**: None (exits on configuration failure)

**Detailed Process**:

1. **Default Configuration Detection**:
   ```bash
   local defconfig_file=""
   if [ -f "arch/arm64/configs/garnet_defconfig" ]; then
       defconfig_file="garnet_defconfig"
   elif [ -f "arch/arm64/configs/sm7435_defconfig" ]; then
       defconfig_file="sm7435_defconfig"
   elif [ -f "arch/arm64/configs/vendor/garnet_defconfig" ]; then
       defconfig_file="vendor/garnet_defconfig"
   else
       defconfig_file="defconfig"
   fi
   ```
   - **Priority Order**: Device-specific → Chipset-specific → Vendor → Generic
   - **Location**: `arch/arm64/configs/` directory
   - **Purpose**: Provides base kernel configuration

2. **Base Configuration Loading**:
   ```bash
   make O=out ARCH=arm64 "$defconfig_file"
   ```
   - **Output Directory**: `out/` keeps source tree clean
   - **Architecture**: ARM64 for 64-bit ARM processors
   - **Result**: Creates `.config` file with base settings

3. **Root Feature Configuration**:
   ```bash
   if [ "$ENABLE_SUKISU_ULTRA" == "true" ] || [ "$ENABLE_SUSFS" == "true" ]; then
       cat >> out/.config << EOF
   ```
   - **Condition**: Only if root features are enabled
   - **Method**: Appends configuration to existing `.config`
   - **Format**: Kernel configuration format (CONFIG_NAME=value)

4. **Security Subsystem Configuration**:
   ```bash
   CONFIG_SECURITY=y
   CONFIG_SECURITY_NETWORK=y
   CONFIG_LSM="lockdown,yama,loadpin,safesetid,integrity,selinux,smack,tomoyo,apparmor"
   CONFIG_SECURITY_SELINUX=y
   CONFIG_SECURITY_SELINUX_BOOTPARAM=y
   CONFIG_SECURITY_SELINUX_DEVELOP=y
   ```
   - **CONFIG_SECURITY**: Enables Linux Security Module framework
   - **CONFIG_SECURITY_NETWORK**: Network security hooks
   - **CONFIG_LSM**: Ordered list of security modules to load
   - **SELinux Options**: Development mode, boot parameters, statistics

5. **Module Support Configuration**:
   ```bash
   CONFIG_MODULES=y
   CONFIG_MODULE_UNLOAD=y
   CONFIG_MODVERSIONS=y
   CONFIG_MODULE_SRCVERSION_ALL=y
   ```
   - **CONFIG_MODULES**: Enables loadable kernel modules
   - **CONFIG_MODULE_UNLOAD**: Allows module removal
   - **CONFIG_MODVERSIONS**: Version checking for modules
   - **CONFIG_MODULE_SRCVERSION_ALL**: Source version tracking

6. **Overlay Filesystem Configuration**:
   ```bash
   CONFIG_OVERLAY_FS=y
   CONFIG_OVERLAY_FS_REDIRECT_DIR=y
   CONFIG_OVERLAY_FS_INDEX=y
   CONFIG_OVERLAY_FS_METACOPY=y
   ```
   - **Purpose**: Required for SUSFS functionality
   - **CONFIG_OVERLAY_FS**: Base overlay filesystem support
   - **Advanced Features**: Directory redirection, indexing, metadata copying

7. **Namespace Support Configuration**:
   ```bash
   CONFIG_NAMESPACES=y
   CONFIG_UTS_NS=y
   CONFIG_IPC_NS=y
   CONFIG_USER_NS=y
   CONFIG_PID_NS=y
   CONFIG_NET_NS=y
   CONFIG_CGROUP_NS=y
   ```
   - **Purpose**: Container and isolation support for root hiding
   - **UTS_NS**: Hostname and domain name isolation
   - **IPC_NS**: Inter-process communication isolation
   - **USER_NS**: User and group ID isolation
   - **PID_NS**: Process ID isolation
   - **NET_NS**: Network stack isolation
   - **CGROUP_NS**: Control group isolation

8. **Additional Security Features**:
   ```bash
   CONFIG_SECURITY_FILE_CAPABILITIES=y
   CONFIG_AUDIT=y
   CONFIG_AUDITSYSCALL=y
   ```
   - **File Capabilities**: POSIX file capabilities support
   - **Audit**: Security event logging
   - **Syscall Auditing**: System call monitoring

9. **Configuration Finalization**:
   ```bash
   make O=out ARCH=arm64 olddefconfig
   ```
   - **Purpose**: Resolves dependencies and conflicts
   - **Method**: Sets default values for new/unset options
   - **Result**: Consistent, buildable configuration

---

## Build Process

### build_kernel()

**Purpose**: Compiles the kernel and modules with automatic configuration handling
**Parameters**: None
**Returns**: Exits with code 1 on build failure

**Detailed Process**:

1. **Build Environment Setup**:
   ```bash
   cd "$KERNEL_DIR"
   mkdir -p out
   export KCONFIG_NOTIMESTAMP=1
   ```
   - **Working Directory**: Kernel source root
   - **Output Directory**: Separates build artifacts from source
   - **KCONFIG_NOTIMESTAMP**: Prevents timestamp-based rebuilds

2. **Kernel Image Compilation**:
   ```bash
   make O=out ARCH=arm64 -j$(nproc) 2>&1 | tee build.log
   ```
   - **Parallel Build**: `-j$(nproc)` uses all CPU cores
   - **Output Redirection**: `2>&1` captures both stdout and stderr
   - **Build Log**: `tee build.log` saves output while displaying
   - **Architecture**: ARM64 cross-compilation

3. **Build Success Verification**:
   ```bash
   if [ ${PIPESTATUS[0]} -eq 0 ]; then
   ```
   - **PIPESTATUS**: Checks exit code of `make` command (before `tee`)
   - **Success Code**: 0 indicates successful compilation
   - **Error Handling**: Non-zero exit stops script execution

4. **Output File Detection**:
   ```bash
   if [ -f "out/arch/arm64/boot/Image" ]; then
       log_success "Kernel Image created: $KERNEL_DIR/out/arch/arm64/boot/Image"
   fi
   ```
   - **Image**: Uncompressed kernel binary
   - **Image.gz**: Compressed kernel binary
   - **Image.gz-dtb**: Kernel with device tree appended
   - **Priority**: Prefers combined image with device tree

5. **Kernel Modules Compilation**:
   ```bash
   make O=out ARCH=arm64 modules -j$(nproc)
   ```
   - **Target**: `modules` builds loadable kernel modules
   - **Parallel**: Uses all CPU cores for faster compilation
   - **Output**: `.ko` files in various subdirectories

6. **Error Handling**:
   ```bash
   else
       log_error "Kernel build failed! Check build.log for details"
       exit 1
   fi
   ```
   - **Log Reference**: Directs user to detailed build log
   - **Script Termination**: Prevents invalid output creation
   - **Exit Code**: Non-zero indicates build failure

**Build Artifacts Generated**:
- **Image**: Raw kernel binary
- **Image.gz**: Compressed kernel
- **Image.gz-dtb**: Kernel with device tree
- **System.map**: Kernel symbol table
- **vmlinux**: Unstripped kernel binary
- **Module files**: Loadable kernel modules (.ko)

**Build Optimization Features**:
- Parallel compilation using all CPU cores
- Incremental builds (only changed files)
- Separate output directory (clean source tree)
- Comprehensive error logging

---

## Output Generation

### create_output()

**Purpose**: Organizes build artifacts and creates final output packages
**Parameters**: None
**Returns**: None

**Detailed Process**:

1. **Output Directory Setup**:
   ```bash
   local output_dir="${BUILD_DIR}/output"
   mkdir -p "$output_dir"
   cd "$KERNEL_DIR"
   ```
   - **Location**: `garnet_kernel_build/output/`
   - **Purpose**: Centralized location for flashable files
   - **Structure**: Clean organization for user access

2. **Kernel Image Selection and Copy**:
   ```bash
   if [ -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
       cp "out/arch/arm64/boot/Image.gz-dtb" "$output_dir/"
   elif [ -f "out/arch/arm64/boot/Image.gz" ]; then
       cp "out/arch/arm64/boot/Image.gz" "$output_dir/"
   elif [ -f "out/arch/arm64/boot/Image" ]; then
       cp "out/arch/arm64/boot/Image" "$output_dir/"
   fi
   ```
   - **Priority Order**: Combined image → Compressed → Raw
   - **Image.gz-dtb**: Preferred for single-file flashing
   - **Fallback Logic**: Ensures some kernel image is always copied

3. **Device Tree Binary Copy**:
   ```bash
   if [ -d "out/arch/arm64/boot/dts" ]; then
       find out/arch/arm64/boot/dts -name "*.dtb" -exec cp {} "$output_dir/" \;
   fi
   ```
   - **Source**: Device tree compiler output
   - **Pattern**: All `.dtb` files (device tree binaries)
   - **Purpose**: Hardware configuration for bootloader

4. **Flashable Package Creation**:
   ```bash
   if [ "$ENABLE_ANYKERNEL3" == "true" ]; then
       create_anykernel3_zip "$output_dir"
   fi
   ```
   - **Conditional**: Only if AnyKernel3 enabled
   - **Purpose**: Creates recovery-flashable ZIP
   - **Convenience**: Automated installation package

**Output Structure**:
```
garnet_kernel_build/output/
├── Image.gz-dtb                    # Kernel with device tree
├── *.dtb                          # Individual device tree files
└── Garnet-Kernel-SukiSU-SUSFS-*.zip # Flashable package
```

**File Usage Guide**:
- **Image.gz-dtb**: Flash directly to boot partition via fastboot
- **DTB files**: For custom bootloader configurations
- **ZIP file**: Install via TWRP/custom recovery

---

## AnyKernel3 Packaging

### create_anykernel3_zip()

**Purpose**: Creates recovery-flashable ZIP packages for easy installation
**Parameters**: `$1` - Output directory path
**Returns**: Returns 1 if no kernel image found

**Detailed Process**:

1. **Package Configuration**:
   ```bash
   local output_dir="$1"
   local ak3_dir="${BUILD_DIR}/AnyKernel3"
   local zip_name="Garnet-Kernel-SukiSU-SUSFS-$(date +%Y%m%d-%H%M).zip"
   ```
   - **Naming**: Includes device, features, and timestamp
   - **Format**: `Garnet-Kernel-SukiSU-SUSFS-20240101-1430.zip`
   - **Location**: AnyKernel3 working directory

2. **AnyKernel3 Repository Management**:
   ```bash
   if [ ! -d "$ak3_dir" ]; then
       git clone https://github.com/osm0sis/AnyKernel3.git
   else
       cd "$ak3_dir" && git pull && cd "$BUILD_DIR"
   fi
   ```
   - **Repository**: `osm0sis/AnyKernel3` (official)
   - **Purpose**: Universal kernel flashing framework
   - **Update**: Ensures latest tools and scripts

3. **Build Environment Cleanup**:
   ```bash
   cd "$ak3_dir"
   rm -f *.zip Image* dtb *.dtbo
   ```
   - **Purpose**: Removes previous build artifacts
   - **Files**: Old ZIPs, kernel images, device trees
   - **Clean Slate**: Prevents file conflicts

4. **Kernel Image Integration**:
   ```bash
   if [ -f "$output_dir/Image.gz-dtb" ]; then
       cp "$output_dir/Image.gz-dtb" .
       kernel_image="Image.gz-dtb"
   elif [ -f "$output_dir/Image.gz" ]; then
       cp "$output_dir/Image.gz" .
       kernel_image="Image.gz"
   elif [ -f "$output_dir/Image" ]; then
       cp "$output_dir/Image" .
       kernel_image="Image"
   fi
   ```
   - **Selection Logic**: Same priority as output generation
   - **Variable Tracking**: Records which image type is used
   - **Error Handling**: Returns failure if no image found

5. **Device Tree Integration**:
   ```bash
   find "$output_dir" -name "*.dtb" -exec cp {} . \; 2>/dev/null || true
   ```
   - **Source**: All DTB files from output directory
   - **Error Suppression**: Ignores missing DTB files
   - **Flexibility**: Supports both combined and separate DTB workflows

6. **AnyKernel3 Script Configuration**:
   ```bash
   cat > anykernel.sh << 'EOF'
   ```

   **Script Properties**:
   ```bash
   properties() { '
   kernel.string=Garnet Kernel with SukiSU Ultra & SUSFS
   do.devicecheck=1
   do.modules=0
   do.systemless=1
   do.cleanup=1
   do.cleanuponabort=0
   device.name1=garnet
   device.name2=2404CPCFG
   device.name3=23127PC33G
   device.name4=2404CPX3G
   device.name5=24069PC21G
   supported.versions=13-15
   '; }
   ```
   - **kernel.string**: Display name in recovery
   - **do.devicecheck**: Verifies device compatibility
   - **do.modules**: Disables module installation (compiled into kernel)
   - **do.systemless**: Systemless root compatibility
   - **do.cleanup**: Cleans old files during installation
   - **device.name**: All known garnet device identifiers
   - **supported.versions**: Android 13, 14, 15 support

   **Installation Variables**:
   ```bash
   block=/dev/block/bootdevice/by-name/boot;
   is_slot_device=1;
   ramdisk_compression=auto;
   patch_vbmeta_flag=auto;
   ```
   - **block**: Boot partition location
   - **is_slot_device**: A/B partition support
   - **ramdisk_compression**: Automatic compression detection
   - **patch_vbmeta_flag**: Automatic verified boot handling

7. **ZIP Package Creation**:
   ```bash
   zip -r9 "$zip_name" * -x .git README.md *placeholder
   ```
   - **Compression**: `-r9` maximum compression, recursive
   - **Exclusions**: Git files, documentation, placeholders
   - **Content**: Scripts, tools, kernel image, device trees

8. **Final Package Delivery**:
   ```bash
   mv "$zip_name" "$output_dir/"
   ```
   - **Destination**: User-accessible output directory
   - **Convenience**: Single location for all outputs

**AnyKernel3 Features**:
- Universal installation across different Android versions
- Automatic boot image extraction and repacking
- Device verification for safety
- Verified boot bypass capabilities
- A/B partition support
- Ramdisk modification support

**Installation Process**:
1. Recovery extracts ZIP contents
2. Verifies device compatibility
3. Extracts current boot image
4. Replaces kernel with new image
5. Preserves existing ramdisk
6. Repacks and flashes new boot image

---

## Command Line Interface

### parse_args()

**Purpose**: Processes command line arguments to control build features
**Parameters**: `$@` - All command line arguments
**Returns**: Exits with code 0 for help, code 1 for invalid options

**Detailed Process**:

1. **Argument Loop**:
   ```bash
   while [[ $# -gt 0 ]]; do
       case $1 in
   ```
   - **Iteration**: Processes each argument sequentially
   - **Pattern Matching**: Uses case statement for option recognition
   - **Flexibility**: Supports multiple options in single command

2. **Feature Disable Options**:

   **--no-sukisu**:
   ```bash
   --no-sukisu)
       ENABLE_SUKISU_ULTRA=false
       log_info "Sukisu Ultra disabled"
   ```
   - **Purpose**: Builds kernel without KernelSU integration
   - **Use Case**: Stock kernel with only SUSFS
   - **Effect**: Skips Sukisu Ultra cloning and integration

   **--no-susfs**:
   ```bash
   --no-susfs)
       ENABLE_SUSFS=false
       log_info "SUSFS disabled"
   ```
   - **Purpose**: Builds kernel without root hiding
   - **Use Case**: Basic KernelSU without advanced hiding
   - **Effect**: Skips SUSFS repository and patches

   **--no-anykernel3**:
   ```bash
   --no-anykernel3)
       ENABLE_ANYKERNEL3=false
       log_info "AnyKernel3 ZIP creation disabled"
   ```
   - **Purpose**: Skips flashable ZIP creation
   - **Use Case**: Direct fastboot flashing workflow
   - **Effect**: Only produces raw kernel images

3. **Feature Combination Options**:

   **--sukisu-only**:
   ```bash
   --sukisu-only)
       ENABLE_SUKISU_ULTRA=true
       ENABLE_SUSFS=false
       log_info "Building with Sukisu Ultra only"
   ```
   - **Configuration**: KernelSU without advanced hiding
   - **Use Case**: Basic root access needs
   - **Benefits**: Faster build, smaller kernel

   **--susfs-only**:
   ```bash
   --susfs-only)
       ENABLE_SUKISU_ULTRA=false
       ENABLE_SUSFS=true
       log_info "Building with SUSFS only"
   ```
   - **Configuration**: Root hiding without KernelSU
   - **Use Case**: Hiding existing root solutions
   - **Benefits**: Stealth mode for banking apps

   **--stock**:
   ```bash
   --stock)
       ENABLE_SUKISU_ULTRA=false
       ENABLE_SUSFS=false
       log_info "Building stock kernel without root features"
   ```
   - **Configuration**: No root features
   - **Use Case**: Performance kernel, debugging
   - **Benefits**: Maximum compatibility, fastest build

4. **Help System**:
   ```bash
   --help|-h)
       show_help
       exit 0
   ```
   - **Triggers**: `--help` or `-h` flags
   - **Action**: Displays usage information and exits
   - **Exit Code**: 0 (success) for help requests

5. **Error Handling**:
   ```bash
   *)
       log_error "Unknown option: $1"
       show_help
       exit 1
   ```
   - **Invalid Options**: Any unrecognized argument
   - **Response**: Error message and help display
   - **Exit Code**: 1 (failure) for invalid usage

### show_help()

**Purpose**: Displays comprehensive usage information and examples
**Parameters**: None
**Returns**: None (output only)

**Content Structure**:

1. **Header Information**:
   - Script purpose and target device
   - Feature summary (Sukisu Ultra, SUSFS)

2. **Usage Syntax**:
   - Basic command structure
   - Option format and placement

3. **Option Documentation**:
   - Complete list of available flags
   - Purpose and effect of each option
   - Mutual exclusivity information

4. **Practical Examples**:
   - Common use cases with exact commands
   - Different build scenarios
   - Feature combination examples

**Example Output**:
```
Android Kernel Build Script for Redmi Note 13 Pro 5G (garnet)
Builds kernel with Sukisu Ultra (KernelSU fork) and SUSFS root hiding

Usage: ./build_garnet_kernel.sh [OPTIONS]

Options:
  --no-sukisu      Disable Sukisu Ultra integration
  --no-susfs       Disable SUSFS integration
  --no-anykernel3  Disable AnyKernel3 ZIP creation
  --sukisu-only    Build with Sukisu Ultra only (no SUSFS)
  --susfs-only     Build with SUSFS only (no Sukisu Ultra)
  --stock          Build stock kernel without root features
  --help, -h       Show this help message

Examples:
  ./build_garnet_kernel.sh                # Build with all features
  ./build_garnet_kernel.sh --stock        # Build stock kernel
  ./build_garnet_kernel.sh --sukisu-only  # Build with KernelSU only
```

---

## Main Execution Flow

### main()

**Purpose**: Orchestrates the complete kernel build process
**Parameters**: None
**Returns**: None (logs completion status)

**Execution Sequence**:

1. **Build Initialization**:
   ```bash
   log_info "Starting Android Kernel Build for Redmi Note 13 Pro 5G (garnet)"
   log_info "Features: Sukisu Ultra ($ENABLE_SUKISU_ULTRA) | SUSFS ($ENABLE_SUSFS)"
   log_info "Build directory: $BUILD_DIR"
   ```
   - **Purpose**: User information and build confirmation
   - **Feature Display**: Shows enabled/disabled features
   - **Path Information**: Build directory location

2. **Dependency Verification**:
   ```bash
   check_dependencies
   ```
   - **Critical Path**: Must pass before proceeding
   - **Early Failure**: Stops build if tools missing
   - **User Guidance**: Provides installation commands

3. **Toolchain Configuration**:
   ```bash
   setup_toolchain
   ```
   - **Cross-Compilation**: Sets up ARM64 compiler
   - **Priority Order**: NDK → System toolchain → Error
   - **Environment**: Exports necessary variables

4. **Source Code Acquisition**:
   ```bash
   clone_repositories
   ```
   - **Base Sources**: Kernel, device trees, modules
   - **Update Logic**: Pulls latest changes if exists
   - **Workspace**: Organizes in build directory

5. **Root Feature Integration**:
   ```bash
   setup_sukisu_ultra
   setup_susfs
   ```
   - **Conditional**: Only if features enabled
   - **Integration**: Patches and source modifications
   - **Error Tolerance**: Continues on patch failures

6. **Kernel Configuration**:
   ```bash
   setup_kernel_config
   ```
   - **Base Config**: Device-specific defaults
   - **Feature Configs**: Root-specific options
   - **Dependency Resolution**: Automatic conflict resolution

7. **Compilation Process**:
   ```bash
   build_kernel
   ```
   - **Parallel Build**: Maximum CPU utilization
   - **Progress Logging**: Build output capture
   - **Failure Handling**: Stops on compilation errors

8. **Output Generation**:
   ```bash
   create_output
   ```
   - **File Organization**: Structured output directory
   - **Package Creation**: AnyKernel3 ZIP if enabled
   - **User Instructions**: Flashing guidance

9. **Completion Notification**:
   ```bash
   log_success "Kernel build process completed!"
   log_info "Check $BUILD_DIR/output/ for flashable files"
   ```
   - **Success Confirmation**: Build completion status
   - **Output Location**: Where to find results
   - **Next Steps**: User action guidance

### Script Entry Point

```bash
# Handle script interruption
trap 'log_error "Build interrupted by user"; exit 130' INT

# Parse command line arguments
parse_args "$@"

# Run main function
main
```

**Interrupt Handling**:
- **Signal**: SIGINT (Ctrl+C)
- **Action**: Clean error message and exit
- **Exit Code**: 130 (standard for SIGINT)

**Argument Processing**:
- **Before Main**: Processes all command line options
- **Global State**: Modifies feature flags
- **Validation**: Ensures valid option combinations

**Execution Order**:
1. Signal handler registration
2. Command line argument parsing
3. Main build process execution

---

## Error Handling and Recovery

### Build Failure Recovery

**Dependency Failures**:
- Clear error messages with installation commands
- Platform-specific package names
- Exit before wasting time on incomplete builds

**Repository Failures**:
- Network connectivity issues handled gracefully
- Fallback to existing repositories if available
- Update failures don't stop builds

**Patch Failures**:
- Individual patch failures logged as warnings
- Build continues with remaining patches
- Manual integration fallbacks available

**Compilation Failures**:
- Detailed build logs preserved
- Clear error indication with log reference
- Script termination prevents invalid outputs

### Signal Handling

**Interrupt Signal (SIGINT)**:
- Graceful termination message
- Standard exit code (130)
- No partial file cleanup needed

### Logging Strategy

**Hierarchical Logging**:
- **INFO**: Process steps and progress
- **SUCCESS**: Completion confirmations
- **WARNING**: Non-fatal issues
- **ERROR**: Build-stopping problems

**Color Coding**:
- Improves readability in terminal
- Quick visual status identification
- Standard conventions followed

---

## Performance Optimizations

### Parallel Processing

**Multi-Core Compilation**:
- `$(nproc)` detects available CPU cores
- Parallel make execution for kernel and modules
- Optimal resource utilization

**Repository Management**:
- Update existing repositories instead of re-cloning
- Incremental builds preserve previous work
- Separate output directories prevent conflicts

### Build Efficiency

**Incremental Builds**:
- Only recompiles changed source files
- Preserves object files between builds
- Configuration changes trigger appropriate rebuilds

**Clean Separation**:
- Source trees remain unmodified
- Output artifacts in dedicated directories
- Easy cleanup and fresh builds

---

## Security Considerations

### Safe Integration Practices

**Patch Validation**:
- Individual patch application with error checking
- Continues build on non-critical patch failures
- Manual fallbacks for integration

**Repository Verification**:
- Uses official and trusted repositories
- Warns on unexpected integration failures
- Provides fallback mechanisms

### Root Feature Security

**KernelSU Integration**:
- Uses established and reviewed projects
- Maintains kernel security model
- Proper SELinux integration

**SUSFS Implementation**:
- Filesystem-level hiding mechanisms
- Maintains Android security architecture
- Configurable hiding policies

---

## Troubleshooting Guide

### Common Build Issues

**Missing Dependencies**:
- Install packages as shown in error messages
- Use distribution-specific package managers
- Verify NDK installation if using Android toolchain

**Toolchain Problems**:
- Ensure ARM64 cross-compiler available
- Set ANDROID_NDK_HOME for NDK usage
- Check PATH for toolchain binaries

**Repository Access**:
- Verify internet connectivity
- Check GitHub repository availability
- Use cached repositories if updates fail

**Configuration Errors**:
- Review build.log for specific errors
- Check defconfig file existence
- Verify architecture compatibility

### Build Output Issues

**Missing Kernel Images**:
- Check compilation success in logs
- Verify defconfig enables required features
- Review make targets and output paths

**AnyKernel3 Failures**:
- Ensure ZIP utility installed
- Check file permissions and paths
- Verify AnyKernel3 repository accessibility

### Device Compatibility

**Boot Failures**:
- Verify device tree compatibility
- Check bootloader unlock status
- Ensure proper partition identification

**Feature Malfunctions**:
- Review kernel configuration options
- Check integration success logs
- Verify Android version compatibility

---

This comprehensive documentation covers every aspect of the kernel build script, from initial setup through final output generation. Each function is explained in detail with its purpose, parameters, internal logic, and integration with the overall build process.