#!/usr/bin/env bash
# Builds firmware on this computer the way CI does (site/build_firmware.sh in the esp-matter container),
# but keeps the build folders and ccache in Docker volumes instead of on the shared repository folder,
# which Docker on macOS reads and writes slowly. A rebuild after a small change then takes a minute or
# two instead of a near-full build. The images still land in _firmware/<project>/.
#   site/build_firmware_local.sh [project...]          e.g. site/build_firmware_local.sh diy-valve-head
# Remove the volumes to start from scratch: docker volume rm firmware-build firmware-ccache
set -euo pipefail

IMAGE=espressif/esp-matter:release-v1.5_idf_v5.4.1
BUILD_VOLUME=firmware-build
CCACHE_VOLUME=firmware-ccache

root=$(cd "$(dirname "$0")/.." && pwd)
exec docker run --rm \
    -v "$root":/repo \
    -v "$BUILD_VOLUME":/build \
    -v "$CCACHE_VOLUME":/ccache \
    -e BUILD_DIR=/build \
    -e IDF_CCACHE_ENABLE=1 -e CCACHE_DIR=/ccache -e CCACHE_MAXSIZE=4G \
    "$IMAGE" bash /repo/site/build_firmware.sh "$@"
