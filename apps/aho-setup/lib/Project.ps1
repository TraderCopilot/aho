. (Join-Path $PSScriptRoot "Plan.ps1")
. (Join-Path $PSScriptRoot "UserActions.ps1")
. (Join-Path $PSScriptRoot "AgentsGen.ps1")
. (Join-Path $PSScriptRoot "MattSetup.ps1")
. (Join-Path $PSScriptRoot "Report.ps1")
. (Join-Path $PSScriptRoot "PlatformRegistry.ps1")
. (Join-Path $PSScriptRoot "Hooks.ps1")

function Invoke-AhoInstall {
    param(
        [Parameter(Mandatory)][string]$Target,
        [string]$Profile = "standard",
        [switch]$Apply,
        [switch]$Confirmed
    )
    $plan = Invoke-AhoPlan -Target $Target -Profile $Profile
    if (-not (Test-AhoWriteAllowed -Apply:$Apply -Confirmed:$Confirmed)) {
        Write-AhoI18nInfo 'install.dryRun'
        return [pscustomobject]@{
            ok       = $true
            dry_run  = $true
            written  = $false
            plan     = $plan
            message  = "refused_write_without_apply_and_confirmed"
        }
    }

    $target = $plan.target
    if (-not (Test-Path -LiteralPath $target)) {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
    }

    $report = @()
    $agentsRoot = Join-Path $target ".agents"
    $skillsRoot = Join-Path $agentsRoot "skills"
    New-Item -ItemType Directory -Path $skillsRoot -Force | Out-Null

    $installed = @()
    $skipped = @()
    foreach ($s in $plan.skill_sources) {
        $dest = Join-Path $skillsRoot $s.name
        $relPath = ".agents/skills/$($s.name)"
        if (Test-Path -LiteralPath $dest) {
            $skipped += $s.name
            $report += New-AhoReportEntry -Path $relPath -Type "skill" -Action "skipped_existing" -Reason "already_exists" -Source $s.source
            continue
        }
        try {
            Copy-AhoDirectoryContents -SourceDir $s.source -DestDir $dest
            $installed += $s.name
            $report += New-AhoReportEntry -Path $relPath -Type "skill" -Action "created" -Source $s.source
        } catch {
            $report += New-AhoReportEntry -Path $relPath -Type "skill" -Action "failed" -Reason "$_" -Source $s.source
        }
    }

    $yp = Get-AhoYourProject
    $platforms = Get-AhoPlatformsForInstall -Target $target
    $coreRootTemplates = @("AGENTS.md", "CLAUDE.md", "GEMINI.md", ".mcp.json")

    foreach ($f in $coreRootTemplates) {
        $src = Join-Path $yp $f
        $dst = Join-Path $target $f
        if (-not (Test-Path -LiteralPath $src)) { continue }
        if (Test-Path -LiteralPath $dst) {
            $report += New-AhoReportEntry -Path $f -Type "root_template" -Action "skipped_existing" -Reason "already_exists" -Source $src
            continue
        }
        try {
            Copy-Item -LiteralPath $src -Destination $dst
            $report += New-AhoReportEntry -Path $f -Type "root_template" -Action "created" -Source $src
        } catch {
            $report += New-AhoReportEntry -Path $f -Type "root_template" -Action "failed" -Reason "$_" -Source $src
        }
    }

    $platRootTemplates = @()
    foreach ($plat in $platforms) {
        $rootTempls = $plat['project_root_templates']
        if ($rootTempls -and $rootTempls.Count -gt 0) {
            foreach ($rt in $rootTempls) {
                if ($rt -notin $coreRootTemplates) {
                    $platRootTemplates += [pscustomobject]@{ template = $rt; platform = $plat['name'] }
                }
            }
        }
    }
    foreach ($prt in $platRootTemplates) {
        $rt = $prt.template
        $src = Join-Path $yp $rt
        $dst = Join-Path $target $rt
        if (-not (Test-Path -LiteralPath $src)) { continue }
        if (Test-Path -LiteralPath $dst) {
            $report += New-AhoReportEntry -Path $rt -Type "root_template" -Action "skipped_existing" -Reason "already_exists" -Source $src
            continue
        }
        try {
            $srcItem = Get-Item -LiteralPath $src -Force
            if ($srcItem.PSIsContainer) {
                Copy-AhoDirectoryContents -SourceDir $src -DestDir $dst -NoOverwrite
            } else {
                $parent = Split-Path -Parent $dst
                if (-not (Test-Path -LiteralPath $parent)) {
                    New-Item -ItemType Directory -Path $parent -Force | Out-Null
                }
                Copy-Item -LiteralPath $src -Destination $dst
            }
            $report += New-AhoReportEntry -Path $rt -Type "root_template" -Action "created" -Source $src
        } catch {
            $report += New-AhoReportEntry -Path $rt -Type "root_template" -Action "failed" -Reason "$_" -Source $src
        }
    }

    $settingsSrc = Join-Path $yp ".agents\settings.json"
    $settingsDst = Join-Path $agentsRoot "settings.json"
    if (Test-Path -LiteralPath $settingsSrc) {
        if (Test-Path -LiteralPath $settingsDst) {
            $report += New-AhoReportEntry -Path ".agents/settings.json" -Type "settings" -Action "skipped_existing" -Reason "already_exists" -Source $settingsSrc
        } else {
            try {
                Copy-Item -LiteralPath $settingsSrc -Destination $settingsDst
                $report += New-AhoReportEntry -Path ".agents/settings.json" -Type "settings" -Action "created" -Source $settingsSrc
            } catch {
                $report += New-AhoReportEntry -Path ".agents/settings.json" -Type "settings" -Action "failed" -Reason "$_" -Source $settingsSrc
            }
        }
    }

    $workflowsCopied = @()
    $scriptsCopied = @()
    if ($plan.packs -contains "workflow-project") {
        $wfSrc = Join-Path $yp ".agents\workflows"
        $wfDst = Join-Path $agentsRoot "workflows"
        if (Test-Path -LiteralPath $wfSrc) {
            New-Item -ItemType Directory -Path $wfDst -Force | Out-Null
            Get-ChildItem -LiteralPath $wfSrc -File | ForEach-Object {
                $d = Join-Path $wfDst $_.Name
                $relPath = ".agents/workflows/$($_.Name)"
                if (Test-Path -LiteralPath $d) {
                    $report += New-AhoReportEntry -Path $relPath -Type "workflow" -Action "skipped_existing" -Reason "already_exists" -Source $_.FullName
                } else {
                    try {
                        Copy-Item -LiteralPath $_.FullName -Destination $d
                        $workflowsCopied += $_.Name
                        $report += New-AhoReportEntry -Path $relPath -Type "workflow" -Action "created" -Source $_.FullName
                    } catch {
                        $report += New-AhoReportEntry -Path $relPath -Type "workflow" -Action "failed" -Reason "$_" -Source $_.FullName
                    }
                }
            }
        }
        $scSrc = Join-Path $yp ".agents\scripts"
        $scDst = Join-Path $agentsRoot "scripts"
        if (Test-Path -LiteralPath $scSrc) {
            New-Item -ItemType Directory -Path $scDst -Force | Out-Null
            Get-ChildItem -LiteralPath $scSrc -File | ForEach-Object {
                $d = Join-Path $scDst $_.Name
                $relPath = ".agents/scripts/$($_.Name)"
                if (Test-Path -LiteralPath $d) {
                    $report += New-AhoReportEntry -Path $relPath -Type "script" -Action "skipped_existing" -Reason "already_exists" -Source $_.FullName
                } else {
                    try {
                        Copy-Item -LiteralPath $_.FullName -Destination $d
                        $scriptsCopied += $_.Name
                        $report += New-AhoReportEntry -Path $relPath -Type "script" -Action "created" -Source $_.FullName
                    } catch {
                        $report += New-AhoReportEntry -Path $relPath -Type "script" -Action "failed" -Reason "$_" -Source $_.FullName
                    }
                }
            }
        }
    }

    $agentsMat = Invoke-AhoAgentsMaterialize -Target $target -TemplateRoot $yp
    foreach ($a in $agentsMat.copied) {
        $report += New-AhoReportEntry -Path ".agents/agents/$a" -Type "agent" -Action "created"
    }
    foreach ($g in $agentsMat.generated) {
        $report += New-AhoReportEntry -Path $g -Type "agent" -Action "created"
    }

    $mattResult = $null
    if ($plan.packs -contains "matt-collab") {
        $mattResult = Invoke-AhoMattSetup -Target $target -Preset "github" -Apply:$Apply -Confirmed:$Confirmed
    }

    $projectionResults = @()
    foreach ($plat in $platforms) {
        $projTo = $plat['project_projection_to']
        if (-not $projTo) { continue }
        $platName = $plat['name']
        try {
            $validatedProjTo = Resolve-AhoContainedPath -ChildPath $projTo -RootPath $target -ContextLabel "projection:$platName"
        } catch {
            $report += New-AhoReportEntry -Path $projTo -Type "junction" -Action "failed" -Reason "AHO_PATH_VIOLATION: $_"
            $projectionResults += [pscustomobject]@{
                platform = $platName; path = ""; mode = "failed"
                target = $skillsRoot; existed = $false; error = "$_"
            }
            continue
        }
        $linkPath = $validatedProjTo
        $lr = New-AhoJunctionOrCopy -LinkPath $linkPath -TargetPath $skillsRoot
        if ($lr.mode -eq "wrong_target") {
            $report += New-AhoReportEntry -Path $projTo -Type "junction" -Action "failed" -Reason "WRONG_PROJECTION_TARGET: expected=$($lr.target) actual=$($lr.actual_target)"
            $projectionResults += [pscustomobject]@{
                platform = $platName; path = $lr.path; mode = "failed"
                target = $lr.target; existed = $false; error = "WRONG_PROJECTION_TARGET"
            }
            continue
        }
        $la = if ($lr.existed) { "skipped_existing" } else { "created" }
        $report += New-AhoReportEntry -Path $projTo -Type "junction" -Action $la -Reason "mode=$($lr.mode)"
        $projectionResults += [pscustomobject]@{
            platform  = $platName
            path      = $lr.path
            mode      = $lr.mode
            target    = $lr.target
            existed   = $lr.existed
        }
        $projDirs = $plat['project_dirs']
        if ($projDirs -and $projDirs.Count -gt 0) {
            foreach ($dir in $projDirs) {
                try {
                    $validatedDir = Resolve-AhoContainedPath -ChildPath $dir -RootPath $target -ContextLabel "project_dir:$platName"
                } catch {
                    $report += New-AhoReportEntry -Path $dir -Type "platform_dir" -Action "failed" -Reason "AHO_PATH_VIOLATION: $_"
                    continue
                }
                if (-not (Test-Path -LiteralPath $validatedDir)) {
                    New-Item -ItemType Directory -Path $validatedDir -Force | Out-Null
                    $report += New-AhoReportEntry -Path $dir -Type "platform_dir" -Action "created"
                }
            }
        }
    }

    $primaryProjection = if ($projectionResults.Count -gt 0) { $projectionResults[0] } else { $null }
    $primaryLinkMode = if ($primaryProjection) { $primaryProjection.mode } else { "none" }
    $primaryLinkPath = if ($primaryProjection) { $primaryProjection.path } else { "" }
    $primaryLinkTarget = if ($primaryProjection) { $primaryProjection.target } else { "" }

    $hooksMerged = @()
    foreach ($plat in $platforms) {
        $settingsPath = $plat['project_settings_path']
        if (-not $settingsPath) { continue }
        $srcSettings = Join-Path $yp $settingsPath
        try {
            $dstSettings = Resolve-AhoContainedPath -ChildPath $settingsPath -RootPath $target -ContextLabel "settings:$platName"
        } catch {
            $report += New-AhoReportEntry -Path $settingsPath -Type "platform_settings" -Action "failed" -Reason "AHO_PATH_VIOLATION: $_"
            continue
        }
        if (-not (Test-Path -LiteralPath $srcSettings)) { continue }
        $settingsContent = Get-Content -LiteralPath $srcSettings -Raw -Encoding UTF8
        $settingsObj = $settingsContent | ConvertFrom-Json
        $settingsHt = Convert-AhoToHashtable -InputObj $settingsObj
        if ($plat['project_hooks_in_settings'] -eq 'true') {
            $hooksKey = $plat['project_hooks_settings_key']
            if (-not $hooksKey) { $hooksKey = 'hooks' }
            $hooksSrc = Join-Path $yp $plat['project_hooks_path']
            if (Test-Path -LiteralPath $hooksSrc) {
                $hooksContent = Get-Content -LiteralPath $hooksSrc -Raw -Encoding UTF8
                $hooksObj = $hooksContent | ConvertFrom-Json
                $hooksHt = Convert-AhoToHashtable -InputObj $hooksObj
                $settingsHt[$hooksKey] = $hooksHt
            }
        }
        $mergeMode = $plat['project_settings_merge']
        if ($mergeMode -eq 'deep') {
            Merge-AhoJsonFile -Path $dstSettings -Updates $settingsHt -NoOverwriteExisting
        } else {
            if (Test-Path -LiteralPath $dstSettings) {
                $report += New-AhoReportEntry -Path $settingsPath -Type "platform_settings" -Action "skipped_existing" -Reason "already_exists" -Source $srcSettings
            } else {
                $parent = Split-Path -Parent $dstSettings
                if (-not (Test-Path -LiteralPath $parent)) {
                    New-Item -ItemType Directory -Path $parent -Force | Out-Null
                }
                $json = $settingsHt | ConvertTo-Json -Depth 8
                $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
                $tempPath = $dstSettings + ".tmp"
                [System.IO.File]::WriteAllText($tempPath, $json, $utf8NoBom)
                Move-Item -LiteralPath $tempPath -Destination $dstSettings -Force
                $hooksMerged += $plat['name']
                $report += New-AhoReportEntry -Path $settingsPath -Type "platform_settings" -Action "created" -Source $srcSettings
            }
        }
        if ($plat['project_hooks_in_settings'] -ne 'true' -and $plat['project_hooks_path']) {
            $hooksPath = $plat['project_hooks_path']
            $srcHooks = Join-Path $yp $hooksPath
            try {
                $dstHooks = Resolve-AhoContainedPath -ChildPath $hooksPath -RootPath $target -ContextLabel "hooks:$platName"
            } catch {
                $report += New-AhoReportEntry -Path $hooksPath -Type "platform_hooks" -Action "failed" -Reason "AHO_PATH_VIOLATION: $_"
                continue
            }
            if ((Test-Path -LiteralPath $srcHooks) -and -not (Test-Path -LiteralPath $dstHooks)) {
                $parent = Split-Path -Parent $dstHooks
                if (-not (Test-Path -LiteralPath $parent)) {
                    New-Item -ItemType Directory -Path $parent -Force | Out-Null
                }
                Copy-Item -LiteralPath $srcHooks -Destination $dstHooks
                $hooksMerged += $plat['name']
                $report += New-AhoReportEntry -Path $hooksPath -Type "platform_hooks" -Action "created" -Source $srcHooks
            }
        }
    }

    $hostsMap = [ordered]@{}
    foreach ($pr in $projectionResults) {
        $hostsMap[$pr.platform] = [ordered]@{
            projection = [ordered]@{
                mode          = $pr.mode
                path          = $pr.path
                expected_target = $pr.target
                existed       = $pr.existed
            }
        }
        if ($pr.error) { $hostsMap[$pr.platform].projection['error'] = $pr.error }
    }

    $manifest = [ordered]@{
        product      = "agents-harness-os"
        tool         = "aho-setup"
        version      = Get-AhoVersion
        profile      = $plan.profile
        packs        = $plan.packs
        skills       = @($plan.skills)
        installed    = $installed
        skipped_existing = $skipped
        workflows_copied = $workflowsCopied
        scripts_copied = $scriptsCopied
        agents       = $agentsMat
        hosts        = $hostsMap
        link_mode    = $primaryLinkMode
        link_path    = $primaryLinkPath
        link_target  = $primaryLinkTarget
        settings_local_written = $false
        generated_at = (Get-Date).ToString("o")
    }
    $manifestPath = Join-Path $agentsRoot ".aho-manifest.json"
    Write-AhoJsonFile -Path $manifestPath -Object $manifest
    $report += New-AhoReportEntry -Path ".agents/.aho-manifest.json" -Type "manifest" -Action "created"

    $ua = Write-AhoUserActions -Target $target -Scope project
    $report += New-AhoReportEntry -Path "USER-ACTIONS.md" -Type "user_actions" -Action "created"

    $reportPath = Write-AhoReport -Target $target -Report $report -Scope "project"

    $failedEntries = @($report | Where-Object { $_.action -eq "failed" })
    $hasRequiredFailure = $false
    foreach ($fe in $failedEntries) {
        if ($fe.type -in @("skill", "manifest", "junction", "platform_settings")) {
            $hasRequiredFailure = $true
            break
        }
    }
    $ok = -not $hasRequiredFailure

    return [pscustomobject]@{
        ok          = $ok
        dry_run     = $false
        written     = $true
        target      = $target
        installed   = $installed
        skipped     = $skipped
        failed      = @($failedEntries | ForEach-Object { $_.path })
        link_mode   = $primaryLinkMode
        manifest    = $manifestPath
        report      = $reportPath
        user_actions = $ua
        plan        = $plan
        exit_code   = $(if ($ok) { 0 } else { 2 })
    }
}
