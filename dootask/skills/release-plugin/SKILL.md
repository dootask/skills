---
name: release-plugin
description: 发布 DooTask 单插件新版本（推 tag 发布到 Docker Hub 与 DooTask 应用商店）。
disable-model-invocation: true
---

# 发布 DooTask 单插件

DooTask 插件靠 **推送 tag** 触发 `.github/workflows/release.yml`：（多架构）构建镜像推 Docker Hub + 打包发布到 DooTask 应用商店。常规 push / PR 不发布，光 `git tag` 不 push 也不会。

单插件仓库**有两种版本目录约定**，套错会踩 CI 打包 / 重命名的坑（最典型：对占位目录型仓库按版本号新建目录，会让 runner 里的 `mv` 直接失败）。所以**发布前第一步必须判定本仓库属于哪种**。

## 第一步：判定仓库属于哪种结构

在仓库根执行 `ls`，按下表判定（互斥）：

| 仓库根看到 | 模型 | tag 形式 | 详细流程 |
|---|---|---|---|
| 有 `dootask-plugin/` 目录，其下是固定占位目录 `version/` + `config.yml`（根目录是应用源码工程，发布载荷隔离在 `dootask-plugin/`） | **B 占位目录型（工程仓库型）** | 纯数字 `0.2.0` | [references/type-B-placeholder.md](references/type-B-placeholder.md) |
| 根直接有 `config.yml` + **数字命名的真实版本目录**（`0.1.0/`）+ `src/`，无 `dootask-plugin/` | **A 真实版本目录型（扁平型）** | 纯数字 `0.2.0` | [references/type-A-flat.md](references/type-A-flat.md) |

> 已知归类：**A** = crm（也是 `dootask:create-plugin` 脚手架生成新插件的标准布局）；**B** = kpi、asset-hub、memos、mcp。遇到新仓库按上表**现场判定**，别套用这条记忆。
>
> 例外：若仓库根**并列多个插件目录**（monorepo，如 `system-plugins` 的 office/drawio/…，tag 形如 `<插件>/<版本>`），**不属本技能**，用该仓库 `.claude/skills/` 里自带的 release 技能。

**判定后读对应 references 文件，按其分步流程执行。** 下面是两型共有的铁律与规范。

## 共有铁律

1. **Tag 不带 `v` 前缀。** workflow 监听 `tags: '*'`，带 `v` 也会触发，但 Docker 镜像 tag 由 `type=ref,event=tag` 取原始 ref 名——推 `v0.2.0` 会得到镜像 tag `v0.2.0`，破坏排序、且和 AppStore / compose 的版本对不上。
2. **只有推送 tag 才触发发布。** 普通 push / PR 不跑发布 workflow；光 `git tag` 不 push 也不会。
3. **AppStore 版本号只增不重复。** 重发只能递增（`0.1.9` → `0.1.10`）。误推的 tag 删了也撤不回已发布的 AppStore 版本。
4. **发布公开且不可逆。** 推 tag 前**必须和用户确认版本号与 CHANGELOG**；常规 git 操作（提交、推分支）可自行判断。
5. **依赖 Repository Secrets**（仓库 Settings → Secrets and variables → Actions）：`DOOTASK_USERNAME` / `DOOTASK_PASSWORD` + `DOCKER_USERNAME` / `DOCKER_PASSWORD`（注意是 `DOCKER_*` 不是 `DOCKERHUB_*`）。由管理员一次性配置，本技能不负责设置；登录类报错时提醒用户检查。

## CHANGELOG 规范（两型通用）

中英双语两文件 `CHANGELOG.md`（英文）/ `CHANGELOG_zh.md`（中文），具体路径见各型流程：

- **覆盖式，不是追加**：整个文件替换成本次内容，不保留上一版条目（AppStore 自己维护历史）。文件里**不写版本号和日期**（版本由目录名 / tag 承载）。
- 按分类列点，只用本次涉及的分类；中英两文件的**分类、条数、含义严格一一对应**（第 N 条说同一件事）。
- 一句话一条，**写给最终用户看**，不是开发者（说「新增客户跟进时间线」，不说「重构 follow_ups 表」）；涉及具体功能写出名字；保持简洁。
- 分类对照：

  | 英文 | 中文 |  | 英文 | 中文 |
  |---|---|---|---|---|
  | Added | 新增 |  | Changed | 变更 |
  | Fixed | 修复 |  | Improved | 优化 |
  | Updated | 更新 |  | Removed | 移除 |

## 通用发布骨架（每步细节看各型 references）

1. **首次发布先确保有工作流**：脚手架新建的插件不带 `.github/workflows/release.yml`，没有就推 tag 也不触发任何发布。缺则先按各型 references 创建（A 型有参数化模板 `assets/release.yml.template`）。
2. **状态干净**：在 `main`、工作区干净、与 `origin/main` 同步（`git fetch && git status`）；待发布的代码改动先提交推上去。
3. **定版本号**：`git tag --sort=-creatordate | head` 看已发版本，按 SemVer（patch=bugfix / minor=新功能 / major=破坏性），与用户确认，只增不重复。
4. **就绪版本目录 + 更新 CHANGELOG**：是否新建目录、目录在哪、CHANGELOG 放哪，**按型号**（A=新建真实版本目录；B=固定占位目录 `version/` 里改）。
5. **提交推 main**：若仓库有 `ci.yml`，确认本次提交跑绿（推 tag 不重跑 lint/build）。
6. **打 tag 推送触发**（不可逆，纯数字 tag）：盯 `gh run watch`。
7. **验证**：Docker Hub 出现新 tag + DooTask 应用商店对应 appid 版本已更新；提醒用户在 DooTask 管理端「更新应用列表」后强刷浏览器。
