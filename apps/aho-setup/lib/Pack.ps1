. (Join-Path $PSScriptRoot "Common.ps1")

function Get-AhoPack {
    param([Parameter(Mandatory)][string]$Name)
    if ($Name -notmatch '^[A-Za-z0-9_-]+$') {
        throw "Invalid pack name: $Name (only alphanumeric, hyphen, underscore allowed)"
    }
    $path = Join-Path (Get-AhoPacksDir) (Join-Path $Name "pack.yaml")
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Pack not found: $Name ($path)"
    }
    $map = Get-AhoSimpleYamlMap -FilePath $path
    $skills = @()
    if ($map.ContainsKey("skills_include")) {
        $skills = @($map["skills_include"])
    }
    return [pscustomobject]@{
        name            = if ($map["name"]) { $map["name"] } else { $Name }
        description     = $map["description"]
        skills_include  = $skills
        path            = $path
    }
}

function Resolve-AhoSkillSource {
    param(
        [Parameter(Mandatory)][string]$SkillName,
        [string]$TemplateRoot = (Get-AhoYourProject)
    )
    if ($SkillName -notmatch '^[A-Za-z0-9_-]+$') {
        throw "Invalid skill name: $SkillName (only alphanumeric, hyphen, underscore allowed)"
    }
    $dir = Join-Path $TemplateRoot (Join-Path ".agents\skills" $SkillName)
    if (-not (Test-Path -LiteralPath $dir)) {
        throw "Skill source missing: $SkillName under $TemplateRoot"
    }
    $skillMd = Join-Path $dir "SKILL.md"
    if (-not (Test-Path -LiteralPath $skillMd)) {
        throw "SKILL.md missing for skill: $SkillName"
    }
    return $dir
}

function Get-AhoSkillsForPacks {
    param([Parameter(Mandatory)][string[]]$PackNames)
    $set = [System.Collections.Generic.List[string]]::new()
    foreach ($p in $PackNames) {
        $pack = Get-AhoPack -Name $p
        foreach ($s in $pack.skills_include) {
            if (-not $set.Contains($s)) { $set.Add($s) | Out-Null }
        }
    }
    return @($set)
}
