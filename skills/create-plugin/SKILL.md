---
name: create-plugin
description: 从零创建一个 DooTask 插件（脚手架 + 本地构建/安装验证）。
disable-model-invocation: true
---

# 创建 DooTask 插件

把「我要一个 DooTask 插件」变成一个**结构正确、能装进主程序跑起来**的脚手架，外加一个最小可见的示例页/接口。业务逻辑留给后续开发填充，但骨架的每个文件、每条约定都要正确，这样开发者拿到就能直接迭代，而不是先踩一遍配置坑。

## 核心原则：对照现成同形态插件，别凭空捏

DooTask 的配置约定有文档漂移（例如 `menu_items` 的菜单模式在不同插件里写成 `url_type:` 或 `type:`），照搬过时文档容易出错。**最可靠的做法是：选定形态后，找一个同形态的现成插件作为「参照样板」，逐文件对照它的真实写法来生成**，而不是套死模板。本技能给出的模板是起点，参照样板是校准基准。

**样板与本地参考资料全部用带 `ref:` 前缀的代表词指代**（`ref:` 是命名空间前缀，把登记条目和正文同名普通词区分开），**绝对路径与获取方式统一登记在 `references/samples.md`**（本机有 checkout 就直接读；没有就 `git clone --depth=1` 到可复用临时目录再读；私有/拿不到则回退本技能 references）。见到 `ref:xxx` 时先按它的「获取约定」解析。

常用样板（按形态选，详见 `references/samples.md`）：
- 前后端自建镜像型（**默认 JS/TS 全栈首选**）：`ref:crm`（**TanStack Start**，扁平布局**与本技能 1:1，优先对照**）、`ref:asset-hub`（**Next.js**，`docs/rules/` 是权威规范）
- 前后端自建镜像型（Go/Python 变体）：`ref:approve`（Go + MySQL）、`ref:ai`（Python + Vite 前端）
- 代理 + 上游官方镜像型：`ref:memos`（包在 `dootask-plugin/` 子目录）
- 纯配置 / 复用现成镜像型：`ref:mysql-expose-port`
- 纯前端静态型：参照镜像型，后端换成一个仅托管静态资源的小容器

> 布局：`ref:crm` 就是扁平布局（`<appid>/` 含 `src/` + `.build.yml` + `<版本>/`），**与本技能生成的结构完全一致，优先对照它**。`ref:asset-hub`/`ref:memos` 用 `dootask-plugin/` 包裹布局——照抄它们的 Dockerfile / basePath / nginx / `@dootask/tools` 集成写法即可，目录仍落到扁平结构。

**生成前先读样板**：解析出样板目录后，读它的 `config.yml`（顶层与版本目录）、`docker-compose.yml`、`nginx.conf`、`.build.yml`，对照真实写法来生成。三档都拿不到时，依赖本技能的参照文件并明确告知用户「未读到现成样板，按规范生成，请重点复核」。

其它本地参考资料（同样登记在 `references/samples.md`，按代表词获取）：`ref:appstore-docs`（官方插件开发文档）、`ref:tools`（`@dootask/tools` 前端 + Go/Node/Python SDK 源码）、`ref:app-landing`（应用落地目录，只读）、`ref:dootask`（主程序源码）。

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
  - 前端：**Next.js** 与 **TanStack Start** 平级推荐，都配 **shadcn/ui** + Tailwind。两者各有取舍（Next 更成熟、`ref:asset-hub`/`ref:kpi` 有现成 Next.js 参照；TanStack Start 更轻、Vite 底座、类型安全路由），**运行时让用户二选一**，别替他默认死。
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
3. **目录布局——扁平布局**：项目根目录就是 `<appid>/`，直接平铺放 `config.yml` + `logo` + `README*` + `<版本>/`，镜像型再加 `src/` 和 `.build.yml`。这与本技能脚本（`build_image.sh` / `upload_to_appstore.sh`）预期的布局一致，部署时把整个项目目录当作「插件目录」传入即可。

> 注：少数现成项目（如 kpi/memos）把 AppStore 包放在 `dootask-plugin/` 子目录、源码与 `Dockerfile` 放仓库根。那是它们的历史布局，本技能新建项目统一用上面的扁平布局，更简单且与脚本对齐。

### 4. 生成骨架

动手前：若用户只给了名字/一句话需求，先问一次（可选）要不要聊聊产品需求（实体、页面、流程、权限）再写代码；已说清楚就直接搭。

按所选形态生成文件。务必遵守的硬约定（细节见 `references/config-yml.md`、`references/forms.md`）：

- **顶层 `config.yml` 只放元数据**：`name`/`description`/`author`/`website`/`tags`（都支持 `en`/`zh`）。标准/镜像型不要把 `fields`/`menu_items`/`hooks` 放顶层——放版本目录（随版本走）。**例外**：纯配置型 D1（如 `ref:mysql-expose-port`）没有版本 `config.yml`，`fields` 直接放顶层。
- **版本目录 `<版本>/config.yml` 放功能配置**：`fields` / `menu_items` / `hooks` / `require_version`，以及推荐默认带上的 `openapi` / `knowledge_base`（见下条）。
- **让主程序 AI 能用上你的插件**：适合接入 AI 的插件默认带上对应项——插件有**值得被调用的后端操作**时声明 `openapi`（指向后端 OpenAPI/Swagger 规范），主程序的用户/AI 即可 `doo app call` 执行你的功能；插件有**面向用户、会被问到的用法**时随包带一份 `knowledge_base` 知识库目录并声明，产品内「AI 助手」即可解答其用法。两者各自独立判断，都没有就都不加。写法/鉴权/目录结构见 `references/config-yml.md`。
- **`docker-compose.yml`**：镜像写 `dootask/<appid>:${PLUGIN_VERSION}`；不对外暴露端口（特殊需求除外）；环境变量来自 fields 与内置变量；连主程序后端用服务名 `service`、连主 nginx 用 `nginx`、数据库用 `${DB_HOST}`/`${DB_PORT}`/`${DB_DATABASE}`/`${DB_USERNAME}`/`${DB_PASSWORD}` 等内置变量。
- **`nginx.conf`**：`location` 路径必须与 `menu_items.url` 的基础路径一致;反代到容器内部服务名:端口;末尾 `/` 用来剥离前缀——**是否加要看前端有没有用 basePath 自己接管前缀：Next/TanStack basePath 模式不加、代理/剥前缀模式才加，按形态见 `references/forms.md`**;SSE/WebSocket 记得关 buffering、带 `Upgrade`/`Connection` 头、调长超时。
- **`CHANGELOG.md` + `CHANGELOG_zh.md`**：首版写一句初始化说明即可。
- **`logo`**：放一个占位 `logo.svg`（提醒用户替换为真实 logo）。
- **右上角是主程序「胶囊」的领地**：插件装进弹窗后，主程序会在内容区右上角浮一个胶囊条（「更多」+「关闭」）盖住页面。前端别把自己的操作/关闭按钮放右上角；需调显隐、位置或往「更多」加菜单项时用 `setCapsuleConfig`（见 `references/tools.md`）。
- **`README.md` + `README_zh.md`**：这是 AppStore 展示文案，不是开发说明。
- 镜像型还要：`.build.yml`（`image: dootask/<appid>` / `context: src` / `dockerfile: src/Dockerfile`）和 `src/`。
- **`CLAUDE.md`（必须生成，关键）**：在插件根目录生成一份项目记忆，让**后续新会话**不丢上下文——它会被每次会话全量注入，价值在「本地参考路径 + 先读本地别上网硬规则 + basePath/端口/部署目录等雷区」，正是新会话最容易忘、会害它跑去联网找 DooTask 文档的部分。做法：读 `assets/CLAUDE.md.template`，**填充并裁剪**——替换所有 `{{...}}` 占位（appid/作者/插件名/技术栈/版本/前端 base 配置文件/产品一句话），并**删掉本项目不适用的行**，逐行套黄金法则「删了 Claude 会不会犯错，不会就删」，保持精简（CLAUDE.md 越长遵从度越低）。模板已内置一份**精简的「本地参考登记」表**（取自 `references/samples.md`，让生成的 CLAUDE.md 自带 `ref:` 解析依据、脱离本技能也能用）：按本插件实际栈**裁剪掉不相关的样板行**（如选 Next.js 就删 `ref:crm` 行、保留 `ref:asset-hub`），用到表外样板时从 `samples.md` 补对应 `ref:` 行。写到 `<appid>/CLAUDE.md`。如需更系统地写/优化，可参考用户级技能 `claude-md`。

**最小可跑示例**（这是本技能区别于纯模板的地方）：`src/` 里给一个能直接看到效果的最小实现——前端一个页面，启动即 `appReady()` 并 `getUserInfo()` 把当前用户名显示出来，证明与主程序握手成功;有后端则加一个 `/api/.../ping` 之类的接口并由前端调用一次。接入方式见 `references/tools.md`。**有后端时一并给出一份覆盖该 ping 接口的 `openapi.yaml` 并在 `config.yml` 声明 `openapi`，让主程序 AI 能直接 `doo app call` 调到它——这是「装上就能被 AI 用起来」的最小证明。**目标是「装上就能看到一个活的页面」，不是空壳。

### 5. 本地构建镜像（镜像型形态）

按 `.build.yml` 本地构建，**镜像 tag 必须等于将要安装的版本号**（compose 里 `${PLUGIN_VERSION}` 会被替换成该版本），否则安装时找不到镜像：

```bash
scripts/build_image.sh <插件目录> <版本号>
# 等价于：docker build -t dootask/<appid>:<版本号> -f <context>/<dockerfile> <context>
```

构建失败要把错误贴给用户、定位到 Dockerfile/依赖问题，别跳过。

### 6. 上传到本机应用商店（通过 doo）

把**打包后**的内容（不含 `src/`、`.build.yml`、点文件）打成 `.tar.gz`，用 `doo app upload` 导入到**本机** DooTask 应用商店（注意：是本机这个开发实例的应用商店，不是公共仓库；公共仓库要靠后续作者发布流程）——等同网页「上传本地应用」，自带后端合规校验，导入后落到 `apps/community_<作者>_<appid>/`（作者 = 本地 AppStore 账号，本机为 `kuaifan`）：

```bash
scripts/upload_to_appstore.sh <插件目录> <版本号> <作者>
```

打包规则（脚本已实现，理解即可）：拷 `config.yml` + `logo.*` + `README*` + 目标 `<版本>/` + 其它非版本子目录（如 `icon/`、`resources/`）;**排除** `src/`、`.build.yml`、`.git` 等点文件、非目标的版本目录、以及根目录其它文件（根文件走白名单 `config.yml`/`logo.*`/`README*`，故 `CLAUDE.md` 等开发文件不会进包）。打成 tar.gz 后调 `doo app upload --appid community_<作者>_<appid>`，后端做合规校验：缺 `config.yml` / `name` 字段非法等会直接报错，不必等到安装时才挂。

**前置**：本机已装并登录 `doo`（`sudo npm i -g @dootask/cli`；`doo auth login` 或设 `DOO_SERVER`/`DOO_TOKEN`）。`doo` 不可用时脚本立即报错退出。

### 7. 安装与验证（CLI 全闭环）

`doo app upload` 走的是后端合规校验通路，与网页「更新应用列表」无关——上传成功即落入本机应用商店，**无需再去后台点更新**。整套验证可在 CLI 完成：

1. 报告已生成的文件清单与镜像构建结果（`docker images | grep <appid>`）。
2. 列字段并装：`doo app fields community_<作者>_<appid>` 看 fields 定义（若不为空，说明各项含义/建议值）→ `doo app install community_<作者>_<appid> [--param K=V ...]`，每个必填字段用一个 `--param` 传值。doo 在装前会做必填校验，缺项立即报错。fields 设计上含密码/密钥的，应在 config.yml 里给 `default: $random:N`（这是 yaml 写法，不是 CLI 参数），后端会在安装时自动生成。
3. 验证：
   - `doo app containers community_<作者>_<appid>` —— 看容器/服务是否在跑;
   - `doo app logs community_<作者>_<appid>` —— 看安装/运行日志;
   - 打开菜单入口 `/apps/<appid>`，最小示例页应显示当前用户名 → 证明与主程序握手成功。
4. 装坏了的回滚：`doo app uninstall community_<作者>_<appid> [--delete-data] --yes`;**先卸载,再**用 `doo app remove community_<作者>_<appid> --yes` 彻底清掉社区应用的本地目录（直接 remove 已安装应用会被后端拒绝）。**`uninstall`/`remove` 是危险操作，默认要交互确认；CLI 非交互流程必须显式加 `--yes`（`-y`），否则会卡在确认提示走不下去。**
5. 如实说明：本技能完成到「镜像已构建 + 已导入 + 已安装 + 容器在跑」才算闭环;最小示例页用于确认握手，业务逻辑待开发。

不要把「已生成骨架」说成「插件已上线可用」。

## 参考文件

- `references/samples.md` —— **样板与本地参考登记表**：`ref:` 代表词 → 本机路径 + 在线仓库的映射，以及「本地优先 → 缺失则 `git clone --depth=1` 到可复用临时目录 → 回退」的获取约定。**全技能见到 `ref:xxx` 都来这里解析。**
- `references/forms.md` —— 四种形态各自的目录结构、`docker-compose.yml`、`nginx.conf`、构建方式、参照样板与适用场景。**选定形态后必读对应小节。**
- `references/config-yml.md` —— `config.yml` 全字段速查：顶层元数据、版本目录的 `fields`（含字段类型与 `$random`/`$uuid` 语法）、`menu_items`（location/url 变量/打开模式，含 `url_type` vs `type` 的实战说明）、`hooks`、`require_version`/`conflict_version`、docker-compose 内置变量表。
- `references/tools.md` —— `@dootask/tools` 速查：前端核心 API 与最小握手代码、Go/Node/Python 后端 SDK 的引入与鉴权（默认 `http://nginx` + token）。
- `references/local-test.md` —— 本地构建 + 上传 + 安装验证的完整 CLI 闭环步骤、打包包含/排除规则、常见报错排查。

## 脚本

- `scripts/build_image.sh` —— 读 `.build.yml` 本地构建镜像，tag 自动打成 `dootask/<appid>:<版本号>`。
- `scripts/upload_to_appstore.sh` —— 按打包规则打成 `.tar.gz`，通过 `doo app upload --appid community_<作者>_<appid>` 导入本机应用商店（前置：本机已装并登录 `doo`）。

## 资源

- `assets/CLAUDE.md.template` —— 生成到插件根目录的项目记忆模板（第 4 步填充占位后写入 `<appid>/CLAUDE.md`），让后续新会话保留本地路径、硬规则与构建部署命令。模板内**自带一份精简的「本地参考登记」表**（`ref:` 代表词 → 路径 + 在线仓库，取自 `references/samples.md`）：因为生成的插件目录里没有 `samples.md`，把相关条目随模板带过去，生成的 CLAUDE.md 才能自洽解析 `ref:xxx`。生成时按实际栈裁剪，保持精简。
