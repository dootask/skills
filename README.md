# dootask/skills

DooTask 的 Claude Code 插件 —— 覆盖 DooTask 插件开发全流程的 `dootask:*` 技能。

## 安装

```text
/plugin marketplace add dootask/skills
/plugin install dootask@dootask-skills
```

装好后用 `/dootask:<技能>` 调用。所有技能均为**显式调用**（`disable-model-invocation`），不会被自动触发。

## 技能

| 技能 | 说明 |
|---|---|
| **`dootask:create-plugin`** | 从零创建一个 DooTask 插件：脚手架 + 最小可跑示例，并通过 `doo` CLI 闭环到本地构建镜像、上传本机应用商店、安装验证。 |
| **`dootask:release-plugin`** | 发布 DooTask 单插件新版本：判定仓库结构（扁平型 / 占位型）、更新中英双语 CHANGELOG、就绪版本目录，推 tag 触发 GitHub Action 发布到 Docker Hub 与 DooTask 应用商店。 |
| **`dootask:claude-md`** | 创建或优化任意仓库的 CLAUDE.md（Claude Code 的项目记忆文件），内置官方与社区最佳实践。 |

## 仓库结构

```text
.claude-plugin/marketplace.json    # 市场清单（供 /plugin marketplace add）
dootask/                           # dootask 插件
├── .claude-plugin/plugin.json     # 插件清单，显式列出下方三个技能
└── skills/
    ├── create-plugin/
    ├── release-plugin/
    └── claude-md/
```

## 两个身份

- **本地加载目录**：本仓库即 `~/.claude/skills/` 本身，`clone` 后 `dootask` 插件经 `@skills-dir` 自动加载，改动直接生效、无需安装。
- **可分发 marketplace**：他人按上方「安装」添加本仓库即可装 `dootask` 插件。对外更新靠 `git push`。

## 维护

```bash
git add -A && git commit -m "..." && git push
```
