# @dootask/tools 速查（插件 ↔ 主程序交互）

官方工具库，前端 npm 包 + 后端 Go/Node/Python SDK。当前前端版本约 `1.2.7`（以 npm 实际为准）。源码用代表词 `ref:tools` 指代（前端在 `src/`，后端在 `server/go`、`server/python`、`server/node`，另有 `example/` 示例）；本地路径与获取方式（本地优先，缺失则 `git clone --depth=1 https://github.com/dootask/tools`）见 `references/samples.md`。

## 一个包，两侧：前端（浏览器）≠ 后端（服务端）

`@dootask/tools` 同一个 npm 包里含**两套互不通用**的东西，**按代码跑在哪决定用哪侧，别混用**：

- **前端 / 浏览器侧** —— `import { appReady, getUserInfo, ... } from "@dootask/tools"`：微前端桥，拿主程序注入的用户/主题/语言、开对话框、选人等。**依赖 `window`**，在 Next.js / TanStack Start 等 SSR 框架里**必须客户端动态 `import()`（或 client-only）**，否则 SSR 阶段触碰 `window` 直接崩。
- **后端 / 服务端侧** —— Node：`import { DooTaskClient } from "@dootask/tools"`（同包，另一入口）；以用户 token 调主程序 HTTP API，默认 `server: "http://nginx"`。其它语言：Go `github.com/dootask/tools/server/go`、Python `pip install dootask-tools`（`from dootask import DooTaskClient`）。

判断：浏览器组件里 → 前端侧；route handler / server function / 后端进程里 → 后端侧。参照 `ref:crm` 的 `lib/dootask.ts`（前端，动态 import）与 `lib/dootask-server.ts`（服务端，DooTaskClient）。

## 前端

安装与引入：

```bash
npm install @dootask/tools --save
```

```ts
import {
  appReady, getUserInfo, getUserId, getUserToken,
  getThemeName, getLanguageName, getSystemInfo, getBaseUrl,
  requestAPI, selectUsers,
  modalSuccess, modalError, modalConfirm, messageSuccess, messageError,
  closeApp, backApp, interceptBack,
  openWindow, openTabWindow, openDialog,
  setCapsuleConfig, isMicroApp,
  UnsupportedError,
} from "@dootask/tools"
```

最小握手（这就是「最小可跑示例」的核心——装上能看到当前用户名即证明打通）：

```ts
async function boot() {
  try {
    await appReady()                    // 必须先等主应用就绪
    const user = await getUserInfo()    // { userid, nickname, email, userimg, identity, ... }
    document.body.innerText = `Hello, ${user.nickname}`
  } catch (e) {
    if (e instanceof UnsupportedError) {
      // 不在 DooTask 微前端环境（比如直接浏览器打开），降级处理
      document.body.innerText = "请在 DooTask 内打开本应用"
    } else {
      throw e
    }
  }
}
boot()
```

调用自己的后端接口：菜单 url 里带了 `{user_token}`，前端从 URL query 取出传给后端；或用 `requestAPI` 调主程序接口。query 参数名自定但**前后端要一致**——真实样板 crm 用 `?theme=&lang=&user_id=&user_token=`（见 `references/config-yml.md` 的 menu_items 示例），前端就读 `user_token`/`user_id`。

要点：所有方法返回 Promise；环境检测类 `isMicroApp()`/`isElectron()` 返回 boolean 不抛异常；`openWindow` 类仅特定客户端有效。

**生产级模式（参照 asset-hub）**：用一个 Bridge 组件（如 `components/providers/DooTaskBridge.tsx`）在应用最外层 `await appReady()` 一次，把用户/主题/语言放进 context 供全局用；用户上下文走菜单 url 的标准参数 `?theme={system_theme}&lang={system_lang}&user_id={user_id}&user_token={user_token}`；脱离宿主（直接浏览器打开）捕获 `UnsupportedError` 自动降级。后端接口鉴权常用「前端把 user_id/token 放进请求头（如 `x-user-id`），服务端读取」的简单方式。

## 后端 SDK

三种语言能力一致：默认连主程序 `http://nginx`，用前端传来的用户 token 鉴权，可查用户、发消息、操作项目/任务/对话等。

**Go** —— `go get github.com/dootask/tools/server/go`

```go
import dootask "github.com/dootask/tools/server/go"

client := dootask.NewClient(token, dootask.WithServer("http://nginx"))
user, err := client.GetUserInfo()
```

**Node** —— `import { DooTaskClient } from "@dootask/tools"`

```ts
const client = new DooTaskClient({ token, server: "http://nginx", timeoutMs: 10_000 })
const user = await client.getUserInfo()
```

**Python** —— `pip install dootask-tools`

```python
from dootask import DooTaskClient
client = DooTaskClient(token=token, server="http://nginx")
user = client.get_user_info()
```

常用方法（各语言命名风格不同，能力一致）：`getUserInfo` / `sendMessage` / `sendMessageToUser` / `createProject` / `createTask` / `updateTask` / `getTaskList` / `createGroup` / `getDialogList`。

鉴权流：前端 `getUserToken()` 或菜单 url 的 `{user_token}` → 传到后端 → 后端用该 token 构造 SDK client → 以该用户身份调主程序。生产环境主程序地址用服务名 `http://nginx`，无需显式配置。
