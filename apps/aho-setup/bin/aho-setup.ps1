#requires -Version 5.1
<#
.SYNOPSIS
  aho-setup — agents-harness-os installer CLI (PLAN v1.2)

.EXAMPLE
  .\apps\aho-setup\bin\aho-setup.ps1 discover --target .
  .\apps\aho-setup\bin\aho-setup.ps1 plan --profile demo --target .\tmp-proj
  .\apps\aho-setup\bin\aho-setup.ps1 install --profile demo --target .\tmp-proj --apply --confirmed
  .\apps\aho-setup\bin\aho-setup.ps1 verify --target .\tmp-proj
  .\apps\aho-setup\bin\aho-setup.ps1 global-setup --home .\tmp-home --apply --confirmed
  .\apps\aho-setup\bin\aho-setup.ps1 doctor --target .\tmp-proj
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = "Stop"
$lib = Join-Path (Split-Path -Parent $PSScriptRoot) "lib"
. (Join-Path $lib "Common.ps1")
. (Join-Path $lib "I18n.ps1")
. (Join-Path $lib "Discover.ps1")
. (Join-Path $lib "Plan.ps1")
. (Join-Path $lib "Project.ps1")
. (Join-Path $lib "GlobalSetup.ps1")
. (Join-Path $lib "Verify.ps1")
. (Join-Path $lib "Doctor.ps1")
. (Join-Path $lib "Reseed.ps1")
. (Join-Path $lib "SkillAdd.ps1")
. (Join-Path $lib "MattSetup.ps1")
. (Join-Path $lib "Scan.ps1")

function Get-AhoDistribution {
    $distPath = Join-Path (Split-Path -Parent $PSScriptRoot) "distribution.json"
    if (-not (Test-Path -LiteralPath $distPath)) { return $null }
    try {
        $raw = Get-Content -LiteralPath $distPath -Raw -Encoding UTF8
        return ($raw | ConvertFrom-Json)
    } catch {
        return $null
    }
}

$AhoDist = Get-AhoDistribution

function Get-AhoArg {
    param(
        [string[]]$ArgsList,
        [string]$Name,
        [switch]$Switch
    )
    for ($i = 0; $i -lt $ArgsList.Count; $i++) {
        if ($ArgsList[$i] -eq $Name) {
            if ($Switch) { return $true }
            if ($i + 1 -lt $ArgsList.Count) { return $ArgsList[$i + 1] }
            return $null
        }
    }
    if ($Switch) { return $false }
    return $null
}

function Show-AhoHelp {
    $distProfile = if ($AhoDist) { $AhoDist.default_profile } else { "standard" }
    $disabled = if ($AhoDist) { @($AhoDist.disabled_commands) } else { @() }
    $allowedProfiles = if ($AhoDist) { @($AhoDist.allowed_profiles) } else { @() }

    $cmdLines = @(
        "  discover       --target <path>",
        "  plan           --profile <name> --target <path>",
        "  install        --profile <name> --target <path> [--apply] [--confirmed]",
        "  verify         --target <path>",
        "  global-plan    [--home <path>]",
        "  global-setup   [--home <path>] [--apply] [--confirmed]",
        "  doctor         --target <path>",
        "  scan           --target <path>"
    )
    if ($disabled -notcontains "reseed") { $cmdLines += "  reseed         --target <path> [--profile <name>] [--only-missing] [--force] [--apply] [--confirmed]" }
    if ($disabled -notcontains "skill") { $cmdLines += "  skill          add --name <skill> --target <path> [--pack <name>] [--apply] [--confirmed]" }
    if ($disabled -notcontains "matt-setup") { $cmdLines += "  matt-setup     --target <path> --preset <local|github|gitlab> [--apply] [--confirmed]" }

    $profileNote = if ($allowedProfiles.Count -gt 0) { "  Allowed profiles: $($allowedProfiles -join ', '). Default: $distProfile" } else { "  Default profile: $distProfile" }

    @"
aho-setup -- agents-harness-os (aho) installer

Commands:
$($cmdLines -join "`n")

Global options:
  --json         Machine-readable output: suppress info messages, emit only JSON to stdout
  --lang <code>  Message language pack (e.g. en-US, zh-CN); else AHO_LANG; else UI culture

$profileNote

Notes:
  - Default is dry-run for write commands; --apply --confirmed required to materialize.
  - Runtime SSOT after install: <target>/.agents and ~/.agents (or --home .agents).
  - Does not write settings.local.json.
"@ | Write-Host
}

if (-not $Command -or $Command -in @("-h", "--help", "help")) {
    Show-AhoHelp
    exit 0
}

$argsList = @($Rest)
$target = Get-AhoArg -ArgsList $argsList -Name "--target"
if ([string]::IsNullOrWhiteSpace($target)) { $target = $null }
$profileName = Get-AhoArg -ArgsList $argsList -Name "--profile"
if (-not $profileName) {
    $profileName = if ($AhoDist) { $AhoDist.default_profile } else { "standard" }
}
if ($AhoDist -and $AhoDist.allowed_profiles) {
    $allowed = @($AhoDist.allowed_profiles)
    if ($allowed -notcontains $profileName) {
        Write-Error "This distribution does not support profile '$profileName'. Allowed profiles: $($allowed -join ', ')"
        exit 1
    }
}
$homeRootArg = Get-AhoArg -ArgsList $argsList -Name "--home"
$apply = [bool](Get-AhoArg -ArgsList $argsList -Name "--apply" -Switch)
$confirmed = [bool](Get-AhoArg -ArgsList $argsList -Name "--confirmed" -Switch)
$onlyMissing = [bool](Get-AhoArg -ArgsList $argsList -Name "--only-missing" -Switch)
$force = [bool](Get-AhoArg -ArgsList $argsList -Name "--force" -Switch)
$skillName = Get-AhoArg -ArgsList $argsList -Name "--name"
$packName = Get-AhoArg -ArgsList $argsList -Name "--pack"
$jsonOutput = [bool](Get-AhoArg -ArgsList $argsList -Name "--json" -Switch)
$langArg = Get-AhoArg -ArgsList $argsList -Name "--lang"
$subCommand = $null
if ($Command -eq "skill" -and $argsList.Count -ge 1) {
    $subCommand = $argsList[0]
}

# i18n：--lang > AHO_LANG > UI culture（PLAN §10.5）
Set-AhoLang -Lang $langArg

if ($jsonOutput) { Set-AhoJsonMode -Enabled $true }

try {
    if ($AhoDist -and $AhoDist.disabled_commands) {
        $disabledCmds = @($AhoDist.disabled_commands)
        if ($disabledCmds -contains $Command) {
            Write-Error "Command '$Command' is not available in this distribution. This is a public demo release; internal commands are disabled."
            exit 1
        }
    }
    switch -Regex ($Command) {
        '^discover$' {
            if (-not $target) { throw "discover requires --target" }
            $r = Invoke-AhoDiscover -Target $target
            $r | ConvertTo-Json -Depth 6
            exit 0
        }
        '^plan$' {
            if (-not $target) { throw "plan requires --target" }
            $r = Invoke-AhoPlan -Target $target -Profile $profileName
            $r | ConvertTo-Json -Depth 8
            exit 0
        }
        '^install$' {
            if (-not $target) { throw "install requires --target" }
            $r = Invoke-AhoInstall -Target $target -Profile $profileName -Apply:$apply -Confirmed:$confirmed
            $r | ConvertTo-Json -Depth 8
            exit $(if ($null -ne $r.exit_code) { $r.exit_code } else { 0 })
        }
        '^verify$' {
            if (-not $target) { throw "verify requires --target" }
            $r = Invoke-AhoVerify -Target $target
            $r | ConvertTo-Json -Depth 6
            exit $r.exit_code
        }
        '^global-plan$' {
            $r = Invoke-AhoGlobalPlan -HomeRoot $homeRootArg
            $r | ConvertTo-Json -Depth 6
            exit 0
        }
        '^global-setup$' {
            $r = Invoke-AhoGlobalSetup -HomeRoot $homeRootArg -Apply:$apply -Confirmed:$confirmed
            $r | ConvertTo-Json -Depth 8
            exit $(if ($null -ne $r.exit_code) { $r.exit_code } else { 0 })
        }
        '^doctor$' {
            if (-not $target) { throw "doctor requires --target" }
            $r = Invoke-AhoDoctor -Target $target
            $r | ConvertTo-Json -Depth 8
            exit $r.exit_code
        }
        '^scan$' {
            if (-not $target) { throw "scan requires --target" }
            $r = Invoke-AhoScan -Target $target
            $r | ConvertTo-Json -Depth 6
            exit 0
        }
        '^reseed$' {
            if (-not $target) { throw "reseed requires --target" }
            $r = Invoke-AhoReseed -Target $target -Profile $profileName -OnlyMissing:$onlyMissing -Force:$force -Apply:$apply -Confirmed:$confirmed
            $r | ConvertTo-Json -Depth 6
            exit $(if ($null -ne $r.exit_code) { $r.exit_code } else { 0 })
        }
        '^skill$' {
            if ($subCommand -ne "add") { throw "usage: skill add --name <skill> --target <path> [--pack <name>] [--apply] [--confirmed]" }
            if (-not $target) { throw "skill add requires --target" }
            if (-not $skillName) { throw "skill add requires --name" }
            $r = Invoke-AhoSkillAdd -Target $target -Name $skillName -Pack $packName -Apply:$apply -Confirmed:$confirmed
            $r | ConvertTo-Json -Depth 6
            exit 0
        }
        '^matt-setup$' {
            if (-not $target) { throw "matt-setup requires --target" }
            $preset = Get-AhoArg -ArgsList $argsList -Name "--preset"
            if (-not $preset) { $preset = "github" }
            $r = Invoke-AhoMattSetup -Target $target -Preset $preset -Apply:$apply -Confirmed:$confirmed
            $r | ConvertTo-Json -Depth 6
            exit 0
        }
        default {
            Write-Error "Unknown command: $Command"
            Show-AhoHelp
            exit 1
        }
    }
} catch {
    Write-Error $_
    exit 1
}
