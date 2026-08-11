. (Join-Path $PSScriptRoot "Common.ps1")

function New-AhoReportEntry {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet("skill","workflow","script","agent","root_template","platform_template","platform_dir","platform_settings","platform_hooks","global_rules_dir","junction","manifest","settings","user_actions")]
        [string]$Type,
        [Parameter(Mandatory)][ValidateSet("created","skipped_existing","merged","failed")]
        [string]$Action,
        [string]$Reason = "",
        [string]$Source = ""
    )
    return [ordered]@{
        path   = $Path
        type   = $Type
        action = $Action
        reason = $Reason
        source = $Source
    }
}

function Write-AhoReport {
    param(
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)]$Report,
        [string]$Scope = "project"
    )
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# aho-setup 安装报告")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("> 生成时间：$ts")
    [void]$sb.AppendLine("> 范围：$Scope")
    [void]$sb.AppendLine("> 目标：``$Target``")
    [void]$sb.AppendLine()

    $created = @($Report | Where-Object { $_.action -eq "created" })
    $skipped = @($Report | Where-Object { $_.action -eq "skipped_existing" })
    $merged = @($Report | Where-Object { $_.action -eq "merged" })
    $failed = @($Report | Where-Object { $_.action -eq "failed" })

    [void]$sb.AppendLine("## 总览")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("| 类别 | 数量 |")
    [void]$sb.AppendLine("|:---|:---|")
    [void]$sb.AppendLine("| 新写入 | $($created.Count) |")
    [void]$sb.AppendLine("| 跳过（已存在） | $($skipped.Count) |")
    [void]$sb.AppendLine("| 合并/追加 | $($merged.Count) |")
    [void]$sb.AppendLine("| 失败 | $($failed.Count) |")
    [void]$sb.AppendLine()

    if ($created.Count -gt 0) {
        [void]$sb.AppendLine("## 新写入")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("| 路径 | 类型 | 来源 |")
        [void]$sb.AppendLine("|:---|:---|:---|")
        foreach ($e in $created) {
            $srcShort = if ($e.source) { Split-Path -Leaf $e.source } else { "" }
            [void]$sb.AppendLine("| ``$($e.path)`` | $($e.type) | $srcShort |")
        }
        [void]$sb.AppendLine()
    }

    if ($skipped.Count -gt 0) {
        [void]$sb.AppendLine("## 跳过（目标已存在）")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("| 路径 | 类型 | 原因 |")
        [void]$sb.AppendLine("|:---|:---|:---|")
        foreach ($e in $skipped) {
            [void]$sb.AppendLine("| ``$($e.path)`` | $($e.type) | $($e.reason) |")
        }
        [void]$sb.AppendLine()
    }

    if ($merged.Count -gt 0) {
        [void]$sb.AppendLine("## 合并/追加")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("| 路径 | 类型 | 说明 |")
        [void]$sb.AppendLine("|:---|:---|:---|")
        foreach ($e in $merged) {
            [void]$sb.AppendLine("| ``$($e.path)`` | $($e.type) | $($e.reason) |")
        }
        [void]$sb.AppendLine()
    }

    if ($failed.Count -gt 0) {
        [void]$sb.AppendLine("## 失败")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("| 路径 | 类型 | 原因 |")
        [void]$sb.AppendLine("|:---|:---|:---|")
        foreach ($e in $failed) {
            [void]$sb.AppendLine("| ``$($e.path)`` | $($e.type) | $($e.reason) |")
        }
        [void]$sb.AppendLine()
    }

    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("日常维护请改 ``.agents/`` 和 ``~/.agents/``，详见 USER-ACTIONS.md")

    $reportPath = Join-Path $Target "INSTALL-REPORT.md"
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($reportPath, $sb.ToString(), $utf8NoBom)
    return $reportPath
}
