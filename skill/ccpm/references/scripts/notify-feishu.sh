#!/usr/bin/env bash
# 飞书机器人 webhook 通知脚本（lark-ccpm 标准版）
#
# Emoji 规范见 conventions.md "Notification Emoji Spec" 章节。
# 每条消息必须以类型 emoji 开头。
#
# 用法:
#   bash notify-feishu.sh "🚀 纯文本消息（需手动加 emoji）"
#   bash notify-feishu.sh --template task-start  --task "001: 数据库设计" --epic "notification-system" --progress "0/5"
#   bash notify-feishu.sh --template task-done   --task "001: 数据库设计" --epic "notification-system" --progress "1/5" --commit "abc1234" --time "2h" --lark-record "recXXX"
#   bash notify-feishu.sh --template mr-merged   --task "001: 数据库设计" --epic "notification-system" --progress "1/5" --commit "abc1234" --lark-record "recXXX"
#   bash notify-feishu.sh --template epic-start  --epic "notification-system" --tasks-total 5 --summary "已同步到飞书多维表格"
#   bash notify-feishu.sh --template epic-done   --epic "notification-system" --tasks-total 5 --summary "全部完成"
#   bash notify-feishu.sh --template bug-report  --task "003: API 端点" --epic "notification-system" --summary "邮件验证绕过"
#   bash notify-feishu.sh --template warning     --summary "API 响应超时，已自动重试"
#   bash notify-feishu.sh --template error       --summary "数据库连接失败，任务中断"
#   bash notify-feishu.sh --template progress    --epic "notification-system" --progress "3/5" --summary "本周完成 3 个 task"
#   bash notify-feishu.sh --template doc-link    --summary "PRD 已发布" --mr-url "https://..."
#   echo "🚀 消息内容" | bash notify-feishu.sh

set -euo pipefail

# ── Webhook URL ──────────────────────────────────
# 从项目配置或环境变量读取
if [ -n "${FEISHU_WEBHOOK_URL:-}" ]; then
  WEBHOOK_URL="$FEISHU_WEBHOOK_URL"
elif [ -f ".claude/lark-ccpm.yml" ]; then
  WEBHOOK_URL=$(grep 'webhook_url:' .claude/lark-ccpm.yml | awk '{print $2}')
else
  WEBHOOK_URL=""
fi

if [ -z "$WEBHOOK_URL" ]; then
  echo "⚠️ No webhook URL configured. Set FEISHU_WEBHOOK_URL or add to .claude/lark-ccpm.yml" >&2
  exit 0
fi

# ── 参数解析 ──────────────────────────────────────
TEMPLATE=""
TASK=""
EPIC=""
PROGRESS=""
COMMIT=""
TIME_SPENT=""
LARK_RECORD=""
TASKS_TOTAL=""
SUMMARY=""
MR_URL=""
RAW_MSG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template)     TEMPLATE="$2";     shift 2 ;;
    --task)         TASK="$2";         shift 2 ;;
    --epic)         EPIC="$2";         shift 2 ;;
    --progress)     PROGRESS="$2";     shift 2 ;;
    --commit)       COMMIT="$2";       shift 2 ;;
    --time)         TIME_SPENT="$2";   shift 2 ;;
    --lark-record)  LARK_RECORD="$2";  shift 2 ;;
    --tasks-total)  TASKS_TOTAL="$2";  shift 2 ;;
    --summary)      SUMMARY="$2";      shift 2 ;;
    --mr-url)       MR_URL="$2";       shift 2 ;;
    *)              RAW_MSG="$1";      shift   ;;
  esac
done

# 如果没有 --template 也没有位置参数，读 stdin
if [[ -z "$TEMPLATE" && -z "$RAW_MSG" ]]; then
  RAW_MSG=$(cat)
fi

# ── 进度条生成 ─────────────────────────────────────
progress_bar() {
  local done="$1" total="$2"
  local pct=$((done * 100 / total))
  local filled=$((pct / 10))
  local empty=$((10 - filled))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty;  i++)); do bar+="░"; done
  echo "${bar} ${pct}% (${done}/${total})"
}

# ── 模板渲染 ──────────────────────────────────────
# Emoji 规范:
#   🚀 task-start   ✅ task-done    📋 epic-start   🎉 epic-done
#   🚢 mr-merged    🐛 bug-report  ⚠️ warning      🚨 error
#   📊 progress     📄 doc-link
render_template() {
  local msg=""
  case "$TEMPLATE" in

    task-start)
      local done="${PROGRESS%%/*}"
      local total="${PROGRESS##*/}"
      msg="🚀 Task 开始 — ${TASK}
Epic: ${EPIC} · 进度: $(progress_bar "$done" "$total")"
      [[ -n "$TIME_SPENT" ]] && msg+="
⏱ 预估耗时: ${TIME_SPENT}"
      ;;

    task-done)
      local done="${PROGRESS%%/*}"
      local total="${PROGRESS##*/}"
      msg="✅ Task 完成 — ${TASK}
Epic: ${EPIC} · 进度: $(progress_bar "$done" "$total")"
      [[ -n "$COMMIT" ]]      && msg+="
  · Commit: ${COMMIT}"
      [[ -n "$TIME_SPENT" ]]  && msg+="
  · 实际耗时: ${TIME_SPENT}"
      [[ -n "$LARK_RECORD" ]] && msg+="
  · 飞书记录: ${LARK_RECORD} 已标记 Closed"
      ;;

    mr-merged)
      local done="${PROGRESS%%/*}"
      local total="${PROGRESS##*/}"
      msg="🚢 Task 合并到 master — ${TASK}
Epic: ${EPIC} · 进度: $(progress_bar "$done" "$total")"
      [[ -n "$COMMIT" ]]      && msg+="
  · Commit: ${COMMIT}"
      [[ -n "$MR_URL" ]]      && msg+="
  · MR: ${MR_URL}"
      [[ -n "$TIME_SPENT" ]]  && msg+="
  · 实际耗时: ${TIME_SPENT}"
      [[ -n "$LARK_RECORD" ]] && msg+="
  · 飞书记录: ${LARK_RECORD} 已标记 Closed"
      ;;

    epic-start)
      msg="📋 Epic 启动 — ${EPIC}"
      [[ -n "$TASKS_TOTAL" ]] && msg+="
  · 共 ${TASKS_TOTAL} 个 task"
      [[ -n "$SUMMARY" ]]     && msg+="
  · ${SUMMARY}"
      ;;

    epic-done)
      msg="🎉🎉🎉 ${EPIC} 收官 — ${SUMMARY:-全部完成}"
      [[ -n "$TASKS_TOTAL" ]] && msg+="
${TASKS_TOTAL} 个 task 全部完成"
      ;;

    bug-report)
      msg="🐛 Bug 报告 — ${SUMMARY:-发现问题}"
      [[ -n "$TASK" ]] && msg+="
  · 关联任务: ${TASK}"
      [[ -n "$EPIC" ]] && msg+="
  · Epic: ${EPIC}"
      [[ -n "$LARK_RECORD" ]] && msg+="
  · 飞书记录: ${LARK_RECORD}"
      ;;

    warning)
      msg="⚠️ 警告 — ${SUMMARY:-请注意}"
      [[ -n "$EPIC" ]] && msg+="
  · Epic: ${EPIC}"
      [[ -n "$TASK" ]] && msg+="
  · 任务: ${TASK}"
      ;;

    error)
      msg="🚨 错误 — ${SUMMARY:-发生严重错误}"
      [[ -n "$EPIC" ]] && msg+="
  · Epic: ${EPIC}"
      [[ -n "$TASK" ]] && msg+="
  · 任务: ${TASK}"
      ;;

    progress)
      msg="📊 进展汇总 — ${SUMMARY:-进度更新}"
      [[ -n "$EPIC" ]] && msg+="
  · Epic: ${EPIC}"
      if [[ -n "$PROGRESS" ]]; then
        local done="${PROGRESS%%/*}"
        local total="${PROGRESS##*/}"
        msg+="
  · 进度: $(progress_bar "$done" "$total")"
      fi
      ;;

    doc-link)
      msg="📄 文档链接 — ${SUMMARY:-文档更新}"
      [[ -n "$MR_URL" ]] && msg+="
  · 链接: ${MR_URL}"
      [[ -n "$EPIC" ]]   && msg+="
  · Epic: ${EPIC}"
      ;;

    *)
      echo "❌ 未知模板: ${TEMPLATE}" >&2
      echo "可用模板: task-start, task-done, mr-merged, epic-start, epic-done, bug-report, warning, error, progress, doc-link" >&2
      exit 1
      ;;
  esac
  echo "$msg"
}

# ── 构建消息 ──────────────────────────────────────
if [[ -n "$TEMPLATE" ]]; then
  MSG=$(render_template)
else
  MSG="$RAW_MSG"
fi

if [[ -z "$MSG" ]]; then
  echo "❌ 用法: notify-feishu.sh \"消息内容\"" >&2
  echo "   或:   notify-feishu.sh --template <模板名> --task ... --epic ..." >&2
  echo "" >&2
  echo "可用模板:" >&2
  echo "  task-start, task-done, mr-merged, epic-start, epic-done," >&2
  echo "  bug-report, warning, error, progress, doc-link" >&2
  exit 1
fi

# ── 发送 ─────────────────────────────────────────
# 飞书 webhook 必须绕过本地代理
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy

PAYLOAD=$(jq -n --arg text "$MSG" '{"msg_type":"text","content":{"text":$text}}')

RESP=$(curl -sk -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" 2>&1)

CODE=$(echo "$RESP" | jq -r '.code // .StatusCode // "?"')

if [ "$CODE" = "0" ]; then
  echo "✅ 飞书通知已发送"
else
  echo "❌ 飞书通知失败: $RESP" >&2
  exit 1
fi
