#!/usr/bin/env bash
set -Eeuo pipefail

TEMPLAR_URL="https://github.com/proctorlabs/templar/releases/download/v0.4.1/templar-x86_64-unknown-linux-gnu.tar.xz"

mkdir -p out .bin
if [[ ! -f .bin/templar ]]; then
    echo "Pulling templar..."
    curl -sL "${TEMPLAR_URL}" | tar xJ -C .bin/
    chmod +x .bin/templar
fi

while getopts ":t:p:P" opt; do
    case ${opt} in
    p)
        PLATFORM=$OPTARG
        ;;
    P)
        PUBLISH=1
        ;;
    t)
        TARGET=$OPTARG
        ;;
    \?)
        echo "Usage: build.sh [-t TARGET]"
        exit 1
    esac
done

PUBLISH="${PUBLISH:-0}"
PLATFORM="${PLATFORM:-linux/amd64 linux/arm/v7 linux/arm64}"
TARGET="${TARGET:-$(echo -n '{% for t in targets %}{{ t.key }} {% end for %}' | .bin/templar -i matrix.yml)}"

SAVEIFS=$IFS
IFS=$' '
PLATFORMS=($PLATFORM)
TARGETS=($TARGET)
IFS=$SAVEIFS

buildx() {
    target="${1}"
    platform="${2}"
    platform_normalized="${platform//\//_}"
    outfile="out/dockerfile.${target}_${platform_normalized}"
    .bin/templar -d "matrix.yml" -s target_name="${target}" -s platform_name="${platform}" -t "dockerfile.tpl" -o "${outfile}"
    docker buildx build --platform "${platform}" --progress plain -t "${target}_${platform_normalized}" -f "${outfile}" --load .
    if [[ $PUBLISH == "1" ]]; then
        docker buildx build --platform "${platform}" --progress plain \
            -t "homelabs/base:${target}" -t "homelabs/base:${target}-$(date +"%Y%m%d-%H%M")" \
            --file "${outfile}" --push .

    fi
}

for t in "${TARGETS[@]}"; do
    for p in "${PLATFORMS[@]}"; do
        buildx "$t" "$p" &
    done
done

wait
