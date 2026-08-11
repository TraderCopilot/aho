#requires -Version 5.1
<#
.SYNOPSIS
  Build a clean external release tree from allowlist + public-demo templates.
  Safe packer: dry-run zero-write, controlled CleanOut, staging promotion.

.DESCRIPTION
  Fixes P1阻断项:
    R7: dry-run 不创建任何文件或目录
    R8: -CleanOut 仅允许删除带有 .aho-release-marker 的目录
    路径校验: 绝对路径解析、根目录拒绝、边界校验
    staging: 先写入隔离 staging，验证后提升

.PARAMETER RepoRoot
  Development repo root (source). Defaults to sibling agents-harness-os.

.PARAMETER OutRoot
  Output release tree root. Must NOT be a filesystem root.

.PARAMETER CleanOut
  Remove existing OutRoot before packing. Only allowed if OutRoot contains
  .aho-release-marker file. Without marker, fails with error.

.PARAMETER Confirmed
  Actually write files. Without -Confirmed, pure dry-run (zero filesystem writes).

.PARAMETER SkipSecretScan
  Skip final secret/block scan.

.EXAMPLE
  .\pack-release.ps1 -DryRun
  .\pack-release.ps1 -Confirmed
  .\pack-release.ps1 -Confirmed -CleanOut
#>
param(
    [string]$RepoRoot = "",
    [string]$OutRoot = "",
    [switch]$CleanOut,
    [switch]$Confirmed,
    [switch]$SkipSecretScan
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
}
if ([string]::IsNullOrWhiteSpace($OutRoot)) {
    $OutRoot = Join-Path (Split-Path -Parent $RepoRoot) "agents-harness-os-release"
}

$RELEASE_MARKER = ".aho-release-marker"

function Write-PackLog([string]$Msg, [string]$Level = "INFO") {
    Write-Host "[pack-release][$Level] $Msg"
}

function Assert-SafeOutputPath {
    param([Parameter(Mandatory)][string]$Path)
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue)
    if ($null -eq $resolved) {
        $resolved = (New-Object System.IO.DirectoryInfo($Path)).FullName
    } else {
        $resolved = $resolved.Path
    }
    $root = [System.IO.Path]::GetPathRoot($resolved)
    if ($resolved -eq $root) {
        throw "Refusing to use filesystem root as output: $resolved"
    }
    $parent = [System.IO.Path]::GetDirectoryName($resolved)
    if ([string]::IsNullOrWhiteSpace($parent)) {
        throw "Output path has no parent directory: $resolved"
    }
    return $resolved
}

function Assert-ControlledCleanOut {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $marker = Join-Path $Path $RELEASE_MARKER
    if (-not (Test-Path -LiteralPath $marker)) {
        throw "CleanOut refused: '$Path' lacks '$RELEASE_MARKER'. Only controlled release directories can be cleaned. Add $RELEASE_MARKER manually to confirm this is a release tree."
    }
    Write-PackLog "CleanOut: marker found, proceeding to remove $Path"
}

function Get-ListFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing list file: $Path" }
    Get-Content -LiteralPath $Path -Encoding UTF8 |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") }
}

function Test-Blocked([string]$RelativePath, [string[]]$Blocks) {
    $norm = $RelativePath -replace "/", "\"
    foreach ($b in $Blocks) {
        $bb = ($b.Trim() -replace "/", "\")
        if ([string]::IsNullOrWhiteSpace($bb)) { continue }
        if ($norm -like "*$bb*") { return $true }
    }
    return $false
}

function Copy-AllowEntry {
    param(
        [string]$Rel,
        [string]$RepoRoot,
        [string]$OutRoot,
        [string[]]$Blocks,
        [System.Collections.Generic.List[string]]$Manifest,
        [switch]$Confirmed
    )
    $relNorm = $Rel.Trim().TrimStart("\", "/") -replace "/", "\"
    $src = Join-Path $RepoRoot $relNorm

    $destRel = $relNorm
    if ($relNorm.StartsWith("templates\public-demo\your-project", [System.StringComparison]::OrdinalIgnoreCase)) {
        $destRel = "your-project" + $relNorm.Substring("templates\public-demo\your-project".Length)
    }
    elseif ($relNorm.StartsWith("templates\public-demo\Global", [System.StringComparison]::OrdinalIgnoreCase)) {
        $destRel = "Global" + $relNorm.Substring("templates\public-demo\Global".Length)
    }

    if (-not (Test-Path -LiteralPath $src)) {
        Write-PackLog "SKIP missing source: $relNorm" "WARN"
        return
    }

    if (Test-Path -LiteralPath $src -PathType Leaf) {
        if (Test-Blocked -RelativePath $destRel -Blocks $Blocks) {
            throw "BLOCKLIST hit (file): $destRel"
        }
        $dest = Join-Path $OutRoot $destRel
        $destDir = Split-Path -Parent $dest
        if ($Confirmed) {
            if (-not (Test-Path -LiteralPath $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -LiteralPath $src -Destination $dest -Force
        }
        $Manifest.Add($destRel.Replace("\", "/"))
        return
    }

    $files = Get-ChildItem -LiteralPath $src -Recurse -File -Force
    foreach ($f in $files) {
        $sub = $f.FullName.Substring($src.Length).TrimStart("\", "/")
        $fileDestRel = Join-Path $destRel $sub
        $fileDestRelNorm = $fileDestRel -replace "/", "\"
        if (Test-Blocked -RelativePath $fileDestRelNorm -Blocks $Blocks) {
            throw "BLOCKLIST hit: $fileDestRelNorm"
        }
        $destFile = Join-Path $OutRoot $fileDestRelNorm
        $dd = Split-Path -Parent $destFile
        if ($Confirmed) {
            if (-not (Test-Path -LiteralPath $dd)) {
                New-Item -ItemType Directory -Path $dd -Force | Out-Null
            }
            Copy-Item -LiteralPath $f.FullName -Destination $destFile -Force
        }
        $Manifest.Add(($fileDestRelNorm -replace "\\", "/"))
    }
}

function Invoke-SecretScan([string]$Root, [string[]]$Blocks) {
    if (-not (Test-Path -LiteralPath $Root)) { return }
    $hits = @()
    $files = Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($Root.Length).TrimStart("\", "/")
        if (Test-Blocked -RelativePath $rel -Blocks $Blocks) {
            $hits += "path:$rel"
            continue
        }
        try {
            $text = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
            if ($null -eq $text) { continue }
            if ($text -match "BEGIN (OPENSSH|RSA|EC) PRIVATE KEY") { $hits += "key:$rel" }
            if ($text -match "(?i)sk-[a-zA-Z0-9]{10,}") { $hits += "tokenish:$rel" }
            if ($text -match "(?i)Bearer\s+[a-zA-Z0-9._-]{20,}") { $hits += "bearer:$rel" }
        } catch { }
    }
    if ($hits.Count -gt 0) {
        throw "Secret/block scan failed (reporting path + rule only, no secret content):`n$($hits -join "`n")"
    }
}

# --- main ---
$outResolved = Assert-SafeOutputPath -Path $OutRoot

$allowlistPath = Join-Path $RepoRoot "tools\release\allowlist.txt"
$blocklistPath = Join-Path $RepoRoot "tools\release\blocklist.txt"
$allows = @(Get-ListFile $allowlistPath)
$blocks = @(Get-ListFile $blocklistPath)
$manifest = [System.Collections.Generic.List[string]]::new()

Write-PackLog "RepoRoot=$RepoRoot"
Write-PackLog "OutRoot=$outResolved"
Write-PackLog "Confirmed=$Confirmed CleanOut=$CleanOut"

if ($Confirmed -and $CleanOut -and (Test-Path -LiteralPath $outResolved)) {
    Assert-ControlledCleanOut -Path $outResolved
    Remove-Item -LiteralPath $outResolved -Recurse -Force
}

$stagingDir = Join-Path $outResolved ".staging"

if ($Confirmed) {
    if (-not (Test-Path -LiteralPath $stagingDir)) {
        New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
    }
}

$effectiveOut = if ($Confirmed) { $stagingDir } else { $outResolved }

foreach ($entry in $allows) {
    Copy-AllowEntry -Rel $entry -RepoRoot $RepoRoot -OutRoot $effectiveOut -Blocks $blocks -Manifest $manifest -Confirmed:$Confirmed
}

$verSrc = Join-Path $RepoRoot "VERSION"
if (Test-Path -LiteralPath $verSrc) {
    $verRel = "VERSION"
    if (-not (Test-Blocked -RelativePath $verRel -Blocks $blocks)) {
        if ($Confirmed) {
            Copy-Item -LiteralPath $verSrc -Destination (Join-Path $effectiveOut "VERSION") -Force
        }
        $manifest.Add("VERSION")
    }
}

$readme = @"
# agents-harness-os (public demo release)

**Generated tree - do not hand-edit.**

Source of truth: development repo ``agents-harness-os``
- Public templates: ``templates/public-demo/``
- Pack script: ``apps/aho-setup/bin/pack-release.ps1``

## Quick start

``````powershell
.\apps\aho-setup\bin\aho-setup.ps1 install --profile demo --target <your-project> --apply --confirmed
.\apps\aho-setup\bin\aho-setup.ps1 verify --target <your-project>
.\apps\aho-setup\bin\aho-setup.ps1 doctor --target <your-project>
``````

Internal full templates (standard/full-dev) live only in the development monorepo.
"@
if ($Confirmed) {
    Set-Content -Path (Join-Path $effectiveOut "README.md") -Value $readme -Encoding UTF8
}
$manifest.Add("README.md")

if ($Confirmed -and -not $SkipSecretScan) {
    Write-PackLog "Running secret/block scan on staging..."
    Invoke-SecretScan -Root $stagingDir -Blocks $blocks
    Write-PackLog "Secret scan OK"
}

$manifestPath = if ($Confirmed) { Join-Path $stagingDir "RELEASE-MANIFEST.json" } else { $null }
$payload = [ordered]@{
    product      = "agents-harness-os"
    distribution = "public-demo"
    version      = if (Test-Path -LiteralPath $verSrc) { (Get-Content -LiteralPath $verSrc -Raw).Trim() } else { "unknown" }
    generated_at = (Get-Date).ToString("o")
    confirmed    = [bool]$Confirmed
    file_count   = $manifest.Count
    files        = @($manifest | Sort-Object -Unique)
}
if ($Confirmed) {
    $json = $payload | ConvertTo-Json -Depth 5
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($manifestPath, $json, $utf8)

    Write-PackLog "Staging complete. Promoting to $outResolved ..."

    $backupDir = Join-Path $outResolved ".backup-previous"
    if (Test-Path -LiteralPath $backupDir) {
        Remove-Item -LiteralPath $backupDir -Recurse -Force
    }

    $existingFiles = Get-ChildItem -LiteralPath $outResolved -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne ".staging" -and $_.Name -ne ".backup-previous" }
    if ($existingFiles) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        foreach ($f in $existingFiles) {
            Move-Item -LiteralPath $f.FullName -Destination $backupDir -Force
        }
        Write-PackLog "Previous release backed up to .backup-previous"
    }

    $stagingContents = Get-ChildItem -LiteralPath $stagingDir -Force
    foreach ($item in $stagingContents) {
        Move-Item -LiteralPath $item.FullName -Destination $outResolved -Force
    }
    Remove-Item -LiteralPath $stagingDir -Recurse -Force

    $markerPath = Join-Path $outResolved $RELEASE_MARKER
    Set-Content -LiteralPath $markerPath -Value "agents-harness-os release tree" -Encoding UTF8

    Write-PackLog "Promotion complete. Marker written."
}

Write-PackLog "Files planned/written: $($manifest.Count)"
if (-not $Confirmed) {
    Write-PackLog "Dry-run only (zero writes). Re-run with -Confirmed to write $outResolved" "WARN"
    exit 0
}
Write-PackLog "Done: $outResolved"
exit 0
