#!/usr/bin/env bash
# 按 <插件目录>/.build.yml 本地构建镜像，tag = dootask/<appid>:<版本号>。
# 用法: build_image.sh <插件目录> <版本号>
set -euo pipefail

PLUGIN_DIR="${1:?用法: build_image.sh <插件目录> <版本号>}"
VERSION="${2:?缺少版本号}"
PLUGIN_DIR="$(cd "$PLUGIN_DIR" && pwd)"
BUILD_YML="$PLUGIN_DIR/.build.yml"

if [[ ! -f "$BUILD_YML" ]]; then
  echo "未找到 $BUILD_YML —— 该插件非镜像型(无需构建)。" >&2
  exit 1
fi

# 简易解析 .build.yml 的三个键（值可能带引号）
val() { grep -E "^\s*$1\s*:" "$BUILD_YML" | head -1 | sed -E "s/^\s*$1\s*:\s*//; s/^[\"']//; s/[\"']\s*$//; s/\s+#.*$//"; }
IMAGE="$(val image)"
CONTEXT="$(val context)"
DOCKERFILE="$(val dockerfile)"

: "${IMAGE:?.build.yml 缺少 image}"
CONTEXT="${CONTEXT:-src}"
DOCKERFILE="${DOCKERFILE:-$CONTEXT/Dockerfile}"

TAG="${IMAGE}:${VERSION}"
echo "==> 构建 $TAG"
echo "    context=$PLUGIN_DIR/$CONTEXT  dockerfile=$PLUGIN_DIR/$DOCKERFILE"
docker build -t "$TAG" -f "$PLUGIN_DIR/$DOCKERFILE" "$PLUGIN_DIR/$CONTEXT"

echo "==> 完成。已构建镜像:"
docker images | grep -E "^${IMAGE//\//\\/}\s|/${IMAGE##*/}\s" || docker images | grep "${IMAGE##*/}" || true
echo "TAG=$TAG"
