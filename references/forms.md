# 四种插件形态

每种形态给出：目录结构（**扁平布局**：项目根目录就是 `<appid>/`）、`docker-compose.yml`、`nginx.conf`、构建方式、参照样板。新建项目统一用扁平布局；个别现成项目（kpi/memos）用 `dootask-plugin/` 子目录包裹包内容，那是其历史布局，不作为新建模板。

路径里的 `<appid>`、`<版本>` 按实际替换。生成前务必对照参照样板的真实文件校准。

**默认技术栈（全 JS/TS）**：前端从 **Next.js** 或 **TanStack Start** 二选一（运行时问用户），都配 **shadcn/ui + Tailwind**；后端默认 **Node + TypeScript**。两套前端的共性要点：
- 子路径部署：插件挂在 `/apps/<appid>/`，前端的 base path 必须设成它——Next.js 用 `next.config` 的 `basePath: '/apps/<appid>'`；TanStack Start 在 router/vite 里设 base 为 `/apps/<appid>/`。否则静态资源与路由 404。
- Next.js：`/home/coder/workspaces/dootask-plugins/kpi` 是现成参照（Next 15 + React 19 + Tailwind + Radix/shadcn 式，含 standalone Dockerfile）。多阶段构建产出 Node standalone 运行。
- TanStack Start：Vite 底座，可产出 SPA 或带 Nitro server；内嵌场景一般 SPA 即可，构建产物交给 nginx:alpine 或自带 server 托管。
- 前端用 `@dootask/tools` 与主程序握手，见 `references/tools.md`。
- 其它语言（Go/Python 后端）仅在用户明确要求时用。

---

## 形态 A：前后端自建镜像型（最常见）

有自己的前端页面和后端接口，打成一个 `dootask/<appid>` 镜像。

```
<appid>/
├── config.yml                 # 仅元数据
├── logo.svg
├── README.md
├── README_zh.md
├── .build.yml                 # image: dootask/<appid> / context: src / dockerfile: src/Dockerfile
├── src/                       # 源码（前端 + 后端），含 Dockerfile
│   ├── Dockerfile
│   └── ...
└── <版本>/                    # 如 0.1.0
    ├── config.yml             # fields / menu_items / hooks / require_version
    ├── docker-compose.yml
    ├── nginx.conf
    ├── CHANGELOG.md
    └── CHANGELOG_zh.md
```

`docker-compose.yml`：

```yaml
services:
  <appid>:
    image: "dootask/<appid>:${PLUGIN_VERSION}"
    restart: unless-stopped
    environment:
      TZ: "${TIMEZONE:-PRC}"
      # 需要数据库就用主程序内置变量：
      MYSQL_HOST: "${DB_HOST}"
      MYSQL_PORT: "${DB_PORT}"
      MYSQL_DBNAME: "${DB_DATABASE}"
      MYSQL_USERNAME: "${DB_USERNAME}"
      MYSQL_PASSWORD: "${DB_PASSWORD}"
      # 表前缀建议带 appid，避免与其它插件撞表：
      MYSQL_Prefix: "${DB_PREFIX}<appid>_"
      KEY: "${APP_KEY}"
      # 安装时 fields 定义的字段也在这里映射，例如：
      # DEMO_DATA: "${DEMO_DATA}"
```

要点：服务名建议取 `<appid>`（nginx 里用它做上游）；不写 `ports`（由主 nginx 反代）；要持久化就挂 `./data:/...` 或命名卷。

`nginx.conf`（前端 + 受保护后端的典型写法，参照 `approve`）：

```nginx
# 前端 / 静态：
location /apps/<appid>/ {
    proxy_pass http://<appid>/;          # 末尾 / 剥离前缀
}
# 后端接口，先经主程序校验 token：
location /apps/<appid>/api/ {
    auth_request /<appid>Auth;
    proxy_pass http://<appid>/api/;
}
# 鉴权子请求：转发到主程序后端服务（服务名 service）做校验
location /<appid>Auth {
    internal;
    proxy_set_header Content-Type "application/json";
    proxy_set_header Content-Length $request_length;
    proxy_pass http://service/api/<appid>/verifyToken;
}
```

`location` 路径必须与 `menu_items.url` 的基础路径一致（这里是 `apps/<appid>`）。`approve` 用的是无 `/apps` 前缀的 `/<appid>/`——以参照样板和你写的菜单 url 为准，两者保持一致即可。

构建：`docker build -t dootask/<appid>:<版本> -f src/Dockerfile src`（`scripts/build_image.sh` 已封装）。

参照样板：`/home/coder/workspaces/dootask-plugins/system-plugins/approve`（Go + MySQL，含 uninstall hook 清数据）、`/home/coder/workspaces/dootask-plugins/system-plugins/ai`（Go 后端 + `src/ui` 前端）。

---

## 形态 B：代理 + 上游官方镜像型

集成一个现成开源服务：跑它的官方镜像，外面套一个自建轻量代理容器做鉴权与前缀处理。

```
<appid>/                        # 或独立仓库的 dootask-plugin/
├── config.yml
├── logo.png
├── README*.md
├── .build.yml                  # 只构建代理镜像 dootask/<appid>
├── src/                        # 代理源码（Node/Express 等）
└── <版本>/
    ├── config.yml
    ├── docker-compose.yml
    ├── nginx.conf
    └── CHANGELOG*.md
```

`docker-compose.yml`（参照 memos）：

```yaml
services:
  <upstream>:
    image: dootask/<upstream>:1.2.3      # 上游官方镜像，固定版本，不用 ${PLUGIN_VERSION}
    restart: always
    volumes:
      - <appid>-data:/path/in/upstream
    environment:
      - SOME_UPSTREAM_ENV=prod

  <appid>-proxy:
    image: dootask/<appid>:${PLUGIN_VERSION}   # 自建代理，跟随插件版本
    restart: always
    depends_on:
      - <upstream>
    environment:
      - PROXY_PORT=7070
      - UPSTREAM=http://<upstream>:5230        # 容器间用服务名互访
      - DOOTASK_URL=http://nginx               # 回连主程序
      - PUBLIC_BASE=/apps/<appid>
      - ADMIN_USER_IDS=${ADMIN_USER_IDS}       # 来自 fields(user_select)
      - INTERNAL_SECRET=${INTERNAL_SECRET}     # 来自 fields(password, default $random:48)

volumes:
  <appid>-data:
```

`nginx.conf`：把 `/apps/<appid>/` 反代到 `<appid>-proxy`，SSE/WebSocket 单独 location 关 buffering、带 Upgrade/Connection、超时调到 86400s。

要点：上游镜像版本**固定写死**（升级上游 = 改这里）；代理负责把 DooTask 的 token 换成上游账号体系的登录态。

参照样板：`/home/coder/workspaces/dootask-plugins/memos`（包在 `dootask-plugin/` 子目录）。

---

## 形态 C：纯前端静态型

只有前端、无业务后端。DooTask 通过主 nginx 反代到容器，所以最稳的做法是打一个仅托管静态资源的小镜像。

```
<appid>/
├── config.yml
├── logo.svg
├── README*.md
├── .build.yml
├── src/
│   ├── Dockerfile              # 构建前端 → 产物交给 nginx:alpine 托管
│   └── ...(前端工程)
└── <版本>/
    ├── config.yml             # 通常只有 menu_items
    ├── docker-compose.yml
    ├── nginx.conf
    └── CHANGELOG*.md
```

`src/Dockerfile` 多阶段：`node` 构建 → 产物 `COPY` 进 `nginx:alpine` 的 `/usr/share/nginx/html`。`docker-compose.yml` 只有一个服务 `image: dootask/<appid>:${PLUGIN_VERSION}`；`nginx.conf` 把 `/apps/<appid>/` 反代到该容器。

前端仍可用 `@dootask/tools` 与主程序交互（见 `references/tools.md`），只是没有自己的后端接口。

参照样板：套形态 A，去掉后端服务。

---

## 形态 D：纯配置 / 外链型（不写代码）

两种子情况：

**D1 复用现成镜像**（参照 `mysql-expose-port`）：不建自己的镜像，compose 直接用公共镜像。

```yaml
# <版本>/docker-compose.yml
services:
  <appid>:
    image: nginx:alpine               # 或任何现成镜像
    restart: unless-stopped
    ports:
      - "${PROXY_PORT}:3306"          # 这类「暴露端口」插件才需要 ports
    volumes:
      - './data/nginx.conf:/etc/nginx/nginx.conf'
```

顶层 `config.yml` 可带 `fields`（端口等）。没有 `src/`、`.build.yml`，无需构建镜像。

**D2 纯外链菜单**：连容器都不要，只在 `<版本>/config.yml` 里加一个 `menu_items`，`url` 指向外部地址，模式 `external`。这种插件可能不需要 `docker-compose.yml`/`nginx.conf`。

参照样板：`/home/coder/workspaces/dootask-plugins/system-plugins/mysql-expose-port`（D1）。
