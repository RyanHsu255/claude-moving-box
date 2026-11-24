@echo off
rem Double-click launcher: bypasses execution policy and never closes the window by itself.
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0claudemovingbox-wizard.ps1"
echo.
echo (exit code: %errorlevel%)
pause
