. (Join-Path $PSScriptRoot "Profile.ps1")
. (Join-Path $PSScriptRoot "Discover.ps1")
. (Join-Path $PSScriptRoot "PlatformRegistry.ps1")

function Invoke-AhoPlan {
    param(
        [Parameter(Mandatory)][string]$Target,
        [string]$Profile = "standard"
    )
    $target = Resolve-AhoPath -Path $Target
    $discover = Invoke-AhoDiscover -Target $target
    $prof = Get-AhoProfile -Name $Profile
    $skills = Get-AhoSkillsForPacks -PackNames $prof.packs
    $skillSources = @()
    foreach ($s in $skills) {
        $src = Resolve-AhoSkillSource -SkillName $s
        $skillSources += [pscustomobject]@{ name = $s; source = $src }
    }
    $platforms = Get-AhoPlatformsForInstall -Target $target
    $projectionDescs = @()
    foreach ($plat in $platforms) {
        $projTo = $plat['project_projection_to']
        if ($projTo) {
            $projectionDescs += "Create $projTo junction -> .agents/skills (or copy fallback) [$($plat['name'])]"
        }
    }
    return [pscustomobject]@{
        target          = $target
        profile         = $prof.name
        packs           = $prof.packs
        skills          = $skills
        skill_sources   = $skillSources
        discover        = $discover
        write_required  = $false
        actions         = @(
            "Materialize skills into <target>/.agents/skills (no overwrite existing)",
            "Write AGENTS.md / CLAUDE.md if missing"
        ) + $projectionDescs + @(
            "Write .agents/.aho-manifest.json",
            "Write USER-ACTIONS.md with SSOT handover",
            "Never write settings.local.json"
        )
        dry_run         = $true
    }
}
