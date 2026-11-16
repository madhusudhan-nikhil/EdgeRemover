<#
.SYNOPSIS
    Status audit tool for Microsoft Edge & WebView2 removal and policy blocking.

.DESCRIPTION
    Inspects 5 system domains:
    1. Binary file & process presence (Edge, WebView2, running processes)
    2. Registry uninstall flags (NoRemove, SystemComponent)
    3. Service states (edgeupdate, edgeupdatem, MicrosoftEdgeElevationService)
    4. Scheduled update tasks (MicrosoftEdgeUpdate*)
    5. Reinstallation prevention policies (Chromium blocker & Enterprise EdgeUpdate policies)

.PARAMETER Json
    Emits raw structured JSON output for consumption by AI agents or automated pipelines.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File scripts\check-edge-status.ps1
    powershell.exe -ExecutionPolicy Bypass -File scripts\check-edge-status.ps1 -Json
#>

[CmdletBinding()]
param(
    [switch]$Json
)

$ErrorActionPreference = "SilentlyContinue"

# ------------------------------------------------------------------------------
# Domain 1: Binaries & Active Processes
# ------------------------------------------------------------------------------
$edgeExePaths = @(
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
)
$foundEdgeExes = @($edgeExePaths | Where-Object { Test-Path $_ })

$wvPatterns = @(
    "C:\Program Files (x86)\Microsoft\EdgeWebView\Application\*\msedgewebview2.exe",
    "C:\Program Files\Microsoft\EdgeWebView\Application\*\msedgewebview2.exe",
    "C:\Program Files (x86)\Microsoft\EdgeCore\*\msedgewebview2.exe"
)
$foundWvExes = @(Resolve-Path $wvPatterns -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path)

$activeEdgeProcs = @(Get-Process -Name msedge -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
$activeWvProcs   = @(Get-Process -Name msedgewebview2 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)

$edgeInstalled = ($foundEdgeExes.Count -gt 0) -or ($activeEdgeProcs.Count -gt 0)
$wvInstalled   = ($foundWvExes.Count -gt 0) -or ($activeWvProcs.Count -gt 0)

# ------------------------------------------------------------------------------
# Domain 2: Registry Uninstall Protection Flags
# ------------------------------------------------------------------------------
$edgeUninstallKey = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge"
$edgeNoRemove = $null
if (Test-Path $edgeUninstallKey) {
    $edgeNoRemove = (Get-ItemProperty -Path $edgeUninstallKey -Name "NoRemove" -ErrorAction SilentlyContinue).NoRemove
}

$wvUninstallKey = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView"
$wvNoRemove = $null
$wvSystemComponent = $null
if (Test-Path $wvUninstallKey) {
    $wvProps = Get-ItemProperty -Path $wvUninstallKey -ErrorAction SilentlyContinue
    $wvNoRemove = $wvProps.NoRemove
    $wvSystemComponent = $wvProps.SystemComponent
}

# ------------------------------------------------------------------------------
# Domain 3: Background Update Services
# ------------------------------------------------------------------------------
$serviceNames = @('edgeupdate', 'edgeupdatem', 'MicrosoftEdgeElevationService')
$servicesState = @{}
$servicesDisabled = $true

foreach ($sName in $serviceNames) {
    $svc = Get-Service -Name $sName -ErrorAction SilentlyContinue
    if ($svc) {
        $servicesState[$sName] = @{
            Status    = $svc.Status.ToString()
            StartType = $svc.StartType.ToString()
        }
        if ($svc.StartType.ToString() -ne "Disabled") {
            $servicesDisabled = $false
        }
    } else {
        $servicesState[$sName] = @{
            Status    = "NotFound"
            StartType = "Disabled"
        }
    }
}

# ------------------------------------------------------------------------------
# Domain 4: Scheduled Update Tasks
# ------------------------------------------------------------------------------
$edgeTasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "*Edge*" })
$tasksState = @{}
$tasksDisabled = $true

if ($edgeTasks.Count -gt 0) {
    foreach ($t in $edgeTasks) {
        $tasksState[$t.TaskName] = $t.State.ToString()
        if ($t.State.ToString() -ne "Disabled") {
            $tasksDisabled = $false
        }
    }
} else {
    $tasksDisabled = $true
}

# ------------------------------------------------------------------------------
# Domain 5: Reinstallation Blocker Policies
# ------------------------------------------------------------------------------
$blocker64 = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\EdgeUpdate" -Name "DoNotUpdateToEdgeWithChromium" -ErrorAction SilentlyContinue).DoNotUpdateToEdgeWithChromium
$blocker32 = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate" -Name "DoNotUpdateToEdgeWithChromium" -ErrorAction SilentlyContinue).DoNotUpdateToEdgeWithChromium

$policyKey = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"
$policyProps = Get-ItemProperty $policyKey -ErrorAction SilentlyContinue
$installDefault = if ($policyProps) { $policyProps.InstallDefault } else { $null }
$updateDefault  = if ($policyProps) { $policyProps.UpdateDefault } else { $null }
$policyBlocker  = if ($policyProps) { $policyProps.DoNotUpdateToEdgeWithChromium } else { $null }

$appPathHKLM = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe"
$appPathWOW  = Test-Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe"

$policiesConfigured = ($blocker64 -eq 1) -and ($blocker32 -eq 1) -and ($installDefault -eq 0) -and ($updateDefault -eq 0) -and (-not $appPathHKLM) -and (-not $appPathWOW)

# ------------------------------------------------------------------------------
# Overall Compliance Determination
# ------------------------------------------------------------------------------
$overallCompliant = (-not $edgeInstalled) -and $servicesDisabled -and $tasksDisabled -and $policiesConfigured
$overallStatus = if ($overallCompliant) { "REMOVED_AND_BLOCKED" } else { "INSTALLED_OR_UNBLOCKED" }

# ------------------------------------------------------------------------------
# Output Presentation
# ------------------------------------------------------------------------------
if ($Json) {
    $result = [PSCustomObject]@{
        Timestamp             = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        EdgeInstalled         = $edgeInstalled
        WebView2Installed     = $wvInstalled
        ServicesDisabled      = $servicesDisabled
        TasksDisabled         = $tasksDisabled
        PoliciesConfigured    = $policiesConfigured
        OverallCompliant      = $overallCompliant
        OverallStatus         = $overallStatus
        Details               = [PSCustomObject]@{
            EdgeBinariesFound       = $foundEdgeExes
            WebView2BinariesFound   = $foundWvExes
            EdgeRunningPIDs         = $activeEdgeProcs
            WebView2RunningPIDs     = $activeWvProcs
            BlockerKey64Bit         = $blocker64
            BlockerKey32Bit         = $blocker32
            PolicyInstallDefault    = $installDefault
            PolicyUpdateDefault     = $updateDefault
            PolicyBlocker           = $policyBlocker
            AppPathsCleaned         = (-not $appPathHKLM -and -not $appPathWOW)
            Services                = $servicesState
            ScheduledTasks          = $tasksState
        }
    }
    $result | ConvertTo-Json -Depth 5
    exit 0
}

# Human-Readable CLI Output
Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                   MICROSOFT EDGE & WEBVIEW2 STATUS REPORT                      " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " Generated at: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
Write-Host ""

# Domain 1: Binaries
Write-Host "1. APPLICATION BINARIES & PROCESSES:" -ForegroundColor White
if (-not $edgeInstalled) {
    Write-Host "   [PASS] Microsoft Edge is NOT installed (no binaries or active processes)." -ForegroundColor Green
} else {
    Write-Host "   [FAIL] Microsoft Edge is INSTALLED or RUNNING." -ForegroundColor Red
    if ($foundEdgeExes) { Write-Host "          Files: $($foundEdgeExes -join ', ')" -ForegroundColor Red }
    if ($activeEdgeProcs) { Write-Host "          PIDs:  $($activeEdgeProcs -join ', ')" -ForegroundColor Red }
}

if (-not $wvInstalled) {
    Write-Host "   [INFO] WebView2 Runtime is NOT present." -ForegroundColor Green
} else {
    Write-Host "   [INFO] WebView2 Runtime is PRESENT." -ForegroundColor Yellow
    if ($foundWvExes) { Write-Host "          Files: $($foundWvExes -join ', ')" -ForegroundColor Yellow }
    if ($activeWvProcs) { Write-Host "          PIDs:  $($activeWvProcs -join ', ')" -ForegroundColor Yellow }
}

# Domain 2: Services
Write-Host ""
Write-Host "2. UPDATE SERVICES:" -ForegroundColor White
foreach ($sName in $servicesState.Keys) {
    $info = $servicesState[$sName]
    $st = $info.StartType
    $status = $info.Status
    if ($st -eq "Disabled") {
        Write-Host "   [PASS] $sName : $status (Startup: $st)" -ForegroundColor Green
    } else {
        Write-Host "   [FAIL] $sName : $status (Startup: $st, should be Disabled)" -ForegroundColor Red
    }
}

# Domain 3: Scheduled Tasks
Write-Host ""
Write-Host "3. SCHEDULED UPDATE TASKS:" -ForegroundColor White
if ($tasksDisabled) {
    Write-Host "   [PASS] All Edge update scheduled tasks are disabled or not present." -ForegroundColor Green
} else {
    Write-Host "   [FAIL] One or more Edge scheduled tasks are active:" -ForegroundColor Red
    foreach ($tName in $tasksState.Keys) {
        $tState = $tasksState[$tName]
        $color = if ($tState -eq "Disabled") { "Green" } else { "Red" }
        Write-Host "          - $tName : $tState" -ForegroundColor $color
    }
}

# Domain 4: Blocker Policies
Write-Host ""
Write-Host "4. REINSTALLATION BLOCKER POLICIES:" -ForegroundColor White
if ($blocker64 -eq 1 -and $blocker32 -eq 1) {
    Write-Host "   [PASS] Chromium Blocker Toolkit (DoNotUpdateToEdgeWithChromium=1) active." -ForegroundColor Green
} else {
    Write-Host "   [FAIL] Chromium Blocker Toolkit is NOT fully configured (64-bit=$blocker64, 32-bit=$blocker32)." -ForegroundColor Red
}

if ($installDefault -eq 0 -and $updateDefault -eq 0) {
    Write-Host "   [PASS] Enterprise Group Policy blocker (InstallDefault=0, UpdateDefault=0) active." -ForegroundColor Green
} else {
    Write-Host "   [FAIL] Enterprise Group Policy blocker missing or not set to 0." -ForegroundColor Red
}

if (-not $appPathHKLM -and -not $appPathWOW) {
    Write-Host "   [PASS] CLI registrations ('App Paths\msedge.exe') removed." -ForegroundColor Green
} else {
    Write-Host "   [FAIL] CLI registrations ('App Paths\msedge.exe') still exist in registry." -ForegroundColor Red
}

# Summary
Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
if ($overallCompliant) {
    Write-Host " OVERALL STATUS: [PASS] REMOVED AND BLOCKED (System is fully compliant)         " -ForegroundColor Green
} else {
    Write-Host " OVERALL STATUS: [FAIL] NOT COMPLIANT (Edge present or update unblocked)        " -ForegroundColor Red
}
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

exit (if ($overallCompliant) { 0 } else { 1 })
