# OS 适配附录 — aho-installer

## Windows（原生）

- PowerShell 5.1 预装（Windows 10+）；推荐安装 PowerShell 7
- 安装 PS7：`winget install Microsoft.PowerShell`
- junction 由 `mklink /J` 创建（需管理员权限或开发者模式）
- Home 目录：`$env:USERPROFILE`（回退 `$env:HOME`）
- Documents：`[Environment]::GetFolderPath('MyDocuments')`

## macOS

- 安装 PowerShell：`brew install --cask powershell`
- junction 退化为 symlink（`System.IO.Directory.CreateSymbolicLink`）
- macOS 12+ 创建 symlink 无需 sudo
- Home 目录：`$env:HOME`
- Documents：`$HOME/Documents`

## Linux

- 安装 PowerShell：各发行版包管理器（`apt`/`yum`/`snap`）
- 详情见 https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux
- symlink 正常工作
- Home 目录：`$env:HOME`

## junction vs symlink 差异

| 特性 | Windows junction | macOS/Linux symlink |
|:---|:---|:---|
| 创建方式 | `mklink /J` | `ln -s` / `CreateSymbolicLink` |
| 需要权限 | 管理员或开发者模式 | macOS 12+ 无需；Linux 无需 |
| aho 回退 | junction 失败 → copy 模式 | symlink 失败 → copy 模式 |
| copy 模式风险 | 投影目录与 .agents 可能漂移 | 同左 |
| doctor 检测 | `DUAL_SOLID_SKILLS` / `COPY_MODE` | 同左 |

**mklink 短路**：非 Windows 环境下，aho 跳过 `mklink /J`，直接使用 `System.IO.Directory.CreateSymbolicLink`（PowerShell 7+）或 `ln -s`（fallback）。Windows 上若 `mklink` 不可用（非管理员且未开开发者模式），同样回退到 symlink 或 copy 模式。三级 fallback：junction → symlink → copy。

## 路径差异

| 路径 | Windows | macOS/Linux |
|:---|:---|:---|
| aho-setup CLI | `apps\aho-setup\bin\aho-setup.ps1` | `apps/aho-setup/bin/aho-setup.ps1` |
| 项目 .agents | `<project>\.agents\` | `<project>/.agents/` |
| 全局 .agents | `%USERPROFILE%\.agents\` | `$HOME/.agents/` |
| Cline 规则 | `%USERPROFILE%\Documents\Cline\Rules\` | `~/Documents/Cline/Rules/` |
