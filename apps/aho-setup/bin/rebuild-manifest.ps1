#requires -Version 5.1
$root = $args[0]
if (-not $root) { $root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path }

$excludeDirs = @(".codeartsdoer", ".staging", ".backup-previous", ".git", ".test-dryrun-tmp", ".test-cleanout-tmp", ".aho-release-marker", "node_modules", "__pycache__", ".env", ".ssh", "official-mirrors")
$excludeSubDirs = @("docs\plans", "docs\audit", "docs\tasks")
$excludeFiles = @("RELEASE-MANIFEST.json", "file-index.db", "upload_state.json", "NEXT-SESSION-PROMPT.md", "GROK-NEXT-SESSION-PROMPT.md", "safe-push.ps1", "safe-backup-push.ps1")

$files = Get-ChildItem -Path $root -Recurse -File -Force | Where-Object {
    $skip = $false
    foreach ($d in $excludeDirs) {
        if ($_.FullName -like "*\$d\*" -or $_.Name -eq $d) { $skip = $true; break }
    }
    if (-not $skip) {
        foreach ($d in $excludeSubDirs) {
            if ($_.FullName -like "*\$d\*") { $skip = $true; break }
        }
    }
    if (-not $skip -and $excludeFiles -contains $_.Name) { $skip = $true }
    -not $skip
}

$fileEntries = @()
foreach ($f in $files) {
    $rel = $f.FullName.Substring($root.Length + 1) -replace "\\", "/"
    $hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
    $fileEntries += [pscustomobject]@{ path = $rel; sha256 = $hash }
}

$version = "unknown"
$verPath = Join-Path $root "VERSION"
if (Test-Path -LiteralPath $verPath) {
    $version = (Get-Content -LiteralPath $verPath -Raw).Trim()
}

$manifest = [ordered]@{
    product      = "agents-harness-os"
    distribution = "public-demo"
    version      = $version
    generated_at = (Get-Date).ToString("o")
    file_count   = $fileEntries.Count
    files        = $fileEntries
}

$json = $manifest | ConvertTo-Json -Depth 5
$utf8 = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText((Join-Path $root "RELEASE-MANIFEST.json"), $json, $utf8)

Write-Host "Manifest rebuilt: $($fileEntries.Count) files, version=$version"
