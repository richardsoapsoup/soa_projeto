#!/bin/bash

echo "Deployando arquitetura SOA no Kubernetes..."

# Criar namespace
kubectl apply -f k8s/namespace.yaml

# Build das imagens (assumindo que está usando minikube ou registry)
echo "Build das imagens..."
docker build -t soa-api-gateway:latest api-gateway/
docker build -t soa-usuarios-service:latest usuarios-service/
docker build -t soa-posts-service:latest posts-service/

# Se usando minikube
# eval $(minikube docker-env)
# docker build -t soa-api-gateway:latest api-gateway/
# docker build -t soa-usuarios-service:latest usuarios-service/
# docker build -t soa-posts-service:latest posts-service/

# Aplicar configurações
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml

# Deploy serviços
kubectl apply -f k8s/zookeeper.yaml
kubectl apply -f k8s/kafka.yaml
kubectl apply -f k8s/consul.yaml
kubectl apply -f k8s/prometheus.yaml
kubectl apply -f k8s/grafana.yaml

# Deploy aplicação
kubectl apply -f k8s/usuarios-service.yaml
kubectl apply -f k8s/posts-service.yaml
kubectl apply -f k8s/api-gateway.yaml

echo "Aguardando serviços inicializarem..."
sleep 60

# Obter endpoints
echo "Serviços:"
kubectl get services -n soa-architecture

echo "Para acessar o API Gateway:"
echo "kubectl port-forward -n soa-architecture service/api-gateway 8000:8000"

echo "Para deletar: ./scripts/delete-k8s.sh"