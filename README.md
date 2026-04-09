# CCPM – 飞书 + GitLab 项目管理 Agent

基于 [CCPM](https://github.com/automazeio/ccpm) 的飞书多维表格 + GitLab 适配版。用 AI Agent 驱动的结构化开发流程：**PRD → Epic → 飞书任务 → 并行 Agent → 代码交付**。

---

## 为什么做这个

团队使用飞书做协作、自建 GitLab 做代码管理，但 CCPM 原版绑定 GitHub 生态。本项目将外部依赖替换为：

| 原来 | 现在 |
|------|------|
| GitHub Issues（任务管理） | **飞书多维表格**（通过 lark-cli） |
| GitHub PR（代码管理） | **GitLab MR**（通过 glab CLI） |

五阶段流程、本地文件结构、并行执行能力保持不变。

---

## 快速开始

### 前置条件

```bash
# 1. lark-cli（飞书 CLI）
npm install -g @nicepkg/lark-cli
lark-cli auth login

# 2. glab（GitLab CLI）
brew install glab   # 或 apt-get install glab
glab auth login --hostname dev.msh.team

# 3. jq（JSON 解析）
brew install jq     # 或 apt-get install jq
```

### 安装 Skill

```bash
# 在你的项目根目录
mkdir -p .claude/skills
ln -s /path/to/lark-ccpm/skill/ccpm .claude/skills/ccpm
```

### 初始化项目

```bash
bash .claude/skills/ccpm/references/scripts/init.sh
```

初始化会：
1. 检查 lark-cli / glab 认证状态
2. 创建飞书多维表格（或连接已有表）— 支持指定文件夹
3. 自动创建 15 个标准字段（含依赖关联字段）
4. 检测 GitLab 项目路径
5. 生成 `.claude/lark-ccpm.yml` 配置文件
6. 验证飞书和 GitLab 的连通性

---

## 使用教程

### 整体流程

```
Plan → Structure → Sync → Execute → Track
 写 PRD    拆 Epic/Task   同步到飞书    Agent 执行    跟踪进度
```

每个阶段需要用户**主动触发**，阶段之间有 review 点。

### Phase 1: Plan — 写 PRD

```
你: "I want to build a notification system"
```

CCPM 会引导你做头脑风暴，问你：问题是什么？用户是谁？成功标准？约束？范围外的内容？

然后生成结构化 PRD 到 `.claude/prds/notification-system.md`。

```
CCPM: ✅ PRD created. Ready to create technical epic?
      Say: parse the notification-system PRD
```

### Phase 2: Structure — 拆分 Epic + Tasks

```
你: "parse the notification-system PRD"
```

生成技术 Epic（架构决策、实现策略）到 `.claude/epics/notification-system/epic.md`。

```
你: "decompose the notification-system epic"
```

拆分为具体 Task 文件（`001.md`, `002.md`...），每个 Task 包含：
- 验收标准
- 依赖关系（`depends_on`）
- 并行标记（`parallel: true/false`）
- 冲突标记（`conflicts_with`）
- 工作量估算

### Phase 3: Sync — 同步到飞书多维表格

```
你: "sync the notification-system epic"
```

CCPM 会：
1. 在飞书多维表格中创建 Epic 记录
2. 为每个 Task 创建记录，设置**所属 Epic** 关联
3. 将**依赖任务**和**冲突任务**写入关联字段
4. 回写 `lark_record` ID 到本地 frontmatter
5. 创建 git worktree 用于开发

在飞书中你会看到：

| 标题 | 类型 | 状态 | 所属 Epic | 依赖任务 | 可并行 |
|------|------|------|-----------|---------|--------|
| Epic: notification-system | Epic | Open | — | — | ❌ |
| 数据库 schema 设计 | Task | Open | ↑ Epic | — | ✅ |
| API 端点实现 | Task | Open | ↑ Epic | 数据库 schema | ❌ |

### Phase 4: Execute — Agent 并行执行

```
你: "start working on task 001"
```

CCPM 分析 Task 的独立工作流，启动并行 Agent。每个 Agent：
- 只修改自己负责的文件
- 以 `Task #001: description` 格式 commit
- 在飞书中更新任务状态为 "In Progress"

```
你: "start the notification-system epic"
```

一次性启动所有 `parallel: true` 且依赖已满足的 Task。

### Phase 5: Track — 跟踪进度

```
你: "standup"          → 今日进展报告
你: "what's next"      → 下一个可开始的任务
你: "what's blocked"   → 被阻塞的任务
你: "status"           → 全局项目状态
```

Track 操作用 bash 脚本执行，不消耗 LLM token。

### 关闭任务和合并 Epic

```
你: "close task 001"
```
→ 更新本地 frontmatter + 飞书记录状态为 Closed + 重算 Epic 进度

```
你: "merge the notification-system epic"
```
→ 运行测试 → 创建 GitLab MR → 合并 → 清理 worktree → 归档 Epic

---

## 自然语言命令速查

| 你说的话 | 触发的阶段 |
|---------|-----------|
| "I want to build X" / "plan X" | Plan — 写 PRD |
| "parse the X PRD" | Plan — PRD → Epic |
| "decompose the X epic" | Structure — 拆分 Tasks |
| "sync the X epic" | Sync — 同步到飞书多维表格 |
| "start working on task 001" | Execute — 启动 Agent |
| "start the X epic" | Execute — 并行启动所有就绪 Task |
| "standup" / "status" | Track — 进度报告 |
| "what's next" / "what's blocked" | Track — 优先级队列 |
| "close task 001" | Sync — 关闭任务 |
| "merge the X epic" | Sync — 合并 Epic |
| "found a bug in task 003" | Sync — 创建 Bug 记录 |

---

## 项目文件结构

### Skill 文件（安装到项目中）

```
skill/ccpm/
├── SKILL.md                  # 入口 — 意图识别 + 路由
└── references/
    ├── plan.md               # PRD 编写 + Epic 生成
    ├── structure.md          # Epic 拆分为 Tasks
    ├── sync.md               # 飞书同步、进度更新、关闭、合并
    ├── execute.md            # Task 分析 + 并行 Agent 启动
    ├── track.md              # 状态、站会、搜索、下一步、阻塞
    ├── conventions.md        # 文件格式、frontmatter schema、命令约定
    └── scripts/              # Bash 脚本（确定性操作）
```

### 项目运行时文件（git tracked）

```
.claude/
├── lark-ccpm.yml             # 飞书 + GitLab 配置
├── prds/                     # PRD 文档
├── epics/
│   └── <feature>/
│       ├── epic.md           # 技术 Epic
│       ├── 001.md            # Task 文件（保持序号，不重命名）
│       ├── 001-analysis.md   # 并行工作流分析
│       └── updates/          # Agent 进度跟踪
└── epics/archived/           # 已完成的 Epic
```

### 配置文件

`.claude/lark-ccpm.yml`（init.sh 自动生成）：

```yaml
lark:
  base_token: <飞书多维表格 App Token>
  table_id: <任务表 Table ID>

gitlab:
  project: <GitLab 项目路径>
  default_branch: main

notifications:
  chat_id: <飞书群聊 ID，可选>
```

---

## 飞书多维表格字段

init.sh 自动创建 15 个字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| 标题 | text | Epic/Task/Bug 标题 |
| 描述 | text | 详细描述 |
| 类型 | select | Epic / Task / Bug |
| 状态 | select | Open / In Progress / Closed |
| 进度 | number (progress) | 0-100% |
| 可并行 | checkbox | 是否可并行执行 |
| 标签 | select (multi) | epic, task, bug 等 |
| 所属 Epic | link (self) | Task → Epic 父子关系 |
| 依赖任务 | link (self) | Task → Task 前置依赖 |
| 冲突任务 | link (self) | 修改相同文件的任务 |
| 负责人 | user | 指派的成员 |
| 本地文件 | text | 对应的 .claude/ 文件路径 |
| GitLab MR | text (url) | MR 链接 |
| 创建时间 | created_at | 系统自动 |
| 更新时间 | updated_at | 系统自动 |

推荐视图配置详见 [飞书多维表格配置指南](docs/guides/feishu-base-setup.md)。

---

## 技术说明

**飞书集成** — 通过 `lark-cli base +record-upsert/+record-get/+record-list` 操作多维表格。JSON 格式直接传字段映射（无 `fields` 包裹），record ID 在 `.data.record.record_id_list[0]`。

**GitLab 集成** — 通过 `glab mr create/merge/view` 管理 Merge Request。MR 链接自动回写到飞书记录。

**文件命名** — Task 文件使用自增序号（`001.md`, `002.md`），sync 后不重命名。Lark Record ID 存储在 frontmatter 的 `lark_record` 字段中。

**依赖管理** — 通过飞书多维表格的自引用关联字段实现。`所属 Epic`、`依赖任务`、`冲突任务` 都是 link 类型字段，写入格式为 `[{"id":"rec_xxx"}]`。

**离线支持** — 本地文件可离线操作，sync 时才需要网络。

---

## 致谢

基于 [CCPM (automazeio/ccpm)](https://github.com/automazeio/ccpm) 改造，感谢原作者 [@aroussi](https://x.com/aroussi) 的开创性工作。

---

## License

[MIT](LICENSE)
