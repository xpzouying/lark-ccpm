# Rewrite init.sh: lark-cli + glab Adaptation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace GitHub-dependent init.sh with a version that initializes CCPM against Feishu Base (lark-cli) + GitLab (glab), producing a `.claude/lark-ccpm.yml` config file.

**Architecture:** The new init.sh follows the same 6-section structure as the original (branding → dependency checks → directory setup → remote config → CLAUDE.md → summary) but swaps GitHub-specific operations for lark-cli and glab equivalents. The biggest new section is "Feishu Base table creation" which replaces the old "GitHub label creation" block.

**Tech Stack:** Bash, lark-cli (base subcommands), glab CLI, jq (for JSON parsing)

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `skill/ccpm/references/scripts/init.sh` | **Rewrite** | Main init script — dependency checks, base table creation, config generation |

This is a single-file rewrite. No new files needed beyond the init.sh itself (`.claude/lark-ccpm.yml` is generated at runtime by the script, not checked in).

---

### Task 1: Rewrite branding and dependency checks section

**Files:**
- Modify: `skill/ccpm/references/scripts/init.sh:1-64`

- [ ] **Step 1: Replace the entire init.sh with the new branding + dependency checks**

Replace lines 1-64 of init.sh with:

```bash
#!/bin/bash

echo "Initializing..."
echo ""
echo ""

echo " ██████╗ ██████╗██████╗ ███╗   ███╗"
echo "██╔════╝██╔════╝██╔══██╗████╗ ████║"
echo "██║     ██║     ██████╔╝██╔████╔██║"
echo "╚██████╗╚██████╗██║     ██║ ╚═╝ ██║"
echo " ╚═════╝ ╚═════╝╚═╝     ╚═╝     ╚═╝"

echo "┌─────────────────────────────────┐"
echo "│ Claude Code Project Management  │"
echo "│ Feishu Base + GitLab Edition    │"
echo "└─────────────────────────────────┘"
echo ""
echo ""

echo "🚀 Initializing Claude Code PM System"
echo "======================================"
echo ""

# Check for required tools
echo "🔍 Checking dependencies..."

# Check jq (needed for JSON parsing)
if ! command -v jq &> /dev/null; then
  echo "  ❌ jq not found"
  echo "  Installing jq..."
  if command -v brew &> /dev/null; then
    brew install jq
  elif command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y jq
  else
    echo "  Please install jq manually: https://jqlang.github.io/jq/"
    exit 1
  fi
fi
echo "  ✅ jq installed"

# Check lark-cli
if command -v lark-cli &> /dev/null; then
  echo "  ✅ lark-cli installed"
else
  echo "  ❌ lark-cli not found"
  echo "  Please install lark-cli: npm install -g @nicepkg/lark-cli"
  exit 1
fi

# Check lark-cli auth status
echo ""
echo "🔐 Checking Feishu authentication..."
lark_status=$(lark-cli auth status 2>&1)
if echo "$lark_status" | jq -e '.tokenStatus == "valid"' &> /dev/null; then
  lark_user=$(echo "$lark_status" | jq -r '.userName')
  echo "  ✅ Feishu authenticated as: $lark_user"
else
  echo "  ⚠️ Feishu not authenticated"
  echo "  Running: lark-cli auth login"
  lark-cli auth login
fi

# Check glab CLI
echo ""
echo "🔍 Checking GitLab CLI..."
if command -v glab &> /dev/null; then
  echo "  ✅ GitLab CLI (glab) installed"
else
  echo "  ❌ GitLab CLI (glab) not found"
  echo "  Installing glab..."
  if command -v brew &> /dev/null; then
    brew install glab
  elif command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y glab
  else
    echo "  Please install glab manually: https://gitlab.com/gitlab-org/cli"
    exit 1
  fi
fi

# Check glab auth status
echo ""
echo "🔐 Checking GitLab authentication..."
if glab auth status 2>&1 | grep -q "Logged in"; then
  echo "  ✅ GitLab authenticated"
else
  echo "  ⚠️ GitLab not authenticated"
  echo "  Running: glab auth login"
  glab auth login
fi
```

- [ ] **Step 2: Verify the script is syntactically valid so far**

Run:
```bash
bash -n skill/ccpm/references/scripts/init.sh
```
Expected: no output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add skill/ccpm/references/scripts/init.sh
git commit -m "Issue #2: rewrite init.sh branding and dependency checks for lark-cli + glab"
```

---

### Task 2: Rewrite directory structure and git/remote checks

**Files:**
- Modify: `skill/ccpm/references/scripts/init.sh:66-148` (old line numbers — now appending after Task 1's content)

- [ ] **Step 1: Append the directory structure and git/remote section**

Append after the dependency checks (replacing old lines 66-148):

```bash

# Create directory structure
echo ""
echo "📁 Creating directory structure..."
mkdir -p .claude/prds
mkdir -p .claude/epics
mkdir -p .claude/rules
mkdir -p .claude/agents
mkdir -p .claude/scripts/pm
echo "  ✅ Directories created"

# Copy scripts if in main repo
if [ -d "scripts/pm" ] && [ ! "$(pwd)" = *"/.claude"* ]; then
  echo ""
  echo "📝 Copying PM scripts..."
  cp -r scripts/pm/* .claude/scripts/pm/
  chmod +x .claude/scripts/pm/*.sh
  echo "  ✅ Scripts copied and made executable"
fi

# Check for git
echo ""
echo "🔗 Checking Git configuration..."
if git rev-parse --git-dir > /dev/null 2>&1; then
  echo "  ✅ Git repository detected"

  # Check remote
  if git remote -v | grep -q origin; then
    remote_url=$(git remote get-url origin)
    echo "  ✅ Remote configured: $remote_url"

    # Safety check: warn if pointing to template repo
    if [[ "$remote_url" == *"lark-ccpm"* ]] && [[ "$remote_url" == *"xpzouying"* ]]; then
      echo ""
      echo "  ⚠️ WARNING: Your remote origin points to the lark-ccpm template repository!"
      echo "  This means any operations will target the template repo, not your project."
      echo ""
      echo "  To fix this:"
      echo "  1. Create your own project on GitLab"
      echo "  2. Update your remote:"
      echo "     git remote set-url origin git@dev.msh.team:YOUR_GROUP/YOUR_PROJECT.git"
      echo ""
    fi
  else
    echo "  ⚠️ No remote configured"
    echo "  Add with: git remote add origin git@dev.msh.team:YOUR_GROUP/YOUR_PROJECT.git"
  fi
else
  echo "  ⚠️ Not a git repository"
  echo "  Initialize with: git init"
fi
```

- [ ] **Step 2: Verify syntax**

Run:
```bash
bash -n skill/ccpm/references/scripts/init.sh
```
Expected: no output

- [ ] **Step 3: Commit**

```bash
git add skill/ccpm/references/scripts/init.sh
git commit -m "Issue #2: rewrite directory structure and remote checks for GitLab"
```

---

### Task 3: Add Feishu Base table creation (replaces GitHub labels)

This is the core new functionality — replacing `gh label create` with `lark-cli base +table-create` and field setup.

**Files:**
- Modify: `skill/ccpm/references/scripts/init.sh` (append new section)

- [ ] **Step 1: Append the Feishu Base setup section**

Append after the git/remote check block:

```bash

# ── Feishu Base Setup ───────────────────────────────────────────────
echo ""
echo "📊 Setting up Feishu Base (多维表格)..."
echo ""

# Check if config already exists
if [ -f ".claude/lark-ccpm.yml" ]; then
  echo "  ℹ️ Found existing .claude/lark-ccpm.yml"
  existing_base=$(grep 'base_token:' .claude/lark-ccpm.yml | awk '{print $2}')
  existing_table=$(grep 'table_id:' .claude/lark-ccpm.yml | awk '{print $2}')
  if [ -n "$existing_base" ] && [ -n "$existing_table" ]; then
    echo "  ✅ Using existing config: base=$existing_base table=$existing_table"
    echo ""
    echo "  To reconfigure, delete .claude/lark-ccpm.yml and re-run init."
    BASE_TOKEN="$existing_base"
    TABLE_ID="$existing_table"
  fi
fi

# If no existing config, prompt for setup
if [ -z "$BASE_TOKEN" ]; then
  echo "  Choose setup mode:"
  echo "    1) Connect to an existing Feishu Base (已有多维表格)"
  echo "    2) Create a new Feishu Base (自动创建)"
  echo ""
  read -r -p "  Enter choice [1/2]: " setup_choice
  echo ""

  if [ "$setup_choice" = "1" ]; then
    # ── Connect to existing Base ──
    read -r -p "  Enter Feishu Base App Token (从多维表格 URL 中获取): " BASE_TOKEN
    echo ""
    echo "  Fetching tables from base..."
    tables_json=$(lark-cli base +table-list --base-token "$BASE_TOKEN" 2>&1)
    if echo "$tables_json" | jq -e '.items' &> /dev/null; then
      echo "  Available tables:"
      echo "$tables_json" | jq -r '.items[] | "    \(.table_id) — \(.name)"'
      echo ""
      read -r -p "  Enter Table ID (or press Enter to create new table): " TABLE_ID
    fi
  else
    # ── Create new Base ──
    project_name=$(basename "$(pwd)")
    echo "  Enter folder token to create in (从飞书云空间文件夹 URL 获取):"
    read -r -p "  (留空则创建到「我的空间」): " FOLDER_TOKEN
    echo ""
    echo "  Creating new Feishu Base: CCPM: $project_name ..."
    create_args="--name \"CCPM: $project_name\" --time-zone Asia/Shanghai"
    if [ -n "$FOLDER_TOKEN" ]; then
      base_json=$(lark-cli base +base-create --name "CCPM: $project_name" --time-zone "Asia/Shanghai" --folder-token "$FOLDER_TOKEN" 2>&1)
    else
      base_json=$(lark-cli base +base-create --name "CCPM: $project_name" --time-zone "Asia/Shanghai" 2>&1)
    fi
    BASE_TOKEN=$(echo "$base_json" | jq -r '.app.app_token // empty')
    if [ -z "$BASE_TOKEN" ]; then
      echo "  ❌ Failed to create Feishu Base"
      echo "  Output: $base_json"
      echo "  Please create manually in Feishu and re-run with option 1."
      exit 1
    fi
    echo "  ✅ Base created: $BASE_TOKEN"
  fi

  # Create task table if no TABLE_ID yet
  if [ -z "$TABLE_ID" ]; then
    echo ""
    echo "  Creating task table with standard fields..."
    table_json=$(lark-cli base +table-create \
      --base-token "$BASE_TOKEN" \
      --name "项目任务" \
      --fields '[
        {"field_name":"标题","type":1},
        {"field_name":"描述","type":1},
        {"field_name":"本地文件","type":1},
        {"field_name":"GitLab MR","type":15},
        {"field_name":"进度","type":2},
        {"field_name":"可并行","type":7},
        {"field_name":"创建时间","type":5},
        {"field_name":"更新时间","type":5}
      ]' 2>&1)
    TABLE_ID=$(echo "$table_json" | jq -r '.table_id // empty')
    if [ -z "$TABLE_ID" ]; then
      echo "  ❌ Failed to create table"
      echo "  Output: $table_json"
      exit 1
    fi
    echo "  ✅ Table created: $TABLE_ID"

    # Add select fields (type, status, labels) separately since they need options
    echo "  Adding select fields..."
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"field_name":"类型","type":3,"property":{"options":[{"name":"Epic"},{"name":"Task"},{"name":"Bug"}]}}' > /dev/null 2>&1
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"field_name":"状态","type":3,"property":{"options":[{"name":"Open"},{"name":"In Progress"},{"name":"Closed"}]}}' > /dev/null 2>&1
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"field_name":"标签","type":4,"property":{"options":[{"name":"epic"},{"name":"task"},{"name":"bug"}]}}' > /dev/null 2>&1
    echo "  ✅ Select fields created (类型, 状态, 标签)"

    # Note: 负责人(人员), 所属Epic(关联), 依赖任务(关联), 冲突任务(关联) fields
    # require human configuration in Feishu UI as they involve user/record linking.
    echo ""
    echo "  ℹ️ The following fields need manual setup in Feishu UI:"
    echo "    - 负责人 (人员字段)"
    echo "    - 所属 Epic (关联字段 → 同表 Epic 记录)"
    echo "    - 依赖任务 (关联字段 → 同表记录)"
    echo "    - 冲突任务 (关联字段 → 同表记录)"
  fi
fi
```

- [ ] **Step 2: Verify syntax**

Run:
```bash
bash -n skill/ccpm/references/scripts/init.sh
```
Expected: no output

- [ ] **Step 3: Commit**

```bash
git add skill/ccpm/references/scripts/init.sh
git commit -m "Issue #2: add Feishu Base table creation replacing GitHub labels"
```

---

### Task 4: Add GitLab project config and write lark-ccpm.yml

**Files:**
- Modify: `skill/ccpm/references/scripts/init.sh` (append)

- [ ] **Step 1: Append GitLab project detection and config file generation**

Append after the Feishu Base setup block:

```bash

# ── GitLab Project Configuration ────────────────────────────────────
echo ""
echo "🔗 Configuring GitLab project..."

GITLAB_PROJECT=""
GITLAB_DEFAULT_BRANCH="main"

# Try to detect from git remote
if git remote -v 2>/dev/null | grep -q origin; then
  remote_url=$(git remote get-url origin 2>/dev/null)
  # Extract project path from SSH or HTTPS URL
  # SSH:   git@dev.msh.team:group/project.git
  # HTTPS: https://dev.msh.team/group/project.git
  GITLAB_PROJECT=$(echo "$remote_url" | sed -E 's|.*[:/]([^/]+/[^/]+)(\.git)?$|\1|')
  echo "  Detected from remote: $GITLAB_PROJECT"
fi

if [ -z "$GITLAB_PROJECT" ]; then
  read -r -p "  Enter GitLab project path (e.g., mygroup/myproject): " GITLAB_PROJECT
fi

# Detect default branch
detected_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
if [ -n "$detected_branch" ]; then
  GITLAB_DEFAULT_BRANCH="$detected_branch"
fi

echo "  ✅ GitLab project: $GITLAB_PROJECT (branch: $GITLAB_DEFAULT_BRANCH)"

# ── Write Config File ───────────────────────────────────────────────
echo ""
echo "📝 Writing .claude/lark-ccpm.yml..."
cat > .claude/lark-ccpm.yml << CFGEOF
lark:
  base_token: $BASE_TOKEN
  table_id: $TABLE_ID

gitlab:
  project: $GITLAB_PROJECT
  default_branch: $GITLAB_DEFAULT_BRANCH

notifications:
  chat_id: ""
CFGEOF
echo "  ✅ Config saved to .claude/lark-ccpm.yml"
```

- [ ] **Step 2: Verify syntax**

Run:
```bash
bash -n skill/ccpm/references/scripts/init.sh
```
Expected: no output

- [ ] **Step 3: Commit**

```bash
git add skill/ccpm/references/scripts/init.sh
git commit -m "Issue #2: add GitLab project config and lark-ccpm.yml generation"
```

---

### Task 5: Add connectivity validation and summary section

**Files:**
- Modify: `skill/ccpm/references/scripts/init.sh` (append, replacing old lines 150-192)

- [ ] **Step 1: Append connectivity validation, CLAUDE.md, and summary**

Append after the config file generation:

```bash

# ── Connectivity Validation ─────────────────────────────────────────
echo ""
echo "🔍 Validating connectivity..."

# Test Feishu Base access
if lark-cli base +table-list --base-token "$BASE_TOKEN" &> /dev/null; then
  echo "  ✅ Feishu Base accessible"
else
  echo "  ⚠️ Cannot access Feishu Base (token: $BASE_TOKEN)"
  echo "  Check permissions and try again."
fi

# Test GitLab access
if glab repo view "$GITLAB_PROJECT" &> /dev/null; then
  echo "  ✅ GitLab project accessible: $GITLAB_PROJECT"
else
  echo "  ⚠️ Cannot access GitLab project: $GITLAB_PROJECT"
  echo "  Check authentication: glab auth status"
fi

# Create CLAUDE.md if it doesn't exist
if [ ! -f "CLAUDE.md" ]; then
  echo ""
  echo "📄 Creating CLAUDE.md..."
  cat > CLAUDE.md << 'EOF'
# CLAUDE.md

> Think carefully and implement the most concise solution that changes as little code as possible.

## Project-Specific Instructions

Add your project-specific instructions here.

## Testing

Always run tests before committing:
- `npm test` or equivalent for your stack

## Code Style

Follow existing patterns in the codebase.
EOF
  echo "  ✅ CLAUDE.md created"
fi

# Summary
echo ""
echo "✅ Initialization Complete!"
echo "=========================="
echo ""
echo "📊 System Status:"
echo "  lark-cli: $(lark-cli --version 2>/dev/null || echo 'unknown')"
echo "  glab: $(glab version 2>/dev/null | head -1 || echo 'unknown')"
echo "  Feishu Base: $BASE_TOKEN"
echo "  Table: $TABLE_ID"
echo "  GitLab: $GITLAB_PROJECT"
echo ""
echo "🎯 Next Steps:"
echo "  1. Create your first PRD: /pm:prd-new <feature-name>"
echo "  2. View help: /pm:help"
echo "  3. Check status: /pm:status"
echo ""
echo "📚 Documentation: README.md"

exit 0
```

- [ ] **Step 2: Verify the complete script parses cleanly**

Run:
```bash
bash -n skill/ccpm/references/scripts/init.sh
```
Expected: no output

- [ ] **Step 3: Verify the complete script structure**

Run:
```bash
wc -l skill/ccpm/references/scripts/init.sh
grep -c 'echo' skill/ccpm/references/scripts/init.sh
```
Expected: ~220-240 lines, roughly similar structure to the original 193 lines

- [ ] **Step 4: Commit**

```bash
git add skill/ccpm/references/scripts/init.sh
git commit -m "Issue #2: add connectivity validation and summary section"
```

---

### Task 6: End-to-end dry-run validation

**Files:**
- Read: `skill/ccpm/references/scripts/init.sh` (full file review)

- [ ] **Step 1: Review the complete init.sh for consistency**

Read the full file and check:
- No remaining references to `gh` CLI or `github`
- All `lark-cli` commands use correct flag names (`--base-token`, `--table-id`)
- All `glab` commands use correct syntax
- Config file YAML uses consistent key names matching SPEC section 6 (`base_token` not `app_token`)
- Variables are set before use (no uninitialized variable reads)
- All `echo` statements are user-friendly

Run:
```bash
grep -n 'gh ' skill/ccpm/references/scripts/init.sh
grep -n 'github' skill/ccpm/references/scripts/init.sh
```
Expected: no matches (zero lines)

- [ ] **Step 2: Run shellcheck if available**

Run:
```bash
shellcheck skill/ccpm/references/scripts/init.sh 2>/dev/null || echo "shellcheck not installed, skipping"
```
Expected: no errors (warnings acceptable)

- [ ] **Step 3: Dry-run the script to catch runtime errors early**

Run:
```bash
bash -x skill/ccpm/references/scripts/init.sh 2>&1 | head -30
```
Expected: starts executing, shows dependency checks (will stop at interactive prompts — that's fine, we just want to see it doesn't crash on startup)

- [ ] **Step 4: Final commit with cleanup if any issues found**

```bash
git add skill/ccpm/references/scripts/init.sh
git commit -m "Issue #2: complete init.sh rewrite for lark-cli + glab"
```

---

## Spec Coverage Checklist

| Acceptance Criteria (Issue #2) | Task |
|-------------------------------|------|
| ✅ 检查 lark-cli 是否安装及认证状态 | Task 1 |
| ✅ 检查 glab 是否安装及认证状态 | Task 1 |
| ✅ 移除 gh-sub-issue 扩展检查 | Task 1 (completely removed) |
| ✅ 交互式获取或自动创建飞书多维表格 | Task 3 |
| ✅ 获取 GitLab 项目路径 | Task 4 |
| ✅ 生成 .claude/lark-ccpm.yml 配置文件 | Task 4 |
| ✅ 连通性验证 | Task 5 |
| ✅ 仓库 remote 检查改为 GitLab URL | Task 2 |

## SPEC Config Key Note

The SPEC section 6 uses `app_token` as the key name. However, `lark-cli base` commands use `--base-token` as the flag. The config file uses `base_token` to match the CLI flag naming for consistency. The SPEC frontmatter uses `lark_app` which maps to this same value. If SPEC compliance requires `app_token`, rename in the YAML — the script reads it with `grep` so the key name just needs to be consistent within the project.
