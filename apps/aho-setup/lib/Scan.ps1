. (Join-Path $PSScriptRoot "Common.ps1")
. (Join-Path $PSScriptRoot "PlatformRegistry.ps1")

function Get-AhoProjectionStatus {
    param(
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)]$Platform
    )
    $projTo = $Platform['project_projection_to']
    if (-not $projTo) { return "absent" }
    $projPath = Join-Path $Target $projTo
    $parentDir = Split-Path $projPath -Parent

    if (-not (Test-Path -LiteralPath $projPath)) {
        if (Test-Path -LiteralPath $parentDir) { return "parent_only" }
        return "absent"
    }

    $item = Get-Item -LiteralPath $projPath -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $resolvedTarget = $null
        try {
            $targetDir = $item.Target
            if ($targetDir) {
                $rawTarget = if ($targetDir -is [array]) { $targetDir[0] } else { $targetDir }
                if ([System.IO.Path]::IsPathRooted($rawTarget)) {
                    $resolvedTarget = [System.IO.Path]::GetFullPath($rawTarget)
                } else {
                    $resolvedTarget = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($parentDir, $rawTarget))
                }
            }
        } catch {}

        $skills = Join-Path $Target ".agents\skills"
        $normSkills = if (Test-Path -LiteralPath $skills) {
            [System.IO.Path]::GetFullPath($skills).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        } else { $null }

        if ($null -eq $resolvedTarget -or -not (Test-Path -LiteralPath $resolvedTarget)) {
            return "broken"
        }
        if ($null -ne $normSkills) {
            $normResolved = $resolvedTarget.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
            if ($normResolved.Equals($normSkills, [StringComparison]::OrdinalIgnoreCase)) {
                return "link_correct"
            }
            return "link_wrong"
        }
        return "link_correct"
    }

    return "solid"
}

function Invoke-AhoScan {
    param(
        [Parameter(Mandatory)][string]$Target
    )
    $target = Resolve-AhoPath -Path $Target
    $result = [ordered]@{
        target       = $target
        exists       = $false
        agents       = $false
        agents_md    = $false
        platforms    = @{}
        git_repo     = $false
        skill_count  = 0
        skills       = @()
    }
    if (-not (Test-Path -LiteralPath $target)) {
        return [pscustomobject]$result
    }
    $result.exists = $true
    $result.agents = Test-Path -LiteralPath (Join-Path $target ".agents")
    $result.agents_md = Test-Path -LiteralPath (Join-Path $target "AGENTS.md")

    $scanPlatforms = Get-AhoPlatformsForScan -Target $target
    $platformsMap = [ordered]@{}
    foreach ($plat in $scanPlatforms) {
        $platName = $plat['name']
        $status = Get-AhoProjectionStatus -Target $target -Platform $plat
        $platformsMap[$platName] = $status
    }
    $result.platforms = $platformsMap

    $result.git_repo = Test-Path -LiteralPath (Join-Path $target ".git")
    $skillsDir = Join-Path $target ".agents\skills"
    if (Test-Path -LiteralPath $skillsDir) {
        $skillDirs = @(Get-ChildItem -LiteralPath $skillsDir -Directory -ErrorAction SilentlyContinue)
        $result.skill_count = $skillDirs.Count
        $result.skills = @($skillDirs | ForEach-Object { $_.Name })
    }
    return [pscustomobject]$result
}
