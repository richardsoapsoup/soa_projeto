@echo off
echo Instalando dependencias do Windows...

echo Verificando se Chocolatey esta instalado...
choco --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Instalando Chocolatey...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
    set PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin
)

echo Instalando curl...
choco install curl -y

echo Instalando jq para JSON...
choco install jq -y

echo.
echo Dependencias instaladas!
echo.
pause