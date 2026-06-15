# dootask-skills

DooTask 的 Claude Code 插件市场。**本仓库根即 `dootask` 插件本身**（扁平布局，superpowers 同款）。

## 结构约定（改动时务必守住）

- `.claude-plugin/marketplace.json` —— 市场清单，单插件 `dootask`，`source` 为 `"./"`（仓库根就是插件）。
- `.claude-plugin/plugin.json` —— 插件清单。**不要**写 `skills` 数组：`skills/` 目录会被自动发现，列出反而冗余/重复注册。
- `skills/<name>/SKILL.md` —— 每个技能一目录，内部用 `references/`（按需文档）、`scripts/`（可执行）、`assets/`（模板）分层。
- 三个技能全部 `disable-model-invocation: true` —— 仅 `/dootask:<技能>` 显式调用，不自动触发。

## SKILL.md 规范要点

- frontmatter：`name`（小写+连字符，≤64 字符，禁含 `claude`/`anthropic`）、`description`（≤1024 字符）。
- 正文 < 500 行；超 100 行的 reference 文件顶部加目录；引用从 SKILL.md 只下钻一层。
- 路径一律正斜杠。

## 维护

- 仅在用户要求时 commit / push；不主动建分支，在当前分支提交。
- 校验：`claude plugin validate .`（市场）/ `claude plugin validate . --strict`（插件）。
