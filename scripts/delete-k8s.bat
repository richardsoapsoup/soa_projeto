@echo off
echo Deletando recursos Kubernetes...
kubectl delete -f k8s\ --ignore-not-found=true
kubectl delete namespace soa-architecture --ignore-not-found=true
echo Recursos deletados
pause