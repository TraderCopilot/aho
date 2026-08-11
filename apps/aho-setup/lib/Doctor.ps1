. (Join-Path $PSScriptRoot "Common.ps1")
. (Join-Path $PSScriptRoot "Verify.ps1")
. (Join-Path $PSScriptRoot "PlatformRegistry.ps1")

function Invoke-AhoDoctor {
    param([Parameter(Mandatory)][string]$Target)
    $target = Resolve-AhoPath -Path $Target
    $verify = Invoke-AhoVerify -Target $target
    $findings = @()
    $fail = $false

    foreach ($e in $verify.errors) {
        $findings += [pscustomobject]@{ severity = "error"; code = "VERIFY"; message = $e }
        $fail = $true
    }
    foreach ($w in $verify.warnings) {
        $findings += [pscustomobject]@{ severity = "warning"; code = "VERIFY"; message = $w }
    }

    $skills = Join-Path $target ".agents\skills"
    $platforms = Get-AhoPlatformsForInstall -Target $target

    $manifestPath = Join-Path $target ".agents\.aho-manifest.json"
    $manifest = $null
    $manifestHosts = $null
    if (Test-Path -LiteralPath $manifestPath) {
        $manifest = Read-AhoJsonFile -Path $manifestPath
        if ($manifest) {
            $manifestLinkMode = $manifest.link_mode
            if ($manifest.PSObject.Properties.Match('hosts').Count -gt 0) {
                $manifestHosts = $manifest.hosts
            }
        }
    }

    foreach ($plat in $platforms) {
        $projTo = $plat['project_projection_to']
        if (-not $projTo) { continue }
        $platName = $plat['name']
        $projPath = Join-Path $target $projTo
        $expectedTarget = $skills
        $isOptional = ($plat['status'] -eq 'new')

        if ($manifestHosts -and $manifestHosts.PSObject.Properties.Match($platName).Count -gt 0) {
            $hostEntry = $manifestHosts.$platName
            if ($hostEntry.PSObject.Properties.Match('projection').Count -gt 0) {
                $projEntry = $hostEntry.projection
                if ($projEntry.PSObject.Properties.Match('expected_target').Count -gt 0) {
                    $expectedTarget = [string]$projEntry.expected_target
                }
            }
        }

        if (Test-Path -LiteralPath $projPath) {
            $isLink = Test-AhoIsReparsePoint -Path $projPath
            if (-not $isLink) {
                if ($manifestLinkMode -eq "copy" -or $manifestLinkMode -eq "existing-solid") {
                    $findings += [pscustomobject]@{
                        severity = "info"
                        code     = "SOLID_KNOWN_MODE"
                        message  = "$projTo is a solid directory (link_mode=$manifestLinkMode). Edits will not sync to .agents/skills. [$platName]"
                    }
                } else {
                    $findings += [pscustomobject]@{
                        severity = "error"
                        code     = "DUAL_SOLID_SKILLS"
                        message  = "$projTo is a solid directory (not junction). Dual skill trees risk drift. [$platName]"
                    }
                    $fail = $true
                }
            } else {
                $resolvedJunctionTarget = Resolve-AhoJunctionTarget -LinkPath $projPath
                $targetValid = $true
                $targetCorrect = $false

                if ($null -ne $resolvedJunctionTarget -and $null -ne $expectedTarget) {
                    $normResolved = $resolvedJunctionTarget.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
                    $normExpected = [System.IO.Path]::GetFullPath($expectedTarget).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
                    $targetCorrect = $normResolved.Equals($normExpected, [StringComparison]::OrdinalIgnoreCase)
                }

                if ($null -eq $resolvedJunctionTarget) {
                    $targetValid = $false
                } else {
                    try {
                        $null = Get-ChildItem -LiteralPath $projPath -ErrorAction Stop
                    } catch {
                        $targetValid = $false
                    }
                }

                if (-not $targetValid) {
                    $findings += [pscustomobject]@{
                        severity = "error"
                        code     = "BROKEN_JUNCTION"
                        message  = "$projTo reparse point target is missing or unreadable [$platName]"
                    }
                    $fail = $true
                } elseif (-not $targetCorrect) {
                    $findings += [pscustomobject]@{
                        severity = "error"
                        code     = "WRONG_PROJECTION_TARGET"
                        message  = "$projTo points to '$resolvedJunctionTarget' but expected '$expectedTarget' [$platName]"
                    }
                    $fail = $true
                } else {
                    $findings += [pscustomobject]@{
                        severity = "info"
                        code     = "JUNCTION_OK"
                        message  = "$projTo is a reparse point (junction/symlink) pointing to correct target [$platName]"
                    }
                }
            }
        } else {
            if ($isOptional) {
                $findings += [pscustomobject]@{
                    severity = "warning"
                    code     = "NO_PROJECTION"
                    message  = ".agents/skills exists but $projTo projection missing (optional platform) [$platName]"
                }
            } else {
                $findings += [pscustomobject]@{
                    severity = "error"
                    code     = "NO_PROJECTION"
                    message  = ".agents/skills exists but $projTo projection missing (required platform) [$platName]"
                }
                $fail = $true
            }
        }

        if ((Test-Path -LiteralPath $projPath) -and (Test-AhoIsReparsePoint -Path $projPath)) {
            if (-not (Test-Path -LiteralPath $skills)) {
                $findings += [pscustomobject]@{
                    severity = "error"
                    code     = "BROKEN_JUNCTION"
                    message  = "$projTo points to missing .agents/skills [$platName]"
                }
                $fail = $true
            }
        }
    }

    if ($manifestLinkMode -eq "copy") {
        $findings += [pscustomobject]@{
            severity = "warning"
            code     = "COPY_MODE"
            message  = "manifest link_mode=copy: platform path may drift from .agents after edits"
        }
    }

    return [pscustomobject]@{
        ok        = (-not $fail)
        target    = $target
        findings  = $findings
        exit_code = $(if ($fail) { 2 } else { 0 })
    }
}
