# Gemini / Antigravity 项目指令（脚手架模板）

跨工具通用规则以业务仓根目录 **AGENTS.md** 为准。

## 语言

聊天框与思维链必须使用**中文**（见 AGENTS.md 语言宪法）。

## 开发模式（若本业务仓启用 aho 工作流）

装完 aho 后，开发会话应遵循产品仓（或本仓文档）中的：

1. **Boot Sequence**（读 PLAN / task_list / 交接文件）  
2. **验证闭环**（测试 + 真实命令）  
3. **Handover**（更新 task_list + NEXT → 审计 → 用户批准后 safe-push）  

开发 **agents-harness-os 产品仓**时：工作流 SSOT 是产品仓 **`AGENTS.md` §2.1**（不是本脚手架文件）。  
业务仓日常：以本仓 `AGENTS.md` 为准。
