. (Join-Path $PSScriptRoot "Common.ps1")
. (Join-Path $PSScriptRoot "PlatformRegistry.ps1")

function Merge-AhoHashtableDeep {
    param(
        [Parameter(Mandatory)][hashtable]$Base,
        [Parameter(Mandatory)][hashtable]$Override,
        [switch]$NoOverwriteExisting
    )
    $result = @{}
    foreach ($key in $Base.Keys) {
        $result[$key] = $Base[$key]
    }
    foreach ($key in $Override.Keys) {
        if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $Override[$key] -is [hashtable]) {
            $result[$key] = Merge-AhoHashtableDeep -Base $result[$key] -Override $Override[$key] -NoOverwriteExisting:$NoOverwriteExisting
        } elseif ($NoOverwriteExisting -and $result.ContainsKey($key)) {
            continue
        } else {
            $result[$key] = $Override[$key]
        }
    }
    return $result
}

function Convert-AhoToHashtable {
    param([Parameter(Mandatory)][AllowNull()]$InputObj)
    if ($null -eq $InputObj) { return @{} }
    if ($InputObj -is [hashtable]) { return $InputObj }
    if ($InputObj -is [System.Collections.Specialized.OrderedDictionary]) {
        $ht = @{}
        foreach ($key in $InputObj.Keys) { $ht[$key] = $InputObj[$key] }
        return $ht
    }
    if ($InputObj -is [array]) {
        $arr = @()
        foreach ($item in $InputObj) {
            if ($item -is [pscustomobject] -or $item -is [System.Collections.Specialized.OrderedDictionary]) {
                $arr += Convert-AhoToHashtable -InputObj $item
            } else {
                $arr += $item
            }
        }
        return $arr
    }
    if ($InputObj -is [pscustomobject]) {
        $ht = @{}
        foreach ($prop in $InputObj.PSObject.Properties) {
            $val = $prop.Value
            if ($val -is [pscustomobject] -or $val -is [System.Collections.Specialized.OrderedDictionary]) {
                $val = Convert-AhoToHashtable -InputObj $val
            }
            $ht[$prop.Name] = $val
        }
        return $ht
    }
    return @{ value = $InputObj }
}

function Test-AhoOrcaManagedContent {
    <#
    .SYNOPSIS
      检测目标文本是否含 Orca 托管标记（PLAN §10.3 / H1-06 最小集）。
      命中则 aho 应跳过 merge，避免破坏 Orca 注入的 hooks/插件块。
    #>
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    if ($Text -match 'Managed by Orca') { return $true }
    if ($Text -match 'orca-managed-') { return $true }
    if ($Text -match '@orca-managed-') { return $true }
    return $false
}

function Merge-AhoJsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Updates,
        [switch]$NoOverwriteExisting,
        [string]$RootPath,
        [switch]$SkipIdentical,
        [switch]$CreateBackup
    )
    $existing = @{}
    if (Test-Path -LiteralPath $Path) {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if (Test-AhoOrcaManagedContent -Text $raw) {
            Write-AhoWarn "Skip JSON merge (Orca managed marker): $Path"
            return $null
        }
        $obj = $raw | ConvertFrom-Json
        $existing = Convert-AhoToHashtable -InputObj $obj
    }
    foreach ($key in $Updates.Keys) {
        if ($existing.ContainsKey($key) -and $existing[$key] -is [hashtable] -and $Updates[$key] -is [hashtable]) {
            $existing[$key] = Merge-AhoHashtableDeep -Base $existing[$key] -Override $Updates[$key] -NoOverwriteExisting:$NoOverwriteExisting
        } elseif ($NoOverwriteExisting -and $existing.ContainsKey($key)) {
            continue
        } else {
            $existing[$key] = $Updates[$key]
        }
    }
    $json = $existing | ConvertTo-Json -Depth 8
    $cfParams = @{
        Path    = $Path
        Content = $json
    }
    if ($RootPath) { $cfParams['RootPath'] = $RootPath }
    if ($SkipIdentical) { $cfParams['SkipIdentical'] = $true }
    if ($CreateBackup) { $cfParams['CreateBackup'] = $true }
    $result = Write-AhoContentFile @cfParams
    return $Path
}

function Set-AhoCodexHooks {
    param(
        [Parameter(Mandatory)][string]$Target,
        [hashtable]$Hooks
    )
    $codex = Get-AhoPlatform -Name "codex" -Target $Target
    $hooksPath = if ($codex -and $codex['project_hooks_path']) {
        Join-Path $target $codex['project_hooks_path']
    } else {
        Join-Path $Target ".codex\hooks.json"
    }
    Merge-AhoJsonFile -Path $hooksPath -Updates $Hooks -NoOverwriteExisting
}

function Set-AhoClaudeSettings {
    param(
        [Parameter(Mandatory)][string]$Target,
        [hashtable]$Settings
    )
    $claude = Get-AhoPlatform -Name "claude" -Target $Target
    $settingsPath = if ($claude -and $claude['project_settings_path']) {
        Join-Path $target $claude['project_settings_path']
    } else {
        Join-Path $Target ".claude\settings.json"
    }
    Merge-AhoJsonFile -Path $settingsPath -Updates $Settings -NoOverwriteExisting
}

function Set-AhoPlatformSettings {
    param(
        [Parameter(Mandatory)][string]$PlatformName,
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][hashtable]$Updates
    )
    $plat = Get-AhoPlatform -Name $PlatformName -Target $Target
    if (-not $plat) {
        Write-AhoWarn "Platform '$PlatformName' not found in registry"
        return $null
    }
    $settingsPath = $plat['project_settings_path']
    if (-not $settingsPath) {
        Write-AhoWarn "Platform '$PlatformName' has no project_settings_path"
        return $null
    }
    $fullPath = Join-Path $Target $settingsPath
    return Merge-AhoJsonFile -Path $fullPath -Updates $Updates -NoOverwriteExisting
}
