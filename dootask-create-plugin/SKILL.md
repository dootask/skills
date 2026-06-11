---
name: dootask-create-plugin
description: 从零创建一个 DooTask 插件：脚手架 + 最小可跑示例，并完成本地构建镜像、部署到主程序测试目录的闭环。
---

# 创建 DooTask 插件

把「我要一个 DooTask 插件」变成一个**结构正确、能装进主程序跑起来**的脚手架，外加一个最小可见的示例页/接口。业务逻辑留给后续开发填充，但骨架的每个文件、每条约定都要正确，这样开发者拿到就能直接迭代，而不是先踩一遍配置坑。

## 核心原则：对照现成同形态插件，别凭空捏

DooTask 的配置约定有文档漂移（例如 `menu_items` 的菜单模式在不同插件里写成 `url_type:` 或 `type:`），照搬过时文档容易出错。**最可靠的做法是：选定形态后，找一个同形态的现成插件作为「参照样板」，逐文件对照它的真实写法来生成**，而不是套死模板。本技能给出的模板是起点，参照样板是校准基准。

常用参照样板（按形态，均为本机绝对路径）：
- 前后端自建镜像型（**默认 JS/TS 全栈首选**）：
  - `/home/coder/workspaces/dootask-plugins/crm`（**TanStack Start** + shadcn + SQLite，**扁平布局,与本技能 1:1**，含 `.build.yml`）
  - `/home/coder/workspaces/dootask-plugins/asset-hub`（**Next.js** + App Router 后端 + SQLite + shadcn；`dootask-plugin/` 包裹布局，但 `CLAUDE.md`/`docs/rules/` 是权威规范）
- 前后端自建镜像型（Go/Python 变体）：`/home/coder/workspaces/dootask-plugins/system-plugins/approve`（Go + MySQL）、`/home/coder/workspaces/dootask-plugins/system-plugins/ai`（Python + Vite 前端）
- 代理 + 上游官方镜像型：`/home/coder/workspaces/dootask-plugins/memos`（独立仓库，包在 `dootask-plugin/`）
- 纯配置 / 复用现成镜像型：`/home/coder/workspaces/dootask-plugins/system-plugins/mysql-expose-port`
- 纯前端静态型：参照镜像型，后端换成一个仅托管静态资源的小容器

> 布局：`crm` 就是扁平布局（`<appid>/` 含 `src/` + `.build.yml` + `<版本>/`），**与本技能生成的结构完全一致，优先对照它**。`asset-hub`/`memos` 用 `dootask-plugin/` 包裹布局——照抄它们的 Dockerfile / basePath / nginx / `@dootask/tools` 集成写法即可，目录仍落到扁平结构。

**生成前先读样板**：读对应样板的 `config.yml`（顶层与版本目录）、`docker-compose.yml`、`nginx.conf`、`.build.yml`，对照它的真实写法来生成。样板被移动/删除导致读不到时，依赖本技能的参照文件并明确告知用户「未找到现成样板，按规范生成，请重点复核」。

其它本机参考资料：
- 官方插件开发文档：`/home/coder/workspaces/dootask-appstore/appstore/apps/_/README_CN.md`
- `@dootask/tools` 源码（前端 + Go/Node/Python SDK）：`/home/coder/workspaces/dootask-tools`
- 主程序测试目录（部署目标）：`/home/coder/workspaces/dootask/docker/appstore/apps`
- 现成系统插件集合（可挑同形态目录当参照样板）：`/home/coder/workspaces/dootask-plugins/system-plugins`

## 工作流

按顺序推进，每一步把假设说清楚，关键岔路口让用户拍板。

### 1. 收集需求

至少问清下面这些（用户一句话需求里没有的才问，已知的别重复问）：

- **插件名**：中文名 + 英文名（`config.yml` 的 `name.zh` / `name.en`）。
- **appid**：小写裸名（如 `crm`、`asset-hub`），是镜像名 `dootask/<appid>`、nginx 路径 `/apps/<appid>`、前端 base path 的统一来源。默认取英文名小写连字符，向用户确认。
- **作者**：AppStore 发布账号（本机为 `kuaifan`），只用于部署目录名 `community_<作者>_<appid>`（见第 6 步）；不影响 appid/镜像/路径。
- **一句话描述**：中英文，进 `description`。
- **形态**：见第 2 步。
- **技术栈**：默认走**全 JS/TS 栈**（前后端一套语言，依赖与工具链统一，最好维护）。
  - 前端：**Next.js** 与 **TanStack Start** 平级推荐，都配 **shadcn/ui** + Tailwind。两者各有取舍（Next 更成熟、`/home/coder/workspaces/dootask-plugins/kpi` 有现成 Next.js 参照；TanStack Start 更轻、Vite 底座、类型安全路由），**运行时让用户二选一**，别替他默认死。
  - 后端：默认 **Node + TypeScript**（用 `@dootask/tools` 的 Node SDK）。
  - 其它语言（Go / Python）仍支持，`@dootask/tools` 有对应 SDK（见 `references/tools.md`），但仅在用户明确要求时才用，不作默认。
- **是否需要后端**：纯前端就走「纯前端静态型」，有业务接口才加后端。
- **菜单入口**：放在哪个位置（`application` 应用菜单 / `application/admin` 应用管理 / `main/menu` 主菜单）、用哪种打开模式（`iframe` 兼容性最好，默认推荐）。
- **配置字段 fields**（可选）：安装时让管理员填的参数（端口、密钥、管理员用户等）。
- **首个版本号**：默认 `0.1.0`。

### 2. 选定形态

四种形态，按需求选一种，然后**读 `references/forms.md` 里对应小节**拿到该形态的目录结构、compose、nginx 写法与构建方式：

| 形态 | 何时选 | 镜像 |
| --- | --- | --- |
| 前后端自建镜像型 | 有自己的前端页面 + 后端接口（最常见） | 自建 `dootask/<appid>` |
| 代理 + 上游官方镜像型 | 想集成一个现成开源服务（如 memos），用轻量代理做鉴权转发 | 上游官方镜像（固定版）+ 自建代理镜像 |
| 纯前端静态型 | 只有前端，无业务后端 | 一个仅托管静态资源的小容器 |
| 纯配置 / 外链型 | 不写代码：复用现成镜像，或只在主程序里加个外链菜单 | 现成镜像或无镜像 |

拿不准时默认「前后端自建镜像型」，它覆盖面最广。

### 3. 确定落地位置（新目录）

本技能默认在一个**新目录**里创建独立插件项目，不假设当前已经在某个插件仓库里。

1. **确认目标路径**：默认 `<cwd>/<appid>/`，把绝对路径报给用户确认后再动手。
2. **git 初始化询问**：检查目标位置是否已在 git 仓库内（`git -C <目标父目录> rev-parse --is-inside-work-tree`）。**若不是 git 目录，询问用户是否 `git init` 初始化**；同意则初始化，不同意就只建普通目录。
3. **目录布局——扁平布局**：项目根目录就是 `<appid>/`，直接平铺放 `config.yml` + `logo` + `README*` + `<版本>/`，镜像型再加 `src/` 和 `.build.yml`。这与本技能脚本（`build_image.sh` / `deploy_to_test.sh`）预期的布局一致，部署时把整个项目目录当作「插件目录」传入即可。

> 注：少数现成项目（如 kpi/memos）把 AppStore 包放在 `dootask-plugin/` 子目录、源码与 `Dockerfile` 放仓库根。那是它们的历史布局，本技能新建项目统一用上面的扁平布局，更简单且与脚本对齐。

### 4. 生成骨架

动手前：若用户只给了名字/一句话需求，先问一次（可选）要不要聊聊产品需求（实体、页面、流程、权限）再写代码；已说清楚就直接搭。

按所选形态生成文件。务必遵守的硬约定（细节见 `references/config-yml.md`、`references/forms.md`）：

- **顶层 `config.yml` 只放元数据**：`name`/`description`/`author`/`website`/`tags`（都支持 `en`/`zh`）。不要把 `fields`/`menu_items`/`hooks` 放顶层。
- **版本目录 `<版本>/config.yml` 放功能配置**：`fields` / `menu_items` / `hooks` / `require_version`。
- **`docker-compose.yml`**：镜像写 `dootask/<appid>:${PLUGIN_VERSION}`；不对外暴露端口（特殊需求除外）；环境变量来自 fields 与内置变量；连主程序后端用服务名 `service`、连主 nginx 用 `nginx`、数据库用 `${DB_HOST}`/`${DB_PORT}`/`${DB_DATABASE}`/`${DB_USERNAME}`/`${DB_PASSWORD}` 等内置变量。
- **`nginx.conf`**：`location` 路径必须与 `menu_items.url` 的基础路径一致;反代到容器内部服务名:端口;末尾 `/` 用来剥离前缀;SSE/WebSocket 记得关 buffering、带 `Upgrade`/`Connection` 头、调长超时。
- **`CHANGELOG.md` + `CHANGELOG_zh.md`**：首版写一句初始化说明即可。
- **`logo`**：放一个占位 `logo.svg`（提醒用户替换为真实 logo）。
- **`README.md` + `README_zh.md`**：这是 AppStore 展示文案，不是开发说明。
- 镜像型还要：`.build.yml`（`image: dootask/<appid>` / `context: src` / `dockerfile: src/Dockerfile`）和 `src/`。
- **`CLAUDE.md`（必须生成，关键）**：在插件根目录生成一份项目记忆，让**后续新会话**不丢上下文。把 `assets/CLAUDE.md.template` 读出来，替换其中所有 `{{...}}` 占位（appid、作者、插件名、技术栈、版本、前端 base 配置文件、产品一句话等），写到 `<appid>/CLAUDE.md`。它带着本地参考路径（主程序、`@dootask/tools`、开发文档、样板）、「先读本地别上网」硬规则、本插件约定与构建/部署/测试命令——这正是新会话最容易忘、且会导致它跑去联网找 DooTask 文档的部分。

**最小可跑示例**（这是本技能区别于纯模板的地方）：`src/` 里给一个能直接看到效果的最小实现——前端一个页面，启动即 `appReady()` 并 `getUserInfo()` 把当前用户名显示出来，证明与主程序握手成功;有后端则加一个 `/api/.../ping` 之类的接口并由前端调用一次。接入方式见 `references/tools.md`。目标是「装上就能看到一个活的页面」，不是空壳。

### 5. 本地构建镜像（镜像型形态）

按 `.build.yml` 本地构建，**镜像 tag 必须等于将要安装的版本号**（compose 里 `${PLUGIN_VERSION}` 会被替换成该版本），否则安装时找不到镜像：

```bash
scripts/build_image.sh <插件目录> <版本号>
# 等价于：docker build -t dootask/<appid>:<版本号> -f <context>/<dockerfile> <context>
```

构建失败要把错误贴给用户、定位到 Dockerfile/依赖问题，别跳过。

### 6. 部署到主程序测试目录

把**打包后**的内容（不含 `src/`、`.build.yml`、点文件）拷到主程序应用目录。开发应用的部署目录**固定**是 `/home/coder/workspaces/dootask/docker/appstore/apps/community_<作者>_<appid>/`（作者 = AppStore 发布账号，本机为 `kuaifan`）：

```bash
scripts/deploy_to_test.sh <插件目录> <版本号> <作者>
```

打包规则（脚本已实现，理解即可）：拷 `config.yml` + `logo*` + `README*` + 目标 `<版本>/` + 其它非版本子目录（如 `icon/`、`resources/`）;**排除** `src/`、`.build.yml`、`.git` 等点文件、以及非目标的版本目录。

### 7. 交付与验证

测试安装是**手动**的——主程序不自动扫描，需要用户在后台点安装。所以收尾要做的是：

1. 报告已生成的文件清单与镜像构建结果（贴 `docker images | grep <appid>` 证据）。
2. 确认打包产物已就位（`ls` 测试目录）。
3. 给出**给用户的下一步指引**：登录 DooTask 管理员 → 应用商店 → 「更新应用列表」→ 找到本应用 → 安装;安装时如有 fields 说明各项填什么。
4. 安装后可验证的抓手：菜单入口路径 `/apps/<appid>`、`docker ps | grep <appid>` 看容器、`docker logs` 看启动日志。
5. 如实说明：本技能完成到「可安装 + 镜像就绪」，实际跑起来需用户在后台安装这一步;最小示例页用于确认握手，业务逻辑待开发。

不要把「已生成骨架」说成「插件已上线可用」。

## 参考文件

- `references/forms.md` —— 四种形态各自的目录结构、`docker-compose.yml`、`nginx.conf`、构建方式、参照样板与适用场景。**选定形态后必读对应小节。**
- `references/config-yml.md` —— `config.yml` 全字段速查：顶层元数据、版本目录的 `fields`（含字段类型与 `$random`/`$uuid` 语法）、`menu_items`（location/url 变量/打开模式，含 `url_type` vs `type` 的实战说明）、`hooks`、`require_version`/`conflict_version`、docker-compose 内置变量表。
- `references/tools.md` —— `@dootask/tools` 速查：前端核心 API 与最小握手代码、Go/Node/Python 后端 SDK 的引入与鉴权（默认 `http://nginx` + token）。
- `references/local-test.md` —— 本地构建 + 部署 + 后台安装的完整闭环步骤、打包包含/排除规则、常见报错排查。

## 脚本

- `scripts/build_image.sh` —— 读 `.build.yml` 本地构建镜像，tag 自动打成 `dootask/<appid>:<版本号>`。
- `scripts/deploy_to_test.sh` —— 按打包规则把插件部署到主程序 `apps/community_<作者>_<appid>/` 测试目录。

## 资源

- `assets/CLAUDE.md.template` —— 生成到插件根目录的项目记忆模板（第 4 步填充占位后写入 `<appid>/CLAUDE.md`），让后续新会话保留本地路径、硬规则与构建部署命令。
