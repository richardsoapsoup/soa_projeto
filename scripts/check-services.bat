@echo off
echo Verificando status dos servicos...

echo.
echo Containers Docker:
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo.
echo Servicos Kubernetes:
kubectl get pods -n soa-architecture

echo.
echo URLs dos servicos:
echo API Gateway: http://localhost:8000
echo Consul:     http://localhost:8500
echo Prometheus: http://localhost:9090
echo Grafana:    http://localhost:3000

echo.
pause