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
  echo "  Please install lark-cli:"
  echo "    npm install -g @larksuite/cli"
  echo "    npx skills add larksuite/cli -y -g"
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
  echo "  ❌ Feishu not authenticated"
  echo "  Please run: lark-cli auth login"
  exit 1
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
  echo "  ❌ GitLab not authenticated"
  echo "  Please run: glab auth login"
  exit 1
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
  echo "  Paste your Feishu Base URL (or press Enter to create a new Base):"
  echo "  Example: https://xxx.feishu.cn/base/AbcToken123?table=tblXXX"
  echo ""
  read -r -p "  > " base_input
  echo ""

  if [ -n "$base_input" ]; then
    # ── Parse URL ──
    # Extract base_token from /base/<token>
    BASE_TOKEN=$(echo "$base_input" | sed -n 's|.*/base/\([^?]*\).*|\1|p')
    # Extract table_id from ?table=<id> if present
    TABLE_ID=$(echo "$base_input" | sed -n 's|.*[?&]table=\([^&]*\).*|\1|p')

    if [ -z "$BASE_TOKEN" ]; then
      # Not a URL, treat as raw base token
      BASE_TOKEN="$base_input"
    fi

    echo "  Parsed: base_token=$BASE_TOKEN"
    [ -n "$TABLE_ID" ] && echo "  Parsed: table_id=$TABLE_ID"

    # Verify base is accessible
    if lark-cli base +table-list --base-token "$BASE_TOKEN" &> /dev/null; then
      echo "  ✅ Feishu Base accessible"
    else
      echo "  ❌ Cannot access Feishu Base: $BASE_TOKEN"
      echo "  Check the URL and try again."
      exit 1
    fi

    # If no table_id from URL, list tables and let user choose
    if [ -z "$TABLE_ID" ]; then
      echo ""
      echo "  Fetching tables..."
      tables_json=$(lark-cli base +table-list --base-token "$BASE_TOKEN" 2>&1)
      if echo "$tables_json" | jq -e '.data.items' &> /dev/null; then
        echo "  Available tables:"
        echo "$tables_json" | jq -r '.data.items[] | "    \(.table_id) — \(.name)"'
        echo ""
        read -r -p "  Enter Table ID (or press Enter to create new table): " TABLE_ID
      fi
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
      exit 1
    fi
    echo "  ✅ Base created: $BASE_TOKEN"
  fi

  # Create task table if no TABLE_ID yet
  if [ -z "$TABLE_ID" ]; then
    echo ""
    echo "  Creating task table..."
    table_json=$(lark-cli base +table-create \
      --base-token "$BASE_TOKEN" \
      --name "项目任务" 2>&1)
    TABLE_ID=$(echo "$table_json" | jq -r '.data.table_id // .table_id // empty')
    if [ -z "$TABLE_ID" ]; then
      echo "  ❌ Failed to create table"
      echo "  Output: $table_json"
      exit 1
    fi
    echo "  ✅ Table created: $TABLE_ID"

    echo "  Adding fields..."
    # Text fields
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"type":"text","name":"标题"}' > /dev/null 2>&1
    sleep 0.5
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"type":"text","name":"描述"}' > /dev/null 2>&1
    sleep 0.5
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"type":"text","name":"本地文件"}' > /dev/null 2>&1
    sleep 0.5
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"type":"text","name":"GitLab MR","style":{"type":"url"}}' > /dev/null 2>&1
    sleep 0.5

    # Number + checkbox
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"type":"number","name":"进度","style":{"type":"progress","percentage":true,"color":"Blue"}}' > /dev/null 2>&1
    sleep 0.5
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"type":"checkbox","name":"可并行"}' > /dev/null 2>&1
    sleep 0.5

    # Select fields
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"type":"select","name":"类型","options":[{"name":"Epic"},{"name":"Task"},{"name":"Bug"}]}' > /dev/null 2>&1
    sleep 0.5
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"type":"select","name":"状态","options":[{"name":"Open"},{"name":"In Progress"},{"name":"Closed"}]}' > /dev/null 2>&1
    sleep 0.5
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"type":"select","name":"标签","multiple":true,"options":[{"name":"epic"},{"name":"task"},{"name":"bug"}]}' > /dev/null 2>&1
    sleep 0.5
    echo "  ✅ Basic fields created"

    # Self-referencing link fields for dependencies
    echo "  Adding link fields for dependencies..."
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"type":"link","name":"所属 Epic","link_table":"项目任务"}' > /dev/null 2>&1
    sleep 0.5
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"type":"link","name":"依赖任务","link_table":"项目任务"}' > /dev/null 2>&1
    sleep 0.5
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"type":"link","name":"冲突任务","link_table":"项目任务"}' > /dev/null 2>&1
    sleep 0.5

    # User field
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"type":"user","name":"负责人","multiple":false}' > /dev/null 2>&1
    sleep 0.5

    # System fields
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"type":"created_at","name":"创建时间"}' > /dev/null 2>&1
    sleep 0.5
    lark-cli base +field-create --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" \
      --json '{"type":"updated_at","name":"更新时间"}' > /dev/null 2>&1

    echo "  ✅ All fields created (including 负责人, 所属 Epic, 依赖任务, 冲突任务)"
  fi
fi

# ── Write Config File ───────────────────────────────────────────────
echo ""
echo "📝 Writing .claude/lark-ccpm.yml..."
cat > .claude/lark-ccpm.yml <<CFGEOF
lark:
  base_token: ${BASE_TOKEN}
  table_id: ${TABLE_ID}

notifications:
  webhook_url: ""
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
if glab repo view &> /dev/null; then
  echo "  ✅ GitLab project accessible"
else
  echo "  ⚠️ Cannot access GitLab project"
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
echo "  GitLab: $(git remote get-url origin 2>/dev/null || echo 'no remote')"
echo ""
echo "🎯 Next Steps (tell your agent):"
echo "  1. \"I want to build X\"         → Create a PRD"
echo "  2. \"parse the X PRD\"           → PRD → Epic"
echo "  3. \"decompose the X epic\"      → Epic → Tasks"
echo "  4. \"sync the X epic\"           → Push to Feishu Base"
echo "  5. \"standup\" / \"what's next\"   → Track progress"
echo ""
echo "📚 Documentation: README.md"

exit 0
