@echo off
rem ============================================================
rem  WeChat AI Service - one-shot installer (run after git clone)
rem  ASCII only on purpose (GBK console safety).
rem ============================================================
setlocal
cd /d "%~dp0\.."

echo ============================================
echo   WeChat AI Service - Installer
echo ============================================

where python >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Python not found in PATH. Install Python 3.10+ first:
  echo         https://www.python.org/downloads/  ^(tick "Add to PATH"^)
  pause
  exit /b 1
)

echo [1/3] Installing Python dependencies (Tsinghua mirror first)...
python -m pip install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple
python -m pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
if errorlevel 1 (
  echo [WARN] Tsinghua mirror failed, trying official PyPI...
  python -m pip install -r requirements.txt
)
if errorlevel 1 (
  echo [ERROR] pip install failed. Check network and re-run this script.
  pause
  exit /b 1
)

echo [2/3] Creating local config from template...
if not exist "config" mkdir config
if not exist "config\config.json" (
  copy /y "config.example.json" "config\config.json" >nul
  echo       config\config.json created.
) else (
  echo       config\config.json already exists, kept as-is.
)

echo [3/3] Running environment doctor...
python scripts\doctor.py

echo.
echo ============================================
echo   Install finished. Next steps:
echo   1. Activate wxautox4:  wxautox4 auth activate ^<YOUR_CODE^>
echo   2. Start the panel:    start.bat
echo   3. Login admin/123456, set your API keys in the panel.
echo ============================================
pause
