@echo off
rem Hyper-V VM auto-logon / keep-display setup. See hyperv-autologon.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0hyperv-autologon.ps1" %*
