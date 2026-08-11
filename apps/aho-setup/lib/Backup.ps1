. (Join-Path $PSScriptRoot "Common.ps1")

function Backup-AhoFile {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string]$BackupSuffix = "bak"
    )
    if (-not (Test-Path -LiteralPath $FilePath)) {
        return $null
    }
    $dir = Split-Path -Parent $FilePath
    $base = [IO.Path]::GetFileNameWithoutExtension($FilePath)
    $ext = [IO.Path]::GetExtension($FilePath)
    $ts = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $backupName = "${base}.${ts}.${BackupSuffix}${ext}"
    $backupPath = Join-Path $dir $backupName
    Copy-Item -LiteralPath $FilePath -Destination $backupPath
    return $backupPath
}

function Backup-AhoDirectory {
    param(
        [Parameter(Mandatory)][string]$DirPath,
        [string]$BackupSuffix = "bak"
    )
    if (-not (Test-Path -LiteralPath $DirPath)) {
        return $null
    }
    $parent = Split-Path -Parent $DirPath
    $name = Split-Path -Leaf $DirPath
    $ts = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $backupName = "${name}.${ts}.${BackupSuffix}"
    $backupPath = Join-Path $parent $backupName
    Copy-Item -LiteralPath $DirPath -Destination $backupPath -Recurse
    return $backupPath
}
