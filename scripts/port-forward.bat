@echo off
echo Iniciando port-forward para os servicos...

echo API Gateway na porta 8000...
start kubectl port-forward -n soa-architecture service/api-gateway 8000:8000

echo Consul na porta 8500...
start kubectl port-forward -n soa-architecture service/consul 8500:8500

echo Prometheus na porta 9090...
start kubectl port-forward -n soa-architecture service/prometheus 9090:9090

echo Grafana na porta 3000...
start kubectl port-forward -n soa-architecture service/grafana 3000:3000

echo.
echo Port-forward iniciado para todos os servicos
echo.
pause