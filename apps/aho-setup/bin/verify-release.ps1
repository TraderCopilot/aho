#requires -Version 5.1
<#
.SYNOPSIS
  Extended release tree scanner: path blocklist + content scan + manifest verify.
  Reports only "file path + rule ID", never echoes suspected secret content.
  Fail-closed: any hit causes exit 1.
.EXAMPLE
  .\verify-release.ps1
  .\verify-release.ps1 -Root C:\release
#>
param(
    [string]$Root = ""
)

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
}

$ErrorActionPreference = "Stop"
$exitCode = 0
$hits = @()

function Add-Hit([string]$Path, [string]$RuleId) {
    $script:hits += "$RuleId`t$Path"
}

$pathBlocklist = @(
    ".env", ".ssh/", "__pycache__", ".pytest_cache", "node_modules/",
    "docs/audit/", "docs/plans/", "docs/tasks/",
    "NEXT-SESSION-PROMPT.md", "GROK-NEXT-SESSION-PROMPT.md",
    "official-mirrors/", "safe-push.ps1", "safe-backup-push.ps1",
    ".codeartsdoer/", ".staging/", ".backup-previous/",
    ".aho-release-marker", "file-index.db", "upload_state.json"
)

$contentRules = @(
    @{ Id = "KEY-OPENSSH"; Pattern = "BEGIN OPENSSH PRIVATE KEY" },
    @{ Id = "KEY-RSA";     Pattern = "BEGIN RSA PRIVATE KEY" },
    @{ Id = "KEY-EC";      Pattern = "BEGIN EC PRIVATE KEY" },
    @{ Id = "KEY-PGP";     Pattern = "BEGIN PGP PRIVATE KEY BLOCK" },
    @{ Id = "TOKEN-SK";    Pattern = "(?i)sk-(ant-)?[a-zA-Z0-9_-]{10,}" },
    @{ Id = "TOKEN-GHP";   Pattern = "gh[pousr]_[a-zA-Z0-9]{20,}" },
    @{ Id = "TOKEN-BEARER"; Pattern = "(?i)Bearer\s+[a-zA-Z0-9._-]{20,}" },
    @{ Id = "TOKEN-X-OSS";  Pattern = "(?i)xox[baprs]-[a-zA-Z0-9-]{10,}" },
    @{ Id = "TOKEN-GLAB";   Pattern = "glpat-[a-zA-Z0-9_-]{20,}" },
    @{ Id = "PATH-WIN";     Pattern = "[A-Z]:\\Users\\" },
    @{ Id = "PATH-WIN-PROJ"; Pattern = "H:\\myProjects\\" },
    @{ Id = "PATH-UNIX";    Pattern = "/Users/[a-z]" },
    @{ Id = "EMAIL-PERSONAL"; Pattern = "[a-z]+\.[a-z]+@(?!example\.com|users\.noreply\.github\.com)[a-z]+\.[a-z]+" }
)

Write-Host "[verify-release] Scanning $Root"

$contentWhitelist = @(
    "SECURITY.md",
    "docs/SECURITY.md",
    "apps/aho-setup/bin/verify-release.ps1",
    "apps/aho-setup/bin/rebuild-manifest.ps1",
    "apps/aho-setup/bin/pack-release.ps1"
)

$gitignorePath = Join-Path $Root ".gitignore"
$gitignorePatterns = @()
if (Test-Path -LiteralPath $gitignorePath) {
    $gitignorePatterns = @(Get-Content -LiteralPath $gitignorePath -Encoding UTF8 |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") })
}

function Test-Gitignored([string]$RelPath, [string[]]$Patterns) {
    $norm = $RelPath -replace "/", "\"
    foreach ($p in $Patterns) {
        $pn = $p -replace "/", "\"
        if ($pn.EndsWith("\")) { $pn = $pn.TrimEnd("\") }
        if ($norm -like "*$pn\*" -or $norm -like "$pn*") { return $true }
    }
    return $false
}

$allFiles = Get-ChildItem -Path $Root -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object {
        $rel = $_.FullName.Substring($Root.Length + 1) -replace "\\", "/"
        $rel -notlike ".git/*" -and
        -not (Test-Gitignored -RelPath $rel -Patterns $gitignorePatterns)
    }

foreach ($f in $allFiles) {
    $rel = $f.FullName.Substring($Root.Length + 1) -replace "\\", "/"

    $isWhitelisted = $false
    foreach ($w in $contentWhitelist) {
        if ($rel -eq $w) { $isWhitelisted = $true; break }
    }

    foreach ($b in $pathBlocklist) {
        $bn = $b -replace "/", "\"
        if ($f.FullName -like "*$bn*" -or $f.Name -eq ($b -replace "/", "\")) {
            if (-not $isWhitelisted) { Add-Hit -Path $rel -RuleId "BLK-PATH" }
            continue
        }
    }

    if ($isWhitelisted) { continue }

    try {
        $text = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
        if ($null -eq $text) { continue }

        foreach ($rule in $contentRules) {
            if ($text -match $rule.Pattern) {
                Add-Hit -Path $rel -RuleId $rule.Id
            }
        }
    } catch { }
}

$manifestPath = Join-Path $Root "RELEASE-MANIFEST.json"
if (Test-Path -LiteralPath $manifestPath) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

    $manifestPaths = @($manifest.files | ForEach-Object { $_.path })
    $actualPaths = @($allFiles | Where-Object {
        $skip = $false
        $rel2 = $_.FullName.Substring($Root.Length + 1) -replace "\\", "/"
        foreach ($b in $pathBlocklist) {
            $bn = $b -replace "/", "\"
            if ($_.FullName -like "*$bn*" -or $_.Name -eq ($b -replace "/", "\")) { $skip = $true; break }
        }
        if (-not $skip -and $rel2 -eq "RELEASE-MANIFEST.json") { $skip = $true }
        -not $skip
    } | ForEach-Object { $_.FullName.Substring($Root.Length + 1) -replace "\\", "/" })

    $missing = $manifestPaths | Where-Object { $_ -notin $actualPaths }
    $extra = $actualPaths | Where-Object { $_ -notin $manifestPaths }

    foreach ($m in $missing) { Add-Hit -Path $m -RuleId "MAN-MISSING" }
    foreach ($e in $extra) { Add-Hit -Path $e -RuleId "MAN-EXTRA" }

    foreach ($entry in $manifest.files) {
        $fullPath = Join-Path $Root ($entry.path -replace "/", "\")
        if (Test-Path -LiteralPath $fullPath) {
            $actualHash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
            if ($actualHash -ne $entry.sha256) {
                Add-Hit -Path $entry.path -RuleId "MAN-HASH-MISMATCH"
            }
        }
    }
} else {
    Add-Hit -Path "RELEASE-MANIFEST.json" -RuleId "MAN-NOT-FOUND"
}

if ($hits.Count -gt 0) {
    Write-Host "[verify-release] FAILED: $($hits.Count) hit(s)"
    Write-Host "rule_id`tfile_path"
    $hits | ForEach-Object { Write-Host $_ }
    $exitCode = 1
} else {
    Write-Host "[verify-release] PASS: 0 hits"
}

exit $exitCode
