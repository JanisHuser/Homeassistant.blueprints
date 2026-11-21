#!/usr/bin/env bash
# Builds the firmware of every project into _firmware/<project>/<target>.bin, one merged image (flashed at
# offset 0) per chip, and for projects that build a Matter OTA image also <project>-<version>-<target>.ota
# + .json (site/ota_metadata.py). A project is
# - a product of the smart PCB: home-automations/smart-pcb/firmware/products/<project>/, built with
#   -DPRODUCT=<project>, for each chip that has a products/<project>/sdkconfig.defaults.<target> file;
#   its version is in products/<project>/product.cmake
# - or a standalone ESP-IDF project in home-automations/<project>/firmware/, for each chip that has a
#   sdkconfig.defaults.<target> file; its version is in its CMakeLists.txt
# Pass project names (e.g. diy-valve-head) to build only those; with none it builds every project.
# Runs inside the esp-matter container, in CI and locally:
#   docker run --rm -v "$PWD":/repo espressif/esp-matter:release-v1.5_idf_v5.4.1 bash /repo/site/build_firmware.sh [project...]
set -euo pipefail

if ! command -v idf.py >/dev/null; then
    . "$IDF_PATH/export.sh" >/dev/null
    . "$ESP_MATTER_PATH/export.sh" >/dev/null
fi

root=$(cd "$(dirname "$0")/.." && pwd)
smart="$root/home-automations/smart-pcb/firmware"

# Every project: smart PCB products, then standalone projects
all=()
for file in "$smart"/products/*/product.cmake; do all+=("$(basename "$(dirname "$file")")"); done
for file in "$root"/home-automations/*/firmware/CMakeLists.txt; do
    dir=$(dirname "$file")
    [ "$dir" = "$smart" ] || all+=("$(basename "$(dirname "$dir")")")
done
if [ $# -eq 0 ]; then
    names=("${all[@]}")
else
    names=("$@")
fi

for name in "${names[@]}"; do
    if [ -f "$smart/products/$name/product.cmake" ]; then
        project=$smart
        defaults_dir=$smart/products/$name
        version_file=$defaults_dir/product.cmake
        product_arg=(-DPRODUCT="$name")
    elif [ -f "$root/home-automations/$name/firmware/CMakeLists.txt" ]; then
        project=$root/home-automations/$name/firmware
        defaults_dir=$project
        version_file=$project/CMakeLists.txt
        product_arg=()
    else
        echo "no firmware project '$name' (have: ${all[*]})" >&2; exit 1
    fi
    out="$root/_firmware/$name"
    mkdir -p "$out"
    for defaults in "$defaults_dir"/sdkconfig.defaults.*; do
        target=${defaults##*.}
        build="$root/_firmware/build/$name-$target"
        echo "== $name ($target)"
        # Always from sdkconfig.defaults*: a kept sdkconfig would ignore options added there since.
        rm -f "$build/sdkconfig"
        idf.py -C "$project" -B "$build" -DSDKCONFIG="$build/sdkconfig" -DIDF_TARGET="$target" "${product_arg[@]}" build
        (cd "$build" && esptool.py --chip "$target" merge_bin -o "$out/$target.bin" @flash_args)
        # Projects with CONFIG_CHIP_OTA_IMAGE_BUILD also get a Matter update image and its description for
        # Home Assistant's Matter Server: <project>-<version>-<target>.ota and .json, named as released.
        rm -f "$out/$name"-*-"$target".ota "$out/$name"-*-"$target".json
        for ota in "$build"/*-ota.bin; do
            [ -f "$ota" ] || continue
            version=$(sed -n 's/^set(PROJECT_VER "\(.*\)")/\1/p' "$version_file")
            image="$out/$name-$version-$target.ota"
            cp "$ota" "$image"
            python3 "$root/site/ota_metadata.py" "$image" "$build/sdkconfig" "$version_file" > "${image%.ota}.json"
        done
    done
done
