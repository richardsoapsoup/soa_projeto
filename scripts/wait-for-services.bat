@echo off
echo Aguardando servicos ficarem disponiveis...

set /a max_attempts=30
set /a attempt=1

:check_loop
echo.
echo Tentativa %attempt% de %max_attempts%...

set /a ready_count=0

echo Verificando servicos...

REM Verificar API Gateway
curl -s -f http://localhost:8000/health >nul 2>&1
if %errorlevel% equ 0 (
    echo API Gateway esta pronto
    set /a ready_count+=1
) else (
    echo API Gateway ainda nao esta pronto
)

REM Verificar Consul
curl -s -f http://localhost:8500/v1/agent/self >nul 2>&1
if %errorlevel% equ 0 (
    echo Consul esta pronto
    set /a ready_count+=1
) else (
    echo Consul ainda nao esta pronto
)

REM Verificar Kafka
docker exec kafka kafka-topics --bootstrap-server localhost:29092 --list >nul 2>&1
if %errorlevel% equ 0 (
    echo Kafka esta pronto
    set /a ready_count+=1
) else (
    echo Kafka ainda nao esta pronto
)

if %ready_count% equ 3 (
    echo.
    echo Todos os servicos estao prontos!
    goto :end
)

if %attempt% geq %max_attempts% (
    echo.
    echo Timeout: Alguns servicos nao ficaram prontos a tempo
    goto :end
)

set /a attempt+=1
echo Aguardando 5 segundos...
ping -n 5 127.0.0.1 > nul
goto :check_loop

:end