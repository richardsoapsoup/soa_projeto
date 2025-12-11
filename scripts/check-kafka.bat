@echo off
echo Verificando status do Kafka...

echo.
echo 1. Verificando containers...
docker ps --filter "name=kafka" --format "table {{.Names}}\t{{.Status}}"

echo.
echo 2. Verificando saúde do Kafka...
docker inspect kafka --format "{{json .State.Health }}" | findstr /I "healthy" >nul
if %errorlevel% equ 0 (
    echo Status: healthy
) else (
    echo Status: unhealthy
)

echo.
echo 3. Listando tópicos...
docker exec kafka kafka-topics --bootstrap-server localhost:29092 --list

echo.
echo 4. Verificando detalhes dos tópicos...
for /f "tokens=*" %%i in ('docker exec kafka kafka-topics --bootstrap-server localhost:29092 --list ^| findstr /V "__consumer_offsets" ^| findstr /V "service-logs" ^| findstr /V "health-check"') do (
    echo Topico: %%i
    docker exec kafka kafka-topics --bootstrap-server localhost:29092 --topic %%i --describe
)

echo.
echo 5. Testando produção de mensagem...

echo "test_key:test_value" | docker exec -i kafka kafka-console-producer --broker-list localhost:29092 --topic test-topic --property "parse.key=true" --property "key.separator=:" 2>NUL

echo.
echo 6. Testando consumo de mensagem...

docker exec kafka kafka-console-consumer --bootstrap-server localhost:29092 --topic test-topic --from-beginning --max-messages 1 --timeout-ms 5000 >NUL 2>&1

if %errorlevel% equ 0 (
    echo Kafka esta funcionando corretamente
) else (
    echo Kafka com problemas de consumo - Erro %errorlevel%
)

echo.
echo Verificação do Kafka concluída!