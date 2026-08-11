. (Join-Path $PSScriptRoot "Common.ps1")

function Invoke-AhoMattSetup {
    param(
        [Parameter(Mandatory)][string]$Target,
        [ValidateSet("local", "github", "gitlab")]
        [string]$Preset = "github",
        [switch]$Apply,
        [switch]$Confirmed
    )
    $target = Resolve-AhoPath -Path $Target
    $yp = Get-AhoYourProject
    $seedDir = Join-Path $yp ".agents\skills\setup-matt-pocock-skills"
    if (-not (Test-Path -LiteralPath $seedDir)) {
        throw "Matt seed directory missing: $seedDir"
    }

    if (-not (Test-AhoWriteAllowed -Apply:$Apply -Confirmed:$Confirmed)) {
        return [pscustomobject]@{
            ok      = $true
            dry_run = $true
            written = $false
            target  = $target
            preset  = $Preset
            seed    = $seedDir
            message = "refused_write_without_apply_and_confirmed"
        }
    }

    $docsAgents = Join-Path $target "docs\agents"
    New-Item -ItemType Directory -Path $docsAgents -Force | Out-Null

    $copied = @()
    $trackerFile = "issue-tracker-$Preset.md"
    $srcTracker = Join-Path $seedDir $trackerFile
    $dstTracker = Join-Path $docsAgents "issue-tracker.md"
    if ((Test-Path -LiteralPath $srcTracker) -and -not (Test-Path -LiteralPath $dstTracker)) {
        Copy-Item -LiteralPath $srcTracker -Destination $dstTracker
        $copied += "issue-tracker.md"
    }

    foreach ($f in @("domain.md", "triage-labels.md")) {
        $src = Join-Path $seedDir $f
        $dst = Join-Path $docsAgents $f
        if ((Test-Path -LiteralPath $src) -and -not (Test-Path -LiteralPath $dst)) {
            Copy-Item -LiteralPath $src -Destination $dst
            $copied += $f
        }
    }

    $agentsSkill = Join-Path $target ".agents\skills\setup-matt-pocock-skills"
    if (-not (Test-Path -LiteralPath $agentsSkill)) {
        $destSkills = Join-Path $target ".agents\skills"
        New-Item -ItemType Directory -Path $destSkills -Force | Out-Null
        Copy-AhoDirectoryContents -SourceDir $seedDir -DestDir $agentsSkill
        $copied += "setup-matt-pocock-skills (skill)"
    }

    return [pscustomobject]@{
        ok      = $true
        dry_run = $false
        written = $true
        target  = $target
        preset  = $Preset
        seed    = $seedDir
        copied  = $copied
    }
}
