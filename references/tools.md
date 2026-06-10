# @dootask/tools 速查（插件 ↔ 主程序交互）

官方工具库，前端 npm 包 + 后端 Go/Node/Python SDK。当前前端版本约 `1.2.7`（以 npm 实际为准）。本机源码：`/home/coder/workspaces/dootask-tools`（前端在 `src/`，后端在 `server/go`、`server/python`、`server/node`，另有 `example/` 示例）。在线仓库：`https://github.com/dootask/tools`。

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

调用自己的后端接口：菜单 url 里带了 `{user_token}`，前端从 URL query 取 token 传给后端；或用 `requestAPI` 调主程序接口。常见做法是前端读 `?token=&lang=&theme=` 初始化主题/语言/鉴权。

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
