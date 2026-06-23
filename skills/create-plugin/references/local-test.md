# 本地构建 + 上传 + 安装验证闭环

本技能负责把「能装并能跑」备齐：镜像就绪 + 包导入本机应用商店 + 通过 `doo` 完成安装与验证。整条链路都在 CLI 内完成，无需进主程序后台操作。

> **`doo` 命令以实时帮助为准**：下文只列工作流必需的子集，完整命令面与参数随版本变化，**用 `doo --help` / `doo app --help` 查当前版本**为准；源码与 README 见 `ref:doo-cli`（即 `dootask/tools` 的 `server/cli`，解析方式见 `references/samples.md`）。

> **术语**：「应用商店」是 DooTask 对企业内免费插件管理的命名，不涉及购买。本文说的「本机应用商店」指这台开发实例的商店（`doo app upload` 的目的地），不是所有用户共享的公共仓库（公共仓库走作者另外的发布流程）。

## 完整流程

### 1. 构建镜像（仅镜像型形态 A/B/C）

镜像 tag 必须等于将要安装的版本号，因为 `docker-compose.yml` 里 `dootask/<appid>:${PLUGIN_VERSION}` 会被替换成安装的版本。本地 build 出同 tag 的镜像后，compose 会直接用本地镜像（存在即不拉取）。

```bash
scripts/build_image.sh <插件目录> <版本号>
```

脚本读 `<插件目录>/.build.yml` 的 `image`/`context`/`dockerfile`，执行 `docker build -t <image>:<版本号> -f <context>/<dockerfile> <context>`。构建失败先解决 Dockerfile / 依赖问题，不要跳过。

验证：`docker images | grep <appid>` 应看到 `<版本号>` 的 tag。

### 2. 上传到本机应用商店（通过 doo）

```bash
scripts/upload_to_appstore.sh <插件目录> <版本号> <作者>
# 打包 → tar.gz → doo app upload --appid community_<作者>_<appid>
# 作者 = AppStore 发布账号，本机为 kuaifan
```

**打包包含**：`config.yml`、`logo.*`、`README*`、目标 `<版本>/` 整个目录、其它非版本子目录（如 `icon/`、`resources/`）。
**打包排除**：`src/`、`.build.yml`、`.git` 等点文件、非目标的版本目录、根目录其它文件（如 `CLAUDE.md` 开发记忆、`package.json`）。脚本对**根文件用白名单**（只收 `config.yml`/`logo.*`/`README*`），所以白名单外的根文件天然不打包——根 `CLAUDE.md` 是开发记忆、不该进应用商店包，正好被排除。

判定「版本目录」的依据：子目录内含 `docker-compose.yml`。脚本据此只拷目标版本目录，跳过其它版本目录与 `src/`（点文件因 shell 通配默认不展开而天然排除）。

**`doo app upload` 做的事**：把 tar.gz 交给后端解压 → 合规校验（`config.yml` 必须存在、`name` 字段必须非空）→ 落到本机 `apps/community_<作者>_<appid>/`。**与网页「更新应用列表」无关**——上传成功即已落入本机应用商店。

前置：`doo` 已装并已登录（`sudo npm i -g @dootask/cli`，免 Node 时去 [GitHub Releases](https://github.com/dootask/tools/releases) 下载对应平台二进制；`doo auth login`，或设 `DOO_SERVER`/`DOO_TOKEN`）。脚本会先检查 `doo` 是否在 PATH，未装直接报错退出。

验证：`doo app catalog --search <appid>` 应能搜到（含 community 应用）；`doo app list` 装完后能看到。

### 3. 安装应用（通过 doo）

```bash
doo app fields community_<作者>_<appid>                              # 看 fields 定义
doo app install community_<作者>_<appid> [--param K=V] [--param ...] # 装
```

- fields 含必填项时，`doo app install` 在装前校验，缺项立即报错（不会让你装完才发现）。
- 已安装应用再 install 即升级，且未传 `--param` 时自动 sticky（保留当前值），不会把令牌/密钥清空。
- 镜像本地有就用本地（`--pull=false` 默认），无需推到 registry。

### 4. 验证跑起来（通过 doo）

```bash
doo app containers community_<作者>_<appid>      # 看容器/服务列表
doo app logs       community_<作者>_<appid>      # 看安装/运行日志
doo app container-logs community_<作者>_<appid> --service <服务名> -n 200  # 看某容器日志
```

- 打开菜单入口（路径 `/apps/<appid>`），最小示例页应显示当前用户名 → 证明与主程序握手成功。
- 装坏了：`doo app uninstall community_<作者>_<appid> [--delete-data] --yes`；要彻底清掉社区应用：`doo app remove community_<作者>_<appid> --yes`（先卸载再 remove）。**`uninstall`/`remove` 默认要交互确认，非交互/脚本流程必须加 `--yes`（`-y`），否则会卡在提示。**

## 常见报错排查

| 现象 | 多半原因 |
| --- | --- |
| `doo: command not found` | 未装 doo；`sudo npm i -g @dootask/cli`（或下载 [GitHub Releases](https://github.com/dootask/tools/releases) 二进制），然后 `doo auth login` |
| `doo: 未登录` / `401` | 未鉴权；`doo auth login` 或设 `DOO_TOKEN`/`DOO_SERVER` |
| 上传时 `config.yml configuration file not found` | 打包结构不对：根或第一层子目录里没有 `config.yml`；检查脚本打包结果 |
| 上传时 `InvalidConfig` / `name` 为空 | `config.yml` 的 `name` 字段缺失或两种语言都为空 |
| 安装时拉不到镜像 / 镜像不存在 | 本地未 build 出与安装版本号一致的 tag；重跑 `build_image.sh <目录> <版本>` |
| 页面 404 / 白屏 | `nginx.conf` 的 `location` 路径与 `menu_items.url` 基础路径不一致；或 `proxy_pass` 上游服务名/端口写错 |
| 页面打开但报「请在 DooTask 内打开」 | 正常——直接浏览器访问会触发 `UnsupportedError`，需从 DooTask 菜单进入 |
| 容器起不来 | `doo app container-logs <id> --service <服务>` 看日志；多为环境变量缺失（fields 没填）或数据库连接变量不对 |
| `require_version` 拦截安装 | 主程序版本低于 `require_version.version`，降低要求或升级主程序 |

## 关于「闭环」边界

本技能完成到：镜像构建成功 + 包已上传 + 应用已安装 + 容器在跑。**业务逻辑的后续开发仍由用户负责**，最小示例页只用于确认握手。交付时如实说明，别把「骨架已生成」描述成「插件已上线可用」。
