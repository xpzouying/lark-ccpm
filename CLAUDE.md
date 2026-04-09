# CLAUDE.md

## Issue 工作流规范

### 计划阶段
- 制定实施计划（Plan）并经用户确认后，将计划作为 comment 发布到对应的 GitHub Issue 中
- 格式：使用 `gh issue comment <N> --body "..."` 提交计划内容

### 完成阶段
- 执行完计划、PR 合并后，关闭对应的 GitHub Issue
- 格式：使用 `gh issue close <N>` 关闭 Issue
