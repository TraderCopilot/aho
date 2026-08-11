. (Join-Path $PSScriptRoot "Pack.ps1")
. (Join-Path $PSScriptRoot "Common.ps1")

function Invoke-AhoSkillAdd {
    param(
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$Name,
        [string]$Pack,
        [switch]$Apply,
        [switch]$Confirmed
    )
    $target = Resolve-AhoPath -Path $Target
    $src = $null
    if ($Pack) {
        $packObj = Get-AhoPack -Name $Pack
        if ($packObj.skills_include -notcontains $Name) {
            throw "Skill '$Name' is not listed in pack '$Pack'"
        }
    }
    $src = Resolve-AhoSkillSource -SkillName $Name

    if (-not (Test-AhoWriteAllowed -Apply:$Apply -Confirmed:$Confirmed)) {
        Write-AhoI18nInfo 'skilladd.dryRun'
        return [pscustomobject]@{
            ok      = $true
            dry_run = $true
            written = $false
            skill   = $Name
            source  = $src
            message = "refused_write_without_apply_and_confirmed"
        }
    }

    $destRoot = Join-Path $target ".agents\skills"
    New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
    $dest = Join-Path $destRoot $Name
    if (Test-Path -LiteralPath $dest) {
        return [pscustomobject]@{
            ok      = $true
            dry_run = $false
            written = $false
            skill   = $Name
            skipped = $true
            message = "skill_exists_no_overwrite"
            path    = $dest
        }
    }
    Copy-AhoDirectoryContents -SourceDir $src -DestDir $dest
    $manifestPath = Join-Path $target ".agents\.aho-manifest.json"
    if (Test-Path -LiteralPath $manifestPath) {
        $mf = Read-AhoJsonFile -Path $manifestPath
        if ($mf) {
            $skillList = @($mf.skills)
            if ($skillList -notcontains $Name) { $skillList += $Name }
            $instList = @($mf.installed)
            if ($instList -notcontains $Name) { $instList += $Name }
            $mf.skills = $skillList
            $mf.installed = $instList
            Write-AhoJsonFile -Path $manifestPath -Object $mf
        }
    }
    return [pscustomobject]@{
        ok      = $true
        dry_run = $false
        written = $true
        skill   = $Name
        skipped = $false
        path    = $dest
        source  = $src
    }
}
