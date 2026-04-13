# Conventions — File Formats, Paths & Rules

Read this before doing any file operations across all phases.

---

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

---

## Frontmatter Schemas

### PRD (.claude/prds/<name>.md)
```yaml
---
name: <feature-name>        # kebab-case, matches filename
description: <one-liner>    # used in lists and summaries
status: backlog | active | completed
created: <ISO 8601>         # date -u +"%Y-%m-%dT%H:%M:%SZ"
---
```

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

---

## Datetime Rule

Always get real current datetime from the system — never use placeholder text:
```bash
date -u +"%Y-%m-%dT%H:%M:%SZ"
```

---

## Frontmatter Update Pattern

When updating a single frontmatter field in an existing file:
```bash
sed -i.bak "/^<field>:/c\\<field>: <value>" <file>
rm <file>.bak
```

When stripping frontmatter to get body content:
```bash
sed '1,/^---$/d; 1,/^---$/d' <file> > /tmp/body.md
```

---

## Notification Emoji Spec

All feishu webhook notifications MUST use an emoji prefix to indicate message type. This ensures messages are scannable at a glance in group chats.

| Emoji | Type | Used When |
|-------|------|-----------|
| 🚀 | Task/Epic start | A task or epic begins execution |
| ✅ | Task/Epic done | A task completes or an MR is merged |
| 📊 | Progress summary | Progress sync, standup reports |
| ⚠️ | Warning / partial failure | Non-critical issues, partial failures |
| 🚨 | Critical error | Blocking errors, pipeline failures |
| 📄 | Document link | Linking to PRD, epic, or external doc |
| 🐛 | Bug report | A bug is found and recorded |
| 📋 | Epic init | An epic is created and synced to Lark Base |
| 🚢 | MR merged | A task MR is merged to master |
| 🎉 | Epic celebration | All tasks in an epic are done |

### Template-to-Emoji Mapping

The `notify-feishu.sh` script uses `--template` to select message format. Each template has a fixed emoji prefix:

```
epic-start   → 📋   "📋 Epic 启动 — ..."
task-start   → 🚀   "🚀 Task 开始 — ..."
task-done    → ✅   "✅ Task 完成 — ..."
mr-merged    → 🚢   "🚢 Task 合并到 master — ..."
epic-done    → 🎉   "🎉🎉🎉 <epic> 收官 — ..."
bug-report   → 🐛   "🐛 Bug 报告 — ..."
warning      → ⚠️   "⚠️ 警告 — ..."
error        → 🚨   "🚨 错误 — ..."
progress     → 📊   "📊 进展汇总 — ..."
doc-link     → 📄   "📄 文档链接 — ..."
```

### Raw Message Emoji Rule

When sending raw messages (without `--template`), manually prefix the message with the appropriate emoji:
```bash
notify "🚀 开始部署 v2.1.0"
notify "⚠️ API 响应超时，已自动重试"
notify "🚨 数据库连接失败，任务中断"
```

---

## Configuration File

All Lark and GitLab settings are stored in `.claude/lark-ccpm.yml`:

```yaml
lark:
  base_token: <飞书多维表格 Base Token>
  table_id: <任务表 Table ID>

notifications:
  webhook_url: <飞书群机器人 webhook URL, optional>
```

Read config values:
```bash
APP_TOKEN=$(grep 'base_token:' .claude/lark-ccpm.yml | awk '{print $2}')  
TABLE_ID=$(grep 'table_id:' .claude/lark-ccpm.yml | awk '{print $2}')
```

---

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

---

## GitLab Operations

### Repository Safety Check (run before any write operation)
```bash
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -z "$remote_url" ]]; then
  echo "❌ No git remote configured."
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

---

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

---

## Naming Conventions

- Feature names: kebab-case, lowercase, letters/numbers/hyphens, starts with a letter
- Task files: `001.md`, `002.md`, ... (sequential, never renamed)
- Record ID stored in frontmatter `lark_record:` field, not in filename
- Labels in Lark Base: `类型` field set to `Epic` / `Task` / `Bug`; `标签` multi-select for `epic:<name>` grouping

---

## Epic Progress Calculation

```bash
total=$(ls .claude/epics/<name>/[0-9]*.md 2>/dev/null | wc -l)
closed=$(grep -l '^status: closed' .claude/epics/<name>/[0-9]*.md 2>/dev/null | wc -l)
progress=$((closed * 100 / total))
```

Update epic frontmatter when any task closes.
