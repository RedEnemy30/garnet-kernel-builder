#!/bin/bash

set -e

# Android Kernel Build Script for Redmi Note 13 Pro 5G (garnet)
# Automatically builds kernel with Sukisu Ultra (KernelSU fork) and SUSFS root hiding
# Includes proper toolchain setup and automatic config prompt handling

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/garnet_kernel_build"
KERNEL_DIR="${BUILD_DIR}/kernel"
DT_DIR="${BUILD_DIR}/devicetrees"
MODULES_DIR="${BUILD_DIR}/modules"
SUKISU_DIR="${BUILD_DIR}/sukisu-ultra"
SUSFS_DIR="${BUILD_DIR}/susfs"

# Feature flags (can be overridden by command line)
ENABLE_SUKISU_ULTRA=true
ENABLE_SUSFS=true
ENABLE_ANYKERNEL3=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_dependencies() {
    log_info "Checking build dependencies..."
    
    local missing_deps=()
    
    # Check for command-line tools
    local tools=("git" "make" "bc" "bison" "flex" "zip")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done
    
    # Check for libraries based on distribution
    if command -v pacman &> /dev/null; then
        # Arch Linux
        local arch_libs=("openssl" "elfutils")
        for lib in "${arch_libs[@]}"; do
            if ! pacman -Q "$lib" &> /dev/null; then
                missing_deps+=("$lib")
            fi
        done
        
        # Check for cross-compiler
        if ! command -v aarch64-linux-gnu-gcc &> /dev/null && [ -z "$ANDROID_NDK_HOME" ]; then
            log_warning "No ARM64 cross-compiler found"
            log_info "Install with: sudo pacman -S aarch64-linux-gnu-gcc"
            log_info "Or set ANDROID_NDK_HOME environment variable"
        fi
        
        if [ ${#missing_deps[@]} -ne 0 ]; then
            log_error "Missing dependencies: ${missing_deps[*]}"
            log_info "Install with: sudo pacman -S ${missing_deps[*]}"
            exit 1
        fi
    elif command -v dpkg &> /dev/null; then
        # Debian/Ubuntu
        local deb_libs=("libssl-dev" "libelf-dev")
        for lib in "${deb_libs[@]}"; do
            if ! dpkg -l | grep -q "$lib"; then
                missing_deps+=("$lib")
            fi
        done
        
        if [ ${#missing_deps[@]} -ne 0 ]; then
            log_error "Missing dependencies: ${missing_deps[*]}"
            log_info "Install with: sudo apt install ${missing_deps[*]}"
            exit 1
        fi
    else
        log_warning "Unknown distribution - skipping library dependency checks"
        log_info "Ensure you have OpenSSL and ELF development libraries installed"
    fi
    
    log_success "All dependencies satisfied"
}

# Setup cross-compilation toolchain
setup_toolchain() {
    log_info "Setting up cross-compilation toolchain..."
    
    # Check if Android NDK or prebuilt toolchain exists
    if [ -n "$ANDROID_NDK_HOME" ] && [ -d "$ANDROID_NDK_HOME" ]; then
        export CROSS_COMPILE="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android-"
        export CC="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang"
        log_success "Using Android NDK toolchain"
    elif command -v aarch64-linux-gnu-gcc &> /dev/null; then
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export CC="aarch64-linux-gnu-gcc"
        log_success "Using system aarch64 toolchain"
    else
        log_error "No suitable cross-compilation toolchain found"
        log_info "Install with: sudo apt install gcc-aarch64-linux-gnu"
        log_info "Or set ANDROID_NDK_HOME environment variable"
        exit 1
    fi
    
    export ARCH=arm64
    export SUBARCH=arm64
}

# Clone repositories
clone_repositories() {
    log_info "Cloning kernel repositories..."
    
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Clone main kernel
    if [ ! -d "$KERNEL_DIR" ]; then
        log_info "Cloning main kernel repository..."
        git clone https://github.com/garnet-random/android_kernel_xiaomi_sm7435.git kernel
    else
        log_info "Updating main kernel repository..."
        cd "$KERNEL_DIR" && git pull && cd "$BUILD_DIR"
    fi
    
    # Clone device trees
    if [ ! -d "$DT_DIR" ]; then
        log_info "Cloning device trees repository..."
        git clone https://github.com/garnet-random/android_kernel_xiaomi_sm7435-devicetrees.git devicetrees
    else
        log_info "Updating device trees repository..."
        cd "$DT_DIR" && git pull && cd "$BUILD_DIR"
    fi
    
    # Clone modules
    if [ ! -d "$MODULES_DIR" ]; then
        log_info "Cloning modules repository..."
        git clone https://github.com/garnet-random/android_kernel_xiaomi_sm7435-modules.git modules
    else
        log_info "Updating modules repository..."
        cd "$MODULES_DIR" && git pull && cd "$BUILD_DIR"
    fi
    
    log_success "Repository cloning/updating completed"
}

# Clone and integrate Sukisu Ultra (KernelSU fork)
setup_sukisu_ultra() {
    if [ "$ENABLE_SUKISU_ULTRA" != "true" ]; then
        log_info "Sukisu Ultra integration disabled"
        return 0
    fi
    
    log_info "Setting up Sukisu Ultra (KernelSU fork)..."
    
    cd "$BUILD_DIR"
    
    # Clone Sukisu Ultra if not exists
    if [ ! -d "$SUKISU_DIR" ]; then
        log_info "Cloning Sukisu Ultra repository..."
        git clone https://github.com/SukiSU-Ultra/SukiSU-Ultra.git sukisu-ultra
    else
        log_info "Updating Sukisu Ultra repository..."
        cd "$SUKISU_DIR" && git pull && cd "$BUILD_DIR"
    fi
    
    # Integrate Sukisu Ultra into kernel
    log_info "Integrating Sukisu Ultra into kernel..."
    cd "$KERNEL_DIR"
    
    # Run Sukisu Ultra setup script with comprehensive error handling
    if [ -f "$SUKISU_DIR/kernel/setup.sh" ]; then
        log_info "Running Sukisu Ultra setup script with susfs-main branch..."
        if bash "$SUKISU_DIR/kernel/setup.sh" susfs-main 2>&1 | tee setup_sukisu.log; then
            log_success "Sukisu Ultra integration completed successfully"
            # Verify integration
            if [ -d "drivers/kernelsu" ] && [ -f "drivers/kernelsu/Makefile" ]; then
                log_success "KernelSU drivers successfully integrated"
            else
                log_warning "KernelSU drivers not found after setup script - attempting manual integration"
                manual_sukisu_integration
            fi
        else
            log_error "Sukisu Ultra setup script failed (exit code: $?)"
            log_info "Check setup_sukisu.log for details. Attempting manual integration..."
            manual_sukisu_integration
        fi
    else
        log_warning "Sukisu Ultra setup script not found, attempting manual integration"
        manual_sukisu_integration
    fi
}

# Manual Sukisu Ultra integration function
manual_sukisu_integration() {
    if [ -d "$SUKISU_DIR/kernel" ]; then
        log_info "Attempting manual Sukisu Ultra integration..."
        
        # Copy KernelSU source files with verification
        if [ -d "$SUKISU_DIR/kernel/drivers/kernelsu" ]; then
            mkdir -p drivers/kernelsu
            if cp -r "$SUKISU_DIR/kernel/drivers/kernelsu"/* drivers/kernelsu/ 2>/dev/null; then
                log_success "KernelSU drivers copied successfully"
                
                # Verify critical files exist
                local required_files=("drivers/kernelsu/Makefile" "drivers/kernelsu/core_hook.c" "drivers/kernelsu/ksu.c")
                for file in "${required_files[@]}"; do
                    if [ ! -f "$file" ]; then
                        log_warning "Critical KernelSU file missing: $file"
                    fi
                done
            else
                log_error "Failed to copy KernelSU drivers"
                return 1
            fi
        else
            log_error "KernelSU drivers directory not found in Sukisu Ultra repository"
            return 1
        fi
        
        # Apply patches with better error handling
        local patch_count=0
        local failed_patches=0
        if [ -d "$SUKISU_DIR/kernel/patches" ]; then
            for patch in "$SUKISU_DIR/kernel/patches"/*.patch; do
                if [ -f "$patch" ]; then
                    patch_count=$((patch_count + 1))
                    log_info "Applying patch: $(basename "$patch")"
                    if patch -p1 --dry-run < "$patch" &>/dev/null; then
                        if patch -p1 < "$patch" &>/dev/null; then
                            log_success "Patch $(basename "$patch") applied successfully"
                        else
                            log_warning "Patch $(basename "$patch") failed to apply"
                            failed_patches=$((failed_patches + 1))
                        fi
                    else
                        log_warning "Patch $(basename "$patch") would fail - skipping"
                        failed_patches=$((failed_patches + 1))
                    fi
                fi
            done
            
            if [ $patch_count -gt 0 ]; then
                log_info "Applied $((patch_count - failed_patches))/$patch_count patches successfully"
            fi
        else
            log_info "No patches directory found - proceeding without patches"
        fi
        
        # Copy additional integration files if they exist
        if [ -d "$SUKISU_DIR/kernel/include" ]; then
            cp -r "$SUKISU_DIR/kernel/include"/* include/ 2>/dev/null || true
            log_info "Copied additional include files"
        fi
        
        if [ -d "$SUKISU_DIR/kernel/fs" ]; then
            cp -r "$SUKISU_DIR/kernel/fs"/* fs/ 2>/dev/null || true
            log_info "Copied additional filesystem files"
        fi
        
        log_success "Manual Sukisu Ultra integration completed"
        return 0
    else
        log_error "Sukisu Ultra kernel directory not found"
        return 1
    fi
}

# Clone and integrate SUSFS (root hiding filesystem)
setup_susfs() {
    if [ "$ENABLE_SUSFS" != "true" ]; then
        log_info "SUSFS integration disabled"
        return 0
    fi
    
    log_info "Setting up SUSFS (root hiding filesystem)..."
    
    cd "$BUILD_DIR"
    
    # Clone SUSFS module if not exists
    if [ ! -d "$SUSFS_DIR" ]; then
        log_info "Cloning SUSFS repository..."
        # Use the main SUSFS repository that works with KernelSU
        git clone https://github.com/sidex15/susfs4ksu-module.git susfs
    else
        log_info "Updating SUSFS repository..."
        cd "$SUSFS_DIR" && git pull && cd "$BUILD_DIR"
    fi
    
    # Integrate SUSFS into kernel
    log_info "Integrating SUSFS into kernel..."
    cd "$KERNEL_DIR"
    
    # Check if SUSFS kernel patches exist
    if [ -d "$SUSFS_DIR/kernel_patches" ]; then
        log_info "Applying SUSFS kernel patches..."
        for patch in "$SUSFS_DIR/kernel_patches"/*.patch; do
            if [ -f "$patch" ]; then
                log_info "Applying SUSFS patch: $(basename "$patch")"
                patch -p1 < "$patch" || log_warning "SUSFS patch $(basename "$patch") failed to apply"
            fi
        done
    fi
    
    # Copy SUSFS filesystem code if available
    if [ -d "$SUSFS_DIR/ksu_module_susfs" ]; then
        log_info "Integrating SUSFS filesystem code..."
        
        # Create SUSFS directory in filesystem
        mkdir -p fs/susfs
        if [ -d "$SUSFS_DIR/ksu_module_susfs/jni" ]; then
            cp -r "$SUSFS_DIR/ksu_module_susfs/jni"/* fs/susfs/ 2>/dev/null || true
        fi
        
        # Copy SUSFS headers to include directory
        if [ -f "$SUSFS_DIR/ksu_module_susfs/jni/susfs.h" ]; then
            mkdir -p include/linux
            cp "$SUSFS_DIR/ksu_module_susfs/jni/susfs.h" include/linux/susfs.h
            log_success "Copied SUSFS header to include/linux/susfs.h"
        else
            # Create a minimal susfs.h header if not found
            log_warning "SUSFS header not found, creating minimal header"
            mkdir -p include/linux
            cat > include/linux/susfs.h << 'EOF'
#ifndef _LINUX_SUSFS_H
#define _LINUX_SUSFS_H

/* Minimal SUSFS header for compilation compatibility */
#ifdef CONFIG_KSU_SUSFS
/* SUSFS function declarations would go here */
#endif

#endif /* _LINUX_SUSFS_H */
EOF
            log_info "Created minimal SUSFS header for compilation"
        fi
    fi
    
    log_success "SUSFS integration completed"
}

# Setup kernel configuration
setup_kernel_config() {
    log_info "Setting up kernel configuration..."
    
    cd "$KERNEL_DIR"
    
    # Use GKI defconfig with garnet-specific config fragment
    log_info "Setting up GKI base configuration with garnet-specific fragment..."
    make O=out ARCH=arm64 gki_defconfig
    
    # Apply garnet-specific config fragment if available
    if [ -f "arch/arm64/configs/vendor/garnet_GKI.config" ]; then
        log_info "Applying garnet GKI config fragment..."
        cat arch/arm64/configs/vendor/garnet_GKI.config >> out/.config
        log_success "Applied garnet-specific GKI configuration"
    else
        log_warning "Garnet GKI config not found, using base GKI configuration"
    fi
    
    # Enable additional configs for Sukisu Ultra and SUSFS
    if [ "$ENABLE_SUKISU_ULTRA" == "true" ] || [ "$ENABLE_SUSFS" == "true" ]; then
        log_info "Enabling additional kernel configurations for root features..."
        
        # Create additional config file
        cat >> out/.config << EOF

# KernelSU / Sukisu Ultra configurations
CONFIG_SECURITY=y
CONFIG_SECURITY_NETWORK=y
CONFIG_LSM="lockdown,yama,loadpin,safesetid,integrity,selinux,smack,tomoyo,apparmor"
CONFIG_SECURITY_SELINUX=y
CONFIG_SECURITY_SELINUX_BOOTPARAM=y
CONFIG_SECURITY_SELINUX_DEVELOP=y
CONFIG_SECURITY_SELINUX_AVC_STATS=y
CONFIG_SECURITY_SELINUX_CHECKREQPROT_VALUE=0
CONFIG_SECURITY_SELINUX_SIDTAB_HASH_BITS=9
CONFIG_SECURITY_SELINUX_SID2STR_CACHE_SIZE=256

# Enable loadable module support for KernelSU
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y
CONFIG_MODVERSIONS=y
CONFIG_MODULE_SRCVERSION_ALL=y

# Enable overlayfs for SUSFS
CONFIG_OVERLAY_FS=y
CONFIG_OVERLAY_FS_REDIRECT_DIR=y
CONFIG_OVERLAY_FS_REDIRECT_ALWAYS_FOLLOW=y
CONFIG_OVERLAY_FS_INDEX=y
CONFIG_OVERLAY_FS_NFS_EXPORT=y
CONFIG_OVERLAY_FS_XINO_AUTO=y
CONFIG_OVERLAY_FS_METACOPY=y

# Advanced SUSFS filesystem configurations
CONFIG_FUSE_FS=y
CONFIG_CUSE=y
CONFIG_PROC_FS=y
CONFIG_PROC_SYSCTL=y
CONFIG_SYSFS=y
CONFIG_TMPFS=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_TMPFS_XATTR=y

# Advanced security features for SUSFS root hiding
CONFIG_SECURITY_DMESG_RESTRICT=y
CONFIG_SECURITY_PERF_EVENTS_RESTRICT=y
# CONFIG_FORTIFY_SOURCE is not set
CONFIG_HARDENED_USERCOPY=y
CONFIG_HARDENED_USERCOPY_FALLBACK=y
CONFIG_SLAB_FREELIST_RANDOM=y
CONFIG_SLAB_FREELIST_HARDENED=y
CONFIG_SHUFFLE_PAGE_ALLOCATOR=y
CONFIG_SLUB_DEBUG=y

# Memory protection for SUSFS
CONFIG_STRICT_KERNEL_RWX=y
CONFIG_STRICT_MODULE_RWX=y
CONFIG_PAGE_TABLE_ISOLATION=y
CONFIG_RETPOLINE=y
CONFIG_SLS=y

# Additional mount and filesystem features for SUSFS
CONFIG_FANOTIFY=y
CONFIG_FANOTIFY_ACCESS_PERMISSIONS=y
CONFIG_QUOTA=y
CONFIG_QFMT_V2=y
CONFIG_QUOTACTL=y

# Enable namespace support for root hiding
CONFIG_NAMESPACES=y
CONFIG_UTS_NS=y
CONFIG_IPC_NS=y
CONFIG_USER_NS=y
CONFIG_PID_NS=y
CONFIG_NET_NS=y
CONFIG_CGROUP_NS=y

# Enable file capabilities
CONFIG_SECURITY_FILE_CAPABILITIES=y

# Enable audit for security monitoring
CONFIG_AUDIT=y
CONFIG_AUDITSYSCALL=y

# KPM (Kernel Patch Module) support for Sukisu Ultra
CONFIG_KPM=y

# KALLSYMS support required for Sukisu Ultra
CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y
CONFIG_KALLSYMS_ABSOLUTE_PERCPU=y
CONFIG_KALLSYMS_BASE_RELATIVE=y

# Disable warnings as errors to prevent build failures
# CONFIG_WERROR is not set
CONFIG_COMPILE_TEST=n

# Disable problematic drivers that cause format warnings
# CONFIG_CLK_QCOM is not set

# Enable SUSFS for KernelSU integration
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SUS_OVERLAYFS=y
CONFIG_KSU_SUSFS_TRY_UMOUNT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y

EOF
        
        # Regenerate config to resolve dependencies
        make O=out ARCH=arm64 olddefconfig
        log_success "Additional kernel configurations enabled"
    fi
    
    log_success "Kernel configuration completed"
}

# Build kernel with automatic config answers
build_kernel() {
    log_info "Starting kernel build..."
    
    cd "$KERNEL_DIR"
    
    # Create output directory
    mkdir -p out
    
    # Answer common config questions automatically
    export KCONFIG_NOTIMESTAMP=1
    
    # Build with automatic yes to new config options
    log_info "Building kernel (this may take a while)..."
    
    # Disable warnings as errors during compilation with comprehensive flags
    export KCFLAGS="-Wno-error -Wno-format -Wno-unused-variable -Wno-format-extra-args -Wno-array-bounds -Wno-stringop-overflow"
    export HOSTCFLAGS="-Wno-error -Wno-format"
    
    # Disable CONFIG_FORTIFY_SOURCE and strict copy checking to fix KPM compilation
    sed -i 's/CONFIG_FORTIFY_SOURCE=y/# CONFIG_FORTIFY_SOURCE is not set/' out/.config 2>/dev/null || true
    sed -i 's/CONFIG_HARDENED_USERCOPY=y/# CONFIG_HARDENED_USERCOPY is not set/' out/.config 2>/dev/null || true
    
    # Add specific flags to disable hardened copy checks during compilation
    export KCFLAGS="$KCFLAGS -D__NO_FORTIFY -fno-stack-protector"
    
    # Patch KPM file to fix copy_to_user issues
    if [ -f "drivers/kernelsu/kpm/kpm.c" ]; then
        log_info "Patching KPM copy_to_user calls to fix compilation issues..."
        # Replace the problematic copy_to_user calls with put_user
        sed -i 's/if(copy_to_user(result, \&res, sizeof(res)) < 1)/if(put_user(res, (int __user *)result))/g' drivers/kernelsu/kpm/kpm.c
    fi
    
    make O=out ARCH=arm64 -j$(nproc) KCFLAGS="$KCFLAGS" HOSTCFLAGS="$HOSTCFLAGS" 2>&1 | tee build.log
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "Kernel build completed successfully!"
        
        # Check for output files
        if [ -f "out/arch/arm64/boot/Image" ]; then
            log_success "Kernel Image created: $KERNEL_DIR/out/arch/arm64/boot/Image"
        fi
        
        if [ -f "out/arch/arm64/boot/Image.gz" ]; then
            log_success "Compressed kernel Image created: $KERNEL_DIR/out/arch/arm64/boot/Image.gz"
        fi
        
        if [ -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
            log_success "Kernel with DTB created: $KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb"
        fi
        
        # Build modules
        log_info "Building kernel modules..."
        make O=out ARCH=arm64 modules -j$(nproc) KCFLAGS="$KCFLAGS" HOSTCFLAGS="$HOSTCFLAGS"
        
        if [ $? -eq 0 ]; then
            log_success "Kernel modules built successfully!"
        else
            log_warning "Kernel modules build had issues (check build.log)"
        fi
        
    else
        log_error "Kernel build failed! Check build.log for details"
        exit 1
    fi
}

# Create flashable output
create_output() {
    log_info "Creating flashable output..."
    
    local output_dir="${BUILD_DIR}/output"
    mkdir -p "$output_dir"
    
    cd "$KERNEL_DIR"
    
    # Copy kernel images
    if [ -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
        cp "out/arch/arm64/boot/Image.gz-dtb" "$output_dir/"
        log_success "Copied Image.gz-dtb to output directory"
    elif [ -f "out/arch/arm64/boot/Image.gz" ]; then
        cp "out/arch/arm64/boot/Image.gz" "$output_dir/"
        log_success "Copied Image.gz to output directory"
    elif [ -f "out/arch/arm64/boot/Image" ]; then
        cp "out/arch/arm64/boot/Image" "$output_dir/"
        log_success "Copied Image to output directory"
    fi
    
    # Copy DTB files if they exist separately
    if [ -d "out/arch/arm64/boot/dts" ]; then
        find out/arch/arm64/boot/dts -name "*.dtb" -exec cp {} "$output_dir/" \;
        log_success "Copied DTB files to output directory"
    fi
    
    # Create AnyKernel3 flashable ZIP if enabled
    if [ "$ENABLE_ANYKERNEL3" == "true" ]; then
        create_anykernel3_zip "$output_dir"
        log_success "Output files created in: $output_dir"
        log_info "Flash the AnyKernel3 ZIP using TWRP/custom recovery"
    else
        log_success "Output files created in: $output_dir"
        log_info "You can flash these files using fastboot or your preferred method"
    fi
}

# Create AnyKernel3 flashable ZIP
create_anykernel3_zip() {
    local output_dir="$1"
    log_info "Creating AnyKernel3 flashable ZIP..."
    
    local ak3_dir="${BUILD_DIR}/AnyKernel3"
    local zip_name="Garnet-Kernel-SukiSU-SUSFS-$(date +%Y%m%d-%H%M).zip"
    
    # Clone AnyKernel3 if not exists
    if [ ! -d "$ak3_dir" ]; then
        log_info "Cloning AnyKernel3 repository..."
        cd "$BUILD_DIR"
        git clone https://github.com/osm0sis/AnyKernel3.git
    else
        log_info "Updating AnyKernel3 repository..."
        cd "$ak3_dir" && git pull && cd "$BUILD_DIR"
    fi
    
    cd "$ak3_dir"
    
    # Clean previous builds
    rm -f *.zip Image* dtb *.dtbo
    
    # Copy kernel image
    if [ -f "$output_dir/Image.gz-dtb" ]; then
        cp "$output_dir/Image.gz-dtb" .
        kernel_image="Image.gz-dtb"
    elif [ -f "$output_dir/Image.gz" ]; then
        cp "$output_dir/Image.gz" .
        kernel_image="Image.gz"
    elif [ -f "$output_dir/Image" ]; then
        cp "$output_dir/Image" .
        kernel_image="Image"
    else
        log_error "No kernel image found to package"
        return 1
    fi
    
    # Copy DTB files if they exist
    find "$output_dir" -name "*.dtb" -exec cp {} . \; 2>/dev/null || true
    
    # Create/update anykernel.sh configuration
    cat > anykernel.sh << 'EOF'
# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
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
supported.patchlevels=
'; } # end properties

# shell variables
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=1;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;

## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
set_perm_recursive 0 0 755 644 $ramdisk/*;
set_perm_recursive 0 0 750 750 $ramdisk/init* $ramdisk/sbin;

## AnyKernel boot install
dump_boot;

# begin ramdisk changes

# init.rc
if [ -f $ramdisk/init.rc ]; then
  backup_file init.rc;
fi;

# end ramdisk changes

write_boot;
## end boot install
EOF
    
    # Create ZIP package
    log_info "Packaging AnyKernel3 ZIP: $zip_name"
    zip -r9 "$zip_name" * -x .git README.md *placeholder
    
    # Move ZIP to output directory
    mv "$zip_name" "$output_dir/"
    
    log_success "AnyKernel3 ZIP created: $output_dir/$zip_name"
}

# Main execution
main() {
    log_info "Starting Android Kernel Build for Redmi Note 13 Pro 5G (garnet)"
    log_info "Features: Sukisu Ultra ($ENABLE_SUKISU_ULTRA) | SUSFS ($ENABLE_SUSFS)"
    log_info "Build directory: $BUILD_DIR"
    
    check_dependencies
    setup_toolchain
    clone_repositories
    setup_sukisu_ultra
    setup_susfs
    setup_kernel_config
    build_kernel
    create_output
    
    log_success "Kernel build process completed!"
    log_info "Check $BUILD_DIR/output/ for flashable files"
}

# Handle script interruption
trap 'log_error "Build interrupted by user"; exit 130' INT

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-sukisu)
                ENABLE_SUKISU_ULTRA=false
                log_info "Sukisu Ultra disabled"
                ;;
            --no-susfs)
                ENABLE_SUSFS=false
                log_info "SUSFS disabled"
                ;;
            --no-anykernel3)
                ENABLE_ANYKERNEL3=false
                log_info "AnyKernel3 ZIP creation disabled"
                ;;
            --sukisu-only)
                ENABLE_SUKISU_ULTRA=true
                ENABLE_SUSFS=false
                log_info "Building with Sukisu Ultra only"
                ;;
            --susfs-only)
                ENABLE_SUKISU_ULTRA=false
                ENABLE_SUSFS=true
                log_info "Building with SUSFS only"
                ;;
            --stock)
                ENABLE_SUKISU_ULTRA=false
                ENABLE_SUSFS=false
                log_info "Building stock kernel without root features"
                ;;
            --clean)
                clean_build
                exit 0
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# Clean build artifacts (preserves source code and integrations)
clean_build() {
    log_info "Cleaning build artifacts..."
    
    if [ -d "$KERNEL_DIR" ]; then
        cd "$KERNEL_DIR"
        
        # Clean kernel build artifacts only
        if [ -d "out" ]; then
            log_info "Removing kernel build output directory..."
            rm -rf out/
        fi
        
        # Clean build logs
        if [ -f "build.log" ]; then
            rm -f build.log
        fi
        
        if [ -f "setup_sukisu.log" ]; then
            rm -f setup_sukisu.log
        fi
        
        # Clean compiled objects and temporary files (preserves source)
        find . -name "*.o" -delete 2>/dev/null || true
        find . -name "*.ko" -delete 2>/dev/null || true
        find . -name ".*.cmd" -delete 2>/dev/null || true
        find . -name "*.mod" -delete 2>/dev/null || true
        find . -name "modules.builtin" -delete 2>/dev/null || true
        find . -name "modules.order" -delete 2>/dev/null || true
        find . -name ".tmp_versions" -type d -exec rm -rf {} + 2>/dev/null || true
        
        log_success "Build artifacts cleaned"
        log_info "Preserved: Sukisu Ultra integration, SUSFS integration, kernel source"
    fi
    
    # Clean output directory
    if [ -d "${BUILD_DIR}/output" ]; then
        log_info "Removing output directory..."
        rm -rf "${BUILD_DIR}/output"
    fi
    
    # Clean AnyKernel3 build artifacts (preserves repository)
    if [ -d "${BUILD_DIR}/AnyKernel3" ]; then
        cd "${BUILD_DIR}/AnyKernel3"
        rm -f *.zip Image* *.dtb *.dtbo 2>/dev/null || true
        log_info "Cleaned AnyKernel3 build artifacts"
    fi
}

# Show help information
show_help() {
    cat << EOF
Android Kernel Build Script for Redmi Note 13 Pro 5G (garnet)
Builds kernel with Sukisu Ultra (KernelSU fork) and SUSFS root hiding

Usage: $0 [OPTIONS]

Options:
  --no-sukisu      Disable Sukisu Ultra integration
  --no-susfs       Disable SUSFS integration
  --no-anykernel3  Disable AnyKernel3 ZIP creation
  --sukisu-only    Build with Sukisu Ultra only (no SUSFS)
  --susfs-only     Build with SUSFS only (no Sukisu Ultra)
  --stock          Build stock kernel without root features
  --clean          Clean build artifacts (preserves source and integrations)
  --help, -h       Show this help message

Default: Builds with both Sukisu Ultra and SUSFS enabled

Examples:
  $0                    # Build with all features
  $0 --stock            # Build stock kernel
  $0 --sukisu-only      # Build with KernelSU only
  $0 --no-anykernel3    # Build without creating flashable ZIP

EOF
}

# Run main function
parse_args "$@"
main