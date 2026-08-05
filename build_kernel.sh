#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if [ -z "${1:-}" ]; then
    echo "[!] Error: No device specified."
    echo "Usage: $0 <device_name> [ksu] [miui|aosp]"
    exit 1
fi

DEVICE_NAME="$1"
DEFCONFIG="${DEVICE_NAME}_defconfig"
if [ ! -f "arch/arm64/configs/${DEFCONFIG}" ]; then
    echo "[!] Error: Defconfig not found: ${DEFCONFIG}"
    exit 1
fi

ENABLE_KSU=0
TARGET_OS=""
shift
for arg in "$@"; do
    case "$arg" in
        ksu) ENABLE_KSU=1 ;;
        miui) TARGET_OS="miui" ;;
        aosp) TARGET_OS="aosp" ;;
    esac
done

if [ -z "$TARGET_OS" ]; then
    echo "[!] Error: Specify miui or aosp"
    exit 1
fi

KERNEL_DIR="$(pwd)"
TOOLCHAIN_BIN="$HOME/zyc-clang/bin"
export PATH="${TOOLCHAIN_BIN}:${PATH}"
export ARCH="arm64"
export SUBARCH="arm64"
export CCACHE_DIR="$HOME/.cache/ccache_mikernel"
export CCACHE_EXEC=$(command -v ccache || true)
if [ -z "$CCACHE_EXEC" ]; then
    echo "[!] ccache not found!"
    exit 1
fi
export USE_CCACHE=1
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"

echo "[*] Cleaning Git working tree (original repo)..."
if git rev-parse --git-dir >/dev/null 2>&1; then
    git reset --hard HEAD
    git clean -fd
fi

echo "[*] Checking Clang..."
clang --version || { echo "[!] Clang not found"; exit 1; }
mkdir -p "$CCACHE_DIR"

echo "[*] Cloning AnyKernel3 into workspace..."
rm -rf anykernel
git clone https://github.com/AstideLabs/AnyKernel3 -b master --single-branch --depth=1 anykernel || { echo "[!] Failed to clone AnyKernel3"; exit 1; }
echo "[+] AnyKernel3 ready."

build_target() {
    local OS_TYPE=$1
    echo "==========================================="
    echo " Building ${DEVICE_NAME} (Target: $OS_TYPE)"
    echo "==========================================="

    local OUT_DIR="${KERNEL_DIR}/out_${OS_TYPE}"
    rm -rf "${OUT_DIR}"
    mkdir -p "${OUT_DIR}"

    local BUILD_SRC="${KERNEL_DIR}/.build_src_${OS_TYPE}"
    rm -rf "${BUILD_SRC}"
    mkdir -p "${BUILD_SRC}"

    echo "[*] Copying source to temporary build directory (${BUILD_SRC})..."
    rsync -a --exclude='.git' \
              --exclude='out_*' \
              --exclude='anykernel' \
              --exclude='.build_src_*' \
              --exclude='*.zip' \
              --exclude='.github' \
              "${KERNEL_DIR}/" "${BUILD_SRC}/"

    pushd "${BUILD_SRC}" >/dev/null

    export CONFIG_="CONFIG_"
    export PATH="$(pwd)/scripts:${PATH}"

    if [ "$ENABLE_KSU" -eq 1 ]; then
        echo "[*] Setting up KernelSU inside build copy..."
        curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash
        echo "[+] KernelSU done."
    fi

    echo "[*] Setting up Baseband-guard inside build copy..."
    wget -qO- https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash
    if [ -f security/Kconfig ]; then
        sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' security/Kconfig || true
    fi
    echo "[+] Baseband-guard done."

    local DTS_SOURCE="arch/arm64/boot/dts/vendor/qcom"
    local DTS_BACKUP=".dts.bak.${OS_TYPE}"
    if [ "$OS_TYPE" == "miui" ]; then
        if [ -d "${DTS_SOURCE}" ]; then
            cp -a "${DTS_SOURCE}" "${DTS_BACKUP}"
            sed -i 's/<154>/<1537>/g' ${DTS_SOURCE}/dsi-panel-j1s* || true
            sed -i 's/<154>/<1537>/g' ${DTS_SOURCE}/dsi-panel-j2* || true
            sed -i 's/<155>/<1544>/g' ${DTS_SOURCE}/dsi-panel-j3s-37-02-0a-dsc-video.dtsi || true
            sed -i 's/<155>/<1545>/g' ${DTS_SOURCE}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi || true
            sed -i 's/<155>/<1546>/g' ${DTS_SOURCE}/dsi-panel-k11a-38-08-0a-dsc-cmd.dtsi || true
            sed -i 's/<155>/<1546>/g' ${DTS_SOURCE}/dsi-panel-l11r-38-08-0a-dsc-cmd.dtsi || true
            sed -i 's/<70>/<695>/g' ${DTS_SOURCE}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi || true
            sed -i 's/<70>/<695>/g' ${DTS_SOURCE}/dsi-panel-j3s-37-02-0a-dsc-video.dtsi || true
            sed -i 's/<70>/<695>/g' ${DTS_SOURCE}/dsi-panel-k11a-38-08-0a-dsc-cmd.dtsi || true
            sed -i 's/<70>/<695>/g' ${DTS_SOURCE}/dsi-panel-l11r-38-08-0a-dsc-cmd.dtsi || true
            sed -i 's/<71>/<710>/g' ${DTS_SOURCE}/dsi-panel-j1s* || true
            sed -i 's/<71>/<710>/g' ${DTS_SOURCE}/dsi-panel-j2* || true
            sed -i 's/\/\/ mi,mdss-dsi-pan-enable-smart-fps/mi,mdss-dsi-pan-enable-smart-fps/g' ${DTS_SOURCE}/dsi-panel* || true
            sed -i 's/\/\/ mi,mdss-dsi-smart-fps-max_framerate/mi,mdss-dsi-smart-fps-max_framerate/g' ${DTS_SOURCE}/dsi-panel* || true
            sed -i 's/\/\/ qcom,mdss-dsi-pan-enable-smart-fps/qcom,mdss-dsi-pan-enable-smart-fps/g' ${DTS_SOURCE}/dsi-panel* || true
            sed -i 's/qcom,mdss-dsi-qsync-min-refresh-rate/\/\/qcom,mdss-dsi-qsync-min-refresh-rate/g' ${DTS_SOURCE}/dsi-panel* || true
            sed -i 's/120 90 60/120 90 60 50 30/g' ${DTS_SOURCE}/dsi-panel-g7a-36-02-0c-dsc-video.dtsi || true
            sed -i 's/120 90 60/120 90 60 50 30/g' ${DTS_SOURCE}/dsi-panel-g7a-37-02-0a-dsc-video.dtsi || true
            sed -i 's/120 90 60/120 90 60 50 30/g' ${DTS_SOURCE}/dsi-panel-g7a-37-02-0b-dsc-video.dtsi || true
            sed -i 's/144 120 90 60/144 120 90 60 50 48 30/g' ${DTS_SOURCE}/dsi-panel-j3s-37-02-0a-dsc-video.dtsi || true
            sed -i 's/\/\/39 00 00 00 00 00 03 51 03 FF/39 00 00 00 00 00 03 51 03 FF/g' ${DTS_SOURCE}/dsi-panel-j9-38-0a-0a-fhd-video.dtsi || true
            sed -i 's/\/\/39 00 00 00 00 00 03 51 0D FF/39 00 00 00 00 00 03 51 0D FF/g' ${DTS_SOURCE}/dsi-panel-j2-p2-1-38-0c-0a-dsc-cmd.dtsi || true
            sed -i 's/\/\/39 00 00 00 00 00 05 51 0F 8F 00 00/39 00 00 00 00 00 05 51 0F 8F 00 00/g' ${DTS_SOURCE}/dsi-panel-j1s-42-02-0a-dsc-cmd.dtsi || true
            sed -i 's/\/\/39 00 00 00 00 00 05 51 0F 8F 00 00/39 00 00 00 00 00 05 51 0F 8F 00 00/g' ${DTS_SOURCE}/dsi-panel-j1s-42-02-0a-mp-dsc-cmd.dtsi || true
            sed -i 's/\/\/39 00 00 00 00 00 05 51 0F 8F 00 00/39 00 00 00 00 00 05 51 0F 8F 00 00/g' ${DTS_SOURCE}/dsi-panel-j2-mp-42-02-0b-dsc-cmd.dtsi || true
            sed -i 's/\/\/39 00 00 00 00 00 05 51 0F 8F 00 00/39 00 00 00 00 00 05 51 0F 8F 00 00/g' ${DTS_SOURCE}/dsi-panel-j2-p2-1-42-02-0b-dsc-cmd.dtsi || true
            sed -i 's/\/\/39 01 00 00 00 00 03 51 00 00/39 01 00 00 00 00 03 51 00 00/g' ${DTS_SOURCE}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi || true
            sed -i 's/\/\/39 01 00 00 00 00 03 51 03 FF/39 01 00 00 00 00 03 51 03 FF/g' ${DTS_SOURCE}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi || true
            sed -i 's/\/\/39 01 00 00 00 00 03 51 03 FF/39 01 00 00 00 00 03 51 03 FF/g' ${DTS_SOURCE}/dsi-panel-j9-38-0a-0a-fhd-video.dtsi || true
            sed -i 's/\/\/39 01 00 00 00 00 03 51 07 FF/39 01 00 00 00 00 03 51 07 FF/g' ${DTS_SOURCE}/dsi-panel-j1u-42-02-0b-dsc-cmd.dtsi || true
            sed -i 's/\/\/39 01 00 00 00 00 03 51 07 FF/39 01 00 00 00 00 03 51 07 FF/g' ${DTS_SOURCE}/dsi-panel-j2-42-02-0b-dsc-cmd.dtsi || true
            sed -i 's/\/\/39 01 00 00 00 00 03 51 07 FF/39 01 00 00 00 00 03 51 07 FF/g' ${DTS_SOURCE}/dsi-panel-j2-p1-42-02-0b-dsc-cmd.dtsi || true
            sed -i 's/\/\/39 01 00 00 00 00 03 51 0F FF/39 01 00 00 00 00 03 51 0F FF/g' ${DTS_SOURCE}/dsi-panel-j1u-42-02-0b-dsc-cmd.dtsi || true
            sed -i 's/\/\/39 01 00 00 00 00 03 51 0F FF/39 01 00 00 00 00 03 51 0F FF/g' ${DTS_SOURCE}/dsi-panel-j2-42-02-0b-dsc-cmd.dtsi || true
            sed -i 's/\/\/39 01 00 00 00 00 03 51 0F FF/39 01 00 00 00 00 03 51 0F FF/g' ${DTS_SOURCE}/dsi-panel-j2-p1-42-02-0b-dsc-cmd.dtsi || true
            sed -i 's/\/\/39 01 00 00 00 00 05 51 07 FF 00 00/39 01 00 00 00 00 05 51 07 FF 00 00/g' ${DTS_SOURCE}/dsi-panel-j1s-42-02-0a-dsc-cmd.dtsi || true
            sed -i 's/\/\/39 01 00 00 00 00 05 51 07 FF 00 00/39 01 00 00 00 00 05 51 07 FF 00 00/g' ${DTS_SOURCE}/dsi-panel-j1s-42-02-0a-mp-dsc-cmd.dtsi || true
            sed -i 's/\/\/39 01 00 00 00 00 05 51 07 FF 00 00/39 01 00 00 00 00 05 51 07 FF 00 00/g' ${DTS_SOURCE}/dsi-panel-j2-mp-42-02-0b-dsc-cmd.dtsi || true
            sed -i 's/\/\/39 01 00 00 00 00 05 51 07 FF 00 00/39 01 00 00 00 00 05 51 07 FF 00 00/g' ${DTS_SOURCE}/dsi-panel-j2-p2-1-42-02-0b-dsc-cmd.dtsi || true
            sed -i 's/\/\/39 01 00 00 00 00 05 51 07 FF 00 00/39 01 00 00 00 00 05 51 07 FF 00 00/g' ${DTS_SOURCE}/dsi-panel-j2s-mp-42-02-0a-dsc-cmd.dtsi || true
            sed -i 's/\/\/39 01 00 00 00 00 01 00 03 51 03 FF/39 01 00 00 00 00 01 00 03 51 03 FF/g' ${DTS_SOURCE}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi || true
            sed -i 's/\/\/39 01 00 00 00 11 00 03 51 03 FF/39 01 00 00 11 00 03 51 03 FF/g' ${DTS_SOURCE}/dsi-panel-j2-p2-1-38-0c-0a-dsc-cmd.dtsi || true
        fi
    fi

    echo "[*] Making defconfig: ${DEFCONFIG}..."
    make -j"$(nproc)" O="${OUT_DIR}" ARCH="${ARCH}" SUBARCH="${SUBARCH}" \
        LLVM=1 LLVM_IAS=1 \
        CC="ccache clang" HOSTCC="ccache clang" \
        CROSS_COMPILE="${CROSS_COMPILE}" CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32}" \
        "${DEFCONFIG}"

    echo "[*] Injecting Baseband-guard config..."
    "$(pwd)/scripts/config" --file "${OUT_DIR}/.config" -e BBG

    if [ "$ENABLE_KSU" -eq 1 ]; then
        echo "[*] Injecting KernelSU config..."
        "$(pwd)/scripts/config" --file "${OUT_DIR}/.config" \
            -e KSU \
            -e THREAD_INFO_IN_TASK \
            -e KSU_SUSFS
    fi

    if [ "$OS_TYPE" == "miui" ]; then
        echo "[*] Injecting MIUI configs..."
        "$(pwd)/scripts/config" --file "${OUT_DIR}/.config" \
            --set-str STATIC_USERMODEHELPER_PATH /system/bin/micd \
            -e PERF_CRITICAL_RT_TASK \
            -e SF_BINDER \
            -e OVERLAY_FS \
            -e MIGT \
            -e MIGT_ENERGY_MODEL \
            -e MIHW \
            -e PACKAGE_RUNTIME_INFO \
            -e BINDER_OPT \
            -e KPERFEVENTS \
            -e MILLET \
            -e PERF_HUMANTASK \
            -d LTO_CLANG \
            -e LTO_NONE \
            -d SHADOW_CALL_STACK \
            -e XIAOMI_MIUI \
            -d MI_MEMORY_SYSFS \
            -e TASK_DELAY_ACCT \
            -e MIUI_ZRAM_MEMORY_TRACKING \
            -e PERF_HELPER \
            -e BOOTUP_RECLAIM \
            -e MI_RECLAIM \
            -e RTMM \
            -d REKERNEL \
            -d REKERNEL_NETWORK
    fi

    if [ "$OS_TYPE" == "miui" ]; then
        if [ "$DEVICE_NAME" = "alioth" ]; then
            SUBLEVEL=157
            HASH="92c089fc2d37"
        else
            SUBLEVEL=325
            if [ -n "${BUILD_HASH:-}" ]; then
                HASH="$BUILD_HASH"
            else
                if git rev-parse --git-dir >/dev/null 2>&1; then
                    HASH=$(git rev-parse --short=12 HEAD) || { echo "[!] Failed to get git hash"; popd >/dev/null; rm -rf "${BUILD_SRC}"; exit 1; }
                else
                    echo "[!] Git metadata not available; please provide BUILD_HASH env or run in a git repo."
                    popd >/dev/null
                    rm -rf "${BUILD_SRC}"
                    exit 1
                fi
            fi
        fi

        if [ -f Makefile ]; then
            sed -E -i "s/^(SUBLEVEL[[:space:]]*=[[:space:]]*).*/\1${SUBLEVEL}/" Makefile || true
            sed -E -i "s/^(EXTRAVERSION[[:space:]]*=[[:space:]]*).*/\1/" Makefile || true
        else
            echo "[!] Makefile not found in build copy"; popd >/dev/null; rm -rf "${BUILD_SRC}"; exit 1
        fi

        "$(pwd)/scripts/config" --file "${OUT_DIR}/.config" \
            --set-val CONFIG_LOCALVERSION_AUTO n \
            --set-str LOCALVERSION "-perf-g${HASH}"

        mkdir -p "${OUT_DIR}/include/config"
        echo "4.19.${SUBLEVEL}-perf-g${HASH}" > "${OUT_DIR}/include/config/kernel.release"

        if [ "$DEVICE_NAME" = "alioth" ]; then
            export KBUILD_BUILD_USER="builder"
            export KBUILD_BUILD_HOST="pangu-build-component-vendor-727090-8pdx4-w2b4x-lb74b"
            export KBUILD_BUILD_TIMESTAMP="Wed Oct 29 11:41:46 UTC 2025"
            export KBUILD_BUILD_VERSION=1
        fi

        OUT_CFG="${OUT_DIR}/.config"
        LOCAL_STR="-perf-g${HASH}"

        "$(pwd)/scripts/config" --file "${OUT_CFG}" --set-val CONFIG_LOCALVERSION_AUTO n || true

        if grep -q '^CONFIG_LOCALVERSION=' "${OUT_CFG}" 2>/dev/null; then
            sed -i 's@^CONFIG_LOCALVERSION=.*@CONFIG_LOCALVERSION="'"${LOCAL_STR}"'@' "${OUT_CFG}" || true
        else
            echo "CONFIG_LOCALVERSION=\"${LOCAL_STR}\"" >> "${OUT_CFG}" || true
        fi

        rm -f .scmversion "${KERNEL_DIR}/.scmversion" || true

        echo "4.19.${SUBLEVEL}${LOCAL_STR}" > "${OUT_DIR}/include/config/kernel.release" || true

        echo "[*] CI-VERIFY: kernelrelease (for CI log only):"
        make -s O="${OUT_DIR}" kernelrelease || true
        if [ -f "${OUT_DIR}/include/config/kernel.release" ]; then
            echo "FINAL_KERNEL_RELEASE: $(cat "${OUT_DIR}/include/config/kernel.release")"
        fi
    fi

    echo "[*] Updating config (olddefconfig)..."
    make -j"$(nproc)" O="${OUT_DIR}" ARCH="${ARCH}" SUBARCH="${SUBARCH}" \
        LLVM=1 LLVM_IAS=1 \
        CC="ccache clang" HOSTCC="ccache clang" \
        CROSS_COMPILE="${CROSS_COMPILE}" CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32}" \
        olddefconfig

    echo "[*] Building kernel..."
    make -j"$(nproc)" O="${OUT_DIR}" ARCH="${ARCH}" SUBARCH="${SUBARCH}" \
        LLVM=1 LLVM_IAS=1 \
        CC="ccache clang" HOSTCC="ccache clang" \
        CROSS_COMPILE="${CROSS_COMPILE}" CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32}"

    {
        echo "[*] Detecting kernel version before packaging..."
        KERNEL_CANDIDATE=""
        if [ -n "${OUT_DIR:-}" ]; then
            KERNEL_CANDIDATE=$(find "${OUT_DIR}" -maxdepth 6 -type f \( -name 'Image' -o -name 'Image.gz' -o -name 'zImage' -o -name 'vmlinux' -o -name 'vmlinuz' -o -name 'System.map' \) 2>/dev/null | head -n1 || true)
        fi
        if [ -z "$KERNEL_CANDIDATE" ]; then
            KERNEL_CANDIDATE=$(find . -maxdepth 8 -type f -name '*.img' ! -iname '*dtbo*' 2>/dev/null | head -n1 || true)
        fi
        if [ -z "$KERNEL_CANDIDATE" ]; then
            echo "No kernel candidate found during build"
            echo "unknown" > "${KERNEL_DIR}/kernel_version.txt" || true
        else
            echo "Found kernel candidate: $KERNEL_CANDIDATE"
            if echo "$KERNEL_CANDIDATE" | grep -qE '\.gz$'; then
                STRINGS_CMD="gunzip -c \"$KERNEL_CANDIDATE\" | strings -a"
            else
                STRINGS_CMD="strings -a \"$KERNEL_CANDIDATE\""
            fi
            VER=$(/bin/sh -c "$STRINGS_CMD" | grep -a -m1 -E 'Linux version [0-9]+\.[0-9]+' || true)
            if [ -z "$VER" ]; then
                VER=$(/bin/sh -c "$STRINGS_CMD" | grep -a -m1 -E 'Kernel command line|Linux version' || true)
            fi
            if [ -n "$VER" ]; then
                echo "Detected kernel version: $VER"
                echo "$VER" > "${KERNEL_DIR}/kernel_version.txt" || true
            else
                echo "Could not detect kernel version from $KERNEL_CANDIDATE"
                echo "unknown" > "${KERNEL_DIR}/kernel_version.txt" || true
            fi
        fi
    } || true

    popd >/dev/null

    if [ -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
        echo "[+] Build Successful!"
        strings "${OUT_DIR}/arch/arm64/boot/Image" | grep "Linux version"
        find "${OUT_DIR}/arch/arm64/boot/dts" -name '*.dtb' -exec cat {} + > "${OUT_DIR}/arch/arm64/boot/dtb" || true

        rm -rf "${KERNEL_DIR}/anykernel/kernels/*"
        mkdir -p "${KERNEL_DIR}/anykernel/kernels/${OS_TYPE}/"
        cp "${OUT_DIR}/arch/arm64/boot/Image" "${KERNEL_DIR}/anykernel/kernels/${OS_TYPE}/"
        cp "${OUT_DIR}/arch/arm64/boot/dtb" "${KERNEL_DIR}/anykernel/kernels/${OS_TYPE}/"
        [ -f "${OUT_DIR}/arch/arm64/boot/dtbo.img" ] && cp "${OUT_DIR}/arch/arm64/boot/dtbo.img" "${KERNEL_DIR}/anykernel/kernels/${OS_TYPE}/"

        local KSU_STR="NoKernelSU"; [ "$ENABLE_KSU" -eq 1 ] && KSU_STR="ReSukiSU-SuSFS"
        local OS_UPPER=$(echo "$OS_TYPE" | tr '[:lower:]' '[:upper:]')
        local ZIP="${DEVICE_NAME}_${OS_UPPER}_${KSU_STR}_anykernel3.zip"
        (cd "${KERNEL_DIR}/anykernel" && zip -r9 "../${ZIP}" . -x '*.git*' 'out/*' '*.zip' > /dev/null)
        echo "[+] Packed: ${ZIP}"
    else
        echo "[-] Build Failed."
        rm -rf "${BUILD_SRC}" || true
        exit 1
    fi

    rm -rf "${BUILD_SRC}" || true
}

build_target "$TARGET_OS"

echo "[*] ccache stats:"; ccache -s || true
echo "[+] Done!"
