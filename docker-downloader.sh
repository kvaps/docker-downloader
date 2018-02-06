#!/bin/sh

if [ -z "$1" ]; then
    >&2 echo "error: image not specified"
    exit 1
fi

USER="$(echo "$1" | sed 's/:[^:/]*$//' | sed 's/[^:/]*$//g' | grep -o '[^/]*/$' | sed -n 's/^\([0-9a-z]*\)\/$/\1/p')"
USER="${USER:-library}"
IMAGE="$(echo "$1" | sed 's/:[^:/]*$//' | awk -F/ '{print $NF}')"
TAG="$(echo "$1" | sed -n 's/.*:\([^\/:]*\)$/\1/p')"
TAG="${TAG:-latest}"
REGISTRY="$(echo "$1" | sed 's/:[^\/:]*$//' | sed 's/[^:/]*$//g' | sed "s/\/\?$USER\/.*$//g")"
REGISTRY="${REGISTRY:-docker.io}"

#echo "$REGISTRY/$USER/$IMAGE:$TAG"
#exit 0

if [ "$REGISTRY" != "docker.io" ]; then
    >&2 echo "error: custom repo still not supproted"
    exit 1
fi

export TOKEN=\
"$(curl \
--silent \
--header 'GET' \
"https://auth.docker.io/token?service=registry.docker.io&scope=repository:${USER}/${IMAGE}:pull" \
| jq -r '.token' \
)"

export LAYERS=\
"$(
curl \
--silent \
--request 'GET' \
--header "Authorization: Bearer ${TOKEN}" \
"https://index.docker.io/v2/${USER}/${IMAGE}/manifests/${TAG}" \
| jq -r '.fsLayers[].blobSum' | tac
)"

LAYER_NUM="1"
LAYERS_NUM="$(echo "$LAYERS" | wc -l)"

rm -rf image
mkdir -p image

if [ -z "${LAYERS}" ]; then
    >&2 echo "error: can not download image"
    exit 1
fi

for BLOBSUM in $LAYERS; do
    echo "[$((LAYER_NUM++))/${LAYERS_NUM}] $BLOBSUM"
    curl \
    --progress-bar \
    --location \
    --request GET \
    --header "Authorization: Bearer ${TOKEN}" \
    "https://index.docker.io/v2/${USER}/${IMAGE}/blobs/${BLOBSUM}" | tar -C image -xzf - || exit 1
    #"https://index.docker.io/v2/${USER}/${IMAGE}/blobs/${BLOBSUM}" -o "${LAYER_NUM}.tar.gz"
done
