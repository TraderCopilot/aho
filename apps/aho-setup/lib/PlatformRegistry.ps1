. (Join-Path $PSScriptRoot "Common.ps1")

function Get-AhoPlatformsDir {
    return Join-Path $script:AhoSetupRoot "platforms"
}

function Get-AhoPlatformYamlFiles {
    param(
        [string]$Target,
        [string]$HomeRoot
    )
    $dirs = @((Get-AhoPlatformsDir))
    if ($Target) {
        $projOverride = Join-Path $Target ".aho\platforms"
        if (Test-Path -LiteralPath $projOverride) { $dirs += $projOverride }
    }
    if ($HomeRoot) {
        $globalOverride = Join-Path $HomeRoot ".aho\platforms"
        if (Test-Path -LiteralPath $globalOverride) { $dirs += $globalOverride }
    }
    if ($HomeRoot) {
        $globalOverride = Join-Path $HomeRoot ".aho\platforms"
        if (Test-Path -LiteralPath $globalOverride) { $dirs += $globalOverride }
    } else {
        $homeProfile = Get-AhoHomePath
        $userGlobal = Join-Path $homeProfile ".aho\platforms"
        if (Test-Path -LiteralPath $userGlobal) { $dirs += $userGlobal }
    }

    $files = @()
    foreach ($d in $dirs) {
        if (Test-Path -LiteralPath $d) {
            $files += @(Get-ChildItem -LiteralPath $d -Filter "*.yaml" -File | Where-Object {
                $_.Name -ne '_schema.yaml'
            })
        }
    }
    return $files
}

function Read-AhoPlatformYaml {
    param([Parameter(Mandatory)][string]$FilePath)
    $map = Get-AhoSimpleYamlMap -FilePath $FilePath
    if (-not $map.ContainsKey('name')) {
        $baseName = [IO.Path]::GetFileNameWithoutExtension($FilePath)
        $map['name'] = $baseName
    }
    if (-not $map.ContainsKey('status')) {
        $map['status'] = 'stable'
    }
    foreach ($listKey in @(
        'project_root_templates',
        'global_root_templates',
        'global_settings',
        'project_dirs'
    )) {
        if (-not $map.ContainsKey($listKey)) {
            $map[$listKey] = @()
        }
    }
    return $map
}

function Get-AhoPlatformRegistry {
    param(
        [string]$Target,
        [string]$HomeRoot
    )
    $files = Get-AhoPlatformYamlFiles -Target $Target -HomeRoot $HomeRoot
    $registry = @{}
    foreach ($f in $files) {
        $plat = Read-AhoPlatformYaml -FilePath $f.FullName
        $name = $plat['name']
        if ($registry.ContainsKey($name)) {
            $existing = $registry[$name]
            $existingSrc = if ($existing.ContainsKey('_source_dir')) { $existing['_source_dir'] } else { 'unknown' }
            $newSrc = $f.DirectoryName
            if ($newSrc -ne $existingSrc) {
                $registry[$name] = $plat
                $plat['_source_dir'] = $newSrc
                $plat['_source_file'] = $f.FullName
            }
        } else {
            $plat['_source_dir'] = $f.DirectoryName
            $plat['_source_file'] = $f.FullName
            $registry[$name] = $plat
        }
    }
    return $registry
}

function Get-AhoPlatform {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Target,
        [string]$HomeRoot
    )
    $registry = Get-AhoPlatformRegistry -Target $Target -HomeRoot $HomeRoot
    if ($registry.ContainsKey($Name)) {
        return $registry[$Name]
    }
    return $null
}

function Get-AhoActivePlatforms {
    param(
        [string]$Target,
        [string]$HomeRoot
    )
    $registry = Get-AhoPlatformRegistry -Target $Target -HomeRoot $HomeRoot
    $active = @()
    foreach ($name in $registry.Keys) {
        $plat = $registry[$name]
        $status = $plat['status']
        if ($status -ne 'disabled') {
            $active += $plat
        }
    }
    return $active
}

function Get-AhoPlatformsForInstall {
    param(
        [string]$Target,
        [string]$HomeRoot
    )
    $registry = Get-AhoPlatformRegistry -Target $Target -HomeRoot $HomeRoot
    $result = @()
    foreach ($name in $registry.Keys) {
        $plat = $registry[$name]
        $status = $plat['status']
        if ($status -eq 'stub' -or $status -eq 'disabled') { continue }
        if (-not $plat.ContainsKey('project_projection_to')) { continue }
        $result += $plat
    }
    return $result
}

function Get-AhoPlatformsForScan {
    param(
        [string]$Target,
        [string]$HomeRoot
    )
    $registry = Get-AhoPlatformRegistry -Target $Target -HomeRoot $HomeRoot
    $result = @()
    foreach ($name in $registry.Keys) {
        $plat = $registry[$name]
        $status = $plat['status']
        if ($status -eq 'disabled') { continue }
        if (-not $plat.ContainsKey('project_projection_to')) { continue }
        $result += $plat
    }
    return $result
}

function Get-AhoPlatformsForGlobalSetup {
    param(
        [string]$Target,
        [string]$HomeRoot
    )
    $registry = Get-AhoPlatformRegistry -Target $Target -HomeRoot $HomeRoot
    $result = @()
    foreach ($name in $registry.Keys) {
        $plat = $registry[$name]
        $status = $plat['status']
        if ($status -eq 'stub' -or $status -eq 'disabled') { continue }
        $hasGlobalSettings = ($plat.ContainsKey('global_settings') -and $plat['global_settings'].Count -gt 0)
        $hasGlobalTemplates = ($plat.ContainsKey('global_root_templates') -and $plat['global_root_templates'].Count -gt 0)
        $hasGlobalProjection = ($plat.ContainsKey('global_projection_to'))
        if ($hasGlobalSettings -or $hasGlobalTemplates -or $hasGlobalProjection) {
            $result += $plat
        }
    }
    return $result
}

function Resolve-AhoPlatformPlaceholder {
    param(
        [Parameter(Mandatory)][string]$Value,
        [string]$HomeRoot
    )
    $result = $Value
    $homePath = if ([string]::IsNullOrWhiteSpace($HomeRoot)) {
        Get-AhoHomePath
    } else {
        [System.IO.Path]::GetFullPath($HomeRoot)
    }
    $docsPath = [System.IO.Path]::Combine($homePath, 'Documents')
    $result = $result -replace '\{\{HOME\}\}', $homePath
    $result = $result -replace '\{\{HOME_DOCUMENTS\}\}', $docsPath
    return $result
}

function Get-AhoPlatformList {
    param(
        [string]$Target,
        [string]$HomeRoot
    )
    $registry = Get-AhoPlatformRegistry -Target $Target -HomeRoot $HomeRoot
    $list = @()
    foreach ($name in $registry.Keys) {
        $plat = $registry[$name]
        $list += [pscustomobject]@{
            name         = $name
            display_name = $plat['display_name']
            status       = $plat['status']
            projection   = $plat['project_projection_to']
        }
    }
    return $list
}
