version := "v1.0"
image_name := "proctorlabs/selfhosted-base"
base := `echo -n ${BASE:-buster}`
arch := `echo -n ${TARGET_ARCH:-amd64}`

setup:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    docker buildx create --platform linux/arm64,linux/amd64,linux/arm/v7 --name cross-builder --append
    docker buildx use cross-builder

enable-xbuild:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

build:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    docker buildx build --platform linux/arm64,linux/amd64,linux/arm/v7 \
        -t "{{image_name}}:{{base}}-{{version}}" \
        -t "{{image_name}}:{{base}}" --file "dockerfile.{{base}}" .

run:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    docker buildx build --platform linux/{{arch}} --load \
        -t "{{image_name}}:{{base}}" --file "dockerfile.{{base}}" .
    docker run --rm -it "{{image_name}}:{{base}}" bash

publish:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    docker buildx build --platform linux/arm64,linux/amd64,linux/arm/v7 \
        -t "{{image_name}}:{{base}}-{{version}}" \
        -t "{{image_name}}:{{base}}" --file "dockerfile.{{base}}" --push .
