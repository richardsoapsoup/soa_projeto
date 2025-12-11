# Aula Exemplo Arquitetura SOA com Docker e k8s
Disciplina de Sistemas Distribuídos


## Recursos da Arquitetura construida:
[x] Service Discovery com Consul
[x] Circuit Breaker no API Gateway
[x] Kafka para comunicação assíncrona
[x] Prometheus para monitoramento
[x] Docker e/ou Kubernetes para orquestração

## Como executar:

#### Windows:

Powershell (modo adm) caso não tenha nem docker nem k8s instalado
```bash
scripts\dev-setup.bat
scripts\install-dependencies.bat
```

Executar Docker
```bash
# inicialização completa
scripts\start-complete.bat
```
```bash
# passo a passo
# Iniciar infraestrutura
scripts\start-docker.bat

# Aguardar serviços e criar tópicos Kafka
scripts\wait-for-services.bat
scripts\create-kafka-topics.bat

# Testar API
scripts\test-api.bat

# Configurar monitoramento
scripts\monitoring-setup.bat

# Abrir interfaces
scripts\monitor.bat
```

Executar k8s
```bash
scripts/deploy-k8s.bat
scripts/port-forward.bat
scripts/test-api.bat
```

Utilitários
```bash
# Ver status completo
scripts\check-services.bat
scripts\health-check.bat

# Verificar métricas e monitoramento
scripts\check-metrics.bat
scripts\check-kafka.bat

# Parar tudo
scripts\stop-docker.bat
scripts\delete-k8s.bat

# Limpar ambiente completamente
scripts\cleanup.bat

# Reiniciar serviços
scripts\restart-docker.bat
```


#### Unix
```bash
chmod +x scripts/*.sh
./scripts/start-docker.sh
```

#### k8s:
- Unix
```bash
chmod +x scripts/*.sh
./scripts/deploy-k8s.sh
```

## Testando API com cURL

```bash
# Teste completo automatizado
scripts\test-api-enhanced.bat

# Ou manualmente:

# Registrar usuário
curl -X POST http://localhost:8000/usuarios/registrar \
  -H "Content-Type: application/json" \
  -d '{"username":"john","password":"secret"}'

# Login
curl -X POST http://localhost:8000/usuarios/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john","password":"secret"}'

# Criar post
curl -X POST http://localhost:8000/posts \
  -H "Content-Type: application/json" \
  -d '{"text":"Meu primeiro post","user_id":1}'

# Listar posts
curl http://localhost:8000/posts

# Verificar métricas
curl http://localhost:8000/metrics

# Health check
curl http://localhost:8000/health
```