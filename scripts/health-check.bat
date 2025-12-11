@echo off
echo Verificando saúde dos servicos...

echo.
echo 1. Verificando containers...
docker ps --format "table {{.Names}}\t{{.Status}}"

echo.
echo 2. Verificando saúde da API...
curl -s -o nul -w "%%{http_code}" http://localhost:8000/health
if %errorlevel% equ 0 (
    echo API Gateway esta respondendo
) else (
    echo API Gateway nao esta respondendo
)

echo.
echo 3. Verificando Consul...
curl -s -o nul -w "%%{http_code}" http://localhost:8500/v1/agent/self
if %errorlevel% equ 0 (
    echo Consul esta respondendo
) else (
    echo Consul nao esta respondendo
)

echo.
echo 4. Verificando Kafka...
docker exec kafka kafka-topics --bootstrap-server localhost:29092 --list >nul 2>&1
if %errorlevel% equ 0 (
    echo Kafka esta respondendo
) else (
    echo Kafka nao esta respondendo
)

echo.
echo Verificacao concluida!