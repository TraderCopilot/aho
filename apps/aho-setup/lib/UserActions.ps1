. (Join-Path $PSScriptRoot "PlatformRegistry.ps1")

function Get-AhoUserActionsText {
    param(
        [Parameter(Mandatory)][string]$Target,
        [string]$Scope = "project"
    )
    $nl = [Environment]::NewLine
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# USER-ACTIONS - aho-setup 交接说明')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('> 由 aho-setup 自动生成。安装完成后，运行时 SSOT 生效。')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## 日常维护（PLAN §18.3）')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("1. **项目技能请改**：``$Target/.agents/``")
    [void]$sb.AppendLine("2. **全局技能请改**：``~/.agents/``（或你指定的 ``--home`` 下 ``.agents``）")

    $platforms = Get-AhoPlatformsForInstall -Target $Target
    $projList = @()
    foreach ($plat in $platforms) {
        $projTo = $plat['project_projection_to']
        if ($projTo) {
            $projList += "``$projTo``"
        }
    }
    if ($projList.Count -gt 0) {
        [void]$sb.AppendLine("3. **不要改** $($projList -join '、') 等投影目录（应为指向 ``.agents/skills`` 的链接）")
    } else {
        [void]$sb.AppendLine("3. **不要改** 投影目录（应为指向 ``.agents/skills`` 的链接）")
    }

    [void]$sb.AppendLine("4. aho 仓的 ``your-project/`` 和 ``Global/`` 仅用于给**新项目**做脚手架")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## 路径')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("- 目标：``$Target``")
    [void]$sb.AppendLine("- 范围：``$Scope``")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## 命令')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('```powershell')
    [void]$sb.AppendLine("# 若已配置 PATH 别名，可直接：")
    [void]$sb.AppendLine("aho-setup verify --target $Target")
    [void]$sb.AppendLine("aho-setup doctor --target $Target")
    [void]$sb.AppendLine("# 否则使用完整路径：")
    [void]$sb.AppendLine(".\apps\aho-setup\bin\aho-setup.ps1 verify --target $Target")
    [void]$sb.AppendLine(".\apps\aho-setup\bin\aho-setup.ps1 doctor --target $Target")
    [void]$sb.AppendLine('```')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## 扩展维护')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('- **OpenSpec Commands**：在 ``.agents/commands/`` 中添加/编辑命令定义')
    [void]$sb.AppendLine('- **全局配置**：``~/.agents/`` 和各平台全局目录；aho 的 ``Global/`` 仅影响下次新装')
    [void]$sb.AppendLine('- **本地覆盖**：各平台 ``settings.local.json`` 为个人层（gitignored），aho 默认不写')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## 注意事项')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('- **无 junction 权限环境**：若系统未开启开发者模式或无管理员权限，``install`` 会以 copy 模式物化（非 junction）。此时 ``doctor`` 报 ``DUAL_SOLID_SKILLS`` 属预期行为，不影响功能，仅表示平台目录与 ``.agents/skills`` 是两份独立副本。')
    return $sb.ToString()
}

function Write-AhoUserActions {
    param(
        [Parameter(Mandatory)][string]$Target,
        [string]$Scope = "project",
        [switch]$NoOverwrite
    )
    $path = Join-Path $Target "USER-ACTIONS.md"
    if ($NoOverwrite -and (Test-Path -LiteralPath $path)) {
        return $path
    }
    $text = Get-AhoUserActionsText -Target $Target -Scope $Scope
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
    return $path
}
