@echo off
echo Iniciando arquitetura SOA com Docker Compose no Windows...

echo Verificando estrutura de diretorios...
if not exist prometheus mkdir prometheus
if not exist logs mkdir logs
if not exist data mkdir data

echo Build das imagens...
docker-compose build

echo Iniciando serviços...
docker-compose up -d

echo.
echo Servicos iniciados:
echo - API Gateway: http://localhost:8000
echo - Consul UI: http://localhost:8500
echo - Prometheus: http://localhost:9090
echo - Grafana: http://localhost:3000 (admin/admin)
echo.

echo Aguardando servicos inicializarem (60 segundos)...
ping -n 60 127.0.0.1 > nul

echo Verificando status dos containers...
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo.
echo Para parar os servicos: scripts\stop-docker.bat
echo.
pause