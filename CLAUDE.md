# CLAUDE.md

## Issue 工作流规范

每个 GitHub Issue 的完整生命周期：**Plan → Comment → Execute → PR → Merge → Close**

### 1. 计划阶段
- 制定实施计划（Plan）并经用户确认后，将计划摘要作为 comment 发布到对应的 GitHub Issue 中
- 每个 Issue 开始执行前都必须有 plan comment，无论任务大小
- 格式：`gh issue comment <N> --body "## Implementation Plan ..."`

### 2. 执行阶段
- 使用 git worktree 隔离开发
- PR body 中使用 `Closes #N` 自动关联 Issue

### 3. 完成阶段
- PR 合并后，`Closes #N` 会自动关闭 Issue
- 如果 PR 未使用 `Closes`，手动关闭：`gh issue close <N>`
