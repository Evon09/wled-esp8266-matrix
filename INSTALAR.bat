@echo off
rem Duplo clique para instalar. Abre o instalador em PowerShell (a politica de execucao vale so para esta janela).
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalador\instalar.ps1" %*
echo.
pause
