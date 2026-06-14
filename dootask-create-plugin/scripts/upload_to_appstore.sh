#!/usr/bin/env bash
# 把插件打包成 DooTask 应用商店可识别的 .tar.gz，通过 doo 上传导入到本机 DooTask 应用商店。
# 用法: upload_to_appstore.sh <插件目录> <版本号> <作者>
#   作者 = AppStore 发布账号(本机为 kuaifan)，决定应用 ID 落到 community_<作者>_<appid>。
set -euo pipefail

PLUGIN_DIR="${1:?用法: upload_to_appstore.sh <插件目录> <版本号> <作者>}"
VERSION="${2:?缺少版本号}"
AUTHOR="${3:?缺少作者(AppStore 发布账号,如 kuaifan)}"

PLUGIN_DIR="$(cd "$PLUGIN_DIR" && pwd)"
APPID="$(basename "$PLUGIN_DIR")"
FULL_ID="community_${AUTHOR}_${APPID}"

# 前置检查
if [[ ! -d "$PLUGIN_DIR/$VERSION" ]]; then
  echo "错误: 版本目录不存在: $PLUGIN_DIR/$VERSION" >&2
  exit 1
fi
if [[ ! -f "$PLUGIN_DIR/$VERSION/docker-compose.yml" ]]; then
  echo "警告: $VERSION/ 内未见 docker-compose.yml(纯外链型可忽略)" >&2
fi
if ! command -v doo >/dev/null 2>&1; then
  echo "错误: 未找到 doo 命令。安装: sudo npm i -g @dootask/cli（或从 https://github.com/dootask/tools/releases 下载对应平台二进制）" >&2
  exit 1
fi

# 暂存目录：用 FULL_ID 包一层，保证 tar 内是单一顶层目录、其中含 config.yml（后端据此识别应用）
echo "==> 暂存打包 $APPID@$VERSION -> $FULL_ID"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
STAGE="$TMPDIR/$FULL_ID"
mkdir -p "$STAGE"

# 打包规则:
#   包含: config.yml + logo* + README* + 目标 <版本>/ + 其它非版本子目录(icon/、resources/…)
#   排除: src/、.build.yml、点文件(.git 等)、非目标的版本目录(=含 docker-compose.yml 的其它子目录)
shopt -s nullglob   # 无匹配时通配符展开为空；点文件默认不展开 => 天然排除 .build.yml/.git
for entry in "$PLUGIN_DIR"/*; do
  base="$(basename "$entry")"
  if [[ -d "$entry" ]]; then
    [[ "$base" == "src" ]] && continue
    if [[ -f "$entry/docker-compose.yml" && "$base" != "$VERSION" ]]; then
      continue
    fi
  else
    case "$base" in
      config.yml|logo.*|README*) ;;
      *) continue ;;
    esac
  fi
  echo "    + $base"
  cp -a "$entry" "$STAGE/"
done

# 打 tar.gz：文件名 <full_id>-<version>.tar.gz 仅为清晰可辨，应用 ID 以下方 --appid 为准
TAR="$TMPDIR/${FULL_ID}-${VERSION}.tar.gz"
tar -czf "$TAR" -C "$TMPDIR" "$FULL_ID"
echo "==> 已打包: $(basename "$TAR") ($(du -h "$TAR" | cut -f1))"

# 上传：显式 --appid，不依赖后端对文件名的解析（合规校验不过 doo 会直接报错）。
echo "==> 通过 doo 上传到本机应用商店"
doo app upload "$TAR" --appid "$FULL_ID"

cat <<EOF

下一步(全部在 CLI 内):
  doo app fields  $FULL_ID    # 看安装字段(若有 fields)
  doo app install $FULL_ID    # 装/部署 (有 fields 时加 --param K=V)
  doo app containers $FULL_ID # 看容器/服务
  doo app logs    $FULL_ID    # 看安装/运行日志
EOF
