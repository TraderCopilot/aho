# aho-setup common helpers - PLAN v1.2 lifecycle

$script:AhoSetupRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$script:AhoRepoRoot = Split-Path -Parent (Split-Path -Parent $script:AhoSetupRoot)
$script:AhoYourProject = Join-Path $script:AhoRepoRoot "your-project"
$script:AhoGlobalTemplate = Join-Path $script:AhoRepoRoot "Global"
$script:AhoProfilesDir = Join-Path $script:AhoSetupRoot "profiles"
$script:AhoPacksDir = Join-Path $script:AhoSetupRoot "packs"

function Get-AhoRepoRoot { return $script:AhoRepoRoot }
function Get-AhoYourProject { return $script:AhoYourProject }
function Get-AhoGlobalTemplate { return $script:AhoGlobalTemplate }
function Get-AhoProfilesDir { return $script:AhoProfilesDir }
function Get-AhoPacksDir { return $script:AhoPacksDir }

function Resolve-AhoPath {
    param([Parameter(Mandatory)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "Path is empty" }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        $resolved = [System.IO.Path]::GetFullPath($Path)
    } else {
        $resolved = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
    }
    $protected = @(
        [System.Environment]::GetFolderPath('Windows'),
        [System.Environment]::GetFolderPath('ProgramFiles'),
        [System.Environment]::GetFolderPath('ProgramFilesX86')
    )
    foreach ($p in $protected) {
        if ([string]::IsNullOrEmpty($p)) { continue }
        if ($resolved.StartsWith($p, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to write to system directory: $resolved"
        }
    }
    return $resolved
}

function New-AhoExecutionContext {
    param(
        [Parameter(Mandatory)][string]$TargetRoot,
        [string]$HomeRoot,
        [switch]$AllowRealHome
    )
    $resolvedTarget = [System.IO.Path]::GetFullPath($TargetRoot)
    $resolvedHome = if ([string]::IsNullOrWhiteSpace($HomeRoot)) {
        Get-AhoHomePath
    } else {
        [System.IO.Path]::GetFullPath($HomeRoot)
    }
    return [pscustomobject]@{
        TargetRoot    = $resolvedTarget
        HomeRoot      = $resolvedHome
        AllowRealHome = [bool]$AllowRealHome
    }
}

function Resolve-AhoContainedPath {
    param(
        [Parameter(Mandatory)][string]$ChildPath,
        [Parameter(Mandatory)][string]$RootPath,
        [string]$ContextLabel = "path"
    )
    if ([string]::IsNullOrWhiteSpace($ChildPath)) {
        throw "AHO_PATH_VIOLATION: $ContextLabel is empty"
    }
    $normalizedRoot = [System.IO.Path]::GetFullPath($RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    if ([System.IO.Path]::IsPathRooted($ChildPath)) {
        $resolved = [System.IO.Path]::GetFullPath($ChildPath)
    } else {
        $combined = [System.IO.Path]::Combine($normalizedRoot, $ChildPath)
        $resolved = [System.IO.Path]::GetFullPath($combined)
    }
    $normalizedRootWithSep = $normalizedRoot + [System.IO.Path]::DirectorySeparatorChar
    if ($resolved -ne $normalizedRoot -and -not $resolved.StartsWith($normalizedRootWithSep, [StringComparison]::OrdinalIgnoreCase)) {
        throw "AHO_PATH_VIOLATION: $ContextLabel resolves outside root (root=$normalizedRoot child=$resolved)"
    }
    $rootDrive = [System.IO.Path]::GetPathRoot($normalizedRoot)
    $childDrive = [System.IO.Path]::GetPathRoot($resolved)
    if ([string]::IsNullOrEmpty($rootDrive) -or [string]::IsNullOrEmpty($childDrive) -or
        -not $rootDrive.Equals($childDrive, [StringComparison]::OrdinalIgnoreCase)) {
        throw "AHO_PATH_VIOLATION: $ContextLabel crosses drive boundary (root=$rootDrive child=$childDrive)"
    }
    if ($ChildPath -match '\.\.') {
        $segments = $ChildPath -split '[\\/]'
        $depth = 0
        foreach ($seg in $segments) {
            if ($seg -eq '..') { $depth-- } elseif ($seg -ne '' -and $seg -ne '.') { $depth++ }
        }
        if ($depth -lt 0) {
            throw "AHO_PATH_VIOLATION: $ContextLabel contains path traversal (..)"
        }
    }
    return $resolved
}

function Get-AhoVersion {
    $versionFile = Join-Path $script:AhoRepoRoot "VERSION"
    if (Test-Path -LiteralPath $versionFile) {
        return (Get-Content -LiteralPath $versionFile -Encoding UTF8).Trim()
    }
    return "0.0.0-unknown"
}

function Get-AhoHomePath {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return [System.IO.Path]::GetFullPath($env:USERPROFILE)
    }
    if (-not [string]::IsNullOrWhiteSpace($env:HOME)) {
        return [System.IO.Path]::GetFullPath($env:HOME)
    }
    throw "Cannot determine home directory: both USERPROFILE and HOME are empty"
}

function Test-AhoWriteAllowed {
    param(
        [switch]$Apply,
        [switch]$Confirmed
    )
    return [bool]($Apply -and $Confirmed)
}

$script:AhoJsonMode = $false

function Set-AhoJsonMode { param([bool]$Enabled) $script:AhoJsonMode = $Enabled }
function Get-AhoJsonMode { return $script:AhoJsonMode }

function Write-AhoInfo { param([string]$Message) if (-not $script:AhoJsonMode) { Write-Host "[aho] $Message" } }
function Write-AhoWarn { param([string]$Message) Write-Warning "[aho] $Message" }

function Write-AhoI18nInfo {
    param(
        [Parameter(Mandatory)][string]$Key,
        [object[]]$FormatArgs
    )
    if (-not (Get-Command 'Get-AhoText' -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot "I18n.ps1")
    }
    $text = Get-AhoText -Key $Key -FormatArgs $FormatArgs
    Write-AhoInfo $text
}

function Write-AhoI18nWarn {
    param(
        [Parameter(Mandatory)][string]$Key,
        [object[]]$FormatArgs
    )
    if (-not (Get-Command 'Get-AhoText' -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot "I18n.ps1")
    }
    $text = Get-AhoText -Key $Key -FormatArgs $FormatArgs
    Write-AhoWarn $text
}

function Get-AhoSimpleYamlMap {
    param([Parameter(Mandatory)][string]$FilePath)
    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw "YAML not found: $FilePath"
    }
    $map = @{}
    $currentListKey = $null
    foreach ($raw in Get-Content -LiteralPath $FilePath -Encoding UTF8) {
        $line = $raw
        if ($line -match '^\s*#' -or $line.Trim() -eq '') { continue }
        if ($line -match '^\s*-\s+(.+)$' -and $currentListKey) {
            if (-not $map.ContainsKey($currentListKey)) { $map[$currentListKey] = @() }
            $listVal = $Matches[1].Trim().Trim('"').Trim("'")
            $dq = [char]34
            $sq = [char]39
            if ($Matches[1].Trim() -notmatch "^[$dq$sq]") {
                $listVal = $listVal -replace '\s+#.*$', ''
            }
            $map[$currentListKey] += $listVal
            continue
        }
        if ($line -match '^\s*([A-Za-z0-9_-]+)\s*:\s*(.*)$') {
            $key = $Matches[1]
            $rawVal = $Matches[2].Trim()
            if ($rawVal -eq '') {
                $currentListKey = $key
                $map[$key] = @()
            } else {
                $currentListKey = $null
                $dq = [char]34
                $sq = [char]39
                $isQuoted = $rawVal -match "^[$dq$sq]"
                $val = $rawVal.Trim('"').Trim("'")
                if (-not $isQuoted) {
                    $val = $val -replace '\s+#.*$', ''
                }
                $map[$key] = $val
            }
        }
    }
    return $map
}

function Copy-AhoDirectoryContents {
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][string]$DestDir,
        [switch]$NoOverwrite
    )
    if (-not (Test-Path -LiteralPath $SourceDir)) {
        throw "Source missing: $SourceDir"
    }
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    Get-ChildItem -LiteralPath $SourceDir -Force | ForEach-Object {
        $destItem = Join-Path $DestDir $_.Name
        if ($_.PSIsContainer) {
            Copy-AhoDirectoryContents -SourceDir $_.FullName -DestDir $destItem -NoOverwrite:$NoOverwrite
        } else {
            if ($NoOverwrite -and (Test-Path -LiteralPath $destItem)) {
                return
            }
            Copy-Item -LiteralPath $_.FullName -Destination $destItem -Force:(-not $NoOverwrite)
        }
    }
}

function New-AhoJunctionOrCopy {
    param(
        [Parameter(Mandatory)][string]$LinkPath,
        [Parameter(Mandatory)][string]$TargetPath
    )
    $parent = Split-Path -Parent $LinkPath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (Test-Path -LiteralPath $LinkPath) {
        $item = Get-Item -LiteralPath $LinkPath -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $actualTarget = Resolve-AhoJunctionTarget -LinkPath $LinkPath
            $normActual = if ($null -ne $actualTarget) { $actualTarget.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) } else { $null }
            $normExpected = [System.IO.Path]::GetFullPath($TargetPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
            $isCorrect = ($null -ne $normActual) -and $normActual.Equals($normExpected, [StringComparison]::OrdinalIgnoreCase)
            if (-not $isCorrect) {
                return @{ mode = "wrong_target"; path = $LinkPath; target = $TargetPath; actual_target = "$actualTarget"; existed = $true }
            }
            return @{ mode = "junction"; path = $LinkPath; target = $TargetPath; existed = $true }
        }
        return @{ mode = "existing-solid"; path = $LinkPath; target = $TargetPath; existed = $true }
    }
    $isWindowsEnv = ($IsWindows -eq $true) -or ($env:OS -eq 'Windows_NT') -or ($PSVersionTable.Platform -eq 'Win32NT') -or ([System.Environment]::OSVersion.Platform -eq 'Win32NT')
    if ($isWindowsEnv) {
        try {
            $null = cmd /c mklink /J ("`"" + $LinkPath + "`"") ("`"" + $TargetPath + "`"") 2>&1
            if (-not (Test-Path -LiteralPath $LinkPath)) { throw "mklink failed" }
            return @{ mode = "junction"; path = $LinkPath; target = $TargetPath; existed = $false }
        } catch {
            try {
                [System.IO.Directory]::CreateSymbolicLink($LinkPath, $TargetPath) | Out-Null
                if (Test-Path -LiteralPath $LinkPath) {
                    return @{ mode = "junction"; path = $LinkPath; target = $TargetPath; existed = $false }
                }
            } catch { Write-AhoWarn "New-AhoJunctionOrCopy: mklink failed, falling back to copy" }
            Copy-AhoDirectoryContents -SourceDir $TargetPath -DestDir $LinkPath -NoOverwrite
            return @{ mode = "copy"; path = $LinkPath; target = $TargetPath; existed = $false; error = "$_" }
        }
    } else {
        try {
            [System.IO.Directory]::CreateSymbolicLink($LinkPath, $TargetPath) | Out-Null
            if (Test-Path -LiteralPath $LinkPath) {
                return @{ mode = "junction"; path = $LinkPath; target = $TargetPath; existed = $false }
            }
        } catch { Write-AhoWarn "New-AhoJunctionOrCopy: symlink failed, falling back to copy" }
        Copy-AhoDirectoryContents -SourceDir $TargetPath -DestDir $LinkPath -NoOverwrite
        return @{ mode = "copy"; path = $LinkPath; target = $TargetPath; existed = $false; error = "symlink_unavailable" }
    }
}

function Test-AhoIsReparsePoint {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force
    return [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Resolve-AhoJunctionTarget {
    param([Parameter(Mandatory)][string]$LinkPath)
    if (-not (Test-Path -LiteralPath $LinkPath)) { return $null }
    $item = Get-Item -LiteralPath $LinkPath -Force
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $null }
    $targetDir = $item.Target
    if ($null -eq $targetDir) { return $null }
    $rawTarget = if ($targetDir -is [array]) { $targetDir[0] } else { $targetDir }
    if ([string]::IsNullOrWhiteSpace($rawTarget)) { return $null }
    if ([System.IO.Path]::IsPathRooted($rawTarget)) {
        return [System.IO.Path]::GetFullPath($rawTarget)
    }
    $parentDir = Split-Path -Parent $LinkPath
    return [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($parentDir, $rawTarget))
}

function Write-AhoJsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Object,
        [string]$RootPath,
        [switch]$SkipIdentical,
        [switch]$CreateBackup
    )
    $json = $Object | ConvertTo-Json -Depth 8
    $cfParams = @{
        Path    = $Path
        Content = $json
    }
    if ($RootPath) { $cfParams['RootPath'] = $RootPath }
    if ($SkipIdentical) { $cfParams['SkipIdentical'] = $true }
    if ($CreateBackup) { $cfParams['CreateBackup'] = $true }
    $result = Write-AhoContentFile @cfParams
    if ($SkipIdentical -or $CreateBackup -or $RootPath) {
        return $result
    }
}

function Write-AhoContentFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content,
        [string]$RootPath,
        [switch]$SkipIdentical,
        [switch]$CreateBackup
    )
    if ($RootPath) {
        $resolvedPath = Resolve-AhoContainedPath -ChildPath $Path -RootPath $RootPath -ContextLabel "write_content"
    } else {
        $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    }
    if ($SkipIdentical -and (Test-Path -LiteralPath $resolvedPath)) {
        $existing = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8
        if ($existing -eq $Content) {
            return @{ action = "skipped_identical"; path = $resolvedPath }
        }
    }
    $dir = Split-Path -Parent $resolvedPath
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if ($CreateBackup -and (Test-Path -LiteralPath $resolvedPath)) {
        $ts = (Get-Date).ToString("yyyyMMdd-HHmmss")
        $bakPath = "$resolvedPath.$ts.bak"
        Copy-Item -LiteralPath $resolvedPath -Destination $bakPath
    }
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    $tempPath = $resolvedPath + ".tmp"
    [System.IO.File]::WriteAllText($tempPath, $Content, $utf8NoBom)
    Move-Item -LiteralPath $tempPath -Destination $resolvedPath -Force
    return @{ action = "created"; path = $resolvedPath }
}

function Read-AhoJsonFile {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return $raw | ConvertFrom-Json
}
