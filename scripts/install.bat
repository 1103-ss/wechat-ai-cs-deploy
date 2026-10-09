@echo off
rem ============================================================
rem  WeChat AI Service - one-shot installer launcher (ASCII only)
rem  Ensures Python 3.10-3.12 (auto download from China mirrors),
rem  installs deps, creates config, runs the doctor.
rem  Add "--git" to also install Git for Windows (China mirror):
rem     install.bat --git
rem ============================================================
setlocal
cd /d "%~dp0\.."

echo ============================================
echo   WeChat AI Service - Installer
echo ============================================

set "EXTRA="
if /I "%~1"=="--git" set "EXTRA=-WithGit"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_windows.ps1" %EXTRA%
set RC=%ERRORLEVEL%

echo.
if "%RC%"=="0" (
  echo Install finished with no hard failures.
) else (
  echo Install finished with issues ^(exit code %RC%^). Read the output above.
)
echo Next: start.bat  ^|  activate wxautox4  ^|  see AGENTS.md for AI agents.
pause
exit /b %RC%
