#!/usr/bin/env bash
# Builds the home-automations/*/firmware ESP-IDF projects into _firmware/<project>/<target>.bin, one merged
# image (flashed at offset 0) per chip that has a sdkconfig.defaults.<target> file, e.g. esp32c6.bin, and for
# projects that build a Matter OTA image also <project>-<version>-<target>.ota + .json (site/ota_metadata.py).
# Pass project names (e.g. diy-valve-head) to build only those; with none it builds every project.
# Runs inside the esp-matter container, in CI and locally:
#   docker run --rm -v "$PWD":/repo espressif/esp-matter:release-v1.5_idf_v5.4.1 bash /repo/site/build_firmware.sh [project...]
set -euo pipefail

if ! command -v idf.py >/dev/null; then
    . "$IDF_PATH/export.sh" >/dev/null
    . "$ESP_MATTER_PATH/export.sh" >/dev/null
fi

root=$(cd "$(dirname "$0")/.." && pwd)
if [ $# -eq 0 ]; then
    projects=("$root"/home-automations/*/firmware)
else
    projects=()
    for name in "$@"; do projects+=("$root/home-automations/$name/firmware"); done
fi
for project in "${projects[@]}"; do
    name=$(basename "$(dirname "$project")")
    if [ ! -f "$project/CMakeLists.txt" ]; then
        [ $# -eq 0 ] && continue
        echo "no firmware project '$name'" >&2; exit 1
    fi
    out="$root/_firmware/$name"
    mkdir -p "$out"
    for defaults in "$project"/sdkconfig.defaults.*; do
        target=${defaults##*.}
        build="$root/_firmware/build/$name-$target"
        echo "== $name ($target)"
        # Always from sdkconfig.defaults*: a kept sdkconfig would ignore options added there since.
        rm -f "$build/sdkconfig"
        idf.py -C "$project" -B "$build" -DSDKCONFIG="$build/sdkconfig" -DIDF_TARGET="$target" build
        (cd "$build" && esptool.py --chip "$target" merge_bin -o "$out/$target.bin" @flash_args)
        # Projects with CONFIG_CHIP_OTA_IMAGE_BUILD also get a Matter update image and its description for
        # Home Assistant's Matter Server: <project>-<version>-<target>.ota and .json, named as released.
        rm -f "$out/$name"-*-"$target".ota "$out/$name"-*-"$target".json
        for ota in "$build"/*-ota.bin; do
            [ -f "$ota" ] || continue
            version=$(sed -n 's/^set(PROJECT_VER "\(.*\)")/\1/p' "$project/CMakeLists.txt")
            image="$out/$name-$version-$target.ota"
            cp "$ota" "$image"
            python3 "$root/site/ota_metadata.py" "$image" "$build/sdkconfig" "$project/CMakeLists.txt" > "${image%.ota}.json"
        done
    done
done
