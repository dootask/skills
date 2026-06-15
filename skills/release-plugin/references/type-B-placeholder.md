# B 型：占位目录型（工程仓库型）

**代表仓库：kpi、asset-hub、memos、mcp。** 先读主 `SKILL.md` 的「共有铁律」和「CHANGELOG 规范」，本文件只讲 B 型特有部分。

## 布局与发布机制

这类仓库的**根目录是应用源码工程本身**（Next.js / server 等），AppStore 发布载荷单独隔离在 `dootask-plugin/` 目录里：固定占位目录 **`version/`** + `config.yml` + `logo*` + `README*`（这份 README 是 AppStore 文案，和仓库根的开发 README 不是一回事）。

发布推 tag 触发 `release.yml`：构建多架构镜像推 Docker Hub，打包步骤 `cd dootask-plugin && mv version <tag> && tar -czf ../dootask-plugin.tar.gz .`——在 runner 里把占位目录 `version` 重命名成 tag 名再打包发布到 AppStore。

> 4 个仓库已统一为 `dootask-plugin/version/` + `mv version <tag>` 的一致约定（历史上 kpi 曾用 `0.1.0`、asset-hub 曾用 `1.0.0`，现已对齐）。

## ⚠️ B 型最关键的坑：占位目录固定叫 `version`，repo 里绝不能出现按版本号命名的目录

打包步骤是 `mv version <tag>`。所以 repo 里那个目录**必须一直叫 `version`**，哪怕已发到 `0.1.9` 也别改名、别按版本号新建目录。**repo 里一旦出现 `dootask-plugin/0.2.0/` 之类，`mv version <tag>` 之后会冒出两个目录、或在重名时失败。** 改插件配置（菜单、`require_version`、hooks、环境变量字段）就改 **`dootask-plugin/version/config.yml`**。

## 先现场探测镜像名与 appid（占位目录固定是 version，无需探测）

```bash
grep -E '^\s*image:' dootask-plugin/version/docker-compose.yml   # 镜像名
grep -E '^name:|appid' dootask-plugin/version/config.yml          # appid（通常 = 仓库名）
```

已知对照（参考，新仓库仍以探测为准）：

| 仓库 | 镜像名 | appid | 特例 |
|---|---|---|---|
| kpi | `dootask/kpi` | kpi | 占位目录暂无 CHANGELOG，发版时补 `version/CHANGELOG*` |
| asset-hub | `dootask/asset-hub` | asset-hub | release.yml 打包时 `sed` 自动注入 `ASSET_HUB_VERSION` / `ASSET_HUB_RELEASED_AT` 到 compose，**勿手改** |
| memos | `dootask/memos`（proxy，**硬编码**）+ 自建 `dootask/memos-server:0.29.0` | memos | 双镜像 |
| mcp | `dootask/mcp` | mcp | gitflow 工作流 |

## 发布流程

### 1. 状态干净 + 定版本号

```bash
git fetch && git status                 # 工作区干净、在 main、与远程同步
git log --oneline -10
git tag --sort=-creatordate | head -5   # 看已发版本
```

待发布的代码改动先提交推上去。与用户确认新版本号（SemVer、纯数字不带 `v`、只增不重复）。

若仓库有 `ci.yml`（如 asset-hub）：推 tag 不重跑 lint/test，先确认最新 push 跑绿——`gh run list --workflow=ci.yml --limit 3`。

### 2. 更新中英双语 CHANGELOG（在占位目录里）

编辑 `dootask-plugin/version/CHANGELOG.md` 和 `dootask-plugin/version/CHANGELOG_zh.md`，按主 `SKILL.md` 的 CHANGELOG 规范。

### 3. 提交 CHANGELOG（及代码）推 main

```bash
git add dootask-plugin/version/CHANGELOG.md dootask-plugin/version/CHANGELOG_zh.md
git commit -m "docs(changelog): notes for 0.2.0"   # 替换为实际版本号
git push origin main
```

### 4. 打 tag 推送，触发发布（不可逆）

```bash
git tag 0.2.0                  # ⚠️ 不带 v 前缀
git push origin 0.2.0
```

推上去立即触发，没回头路。误推可 `git push --delete origin 0.2.0 && git tag -d 0.2.0`（已发布到 AppStore 则删 tag 不撤回）。

### 5. 监控 + 验证

```bash
gh run list --workflow=release.yml --limit 3
gh run watch
```

验证：Docker Hub 对应镜像出现新 tag；DooTask 应用商店里对应 appid 插件版本已更新，更新说明显示本次 CHANGELOG。最后提醒用户：DooTask 管理端 → 应用商店 → **更新应用列表** → 更新到新版 → 强刷浏览器（Ctrl+Shift+R）。

## 发布失败时

- **Docker 登录失败**：secret 名 `DOCKER_USERNAME` / `DOCKER_PASSWORD`（不是 `DOCKERHUB_*`），多半过期或缺失。
- **AppStore 发布失败**：查 `dootask-plugin/version/config.yml`（尤其 `require_version`）和 `DOOTASK_USERNAME` / `DOOTASK_PASSWORD`；也可能版本号重复。
- **打包步骤 `mv` 报错**：repo 里多半混进了按版本号命名的目录（见上文最关键的坑），删掉只留 `version/`。
- **Action 没触发**：确认 tag 真的推到了远程（仅 `git tag` 不推送）；tag 带了 `v` 会破坏排序，删了重打。
