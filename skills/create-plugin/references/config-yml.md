# config.yml 速查

DooTask 插件有两层 `config.yml`：顶层（应用元数据）和版本目录（功能配置）。版本目录里的同名键会**覆盖**顶层。

## 顶层 config.yml（只放元数据）

```yaml
name:                       # 必需，支持多语言
  en: Plugin Name
  zh: 插件名称
description:                # 必需
  en: One-line description
  zh: 一句话描述
author: DooTask
website: https://www.dootask.com/
github: https://github.com/...     # 可选
document: https://...              # 可选
tags:                              # 可选，分类
  - 审批
```

`name`/`description` 也可写成单值字符串（如 `name: MysqlExposePort`），但推荐多语言对象。一般**不要**把 `fields`/`menu_items`/`hooks` 放顶层——放版本目录（这样随版本走）；**例外**：纯配置型插件（如 `mysql-expose-port`）没有版本 `config.yml` 时，`fields` 直接放顶层、版本目录只留 `docker-compose.yml`。

## 版本目录 config.yml（功能配置）

```yaml
fields:        # 安装时让管理员填的参数，会注入为环境变量
menu_items:    # 菜单入口
hooks:         # 生命周期脚本
require_version:   # 主程序版本要求
conflict_version:  # 冲突版本
```

### fields（字段）

```yaml
fields:
  - name: PORT                 # 环境变量名，docker-compose 里用 ${PORT}
    label:
      en: Port
      zh: 端口
    placeholder:               # 可选
      en: Service Port
      zh: 服务端口
    description:               # 可选
      en: Ensure this port is open
      zh: 请确保端口已开放
    type: number               # number | text | password | select | user_select
    required: true             # 可选，默认 false
    default: 3306              # 默认值
    options:                   # 仅 select：
      - label: { en: Docker, zh: Docker }
        value: docker
```

`default` 支持随机生成语法（适合密钥）：
- `$random:N` —— N 位随机字母数字（如 `$random:48`）
- `$random:N:hex` / `:alpha` / `:num` —— 指定字符集
- `$uuid` —— UUID v4

`type: user_select` 让管理员选 DooTask 用户，值为用户 ID 列表（常用于「指定管理员」）。

### menu_items（菜单入口）

```yaml
menu_items:
  - location: application      # application | application/admin | main/menu
    label:
      en: My App
      zh: 我的应用
    url: "apps/<appid>/?theme={system_theme}&lang={system_lang}&user_id={user_id}&user_token={user_token}"   # 参数名自定，但必须与前端读取的一致；这里用真实样板 crm 的约定
    url_type: iframe           # 见下方「打开模式」说明
    immersive: true            # iframe[_blank] 全屏沉浸（可选）
    icon: ./icon.png           # 可选，默认用应用 logo
    visible_to: all            # all | admin | "1,2,3" | "${FIELD_NAME}"
    capsule:                   # 右上角胶囊按钮（可选）
      visible: false
```

**打开模式键名 `url_type` vs `type`（重要的实战坑）**：DooTask 文档写的是 `type:`，但真实插件里两种都出现——`ai` 用 `url_type: iframe`，`okr` 用 `type: inline`。两者目前都被识别。**生成时以你选的参照样板里的写法为准**，不要混用。拿不准就跟样板一致。

`location` 取值：`application`（应用常用菜单）、`application/admin`（应用管理菜单）、`main/menu`（主菜单）。

打开模式取值：`iframe`（默认，兼容性最好，推荐）、`iframe_blank`、`inline`（无缝集成但调样式麻烦）、`inline_blank`、`external`（纯外链，无法与 DooTask 交互）。前四种支持 `@dootask/tools`。

`url` 支持的变量：`{user_id}`、`{user_nickname}`、`{user_email}`、`{user_avatar}`、`{user_token}`、`{system_theme}`（light/dark）、`{system_lang}`、`{system_base_url}`、`{window.location.?}`、`{字段名}`（如 `{PORT}`）。示例：`":{PORT}"`、`"{system_base_url}/apps/x?user_id={user_id}"`。

### hooks（生命周期脚本）

```yaml
hooks:
  install: install.sh            # 等价于 install.after
  upgrade:
    before: upgrade_before.sh
    after: upgrade_after.sh
  uninstall:
    before:
      cmd: |
        if [ "$DELETE_DATA" = "true" ]; then
          curl -sS -m 30 -X POST "http://<appid>:8700/api/v1/clear" || true
        fi
      timeout: 120               # 秒，默认 300
  user_onboard: user_onboard.sh  # 系统新增用户
  user_offboard: user_offboard.sh
  user_update: user_update.sh
```

写法可为脚本文件名（相对应用/版本目录）或 inline shell（`cmd: |`）。可用环境变量：`APP_ID`/`APP_NAME`/`ACTION`/`PHASE`/`MAIN_VERSION`；卸载附带 `DELETE_DATA`；升级附带 `PREV_VERSION`；操作者 `ACTOR_*`；用户事件 `USER_*` 与 `USER_EVENT`。hook 的 `cmd` 由钩子运行器当普通 shell 执行，环境变量**直接写 `$VAR`**（如上例 `$DELETE_DATA`，真实插件 `approve` 即如此）；`$$` 转义是 `docker-compose.yml` 专属，别用在 hook 里。

### require_version / conflict_version

```yaml
require_version:
  version: "> 1.7.90"            # 主程序版本不满足则禁止安装
  reason:
    en: Requires new API features
    zh: 需要新的 API 功能
conflict_version:
  version: "<= 1.0.0"           # 已装版本冲突，升级前需先卸载
  reason: { en: "...", zh: "..." }
```

### openapi / knowledge_base（推荐：让主程序 AI 能用上你的插件）

适合接入 AI 的插件建议默认带上——主应用的用户/AI 才能完整用上它：有值得被调用的后端操作就声明 `openapi`（用户/AI 可 `doo app call` 执行），有面向用户、会被问到的用法就带 `knowledge_base`（产品内「AI 助手」可解答）。两者各自独立判断，都没有就都不加。顶层或版本目录均可（版本目录覆盖），不声明则不启用。

```yaml
# 有后端接口就声明：指向后端 OpenAPI 3.x / Swagger 2.0 规范 → 用户/AI 可 `doo app call <appid> <指令>` 调你的接口
openapi: ./openapi.yaml      # 静态文件；或对象式 {service, port, path} 指运行时端点；或 {file, service, port} 并用
# 面向用户的应用就带上：知识库随包发布，装了「AI 助手」后并入其检索、卸载自动移除
knowledge_base: ./ai-kb      # 指向应用内目录，结构 <语言>/<类型>/<功能>/*.md，每个 .md 带 frontmatter
```

- `openapi`：调用自带当前用户身份（`Token` + `X-Doo-User-Id/Email/Name/Role` 头），后端自行鉴权（推荐用后端 SDK 校验）；指令名取 operation 的 `operationId`，可用 `x-doo-cli-name` 改名、`x-doo-cli: false` 隐藏某接口；`query`/`path`/扁平请求体顶层字段→命令参数（`K=V`），复杂体用 `--data '<json>'`。多服务应用用 `openapi.service`（必要时加 `openapi.port`）指定接口所在服务。
- `knowledge_base`：chunk `id` 须全局唯一（建议加应用功能名前缀，如 `example.start.howto`）；需装「AI 助手」应用才被检索（安装顺序无所谓）；写作规范同主程序 `resources/ai-kb/`（参考其 `_schema/` 与 `README.md`）。
- 完整细节以 `ref:appstore-docs` 为准。

## docker-compose.yml 内置变量

| 变量 | 说明 |
| --- | --- |
| `${PLUGIN_VERSION}` | 当前安装版本号（= 版本目录名），镜像 tag 用它 |
| `${APP_ID}` / `${APP_VERSION}` | 应用 ID / 版本 |
| `${APP_BASE_PATH}` / `${APP_VERSION_PATH}` | 应用目录(`../`) / 版本目录(`./`) |
| `${ROOT_PATH}` / `${DOCKER_PATH}` / `${PUBLIC_PATH}` | 主程序工作目录 / docker 目录 / public 目录 |
| `${DB_HOST}` `${DB_PORT}` `${DB_DATABASE}` `${DB_USERNAME}` `${DB_PASSWORD}` `${DB_PREFIX}` | 主程序数据库连接（命名以主程序为准） |
| `${APP_KEY}` `${TIMEZONE}` | 应用密钥 / 时区 |
| `${字段名}` | fields 里定义的字段值 |

容器间网络：主程序后端服务名 `service`，主 nginx 服务名 `nginx`。变量插值遵循 docker compose 规范：`${VAR:-默认}`（空/未定义用默认）、`${VAR:?报错}`（必填）、字面量 `$` 写 `$$`。可在版本目录放 `.env` 提供默认值。
