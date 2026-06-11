# 本地构建 + 部署 + 安装验证闭环

主程序**不会自动扫描** `apps/` 目录，测试安装是手动的。本技能负责把「能安装」这件事备齐：镜像就绪 + 打包产物就位，最后由用户在后台点安装。

## 完整流程

### 1. 构建镜像（仅镜像型形态 A/B/C）

镜像 tag 必须等于将要安装的版本号，因为 `docker-compose.yml` 里 `dootask/<appid>:${PLUGIN_VERSION}` 会被替换成安装的版本。本地 build 出同 tag 的镜像后，compose 会直接用本地镜像（存在即不拉取）。

```bash
scripts/build_image.sh <插件目录> <版本号>
```

脚本读 `<插件目录>/.build.yml` 的 `image`/`context`/`dockerfile`，执行 `docker build -t <image>:<版本号> -f <context>/<dockerfile> <context>`。构建失败先解决 Dockerfile / 依赖问题，不要跳过。

验证：`docker images | grep <appid>` 应看到 `<版本号>` 的 tag。

### 2. 部署打包产物到主程序测试目录

```bash
scripts/deploy_to_test.sh <插件目录> <版本号> <作者>
# 部署到 <apps>/community_<作者>_<appid>/，apps 默认 /home/coder/workspaces/dootask/docker/appstore/apps
# 作者 = AppStore 发布账号，本机为 kuaifan
```

**打包包含**：`config.yml`、`logo*`、`README*`、目标 `<版本>/` 整个目录、其它非版本子目录（如 `icon/`、`resources/`）。
**打包排除**：`src/`、`.build.yml`、`.git` 等点文件、非目标的版本目录。

判定「版本目录」的依据：子目录内含 `docker-compose.yml`。脚本据此只拷目标版本目录，跳过其它版本目录与 `src/`（点文件因 shell 通配默认不展开而天然排除）。

验证：`ls <apps目录>/community_<作者>_<appid>/` 应看到 `config.yml` + `logo` + `README*` + `<版本>/`，且**不含** `src/`、`.build.yml`。

### 3. 用户在 DooTask 后台安装

这步交给用户，给出明确指引：

1. 管理员账号登录 DooTask；
2. 进入「应用商店」；
3. 点「更新应用列表」，让主程序重新读取 `apps/` 目录；
4. 找到本应用，点安装；若插件定义了 `fields`，逐项说明填什么（端口、密钥、管理员等）。

### 4. 验证跑起来

- `docker ps | grep <appid>` —— 容器是否在跑；
- `docker logs <容器名>` —— 启动日志有无报错；
- 打开菜单入口（路径 `/apps/<appid>`），最小示例页应显示当前用户名 → 证明与主程序握手成功。

## 常见报错排查

| 现象 | 多半原因 |
| --- | --- |
| 安装时拉不到镜像 / 镜像不存在 | 本地未 build 出与安装版本号一致的 tag；重跑 `build_image.sh <目录> <版本>` |
| 应用列表里看不到新应用 | 没点「更新应用列表」，或打包产物没拷进 `apps/community_<作者>_<appid>/`，或 `config.yml` 不合法 |
| 页面 404 / 白屏 | `nginx.conf` 的 `location` 路径与 `menu_items.url` 基础路径不一致；或 `proxy_pass` 上游服务名/端口写错 |
| 页面打开但报「请在 DooTask 内打开」 | 正常——直接浏览器访问会触发 `UnsupportedError`，需从 DooTask 菜单进入 |
| 容器起不来 | `docker logs` 看日志；多为环境变量缺失（fields 没填）或数据库连接变量不对 |
| require_version 拦截安装 | 主程序版本低于 `require_version.version`，降低要求或升级主程序 |

## 关于「闭环」边界

本技能完成到：镜像构建成功 + 打包产物就位 + 给出安装指引。**实际安装跑起来需要用户在后台操作这一步**，以及业务逻辑的后续开发。交付时如实说明，别把「骨架已生成」描述成「插件已上线可用」。
