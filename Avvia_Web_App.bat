@echo off
cd /d "%~dp0"
echo =======================================================
echo   WILD-CARDS Burraco: Avvio WebApp Locale Mobile
echo =======================================================
echo.
echo Avvio del server web con supporto mobile e WebAssembly...
echo.
start http://localhost:8080
python serve_web.py
pause
