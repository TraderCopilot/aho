# 公开发行合同（Release Contract）

**版本：** 0.5.0 (public-demo)
**状态：** 目标声明（distribution.json 行为待 P2 在 CLI 中实现）
**生成日期：** 2026-08-12

---

## 1. 发行范围

本合同定义 `agents-harness-os` 公开 Demo 发行包的边界、支持面和约束。

### 1.1 公开支持面

| 类别 | 公开支持 | 明确不支持 |
|---|---|---|
| Profile | `demo` | `minimal`、`standard`、`full-dev`、`internal` |
| Pack | `demo-core` | `core`、gates、workflow、Matt、内部扩展 pack |
| 项目命令 | `discover`、`scan`、`plan`、`install`、`verify`、`doctor` | `reseed`、`skill`、`matt-setup` 及依赖内部 seed 的命令 |
| 全局命令 | `global-plan`、`global-setup`（仅在公开 Global 模板可验证后保留） | 读取本机私有模板的路径 |
| Skill | `thinking-language`、`session-boot-ritual`、`aho-installer`、`demo-hello` | 内部 gate、审计、协作、mirrors 和项目专用 skill |

### 1.2 发行模式配置

发行模式配置文件位于：`apps/aho-setup/distribution.json`

**目标行为（P2 在 CLI 中实现）：**

1. 该文件存在且用户未传 `--profile` 时，使用 `demo`。
2. 用户传入未允许 profile 时，以明确错误退出。
3. 禁用命令不出现在 help 中；直接调用时以明确错误退出。
4. 该文件不存在时（开发仓），继续保持对内默认 `standard` 与完整命令集。

**当前状态：** distribution.json 已创建，字段与计划 §4.2 一致。CLI 读取逻辑在 P2 中实现。

---

## 2. 公开模板源

唯一公开模板源：开发仓 `templates/public-demo/`

- 公开包只从该目录取模板内容。
- 开发仓中的 `your-project/`、`Global/`、根 `.agents/` 均不得直接复制到公开仓。
- release 树中的 `your-project/`、`Global/` 是从公开模板生成的合法公开内容。

---

## 3. release 树边界

### 3.1 生成物约束

- release 树是生成物，由打包器生成。
- 禁止手工修补业务内容；修复必须回到开发仓的公开模板或打包器，再重新生成。

### 3.2 docs/plans/ 边界

- `docs/plans/` 仅用于本地发布管理资料。
- 默认不纳入公开 payload（.gitignore 已排除）。
- 若未来需要公开，必须先去除本机路径与仅限本地的操作说明。

### 3.3 docs/audit/ 边界

- `docs/audit/` 仅用于本地审计记录。
- 默认不纳入公开 payload（.gitignore 已排除）。

---

## 4. 不可变约束

1. 开发仓中的 `your-project/`、`Global/`、根 `.agents/` 均不得直接复制到公开仓。
2. 公开包只从 `templates/public-demo/` 取模板内容；其它内容必须逐条列入 allowlist。
3. release 树是生成物，禁止手工修补业务内容。
4. 打包过程中未被 allowlist 明确允许的文件一律不进入输出。
5. 最终扫描必须在所有 README、manifest、CI 文件生成后执行，命中即失败。
6. 对外 README、公开 skill、CLI help、profile、pack 和 CI 必须从同一份公开发行配置导出或由测试锁定。
7. RELEASE-MANIFEST.json 不得包含本机绝对路径（P3 修复）。

---

## 5. 许可证、安全联系与发布渠道

- **许可证：** Apache-2.0
- **安全联系渠道：** GitHub Security Advisory 流程
- **首版定位：** `0.x` 公开 Demo，非 `1.0` 正式版
- **公开仓名称：** `agents-harness-os-demo`（新建独立 GitHub 仓，不复用开发仓 remote）
- **是否公开 CI：** 是（GitHub Actions，最小权限）
