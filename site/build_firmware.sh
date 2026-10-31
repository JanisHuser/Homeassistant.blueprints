#!/usr/bin/env bash
# Builds every home-automations/*/firmware ESP-IDF project into _firmware/<project>/firmware.bin
# (one merged image, flashed at offset 0 by the site's browser installer).
# Runs inside the esp-matter container, in CI and locally:
#   docker run --rm -v "$PWD":/repo -w /repo espressif/esp-matter:release-v1.5_idf_v5.4.1 bash site/build_firmware.sh
set -euo pipefail

if ! command -v idf.py >/dev/null; then
    . "$IDF_PATH/export.sh" >/dev/null
    . "$ESP_MATTER_PATH/export.sh" >/dev/null
fi

root=$(cd "$(dirname "$0")/.." && pwd)
for project in "$root"/home-automations/*/firmware; do
    [ -f "$project/CMakeLists.txt" ] || continue
    name=$(basename "$(dirname "$project")")
    build="$root/_firmware/build/$name"
    out="$root/_firmware/$name"
    target=$(sed -n 's/^CONFIG_IDF_TARGET="\(.*\)"/\1/p' "$project/sdkconfig.defaults")
    echo "== $name ($target)"
    idf.py -C "$project" -B "$build" -DSDKCONFIG="$build/sdkconfig" -DIDF_TARGET="$target" build
    mkdir -p "$out"
    (cd "$build" && esptool.py --chip "$target" merge_bin -o "$out/firmware.bin" @flash_args)
done
