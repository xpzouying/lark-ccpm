---
name: lark-gitlab-adaptation
description: 将 CCPM 从 GitHub Issues 适配为飞书多维表格 + GitLab 的任务与代码管理后端
status: active
created: 2026-04-09T10:00:00Z
---

# PRD: CCPM 飞书 + GitLab 适配

## Executive Summary

将 CCPM 的外部依赖从 GitHub 生态（Issues + gh CLI）迁移到飞书多维表格（任务管理）+ GitLab（代码管理），使团队能在已有的飞书 + 自建 GitLab 工作流中使用 CCPM 的全部能力。

## Problem Statement

CCPM 当前硬绑定 GitHub 生态：任务管理用 GitHub Issues，代码管理用 `gh` CLI。我们团队使用飞书做协作、自建 GitLab（dev.msh.team）做代码管理，导致 CCPM 无法直接落地使用。核心矛盾是工具链不匹配，而非流程不匹配——CCPM 的五阶段流程（Plan → Structure → Sync → Execute → Track）完全适用于我们的场景。

## User Stories

1. **作为项目管理者**，我希望在飞书多维表格中看到所有 Epic/Task 的层级关系、状态和进度，以便团队协作跟踪。
2. **作为开发者**，我希望 CCPM Agent 能自动将任务同步到飞书多维表格，并通过 glab 提交 MR 到 GitLab，无需手动在多个平台间切换。
3. **作为团队成员**，我希望任务状态变更时能在飞书中收到通知，保持信息同步。
4. **作为 CCPM 用户**，我希望本地文件结构和五阶段流程保持不变，迁移后端不影响我的使用习惯。

## Functional Requirements

### FR-1: 飞书多维表格集成（替代 GitHub Issues）

- **FR-1.1**: 项目初始化时自动创建飞书多维表格（或连接已有表），包含标准字段（标题、类型、状态、描述、负责人、所属 Epic、依赖任务、可并行、冲突任务、GitLab MR、本地文件、标签、进度、创建/更新时间）
- **FR-1.2**: Epic/Task/Bug 记录的 CRUD 操作全部通过 `lark-cli base record` 命令完成
- **FR-1.3**: 支持 Epic-Task 父子层级关系（通过"所属 Epic"关联字段）
- **FR-1.4**: 支持任务间依赖关系（通过"依赖任务"关联字段）
- **FR-1.5**: 进度同步：状态和进度数字直接更新记录，详细进展追加到描述字段

### FR-2: GitLab 集成（替代 GitHub PR）

- **FR-2.1**: MR 创建、查看、合并通过 `glab` CLI 完成
- **FR-2.2**: MR 链接自动回写到飞书多维表格的 "GitLab MR" 字段
- **FR-2.3**: 仓库信息查询通过 `glab repo view` 完成

### FR-3: 配置管理

- **FR-3.1**: 项目级配置文件 `.claude/lark-ccpm.yml` 存储飞书 App Token、Table ID、GitLab 项目路径等
- **FR-3.2**: 初始化流程交互式获取配置，后续操作自动读取

### FR-4: ID 体系适配

- **FR-4.1**: 任务唯一标识从 GitHub Issue 编号改为飞书 Record ID
- **FR-4.2**: 任务文件保留自增序号命名，frontmatter 中记录 Record ID
- **FR-4.3**: `depends_on` 使用 Record ID 而非 Issue 编号

### FR-5: 认证与初始化

- **FR-5.1**: init.sh 检查 `lark-cli` 和 `glab` 的安装及认证状态
- **FR-5.2**: 自动创建多维表格或连接已有表
- **FR-5.3**: 连通性验证（读取表、访问 GitLab 项目）

## Non-Functional Requirements

- **NF-1**: 本地文件结构（`.claude/prds/`、`.claude/epics/`）保持不变
- **NF-2**: 五阶段流程（Plan → Structure → Sync → Execute → Track）保持不变
- **NF-3**: 离线场景支持：本地文件可离线工作，sync 时才需网络
- **NF-4**: 飞书 API 调用频率需考虑限速，批量操作时适当限流
- **NF-5**: Superpowers 和 RalphLoop 的集成方式不变

## Success Criteria

1. `lark-cli` 和 `glab` 认证检查通过
2. 初始化时能自动创建飞书多维表格（或连接已有表）
3. PRD → Epic → Task 拆解流程正常，任务记录同步到飞书多维表格
4. 飞书多维表格中能看到 Epic/Task 层级关系和依赖关系
5. 团队成员通过飞书能看到任务状态和进度
6. 代码通过 glab 提交 MR 到 GitLab
7. MR 链接自动回写到飞书多维表格记录
8. Track 阶段所有脚本正常工作（status、standup、next、blocked 等）
9. 整套流程在一个示例项目上端到端跑通

## Constraints & Assumptions

- `lark-cli` 命令格式需根据实际 `lark-cli base --help` 输出调整
- 飞书 Record ID 较长，不适合做文件名，保留自增序号
- 飞书多维表格无原生"评论"功能，进度信息通过更新描述字段或发群消息替代
- 团队已有飞书企业版和自建 GitLab 实例

## Out of Scope

- 飞书多维表格自动化规则配置（由用户在飞书 UI 中手动完成）
- 多维表格视图创建（建议手动配置看板视图、我的任务视图）
- 飞书机器人消息推送（作为可选增强，不在核心范围内）
- 从 GitHub 到飞书的历史数据迁移

## Dependencies

- `lark-cli` CLI 工具已安装且支持 `base record` 子命令
- `glab` CLI 工具已安装且可认证自建 GitLab
- 飞书企业版多维表格 API 权限
