# 项目级指令宪法（模板）

> 由 aho-setup 安装到业务仓根目录 `AGENTS.md`。装完后请按项目需要编辑本文件。

## 1. 语言宪法（强制）

**所有聊天框内容与思维链必须使用中文**，包括：

- 与用户的全部对话、汇报、计划说明
- 思维链 / Thinking / Thought Process / 任务状态与摘要
- 文档、TASK、关键逻辑注释

**例外**：代码标识符、Git commit message、API 路径用英文；技术术语可保留英文；直接引用的英文原文可保持原文（说明用中文）。

## 2. 运行时配置 SSOT（装完后）

| 类型 | 路径 |
|:---|:---|
| 项目 skill / workflow | `./.agents/` |
| 全局 skill | `~/.agents/` |

不要把 `.claude/skills` 等投影目录当作第二份正文源。

## 3. Git

- 优先使用项目提供的 safe-push 流程（若有）
- 禁止未确认的 `reset --hard` / force-push / 批量删除

## 4. 凭据

- 禁止硬编码 API Key；使用环境变量或本地 `.env`（且勿提交）
