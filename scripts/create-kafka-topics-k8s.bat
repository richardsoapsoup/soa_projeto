@echo off
echo Criando topicos Kafka no Kubernetes...

echo Aguardando Kafka ficar pronto...
timeout 60

echo Criando topico user-events...
kubectl exec -n soa-architecture deployment/kafka -- kafka-topics --create --topic user-events --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1

echo Criando topico post-events...
kubectl exec -n soa-architecture deployment/kafka -- kafka-topics --create --topic post-events --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1

echo Listando topicos...
kubectl exec -n soa-architecture deployment/kafka -- kafka-topics --list --bootstrap-server localhost:9092

echo.
echo Topicos criados com sucesso!
pause