# skills

个人的 Claude Code 用户级技能集合,对应 `~/.claude/skills/`。

每个子目录是一个技能,至少包含一个 `SKILL.md`(技能说明 + 工作流),可附带 `references/`(按需加载的参考资料)、`scripts/`、`assets/` 等。Claude Code 会自动发现这些技能,并在合适的场景下调用。

## 维护

```bash
# 新增/修改技能后
git add -A && git commit -m "..." && git push
```

> 本仓库即 `~/.claude/skills/` 本身,改动直接生效,无需安装步骤。
