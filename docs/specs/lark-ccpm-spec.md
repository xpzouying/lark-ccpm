---
name: lark-gitlab-adaptation
description: 将 CCPM 从 GitHub Issues 适配为飞书多维表格 + GitLab 的任务与代码管理后端
status: backlog
created: 2026-04-09T10:00:00Z
---

# SPEC: CCPM 飞书 + GitLab 适配

## 1. 背景与目标

### 问题

CCPM 当前硬绑定 GitHub 生态：任务管理用 GitHub Issues，代码管理用 `gh` CLI。我们团队使用飞书做协作、自建 GitLab 做代码管理，无法直接使用 CCPM。

### 目标

将 CCPM 的两个外部依赖替换：

| 原来 | 改为 |
|------|------|
| GitHub Issues（任务管理） | 飞书多维表格（通过 lark-cli） |
| GitHub PR（代码管理） | GitLab MR（通过 glab CLI） |

### 不变的部分

- CCPM 的五阶段流程（Plan → Structure → Sync → Execute → Track）不变
- 本地文件结构（`.claude/prds/`、`.claude/epics/`）不变
- PRD 编写、Epic 分解、任务执行的逻辑不变
- Superpowers 和 RalphLoop 的集成方式不变

## 2. 飞书多维表格设计

### 2.1 表结构：项目任务表

Agent 在项目初始化时通过 `lark-cli base` 自动创建此表。

| 字段名 | 字段类型 | 说明 |
|--------|----------|------|
| 标题 | 文本 | 任务标题 |
| 类型 | 单选 | `Epic` / `Task` / `Bug` |
| 状态 | 单选 | `Open` / `In Progress` / `Closed` |
| 描述 | 多行文本 | 任务详细描述（从 task md 的 body 提取） |
| 负责人 | 人员 | 指派的团队成员 |
| 所属 Epic | 关联 | 关联同表中类型为 Epic 的记录（表达父子层级） |
| 依赖任务 | 关联 | 关联同表中的前置任务记录（表达依赖关系） |
| 可并行 | 复选框 | 是否可与其他任务并行执行 |
| 冲突任务 | 关联 | 关联同表中会修改相同文件的任务 |
| GitLab MR | URL | 对应的 GitLab Merge Request 链接 |
| 本地文件 | 文本 | 对应的本地 task 文件路径，如 `.claude/epics/foo/42.md` |
| 标签 | 多选 | `epic`、`task`、`epic:<name>`、`bug` 等 |
| 进度 | 数字 | 0-100，Epic 级别自动计算 |
| 创建时间 | 日期 | 记录创建时间 |
| 更新时间 | 日期 | 最近更新时间 |

### 2.2 多维表格视图

建议创建以下视图（可在初始化时自动创建或由用户手动配置）：

- **全部任务**：默认表格视图，按 Epic 分组
- **看板视图**：按状态分列（Open / In Progress / Closed）
- **我的任务**：按负责人过滤

### 2.3 自动化流程（飞书内建）

配置多维表格自动化规则：当记录状态改为特定值时，自动创建飞书任务并指派给负责人。这一步由用户在飞书 UI 中手动配置，CCPM 不负责。SPEC 文档中提供配置指南。

## 3. 命令映射表

### 3.1 任务管理：gh → lark-cli base

| 原 CCPM 操作 | 原命令 | 新命令 |
|-------------|--------|--------|
| 创建 Epic 记录 | `gh issue create --label "epic"` | `lark-cli base record create --app <APP_TOKEN> --table <TABLE_ID> --fields '{"标题":"Epic: xxx", "类型":"Epic", "状态":"Open"}'` |
| 创建 Task 记录 | `gh issue create --label "task"` | `lark-cli base record create --app <APP_TOKEN> --table <TABLE_ID> --fields '{"标题":"xxx", "类型":"Task", "所属Epic":"<EPIC_RECORD_ID>"}'` |
| 更新状态 | `gh issue edit <N> --add-label "in-progress"` | `lark-cli base record update --app <APP_TOKEN> --table <TABLE_ID> --record <RECORD_ID> --fields '{"状态":"In Progress"}'` |
| 关闭任务 | `gh issue close <N>` | `lark-cli base record update ... --fields '{"状态":"Closed"}'` |
| 查看任务 | `gh issue view <N>` | `lark-cli base record get --app <APP_TOKEN> --table <TABLE_ID> --record <RECORD_ID>` |
| 发评论 | `gh issue comment <N> --body "..."` | 无直接对应，改为：更新记录的"描述"字段追加进度信息，或通过 lark-cli messenger 发消息到项目群 |
| 列出任务 | `gh issue list --label "epic:<name>"` | `lark-cli base record list --app <APP_TOKEN> --table <TABLE_ID> --filter '...'` |

### 3.2 代码管理：gh → glab

| 原 CCPM 操作 | 原命令 | 新命令 |
|-------------|--------|--------|
| 创建 MR | `gh pr create` | `glab mr create --title "..." --description "..."` |
| 查看 MR | `gh pr view` | `glab mr view <N>` |
| 合并 MR | `gh pr merge` | `glab mr merge <N>` |
| 仓库信息 | `gh repo view` | `glab repo view` |

### 3.3 ID 体系变化

| 概念 | 原来 | 改为 |
|------|------|------|
| 任务唯一标识 | GitHub Issue 编号（#42） | 飞书多维表格 Record ID |
| 任务关联 | `Refs: #42`、`Closes #42` | MR 描述中写飞书记录链接 |
| 依赖表达 | `depends_on: [42, 43]`（Issue 编号） | `depends_on: [rec_xxx, rec_yyy]`（Record ID） |

## 4. 文件改动清单

### 4.1 重度改造

#### `skill/ccpm/references/sync.md`

改动量最大。所有 `gh issue create/close/comment/view/edit` 替换为 `lark-cli base record` 操作 + `glab mr` 操作。

具体改动点：

- **Epic Sync 流程**：`gh issue create` → `lark-cli base record create`，返回的 record_id 作为 Epic 标识
- **Task 创建**：`gh issue create` + `gh sub-issue` → `lark-cli base record create` 并设置"所属 Epic"关联字段
- **Task 文件重命名**：原来用 Issue 编号命名（`001.md → 42.md`），改为使用 Record ID 或自增序号（Record ID 太长不适合做文件名，建议保留自增序号，在 frontmatter 中记录 Record ID）
- **Progress 同步**：`gh issue comment` → 更新多维表格记录或发飞书群消息
- **关闭 Issue**：`gh issue close` → 更新多维表格记录状态为 Closed
- **合并 Epic**：`gh issue close` → 更新 Epic 记录状态 + `glab mr merge`
- **Bug 报告**：`gh issue create --label "bug"` → 创建类型为 Bug 的多维表格记录
- **仓库安全检查**：原来检查 remote URL 是否为 `automazeio/ccpm`，改为检查是否为 lark-ccpm 模板仓库

#### `skill/ccpm/references/conventions.md`

- **Frontmatter schema**：`github:` 字段改为 `lark_record:` + `gitlab_mr:`
- **GitHub Operations 整节**：替换为 Lark Operations + GitLab Operations
- **认证检查**：`gh auth login` → `lark-cli` 认证检查 + `glab auth login`
- **Issue 编号获取**：改为从 frontmatter 中读取 `lark_record:` 字段
- **Git 约定**：worktree 和分支策略不变，push 目标改为 GitLab remote

### 4.2 中度改造

#### `skill/ccpm/references/execute.md`

- **Issue 读取**：`gh issue view <N>` → `lark-cli base record get`
- **状态更新**：`gh issue edit <N> --add-assignee --add-label` → `lark-cli base record update`
- **Agent prompt 模板**：将 "GitHub issue" 的描述改为 "飞书多维表格记录"

#### `skill/ccpm/references/scripts/init.sh`

- 检查 `lark-cli` 是否安装及认证状态（替代 `gh` 检查）
- 检查 `glab` 是否安装及认证状态
- 移除 `gh-sub-issue` 扩展检查
- GitHub label 创建 → 飞书多维表格初始化（创建表、创建字段、创建视图）
- 仓库 remote 检查改为 GitLab URL

### 4.3 轻度改造

#### `skill/ccpm/SKILL.md`

- 描述中 "GitHub Issues" → "飞书多维表格"
- "GitHub" → "GitLab"
- 触发词说明更新

#### `skill/ccpm/references/plan.md`

- 无逻辑改动，仅文案中 "push to GitHub" → "sync to Lark Base"

#### `skill/ccpm/references/structure.md`

- 无逻辑改动，仅文案中 "GitHub issue number" → "record ID"
- `depends_on` 说明更新

#### `skill/ccpm/references/track.md`

- 无逻辑改动，脚本引用不变

#### 其他脚本文件（`scripts/*.sh`）

- `epic-list.sh`、`epic-show.sh`、`epic-status.sh`：`github:` frontmatter 字段读取改为 `lark_record:` 和 `gitlab_mr:`
- `init.sh`：如上述中度改造
- 其余脚本（`blocked.sh`、`next.sh`、`status.sh` 等）：仅操作本地文件，基本不涉及外部 API，改动极小

## 5. Frontmatter Schema 变更

### Epic frontmatter（改后）

```yaml
---
name: <feature-name>
status: backlog | in-progress | completed
created: <ISO 8601>
updated: <ISO 8601>
progress: 0%
prd: .claude/prds/<name>.md
lark_record: <飞书多维表格 Record ID>
lark_app: <多维表格 App Token>
lark_table: <表 ID>
gitlab_project: <GitLab 项目路径，如 group/project>
---
```

### Task frontmatter（改后）

```yaml
---
name: <Task Title>
status: open | in-progress | closed
created: <ISO 8601>
updated: <ISO 8601>
lark_record: <飞书多维表格 Record ID>
gitlab_mr: <GitLab MR URL，执行后填入>
depends_on: []
parallel: true
conflicts_with: []
---
```

## 6. 配置管理

### 项目级配置文件：`.claude/lark-ccpm.yml`

Agent 初始化项目时创建此文件，后续操作从中读取配置，避免每次都传参。

```yaml
lark:
  app_token: <飞书多维表格 App Token>
  table_id: <任务表 Table ID>
  
gitlab:
  project: <GitLab 项目路径，如 mygroup/myproject>
  default_branch: main

notifications:
  chat_id: <飞书群聊 ID，用于发送进度通知，可选>
```

## 7. 初始化流程（init.sh 改造）

原版 init.sh 检查 gh CLI 并创建 GitHub labels。新版需要：

1. 检查 `lark-cli` 是否安装，检查认证状态
2. 检查 `glab` 是否安装，检查认证状态（`glab auth status`）
3. 创建 `.claude/` 目录结构（不变）
4. 交互式获取飞书多维表格 App Token 和 Table ID（或自动创建新表）
5. 获取 GitLab 项目路径
6. 写入 `.claude/lark-ccpm.yml`
7. 验证连通性：尝试读取多维表格、尝试访问 GitLab 项目

## 8. 进度同步策略

原版 CCPM 用 GitHub Issue Comment 同步进度。飞书多维表格没有"评论"概念，替代方案：

- **状态更新**：直接更新记录的"状态"和"进度"字段
- **详细进展**：更新记录的"描述"字段，在末尾追加进度日志
- **团队通知**（可选）：通过 `lark-cli messenger` 向项目群发送进度消息

## 9. 任务文件命名策略

原版 CCPM 在 sync 后将 `001.md` 重命名为 Issue 编号（如 `42.md`）。飞书 Record ID 格式为长字符串（如 `recXXXXXX`），不适合做文件名。

新策略：**保留自增序号作为文件名**，在 frontmatter 的 `lark_record` 字段中记录 Record ID。所有对任务的引用通过 Record ID 而非文件名。

## 10. 约束与风险

- **lark-cli 命令格式**：本 SPEC 中的 lark-cli 命令为预估格式，实际开发时需根据 `lark-cli base --help` 输出调整
- **多维表格 API 限速**：飞书 API 有调用频率限制，批量创建任务时需注意
- **Record ID 长度**：飞书 Record ID 较长，在 depends_on 数组中可读性不如 Issue 编号，可考虑使用短别名
- **离线场景**：原版 CCPM 的本地文件可离线工作，sync 时才需要网络。新版保持相同策略

## 11. 验收标准

- [ ] `lark-cli` 和 `glab` 认证检查通过
- [ ] 初始化时能自动创建飞书多维表格（或连接已有表）
- [ ] PRD → Epic → Task 拆解流程正常，任务记录同步到飞书多维表格
- [ ] 飞书多维表格中能看到 Epic/Task 层级关系和依赖关系
- [ ] 团队成员通过飞书能看到任务状态和进度
- [ ] 代码通过 glab 提交 MR 到 GitLab
- [ ] MR 链接自动回写到飞书多维表格记录
- [ ] Track 阶段的所有脚本正常工作（status、standup、next、blocked 等）
- [ ] 整套流程在一个示例项目上端到端跑通
