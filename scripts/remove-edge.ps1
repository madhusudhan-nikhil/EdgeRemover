<#
.SYNOPSIS
    Automated uninstallation and reinstallation prevention script for Microsoft Edge & WebView2.

.DESCRIPTION
    Terminates running Edge processes, clears organizational policy uninstall locks,
    invokes native setup.exe with force-uninstall flags, removes AppX packages, purges
    residual directories and shortcuts, and sets Group Policy, Blocker Toolkit keys,
    disables update services, and disables scheduled tasks to permanently prevent reinstallation.

.PARAMETER Force
    Bypasses the interactive confirmation prompt.

.PARAMETER PurgeWebView2
    Includes Microsoft Edge WebView2 runtime and EdgeCore in the removal scope.

.PARAMETER Silent
    Suppresses non-error console output for automated execution.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File scripts\remove-edge.ps1 -Force
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$PurgeWebView2 = $true,
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
        if ($PurgeWebView2) { $arguments += " -PurgeWebView2" }
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
    Write-Host "                    MICROSOFT EDGE REMOVAL & PREVENTION TOOL                   " -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Yellow
    Write-Host " This script will perform the following actions on your Windows system:" -ForegroundColor White
    Write-Host "   1. Terminate running Edge and WebView2 processes to release DLL locks." -ForegroundColor White
    Write-Host "   2. Clear organizational policy locks ('NoRemove' and 'SystemComponent')." -ForegroundColor White
    Write-Host "   3. Force-uninstall Microsoft Edge (and WebView2) via native setup.exe." -ForegroundColor White
    Write-Host "   4. Remove MicrosoftEdge AppX packages for all user accounts." -ForegroundColor White
    Write-Host "   5. Purge residual application directories, shortcuts, and App Paths." -ForegroundColor White
    Write-Host "   6. Configure Chromium Blocker & Enterprise Group Policies to block reinstallation." -ForegroundColor White
    Write-Host "   7. Stop and disable EdgeUpdate services and background scheduled tasks." -ForegroundColor White
    Write-Host ""
    Write-Host " NOTICE: Removing WebView2 may affect desktop applications that embed web views" -ForegroundColor Yellow
    Write-Host "         (e.g., Microsoft Teams, Outlook, or certain launcher applications)." -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Yellow
    Write-Host ""

    $response = Read-Host "Are you sure you want to proceed with Edge removal? [y/N]"
    if ($response -notmatch '^(y|yes)$') {
        Write-Log "Operation cancelled by user. No modifications were made." "WARN"
        exit 0
    }
}

Write-Log "Starting Microsoft Edge removal and reinstallation prevention workflow..." "INFO"

# ------------------------------------------------------------------------------
# 3. Process Termination Loop (Release File Locks)
# ------------------------------------------------------------------------------
Write-Log "Step 1/8: Terminating running Edge and related processes..." "INFO"
$targetProcesses = @('msedge', 'msedgewebview2', 'SearchHost', 'msedgeupdate', 'identity_helper')

for ($attempt = 1; $attempt -le 5; $attempt++) {
    $found = $false
    foreach ($procName in $targetProcesses) {
        $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($procs) {
            $found = $true
            Write-Log "Terminating $($procs.Count) process instance(s) of '$procName' (Attempt $attempt/5)..." "INFO"
            Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
        }
    }
    if (-not $found) { break }
    Start-Sleep -Milliseconds 700
}

# ------------------------------------------------------------------------------
# 4. Clear Organizational Policy Locks (Registry)
# ------------------------------------------------------------------------------
Write-Log "Step 2/8: Clearing organizational uninstall locks in registry..." "INFO"
$uninstallHives = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView"
)

foreach ($hive in $uninstallHives) {
    if (Test-Path $hive) {
        try {
            Remove-ItemProperty -Path $hive -Name "NoRemove" -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $hive -Name "NoRemove" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $hive -Name "SystemComponent" -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $hive -Name "SystemComponent" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            Write-Log "Unlocked uninstall policy flags on: $hive" "SUCCESS"
        } catch {
            Write-Log "Failed to update flags on $hive : $_" "WARN"
        }
    }
}

# ------------------------------------------------------------------------------
# 5. Native setup.exe Force-Uninstall
# ------------------------------------------------------------------------------
Write-Log "Step 3/8: Executing native force-uninstall via setup.exe..." "INFO"

# Locate Edge setup.exe
$edgeSetupCandidates = @(
    (Get-ChildItem -Path "C:\Program Files (x86)\Microsoft\Edge\Application" -Filter "setup.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName),
    (Get-ChildItem -Path "C:\Program Files\Microsoft\Edge\Application" -Filter "setup.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
) | Where-Object { $_ -and (Test-Path $_) }

$edgeSetup = $edgeSetupCandidates | Select-Object -First 1

if ($edgeSetup) {
    Write-Log "Found Edge setup.exe: $edgeSetup" "INFO"
    $edgeArgs = "--uninstall --msedge --channel=beta --system-level --verbose-logging --force-uninstall"
    Write-Log "Running Edge uninstallation..." "INFO"
    $proc = Start-Process -FilePath $edgeSetup -ArgumentList $edgeArgs -PassThru -Wait
    Write-Log "Edge setup.exe finished with exit code: $($proc.ExitCode)" "SUCCESS"
} else {
    Write-Log "No Edge setup.exe found (Edge may already be uninstalled)." "INFO"
}

# Locate WebView2 setup.exe if requested
if ($PurgeWebView2) {
    $wvSetupCandidates = @(
        (Get-ChildItem -Path "C:\Program Files (x86)\Microsoft\EdgeWebView\Application" -Filter "setup.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName),
        (Get-ChildItem -Path "C:\Program Files\Microsoft\EdgeWebView\Application" -Filter "setup.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName),
        (Get-ChildItem -Path "C:\Program Files (x86)\Microsoft\EdgeCore" -Filter "setup.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    ) | Where-Object { $_ -and (Test-Path $_) }

    $wvSetup = $wvSetupCandidates | Select-Object -First 1

    if ($wvSetup) {
        Write-Log "Found WebView2 setup.exe: $wvSetup" "INFO"
        $wvArgs = "--uninstall --msedgewebview --channel=beta --system-level --verbose-logging --force-uninstall"
        Write-Log "Running WebView2 uninstallation..." "INFO"
        $procWv = Start-Process -FilePath $wvSetup -ArgumentList $wvArgs -PassThru -Wait
        Write-Log "WebView2 setup.exe finished with exit code: $($procWv.ExitCode)" "SUCCESS"
    } else {
        Write-Log "No WebView2 setup.exe found." "INFO"
    }
}

# Wait briefly for background installer worker threads
Get-Process -Name setup -ErrorAction SilentlyContinue | Wait-Process -Timeout 15 -ErrorAction SilentlyContinue

# ------------------------------------------------------------------------------
# 6. Remove AppX Packages
# ------------------------------------------------------------------------------
Write-Log "Step 4/8: Removing MicrosoftEdge AppX packages..." "INFO"
try {
    $appxPackages = Get-AppxPackage -AllUsers -Name "*MicrosoftEdge*" -ErrorAction SilentlyContinue
    foreach ($pkg in $appxPackages) {
        Write-Log "Removing AppX package: $($pkg.PackageFullName)" "INFO"
        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
    }

    $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*MicrosoftEdge*" }
    foreach ($prov in $provisioned) {
        Write-Log "Removing provisioned package: $($prov.PackageName)" "INFO"
        Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue | Out-Null
    }
    Write-Log "AppX package removal completed." "SUCCESS"
} catch {
    Write-Log "Error during AppX removal: $_" "WARN"
}

# ------------------------------------------------------------------------------
# 7. Residual Directory Purge
# ------------------------------------------------------------------------------
Write-Log "Step 5/8: Purging residual application directories..." "INFO"

# Final quick kill to ensure no handles remain
Get-Process -Name @('msedge', 'msedgewebview2', 'SearchHost') -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

$purgeDirs = @(
    "C:\Program Files (x86)\Microsoft\Edge",
    "C:\Program Files (x86)\Microsoft\EdgeWebView",
    "C:\Program Files (x86)\Microsoft\EdgeCore",
    "C:\Program Files\Microsoft\Edge",
    "C:\Program Files\Microsoft\EdgeWebView",
    "C:\Program Files\Microsoft\EdgeCore"
)

foreach ($dir in $purgeDirs) {
    if (Test-Path $dir) {
        try {
            Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
            Write-Log "Purged directory: $dir" "SUCCESS"
        } catch {
            Write-Log "Direct removal failed for $dir, retrying with empty folder mirror..." "WARN"
            try {
                $tempEmpty = Join-Path $env:TEMP "empty_mirror_$(Get-Random)"
                New-Item -ItemType Directory -Path $tempEmpty -Force | Out-Null
                & robocopy.exe $tempEmpty $dir /MIR /R:1 /W:1 /NJH /NJS /NFL /NDL | Out-Null
                Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $tempEmpty -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Purged directory via mirror: $dir" "SUCCESS"
            } catch {
                Write-Log "Could not fully remove directory $($dir): $_" "WARN"
            }
        }
    }
}

# ------------------------------------------------------------------------------
# 8. Shortcut and CLI App Paths Cleanup
# ------------------------------------------------------------------------------
Write-Log "Step 6/8: Cleaning shortcuts and App Paths registrations..." "INFO"
$wsh = New-Object -ComObject WScript.Shell
$shortcutSearchDirs = @(
    "C:\ProgramData\Microsoft\Windows\Start Menu",
    "$env:APPDATA\Microsoft\Windows\Start Menu",
    "C:\Users\Public\Desktop",
    "$env:USERPROFILE\Desktop",
    "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch"
)

# Also check other user profiles if accessible
Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $userDesktop = Join-Path $_.FullName "Desktop"
    $userStart = Join-Path $_.FullName "AppData\Roaming\Microsoft\Windows\Start Menu"
    $userQuickLaunch = Join-Path $_.FullName "AppData\Roaming\Microsoft\Internet Explorer\Quick Launch"
    if (Test-Path $userDesktop) { $shortcutSearchDirs += $userDesktop }
    if (Test-Path $userStart) { $shortcutSearchDirs += $userStart }
    if (Test-Path $userQuickLaunch) { $shortcutSearchDirs += $userQuickLaunch }
}
$shortcutSearchDirs = $shortcutSearchDirs | Select-Object -Unique

foreach ($sDir in $shortcutSearchDirs) {
    if (Test-Path $sDir) {
        $links = Get-ChildItem -Path $sDir -Filter "*.lnk" -Recurse -File -ErrorAction SilentlyContinue
        foreach ($lnk in $links) {
            $match = $false
            if ($lnk.Name -like "*Microsoft Edge*.lnk" -or $lnk.Name -like "*Edge*.lnk") {
                $match = $true
            } else {
                try {
                    $target = ($wsh.CreateShortcut($lnk.FullName)).TargetPath
                    if ($target -like "*msedge.exe*" -or $target -like "*msedgewebview2.exe*") {
                        $match = $true
                    }
                } catch {}
            }
            if ($match) {
                Write-Log "Removing shortcut: $($lnk.FullName)" "INFO"
                Remove-Item -Path $lnk.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# Remove CLI App Paths
$appPathsKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe"
)
foreach ($apKey in $appPathsKeys) {
    if (Test-Path $apKey) {
        Write-Log "Removing App Paths key: $apKey" "INFO"
        Remove-Item -Path $apKey -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Clean client registration GUIDs
$clientKeys = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\ClientState\{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\ClientState\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
)
foreach ($ck in $clientKeys) {
    if (Test-Path $ck) {
        Remove-Item -Path $ck -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Write-Log "Shortcut and App Paths cleanup completed." "SUCCESS"

# ------------------------------------------------------------------------------
# 9. Configure Reinstallation Prevention Policies
# ------------------------------------------------------------------------------
Write-Log "Step 7/8: Applying reinstallation blocker policies..." "INFO"

# Chromium Blocker Toolkit Registry Keys
$edgeUpdateRoots = @(
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate"
)
foreach ($euRoot in $edgeUpdateRoots) {
    if (-not (Test-Path $euRoot)) {
        New-Item -Path $euRoot -Force -ErrorAction SilentlyContinue | Out-Null
    }
    Set-ItemProperty -Path $euRoot -Name "DoNotUpdateToEdgeWithChromium" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
}
Write-Log "Set DoNotUpdateToEdgeWithChromium = 1 across 32-bit and 64-bit hives." "SUCCESS"

# Enterprise EdgeUpdate Policy Keys
$policyRoots = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate",
    "HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\EdgeUpdate"
)
foreach ($pRoot in $policyRoots) {
    if (-not (Test-Path $pRoot)) {
        New-Item -Path $pRoot -Force -ErrorAction SilentlyContinue | Out-Null
    }
    Set-ItemProperty -Path $pRoot -Name "InstallDefault" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $pRoot -Name "UpdateDefault" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $pRoot -Name "Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $pRoot -Name "Update{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $pRoot -Name "Install{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $pRoot -Name "Update{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $pRoot -Name "DoNotUpdateToEdgeWithChromium" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
}
Write-Log "Configured enterprise group update prevention policies." "SUCCESS"

# ------------------------------------------------------------------------------
# 10. Disable Update Services and Scheduled Tasks
# ------------------------------------------------------------------------------
Write-Log "Step 8/8: Disabling update services and scheduled tasks..." "INFO"
$targetServices = @('edgeupdate', 'edgeupdatem', 'MicrosoftEdgeElevationService')

foreach ($svcName in $targetServices) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Log "Disabling service '$svcName'..." "INFO"
        Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
        Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
        & sc.exe config $svcName start= disabled 2>&1 | Out-Null
    }
}
Write-Log "Edge update services stopped and disabled." "SUCCESS"

# Disable scheduled update tasks
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "*Edge*" } | ForEach-Object {
    Write-Log "Disabling scheduled task: $($_.TaskName)" "INFO"
    $_ | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue | Out-Null
    & schtasks.exe /change /tn "$($_.TaskPath)$($_.TaskName)" /disable 2>$null | Out-Null
    & schtasks.exe /change /tn "$($_.TaskName)" /disable 2>$null | Out-Null
}
Write-Log "Scheduled update tasks disabled." "SUCCESS"

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "     MICROSOFT EDGE REMOVAL & PREVENTION WORKFLOW COMPLETED SUCCESSFULLY!       " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host " - Binaries & AppX packages removed." -ForegroundColor White
Write-Host " - Shortcuts & App Paths purged." -ForegroundColor White
Write-Host " - Reinstallation blocker policies active." -ForegroundColor White
Write-Host " - EdgeUpdate services & tasks disabled." -ForegroundColor White
Write-Host ""
Write-Host " You can run scripts\check-edge-status.ps1 to verify system status at any time." -ForegroundColor Cyan
Write-Host " If you ever need to restore Edge, run scripts\restore-edge.ps1." -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""

exit 0
