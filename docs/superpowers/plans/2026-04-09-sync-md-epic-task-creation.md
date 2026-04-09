# Rewrite sync.md: Epic Sync + Task Creation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `skill/ccpm/references/sync.md` to replace all GitHub CLI operations with Feishu Base (`lark-cli base`) + GitLab (`glab`) equivalents, covering: repository safety check, epic sync, task creation, progress sync, issue closing, epic merging, and bug reporting.

**Architecture:** The file is a prompt reference document (not executable code) that guides the CCPM agent through sync operations. Each section maps to a user-triggered workflow. We replace `gh` commands with `lark-cli base +record-*` and `glab mr` commands, update ID references from GitHub issue numbers to Lark Record IDs, and remove file-rename logic (task files keep sequential numbers).

**Tech Stack:** lark-cli base (`+record-upsert`, `+record-get`, `+record-list`), glab CLI, bash, jq

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `skill/ccpm/references/sync.md` | **Rewrite** | All sync operations: push to Lark Base, track progress, close tasks, merge epics, report bugs |

Single file rewrite. The current file is 297 lines across 6 sections.

## CLI Command Reference (verified via smoke test 2026-04-09)

```bash
# Create record (no --record-id = create new, NO "fields" wrapper)
result=$(lark-cli base +record-upsert --base-token "$APP_TOKEN" --table-id "$TABLE_ID" \
  --json '{"标题":"xxx","类型":"Epic","状态":"Open"}')
record_id=$(echo "$result" | jq -r '.data.record.record_id_list[0]')

# Update record (with --record-id)
lark-cli base +record-upsert --base-token "$APP_TOKEN" --table-id "$TABLE_ID" \
  --record-id "$RECORD_ID" --json '{"状态":"In Progress"}'

# Get record (fields at .data.record.字段名)
lark-cli base +record-get --base-token "$APP_TOKEN" --table-id "$TABLE_ID" \
  --record-id "$RECORD_ID"

# List records (record IDs at .data.record_id_list[])
lark-cli base +record-list --base-token "$APP_TOKEN" --table-id "$TABLE_ID"

# Link fields (所属 Epic / 依赖任务 / 冲突任务) use array of {id}:
--json '{"所属 Epic":[{"id":"rec_xxx"}],"依赖任务":[{"id":"rec_yyy"}]}'
```

### Key format rules (from smoke test)
- `--json` 顶层直接传字段映射，**不要** `{"fields":{...}}` 包裹
- record_id 提取路径：`.data.record.record_id_list[0]`
- select 字段写入用字符串：`"类型":"Epic"`
- checkbox 字段写入用布尔：`"可并行":true`
- link 字段写入用对象数组：`"所属 Epic":[{"id":"rec_xxx"}]`

---

### Task 1: Rewrite header, config loading, and repository safety check

**Files:**
- Modify: `skill/ccpm/references/sync.md:1-19`

- [ ] **Step 1: Replace the file header and safety check**

Replace the entire content of `skill/ccpm/references/sync.md` with the following (this is the first section — subsequent tasks append to this):

```markdown
# Sync — Push to Lark Base & Track Progress

This phase covers pushing local epics/tasks to Feishu Base (飞书多维表格) as records, syncing progress, and closing tasks when work is done. Code operations use GitLab via `glab`.

---

## Load Project Config

**Always load config before any sync operation:**

```bash
APP_TOKEN=$(grep 'app_token:' .claude/lark-ccpm.yml | awk '{print $2}')
TABLE_ID=$(grep 'table_id:' .claude/lark-ccpm.yml | awk '{print $2}')
GITLAB_PROJECT=$(grep 'project:' .claude/lark-ccpm.yml | awk '{print $2}')

if [ -z "$APP_TOKEN" ] || [ -z "$TABLE_ID" ]; then
  echo "❌ Missing Lark config. Run init first to create .claude/lark-ccpm.yml"
  exit 1
fi
```

---

## Repository Safety Check

**Always run this before any write operation:**

```bash
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"lark-ccpm"* ]] && [[ "$remote_url" == *"xpzouying"* ]]; then
  echo "❌ Cannot sync from the lark-ccpm template repository."
  echo "Update remote: git remote set-url origin git@dev.msh.team:YOUR_GROUP/YOUR_PROJECT.git"
  exit 1
fi
```

---
```

- [ ] **Step 2: Verify the file is valid markdown**

Run:
```bash
wc -l skill/ccpm/references/sync.md
head -5 skill/ccpm/references/sync.md
```
Expected: ~35 lines, first line is `# Sync — Push to Lark Base & Track Progress`

- [ ] **Step 3: Commit**

```bash
git add skill/ccpm/references/sync.md
git commit -m "Issue #4: rewrite sync.md header, config loading, and safety check"
```

---

### Task 2: Rewrite Epic Sync section

This is the core section — pushing a local epic and its tasks to Feishu Base as records.

**Files:**
- Modify: `skill/ccpm/references/sync.md` (append after safety check)

- [ ] **Step 1: Append the Epic Sync section**

Append after the `---` at the end of the safety check:

```markdown

## Epic Sync — Push Epic + Tasks to Lark Base

**Trigger**: User wants to push a local epic and its tasks to Feishu Base as records.

### Preflight
- Verify `.claude/epics/<name>/epic.md` exists.
- Verify numbered task files exist — if none: "❌ No tasks to sync. Decompose the epic first."
- Load config: `APP_TOKEN`, `TABLE_ID` from `.claude/lark-ccpm.yml`.

### Process

**Step 1 — Create epic record in Lark Base:**

Strip frontmatter from epic.md to get the description body:
```bash
description=$(sed '1,/^---$/d; 1,/^---$/d' .claude/epics/<name>/epic.md)
```

Create the record:
```bash
epic_result=$(lark-cli base +record-upsert \
  --base-token "$APP_TOKEN" --table-id "$TABLE_ID" \
  --json "{\"标题\":\"Epic: <name>\",\"类型\":\"Epic\",\"状态\":\"Open\",\"描述\":$(echo "$description" | jq -Rs .),\"本地文件\":\".claude/epics/<name>/epic.md\",\"标签\":[\"epic\",\"epic:<name>\"],\"可并行\":false,\"进度\":0}")
epic_record_id=$(echo "$epic_result" | jq -r '.data.record.record_id_list[0]')
```

If `epic_record_id` is empty, print the error and exit.

**Step 2 — Update epic frontmatter with record ID:**
```bash
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
sed -i.bak "/^lark_record:/c\\lark_record: $epic_record_id" .claude/epics/<name>/epic.md
sed -i.bak "/^lark_app:/c\\lark_app: $APP_TOKEN" .claude/epics/<name>/epic.md
sed -i.bak "/^lark_table:/c\\lark_table: $TABLE_ID" .claude/epics/<name>/epic.md
sed -i.bak "/^updated:/c\\updated: $current_date" .claude/epics/<name>/epic.md
rm .claude/epics/<name>/epic.md.bak
```

**Step 3 — Create task records:**

For <5 tasks: create sequentially.
For ≥5 tasks: use parallel Task agents (3-4 tasks per batch).

Per task file (e.g., `001.md`):
```bash
task_name=$(grep '^name:' .claude/epics/<name>/001.md | sed 's/^name: *//')
task_desc=$(sed '1,/^---$/d; 1,/^---$/d' .claude/epics/<name>/001.md)
task_parallel=$(grep '^parallel:' .claude/epics/<name>/001.md | awk '{print $2}')

task_result=$(lark-cli base +record-upsert \
  --base-token "$APP_TOKEN" --table-id "$TABLE_ID" \
  --json "{\"标题\":\"$task_name\",\"类型\":\"Task\",\"状态\":\"Open\",\"描述\":$(echo "$task_desc" | jq -Rs .),\"本地文件\":\".claude/epics/<name>/001.md\",\"标签\":[\"task\",\"epic:<name>\"],\"所属 Epic\":[{\"id\":\"$epic_record_id\"}],\"可并行\":$task_parallel,\"进度\":0}")
task_record_id=$(echo "$task_result" | jq -r '.data.record.record_id_list[0]')
```

**Step 4 — Update task frontmatter (do NOT rename files):**

Task files keep their sequential names (`001.md`, `002.md`). Record ID goes into frontmatter:
```bash
sed -i.bak "/^lark_record:/c\\lark_record: $task_record_id" .claude/epics/<name>/001.md
sed -i.bak "/^updated:/c\\updated: $current_date" .claude/epics/<name>/001.md
rm .claude/epics/<name>/001.md.bak
```

**Step 5 — Sync dependency and conflict links to Lark Base:**

After all tasks have record IDs, update both local frontmatter AND Lark Base records:
```bash
# Build mapping: sequential_number → record_id
declare -A id_map
for f in .claude/epics/<name>/[0-9]*.md; do
  num=$(basename "$f" .md)
  rid=$(grep 'lark_record:' "$f" | awk '{print $2}')
  id_map[$num]=$rid
done

# For each task file:
# 1. Replace depends_on values in frontmatter: [001, 002] → [recXXX, recYYY]
# 2. Update Lark Base record with link fields
for f in .claude/epics/<name>/[0-9]*.md; do
  rid=$(grep 'lark_record:' "$f" | awk '{print $2}')
  
  # Build depends_on link array for Lark Base
  deps_json="[]"
  deps=$(grep 'depends_on:' "$f" | sed 's/depends_on: *\[//;s/\]//')
  if [ -n "$deps" ]; then
    deps_json=$(echo "$deps" | tr ',' '\n' | while read d; do
      d=$(echo "$d" | xargs)  # trim
      echo "{\"id\":\"${id_map[$d]}\"}"
    done | jq -s '.')
  fi
  
  # Build conflicts_with link array
  conflicts_json="[]"
  conflicts=$(grep 'conflicts_with:' "$f" | sed 's/conflicts_with: *\[//;s/\]//')
  if [ -n "$conflicts" ]; then
    conflicts_json=$(echo "$conflicts" | tr ',' '\n' | while read c; do
      c=$(echo "$c" | xargs)
      echo "{\"id\":\"${id_map[$c]}\"}"
    done | jq -s '.')
  fi
  
  # Update Lark Base record with dependency links
  lark-cli base +record-upsert --base-token "$APP_TOKEN" --table-id "$TABLE_ID" \
    --record-id "$rid" \
    --json "{\"依赖任务\":$deps_json,\"冲突任务\":$conflicts_json}"
done
```

**Step 6 — Create worktree for the epic:**
```bash
git checkout main && git pull origin main
git worktree add ../epic-<name> -b epic/<name>
```

**Output:**
```
✅ Synced epic <name> to Lark Base
  Epic record: <epic_record_id>
  Tasks: N records created
  Worktree: ../epic-<name>
  Next: "start working on task 001" or "start the <name> epic"
```

---
```

- [ ] **Step 2: Verify line count**

Run:
```bash
wc -l skill/ccpm/references/sync.md
```
Expected: ~130-140 lines

- [ ] **Step 3: Commit**

```bash
git add skill/ccpm/references/sync.md
git commit -m "Issue #4: rewrite Epic Sync section for Lark Base"
```

---

### Task 3: Rewrite Progress Sync section

**Files:**
- Modify: `skill/ccpm/references/sync.md` (append)

- [ ] **Step 1: Append the Progress Sync section**

Append after the Epic Sync `---`:

```markdown

## Progress Sync — Update Task Status in Lark Base

**Trigger**: User wants to sync local development progress to a Lark Base record.

### Preflight
- Verify task file exists and has `lark_record:` in frontmatter.
- Get record ID: `RECORD_ID=$(grep 'lark_record:' <task_file> | awk '{print $2}')`
- If no record ID: "❌ Task not synced. Run epic sync first."
- Check `.claude/epics/*/updates/<N>/` exists with a `progress.md` file.
- Check `last_sync` in progress.md — if synced <5 minutes ago, confirm before proceeding.

### Process

Gather updates from `.claude/epics/<epic>/updates/<N>/` (progress.md, notes.md, commits.md).

Format as a progress update and append to the record's description field:
```bash
existing=$(lark-cli base +record-get \
  --base-token "$APP_TOKEN" --table-id "$TABLE_ID" \
  --record-id "$RECORD_ID" | jq -r '.record.fields.描述 // ""')

progress_text="
---
## 🔄 Progress Update — $(date -u +%Y-%m-%d)

### ✅ Completed Work
### 🔄 In Progress
### 📝 Technical Notes
### 📊 Acceptance Criteria Status
### 🚀 Next Steps
### ⚠️ Blockers

*Progress: N% | Synced at $(date -u +"%Y-%m-%dT%H:%M:%SZ")*
"

# Append progress to description
new_desc="${existing}${progress_text}"
lark-cli base +record-upsert \
  --base-token "$APP_TOKEN" --table-id "$TABLE_ID" \
  --record-id "$RECORD_ID" \
  --json "{\"fields\":{\"描述\":$(echo "$new_desc" | jq -Rs .),\"进度\":$completion_pct}}"
```

Optionally, send a notification to the project chat:
```bash
CHAT_ID=$(grep 'chat_id:' .claude/lark-ccpm.yml | awk '{print $2}')
if [ -n "$CHAT_ID" ]; then
  lark-cli im +send --chat-id "$CHAT_ID" \
    --text "📊 Task update: <task_name> — ${completion_pct}% complete"
fi
```

After posting: update `last_sync` in progress.md frontmatter, update `updated` in the task file.

---
```

- [ ] **Step 2: Commit**

```bash
git add skill/ccpm/references/sync.md
git commit -m "Issue #4: rewrite Progress Sync section for Lark Base"
```

---

### Task 4: Rewrite Closing an Issue section

**Files:**
- Modify: `skill/ccpm/references/sync.md` (append)

- [ ] **Step 1: Append the Closing section**

Append after the Progress Sync `---`:

```markdown

## Closing a Task

**Trigger**: User marks a task complete.

### Process

1. Find the local task file (`.claude/epics/*/<N>.md`).
2. Get record ID: `RECORD_ID=$(grep 'lark_record:' <task_file> | awk '{print $2}')`
3. Update frontmatter: `status: closed`, `updated: <now>`.
4. Update Lark Base record:
```bash
lark-cli base +record-upsert \
  --base-token "$APP_TOKEN" --table-id "$TABLE_ID" \
  --record-id "$RECORD_ID" \
  --json '{"状态":"Closed","进度":100}'
```
5. Recalculate and update epic progress:
```bash
total=$(ls .claude/epics/<name>/[0-9]*.md 2>/dev/null | wc -l)
closed=$(grep -l '^status: closed' .claude/epics/<name>/[0-9]*.md 2>/dev/null | wc -l)
progress=$((closed * 100 / total))

epic_record=$(grep 'lark_record:' .claude/epics/<name>/epic.md | awk '{print $2}')
lark-cli base +record-upsert \
  --base-token "$APP_TOKEN" --table-id "$TABLE_ID" \
  --record-id "$epic_record" \
  --json "{\"fields\":{\"进度\":$progress}}"

sed -i.bak "/^progress:/c\\progress: ${progress}%" .claude/epics/<name>/epic.md
rm .claude/epics/<name>/epic.md.bak
```

---
```

- [ ] **Step 2: Commit**

```bash
git add skill/ccpm/references/sync.md
git commit -m "Issue #4: rewrite Closing a Task section for Lark Base"
```

---

### Task 5: Rewrite Merging an Epic section

**Files:**
- Modify: `skill/ccpm/references/sync.md` (append)

- [ ] **Step 1: Append the Merging section**

Append after the Closing `---`:

```markdown

## Merging an Epic

**Trigger**: User wants to merge a completed epic back to main.

### Preflight
- Verify worktree `../epic-<name>` exists.
- Check for uncommitted changes in the worktree — block if dirty.
- Warn if any task records are still Open/In Progress.

### Process

```bash
# From worktree: run project tests if detectable
cd ../epic-<name>
# detect and run: npm test / pytest / cargo test / go test / etc.

# Create MR on GitLab
glab mr create \
  --source-branch "epic/<name>" \
  --target-branch "$GITLAB_DEFAULT_BRANCH" \
  --title "Epic: <name>" \
  --description "Merges epic <name>. Lark Base epic record: $epic_record_id"

# After MR review and merge:
glab mr merge <MR_N>

# From main repo:
git checkout main && git pull origin main

# Cleanup worktree
git worktree remove ../epic-<name>
git branch -d epic/<name>

# Archive
mkdir -p .claude/epics/archived/
mv .claude/epics/<name> .claude/epics/archived/

# Update Lark Base: close epic record
epic_record=$(grep 'lark_record:' .claude/epics/archived/<name>/epic.md | awk '{print $2}')
lark-cli base +record-upsert \
  --base-token "$APP_TOKEN" --table-id "$TABLE_ID" \
  --record-id "$epic_record" \
  --json '{"状态":"Closed","进度":100}'
```

Update epic.md frontmatter: `status: completed`.

Write MR URL back to epic frontmatter:
```bash
sed -i.bak "/^gitlab_mr:/c\\gitlab_mr: <MR_URL>" .claude/epics/archived/<name>/epic.md
rm .claude/epics/archived/<name>/epic.md.bak
```

---
```

- [ ] **Step 2: Commit**

```bash
git add skill/ccpm/references/sync.md
git commit -m "Issue #4: rewrite Merging an Epic section for glab MR"
```

---

### Task 6: Rewrite Bug Reporting section

**Files:**
- Modify: `skill/ccpm/references/sync.md` (append)

- [ ] **Step 1: Append the Bug Reporting section**

Append after the Merging `---`:

```markdown

## Reporting a Bug Against a Completed Task

**Trigger**: User finds a bug while testing a completed or in-progress task — e.g. "found a bug in task 003", "email validation is broken, came up while testing task 003".

### Process

**Step 1 — Read the original task for context:**
```bash
# Read local task file
cat .claude/epics/*/<original_N>.md

# Read from Lark Base if record exists
RECORD_ID=$(grep 'lark_record:' .claude/epics/*/<original_N>.md | awk '{print $2}')
if [ -n "$RECORD_ID" ]; then
  lark-cli base +record-get --base-token "$APP_TOKEN" --table-id "$TABLE_ID" --record-id "$RECORD_ID"
fi
```

**Step 2 — Create a local bug task file:**

```markdown
---
name: "Bug: <short description>"
status: open
created: <run: date -u +"%Y-%m-%dT%H:%M:%SZ">
updated: <same>
lark_record:
gitlab_mr:
depends_on: []
parallel: false
conflicts_with: []
bug_for: <original_N>
---

# Bug: <short description>

## Context
Found while working on / testing task <original_N>: <original title>

## Description
<what's broken>

## Steps to Reproduce
<steps>

## Expected vs Actual
- Expected:
- Actual:

## Acceptance Criteria
- [ ] Bug is fixed
- [ ] Original task <original_N> behaviour is unaffected

## Effort Estimate
- Size: XS/S
```

Save to `.claude/epics/<same_epic_as_original>/bug-<original_N>-<slug>.md`

**Step 3 — Create a bug record in Lark Base:**
```bash
bug_result=$(lark-cli base +record-upsert \
  --base-token "$APP_TOKEN" --table-id "$TABLE_ID" \
  --json "{\"标题\":\"Bug: <short description>\",\"类型\":\"Bug\",\"状态\":\"Open\",\"描述\":$(cat /tmp/bug-body.md | jq -Rs .),\"标签\":[\"bug\",\"epic:<epic_name>\"],\"本地文件\":\".claude/epics/<epic>/bug-<original_N>-<slug>.md\",\"可并行\":false,\"进度\":0}")
bug_record_id=$(echo "$bug_result" | jq -r '.data.record.record_id_list[0]')
```

**Step 4 — Update the local file** with the Lark record ID:
```bash
sed -i.bak "/^lark_record:/c\\lark_record: $bug_record_id" <bug_file>
rm <bug_file>.bak
```

**Output:**
```
✅ Bug record created in Lark Base: <bug_record_id>
  Title: "Bug: <short description>"
  Linked to: task <original_N>
  Epic: <epic_name>

Start fixing it: "start working on bug-<original_N>-<slug>"
```
```

- [ ] **Step 2: Verify the complete file**

Run:
```bash
wc -l skill/ccpm/references/sync.md
grep -c 'gh ' skill/ccpm/references/sync.md
grep -c 'github' skill/ccpm/references/sync.md
```
Expected: ~300 lines, 0 gh references, 0 github references

- [ ] **Step 3: Commit**

```bash
git add skill/ccpm/references/sync.md
git commit -m "Issue #4: rewrite Bug Reporting section for Lark Base"
```

---

### Task 7: Final review and fix conventions.md CLI commands

The conventions.md uses `lark-cli base record create --app ...` notation but the actual CLI is `lark-cli base +record-upsert --base-token ...`. Since sync.md now uses the actual format, we should align conventions.md.

**Files:**
- Modify: `skill/ccpm/references/conventions.md:138-169` (Lark Operations section)

- [ ] **Step 1: Update Lark Operations commands in conventions.md**

Replace the Lark Operations section (lines 138-169) with corrected CLI commands:

```markdown
## Lark Operations

### Authentication
Don't pre-check authentication. Run the `lark-cli` command and handle failure:
```bash
lark-cli base +record-list --base-token "$APP_TOKEN" --table-id "$TABLE_ID" --limit 1 \
  || echo "❌ lark-cli failed. Run: lark-cli auth login"
```

### Getting Record IDs
```bash
# From a task file's lark_record field:
grep 'lark_record:' <file> | awk '{print $2}'
```

### Creating Records
```bash
result=$(lark-cli base +record-upsert --base-token "$APP_TOKEN" --table-id "$TABLE_ID" \
  --json '{"标题":"<title>","类型":"<Epic|Task>","状态":"Open"}')
record_id=$(echo "$result" | jq -r '.data.record.record_id_list[0]')
```

### Updating Records
```bash
lark-cli base +record-upsert --base-token "$APP_TOKEN" --table-id "$TABLE_ID" \
  --record-id "$RECORD_ID" --json '{"状态":"In Progress"}'
```

### Querying Records
```bash
lark-cli base +record-get --base-token "$APP_TOKEN" --table-id "$TABLE_ID" --record-id "$RECORD_ID"
lark-cli base +record-list --base-token "$APP_TOKEN" --table-id "$TABLE_ID"
```
```

- [ ] **Step 2: Verify no old-style commands remain**

Run:
```bash
grep -n 'record create\|record update\|record get\|record list' skill/ccpm/references/conventions.md
```
Expected: 0 matches (all should now be `+record-upsert`, `+record-get`, `+record-list`)

- [ ] **Step 3: Verify sync.md has no remaining gh/github references**

Run:
```bash
grep -n '\bgh \|github' skill/ccpm/references/sync.md
```
Expected: 0 matches

- [ ] **Step 4: Commit**

```bash
git add skill/ccpm/references/sync.md skill/ccpm/references/conventions.md
git commit -m "Issue #4: align conventions.md CLI commands with actual lark-cli format"
```

---

## Spec Coverage Checklist

| Acceptance Criteria (Issue #4) | Task |
|-------------------------------|------|
| ✅ Epic Sync: `gh issue create` → `lark-cli base +record-upsert` | Task 2 |
| ✅ Task 创建: `gh issue create` + `gh sub-issue` → `lark-cli base +record-upsert` + 所属Epic | Task 2 |
| ✅ Task 文件保留自增序号, frontmatter 记录 `lark_record` | Task 2 (Step 4) |
| ✅ 创建记录时设置正确的字段类型 | Task 2 (fields JSON) |
| ✅ 依赖关系和并行标记写入多维表格 | Task 2 (Step 3 + Step 5) |
| ✅ Progress Sync: `gh issue comment` → update Lark record description | Task 3 |
| ✅ Closing: `gh issue close` → update record 状态 to Closed | Task 4 |
| ✅ Merging: `gh pr merge` → `glab mr merge` | Task 5 |
| ✅ Bug reporting: `gh issue create --label bug` → `+record-upsert` with 类型=Bug | Task 6 |
| ✅ conventions.md CLI command alignment | Task 7 |

## Note on Issue #4 vs #5 scope

Issue #4 covers sync.md Epic Sync + Task creation (the "前半部分"). Issue #5 covers sync.md Progress sync, closing, merging (the "后半部分"). However, since these are all sections of the same file and must be written together coherently, this plan covers the **complete** sync.md rewrite. After execution, both Issue #4 and #5 can be closed.
