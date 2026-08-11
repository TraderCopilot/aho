. (Join-Path $PSScriptRoot "Common.ps1")
. (Join-Path $PSScriptRoot "PlatformRegistry.ps1")

function Invoke-AhoVerify {
    param([Parameter(Mandatory)][string]$Target)
    $target = Resolve-AhoPath -Path $Target
    $errors = @()
    $warnings = @()

    $agents = Join-Path $target ".agents"
    $skills = Join-Path $agents "skills"
    if (-not (Test-Path -LiteralPath $agents)) { $errors += "missing .agents" }
    if (-not (Test-Path -LiteralPath $skills)) { $errors += "missing .agents/skills" }

    $manifestPath = Join-Path $agents ".aho-manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        $warnings += "missing .aho-manifest.json"
    } else {
        $m = Read-AhoJsonFile -Path $manifestPath
        if (-not $m) { $errors += "invalid manifest json" }
    }

    $ua = Join-Path $target "USER-ACTIONS.md"
    if (-not (Test-Path -LiteralPath $ua)) {
        $warnings += "missing USER-ACTIONS.md"
    } else {
        $text = Get-Content -LiteralPath $ua -Raw -Encoding UTF8
        if ($text -notmatch '\.agents') {
            $warnings += "USER-ACTIONS missing .agents SSOT language"
        }
    }

    $local = Join-Path $target "settings.local.json"
    if (Test-Path -LiteralPath $local) { $warnings += "settings.local.json present (not written by aho by default)" }

    $platforms = Get-AhoPlatformsForInstall -Target $target
    foreach ($plat in $platforms) {
        $forbidden = $plat['project_settings_forbidden']
        if ($forbidden) {
            $forbiddenPath = Join-Path $target $forbidden
            if (Test-Path -LiteralPath $forbiddenPath) {
                $platName = $plat['name']
                $warnings += "$forbidden present (not written by aho by default) [$platName]"
            }
        }
    }

    $skillCount = 0
    if (Test-Path -LiteralPath $skills) {
        $skillCount = @(Get-ChildItem -LiteralPath $skills -Directory).Count
        if ($skillCount -eq 0) { $errors += "no skills installed under .agents/skills" }
        Get-ChildItem -LiteralPath $skills -Directory | ForEach-Object {
            if (-not (Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md"))) {
                $errors += "skill missing SKILL.md: $($_.Name)"
            }
        }
    }

    $ok = ($errors.Count -eq 0)
    return [pscustomobject]@{
        ok         = $ok
        target     = $target
        skill_count = $skillCount
        errors     = $errors
        warnings   = $warnings
        exit_code  = $(if ($ok) { 0 } else { 1 })
    }
}
