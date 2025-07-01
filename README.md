# Garnet Kernel Builder

Automated kernel build script for **Redmi Note 13 Pro 5G (garnet)** with integrated **Sukisu Ultra** (KernelSU fork) and **SUSFS** root hiding capabilities.

## Features

- 🔧 **Automated Build Process** - Complete kernel compilation with one command
- ⚡ **Sukisu Ultra Integration** - Enhanced KernelSU fork with advanced features
- 🛡️ **SUSFS Root Hiding** - Filesystem-level root detection bypass
- 📦 **AnyKernel3 Packaging** - Ready-to-flash ZIP files
- 🎯 **Multiple Build Options** - Stock, KernelSU-only, SUSFS-only configurations

## Device Compatibility

- **Device**: Redmi Note 13 Pro 5G
- **Codename**: garnet
- **SoC**: SM7435 (Snapdragon 7s Gen 2)
- **Android**: 13, 14, 15
- **Architecture**: ARM64

## Quick Start

### Prerequisites

**Arch Linux:**
```bash
sudo pacman -S base-devel git bc bison flex openssl elfutils zip aarch64-linux-gnu-gcc
```

**Ubuntu/Debian:**
```bash
sudo apt install git make bc bison flex libssl-dev libelf-dev zip gcc-aarch64-linux-gnu
```

### Clone and Build

```bash
# Clone the repository
git clone https://github.com/overspend1/garnet-kernel-builder.git
cd garnet-kernel-builder

# Make executable
chmod +x build_garnet_kernel.sh

# Build with all features (recommended)
./build_garnet_kernel.sh
```

## Build Options

```bash
# Full build with Sukisu Ultra + SUSFS (default)
./build_garnet_kernel.sh

# Stock kernel without root features
./build_garnet_kernel.sh --stock

# KernelSU only (no SUSFS)
./build_garnet_kernel.sh --sukisu-only

# SUSFS only (no KernelSU)
./build_garnet_kernel.sh --susfs-only

# Skip AnyKernel3 ZIP creation
./build_garnet_kernel.sh --no-anykernel3

# Show help
./build_garnet_kernel.sh --help
```

## Android NDK Support (Optional)

For optimal Android kernel compilation, use Android NDK:

```bash
# Set NDK path
export ANDROID_NDK_HOME=/path/to/android-ndk

# Build with NDK toolchain
./build_garnet_kernel.sh
```

## Output

Build artifacts are created in `garnet_kernel_build/output/`:

- `Image.gz-dtb` - Kernel with device tree (for fastboot)
- `*.dtb` - Individual device tree files
- `Garnet-Kernel-SukiSU-SUSFS-YYYYMMDD-HHMM.zip` - Flashable ZIP

## Installation

### Method 1: Custom Recovery (Recommended)
1. Boot into TWRP/custom recovery
2. Flash the generated ZIP file
3. Reboot system

### Method 2: Fastboot
```bash
fastboot flash boot Image.gz-dtb
fastboot reboot
```

## Post-Installation

1. **Install Sukisu Ultra Manager** APK
2. **Install SUSFS4KSU Module** for root hiding
3. **Configure root hiding** through the manager app

## Build Process Details

The script automatically:

1. **Dependency Verification** - Checks for required build tools
2. **Toolchain Setup** - Configures ARM64 cross-compilation
3. **Repository Management** - Clones/updates kernel sources
4. **Feature Integration** - Applies Sukisu Ultra and SUSFS patches
5. **Kernel Configuration** - Enables required features
6. **Compilation** - Parallel build using all CPU cores
7. **Package Creation** - Generates flashable ZIP files

## Advanced Configuration

### Kernel Features Enabled

- **KPM Support** - Kernel Patch Module for Sukisu Ultra
- **KALLSYMS** - Symbol resolution for KernelSU
- **Security Framework** - SELinux, LSM, audit support
- **Overlay Filesystem** - Required for SUSFS
- **Namespace Support** - Container isolation
- **Memory Protection** - Hardened security features

### Repositories Used

- **Kernel**: `garnet-random/android_kernel_xiaomi_sm7435`
- **Device Trees**: `garnet-random/android_kernel_xiaomi_sm7435-devicetrees`
- **Modules**: `garnet-random/android_kernel_xiaomi_sm7435-modules`
- **Sukisu Ultra**: `SukiSU-Ultra/SukiSU-Ultra`
- **SUSFS**: `sidex15/susfs4ksu-module`

## Troubleshooting

### Common Issues

**Build Failures:**
- Check `build.log` in kernel directory
- Verify all dependencies are installed
- Ensure sufficient disk space (>10GB)

**Missing Cross-Compiler:**
```bash
# Arch Linux
sudo pacman -S aarch64-linux-gnu-gcc

# Ubuntu/Debian
sudo apt install gcc-aarch64-linux-gnu
```

**Integration Failures:**
- Check `setup_sukisu.log` for Sukisu Ultra errors
- Verify internet connectivity for repository access
- Try manual integration fallback

### Build Time

- **First Build**: 20-40 minutes (downloads repositories)
- **Subsequent Builds**: 10-20 minutes (incremental)
- **Clean Build**: 15-30 minutes

## Security Notice

This script integrates defensive security tools:
- **KernelSU**: Provides root access management
- **SUSFS**: Enables root hiding from detection
- **Hardened Configuration**: Security-focused kernel options

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is for educational and defensive security purposes only. Ensure compliance with local laws and device warranties.

## Support

- **Issues**: [GitHub Issues](https://github.com/overspend1/garnet-kernel-builder/issues)
- **Device**: Redmi Note 13 Pro 5G (garnet) only
- **Android**: Versions 13, 14, 15

---

**⚠️ Warning**: Flashing custom kernels can void warranties and potentially brick devices. Proceed at your own risk with proper backups.