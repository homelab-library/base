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
TIMESTAMP="$(date +"%Y%m%d-%H%M")"

SAVEIFS=$IFS
IFS=$' '
PLATFORMS=($PLATFORM)
TARGETS=($TARGET)
IFS=$SAVEIFS

buildx() {
    target="${1}"
    platform="${2}"
    platform_normalized="${platform//\//_}"
    outfile="out/dockerfile.${target}"
    .bin/templar -d "matrix.yml" -s target_name="${target}" -s platform_name="${platform}" -t "dockerfile.tpl" -o "${outfile}"
    docker buildx build --platform "${platform}" --progress plain \
        -t "${target}_${platform_normalized}" \
        -t "homelabs/base:${target}" \
        -t "homelabs/base:${target}-${TIMESTAMP}" \
            -f "${outfile}" --load .
}

publish() {
    platform="linux/amd64 linux/arm/v7 linux/arm64"
    target="$1"
    if [[ $PUBLISH == "1" ]]; then
        outfile="out/dockerfile.${target}"
        docker buildx build --platform "linux/amd64,linux/arm/v7,linux/arm64" --progress plain \
            -t "homelabs/base:${target}" -t "homelabs/base:${target}-${TIMESTAMP}" --file "${outfile}" --push .
    fi
}

for t in "${TARGETS[@]}"; do
    for p in "${PLATFORMS[@]}"; do
        buildx "$t" "$p" &
    done
done

wait

for t in "${TARGETS[@]}"; do
    publish "$t" &
done

wait
