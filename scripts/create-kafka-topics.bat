@echo off
echo Criando topicos Kafka...

echo Aguardando Kafka ficar disponivel...
:check_kafka
docker exec kafka kafka-topics --bootstrap-server localhost:29092 --list >nul 2>&1
if %errorlevel% neq 0 (
    echo Kafka ainda nao esta pronto, aguardando...
    timeout 5
    goto :check_kafka
)

echo Criando topico user-events...
docker exec kafka kafka-topics --bootstrap-server localhost:29092 --create --topic user-events --partitions 1 --replication-factor 1

echo Criando topico post-events...
docker exec kafka kafka-topics --bootstrap-server localhost:29092 --create --topic post-events --partitions 1 --replication-factor 1

echo Listando topicos criados...
docker exec kafka kafka-topics --bootstrap-server localhost:29092 --list

echo.
echo Topicos Kafka criados com sucesso!