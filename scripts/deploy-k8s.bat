@echo off
echo Deployando arquitetura SOA no Kubernetes...

echo Criando namespace...
kubectl apply -f k8s\namespace.yaml

echo Build das imagens...
docker build -t soa-api-gateway:latest api-gateway/
if %errorlevel% neq 0 (
    echo Erro no build do api-gateway
    exit /b 1
)

docker build -t soa-usuarios-service:latest usuarios-service/
if %errorlevel% neq 0 (
    echo Erro no build do usuarios-service
    exit /b 1
)

docker build -t soa-posts-service:latest posts-service/
if %errorlevel% neq 0 (
    echo Erro no build do posts-service
    exit /b 1
)

echo Aplicando configuracoes...
kubectl apply -f k8s\configmap.yaml
kubectl apply -f k8s\secrets.yaml

echo Deployando infraestrutura...
kubectl apply -f k8s\zookeeper.yaml
kubectl apply -f k8s\kafka.yaml
kubectl apply -f k8s\consul.yaml
kubectl apply -f k8s\prometheus.yaml
kubectl apply -f k8s\grafana.yaml

echo Deployando aplicacao...
kubectl apply -f k8s\usuarios-service.yaml
kubectl apply -f k8s\posts-service.yaml
kubectl apply -f k8s\api-gateway.yaml

echo.
echo Aguardando servicos inicializarem...
timeout 60

echo Servicos:
kubectl get services -n soa-architecture

echo.
echo Para acessar o API Gateway:
echo kubectl port-forward -n soa-architecture service/api-gateway 8000:8000
echo.
echo Para deletar: scripts/delete-k8s.bat
echo.
pause