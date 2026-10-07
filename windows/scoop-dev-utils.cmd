@echo off
rem Install Scoop and selected dev tools. See scoop-dev-utils.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scoop-dev-utils.ps1" %*
