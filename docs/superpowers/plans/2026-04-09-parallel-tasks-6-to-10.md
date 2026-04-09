# Parallel Tasks #6-#10 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete 5 independent text/script adaptations to replace all remaining GitHub references with Feishu Base + GitLab equivalents across the CCPM skill.

**Architecture:** Each Issue maps to a separate worktree and agent. All changes are text replacements in prompt reference files or shell scripts — no logic changes, only terminology and command substitutions. The verified CLI format from smoke testing applies: `lark-cli base +record-*` with `--base-token`/`--table-id`/`--record-id` flags.

**Tech Stack:** Markdown (prompt references), Bash (scripts), lark-cli, glab

---

## File Map

| Issue | Files | Change Type |
|-------|-------|-------------|
| #6 | `skill/ccpm/references/execute.md` | Command replacement + terminology |
| #7 | `skill/ccpm/SKILL.md`, `skill/ccpm/references/plan.md` | Terminology only |
| #8 | `skill/ccpm/references/structure.md`, `skill/ccpm/references/track.md` | Terminology only |
| #9 | `skill/ccpm/references/scripts/epic-list.sh`, `epic-show.sh`, `epic-status.sh` | Frontmatter field name replacement |
| #10 | `docs/guides/feishu-base-setup.md` (new) | New documentation |

---

## Issue #6: Rewrite execute.md (Task 005)

**Files:**
- Modify: `skill/ccpm/references/execute.md` (213 lines)

### Task 1: Replace Issue Analysis section

- [ ] **Step 1: Update the file header and Issue Analysis preflight**

In `skill/ccpm/references/execute.md`, replace lines 1-13:

Old:
```markdown
# Execute — Start Building with Parallel Agents

This phase covers analyzing GitHub issues for parallel work streams and launching agents to execute them.

---

## Issue Analysis

**Trigger**: User wants to understand how to parallelize work on an issue before starting.

### Preflight
- Find the local task file: check `.claude/epics/*/<N>.md` first, then search for `github:.*issues/<N>` in frontmatter.
- If not found: "❌ No local task for issue #<N>. Run a sync first."
```

New:
```markdown
# Execute — Start Building with Parallel Agents

This phase covers analyzing tasks for parallel work streams and launching agents to execute them.

---

## Task Analysis

**Trigger**: User wants to understand how to parallelize work on a task before starting.

### Preflight
- Find the local task file: check `.claude/epics/*/<N>.md` first, then search for `lark_record:` in frontmatter.
- If not found: "❌ No local task file for task <N>. Run a sync first."
```

- [ ] **Step 2: Replace `gh issue view` command**

Replace line 17:

Old:
```
Get issue details: `gh issue view <N> --json title,body,labels`
```

New:
```
Get task details from Lark Base:
```bash
RECORD_ID=$(grep 'lark_record:' .claude/epics/*/<N>.md | awk '{print $2}')
APP_TOKEN=$(grep 'app_token:' .claude/lark-ccpm.yml | awk '{print $2}')
TABLE_ID=$(grep 'table_id:' .claude/lark-ccpm.yml | awk '{print $2}')
lark-cli base +record-get --base-token "$APP_TOKEN" --table-id "$TABLE_ID" --record-id "$RECORD_ID"
```
```

- [ ] **Step 3: Update analysis file frontmatter template**

Replace the `issue: <N>` field in the analysis template (lines 36-40):

Old:
```yaml
issue: <N>
title: <title>
```

New:
```yaml
task: <N>
title: <title>
lark_record: <Record ID>
```

- [ ] **Step 4: Update "Parallel Work Analysis" heading**

Replace line 46:

Old: `# Parallel Work Analysis: Issue #<N>`
New: `# Parallel Work Analysis: Task <N>`

- [ ] **Step 5: Update output message**

Replace line 75:

Old: `**Output**: "✅ Analysis complete for issue #<N> — N parallel streams identified. Ready to start? Say: start issue <N>"`
New: `**Output**: "✅ Analysis complete for task <N> — N parallel streams identified. Ready to start? Say: start task <N>"`

### Task 2: Replace Starting an Issue section

- [ ] **Step 1: Update section heading and preflight**

Replace lines 79-88:

Old:
```markdown
## Starting an Issue

**Trigger**: User wants to begin work on a specific GitHub issue.

### Preflight
1. Verify issue exists and is open: `gh issue view <N> --json state,title,labels,body`
2. Find local task file (as above).
3. Check for analysis file: `.claude/epics/*/<N>-analysis.md` — if missing, run analysis first (or do both in sequence: analyze then start).
4. Verify epic worktree exists: `git worktree list | grep "epic-<name>"` — if not: "❌ No worktree. Sync the epic first."
```

New:
```markdown
## Starting a Task

**Trigger**: User wants to begin work on a specific task.

### Preflight
1. Find local task file and verify `lark_record:` exists in frontmatter. If no record: "❌ Task not synced. Sync the epic first."
2. Read Lark Base record to verify status is Open:
   ```bash
   lark-cli base +record-get --base-token "$APP_TOKEN" --table-id "$TABLE_ID" --record-id "$RECORD_ID"
   ```
3. Check for analysis file: `.claude/epics/*/<N>-analysis.md` — if missing, run analysis first.
4. Verify epic worktree exists: `git worktree list | grep "epic-<name>"` — if not: "❌ No worktree. Sync the epic first."
```

- [ ] **Step 2: Update agent prompt template**

Replace the agent prompt (lines 114-135), specifically these references:

Old:
```
    You are working on Issue #<N> in the epic worktree at: ../epic-<name>/
    ...
    1. Read full task from: .claude/epics/<epic>/<N>.md
    ...
    4. Commit frequently: "Issue #<N>: <specific change>"
    5. Update progress in: .claude/epics/<epic>/updates/<N>/stream-<X>.md
```

New:
```
    You are working on Task <N> in the epic worktree at: ../epic-<name>/
    ...
    1. Read full task from: .claude/epics/<epic>/<N>.md
    ...
    4. Commit frequently: "Task #<N>: <specific change>"
    5. Update progress in: .claude/epics/<epic>/updates/<N>/stream-<X>.md
```

- [ ] **Step 3: Replace GitHub assignment with Lark Base status update**

Replace lines 139-142:

Old:
```markdown
**Step 4 — Assign on GitHub:**
```bash
gh issue edit <N> --add-assignee @me --add-label "in-progress"
```
```

New:
```markdown
**Step 4 — Update status in Lark Base:**
```bash
lark-cli base +record-upsert --base-token "$APP_TOKEN" --table-id "$TABLE_ID" \
  --record-id "$RECORD_ID" --json '{"状态":"In Progress"}'
```
```

- [ ] **Step 4: Update output messages**

Replace lines 157-168, changing all "issue #<N>" to "task <N>":

Old: `✅ Started work on issue #<N>`
New: `✅ Started work on task <N>`

Old: `Sync updates: "sync issue <N>"`
New: `Sync updates: "sync task <N>"`

### Task 3: Replace Starting a Full Epic section

- [ ] **Step 1: Update preflight**

Replace line 177:

Old: `- Verify `.claude/epics/<name>/epic.md` exists and has a `github:` field (i.e., it's been synced).`
New: `- Verify `.claude/epics/<name>/epic.md` exists and has a `lark_record:` field (i.e., it's been synced).`

- [ ] **Step 2: Update Agent Coordination Rules**

Replace line 207:

Old: `- Agents commit frequently with `Issue #<N>: <description>` format.`
New: `- Agents commit frequently with `Task #<N>: <description>` format.`

### Task 4: Final verification and commit

- [ ] **Step 1: Verify no gh/github references remain**

Run:
```bash
grep -n 'gh \|github\|GitHub' skill/ccpm/references/execute.md
```
Expected: 0 matches

- [ ] **Step 2: Verify "Issue" → "Task" replacements**

Run:
```bash
grep -c 'Issue #' skill/ccpm/references/execute.md
```
Expected: 0 (all replaced with "Task")

- [ ] **Step 3: Commit**

```bash
git add skill/ccpm/references/execute.md
git commit -m "Issue #6: rewrite execute.md for Lark Base task management"
```

---

## Issue #7: Update SKILL.md and plan.md terminology (Task 006)

**Files:**
- Modify: `skill/ccpm/SKILL.md` (83 lines)
- Modify: `skill/ccpm/references/plan.md` (107 lines)

### Task 1: Update SKILL.md

- [ ] **Step 1: Update frontmatter description**

In `skill/ccpm/SKILL.md`, replace the `description` field in the frontmatter (line 3). This is one long line.

Old (partial): `...PRD → Epic → GitHub Issues → parallel agents → shipped code. Use this skill for anything in the software delivery lifecycle...syncing to GitHub ('sync the X epic', 'push tasks to github')...closing issues, or merging an epic...`

New: Replace all occurrences in this line:
- `GitHub Issues` → `Lark Base records`
- `push tasks to github` → `push tasks to Lark Base`
- `syncing to GitHub` → `syncing to Lark Base`
- `closing issues` → `closing tasks`

- [ ] **Step 2: Update line 8 (main tagline)**

Old: `A spec-driven development workflow: PRD → Epic → GitHub Issues → Parallel Agents → Shipped Code.`
New: `A spec-driven development workflow: PRD → Epic → Lark Base Records → Parallel Agents → Shipped Code.`

- [ ] **Step 3: Update line 10 (Core Philosophy)**

Old: `Requirements live in files, not heads. Every feature starts as a PRD, becomes a technical epic, decomposes into GitHub issues, and gets executed by parallel agents with full traceability.`
New: `Requirements live in files, not heads. Every feature starts as a PRD, becomes a technical epic, decomposes into Lark Base task records, and gets executed by parallel agents with full traceability.`

- [ ] **Step 4: Update Phase 3 description (lines 30-33)**

Old:
```
### 3. Sync — Push to GitHub
**When**: Local epic/tasks need to become GitHub issues, progress needs to be posted as comments, or a bug is found and needs a linked issue created.
**Read**: `references/sync.md`
**Covers**: Epic sync (epic + tasks → GitHub issues), issue sync (progress comments), closing issues/epics, bug reporting against completed issues.
```

New:
```
### 3. Sync — Push to Lark Base
**When**: Local epic/tasks need to become Lark Base records, progress needs syncing, or a bug is found and needs a linked record created.
**Read**: `references/sync.md`
**Covers**: Epic sync (epic + tasks → Lark Base records), progress sync, closing tasks/epics, bug reporting against completed tasks.
```

- [ ] **Step 5: Update Phase 4 description (lines 35-38)**

Old:
```
### 4. Execute — Start building
**When**: User wants to start working on one or more GitHub issues with parallel agents.
**Read**: `references/execute.md`
**Covers**: Issue analysis (parallel work stream identification), launching parallel agents, coordinating worktrees.
```

New:
```
### 4. Execute — Start building
**When**: User wants to start working on one or more tasks with parallel agents.
**Read**: `references/execute.md`
**Covers**: Task analysis (parallel work stream identification), launching parallel agents, coordinating worktrees.
```

- [ ] **Step 6: Update Quick Reference (lines 72-82)**

Replace these lines:

Old:
```
Sync to GitHub:     "push the X epic to GitHub"
Start an issue:     "start working on issue 42"
...
Merge epic:         "merge the X epic"
Report a bug:       "found a bug in issue 42" / "testing issue 42 revealed X"
```

New:
```
Sync to Lark Base:  "push the X epic to Lark Base"
Start a task:       "start working on task 001"
...
Merge epic:         "merge the X epic"
Report a bug:       "found a bug in task 003" / "testing task 003 revealed X"
```

### Task 2: Update plan.md

- [ ] **Step 1: Update epic frontmatter template**

In `skill/ccpm/references/plan.md`, replace the epic frontmatter template (lines 76-78):

Old:
```yaml
github: (will be set on sync)
```

New:
```yaml
lark_record: (will be set on sync)
lark_app: (will be set on sync)
lark_table: (will be set on sync)
gitlab_mr: (will be set after MR creation)
```

- [ ] **Step 2: Update after-creation message**

Replace line 100:

Old: `**After creation**: Confirm "✅ Epic created: `.claude/epics/<name>/epic.md`" and suggest: "Ready to decompose into tasks? Say: decompose the <name> epic"`

This line stays the same — no GitHub reference here. Skip.

- [ ] **Step 3: Verify and commit**

Run:
```bash
grep -n 'github\|GitHub\|gh ' skill/ccpm/SKILL.md skill/ccpm/references/plan.md
```
Expected: 0 matches

```bash
git add skill/ccpm/SKILL.md skill/ccpm/references/plan.md
git commit -m "Issue #7: update SKILL.md and plan.md terminology for Lark Base + GitLab"
```

---

## Issue #8: Update structure.md and track.md terminology (Task 007)

**Files:**
- Modify: `skill/ccpm/references/structure.md` (107 lines)
- Modify: `skill/ccpm/references/track.md` (164 lines)

### Task 1: Update structure.md

- [ ] **Step 1: Update task file frontmatter template**

In `skill/ccpm/references/structure.md`, replace the task frontmatter template (lines 53-55):

Old:
```yaml
github: (will be set on sync)
depends_on: []
```

New:
```yaml
lark_record: (will be set on sync)
gitlab_mr: (will be set after MR creation)
depends_on: []
```

- [ ] **Step 2: Update numbering note**

Replace line 81:

Old: `**Numbering**: sequential 001.md, 002.md, etc. Tasks are renamed to GitHub issue numbers after sync — do not hard-code dependencies by filename, use the `depends_on` array.`

New: `**Numbering**: sequential 001.md, 002.md, etc. Task files are never renamed — the Lark Base Record ID is stored in the `lark_record` frontmatter field. Use `depends_on` for dependency references.`

- [ ] **Step 3: Update after-completion message**

Replace line 98:

Old: `**After completion**: Confirm "✅ Created N tasks for epic: <name>" and suggest: "Ready to push to GitHub? Say: sync the <name> epic"`

New: `**After completion**: Confirm "✅ Created N tasks for epic: <name>" and suggest: "Ready to sync to Lark Base? Say: sync the <name> epic"`

### Task 2: Update track.md

- [ ] **Step 1: Update validate description**

Replace line 152:

Old: `Checks: frontmatter consistency, orphaned files, missing GitHub links, dependency integrity.`

New: `Checks: frontmatter consistency, orphaned files, missing Lark record links, dependency integrity.`

- [ ] **Step 2: Verify and commit**

Run:
```bash
grep -n 'github\|GitHub\|gh ' skill/ccpm/references/structure.md skill/ccpm/references/track.md
```
Expected: 0 matches

```bash
git add skill/ccpm/references/structure.md skill/ccpm/references/track.md
git commit -m "Issue #8: update structure.md and track.md terminology for Lark Base"
```

---

## Issue #9: Update epic-*.sh scripts (Task 008)

**Files:**
- Modify: `skill/ccpm/references/scripts/epic-list.sh:27`
- Modify: `skill/ccpm/references/scripts/epic-show.sh:36,42,88,89`
- Modify: `skill/ccpm/references/scripts/epic-status.sh:40,86,87`

### Task 1: Update epic-list.sh

- [ ] **Step 1: Replace github field read**

In `skill/ccpm/references/scripts/epic-list.sh`, replace line 27:

Old:
```bash
  g=$(grep "^github:" "$dir/epic.md" | head -1 | sed 's/^github: *//')
```

New:
```bash
  g=$(grep "^lark_record:" "$dir/epic.md" | head -1 | sed 's/^lark_record: *//')
```

Also find where `g` is displayed (should show record ID instead of issue number). Find the line that extracts the issue number and displays `(#$i)` — update it to display `($g)` or `[record: $g]`.

### Task 2: Update epic-show.sh

- [ ] **Step 1: Replace field reads and display**

In `skill/ccpm/references/scripts/epic-show.sh`:

Replace line 36:
Old: `github=$(grep "^github:" "$epic_file" | head -1 | sed 's/^github: *//')`
New: `lark_record=$(grep "^lark_record:" "$epic_file" | head -1 | sed 's/^lark_record: *//')`

Replace line 42:
Old: `[ -n "$github" ] && echo "  GitHub: $github"`
New: `[ -n "$lark_record" ] && echo "  Lark Record: $lark_record"`

Replace line 88:
Old: `[ -z "$github" ] && [ $task_count -gt 0 ] && echo "  • Sync to GitHub: /pm:epic-sync $epic_name"`
New: `[ -z "$lark_record" ] && [ $task_count -gt 0 ] && echo "  • Sync to Lark Base: /pm:epic-sync $epic_name"`

Replace line 89:
Old: `[ -n "$github" ] && [ "$status" != "completed" ] && echo "  • Start work: /pm:epic-start $epic_name"`
New: `[ -n "$lark_record" ] && [ "$status" != "completed" ] && echo "  • Start work: /pm:epic-start $epic_name"`

### Task 3: Update epic-status.sh

- [ ] **Step 1: Replace field reads and display**

In `skill/ccpm/references/scripts/epic-status.sh`:

Replace line 40:
Old: `  github=$(grep "^github:" "$epic_file" | head -1 | sed 's/^github: *//')`
New: `  lark_record=$(grep "^lark_record:" "$epic_file" | head -1 | sed 's/^lark_record: *//')`

Replace lines 86-87:
Old:
```bash
  [ -n "$github" ] && echo ""
  [ -n "$github" ] && echo "🔗 GitHub: $github"
```
New:
```bash
  [ -n "$lark_record" ] && echo ""
  [ -n "$lark_record" ] && echo "🔗 Lark Record: $lark_record"
```

### Task 4: Verify and commit

- [ ] **Step 1: Verify no github references remain in any script**

Run:
```bash
grep -rn 'github\|GitHub' skill/ccpm/references/scripts/epic-list.sh skill/ccpm/references/scripts/epic-show.sh skill/ccpm/references/scripts/epic-status.sh
```
Expected: 0 matches

- [ ] **Step 2: Verify scripts still parse**

Run:
```bash
bash -n skill/ccpm/references/scripts/epic-list.sh
bash -n skill/ccpm/references/scripts/epic-show.sh
bash -n skill/ccpm/references/scripts/epic-status.sh
```
Expected: no output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add skill/ccpm/references/scripts/epic-list.sh skill/ccpm/references/scripts/epic-show.sh skill/ccpm/references/scripts/epic-status.sh
git commit -m "Issue #9: update epic-*.sh scripts to read lark_record instead of github field"
```

---

## Issue #10: Feishu Base setup guide (Task 009)

**Files:**
- Create: `docs/guides/feishu-base-setup.md`

### Task 1: Write the setup guide

- [ ] **Step 1: Create the guide document**

Create `docs/guides/feishu-base-setup.md`:

```markdown
# 飞书多维表格配置指南

本指南说明 CCPM 项目任务表的字段结构和推荐视图配置。

## 字段说明

init.sh 自动创建以下字段：

| 字段名 | 类型 | 说明 |
|--------|------|------|
| 标题 | text | 任务标题，如 "Epic: feature-name" 或 "Task: 具体任务" |
| 描述 | text | 任务详细描述，从 task md 的 body 提取 |
| 类型 | select | `Epic` / `Task` / `Bug` |
| 状态 | select | `Open` / `In Progress` / `Closed` |
| 进度 | number (progress) | 0-100%，Epic 级别根据子任务自动计算 |
| 可并行 | checkbox | 是否可与其他任务并行执行 |
| 标签 | select (multi) | `epic`、`task`、`bug`、`epic:<name>` 等 |
| 本地文件 | text | 对应的本地 task 文件路径，如 `.claude/epics/foo/001.md` |
| GitLab MR | text (url) | 对应的 GitLab Merge Request 链接 |
| 所属 Epic | link (self) | 关联同表中类型为 Epic 的记录（表达父子层级） |
| 依赖任务 | link (self) | 关联同表中的前置任务记录（表达依赖关系） |
| 冲突任务 | link (self) | 关联同表中会修改相同文件的任务 |
| 负责人 | user | 指派的团队成员 |
| 创建时间 | created_at | 记录创建时间（系统自动） |
| 更新时间 | updated_at | 最近更新时间（系统自动） |

## 推荐视图配置

在飞书多维表格 UI 中手动创建以下视图：

### 1. 看板视图（按状态）

1. 点击 "+" 创建新视图 → 选择 **看板**
2. 分组字段选择 **状态**
3. 列顺序：Open → In Progress → Closed
4. 卡片显示字段：标题、类型、负责人、进度

适合日常跟踪任务流转。

### 2. 全部任务（按 Epic 分组）

1. 点击 "+" 创建新视图 → 选择 **表格**
2. 分组字段选择 **所属 Epic**
3. 排序：状态（Open 优先）→ 创建时间
4. 筛选：类型 = Task 或 Bug

适合查看某个 Epic 下的所有任务。

### 3. 我的任务

1. 点击 "+" 创建新视图 → 选择 **表格**
2. 筛选条件：负责人 = 当前用户
3. 排序：状态（In Progress 优先）→ 创建时间

适合个人工作台。

## 自动化规则配置（可选）

在多维表格的"自动化"功能中配置：

### 规则 1：状态变更通知

- **触发条件**：当记录的"状态"字段变为 "In Progress"
- **执行动作**：向"负责人"发送飞书通知
- **通知内容**：`任务 {{标题}} 已开始，请关注进度`

### 规则 2：Epic 完成提醒

- **触发条件**：当记录的"状态"字段变为 "Closed" 且 "类型" = "Epic"
- **执行动作**：向项目群发送消息
- **通知内容**：`🎉 Epic {{标题}} 已完成！`

### 规则 3：新任务分配通知

- **触发条件**：当记录的"负责人"字段被修改
- **执行动作**：向新负责人发送飞书通知
- **通知内容**：`你被指派了新任务：{{标题}}`

> 注意：以上自动化规则需要在飞书多维表格 UI 中手动配置，CCPM 不会自动创建。
```

- [ ] **Step 2: Commit**

```bash
mkdir -p docs/guides
git add docs/guides/feishu-base-setup.md
git commit -m "Issue #10: add Feishu Base field and view setup guide"
```

---

## Spec Coverage Checklist

| Issue | Acceptance Criteria | Covered |
|-------|-------------------|---------|
| #6 | `gh issue view` → `lark-cli base +record-get` | Task 1 Step 2 |
| #6 | `gh issue edit` → `lark-cli base +record-upsert` | Task 2 Step 3 |
| #6 | "GitHub issue" → "飞书多维表格记录" in prompts | Task 2 Step 2 |
| #6 | Read `lark_record` from frontmatter | Task 1 Step 1, Task 2 Step 1 |
| #7 | SKILL.md: "GitHub Issues" → "飞书多维表格" | Task 1 Steps 1-6 |
| #7 | SKILL.md: trigger descriptions updated | Task 1 Steps 4-6 |
| #7 | plan.md: "push to GitHub" → "sync to Lark Base" | Task 2 Step 1 |
| #8 | structure.md: "GitHub issue number" → "record ID" | Task 1 Steps 1-3 |
| #8 | structure.md: `depends_on` updated | Task 1 Step 2 |
| #8 | track.md: text updates | Task 2 Step 1 |
| #9 | epic-list.sh: `github:` → `lark_record:` | Task 1 |
| #9 | epic-show.sh: `github:` → `lark_record:` + display | Task 2 |
| #9 | epic-status.sh: `github:` → `lark_record:` + display | Task 3 |
| #10 | Field types and purpose docs | Task 1 |
| #10 | Kanban view guide | Task 1 |
| #10 | "My tasks" filter guide | Task 1 |
| #10 | Automation rules guide | Task 1 |
