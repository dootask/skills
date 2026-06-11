#!/usr/bin/env bash
# 按打包规则把插件部署到主程序测试目录 <apps>/community_<作者>_<appid>/。
# 包含: config.yml + logo* + README* + 目标 <版本>/ + 其它非版本子目录(icon/、resources/…)
# 排除: src/、.build.yml、点文件、非目标的版本目录(=含 docker-compose.yml 的其它子目录)
# 用法: deploy_to_test.sh <插件目录> <版本号> <作者> [apps目录]
set -euo pipefail

PLUGIN_DIR="${1:?用法: deploy_to_test.sh <插件目录> <版本号> <作者> [apps目录]}"
VERSION="${2:?缺少版本号}"
AUTHOR="${3:?缺少作者(AppStore 发布账号,如 kuaifan)}"
APPS_DIR="${4:-/home/coder/workspaces/dootask/docker/appstore/apps}"

PLUGIN_DIR="$(cd "$PLUGIN_DIR" && pwd)"
APPID="$(basename "$PLUGIN_DIR")"
DEST="$APPS_DIR/community_${AUTHOR}_${APPID}"

if [[ ! -d "$PLUGIN_DIR/$VERSION" ]]; then
  echo "错误: 版本目录不存在: $PLUGIN_DIR/$VERSION" >&2
  exit 1
fi
if [[ ! -f "$PLUGIN_DIR/$VERSION/docker-compose.yml" ]]; then
  echo "警告: $VERSION/ 内未见 docker-compose.yml(纯外链型可忽略)" >&2
fi

echo "==> 部署 $APPID@$VERSION -> $DEST"
mkdir -p "$DEST"

shopt -s nullglob   # 无匹配时通配符展开为空；点文件默认不展开 => 天然排除 .build.yml/.git
for entry in "$PLUGIN_DIR"/*; do
  base="$(basename "$entry")"
  if [[ -d "$entry" ]]; then
    # 目录：排除源码目录与非目标的「版本目录」(含 docker-compose.yml 的其它子目录)
    [[ "$base" == "src" ]] && continue
    if [[ -f "$entry/docker-compose.yml" && "$base" != "$VERSION" ]]; then
      continue
    fi
  else
    # 顶层文件白名单：只收 config.yml / logo* / README*；CLAUDE.md/AGENTS.md 等开发文件不入包
    case "$base" in
      config.yml|logo.*|README*) ;;
      *) continue ;;
    esac
  fi
  echo "    + $base"
  cp -a "$entry" "$DEST/"
done

echo "==> 完成。测试目录内容:"
ls -la "$DEST"
echo
echo "下一步: 在 DooTask 后台 应用商店 -> 更新应用列表 -> 安装「$APPID」。"
