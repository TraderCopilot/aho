. (Join-Path $PSScriptRoot "Plan.ps1")
. (Join-Path $PSScriptRoot "Backup.ps1")

function Invoke-AhoReseed {
    param(
        [Parameter(Mandatory)][string]$Target,
        [string]$Profile = "standard",
        [switch]$OnlyMissing,
        [switch]$Force,
        [switch]$Apply,
        [switch]$Confirmed
    )
    $target = Resolve-AhoPath -Path $Target
    if ($Force -and -not $Confirmed) {
        Write-AhoI18nInfo 'reseed.forceRefused'
        return [pscustomobject]@{
            ok      = $false
            written = $false
            message = "force_requires_confirmed"
            exit_code = 3
        }
    }
    if (-not $Apply) {
        $plan = Invoke-AhoPlan -Target $target -Profile $Profile
        $skillsRoot = Join-Path $target ".agents\skills"
        $missing = @()
        $existing = @()
        foreach ($s in $plan.skill_sources) {
            $dest = Join-Path $skillsRoot $s.name
            if (Test-Path -LiteralPath $dest) {
                $existing += $s.name
            } else {
                $missing += $s.name
            }
        }
        Write-AhoI18nInfo 'reseed.dryRun'
        return [pscustomobject]@{
            ok        = $true
            dry_run   = $true
            written   = $false
            target    = $target
            only_missing = $true
            missing_skills = $missing
            existing_skills = $existing
            message   = "dry_run_without_apply"
        }
    }
    if (-not $OnlyMissing -and -not $Force) {
        $OnlyMissing = $true
    }

    $plan = Invoke-AhoPlan -Target $target -Profile $Profile
    $skillsRoot = Join-Path $target ".agents\skills"
    if (-not (Test-Path -LiteralPath $skillsRoot)) {
        New-Item -ItemType Directory -Path $skillsRoot -Force | Out-Null
    }

    $restored = @()
    $replaced = @()
    $skipped = @()

    foreach ($s in $plan.skill_sources) {
        $dest = Join-Path $skillsRoot $s.name
        if ($OnlyMissing -and -not $Force) {
            if (Test-Path -LiteralPath $dest) {
                $skipped += $s.name
                continue
            }
            Copy-AhoDirectoryContents -SourceDir $s.source -DestDir $dest
            $restored += $s.name
        } elseif ($Force -and $Confirmed) {
            if (Test-Path -LiteralPath $dest) {
                Backup-AhoDirectory -DirPath $dest
                Remove-Item -LiteralPath $dest -Recurse -Force
                $replaced += $s.name
            }
            Copy-AhoDirectoryContents -SourceDir $s.source -DestDir $dest
            if ($replaced -notcontains $s.name) { $restored += $s.name }
        }
    }

    return [pscustomobject]@{
        ok        = $true
        written   = $true
        target    = $target
        only_missing = [bool]$OnlyMissing
        force     = [bool]$Force
        restored  = $restored
        replaced  = $replaced
        skipped   = $skipped
        exit_code = 0
    }
}
