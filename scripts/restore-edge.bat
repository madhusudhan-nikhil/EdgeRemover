@echo off
setlocal EnableDelayedExpansion
title Microsoft Edge Restoration Tool

:: Check for Administrative Privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Requesting administrative elevation for restoring services and policies...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c `\"%~f0`\" %*' -Verb RunAs"
    exit /b
)

:: Elevated Execution Context
cd /d "%~dp0"
echo ===============================================================================
echo                MICROSOFT EDGE RESTORATION - ADMINISTRATOR MODE
echo ===============================================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore-edge.ps1" %*
set SCRIPT_EXIT_CODE=%errorlevel%

echo.
pause
exit /b %SCRIPT_EXIT_CODE%
