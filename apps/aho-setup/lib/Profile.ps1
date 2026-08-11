. (Join-Path $PSScriptRoot "Pack.ps1")

function Get-AhoProfile {
    param([Parameter(Mandatory)][string]$Name)
    if ($Name -notmatch '^[A-Za-z0-9_-]+$') {
        throw "Invalid profile name: $Name (only alphanumeric, hyphen, underscore allowed)"
    }
    $path = Join-Path (Get-AhoProfilesDir) "$Name.yaml"
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Profile not found: $Name ($path)"
    }
    $map = Get-AhoSimpleYamlMap -FilePath $path
    $packs = @()
    if ($map.ContainsKey("packs")) {
        $packs = @($map["packs"])
    }
    if ($packs.Count -eq 0) {
        throw "Profile $Name has no packs"
    }
    # validate packs exist
    foreach ($p in $packs) {
        $null = Get-AhoPack -Name $p
    }
    return [pscustomobject]@{
        name        = if ($map["name"]) { $map["name"] } else { $Name }
        description = $map["description"]
        packs       = $packs
        path        = $path
    }
}
