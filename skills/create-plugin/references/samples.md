# 样板与本地参考登记表

本技能全程用**带 `ref:` 前缀的代表词**（下表第一列，如 `ref:crm`、`ref:tools`）指代参照样板与本地参考资料，不在正文里写死机器绝对路径。`ref:` 是命名空间前缀，用来把这些登记条目和正文里同名的普通词/产品名（如 ai、tools、crm）区分开：**凡见到 `ref:xxx`，就去本表按下面的「获取约定」解析到一个可读目录再读**。

## 获取约定（解析一个 `ref:` 代表词 → 可读目录）

约定一个**可复用的临时目录**（已存在就复用，不重复 clone）：

```bash
REFDIR="${DOOTASK_REFS:-/tmp/dootask-refs}"; mkdir -p "$REFDIR"
```

对任一 `ref:` 代表词，按顺序解析（在线仓库 / 本机路径 / 子目录均查下表）：

1. **本机本地路径存在** → 直接读（最快、免联网，开发机首选）。
2. **本地不存在、且有公开在线仓库** → 浅克隆到 `$REFDIR` 后读：
   ```bash
   # 仓库整体（system-plugins 三个样板共用一个仓库，clone 一次读子目录）
   [ -d "$REFDIR/<repo>" ] || git clone --depth=1 https://github.com/dootask/<repo> "$REFDIR/<repo>"
   # 然后读 $REFDIR/<repo>/<子目录>
   ```
3. **私有 / 无仓库**（`ref:appstore-docs` 私有、`ref:app-landing` 运行时生成）→ 本机能读就读；否则 `ref:appstore-docs` 可 `gh repo clone dootask/appstore "$REFDIR/appstore"`（需 gh 授权），`ref:app-landing` 无在线源。**都拿不到时回退到本技能自带的 `references/*.md`**，并明确告知用户「未读到现成样板，按内置规范生成，请重点复核」。

> 只浅克隆（`--depth=1`）、只读不改。`$REFDIR` 可跨会话复用；想刷新某个样板时 `git -C "$REFDIR/<repo>" pull --depth=1` 或删掉重 clone。

## 登记表

| 代表词 | 形态 / 用途 | 本机本地路径 | 在线仓库（clone 源） |
| --- | --- | --- | --- |
| `ref:crm` | 样板·形态A·**TanStack Start**·扁平布局**与本技能 1:1，首选对照** | `~/workspaces/dootask-plugins/crm` | `dootask/crm`（公开） |
| `ref:asset-hub` | 样板·形态A·**Next.js**·`docs/rules/` 与 `CLAUDE.md` 是权威规范 | `~/workspaces/dootask-plugins/asset-hub` | `dootask/asset-hub`（公开） |
| `ref:kpi` | 样板·Next.js 参照 | `~/workspaces/dootask-plugins/kpi` | `dootask/kpi`（公开） |
| `ref:memos` | 样板·形态B·代理 + 上游官方镜像（包在 `dootask-plugin/` 子目录） | `~/workspaces/dootask-plugins/memos` | `dootask/memos`（公开） |
| `ref:approve` | 样板·形态A 变体·Go + MySQL 后端（容器监听 80，含 `auth_request`） | `~/workspaces/dootask-plugins/system-plugins/approve` | `dootask/system-plugins`（公开，子目录 `approve`） |
| `ref:ai` | 样板·形态A 变体·Python + Vite（单进程 5001 同托管 `static/ui` + API） | `~/workspaces/dootask-plugins/system-plugins/ai` | `dootask/system-plugins`（公开，子目录 `ai`） |
| `ref:mysql-expose-port` | 样板·形态D1·纯配置复用现成镜像 | `~/workspaces/dootask-plugins/system-plugins/mysql-expose-port` | `dootask/system-plugins`（公开，子目录 `mysql-expose-port`） |
| `ref:tools` | `@dootask/tools` 源码（前端 `src/` + 后端 `server/{go,node,python}` + `example/`） | `~/workspaces/dootask-tools` | `dootask/tools`（公开） |
| `ref:doo-cli` | `doo` CLI（npm 包 `@dootask/cli`）源码 + README；**完整命令以 `doo --help` / `doo <子命令> --help` 实时输出为准** | `~/workspaces/dootask-tools/server/cli` | `dootask/tools`（公开，子目录 `server/cli`） |
| `ref:appstore-docs` | 官方插件开发文档 `apps/_/README_CN.md` | `~/workspaces/dootask-appstore/appstore/apps/_/README_CN.md` | `dootask/appstore`（**私有**，需 gh 授权才能 clone） |
| `ref:dootask` | 主程序源码（查 API / 约定 / 主程序行为时读它） | `~/workspaces/dootask` | `kuaifan/dootask`（公开） |
| `ref:app-landing` | 应用落地目录（`doo app upload` 导入后所在，只读参考） | `~/workspaces/dootask/docker/appstore/apps` | 运行时生成，**无在线源** |

> 表中本机路径用 `~/workspaces/...` 表示约定位置；实际开发机展开为 `/home/coder/workspaces/...`。`DOOTASK_REFS` 未设时临时目录默认 `/tmp/dootask-refs`。`ref:` 代表词 → 在线仓库的映射多数同名（`ref:crm`→`dootask/crm`），少数例外见表（`ref:approve`/`ref:ai`/`ref:mysql-expose-port`→`dootask/system-plugins` 子目录，`ref:doo-cli`→`dootask/tools` 子目录 `server/cli`，`ref:dootask`→`kuaifan/dootask`）。
