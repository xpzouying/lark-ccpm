# Task 002: conventions.md Adaptation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all GitHub-centric conventions in `skill/ccpm/references/conventions.md` with Lark Base + GitLab equivalents, establishing the schema contract for all subsequent CCPM adaptation tasks.

**Architecture:** Single file rewrite of `conventions.md`. The file has 6 sections; we modify 4 (Frontmatter Schemas, GitHub Operations, Git/Worktree Conventions, Naming Conventions) and add 1 new section (Configuration File). Directory Structure and utility sections stay mostly intact with minor wording changes.

**Tech Stack:** Markdown, YAML frontmatter, `lark-cli base` commands, `glab` CLI commands.

**Source of truth:**
- Spec: `docs/specs/lark-ccpm-spec.md` (sections 5, 6, 3.1, 3.2)
- Task file: `docs/epics/lark-gitlab-adaptation/002.md`
- Current file: `skill/ccpm/references/conventions.md`

---

## File Map

- **Modify:** `skill/ccpm/references/conventions.md` (entire file — 166 lines)

No new files created. No tests (this is a documentation/convention file).

---

### Task 1: Update Directory Structure section

Update the directory comment in the tree diagram: `github-mapping.md` no longer exists, `issue_N` references become record-based.

- [ ] **Step 1: Replace directory structure tree**

In `skill/ccpm/references/conventions.md`, replace the Directory Structure code block (lines 9-28) with:

```markdown
## Directory Structure

```
.claude/
├── lark-ccpm.yml                  # Project config (Lark + GitLab settings)
├── prds/
│   └── <feature-name>.md          # Product requirement documents
├── epics/
│   ├── <feature-name>/
│   │   ├── epic.md                # Technical epic
│   │   ├── <N>.md                 # Task files (sequential number, lark_record in frontmatter)
│   │   ├── <N>-analysis.md        # Parallel work stream analysis
│   │   ├── execution-status.md    # Active agents tracker
│   │   └── updates/
│   │       └── <task_N>/
│   │           ├── stream-A.md    # Per-agent progress
│   │           ├── progress.md    # Overall task progress
│   │           └── execution.md   # Execution state
│   └── archived/
│       └── <feature-name>/        # Completed epics
└── context/                       # Project context docs (separate system)
```
```

Key changes: removed `github-mapping.md`, renamed `issue_N` → `task_N`, added `lark-ccpm.yml`, updated comments.

- [ ] **Step 2: Verify the edit**

Read `skill/ccpm/references/conventions.md` lines 1-30. Confirm the tree now shows `lark-ccpm.yml` at top level, no `github-mapping.md`, `task_N` instead of `issue_N`.

- [ ] **Step 3: Commit**

```bash
git add skill/ccpm/references/conventions.md
git commit -m "refactor(conventions): update directory structure for Lark + GitLab"
```

---

### Task 2: Rewrite Frontmatter Schemas section

Replace all three frontmatter schemas (PRD stays, Epic and Task get new fields) per SPEC section 5.

- [ ] **Step 1: Replace Epic frontmatter schema**

In `skill/ccpm/references/conventions.md`, replace the Epic schema block (lines 44-55) with:

```markdown
### Epic (.claude/epics/<name>/epic.md)
```yaml
---
name: <feature-name>
status: backlog | in-progress | completed
created: <ISO 8601>
updated: <ISO 8601>
progress: 0%                # recalculated when tasks close
prd: .claude/prds/<name>.md
lark_record: <Record ID>    # 飞书多维表格 Record ID, set on sync
lark_app: <App Token>       # 多维表格 App Token (also in .claude/lark-ccpm.yml)
lark_table: <Table ID>      # 表 ID (also in .claude/lark-ccpm.yml)
gitlab_mr: <MR URL>         # GitLab Merge Request URL, set after MR creation
---
```
```

Key changes: `github:` removed. Added `lark_record:`, `lark_app:`, `lark_table:`, `gitlab_mr:`.

- [ ] **Step 2: Replace Task frontmatter schema**

Replace the Task schema block (lines 57-69) with:

```markdown
### Task (.claude/epics/<name>/<N>.md)
```yaml
---
name: <Task Title>
status: open | in-progress | closed
created: <ISO 8601>
updated: <ISO 8601>
lark_record: <Record ID>    # 飞书多维表格 Record ID, set on sync
gitlab_mr: <MR URL>         # GitLab MR URL, set after MR creation
depends_on: []              # lark_record IDs this must wait for
parallel: true              # can run concurrently with non-conflicting tasks
conflicts_with: []          # lark_record IDs that touch the same files
---
```
```

Key changes: `github:` → `lark_record:` + `gitlab_mr:`. `depends_on` and `conflicts_with` now reference Record IDs instead of issue numbers.

- [ ] **Step 3: Update Progress frontmatter schema**

Replace the Progress schema block (lines 71-79) with:

```markdown
### Progress (.claude/epics/<name>/updates/<N>/progress.md)
```yaml
---
task: <N>                   # local task file number
lark_record: <Record ID>    # corresponding Lark Base record
started: <ISO 8601>
last_sync: <ISO 8601>
completion: 0%
---
```
```

Key change: `issue:` → `task:` + `lark_record:`.

- [ ] **Step 4: Verify all three schemas**

Read `skill/ccpm/references/conventions.md` from the Frontmatter Schemas heading through the Progress schema. Confirm:
- No `github:` field anywhere
- Epic has `lark_record`, `lark_app`, `lark_table`, `gitlab_mr`
- Task has `lark_record`, `gitlab_mr`
- Progress has `task` and `lark_record`

- [ ] **Step 5: Commit**

```bash
git add skill/ccpm/references/conventions.md
git commit -m "refactor(conventions): replace GitHub frontmatter with Lark + GitLab fields"
```

---

### Task 3: Update Frontmatter Update Pattern section

The `sed` pattern for stripping frontmatter stays the same, but update the context comment about "GitHub" body extraction.

- [ ] **Step 1: Update body extraction comment**

In `skill/ccpm/references/conventions.md`, replace:

```markdown
When stripping frontmatter to get body content for GitHub:
```

with:

```markdown
When stripping frontmatter to get body content:
```

- [ ] **Step 2: Commit**

```bash
git add skill/ccpm/references/conventions.md
git commit -m "refactor(conventions): remove GitHub reference from frontmatter pattern section"
```

---

### Task 4: Replace "GitHub Operations" with "Lark Operations" + "GitLab Operations"

This is the largest change — the entire GitHub Operations section (lines 107-131) gets replaced with two new sections.

- [ ] **Step 1: Delete the old GitHub Operations section and replace with Lark Operations + GitLab Operations**

Replace everything from `## GitHub Operations` through the end of `grep 'github:' <file> | grep -oE '[0-9]+$'` closing code fence (lines 107-131) with:

```markdown
## Configuration File

All Lark and GitLab settings are stored in `.claude/lark-ccpm.yml`:

```yaml
lark:
  app_token: <飞书多维表格 App Token>
  table_id: <任务表 Table ID>

gitlab:
  project: <GitLab 项目路径, e.g. mygroup/myproject>
  default_branch: main

notifications:
  chat_id: <飞书群聊 ID, optional>
```

Read config values:
```bash
APP_TOKEN=$(grep 'app_token:' .claude/lark-ccpm.yml | awk '{print $2}')
TABLE_ID=$(grep 'table_id:' .claude/lark-ccpm.yml | awk '{print $2}')
GITLAB_PROJECT=$(grep 'project:' .claude/lark-ccpm.yml | awk '{print $2}')
```

---

## Lark Operations

### Authentication
Don't pre-check authentication. Run the `lark-cli` command and handle failure:
```bash
lark-cli base record list --app "$APP_TOKEN" --table "$TABLE_ID" --limit 1 \
  || echo "❌ lark-cli failed. Run: lark-cli auth login"
```

### Getting Record IDs
```bash
# From a task file's lark_record field:
grep 'lark_record:' <file> | awk '{print $2}'
```

### Creating Records
```bash
lark-cli base record create --app "$APP_TOKEN" --table "$TABLE_ID" \
  --fields '{"标题":"<title>", "类型":"<Epic|Task>", "状态":"Open"}'
```

### Updating Records
```bash
lark-cli base record update --app "$APP_TOKEN" --table "$TABLE_ID" \
  --record "$RECORD_ID" --fields '{"状态":"In Progress"}'
```

### Querying Records
```bash
lark-cli base record get --app "$APP_TOKEN" --table "$TABLE_ID" --record "$RECORD_ID"
lark-cli base record list --app "$APP_TOKEN" --table "$TABLE_ID" --filter '<filter>'
```

---

## GitLab Operations

### Repository Safety Check (run before any write operation)
```bash
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
GITLAB_PROJECT=$(grep 'project:' .claude/lark-ccpm.yml | awk '{print $2}')
if [[ -z "$GITLAB_PROJECT" ]]; then
  echo "❌ No GitLab project configured. Run init to set up .claude/lark-ccpm.yml"
  exit 1
fi
```

### Authentication
Don't pre-check authentication. Run the `glab` command and handle failure:
```bash
glab mr list --per-page 1 || echo "❌ GitLab CLI failed. Run: glab auth login"
```

### Creating Merge Requests
```bash
glab mr create --title "<title>" --description "<description>"
```

### Viewing Merge Requests
```bash
glab mr view <N>
```
```

- [ ] **Step 2: Verify the replacement**

Read the file from the Configuration File section through GitLab Operations. Confirm:
- No `gh` commands remain
- Configuration section reads from `.claude/lark-ccpm.yml`
- Lark Operations has auth, record ID, create, update, query subsections
- GitLab Operations has safety check, auth, MR create, MR view subsections

- [ ] **Step 3: Commit**

```bash
git add skill/ccpm/references/conventions.md
git commit -m "refactor(conventions): replace GitHub Operations with Lark + GitLab Operations"
```

---

### Task 5: Update Git / Worktree Conventions section

Push target changes to GitLab. Commit format changes from issue numbers to task references.

- [ ] **Step 1: Update Git / Worktree Conventions**

Replace the Git / Worktree Conventions section (lines 134-145) with:

```markdown
## Git / Worktree Conventions

- One branch per epic: `epic/<name>`
- Worktrees live at `../epic-<name>/` (sibling to project root)
- Always start branches from an up-to-date main:
  ```bash
  git checkout main && git pull origin main
  git worktree add ../epic-<name> -b epic/<name>
  ```
- Commit format inside epics: `Task #<N>: <description>` (N = local task file number)
- Push to GitLab remote: `git push origin epic/<name>`
- Never use `--force` in any git operation
```

Key changes: commit format `Issue #<N>` → `Task #<N>`, added explicit push-to-GitLab line.

- [ ] **Step 2: Commit**

```bash
git add skill/ccpm/references/conventions.md
git commit -m "refactor(conventions): update git conventions for GitLab push target"
```

---

### Task 6: Update Naming Conventions section

Task files no longer get renamed to issue numbers. They keep sequential numbers, with Record ID in frontmatter.

- [ ] **Step 1: Replace Naming Conventions section**

Replace the Naming Conventions section (lines 148-153) with:

```markdown
## Naming Conventions

- Feature names: kebab-case, lowercase, letters/numbers/hyphens, starts with a letter
- Task files: `001.md`, `002.md`, ... (sequential, never renamed)
- Record ID stored in frontmatter `lark_record:` field, not in filename
- Labels in Lark Base: `类型` field set to `Epic` / `Task` / `Bug`; `标签` multi-select for `epic:<name>` grouping
```

Key change: removed "renamed to GitHub issue number" — files keep their sequential names permanently.

- [ ] **Step 2: Commit**

```bash
git add skill/ccpm/references/conventions.md
git commit -m "refactor(conventions): update naming conventions for Lark record-based IDs"
```

---

### Task 7: Update Epic Progress Calculation section

Minor update — the calculation logic is the same (counts local files), just ensure no GitHub references.

- [ ] **Step 1: Verify progress section**

Read the Epic Progress Calculation section. The `grep` and `wc` logic operates on local files only — no GitHub dependency. Confirm no changes needed. If the section still says "Update epic frontmatter when any task closes." — that's correct and stays.

- [ ] **Step 2: (No commit needed if no changes)**

---

### Task 8: Final review — full file read and acceptance criteria check

- [ ] **Step 1: Read the entire file**

Read `skill/ccpm/references/conventions.md` from top to bottom.

- [ ] **Step 2: Verify all 7 acceptance criteria**

Check each criterion from the task file:

| # | Criterion | What to look for |
|---|-----------|-----------------|
| 1 | `github:` → `lark_record:` + `gitlab_mr:` | No `github:` in any frontmatter schema |
| 2 | Epic has `lark_app:` and `lark_table:` | Present in Epic schema |
| 3 | GitHub Operations → Lark + GitLab Operations | Section headers and content |
| 4 | Auth check → `lark-cli` + `glab auth login` | In Lark Operations and GitLab Operations |
| 5 | Issue number → `lark_record:` from frontmatter | `grep 'lark_record:'` pattern |
| 6 | Push to GitLab remote | In Git / Worktree Conventions |
| 7 | `.claude/lark-ccpm.yml` reading convention | Configuration File section exists |

- [ ] **Step 3: Grep for any remaining GitHub references**

```bash
grep -in 'github' skill/ccpm/references/conventions.md
```

Expected: zero matches. If any remain, fix them.

- [ ] **Step 4: Final commit (if any fixes needed)**

```bash
git add skill/ccpm/references/conventions.md
git commit -m "refactor(conventions): final cleanup of GitHub references"
```
