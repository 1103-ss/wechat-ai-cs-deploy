@echo off
rem ============================================================
rem  WeChat AI Service - start the web control panel
rem  ASCII only on purpose (GBK console safety).
rem ============================================================
setlocal
cd /d "%~dp0"

if not exist "config\config.json" (
  echo [ERROR] config\config.json not found.
  echo         Run scripts\install.bat first.
  pause
  exit /b 1
)

echo Starting control panel...
echo Browser will open automatically. Default login: admin / 123456
echo Keep this window open. Press Ctrl+C to stop.
python -B web_server.py
pause
