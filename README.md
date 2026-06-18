# dootask/skills

DooTask 的编码 Agent 插件 —— 覆盖 DooTask 插件开发全流程的 `dootask:*` 技能。同一套 `skills/` 同时供 [Claude Code](#claude-code) 与 [Codex](#codex) 使用。

## 安装

### Claude Code

```text
/plugin marketplace add dootask/skills
/plugin install dootask@dootask-skills
```

装好后用 `/dootask:<技能>` 调用。所有技能均为**显式调用**（`disable-model-invocation`），不会被自动触发。

### Codex

Codex 原生扫描 `skills/` 目录发现技能（清单见 `.codex-plugin/plugin.json`）。手动安装（跟踪 main 分支）：

```bash
# 1. 克隆本仓库
git clone https://github.com/dootask/skills ~/.codex/dootask-skills
# 2. 把 skills/ 软链到 Codex 技能目录，让其发现
mkdir -p ~/.agents/skills
ln -s ~/.codex/dootask-skills/skills ~/.agents/skills/dootask
```

之后在 Codex 里按技能名调用即可。更新：`git -C ~/.codex/dootask-skills pull`。

## 技能

| 技能 | 说明 |
|---|---|
| **`dootask:create-plugin`** | 从零创建一个 DooTask 插件：脚手架 + 最小可跑示例，并通过 `doo` CLI 闭环到本地构建镜像、上传本机应用商店、安装验证。 |
| **`dootask:release-plugin`** | 发布 DooTask 单插件新版本：判定仓库结构（扁平型 / 占位型）、更新中英双语 CHANGELOG、就绪版本目录，推 tag 触发 GitHub Action 发布到 Docker Hub 与 DooTask 应用商店。 |
| **`dootask:claude-md`** | 创建或优化任意仓库的 CLAUDE.md（Claude Code 的项目记忆文件），内置官方与社区最佳实践。 |

## 仓库结构

扁平布局——**仓库根即 `dootask` 插件本身**：

```text
.claude-plugin/
├── marketplace.json    # 市场清单（供 /plugin marketplace add）
└── plugin.json         # Claude Code 插件清单（skills/ 自动发现，无需逐个列出）
.codex-plugin/
└── plugin.json         # Codex 插件清单（"skills": "./skills/"）
AGENTS.md -> CLAUDE.md   # Codex 等 Agent 读取的仓库上下文，软链到 CLAUDE.md
skills/                 # 三个技能，各一目录
├── create-plugin/
├── release-plugin/
└── claude-md/
LICENSE                 # MIT
```

## 两个身份

- **可分发 marketplace**：他人按上方「安装」添加本仓库即可装 `dootask` 插件，对外更新靠 `git push`。
- **本地开发**：`marketplace.json` 的 `source` 指向 `./`，本仓库既是市场也是插件；改动后用 `claude plugin validate .` 校验。

## 维护

```bash
git add -A && git commit -m "..." && git push
```
