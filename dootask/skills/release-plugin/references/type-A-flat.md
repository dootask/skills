# A 型：真实版本目录型（扁平布局）

**代表仓库：crm。** 先读主 `SKILL.md` 的「三型共有铁律」和「CHANGELOG 规范」，本文件只讲 A 型特有部分。

## 布局与发布机制

项目根**直接**放 `config.yml` + `logo.svg` + `README*` + **每个版本一个真实目录**（如 `0.1.0/`）+ `src/`（前端工程，Dockerfile 在 `src/Dockerfile`）+ `.build.yml`。

发布推 tag 触发 `release.yml`：多架构（amd64+arm64）构建镜像推 Docker Hub（crm 是 `dootask/crm`），再打包**根目录元数据 + `<tag>/` 版本目录**发布到 AppStore。常规 push / PR 只跑 `ci.yml`（lint + build），不发布。

镜像名 / 路径 / appid 从仓库读：`config.yml` 里的 appid，镜像名见 `<版本>/docker-compose.yml` 的 `image:`（crm = `dootask/crm`，路径 `/apps/crm`，appid `crm`）。

## 首次发布：仓库还没有 `.github/workflows/release.yml` 时

脚手架 `dootask:create-plugin` 创建的新插件**不带发布工作流**（它的闭环是本机 `doo` CLI 本地验证，正式发版不在其范围）。正式发版前先确认：

```bash
ls .github/workflows/release.yml 2>/dev/null || echo "缺工作流，需先创建"
```

没有就用本技能内置模板 `assets/release.yml.template` 创建，按本仓库填 3 处占位符：

- `__APPID__` → appid（读 `config.yml` 的 appid，通常等于仓库目录名）
- `__BUILD_CONTEXT__` → 构建上下文（读 `.build.yml` 的 `context`，脚手架标准为 `src`）
- `__DOCKERFILE__` → Dockerfile 路径（读 `.build.yml` 的 `dockerfile`，脚手架标准为 `./src/Dockerfile`）

镜像名无需填——模板用 `${{ secrets.DOCKER_USERNAME }}/${{ github.event.repository.name }}` 自动取仓库名（前提：仓库名=appid、Docker 组织账号=dootask）。打包清单用 `logo.* README*.md` 通配，不必关心 logo 扩展名。

填好写入 `.github/workflows/release.yml`、提交推 main，再走下面的发布流程。首次推 tag 前确认 4 个 Secret 已配齐（见主 `SKILL.md` 铁律 5）。
（可选）质量门禁 `ci.yml` 不是发版必需，需要可参照 crm 的 `ci.yml` 另建。

## A 型特有的坑

1. **版本目录必须先提交再打 tag。** CI 打包的是 repo 里 `<tag>/` 这个**真实目录**（A 型不像 B 型用占位目录重命名）。发 `0.2.0` 就要先有并提交 `0.2.0/`，否则 CI 打包步骤直接报错退出。
2. **每个版本一个独立目录。** 发新版是**新建 `<新版本>/` 目录**（从上一版 `cp -r` 复制），不是改旧目录。老版本目录留着无妨，CI 只打包当前 tag 的目录。
3. **改装机配置 vs 改代码。** 版本目录里的 `config.yml` / `nginx.conf` / `docker-compose.yml` 不进镜像、随 tar 包发布；`src/` 下任何改动要靠 CI 重建镜像才生效。compose 用 `${PLUGIN_VERSION}` 自动跟随版本，无需手改。

## 发布流程

### 1. 决定版本号

```bash
git status                       # 工作区应干净、在 main 分支
ls -d */ | grep -E '^[0-9]'      # 看现有版本目录
git tag --sort=-creatordate | head   # 看已发版本
```

与用户确认新版本号，SemVer、不带 `v`、只增不重复。

### 2. 新建版本目录（从上一版复制）

```bash
cp -r 0.1.0 0.2.0      # 用实际的上一版 / 新版号
```

`0.2.0/` 里的 `config.yml`、`docker-compose.yml`、`nginx.conf` 一般原样保留；只有当本次确有「装机配置字段 / 反代 / require_version」变化时才改对应文件。

### 3. 更新中英双语 CHANGELOG

编辑 `0.2.0/CHANGELOG.md`（英文）和 `0.2.0/CHANGELOG_zh.md`（中文），按主 `SKILL.md` 的 CHANGELOG 规范（覆盖式、不写版本号日期、中英一一对应）。

### 4.（建议）发版前本地验证一遍

推 tag 前先本地构建，确认镜像能起、资源能加载，避免把坏版本发到公开 AppStore：

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/create-plugin/scripts/build_image.sh . 0.2.0
bash ${CLAUDE_PLUGIN_ROOT}/skills/create-plugin/scripts/upload_to_appstore.sh . 0.2.0
```

验证抓手：`docker ps | grep crm`、`docker logs <容器>`、页面 `/apps/crm`，并**单独 curl 一个 `/apps/crm/assets/*.js`** 确认资源加载（页面 200 不代表资源能加载，见仓库 CLAUDE.md）。

### 5. 提交版本目录 + CHANGELOG，推到 main

```bash
git add -A
git commit -m "release: 0.2.0"
git push origin main
```

确认本次提交的 `ci.yml` 跑绿：`gh run list --workflow=ci.yml --limit 1`。

### 6. 打 tag 推送，触发发布（不可逆）

```bash
git tag 0.2.0 && git push origin 0.2.0
```

推上去立即触发，没回头路。盯 Action：`gh run watch` 或 GitHub Actions 页。

### 7. 验证发布

- Docker Hub `dootask/crm` 出现新 tag（amd64+arm64）；
- DooTask 应用商店里对应 appid 版本已更新；
- 让用户：DooTask 管理员 → 应用商店 → **更新应用列表** → 找到对应插件 → 更新到新版 → 强刷浏览器（Ctrl+Shift+R）。

## 发布失败时

- **Docker 登录失败**：secret 名 `DOCKER_USERNAME` / `DOCKER_PASSWORD`，多半过期或缺失；组织账号需为 `dootask`，否则镜像名不是 `dootask/crm`。
- **AppStore 发布失败**：查 `<tag>/config.yml`（尤其 `require_version`）和 `DOOTASK_USERNAME` / `DOOTASK_PASSWORD`；也可能是版本号重复。
- **打包步骤报「版本目录不存在」**：忘了先创建并提交 `<tag>/` 目录就打了 tag（见坑 1）。补建目录、提交、删旧 tag 重打。
