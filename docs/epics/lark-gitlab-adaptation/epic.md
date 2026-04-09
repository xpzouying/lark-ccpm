---
name: lark-gitlab-adaptation
status: backlog
created: 2026-04-09T10:00:00Z
updated: 2026-04-09T10:00:00Z
progress: 0%
prd: docs/prds/lark-gitlab-adaptation.md
---

# Epic: CCPM 飞书 + GitLab 适配

## Overview

将 CCPM 的外部后端从 GitHub（Issues + gh CLI）迁移到飞书多维表格（lark-cli base）+ GitLab（glab CLI）。改造范围覆盖 `skill/ccpm/` 下的 references 文件、init 脚本和 track 脚本，本地文件结构和五阶段流程不变。

## Architecture Decisions

### AD-1: 命令层直接替换，不引入抽象层

直接将 `gh` 命令替换为 `lark-cli base` / `glab` 命令，不引入中间抽象层（如 provider interface）。理由：CCPM 的 references 文件是 prompt 模板而非可执行代码，抽象层增加复杂度但无实际收益。

### AD-2: 任务文件保留自增序号命名

飞书 Record ID（如 `recXXXXXX`）太长不适合做文件名。保留 `001.md`、`002.md` 命名，sync 后不再重命名为外部 ID，改为在 frontmatter 的 `lark_record` 字段中记录 Record ID。

### AD-3: 项目级配置文件集中管理

新增 `.claude/lark-ccpm.yml` 存储飞书 App Token、Table ID、GitLab 项目路径，避免每次命令都传参。init.sh 负责创建此文件。

### AD-4: 进度同步采用字段更新 + 可选群消息

飞书多维表格无评论功能。进度同步通过更新记录的"状态"和"进度"字段实现；详细进展追加到"描述"字段；可选通过 `lark-cli messenger` 发群消息。

### AD-5: Frontmatter schema 向后兼容演进

`github:` 字段替换为 `lark_record:` + `gitlab_mr:`，同时新增 `lark_app:` 和 `lark_table:` 用于 Epic 级别。

## Technical Approach

### 改造分层

| 层级 | 文件 | 改动性质 |
|------|------|----------|
| 重度 | `sync.md`, `conventions.md` | 核心逻辑替换（gh → lark-cli/glab） |
| 中度 | `execute.md`, `scripts/init.sh` | 命令替换 + 初始化逻辑重写 |
| 轻度 | `SKILL.md`, `plan.md`, `structure.md`, `track.md` | 文案替换 |
| 轻度 | `scripts/epic-*.sh` | frontmatter 字段名替换 |

### 关键改造点

1. **sync.md**（改动量最大）：Epic Sync、Task 创建、Progress 同步、关闭任务、合并 Epic、Bug 报告——全部从 gh 命令改为 lark-cli + glab
2. **conventions.md**：Frontmatter schema、GitHub Operations 整节替换、认证检查
3. **init.sh**：从检查 gh → 检查 lark-cli + glab，从创建 GitHub labels → 创建飞书多维表格
4. **execute.md**：Issue 读取和状态更新命令替换

## Implementation Strategy

采用**自底向上**策略：先改造基础设施（init.sh + conventions.md），再改造核心流程（sync.md），最后改造上层文件和脚本。这样每完成一层，下一层的改造可以基于已验证的基础。

## Task Breakdown Preview

1. 基础设施层：init.sh 改造、conventions.md 改造、配置文件设计
2. 核心流程层：sync.md 改造（Epic Sync、Task 创建、进度同步、关闭/合并）
3. 执行层：execute.md 改造
4. 文案层：SKILL.md、plan.md、structure.md、track.md 文案替换
5. 脚本层：epic-list.sh、epic-show.sh、epic-status.sh 字段替换
6. 验证层：端到端测试

## Dependencies

- `lark-cli base` 子命令可用且 API 格式确认
- `glab` 可连接自建 GitLab（dev.msh.team）
- 飞书多维表格 API 权限到位

## Success Criteria (Technical)

- 所有 `gh` 命令调用已替换为 `lark-cli` / `glab` 等效命令
- Frontmatter schema 已更新，所有脚本能正确读取新字段
- init.sh 能完成飞书多维表格创建和连通性验证
- 端到端：从 PRD 到 MR 合并的完整流程在示例项目上跑通

## Estimated Effort

- **Size**: L
- **Tasks**: 10
- **Parallelizable**: 部分任务可并行（文案替换层、脚本层可并行）
