---
name: lark-ccpm
description: "CCPM - spec-driven project management: PRD → Epic → Lark Base records → parallel agents → shipped code. Use this skill for anything in the software delivery lifecycle: writing a PRD ('write a PRD for X', 'let's plan X', 'scope this out'), parsing a PRD into an epic, decomposing an epic into tasks, syncing to Lark Base ('sync the X epic', 'push tasks to Lark Base'), starting work on an issue ('start working on issue N', 'let's work on issue N'), analyzing parallel work streams, running standups ('standup', 'run the standup'), checking status ('what's next', 'what's blocked', 'what are we working on'), closing tasks, or merging an epic. Use ccpm any time the user is talking about shipping a feature, managing work, or tracking progress — even if they don't say 'ccpm' or 'PRD'. Do NOT use for: debugging code, writing tests, reviewing PRs, or raw issue/PR operations with no delivery context."
---

# CCPM - Claude Code Project Manager

A spec-driven development workflow: PRD → Epic → Lark Base Records → Parallel Agents → Shipped Code.

## Core Philosophy

Requirements live in files, not heads. Every feature starts as a PRD, becomes a technical epic, decomposes into Lark Base task records, and gets executed by parallel agents with full traceability.

## File Conventions

Before doing anything, read `references/conventions.md` for path standards, frontmatter schemas, and operation rules. These apply to all phases.

## The Five Phases

### 1. Plan — Capture requirements
**When**: User wants to define a new feature, product requirement, or scope of work.
**Read**: `references/plan.md`
**Covers**: Writing PRDs through guided brainstorming, converting PRDs to technical epics.

### 2. Structure — Break it down
**When**: An epic exists and needs to be decomposed into concrete tasks.
**Read**: `references/structure.md`
**Covers**: Epic decomposition into numbered task files with dependencies and parallelization.

### 3. Sync — Push to Lark Base
**When**: Local epic/tasks need to become Lark Base records, progress needs to be posted as comments, or a bug is found and needs a linked issue created.
**Read**: `references/sync.md`
**Covers**: Epic sync (epic + tasks → Lark Base records), progress sync, closing tasks/epics, bug reporting against completed tasks.

### 4. Execute — Start building
**When**: User wants to start working on one or more tasks with parallel agents.
**Read**: `references/execute.md`
**Covers**: Task analysis (parallel work stream identification), launching parallel agents, coordinating worktrees.

### 5. Track — Know where things stand
**When**: User asks for status, standup report, what's blocked, what's next, or needs to validate state.
**Read**: `references/track.md`
**Covers**: Status, standup, search, in-progress, next priority, blocked items, validation.

---

## Script-First Rule

For deterministic operations — anything that reads and reports without needing reasoning — always run the bash script directly rather than doing the work manually:

| What the user wants | Script to run |
|---|---|
| Project status | `bash references/scripts/status.sh` |
| Standup report | `bash references/scripts/standup.sh` |
| List all epics | `bash references/scripts/epic-list.sh` |
| Show epic details | `bash references/scripts/epic-show.sh <name>` |
| Epic status | `bash references/scripts/epic-status.sh <name>` |
| List PRDs | `bash references/scripts/prd-list.sh` |
| PRD status | `bash references/scripts/prd-status.sh` |
| Search issues/tasks | `bash references/scripts/search.sh <query>` |
| What's in progress | `bash references/scripts/in-progress.sh` |
| What's next | `bash references/scripts/next.sh` |
| What's blocked | `bash references/scripts/blocked.sh` |
| Validate project state | `bash references/scripts/validate.sh` |

Use the LLM for work that requires reasoning: writing PRDs, analyzing parallelism, launching agents, synthesizing updates.

---

## Quick Reference

```
Plan a feature:     "I want to build X" or "create a PRD for X"
Parse to epic:      "turn the X PRD into an epic"
Decompose:          "break down the X epic into tasks"
Sync to Lark Base:  "push the X epic to Lark Base"
Start a task:       "start working on task 001"
Check status:       "what's our status" / "standup"
What's next:        "what should I work on next"
Merge epic:         "merge the X epic"
Report a bug:       "found a bug in task 003" / "testing task 003 revealed X"
```
