. (Join-Path $PSScriptRoot "Common.ps1")
. (Join-Path $PSScriptRoot "UserActions.ps1")
. (Join-Path $PSScriptRoot "Report.ps1")
. (Join-Path $PSScriptRoot "PlatformRegistry.ps1")

function Resolve-AhoHomeRoot {
    param([string]$HomeRoot)
    if ([string]::IsNullOrWhiteSpace($HomeRoot)) {
        return Get-AhoHomePath
    }
    return Resolve-AhoPath -Path $HomeRoot
}

function Invoke-AhoGlobalPlan {
    param([string]$HomeRoot)
    $homeRoot = Resolve-AhoHomeRoot -HomeRoot $HomeRoot
    $template = Get-AhoGlobalTemplate
    $skillsTemplate = Join-Path $template ".agents\skills"
    $skillNames = @()
    if (Test-Path -LiteralPath $skillsTemplate) {
        $skillNames = @(Get-ChildItem -LiteralPath $skillsTemplate -Directory | ForEach-Object { $_.Name })
    }
    $agentsDest = Join-Path $homeRoot ".agents"
    $conflicts = @()
    foreach ($name in $skillNames) {
        $dest = Join-Path $agentsDest (Join-Path "skills" $name)
        if (Test-Path -LiteralPath $dest) {
            $conflicts += $dest
        }
    }
    return [pscustomobject]@{
        home_root       = $homeRoot
        template        = $template
        skills          = $skillNames
        agents_dest     = $agentsDest
        existing_conflicts = $conflicts
        dry_run         = $true
        actions         = @(
            "Materialize Global/.agents skills into <home>/.agents/skills (skip existing)",
            "Write USER-ACTIONS under <home> if missing",
            "Do not overwrite pre-existing skill directories",
            "Optional: junction <home>/.claude/skills -> <home>/.agents/skills"
        )
    }
}

function Invoke-AhoGlobalSetup {
    param(
        [string]$HomeRoot,
        [switch]$Apply,
        [switch]$Confirmed
    )
    $plan = Invoke-AhoGlobalPlan -HomeRoot $HomeRoot
    if (-not (Test-AhoWriteAllowed -Apply:$Apply -Confirmed:$Confirmed)) {
        Write-AhoI18nInfo 'global.dryRun'
        return [pscustomobject]@{
            ok      = $true
            dry_run = $true
            written = $false
            plan    = $plan
            message = "refused_write_without_apply_and_confirmed"
        }
    }

    $report = @()
    $homeRoot = $plan.home_root
    $template = $plan.template
    $agentsDest = Join-Path $homeRoot ".agents"
    $skillsDest = Join-Path $agentsDest "skills"
    New-Item -ItemType Directory -Path $skillsDest -Force | Out-Null

    $installed = @()
    $skipped = @()
    $conflicts = @()
    $skillsTemplate = Join-Path $template ".agents\skills"
    if (Test-Path -LiteralPath $skillsTemplate) {
        foreach ($skillDir in (Get-ChildItem -LiteralPath $skillsTemplate -Directory)) {
            $dest = Join-Path $skillsDest $skillDir.Name
            $relPath = ".agents/skills/$($skillDir.Name)"
            if (Test-Path -LiteralPath $dest) {
                $skipped += $skillDir.Name
                $conflicts += $dest
                $report += New-AhoReportEntry -Path $relPath -Type "skill" -Action "skipped_existing" -Reason "already_exists" -Source $skillDir.FullName
            } else {
                try {
                    Copy-AhoDirectoryContents -SourceDir $skillDir.FullName -DestDir $dest
                    $installed += $skillDir.Name
                    $report += New-AhoReportEntry -Path $relPath -Type "skill" -Action "created" -Source $skillDir.FullName
                } catch {
                    $report += New-AhoReportEntry -Path $relPath -Type "skill" -Action "failed" -Reason "$_" -Source $skillDir.FullName
                }
            }
        }
    }

    $srcAgents = Join-Path $template "AGENTS.md"
    $dstAgents = Join-Path $homeRoot "AGENTS.md"
    $agentsWritten = $false
    if ((Test-Path -LiteralPath $srcAgents) -and -not (Test-Path -LiteralPath $dstAgents)) {
        Copy-Item -LiteralPath $srcAgents -Destination $dstAgents
        $agentsWritten = $true
        $report += New-AhoReportEntry -Path "AGENTS.md" -Type "root_template" -Action "created" -Source $srcAgents
    } elseif (Test-Path -LiteralPath $dstAgents) {
        $conflicts += $dstAgents
        $report += New-AhoReportEntry -Path "AGENTS.md" -Type "root_template" -Action "skipped_existing" -Reason "already_exists" -Source $srcAgents
    }

    $claudeLinkPath = Join-Path $homeRoot ".claude\skills"
    try {
        $validatedClaudeLink = Resolve-AhoContainedPath -ChildPath ".claude\skills" -RootPath $homeRoot -ContextLabel "global_projection:claude"
        $linkResult = New-AhoJunctionOrCopy -LinkPath $validatedClaudeLink -TargetPath $skillsDest
    } catch {
        $linkResult = @{ mode = "failed"; path = ""; target = $skillsDest; existed = $false; error = "$_" }
        $report += New-AhoReportEntry -Path ".claude/skills" -Type "junction" -Action "failed" -Reason "AHO_PATH_VIOLATION: $_"
    }
    if ($linkResult.mode -eq "wrong_target") {
        $report += New-AhoReportEntry -Path ".claude/skills" -Type "junction" -Action "failed" -Reason "WRONG_PROJECTION_TARGET: expected=$($linkResult.target) actual=$($linkResult.actual_target)"
        $linkResult = @{ mode = "failed"; path = $linkResult.path; target = $linkResult.target; existed = $false; error = "WRONG_PROJECTION_TARGET" }
    }
    $linkAction = if ($linkResult.existed) { "skipped_existing" } else { "created" }
    if ($linkResult.mode -ne "failed") {
        $report += New-AhoReportEntry -Path ".claude/skills" -Type "junction" -Action $linkAction -Reason "mode=$($linkResult.mode)"
    }

    $globalPlatforms = Get-AhoPlatformsForGlobalSetup -HomeRoot $homeRoot
    $globalProjectionResults = @()
    foreach ($plat in $globalPlatforms) {
        $projTo = $plat['global_projection_to']
        $platName = $plat['name']
        if ($projTo -and $platName -ne 'claude') {
            try {
                $validatedProjTo = Resolve-AhoContainedPath -ChildPath $projTo -RootPath $homeRoot -ContextLabel "global_projection:$platName"
            } catch {
                $report += New-AhoReportEntry -Path $projTo -Type "junction" -Action "failed" -Reason "AHO_PATH_VIOLATION: $_"
                $globalProjectionResults += [pscustomobject]@{
                    platform = $platName; mode = "failed"; error = "$_"
                }
                continue
            }
            $gLinkPath = $validatedProjTo
            if ($gLinkPath -ne $claudeLinkPath) {
                $glr = New-AhoJunctionOrCopy -LinkPath $gLinkPath -TargetPath $skillsDest
                if ($glr.mode -eq "wrong_target") {
                    $report += New-AhoReportEntry -Path $projTo -Type "junction" -Action "failed" -Reason "WRONG_PROJECTION_TARGET: expected=$($glr.target) actual=$($glr.actual_target)"
                    $globalProjectionResults += [pscustomobject]@{
                        platform = $platName; mode = "failed"; path = $glr.path; target = $glr.target; existed = $false; error = "WRONG_PROJECTION_TARGET"
                    }
                    continue
                }
                $gla = if ($glr.existed) { "skipped_existing" } else { "created" }
                $report += New-AhoReportEntry -Path $projTo -Type "junction" -Action $gla -Reason "mode=$($glr.mode)"
                $globalProjectionResults += [pscustomobject]@{
                    platform = $platName; mode = $glr.mode; path = $glr.path; target = $glr.target; existed = $glr.existed
                }
            }
        }
    }

    $ua = Write-AhoUserActions -Target $homeRoot -Scope global -NoOverwrite

    $platformCopied = @()
    foreach ($plat in $globalPlatforms) {
        $platName = $plat['name']
        $globalSettings = $plat['global_settings']
        if ($globalSettings -and $globalSettings.Count -gt 0) {
            foreach ($rel in $globalSettings) {
                $srcP = Join-Path $template $rel
                try {
                    $dstP = Resolve-AhoContainedPath -ChildPath $rel -RootPath $homeRoot -ContextLabel "global_settings:$platName"
                } catch {
                    $report += New-AhoReportEntry -Path $rel -Type "platform_template" -Action "failed" -Reason "AHO_PATH_VIOLATION: $_"
                    continue
                }
                $relNorm = $rel
                if (-not (Test-Path -LiteralPath $srcP)) { continue }
                if (Test-Path -LiteralPath $dstP) {
                    $conflicts += $dstP
                    $report += New-AhoReportEntry -Path $relNorm -Type "platform_template" -Action "skipped_existing" -Reason "already_exists" -Source $srcP
                } else {
                    try {
                        $parent = Split-Path -Parent $dstP
                        if (-not (Test-Path -LiteralPath $parent)) {
                            New-Item -ItemType Directory -Path $parent -Force | Out-Null
                        }
                        Copy-Item -LiteralPath $srcP -Destination $dstP
                        $platformCopied += $rel
                        $report += New-AhoReportEntry -Path $relNorm -Type "platform_template" -Action "created" -Source $srcP
                    } catch {
                        $report += New-AhoReportEntry -Path $relNorm -Type "platform_template" -Action "failed" -Reason "$_" -Source $srcP
                    }
                }
            }
        }
        $globalTemplates = $plat['global_root_templates']
        if ($globalTemplates -and $globalTemplates.Count -gt 0) {
            foreach ($rel in $globalTemplates) {
                $srcP = Join-Path $template $rel
                try {
                    $dstP = Resolve-AhoContainedPath -ChildPath $rel -RootPath $homeRoot -ContextLabel "global_template:$platName"
                } catch {
                    $report += New-AhoReportEntry -Path $rel -Type "platform_template" -Action "failed" -Reason "AHO_PATH_VIOLATION: $_"
                    continue
                }
                $relNorm = $rel
                if (-not (Test-Path -LiteralPath $srcP)) { continue }
                if (Test-Path -LiteralPath $dstP) {
                    $conflicts += $dstP
                    $report += New-AhoReportEntry -Path $relNorm -Type "platform_template" -Action "skipped_existing" -Reason "already_exists" -Source $srcP
                } else {
                    try {
                        $parent = Split-Path -Parent $dstP
                        if (-not (Test-Path -LiteralPath $parent)) {
                            New-Item -ItemType Directory -Path $parent -Force | Out-Null
                        }
                        Copy-Item -LiteralPath $srcP -Destination $dstP
                        $platformCopied += $rel
                        $report += New-AhoReportEntry -Path $relNorm -Type "platform_template" -Action "created" -Source $srcP
                    } catch {
                        $report += New-AhoReportEntry -Path $relNorm -Type "platform_template" -Action "failed" -Reason "$_" -Source $srcP
                    }
                }
            }
        }
        $globalRulesDir = $plat['global_rules_dir']
        if ($globalRulesDir) {
            $expandedDir = Resolve-AhoPlatformPlaceholder -Value $globalRulesDir -HomeRoot $homeRoot
            try {
                $validatedRulesDir = Resolve-AhoContainedPath -ChildPath $expandedDir -RootPath $homeRoot -ContextLabel "global_rules_dir:$platName"
            } catch {
                $report += New-AhoReportEntry -Path $globalRulesDir -Type "global_rules_dir" -Action "failed" -Reason "AHO_PATH_VIOLATION: $_"
                continue
            }
            if (-not (Test-Path -LiteralPath $validatedRulesDir)) {
                try {
                    New-Item -ItemType Directory -Path $validatedRulesDir -Force | Out-Null
                    $report += New-AhoReportEntry -Path $globalRulesDir -Type "global_rules_dir" -Action "created" -Reason "expanded=$validatedRulesDir"
                } catch {
                    $report += New-AhoReportEntry -Path $globalRulesDir -Type "global_rules_dir" -Action "failed" -Reason "$_"
                }
            } else {
                $report += New-AhoReportEntry -Path $globalRulesDir -Type "global_rules_dir" -Action "skipped_existing" -Reason "already_exists"
            }
        }
    }

    $hostsMap = [ordered]@{}
    $allProjResults = @(
        [pscustomobject]@{ platform = 'claude'; mode = $linkResult.mode; path = $linkResult.path; target = $linkResult.target; existed = $linkResult.existed }
    ) + $globalProjectionResults
    foreach ($pr in $allProjResults) {
        $hostsMap[$pr.platform] = [ordered]@{
            projection = [ordered]@{
                mode            = $pr.mode
                path            = $pr.path
                expected_target = $pr.target
                existed         = $pr.existed
            }
        }
        if ($pr.error) { $hostsMap[$pr.platform].projection['error'] = $pr.error }
    }

    $manifest = [ordered]@{
        product     = "agents-harness-os"
        tool        = "aho-setup"
        scope       = "global"
        version     = Get-AhoVersion
        home_root   = $homeRoot
        installed   = $installed
        skipped_existing = $skipped
        conflicts   = $conflicts
        platform_copied = $platformCopied
        hosts       = $hostsMap
        link_mode   = $linkResult.mode
        agents_md_written = $agentsWritten
        generated_at = (Get-Date).ToString("o")
    }
    Write-AhoJsonFile -Path (Join-Path $agentsDest ".aho-manifest.json") -Object $manifest
    $report += New-AhoReportEntry -Path ".agents/.aho-manifest.json" -Type "manifest" -Action "created"

    $reportPath = Write-AhoReport -Target $homeRoot -Report $report -Scope "global"

    $failedEntries = @($report | Where-Object { $_.action -eq "failed" })
    $hasRequiredFailure = $false
    foreach ($fe in $failedEntries) {
        if ($fe.type -in @("skill", "manifest", "junction", "platform_template", "global_rules_dir")) {
            $hasRequiredFailure = $true
            break
        }
    }
    $ok = -not $hasRequiredFailure

    return [pscustomobject]@{
        ok        = $ok
        dry_run   = $false
        written   = $true
        home_root = $homeRoot
        installed = $installed
        skipped   = $skipped
        failed    = @($failedEntries | ForEach-Object { $_.path })
        conflicts = $conflicts
        link_mode = $linkResult.mode
        report    = $reportPath
        user_actions = $ua
        plan      = $plan
        exit_code = $(if ($ok) { 0 } else { 2 })
    }
}
