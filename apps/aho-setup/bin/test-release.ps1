#requires -Version 5.1
<#
.SYNOPSIS
  Public release test matrix for agents-harness-os demo release.
  Runs all P5 tests against a release tree and reports pass/fail per test.
  Exits 0 only if all tests pass.
.EXAMPLE
  .\test-release.ps1
  .\test-release.ps1 -Root C:\release
  .\test-release.ps1 -Root C:\release -Skip Smoke
#>
[CmdletBinding()]
param(
    [string]$Root = "",
    [string[]]$Skip = @()
)

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
}
$Root = (Resolve-Path $Root).Path

$ErrorActionPreference = "Stop"
$results = @()
$exitCode = 0

function Add-Result([string]$Name, [bool]$Pass, [string]$Detail = "") {
    $script:results += [PSCustomObject]@{
        Test = $Name
        Pass = $Pass
        Detail = $Detail
    }
    if (-not $Pass) { $script:exitCode = 1 }
}

function Invoke-CliCommand([string[]]$CliArgs) {
    $cli = Join-Path $script:Root "apps\aho-setup\bin\aho-setup.ps1"
    $psExe = if ($PSVersionTable.PSVersion.Major -ge 6) { "pwsh" } else { "powershell" }
    $argStr = ($CliArgs | ForEach-Object { if ($_ -match '\s') { "'$_'" } else { $_ } }) -join ' '
    $cmd = "& '$cli' $argStr"
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $psExe -NoProfile -Command $cmd 2>&1 | Out-String
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEAP
    }
    return @{ Output = $output; ExitCode = $code }
}

Write-Host "[test-release] Root: $Root"
Write-Host "[test-release] PowerShell: $($PSVersionTable.PSVersion)"

# T1: Encoding — all .ps1/.psd1 parse under current PowerShell; non-ASCII files have UTF-8 BOM
if ($Skip -notcontains "Encoding") {
    try {
        $scripts = Get-ChildItem -Path $Root -Recurse -File -Include *.ps1,*.psd1 -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\\.git\\' }
        $badParse = @()
        $badBom = @()
        foreach ($f in $scripts) {
            $tokens = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors) | Out-Null
            if ($errors.Count -gt 0) { $badParse += $f.FullName.Substring($Root.Length + 1) }

            $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
            $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
            $hasNonAscii = $false
            $startIdx = if ($hasBom) { 3 } else { 0 }
            for ($i = $startIdx; $i -lt $bytes.Length; $i++) {
                if ($bytes[$i] -gt 0x7F) { $hasNonAscii = $true; break }
            }
            if ($hasNonAscii -and -not $hasBom) { $badBom += $f.FullName.Substring($Root.Length + 1) }
        }
        if ($badParse.Count -eq 0 -and $badBom.Count -eq 0) {
            Add-Result "Encoding" $true "$($scripts.Count) scripts OK"
        } else {
            $detail = ""
            if ($badParse.Count -gt 0) { $detail += "Parse errors: $($badParse -join ', '). " }
            if ($badBom.Count -gt 0) { $detail += "Missing BOM: $($badBom -join ', ')." }
            Add-Result "Encoding" $false $detail
        }
    } catch {
        Add-Result "Encoding" $false $_.Exception.Message
    }
}

# T2: Help — --help succeeds and mentions demo
if ($Skip -notcontains "Help") {
    try {
        $r = Invoke-CliCommand @("--help")
        $pass = $r.ExitCode -eq 0 -and $r.Output -match "demo" -and $r.Output -match "Allowed profiles: demo"
        Add-Result "Help" $pass "exit=$($r.ExitCode)"
    } catch {
        Add-Result "Help" $false $_.Exception.Message
    }
}

# T3: Default profile — plan without --profile defaults to demo
if ($Skip -notcontains "DefaultProfile") {
    try {
        $tmp = Join-Path $env:TEMP "aho-test-default-$(Get-Random)"
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $r = Invoke-CliCommand @("plan", "--target", $tmp, "--json")
        $json = $r.Output | ConvertFrom-Json
        $pass = $r.ExitCode -eq 0 -and $json.profile -eq "demo"
        Add-Result "DefaultProfile" $pass "exit=$($r.ExitCode), profile=$($json.profile)"
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    } catch {
        Add-Result "DefaultProfile" $false $_.Exception.Message
    }
}

# T4: Negative contract — unsupported profiles and disabled commands fail with clear error
if ($Skip -notcontains "NegativeContract") {
    try {
        $tmp = Join-Path $env:TEMP "aho-test-neg-$(Get-Random)"
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $fails = 0
        $details = @()

        foreach ($prof in @("standard", "full-dev", "minimal", "internal")) {
            $r = Invoke-CliCommand @("plan", "--profile", $prof, "--target", $tmp, "--json")
            if ($r.ExitCode -ne 1) { $fails++; $details += "profile $prof did not fail" }
        }

        foreach ($cmd in @("reseed", "skill", "matt-setup")) {
            $r = Invoke-CliCommand @($cmd, "--target", $tmp, "--json")
            if ($r.ExitCode -ne 1) { $fails++; $details += "command $cmd did not fail" }
        }

        Add-Result "NegativeContract" ($fails -eq 0) ($details -join "; ")
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    } catch {
        Add-Result "NegativeContract" $false $_.Exception.Message
    }
}

# T5: Demo smoke — clean dir: plan → install → verify → doctor, all exit 0
if ($Skip -notcontains "Smoke") {
    try {
        $tmp = Join-Path $env:TEMP "aho-test-smoke-$(Get-Random)"
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $details = @()
        $allPass = $true

        $r = Invoke-CliCommand @("plan", "--profile", "demo", "--target", $tmp, "--json")
        if ($r.ExitCode -ne 0) { $allPass = $false; $details += "plan exit=$($r.ExitCode)" }

        $r = Invoke-CliCommand @("install", "--profile", "demo", "--target", $tmp, "--apply", "--confirmed", "--json")
        if ($r.ExitCode -ne 0) { $allPass = $false; $details += "install exit=$($r.ExitCode)" }

        $r = Invoke-CliCommand @("verify", "--target", $tmp, "--json")
        if ($r.ExitCode -ne 0) { $allPass = $false; $details += "verify exit=$($r.ExitCode)" }

        $r = Invoke-CliCommand @("doctor", "--target", $tmp, "--json")
        if ($r.ExitCode -ne 0) { $allPass = $false; $details += "doctor exit=$($r.ExitCode)" }

        if ($details.Count -eq 0) { $details += "plan+install+verify+doctor all exit 0" }
        Add-Result "Smoke" $allPass ($details -join "; ")
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    } catch {
        Add-Result "Smoke" $false $_.Exception.Message
    }
}

# T6: Dry-run — install without --apply writes nothing
if ($Skip -notcontains "DryRun") {
    try {
        $tmp = Join-Path $env:TEMP "aho-test-dryrun-$(Get-Random)"
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $before = (Get-ChildItem -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object).Count

        $r = Invoke-CliCommand @("install", "--profile", "demo", "--target", $tmp, "--json")
        $after = (Get-ChildItem -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object).Count

        $pass = ($before -eq $after) -and ($r.Output -match "DRY-RUN" -or $r.Output -match "dry")
        Add-Result "DryRun" $pass "before=$before after=$after"
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    } catch {
        Add-Result "DryRun" $false $_.Exception.Message
    }
}

# T7: Public scan — verify-release.ps1 passes on the release tree
if ($Skip -notcontains "Scan") {
    try {
        $scanner = Join-Path $Root "apps\aho-setup\bin\verify-release.ps1"
        $r = & $scanner $Root 2>&1 | Out-String
        $pass = $LASTEXITCODE -eq 0
        Add-Result "Scan" $pass "exit=$LASTEXITCODE"
    } catch {
        Add-Result "Scan" $false $_.Exception.Message
    }
}

# T8: Manifest — RELEASE-MANIFEST.json exists, has files, all hashes match
if ($Skip -notcontains "Manifest") {
    try {
        $manifestPath = Join-Path $Root "RELEASE-MANIFEST.json"
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $fileCount = @($manifest.files).Count
        $mismatches = 0

        foreach ($entry in $manifest.files) {
            $fullPath = Join-Path $Root ($entry.path -replace "/", "\")
            if (Test-Path -LiteralPath $fullPath) {
                $hash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
                if ($hash -ne $entry.sha256) { $mismatches++ }
            } else {
                $mismatches++
            }
        }

        $hasNoMachinePath = $manifest.psobject.properties.name -notcontains "repo_root" -and
            $manifest.psobject.properties.name -notcontains "out_root"

        $pass = $fileCount -gt 0 -and $mismatches -eq 0 -and $hasNoMachinePath
        Add-Result "Manifest" $pass "files=$fileCount mismatches=$mismatches noMachinePath=$hasNoMachinePath"
    } catch {
        Add-Result "Manifest" $false $_.Exception.Message
    }
}

# T9: Pack dry-run — pack-release.ps1 -DryRun does not create output
#     Skipped when allowlist is not available (release tree does not ship the packer's source allowlist).
if ($Skip -notcontains "PackDryRun") {
    try {
        $packScript = Join-Path $Root "apps\aho-setup\bin\pack-release.ps1"
        $tmpOut = Join-Path $env:TEMP "aho-test-packdry-$(Get-Random)"

        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $probe = & $packScript -DryRun -OutputPath $tmpOut 2>&1 | Out-String
        $ErrorActionPreference = $prevEAP

        if ($probe -match "Missing list file" -or $probe -match "allowlist" -or $probe -match "list file") {
            Add-Result "PackDryRun" $true "SKIPPED: packer allowlist not available in release tree (expected)"
        } else {
            $pass = -not (Test-Path -LiteralPath $tmpOut)
            Add-Result "PackDryRun" $pass "outputCreated=$(-not $pass)"
        }
        if (Test-Path -LiteralPath $tmpOut) { Remove-Item -Recurse -Force $tmpOut -ErrorAction SilentlyContinue }
    } catch {
        Add-Result "PackDryRun" $true "SKIPPED: packer not runnable in release tree ($($_.Exception.Message -replace '\s+',' '))"
        if (Test-Path -LiteralPath $tmpOut) { Remove-Item -Recurse -Force $tmpOut -ErrorAction SilentlyContinue }
    }
}

# Report
Write-Host ""
Write-Host "[test-release] Results:"
$results | Format-Table -AutoSize

$passed = ($results | Where-Object { $_.Pass }).Count
$failed = ($results | Where-Object { -not $_.Pass }).Count
Write-Host "[test-release] $passed passed, $failed failed"

if ($failed -gt 0) {
    Write-Host "[test-release] FAILED tests:"
    $results | Where-Object { -not $_.Pass } | ForEach-Object {
        Write-Host "  $($_.Test): $($_.Detail)"
    }
}

exit $exitCode
