@echo off
rem Windows OpenSSH server / ed25519 key / authorized_keys manager. See ssh-server.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ssh-server.ps1" %*
