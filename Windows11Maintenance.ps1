#Requires -RunAsAdministrator
param(
    [switch]$AutoReboot,
    [switch]$DeepClean,
    [switch]$EmergencyRepair,
    [switch]$SkipUpdates
)

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script requires Administrator privileges. Please run as Administrator."
    exit 1
}

Write-Host "Windows 11 Maintenance Script" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green

# Basic Cleanup
Write-Host "Performing basic cleanup..." -ForegroundColor Yellow
Get-ChildItem -Path $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
cleanmgr /sagerun:1

# Disk Cleanup
if ($DeepClean) {
    Write-Host "Deep cleaning system..." -ForegroundColor Yellow
    dism /online /cleanup-image /startcomponentcleanup /resetbase
    vssadmin delete shadows /all /quiet
    Get-EventLog -List | ForEach-Object { Clear-EventLog $_.Log -ErrorAction SilentlyContinue }
}

# System File Check
Write-Host "Checking system files..." -ForegroundColor Yellow
sfc /scannow

if ($EmergencyRepair) {
    Write-Host "Emergency repair mode..." -ForegroundColor Red
    dism /online /cleanup-image /restorehealth
    chkdsk C: /f /r /x
}

# Windows Updates
if (-not $SkipUpdates) {
    Write-Host "Installing Windows updates..." -ForegroundColor Yellow
    if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
        Import-Module PSWindowsUpdate
        Get-WUInstall -AcceptAll -AutoReboot:$false
    } else {
        Write-Host "PSWindowsUpdate module not found. Install with: Install-Module PSWindowsUpdate" -ForegroundColor Red
    }
}

# Registry Cleanup
Write-Host "Cleaning registry..." -ForegroundColor Yellow
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" /f 2>$null

Write-Host "Maintenance completed!" -ForegroundColor Green

if ($AutoReboot) {
    Write-Host "Auto-reboot enabled. Restarting in 10 seconds..." -ForegroundColor Red
    shutdown /r /t 10
}