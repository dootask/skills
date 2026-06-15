# CLAUDE.md 参考资料

SKILL.md 用不到的深入机制、数据和清单都在这里,按需查阅。内容来自 Anthropic 官方文档与社区实战(2026-06 调研);**官方原则是地基,社区数字是参考**。

## 目录
1. [加载机制](#1-加载机制)
2. [层级体系与加载顺序](#2-层级体系与加载顺序)
3. [`@path` import 语法](#3-path-import-语法)
4. [`/init` 与 `/memory`、auto memory](#4-init-与-memoryauto-memory)
5. [长度阈值:各家数据与矛盾点](#5-长度阈值各家数据与矛盾点)
6. [完整反模式清单](#6-完整反模式清单)
7. [monorepo / 多包处理](#7-monorepo--多包处理)
8. [CLAUDE.md vs Skills vs Rules vs Hooks](#8-claudemd-vs-skills-vs-rules-vs-hooks)
9. [参考实例与权威来源](#9-参考实例与权威来源)

---

## 1. 加载机制

- **每次会话开始全量加载,不论长短**;但越短遵从度越好(officially: "loaded in full regardless of length, though shorter files produce better adherence")。
- **它是 system prompt 之后的一条 user message,不是系统提示本身**,所以"Claude 读到并尽量遵守,但对模糊或冲突的指令不保证严格执行"。想要系统提示级强度用 `--append-system-prompt`。
- **是 context 而非强制配置。** 要"无论如何都拦住某操作",用 `PreToolUse` hook,别指望 CLAUDE.md。
- **token 成本 = 每个请求都付。** 这正是要 < 200 行、把参考材料挪去 skill 的原因。
- **块级 HTML 注释 `<!-- ... -->` 注入前会被剥掉、不占 token**(代码块内的注释保留)——可用来写维护者备注。
- **`/compact` 后项目根 CLAUDE.md 会从磁盘重新注入**;子目录 CLAUDE.md 不会自动重注入,下次读到该目录文件时才重新加载。

## 2. 层级体系与加载顺序

按 **从最广到最具体** 的顺序加载(更具体的出现在上下文更后面;冲突时"通常更具体的优先",由 Claude 判断调和,不是硬覆盖):

| 级别 | 位置 | 说明 |
|---|---|---|
| Managed policy(组织级) | Linux `/etc/claude-code/CLAUDE.md`;macOS `/Library/Application Support/ClaudeCode/CLAUDE.md`;Windows `C:\Program Files\ClaudeCode\CLAUDE.md` | 最先加载,个人设置无法排除 |
| User(个人,跨所有项目) | `~/.claude/CLAUDE.md` | |
| Project(团队共享,入 git) | `./CLAUDE.md` 或 `./.claude/CLAUDE.md` | |
| Local(个人项目偏好,gitignore) | `./CLAUDE.local.md` | 官方动向已弱化,推荐改用 `@import` + gitignored 文件 |

- **向上遍历 + 拼接(不是覆盖)。** Claude 从工作目录向文件系统根逐级向上,把所有发现的 CLAUDE.md 拼进上下文,从根到工作目录排序(越靠近工作目录越靠后)。
- **子目录 CLAUDE.md 懒加载:** 不在启动时加载,只在 Claude 读到该子目录的文件时才纳入。**兄弟目录永不互相加载**(在 `frontend/` 干活不会拉 `backend/CLAUDE.md`)。
- 大型 monorepo 可用 settings 的 `claudeMdExcludes`(glob 匹配绝对路径)排除无关 CLAUDE.md;但 managed policy 的排不掉。

## 3. `@path` import 语法

- 语法 `@path/to/import`,可放任意位置。例:`See @README for overview and @package.json for commands.`
- 相对路径相对**包含该 import 的文件**(不是工作目录);绝对路径也支持。
- 可递归 import,**最大深度 4 跳**(以官方 memory 文档为准;早期 best-practices 写 5 跳)。
- **import 不省 token**:被引文件在启动时连同 CLAUDE.md 一起全量展开进上下文。拆 `@path` 只帮组织,不减上下文。
- 首次遇到外部 import 会弹审批;拒绝后永久禁用且不再提示。
- 跨 git worktree 共享个人指令用 `@~/.claude/...`(因为 gitignored 的 `CLAUDE.local.md` 只存在于创建它的那个 worktree)。
- **AGENTS.md:** Claude Code 只读 CLAUDE.md,不读 AGENTS.md;要复用就 `@AGENTS.md` import 或建 symlink。

## 4. `/init` 与 `/memory`、auto memory

- **`/init`** 分析代码库(检测 build 系统、测试框架、代码模式)生成起步版 CLAUDE.md。**已存在时不覆盖,而是建议改进。** 仓库里有 AGENTS.md / .cursorrules / .windsurfrules 等会读取并并入。可作为新建时的起点,但**必须手工精修**——纯自动生成不打磨是社区公认的反模式。
- **`/memory`** 列出当前会话加载的所有 CLAUDE.md / local / rules 文件,可开关 auto memory、直接编辑。
- **Auto memory**(v2.1.59+ 默认开)是 Claude 自己写的另一套记忆,存 `~/.claude/projects/<project>/memory/`,与 CLAUDE.md 互补,都在会话开始加载。其入口 `MEMORY.md` 只加载前 200 行或 25KB(topic 文件按需读)——这个限制只针对 MEMORY.md,CLAUDE.md 仍全量加载。让 Claude"记住某事"默认进 auto memory;要进 CLAUDE.md 得明说"加到 CLAUDE.md"或自己编辑。

## 5. 长度阈值:各家数据与矛盾点

| 阈值 | 出处 |
|---|---|
| < 200 行(**官方推荐上限**),> 200 行是警告信号 | Anthropic memory 文档 |
| < 60 行(HumanLayer 自己 root 文件的标杆) | HumanLayer |
| > 80 行开始被忽略 | abhishekray07 |
| < 300 行(目标,越短越好) | HumanLayer |
| ~250 行实践天花板,> 500 行必须拆 | redreamality |
| < ~800 词/汉字(非英文项目甜区) | redreamality |

**比行数更关键的是 distinct 指令条数**:前沿模型约 150–200 条可保持合理一致,Claude Code 系统提示已占 ~50 条,**超过 ~50 条 distinct 指令是警告线**。Anthropic 研究(Jaroslawicz et al. 2025)被多处引用:**指令遵从度随指令数线性衰减——指令翻倍,遵从减半**。

**矛盾点 / 注意:**
- 官方 memory 文档给的是「**target under 200 lines**」这一推荐目标(措辞是"目标/建议"而非硬性上限);其余行数阈值(60/80/300/250)众说纷纭、都是社区实测,别把社区数字当硬规则。共识:"越短越好 + 按 distinct 指令条数卡"。
- "越短越好" **有下限**:redreamality 实测 3000 字符砍到 800 最优、砍到 400 会丢关键信息。是 U 形,不是越短越好的单调曲线。
- 官方除了原则(concise / 解决真实问题 / 像调 prompt 一样迭代),**也给了「< 200 行」这个推荐目标**(memory 文档原文 "target under 200 lines");但更细的精确数字(字符数、各家行数)多来自社区博客实测,权威性弱于官方。

## 6. 完整反模式清单

- **当 linter 用** — 把风格规则(缩进/引号/import 顺序)写进去。交给确定性工具。
- **文件太长 / 指令太多** — 低优先级指令被挤掉,整体被当"可忽略"。
- **重复 README / 代码能看出的** — 项目介绍、架构图、stack 描述、Getting Started 属于 README。LLM 是 in-context learner,代码里一致的模式它自己会学。
- **过期 / 死指令** — 引用已不存在的目录/API/命令,反而误导。配一次不管,三个月后 Claude 在遵守不再适用的规则。
- **矛盾指令** — 不同人陆续加进互斥规则("用 interface" vs "用 type alias"),行为随机。
- **纯靠 `/init` 自动生成不打磨** — harness 杠杆率最高的点恰恰需要手工精修。
- **嵌入整份大文档 `@大文件`、写"人格"指令("你是资深工程师/be nice")、硬编码凭证或过期 model ID。**
- **每条都标 IMPORTANT/MUST** — 强调通胀,等于没强调。
- **贴会过期的代码 snippet** — 用 `file:line` 指针代替。

## 7. monorepo / 多包处理

- **root 放跨包全局约定**:各 app 是什么、shared 包干嘛,给一张 mental map。
- **包级 CLAUDE.md 放该包专属规则**,靠懒加载(只在动该目录文件时才载)避免无关包污染上下文。
- `.claude/rules/` + YAML frontmatter `paths`:路径作用域规则,只在匹配文件出现时加载,可给 root CLAUDE.md 减负。
- 每个 skill / 包级文件控制在 ≤ 500 行,超了再按目录拆。

## 8. CLAUDE.md vs Skills vs Rules vs Hooks

| | 加载 | 适合 |
|---|---|---|
| **CLAUDE.md** | 每会话全量,每请求付费 | "永远该知道"的约定、build/测试命令、项目结构、"永不做 X" |
| **Skill** | 默认只加载 description,全文按需 | 偶尔才用的参考资料(API 文档、风格指南)、`/<name>` 触发的工作流(部署、发版、review) |
| **`.claude/rules/`** | 每会话或匹配 `paths` 时加载 | 给 CLAUDE.md 减负的路径作用域规则 |
| **Hook** | 确定性执行(非 prompt) | 必须 100% 生效的红线("禁止改 .env")——prompt 里的规则是请求,hook 才是法律 |

判定口诀:
- Claude 应该**永远知道** → CLAUDE.md。
- **偶尔才需要**的参考 / 多步流程 / 可 `/触发` 的工作流 → skill。
- 同一份 playbook 第三次粘进 chat → 做成 skill。
- 规则必须**每次都强制** → hook。

## 9. 参考实例与权威来源

**优秀 CLAUDE.md 实例 / 模板(看真实例子):**
- https://github.com/josix/awesome-claude-md — 精选合集,带分析
- https://github.com/abhishekray07/claude-md-templates — 速查卡 + 三级层级模板
- https://github.com/MuhammadUsmanGM/claude-code-best-practices — 含 minimal / monorepo 范例

**官方文档:**
- https://code.claude.com/docs/en/memory
- https://code.claude.com/docs/en/best-practices
- https://code.claude.com/docs/en/features-overview

**社区深度文:**
- https://www.humanlayer.dev/blog/writing-a-good-claude-md
- https://www.humanlayer.dev/blog/stop-claude-from-ignoring-your-claude-md(条件块 `<important if="...">` 技巧)
- https://redreamality.com/blog/claude-md-agents-md-deep-dive/
- https://www.aicodex.to/articles/claude-md-maintenance(维护工作流)
