@echo off
setlocal enableextensions enabledelayedexpansion

echo 1. Aguardando Grafana...

:wait
curl -s http://localhost:3000/api/health >nul
if errorlevel 1 (
    echo Grafana nao esta pronto, aguardando...
    timeout /t 3 >nul
    goto wait
)
echo OK!
echo.

set "PS_SCRIPT=%CD%\setup_grafana_temp.ps1"
set "DASH_JSON=%CD%\dash_temp.json"

if exist "%PS_SCRIPT%" del "%PS_SCRIPT%"
if exist "%DASH_JSON%" del "%DASH_JSON%"

echo 2. Salvando dashboard JSON...

(
echo {
echo   "dashboard": {
echo     "id": null,
echo     "uid": "soa-monitoring",
echo     "title": "SOA Architecture Monitoring",
echo     "timezone": "browser",
echo     "schemaVersion": 35,
echo     "version": 1,
echo     "refresh": "10s",
echo     "panels": [
echo       {
echo         "id": 5,
echo         "title": "Service Health",
echo         "type": "stat",
echo         "targets": [
echo           { "expr": "up{job=~\"api-gateway^|usuarios-service^|posts-service\"}", "legendFormat": "{{job}}", "refId": "A" }
echo         ],
echo         "gridPos": { "h": 8, "w": 8, "x": 16, "y": 8 }
echo       }
echo     ]
echo   },
echo   "folderId": 0,
echo   "overwrite": true
echo }
) > "%DASH_JSON%"

echo JSON OK
echo.

echo 3. Criando script PowerShell...

(
echo $ErrorActionPreference = "Stop"
echo $headers = @{^"Content-Type^"=^"application/json^"; ^"Accept^"=^"application/json^"}
echo $auth = ^"admin:admin^"
echo $bytes = [System.Text.Encoding]::UTF8.GetBytes^($auth^)
echo $b64 = [Convert]::ToBase64String^($bytes^)
echo $headers.Authorization = ^"Basic $b64^"
echo Write-Host ^"Criando datasource...^"
echo $datasource = @{
echo   name = ^"Prometheus^"
echo   type = ^"prometheus^"
echo   access = ^"proxy^"
echo   url = ^"http://prometheus:9090^"
echo   isDefault = $true
echo   jsonData = @{
echo      timeInterval = ^"15s^"
echo      queryTimeout = ^"60s^"
echo   }
echo } ^| ConvertTo-Json -Depth 10
echo try {
echo   Invoke-RestMethod -Uri ^"http://localhost:3000/api/datasources^" -Method Post -Headers $headers -Body $datasource
echo   Write-Host ^"Datasource OK!^" -ForegroundColor Green
echo } catch {
echo   Write-Host ^"Erro datasource:^" $_.Exception.Message -ForegroundColor Red
echo }
echo Write-Host ^"Importando dashboard...^"
echo $dash = Get-Content ^"%DASH_JSON%^" -Raw
echo Invoke-RestMethod -Uri ^"http://localhost:3000/api/dashboards/db^" -Method Post -Headers $headers -Body $dash
echo Write-Host ^"Dashboard importado!^" -ForegroundColor Green
) > "%PS_SCRIPT%"

echo Script PS OK
echo.

echo Executando script...
powershell -ExecutionPolicy Bypass -File "%PS_SCRIPT%"

echo Limpando arquivos temporarios...
del "%PS_SCRIPT%"
del "%DASH_JSON%"

echo.
echo Grafana configurado com sucesso!
echo Dashboard: http://localhost:3000/d/soa-monitoring
echo.

endlocal
