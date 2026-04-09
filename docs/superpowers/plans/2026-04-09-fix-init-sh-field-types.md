# Fix init.sh Field Types + Add Link Fields

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan.

**Goal:** Fix init.sh field creation to use correct lark-cli format (string types, correct options syntax) and add self-referencing link fields for dependency tracking.

**Architecture:** Single file fix. The smoke test on 2026-04-09 revealed that `+field-create` requires string type names and `+table-create --fields` uses a different schema from `+field-create --json`.

**Tech Stack:** lark-cli base, bash

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `skill/ccpm/references/scripts/init.sh` | **Modify** | Fix field types in table creation section |

---

### Task 1: Fix table creation and field types in init.sh

**Files:**
- Modify: `skill/ccpm/references/scripts/init.sh` (table creation section, ~lines 207-248)

- [ ] **Step 1: Replace the table creation block**

Find the `+table-create` call and replace it with individual `+field-create` calls using correct format.

Replace from `Creating task table with standard fields...` to the end of field creation with:

```bash
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
```

- [ ] **Step 2: Remove the old "manual setup" notice**

Delete the lines about "ℹ️ The following fields need manual setup in Feishu UI" since we now create all fields automatically.

- [ ] **Step 3: Verify syntax**

```bash
bash -n skill/ccpm/references/scripts/init.sh
```

- [ ] **Step 4: Commit**

```bash
git add skill/ccpm/references/scripts/init.sh
git commit -m "fix: correct init.sh field types and add link fields for dependency tracking"
```

## Spec Coverage

- ✅ Field type: string names (`text`, `number`, `select`, `checkbox`, `link`)
- ✅ Select options: top-level `options` array, not nested in `property`
- ✅ Link fields: 所属 Epic, 依赖任务, 冲突任务 (self-referencing)
- ✅ User field: 负责人 (no longer manual)
- ✅ System fields: created_at, updated_at (no longer manual)
- ✅ Rate limit: 0.5s delay between field creation calls
