. (Join-Path $PSScriptRoot "Common.ps1")
. (Join-Path $PSScriptRoot "PlatformRegistry.ps1")

function Invoke-AhoDiscover {
    param([Parameter(Mandatory)][string]$Target)
    $target = Resolve-AhoPath -Path $Target
    $result = [ordered]@{
        target           = $target
        exists           = (Test-Path -LiteralPath $target)
        has_agents       = $false
        has_agents_md    = $false
        platforms        = @{}
        git_repo         = $false
        notes            = @()
    }
    if ($result.exists) {
        $result.has_agents = Test-Path -LiteralPath (Join-Path $target ".agents")
        $result.has_agents_md = Test-Path -LiteralPath (Join-Path $target "AGENTS.md")
        $result.git_repo = Test-Path -LiteralPath (Join-Path $target ".git")

        $scanPlatforms = Get-AhoPlatformsForScan -Target $target
        $platMap = [ordered]@{}
        foreach ($plat in $scanPlatforms) {
            $platName = $plat['name']
            $projTo = $plat['project_projection_to']
            if ($projTo) {
                $platMap[$platName] = Test-Path -LiteralPath (Join-Path $target (Split-Path $projTo -Parent))
            }
        }
        $result.platforms = $platMap

        if ($result.has_agents) {
            $result.notes += "Target already has .agents (install will not overwrite existing skill files by default)"
        }
    } else {
        $result.notes += "Target does not exist yet; install --apply --confirmed will create it"
    }
    return [pscustomobject]$result
}
