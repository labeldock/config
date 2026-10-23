@echo off
rem clipaste paste server (Windows side): status / install / ssh-setup. See clipaste.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0clipaste.ps1" %*
