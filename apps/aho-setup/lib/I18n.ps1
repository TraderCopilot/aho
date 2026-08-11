# I18n.ps1 — 声明式语言包：apps/aho-setup/i18n/<culture>.psd1
# 回退链：请求语言 → en-US → key 本身（PLAN §10.5）
# 注意：本文件不 dot-source Common.ps1（避免循环引用）

$script:AhoI18nSetupRoot = Split-Path -Parent $PSScriptRoot

$script:AhoI18nTables = @{}
$script:AhoLang = $null
$script:AhoI18nLoaded = $false

function Get-AhoI18nDir {
    return Join-Path $script:AhoI18nSetupRoot "i18n"
}

function Resolve-AhoLang {
    param(
        [string]$Explicit
    )
    if ($Explicit -and $Explicit.Trim()) {
        return $Explicit.Trim()
    }
    $envLang = [Environment]::GetEnvironmentVariable("AHO_LANG")
    if ($envLang -and $envLang.Trim()) {
        return $envLang.Trim()
    }
    try {
        $cul = [System.Globalization.CultureInfo]::CurrentUICulture.Name
        if ($cul -like "zh*") { return "zh-CN" }
    } catch { Write-Warning "[aho] Get-AhoLang: failed to detect system culture, defaulting to en-US" }
    return "en-US"
}

function Import-AhoI18nTables {
    if ($script:AhoI18nLoaded) { return }
    $dir = Get-AhoI18nDir
    $script:AhoI18nTables = @{}
    if (Test-Path -LiteralPath $dir) {
        Get-ChildItem -LiteralPath $dir -Filter "*.psd1" -File | ForEach-Object {
            $culture = [IO.Path]::GetFileNameWithoutExtension($_.Name)
            try {
                $data = Import-PowerShellDataFile -LiteralPath $_.FullName
                $script:AhoI18nTables[$culture] = $data
            } catch {
                Write-Warning "[aho] Failed to load i18n pack $($_.Name): $_"
            }
        }
    }
    $script:AhoI18nLoaded = $true
}

function Set-AhoLang {
    param([string]$Lang)
    Import-AhoI18nTables
    $script:AhoLang = Resolve-AhoLang -Explicit $Lang
}

function Get-AhoLang {
    if (-not $script:AhoLang) {
        Set-AhoLang -Lang $null
    }
    return $script:AhoLang
}

function Get-AhoText {
    param(
        [Parameter(Mandatory)][string]$Key,
        [object[]]$FormatArgs
    )
    Import-AhoI18nTables
    $lang = Get-AhoLang
    $text = $null
    if ($script:AhoI18nTables.ContainsKey($lang) -and $script:AhoI18nTables[$lang].ContainsKey($Key)) {
        $text = [string]$script:AhoI18nTables[$lang][$Key]
    } elseif ($script:AhoI18nTables.ContainsKey("en-US") -and $script:AhoI18nTables["en-US"].ContainsKey($Key)) {
        $text = [string]$script:AhoI18nTables["en-US"][$Key]
    } else {
        $text = $Key
    }
    if ($FormatArgs -and $FormatArgs.Count -gt 0) {
        try {
            return ($text -f $FormatArgs)
        } catch {
            return $text
        }
    }
    return $text
}

function Get-AhoI18nKeySet {
    param([string]$Culture = "en-US")
    Import-AhoI18nTables
    if (-not $script:AhoI18nTables.ContainsKey($Culture)) {
        return @()
    }
    return @($script:AhoI18nTables[$Culture].Keys | Sort-Object)
}
