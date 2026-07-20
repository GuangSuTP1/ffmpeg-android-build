#!/usr/bin/env bash
set -euo pipefail

CROSS_FILE_NAME="crossfile-${ANDROID_ABI}.meson"

# remove old cross file if it exists (don't fail if it doesn't)
rm -f "${CROSS_FILE_NAME}"

cat > "${CROSS_FILE_NAME}" <<'EOF'
[binaries]
c = '${FAM_CC}'
ar = '${FAM_AR}'
strip = '${FAM_STRIP}'
nasm = '${NASM_EXECUTABLE}'
pkgconfig = '${PKG_CONFIG_EXECUTABLE}'

[properties]
needs_exe_wrapper = true
sys_root = '${SYSROOT_PATH}'

[host_machine]
system = 'linux'
cpu_family = '${CPU_FAMILY}'
cpu = '${TARGET_TRIPLE_MACHINE_ARCH}'
endian = 'little'

[built-in options]
prefix = '${INSTALL_DIR}'
EOF

BUILD_DIRECTORY="build/${ANDROID_ABI}"

# ensure parent directory exists and remove any previous build directory
mkdir -p "$(dirname "${BUILD_DIRECTORY}")"
rm -rf "${BUILD_DIRECTORY}"

MESON="${MESON_EXECUTABLE:-meson}"
NINJA="${NINJA_EXECUTABLE:-ninja}"
HOST_NPROC="${HOST_NPROC:-1}"

# Run meson setup (use 'meson setup <builddir> [sourcedir]')
# Keep source dir as '.' so cross-file and options apply to this source tree
"${MESON}" setup "${BUILD_DIRECTORY}" . \
  --cross-file "${CROSS_FILE_NAME}" \
  --default-library=static \
  -Denable_asm=true \
  -Denable_tools=false \
  -Denable_tests=false \
  -Denable_examples=false \
  -Dtestdata_tests=false

if [ $? -ne 0 ]; then
  echo "meson setup failed — printing meson logs (if available)"
  if [ -d "${BUILD_DIRECTORY}" ]; then
    ls -la "${BUILD_DIRECTORY}"
    if [ -f "${BUILD_DIRECTORY}/meson-logs/meson-log.txt" ]; then
      echo "--- meson-log.txt ---"
      sed -n '1,200p' "${BUILD_DIRECTORY}/meson-logs/meson-log.txt"
      echo "--- end meson-log.txt ---"
    fi
  fi
  exit 1
fi

cd "${BUILD_DIRECTORY}"

if [ ! -f build.ninja ]; then
  echo "build.ninja not found in ${BUILD_DIRECTORY} — meson setup may have failed"
  ls -la
  exit 1
fi

"${NINJA}" -j "${HOST_NPROC}"
"${NINJA}" install
