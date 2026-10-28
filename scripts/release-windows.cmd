@echo off
rem Double-click to publish the Windows release to GitHub (asks for the token in a password dialog).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0release-windows.ps1"
echo.
pause
