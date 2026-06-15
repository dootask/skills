# 四种插件形态

每种形态给出：目录结构（**扁平布局**：项目根目录就是 `<appid>/`）、`docker-compose.yml`、`nginx.conf`、构建方式、参照样板。新建项目统一用扁平布局；个别现成项目（asset-hub/kpi/memos）用 `dootask-plugin/` 子目录包裹包内容，那是其历史布局，**照抄它们的 Dockerfile/basePath/nginx/集成写法，但目录落到扁平布局**。

路径里的 `<appid>`、`<版本>` 按实际替换。生成前务必对照参照样板的真实文件校准。

**默认技术栈（全 JS/TS）**：前端从 **Next.js** 或 **TanStack Start** 二选一（运行时问用户），都配 **shadcn/ui + Tailwind**；**后端不单开**——用框架自带的服务端路由（Next.js 的 `app/api/**/route.ts`、TanStack Start 的 server routes / Nitro），单进程单端口（3000）同时托管页面 + API。两个权威全栈样板：
- `/home/coder/workspaces/dootask-plugins/crm`（**TanStack Start**，**扁平布局,与本技能 1:1**，首选对照）
- `/home/coder/workspaces/dootask-plugins/asset-hub`（**Next.js**，`docs/rules/` 与 `CLAUDE.md` 是权威规范）

---

## 形态 A：前后端自建镜像型（最常见，默认走 JS/TS 单进程全栈）

有自己的前端页面 + 后端接口，打成一个 `dootask/<appid>` 镜像。**默认 Next.js 单进程全栈**：`app/api/**/route.ts` 即后端，一个 `next start` 进程同端口托管页面与 API，不用 Express/Koa、不用双进程。1:1 模式样板：`/home/coder/workspaces/dootask-plugins/asset-hub`（它用 `dootask-plugin/` 包裹布局，下面把同样写法落到扁平布局）。

### 扁平布局目录

```
<appid>/
├── config.yml                 # 仅元数据
├── logo.svg
├── README.md / README_zh.md
├── .build.yml                 # image: dootask/<appid> / context: src / dockerfile: src/Dockerfile
├── src/                       # Next.js 工程（页面 + app/api 后端 + Dockerfile）
│   ├── Dockerfile
│   ├── package.json           # next / react / @dootask/tools / shadcn 等
│   ├── next.config.ts         # basePath: '/apps/<appid>'
│   ├── app/
│   │   ├── [locale]/...        # 页面（可选 i18n，参照 asset-hub）
│   │   └── api/**/route.ts     # 后端接口
│   ├── components/  lib/  ...
│   └── ...                      # SQLite 等数据走运行时卷，不进镜像
└── <版本>/                    # 如 0.1.0
    ├── config.yml             # fields / menu_items / hooks / require_version
    ├── docker-compose.yml
    ├── nginx.conf
    ├── CHANGELOG.md
    └── CHANGELOG_zh.md
```

### basePath 一致性铁律（最容易踩的坑）

页面与 API 都挂在 `/apps/<appid>` 前缀下，下面**四处必须完全一致**，否则静态资源/路由 404：
- `next.config.ts` 的 `basePath: '/apps/<appid>'`
- nginx 的 `location /apps/<appid>/`
- 版本目录 `config.yml` 里 `menu_items.url`：`apps/<appid>/...`
- 前端内部链接交给框架自动加前缀，别手写裸路径

```ts
// src/next.config.ts
import type { NextConfig } from "next";
const nextConfig: NextConfig = { basePath: "/apps/<appid>" };
export default nextConfig;
```

### src/Dockerfile（多阶段，参照 asset-hub）

```dockerfile
FROM node:20 AS builder
WORKDIR /app
RUN corepack enable pnpm
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm build

FROM node:20-slim AS runner
WORKDIR /app
ENV NODE_ENV=production PORT=3000 NEXT_TELEMETRY_DISABLED=1
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/next.config.ts ./next.config.ts
EXPOSE 3000
CMD ["node", "node_modules/next/dist/bin/next", "start", "-p", "3000"]
```

`.build.yml` 的 `context: src`，所以 Dockerfile 里 `COPY . .` 拷的就是 `src/` 内容。需要开机做迁移/定时任务时，可像 asset-hub 那样换成 `start.sh` 作 `CMD`（先 migrate / 起 cron，再 `exec next start`）。

### docker-compose.yml

```yaml
services:
  <appid>:
    image: "dootask/<appid>:${PLUGIN_VERSION}"
    restart: unless-stopped
    environment:
      - TZ=${TIMEZONE:-PRC}
      - <APPID>_ADMIN_USER_IDS=${<APPID>_ADMIN_USER_IDS}   # 来自 fields(user_select)
    volumes:
      - <appid>-data:/app/data          # SQLite 等持久化
volumes:
  <appid>-data:
```

不写 `ports`（由主 nginx 反代）；容器内监听 `3000`。需要主程序数据库的话，用内置变量 `${DB_HOST}`/`${DB_PORT}`/`${DB_DATABASE}`/`${DB_USERNAME}`/`${DB_PASSWORD}`（见 `references/config-yml.md`），但 JS/TS 全栈一般自带 SQLite，挂卷即可。

### nginx.conf（Next basePath 模式，最简单）

```nginx
location /apps/<appid>/ {
    proxy_http_version 1.1;
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_pass http://<appid>:3000;     # 显式端口！且不加末尾 /（Next 已用 basePath 接管前缀，不要剥）
}
```

**两个要点**：① 上游**必须写端口** `:3000`（漏写会默认打到 80 → 502）；② 因为 Next 用 basePath 自己接管了 `/apps/<appid>`，这里 `proxy_pass` **不加末尾 `/`**、不剥前缀——与下文 memos/approve 的「剥前缀」模式正相反。

### DooTask 集成（前端）

用一个 Bridge 组件在启动时 `await appReady()` 初始化 `@dootask/tools`，用户上下文从菜单 url 的 `?theme=&lang=&user_id=&user_token=` 取；脱离 DooTask 宿主时自动降级（捕获 `UnsupportedError`）。参照 asset-hub 的 `components/providers/DooTaskBridge.tsx`，API 速查见 `references/tools.md`。**最小示例**：首页 `appReady()` + `getUserInfo()` 显示当前用户名，证明握手成功。

### 变体

- **TanStack Start**（1:1 扁平样板 `/home/coder/workspaces/dootask-plugins/crm`）：`vite.config.ts` 设 `base: '/apps/<appid>/'`（用 `tanstackStart()` + `nitro` 插件），Dockerfile 多阶段构建后 `CMD ["node", ".output/server/index.mjs"]`、监听 3000。nginx 需**两个 location**：先 `location /apps/<appid>/assets/ { proxy_pass http://<appid>:3000/assets/; }`（剥前缀映射 vite 静态产物，必须放在前面），再 `location /apps/<appid>/ { proxy_pass http://<appid>:3000; }`（SSR + API，不剥前缀）。其余（compose/字段/菜单）一致。
- **后端用 Go/Python（仅按需）**：参照 `approve`（Go，容器监听 80）、`ai`（Python，监听 5001）。容器监听自己的端口，nginx 写 `proxy_pass http://<appid>:<该端口>`；这类后端常自己处理前缀（可加末尾 `/` 剥前缀），需主程序校验 token 时加 `auth_request` 子请求转发到 `http://service/api/<appid>/verifyToken`（见 approve 的 `nginx.conf`）。

### 构建

`docker build -t dootask/<appid>:<版本> -f src/Dockerfile src`（`scripts/build_image.sh` 已封装）。

参照样板：`/home/coder/workspaces/dootask-plugins/asset-hub`（**默认 Next.js 全栈，首选对照**，含 `docs/rules/`）、`/home/coder/workspaces/dootask-plugins/system-plugins/approve`（Go + MySQL）、`/home/coder/workspaces/dootask-plugins/system-plugins/ai`（Python + Vite 前端，单进程 5001 端口同托管 `static/ui` + API）。

---

## 形态 B：代理 + 上游官方镜像型

集成一个现成开源服务：跑它的官方镜像，外面套一个自建轻量代理容器做鉴权与前缀处理。

```
<appid>/
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

`nginx.conf`：把 `/apps/<appid>/` 反代到 `http://<appid>-proxy:7070/`（这里**末尾带 `/` 剥前缀**，因为代理与上游看的是根相对路径）；SSE/WebSocket 单独 `location` 关 buffering、带 `Upgrade`/`Connection`、超时调到 `86400s`。

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

`src/Dockerfile` 多阶段：`node` 构建 → 产物 `COPY` 进 `nginx:alpine` 的 `/usr/share/nginx/html`。前端 base path 仍要设成 `/apps/<appid>/`（Vite `base`、或框架对应配置）。`docker-compose.yml` 只有一个服务 `image: dootask/<appid>:${PLUGIN_VERSION}`；容器内 nginx 监听 80，所以版本目录的 `nginx.conf` 写 `proxy_pass http://<appid>:80/`（或省略端口=80）把 `/apps/<appid>/` 反代过去。

前端仍可用 `@dootask/tools` 与主程序交互（见 `references/tools.md`），只是没有自己的后端接口。

参照样板：套形态 A 的前端部分，去掉 `app/api` 与后端进程。

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
