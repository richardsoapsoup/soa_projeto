@echo off
echo Diagnostico do Ambiente SOA...

echo.
echo 1. Verificando containers...
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo.
echo 2. Verificando logs do Prometheus...
docker logs prometheus --tail 20

echo.
echo 3. Verificando se arquivo de configuracao existe...
if exist prometheus\prometheus.yml (
    echo Arquivo prometheus.yml existe
    type prometheus\prometheus.yml
) else (
    echo Arquivo prometheus.yml nao encontrado
)

echo.
echo 4. Verificando permissoes...
dir prometheus

echo.
echo 5. Reiniciando Prometheus...
docker-compose restart prometheus

echo.
echo Diagnostico concluido!
pause