#!/bin/bash

set -e
set -u

IMAGES="${1:-triangle-rolling}"
ARCHS="${2:-amd64}"

BASE_IMAGES="triangle-rolling triangle-dev triangle-last-release"
EXTRA_IMAGES="triangle-experimental triangle-bleeding-edge"
ALL_IMAGES="$BASE_IMAGES $EXTRA_IMAGES"
ALL_ARCHS="amd64 arm64 armhf armel i386"

USAGE="Usage: $(basename $0) [IMAGES] [ARCHITECTURES]

IMAGES and ARCHITECTURES must be space-separated and surrounded by quotes.
The special value 'all' can be used to select them all.

List of supported values:
* IMAGES: $ALL_IMAGES
* ARCHITECTURES: $ALL_ARCHS"

if [ $# -eq 1 ] && [ $1 = "-h" -o $1 = "--help" ]; then
    echo "$USAGE"
    exit 0
elif [ $# -gt 2 ]; then
    echo "$USAGE" >&2
    exit 1
fi

[ "$IMAGES" = all ] && IMAGES="$ALL_IMAGES"
[ "$ARCHS"  = all ] && ARCHS="$ALL_ARCHS"

# ensure base images get built first, as extra images depend on it
for image in $(printf "%s\n" $BASE_IMAGES | tac); do
    if echo "$IMAGES" | grep -qw $image; then
        IMAGES="$image ${IMAGES//$image/}"
    fi
done

echo "Images ..... : $IMAGES"
echo "Architectures: $ARCHS"

SUDO=$(test $(id -u) -eq 0 || echo sudo)

for image in $IMAGES; do
    if echo "$BASE_IMAGES" | grep -qw $image; then
        base_image=1
    elif echo "$EXTRA_IMAGES" | grep -qw $image; then
        base_image=0
    else
        echo "Invalid image name '$image'" >&2
        continue
    fi
    for arch in $ARCHS; do
        echo "========================================"
        echo "Building image $image/$arch"
        echo "========================================"
        if [ $base_image -eq 1 ]; then
            $SUDO ./build-rootfs.sh "$image" "$arch"
            ./docker-build.sh "$image" "$arch"
        else
            ./docker-build-extra.sh "$image" "$arch"
        fi
        ./docker-test.sh  "$image" "$arch"
    done
done

# On the Docker Hub, the image that was pushed last appears first.
# However we'd be much happier if the images were sorted by order
# of importance instead. So let's push it by reverse order of
# importance then.
ORDER="triangle-rolling triangle-last-release triangle-bleeding-edge triangle-experimental triangle-dev"
for image in $(printf "%s\n" $ORDER | tac); do
    if echo "$IMAGES" | grep -qw $image; then
        IMAGES="${IMAGES//$image/} $image"
    fi
done

for image in $IMAGES; do
    ./docker-publish.sh "$image" "$ARCHS"
done
