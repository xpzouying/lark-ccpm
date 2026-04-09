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

    # Note: relation and people fields need manual setup
    echo ""
    echo "  ℹ️ The following fields need manual setup in Feishu UI:"
    echo "    - 负责人 (人员字段)"
    echo "    - 所属 Epic (关联字段 → 同表 Epic 记录)"
    echo "    - 依赖任务 (关联字段 → 同表记录)"
    echo "    - 冲突任务 (关联字段 → 同表记录)"
  fi
fi

# ── GitLab Project Configuration ────────────────────────────────────
echo ""
echo "🔗 Configuring GitLab project..."

GITLAB_PROJECT=""
GITLAB_DEFAULT_BRANCH="main"

# Try to detect from git remote
if git remote -v 2>/dev/null | grep -q origin; then
  remote_url=$(git remote get-url origin 2>/dev/null)
  # Extract project path from SSH or HTTPS URL
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
cat > .claude/lark-ccpm.yml <<CFGEOF
lark:
  base_token: ${BASE_TOKEN}
  table_id: ${TABLE_ID}

gitlab:
  project: ${GITLAB_PROJECT}
  default_branch: ${GITLAB_DEFAULT_BRANCH}

notifications:
  chat_id: ""
CFGEOF
echo "  ✅ Config saved to .claude/lark-ccpm.yml"

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
