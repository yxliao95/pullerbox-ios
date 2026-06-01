# Agent 共享说明

本目录用于存放 Codex 和 Claude Code 共享的项目说明、技能文档和任务流程。

由于 [Claude Code](https://code.claude.com/docs/en/skills#add-supporting-files) 和 [Codex](https://developers.openai.com/codex/skills) 的 skill 自动发现目录不同，本项目不直接共用同一个 `SKILL.md` 文件，而是采用“共享正文 + 工具入口”的方式。

## 目录结构

```text
repo/
├── AGENTS.md
├── CLAUDE.md
├── agent/
│   └── skills/
        └── <skill-name>/
            ├── SKILL.md
            └── support_material.md

├── .agents/
│   └── skills/
│       └── <skill-name>/
│           └── SKILL.md
└── .claude/
    └── skills/
        └── <skill-name>/
            └── SKILL.md
```

## 设计原则

`agent/` 是唯一的项目知识源。

```text
agent/skills/       存放稳定的项目规则
.agents/skills/     Codex 的 skill 入口
.claude/skills/     Claude Code 的 skill 入口
```

不要把完整项目规则重复写进 `.agents/skills/` 或 `.claude/skills/`。这两个目录只负责让对应工具发现 skill。

## 入口文件示例

例如 SwiftData 相关 skill：

```text
.agents/skills/swiftdata-modeling/SKILL.md
.claude/skills/swiftdata-modeling/SKILL.md
```

内容可以相同：

```md
---
name: swiftdata-modeling
description: 当任务涉及 SwiftData 模型、关系、迁移、查询或持久化逻辑时使用。
---

请先阅读共享项目文档：

- `agent/skills/data-model/SKILL.md`
- `agent/skills/swiftdata-modeling/SKILL.md`
- `agent/skills/testing-and-verification/SKILL.md`

以上共享文档是准则来源。
```

## 新增 Skill 的流程

新增一个 skill 时，先创建共享正文：

```text
agent/skills/<skill-name>/SKILL.md
```

然后分别创建 Codex 和 Claude Code 的入口：

```text
.agents/skills/<skill-name>/SKILL.md
.claude/skills/<skill-name>/SKILL.md
```

入口文件只写 `name`、`description` 和需要读取的共享文档路径，不写详细业务规则。

## 修改规则的原则

普通项目规则只修改 `agent/skills/` 或 `agent/workflows/`。

只有以下情况才修改 `.agents/skills/` 或 `.claude/skills/`：

```text
skill 名称改变
触发描述改变
引用的共享文档改变
某个工具需要特殊说明
```
