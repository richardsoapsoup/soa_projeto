@echo off
echo ====================================
echo    CONFIGURACAO DE MONITORAMENTO
echo ====================================

echo.
echo 1. Verificando servicos de monitoramento...
docker ps --filter "name=prometheus" --format "table {{.Names}}\t{{.Status}}"
docker ps --filter "name=grafana" --format "table {{.Names}}\t{{.Status}}"

echo.
echo 2. Configurando Grafana...
call setup-grafana.bat

echo.
echo 3. Verificando metricas no Prometheus (up)...

curl -s "http://localhost:9090/api/v1/query?query=up" | findstr /I "up" >NUL
if %errorlevel% equ 0 (
    echo Prometheus API esta respondendo com metricas 'up'.
) else (
    echo Prometheus API nao esta respondendo ou metricas 'up' ausentes.
)

echo.
echo 4. URLs de Monitoramento:
echo.
echo Prometheus:  http://localhost:9090
echo Grafana:     http://localhost:3000
echo    Usuario:     admin
echo    Senha:       admin
echo.
echo Dashboard:   http://localhost:3000/d/soa-monitoring
echo.

echo 5. Testando consultas Prometheus...
echo.
echo "Consultas exemplo:"
echo "  requests_total"
echo "  rate(requests_total[5m])"
echo "  up{job='api-gateway'}"
echo "  user_registrations_total"
echo.

echo Configuracao de monitoramento concluida!
pause