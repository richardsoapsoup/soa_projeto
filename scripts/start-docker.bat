@echo off
echo Iniciando arquitetura SOA com Docker Compose no Windows...

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

echo Aguardando servicos inicializarem...
timeout 30

echo Testando servicos...
curl -X POST http://localhost:8000/usuarios/registrar -H "Content-Type: application/json" -d "{\"username\":\"testuser\",\"password\":\"testpass\"}"

if %errorlevel% neq 0 (
    echo Teste falhou - servicos ainda inicializando
)

echo.
echo Para parar os servicos: scripts\stop-docker.bat
echo.
pause