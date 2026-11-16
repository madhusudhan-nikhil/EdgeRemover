<#
.SYNOPSIS
    Restoration and policy unblocking script for Microsoft Edge & WebView2.

.DESCRIPTION
    Reverses reinstallation prevention policies, clears Blocker Toolkit keys,
    re-enables background update services (edgeupdate, edgeupdatem, elevation service)
    and scheduled tasks to allow Microsoft Edge and WebView2 to be reinstalled or updated.

.PARAMETER Force
    Bypasses the interactive confirmation prompt.

.PARAMETER Silent
    Suppresses non-error console output for automated execution.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File scripts\restore-edge.ps1 -Force
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Silent
)

$ErrorActionPreference = "Continue"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    if ($Silent -and $Level -eq "INFO") { return }

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    switch ($Level) {
        "SUCCESS" { Write-Host "[$timestamp] [SUCCESS] $Message" -ForegroundColor Green }
        "WARN"    { Write-Host "[$timestamp] [WARN]    $Message" -ForegroundColor Yellow }
        "ERROR"   { Write-Host "[$timestamp] [ERROR]   $Message" -ForegroundColor Red }
        Default   { Write-Host "[$timestamp] [INFO]    $Message" -ForegroundColor Cyan }
    }
}

# ------------------------------------------------------------------------------
# 1. Elevation Verification
# ------------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Log "Administrative privileges required. Attempting self-elevation..." "WARN"
    try {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        if ($Force) { $arguments += " -Force" }
        if ($Silent) { $arguments += " -Silent" }

        $elevatedProcess = Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -Verb RunAs -PassThru -Wait
        exit $elevatedProcess.ExitCode
    } catch {
        Write-Log "Failed to elevate process: $_" "ERROR"
        Write-Log "Please run this script from an elevated (Administrator) PowerShell window." "ERROR"
        exit 1
    }
}

# ------------------------------------------------------------------------------
# 2. Interactive Safety Confirmation
# ------------------------------------------------------------------------------
if (-not $Force -and -not $Silent) {
    Write-Host ""
    Write-Host "================================================================================" -ForegroundColor Yellow
    Write-Host "                    MICROSOFT EDGE RESTORATION & UNBLOCK TOOL                  " -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Yellow
    Write-Host " This script will restore the system's ability to install Microsoft Edge:" -ForegroundColor White
    Write-Host "   1. Clear Chromium Blocker Toolkit keys ('DoNotUpdateToEdgeWithChromium')." -ForegroundColor White
    Write-Host "   2. Remove Enterprise Group Policies blocking Edge and WebView2 updates." -ForegroundColor White
    Write-Host "   3. Restore update services ('edgeupdate', 'edgeupdatem') to Demand start." -ForegroundColor White
    Write-Host "   4. Re-enable EdgeUpdate background scheduled tasks." -ForegroundColor White
    Write-Host ""
    Write-Host " After unblocking, you can reinstall Edge or WebView2 whenever you choose." -ForegroundColor White
    Write-Host "================================================================================" -ForegroundColor Yellow
    Write-Host ""

    $response = Read-Host "Are you sure you want to restore Edge policies and update services? [y/N]"
    if ($response -notmatch '^(y|yes)$') {
        Write-Log "Restoration cancelled by user. No modifications were made." "WARN"
        exit 0
    }
}

Write-Log "Starting Microsoft Edge policy unblock and service restoration..." "INFO"

# ------------------------------------------------------------------------------
# 3. Clear Blocker Toolkit Registry Values
# ------------------------------------------------------------------------------
Write-Log "Step 1/3: Clearing Chromium Blocker Toolkit registry keys..." "INFO"
$edgeUpdateRoots = @(
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate"
)

foreach ($euRoot in $edgeUpdateRoots) {
    if (Test-Path $euRoot) {
        Remove-ItemProperty -Path $euRoot -Name "DoNotUpdateToEdgeWithChromium" -ErrorAction SilentlyContinue
        Write-Log "Removed DoNotUpdateToEdgeWithChromium from $euRoot" "SUCCESS"
    }
}

# Remove Enterprise Group Policy block keys
$policyRoots = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate",
    "HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\EdgeUpdate"
)
foreach ($pRoot in $policyRoots) {
    if (Test-Path $pRoot) {
        Remove-Item -Path $pRoot -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Removed Enterprise Policy key: $pRoot" "SUCCESS"
    }
}

# ------------------------------------------------------------------------------
# 4. Restore Update Services
# ------------------------------------------------------------------------------
Write-Log "Step 2/3: Restoring Edge update background services..." "INFO"
$targetServices = @('edgeupdate', 'edgeupdatem', 'MicrosoftEdgeElevationService')

foreach ($svcName in $targetServices) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Log "Configuring service '$svcName' to Manual (Demand) start..." "INFO"
        Set-Service -Name $svcName -StartupType Manual -ErrorAction SilentlyContinue
        & sc.exe config $svcName start= demand 2>&1 | Out-Null
    }
}
Write-Log "Edge update services re-enabled." "SUCCESS"

# ------------------------------------------------------------------------------
# 5. Re-enable Scheduled Tasks
# ------------------------------------------------------------------------------
Write-Log "Step 3/3: Re-enabling Edge scheduled update tasks..." "INFO"
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "*Edge*" } | ForEach-Object {
    Write-Log "Enabling scheduled task: $($_.TaskName)" "INFO"
    $_ | Enable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
    Enable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue | Out-Null
    & schtasks.exe /change /tn "$($_.TaskPath)$($_.TaskName)" /enable 2>$null | Out-Null
    & schtasks.exe /change /tn "$($_.TaskName)" /enable 2>$null | Out-Null
}
Write-Log "Scheduled tasks re-enabled." "SUCCESS"

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "       EDGE UPDATE POLICIES AND SERVICES RESTORED SUCCESSFULLY!                 " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host " - Blocker Toolkit and Enterprise Policies removed." -ForegroundColor White
Write-Host " - EdgeUpdate services restored to Demand start." -ForegroundColor White
Write-Host " - Scheduled update tasks re-enabled." -ForegroundColor White
Write-Host ""
Write-Host " You can now install Edge via official installer or winget:" -ForegroundColor Cyan
Write-Host "   winget install Microsoft.Edge" -ForegroundColor Yellow
Write-Host "   winget install Microsoft.EdgeWebView2Runtime" -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""

exit 0
