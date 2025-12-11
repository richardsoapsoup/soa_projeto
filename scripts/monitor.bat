@echo off
echo Iniciando monitoramento dos servicos...

echo Abrindo Consul UI...
start http://localhost:8500

echo Abrindo Prometheus...
start http://localhost:9090

echo Abrindo Grafana...
start http://localhost:3000

echo.
echo Monitoramento iniciado!
echo - Consul: http://localhost:8500
echo - Prometheus: http://localhost:9090
echo - Grafana: http://localhost:3000 (admin/admin)
echo.

echo Pressione Ctrl+C para parar o monitoramento...
pause